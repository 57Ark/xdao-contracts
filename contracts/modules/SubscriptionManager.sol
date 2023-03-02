// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.6;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/IERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";

contract SubscriptionManager is
    Initializable,
    OwnableUpgradeable,
    UUPSUpgradeable,
    AccessControlEnumerableUpgradeable
{
    using SafeERC20Upgradeable for IERC20Upgradeable;

    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    IERC20Upgradeable public token;
    address public recipientAddress;
    uint64 public minDuration;
    uint256 constant uUNIT = 1e18;

    struct SubscriptionStatus {
        uint8 subscriptionLevel;
        uint256 endTimestamp; // this timestamp is multiplied by 1e18
    }

    struct SubscriptionParameters {
        uint8 subscriptionLevel;
        uint256 period; // timestamp  multiplied by 1e18
    }

    // Chain ID => DAO Address => Current Subscription
    mapping(uint256 => mapping(address => SubscriptionStatus))
        public subscriptions;

    // Subscription Level => Timestamp per 1 Token
    mapping(uint8 => uint64) public durationPerToken;

    // NFT Address => Token ID => Issuing Subscription
    mapping(address => mapping(uint256 => SubscriptionParameters))
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
        IERC20Upgradeable _token,
        address _recipientAddress,
        uint64 _minDuration
    ) public initializer {
        __Ownable_init();
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MANAGER_ROLE, msg.sender);

        token = _token;
        recipientAddress = _recipientAddress;
        minDuration = _minDuration;
    }

    function editToken(
        IERC20Upgradeable _token
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        token = _token;
    }

    function editMinDuration(
        uint64 _minDuration
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        minDuration = _minDuration;
    }

    function editRecipient(
        address _recipientAddress
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        recipientAddress = _recipientAddress;
    }

    function editDurationPerToken(
        uint8 _subscriptionLevel,
        uint64 _timestamp
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        durationPerToken[_subscriptionLevel] = _timestamp;
    }

    function editReceivableERC1155(
        address _tokenAddress,
        uint256 _tokenId,
        uint8 _subscriptionLevel,
        uint64 _timestamp
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        receivableERC1155[_tokenAddress][_tokenId] = SubscriptionParameters({
            subscriptionLevel: _subscriptionLevel,
            period: _timestamp * uUNIT
        });
    }

    function setSubscriptionStatus(
        uint256 _chainId,
        address _dao,
        uint8 _level,
        uint64 _timestamp
    ) external onlyRole(MANAGER_ROLE) {
        subscriptions[_chainId][_dao] = SubscriptionStatus({
            subscriptionLevel: _level,
            endTimestamp: _timestamp * uUNIT
        });
    }

    function pay(
        uint256 _chainId,
        address _dao,
        uint8 _level,
        uint256 _tokenAmount
    ) external {
        SubscriptionStatus storage daoSubscription = subscriptions[_chainId][
            _dao
        ];

        require(
            daoSubscription.endTimestamp < block.timestamp * uUNIT ||
                (_level >= daoSubscription.subscriptionLevel),
            "SubscriptionManager: subscription can't be downgraded"
        );

        uint64 newLevelPricing = durationPerToken[_level];

        require(
            newLevelPricing > 0,
            "SubscriptionManager: invalid subscription level"
        );

        require(
            (_tokenAmount * newLevelPricing) >= uUNIT * (minDuration),
            "SubscriptionManager: subscription period is too low"
        );

        uint64 currentLevelPricing = durationPerToken[
            daoSubscription.subscriptionLevel
        ];

        uint256 alreadyPaidAmount = daoSubscription.endTimestamp >
            block.timestamp * uUNIT
            ? (daoSubscription.endTimestamp - block.timestamp * uUNIT) /
                currentLevelPricing
            : 0;

        uint256 newTimestamp = (newLevelPricing *
            (_tokenAmount + alreadyPaidAmount)) + block.timestamp * uUNIT;

        subscriptions[_chainId][_dao] = SubscriptionStatus({
            subscriptionLevel: _level,
            endTimestamp: newTimestamp
        });

        token.safeTransferFrom(msg.sender, recipientAddress, _tokenAmount);

        emit PaySubscription(_chainId, _dao, _level, newTimestamp);
    }

    function payWithERC1155(
        uint256 _chainId,
        address _dao,
        address _tokenAddress,
        uint256 _tokenId
    ) external {
        SubscriptionStatus storage daoSubscription = subscriptions[_chainId][
            _dao
        ];
        SubscriptionParameters storage tokenSubscription = receivableERC1155[
            _tokenAddress
        ][_tokenId];

        require(
            daoSubscription.endTimestamp < block.timestamp * uUNIT ||
                (tokenSubscription.subscriptionLevel >=
                    daoSubscription.subscriptionLevel),
            "SubscriptionManager: subscription can't be downgraded"
        );

        require(
            tokenSubscription.period > 0,
            "SubscriptionManager: unsupported ERC1155"
        );

        uint64 newLevelPricing = durationPerToken[
            tokenSubscription.subscriptionLevel
        ];

        uint64 currentLevelPricing = durationPerToken[
            daoSubscription.subscriptionLevel
        ];

        uint256 alreadyPaidAmount = daoSubscription.endTimestamp >
            block.timestamp * uUNIT
            ? (daoSubscription.endTimestamp - block.timestamp * uUNIT) /
                currentLevelPricing
            : 0;

        uint256 newTimestamp = (newLevelPricing * alreadyPaidAmount) +
            tokenSubscription.period +
            block.timestamp *
            uUNIT;

        subscriptions[_chainId][_dao] = SubscriptionStatus({
            subscriptionLevel: tokenSubscription.subscriptionLevel,
            endTimestamp: newTimestamp
        });

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
