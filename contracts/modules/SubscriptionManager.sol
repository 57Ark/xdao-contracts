// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.6;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/IERC1155Upgradeable.sol";

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
    uint256 public minimumTimestampPayment;

    struct Subscription {
        uint256 subscriptionLevel;
        uint256 timestamp;
    }

    // Chain ID => DAO Address => Current Subscription
    mapping(uint256 => mapping(address => Subscription)) private subscriptions;

    // Subscription Level => Timestamp per 1 Token
    mapping(uint256 => uint256) private pricing;

    // NFT Address => Token ID => Issuing Subscription
    mapping(address => mapping(uint256 => Subscription)) private receivableNft;

    event PaySubscription(
        uint256 indexed chainId,
        address indexed daoAddress,
        uint256 subscriptionLevel,
        uint256 timestamp
    );

    event PaySubscriptionWithNft(
        uint256 indexed chainId,
        address indexed daoAddress,
        address tokenAddress,
        uint256 tokenId,
        uint256 subscriptionLevel,
        uint256 timestamp
    );

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {}

    function initialize(
        IERC20Upgradeable _token,
        address _recipientAddress,
        uint256 _minimumTimestampPayment
    ) public initializer {
        __Ownable_init();
        __UUPSUpgradeable_init();

        token = _token;
        recipientAddress = _recipientAddress;
        minimumTimestampPayment = _minimumTimestampPayment;
    }

    function editMinimumTimestampPayment(
        uint256 _minimumTimestampPayment
    ) external onlyOwner {
        minimumTimestampPayment = _minimumTimestampPayment;
    }

    function editRecipient(address _recipientAddress) external onlyOwner {
        recipientAddress = _recipientAddress;
    }

    // IMPROTANT!: low level subscription level must be eq 0
    function editPricing(
        uint256 _subscriptionLevel,
        uint256 _timestamp
    ) external onlyOwner {
        pricing[_subscriptionLevel] = _timestamp;
    }

    function editReceivableNft(
        address _tokenAddress,
        uint256 _tokenId,
        uint256 _subscriptionLevel,
        uint256 _timestamp
    ) external onlyOwner {
        receivableNft[_tokenAddress][_tokenId] = Subscription({
            subscriptionLevel: _subscriptionLevel,
            timestamp: _timestamp
        });
    }

    // for highest level custom subscription (pro/enterprice... etc (it doesn't have name right now))
    // maybe we need to add a manager role so they can manually distribute the subscriptions by themselves?
    function setSubscription(
        uint256 _chainId,
        address _dao,
        uint256 _level,
        uint256 _timestamp
    ) external onlyOwner {
        Subscription storage daoSubscription = subscriptions[_chainId][_dao];
        daoSubscription.subscriptionLevel = _level;
        daoSubscription.timestamp = _timestamp;
    }

    function pay(
        uint256 _chainId,
        address _dao,
        uint256 _level,
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

        uint256 newTimestamp = (newLevelPricing *
            (_tokenAmount + alreadyPaidAmount)) + block.timestamp;

        token.safeTransferFrom(msg.sender, recipientAddress, _tokenAmount);

        daoSubscription.subscriptionLevel = _level;
        daoSubscription.timestamp = newTimestamp;

        emit PaySubscription(_chainId, _dao, _level, newTimestamp);
    }

    function payWithNft(
        uint256 _chainId,
        address _dao,
        address _tokenAddress,
        uint256 _tokenId
    ) external {
        Subscription storage daoSubscription = subscriptions[_chainId][_dao];
        Subscription storage nftSubscription = receivableNft[_tokenAddress][
            _tokenId
        ];

        require(
            daoSubscription.timestamp < block.timestamp ||
                (nftSubscription.subscriptionLevel >=
                    daoSubscription.subscriptionLevel),
            "SubscriptionManager: subscription can't be downgraded"
        );

        require(
            nftSubscription.timestamp > 0,
            "SubscriptionManager: unsupported nft"
        );

        uint256 newLevelPricing = pricing[nftSubscription.subscriptionLevel];

        uint256 currentLevelPricing = pricing[
            daoSubscription.subscriptionLevel
        ];

        // recalculation of remaining valid subscription
        uint256 alreadyPaidAmount = MathUpgradeable.max(
            0,
            (daoSubscription.timestamp - block.timestamp) / currentLevelPricing
        );

        uint256 newTimestamp = (newLevelPricing * alreadyPaidAmount) +
            nftSubscription.timestamp +
            block.timestamp;

        IERC1155Upgradeable(_tokenAddress).safeTransferFrom(
            msg.sender,
            recipientAddress,
            _tokenId,
            1,
            hex""
        );

        daoSubscription.subscriptionLevel = nftSubscription.subscriptionLevel;
        daoSubscription.timestamp = newTimestamp;

        emit PaySubscriptionWithNft(
            _chainId,
            _dao,
            _tokenAddress,
            _tokenId,
            nftSubscription.subscriptionLevel,
            newTimestamp
        );
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}
}
