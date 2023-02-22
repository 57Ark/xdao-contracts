// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.6;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/IERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";

contract SubscriptionManager is
    Initializable,
    OwnableUpgradeable,
    UUPSUpgradeable,
    AccessControlEnumerableUpgradeable
{
    using SafeERC20Upgradeable for ERC20Upgradeable;

    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    ERC20Upgradeable public token;
    address public recipientAddress;
    uint64 public minimumTimestampPayment;

    struct Subscription {
        uint8 subscriptionLevel;
        uint256 timestamp; // this timestamp is multiplied by 10 ** token.decimals()
    }

    // Chain ID => DAO Address => Current Subscription
    mapping(uint256 => mapping(address => Subscription)) public subscriptions;

    // Subscription Level => Timestamp per 1 Token
    mapping(uint8 => uint64) public pricing;

    // NFT Address => Token ID => Issuing Subscription
    mapping(address => mapping(uint256 => Subscription))
        public receivableERC1155;

    event PaySubscription(
        uint256 indexed chainId,
        address indexed daoAddress,
        uint8 subscriptionLevel,
        uint256 timestamp
    );

    event PaySubscriptionWithERC1155(
        uint256 indexed chainId,
        address indexed daoAddress,
        address tokenAddress,
        uint256 tokenId,
        uint8 subscriptionLevel,
        uint256 timestamp
    );

    function initialize(
        ERC20Upgradeable _token,
        address _recipientAddress,
        uint64 _minimumTimestampPayment
    ) public initializer {
        __Ownable_init();
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MANAGER_ROLE, msg.sender);

        token = _token;
        recipientAddress = _recipientAddress;
        minimumTimestampPayment = _minimumTimestampPayment;
    }

    function editMinimumTimestampPayment(
        uint64 _minimumTimestampPayment
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        minimumTimestampPayment = _minimumTimestampPayment;
    }

    function editRecipient(
        address _recipientAddress
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        recipientAddress = _recipientAddress;
    }

    function editPricing(
        uint8 _subscriptionLevel,
        uint64 _timestamp
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        pricing[_subscriptionLevel] = _timestamp;
    }

    function editReceivableERC1155(
        address _tokenAddress,
        uint256 _tokenId,
        uint8 _subscriptionLevel,
        uint64 _timestamp
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        receivableERC1155[_tokenAddress][_tokenId] = Subscription({
            subscriptionLevel: _subscriptionLevel,
            timestamp: _timestamp * (10 ** token.decimals())
        });
    }

    function setSubscription(
        uint256 _chainId,
        address _dao,
        uint8 _level,
        uint64 _timestamp
    ) external onlyRole(MANAGER_ROLE) {
        Subscription storage daoSubscription = subscriptions[_chainId][_dao];
        daoSubscription.subscriptionLevel = _level;
        daoSubscription.timestamp = _timestamp * (10 ** token.decimals());
    }

    function pay(
        uint256 _chainId,
        address _dao,
        uint8 _level,
        uint256 _tokenAmount
    ) external {
        Subscription storage daoSubscription = subscriptions[_chainId][_dao];

        require(
            daoSubscription.timestamp <
                block.timestamp * (10 ** token.decimals()) ||
                (_level >= daoSubscription.subscriptionLevel),
            "SubscriptionManager: subscription can't be downgraded"
        );

        uint64 newLevelPricing = pricing[_level];

        require(
            newLevelPricing > 0,
            "SubscriptionManager: invalid subscription level"
        );

        require(
            (_tokenAmount * newLevelPricing) >=
                (10 ** token.decimals()) * (minimumTimestampPayment),
            "SubscriptionManager: subscription period is too low"
        );

        uint64 currentLevelPricing = pricing[daoSubscription.subscriptionLevel];

        uint256 alreadyPaidAmount = daoSubscription.timestamp >
            block.timestamp * (10 ** token.decimals())
            ? (daoSubscription.timestamp -
                block.timestamp *
                (10 ** token.decimals())) / currentLevelPricing
            : 0;

        uint256 newTimestamp = (newLevelPricing *
            (_tokenAmount + alreadyPaidAmount)) +
            block.timestamp *
            (10 ** token.decimals());

        daoSubscription.subscriptionLevel = _level;
        daoSubscription.timestamp = newTimestamp;

        token.safeTransferFrom(msg.sender, recipientAddress, _tokenAmount);

        emit PaySubscription(_chainId, _dao, _level, newTimestamp);
    }

    function payWithERC1155(
        uint256 _chainId,
        address _dao,
        address _tokenAddress,
        uint256 _tokenId
    ) external {
        Subscription storage daoSubscription = subscriptions[_chainId][_dao];
        Subscription storage tokenSubscription = receivableERC1155[
            _tokenAddress
        ][_tokenId];

        require(
            daoSubscription.timestamp <
                block.timestamp * (10 ** token.decimals()) ||
                (tokenSubscription.subscriptionLevel >=
                    daoSubscription.subscriptionLevel),
            "SubscriptionManager: subscription can't be downgraded"
        );

        require(
            tokenSubscription.timestamp > 0,
            "SubscriptionManager: unsupported ERC1155"
        );

        uint64 newLevelPricing = pricing[tokenSubscription.subscriptionLevel];

        uint64 currentLevelPricing = pricing[daoSubscription.subscriptionLevel];

        uint256 alreadyPaidAmount = daoSubscription.timestamp >
            block.timestamp * (10 ** token.decimals())
            ? (daoSubscription.timestamp -
                block.timestamp *
                (10 ** token.decimals())) / currentLevelPricing
            : 0;

        uint256 newTimestamp = (newLevelPricing * alreadyPaidAmount) +
            tokenSubscription.timestamp +
            block.timestamp *
            (10 ** token.decimals());

        daoSubscription.subscriptionLevel = tokenSubscription.subscriptionLevel;
        daoSubscription.timestamp = newTimestamp;

        IERC1155Upgradeable(_tokenAddress).safeTransferFrom(
            msg.sender,
            recipientAddress,
            _tokenId,
            1,
            hex""
        );

        emit PaySubscriptionWithERC1155(
            _chainId,
            _dao,
            _tokenAddress,
            _tokenId,
            tokenSubscription.subscriptionLevel,
            newTimestamp
        );
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}
}
