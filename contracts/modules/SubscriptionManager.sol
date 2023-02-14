// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.6;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/IERC1155Upgradeable.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";

import "../interfaces/IFactory.sol";
import "../interfaces/IShop.sol";
import "../interfaces/IDao.sol";
import "../interfaces/IPrivateExitModule.sol";

contract SubscriptionManager is
    Initializable,
    OwnableUpgradeable,
    UUPSUpgradeable
{
    using SafeERC20Upgradeable for IERC20Upgradeable;

    IERC20Upgradeable public token;
    address public recipientAddress;
    uint64 public minimumTimestampPayment;

    struct Subscription {
        uint8 subscriptionLevel;
        uint64 timestamp;
    }

    // Chain ID => DAO Address => Current Subscription
    mapping(uint256 => mapping(address => Subscription)) public subscriptions;

    // Subscription Level => Timestamp per 1 Token
    mapping(uint8 => uint64) public pricing;

    // NFT Address => Token ID => Issuing Subscription
    mapping(address => mapping(uint256 => Subscription)) public receivable1155;

    event PaySubscription(
        uint256 indexed chainId,
        address indexed daoAddress,
        uint256 subscriptionLevel,
        uint256 timestamp
    );

    event PaySubscriptionWith1155(
        uint256 indexed chainId,
        address indexed daoAddress,
        address tokenAddress,
        uint256 tokenId,
        uint256 subscriptionLevel,
        uint256 timestamp
    );

    function initialize(
        IERC20Upgradeable _token,
        address _recipientAddress,
        uint64 _minimumTimestampPayment
    ) public initializer {
        __Ownable_init();
        __UUPSUpgradeable_init();

        token = _token;
        recipientAddress = _recipientAddress;
        minimumTimestampPayment = _minimumTimestampPayment;
    }

    function editMinimumTimestampPayment(
        uint64 _minimumTimestampPayment
    ) external onlyOwner {
        minimumTimestampPayment = _minimumTimestampPayment;
    }

    function editRecipient(address _recipientAddress) external onlyOwner {
        recipientAddress = _recipientAddress;
    }

    // IMPROTANT!: low level subscription level must be eq 0
    function editPricing(
        uint8 _subscriptionLevel,
        uint64 _timestamp
    ) external onlyOwner {
        pricing[_subscriptionLevel] = _timestamp;
    }

    function editReceivable1155(
        address _tokenAddress,
        uint256 _tokenId,
        uint8 _subscriptionLevel,
        uint64 _timestamp
    ) external onlyOwner {
        receivable1155[_tokenAddress][_tokenId] = Subscription({
            subscriptionLevel: _subscriptionLevel,
            timestamp: _timestamp
        });
    }

    // for highest level custom subscription (pro/enterprice... etc (it doesn't have name right now))
    // maybe we need to add a manager role so they can manually distribute the subscriptions by themselves?
    function setSubscription(
        uint256 _chainId,
        address _dao,
        uint8 _level,
        uint64 _timestamp
    ) external onlyOwner {
        Subscription storage daoSubscription = subscriptions[_chainId][_dao];
        daoSubscription.subscriptionLevel = _level;
        daoSubscription.timestamp = _timestamp;
    }

    function pay(
        uint256 _chainId,
        address _dao,
        uint8 _level,
        uint256 _tokenAmount
    ) external {
        Subscription storage daoSubscription = subscriptions[_chainId][_dao];

        require(
            daoSubscription.timestamp < block.timestamp ||
                (_level >= daoSubscription.subscriptionLevel),
            "SubscriptionManager: subscription can't be downgraded"
        );

        uint256 newLevelPricing = pricing[_level];

        require(
            newLevelPricing > 0,
            "SubscriptionManager: invalid subscription level"
        );

        require(
            newLevelPricing * _tokenAmount >= minimumTimestampPayment,
            "SubscriptionManager: subscription period is too low"
        );

        uint256 currentLevelPricing = pricing[
            daoSubscription.subscriptionLevel
        ];

        // recalculation of remaining valid subscription
        uint256 alreadyPaidAmount = MathUpgradeable.max(
            0,
            (daoSubscription.timestamp - block.timestamp) / currentLevelPricing
        );

        uint64 newTimestamp = SafeCast.toUint64(
            (newLevelPricing * (_tokenAmount + alreadyPaidAmount)) +
                block.timestamp
        );

        daoSubscription.subscriptionLevel = _level;
        daoSubscription.timestamp = newTimestamp;

        token.safeTransferFrom(msg.sender, recipientAddress, _tokenAmount);

        emit PaySubscription(_chainId, _dao, _level, newTimestamp);
    }

    function payWith1155(
        uint256 _chainId,
        address _dao,
        address _tokenAddress,
        uint256 _tokenId
    ) external {
        Subscription storage daoSubscription = subscriptions[_chainId][_dao];
        Subscription storage tokenSubscription = receivable1155[_tokenAddress][
            _tokenId
        ];

        require(
            daoSubscription.timestamp < block.timestamp ||
                (tokenSubscription.subscriptionLevel >=
                    daoSubscription.subscriptionLevel),
            "SubscriptionManager: subscription can't be downgraded"
        );

        require(
            tokenSubscription.timestamp > 0,
            "SubscriptionManager: unsupported ERC1155"
        );

        uint256 newLevelPricing = pricing[tokenSubscription.subscriptionLevel];

        uint256 currentLevelPricing = pricing[
            daoSubscription.subscriptionLevel
        ];

        // recalculation of remaining valid subscription
        uint256 alreadyPaidAmount = MathUpgradeable.max(
            0,
            (daoSubscription.timestamp - block.timestamp) / currentLevelPricing
        );

        uint64 newTimestamp = SafeCast.toUint64(
            (newLevelPricing * alreadyPaidAmount) +
                tokenSubscription.timestamp +
                block.timestamp
        );

        daoSubscription.subscriptionLevel = tokenSubscription.subscriptionLevel;
        daoSubscription.timestamp = newTimestamp;

        IERC1155Upgradeable(_tokenAddress).safeTransferFrom(
            msg.sender,
            recipientAddress,
            _tokenId,
            1,
            hex""
        );

        emit PaySubscriptionWith1155(
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
