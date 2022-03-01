// SPDX-License-Identifier: WTFPL

pragma solidity 0.8.12;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import "./libraries/FungibleTokens.sol";
import "./strategies/interfaces/IIDOStrategy.sol";

abstract contract BaseIDO is Ownable {
    using FungibleTokens for address;

    /**
     * @notice Token to be used for purchasing (either ERC20 or ETH)
     */
    address public currency;
    /**
     * @notice Token to be sold (One of ERC20, ERC721 or ERC1155)
     */
    address public asset;
    /**
     * @notice Start timestamp
     */
    uint64 public start;
    /**
     * @notice Duration in seconds
     */
    uint64 public duration;
    /**
     * @notice An IDO strategy contract that implements IIDOStrategy.
     */
    address public strategy;
    /**
     * @notice If this sets to true, only whitelisted accounts can call `enroll()`
     */
    bool public whitelistOnly;
    /**
     * @notice Minimum amount to raise. If `totalAmount` is less than this after the IDO finishes, raised amount will be
     * refunded to the participants using `refund()`.
     */
    uint256 public softCap;
    /**
     * @notice Maximum amount to raise.
     */
    uint256 public hardCap;
    /**
     * @notice Maximum amount than an account can participate with.
     */
    uint256 public individualCap;
    /**
     * @notice A distinct Uniform Resource Identifier (URI) for the IDO. URIs are defined in RFC 3986. The URI
     * should point to a JSON file that conforms to the "IDO Metadata JSON Schema".
     *
     * The "IDO Metadata JSON Schema" is as follows:
     * {
     *    "title": "IDO Metadata",
     *    "type": "object",
     *    "properties": {
     *        "name": {
     *            "type": "string",
     *            "description": "Identifies the name of the IDO"
     *        },
     *        "description": {
     *            "type": "string",
     *            "description": "Describes the IDO"
     *        },
     *        "logo": {
     *            "type": "string",
     *            "description": "A URI pointing to a logo image whose ratio is 1:1."
     *        },
     *        "cover": {
     *            "type": "string",
     *            "description": "A URI pointing to a cover image whose ratio is 16:9."
     *        },
     *        "website": {
     *            "type": "string",
     *            "description": "A URI pointing to the website."
     *        },
     *        "twitter": {
     *            "type": "string",
     *            "description": "A URI pointing to the twitter account."
     *        },
     *        "discord": {
     *            "type": "string",
     *            "description": "A URI pointing to the discord server."
     *        },
     *        "telegram": {
     *            "type": "string",
     *            "description": "A URI pointing to the telegram."
     *        },
     *        "medium": {
     *            "type": "string",
     *            "description": "A URI pointing to the medium."
     *        },
     *        "facebook": {
     *            "type": "string",
     *            "description": "A URI pointing to the facebook page."
     *        },
     *        "reddit": {
     *            "type": "string",
     *            "description": "A URI pointing to the reddit."
     *        }
     *    }
     * }
     */
    string public uri;

    mapping(address => bool) public isWhitelisted;
    Enrollment[] public enrollments;
    uint256 public totalAmount;
    bool public cancelled;
    bool public closed;

    mapping(address => uint256) private _amounts;

    modifier notCancelled {
        require(!cancelled, "DAOKIT: CANCELLED");
        _;
    }

    struct Config {
        address currency;
        address asset;
        uint64 start;
        uint64 duration;
        address strategy;
        bool whitelistOnly;
        uint256 softCap;
        uint256 hardCap;
        uint256 individualCap;
        string uri;
    }

    struct Enrollment {
        uint256 amount;
        address account;
        uint64 timestamp;
        bool claimedOrRefunded;
    }

    event Cancel();
    event AddToWhitelist(address indexed account);
    event RemoveFromWhitelist(address indexed account);
    event Enroll(uint256 id, address indexed account, uint256 amount);
    event Claim(address indexed account, uint256 tokenId, uint256 amount);
    event Refund(address indexed account, uint256 amount);
    event Close();

    constructor(address _owner, Config memory config) {
        _transferOwnership(_owner);
        _updateConfig(config);
    }

    /**
     * @notice This is called when the `asset` is initially offered to `to` address for a given `tokenId` and `amount`
     * only if the IDO was successful, when `totalAmount` > `hardCap`.
     */
    function _offerAssets(
        address to,
        uint256[] memory tokenIds,
        uint256[] memory amounts
    ) internal virtual;

    /**
     * @notice This is called when the IDO was `cancelled` or `closed` so that assets need to be returned
     */
    function _returnAssets(uint256[] memory tokenIds) internal virtual;

    /**
     * @notice Only `owner` can cancel the IDO if it didn't start yet. All `asset`s of `tokenIds` that belongs to this
     *  contract will return to `owner`.
     */
    function cancel(uint256[] memory tokenIds) external onlyOwner notCancelled {
        require(block.timestamp < start, "DAOKIT: STARTED");

        cancelled = true;
        emit Cancel();
        _returnAssets(tokenIds);
    }

    /**
     * @notice Only `owner` can update the config if it didn't start yet.
     */
    function updateConfig(Config memory config) public onlyOwner notCancelled {
        require(block.timestamp < start, "DAOKIT: STARTED");

        _updateConfig(config);
    }

    function _updateConfig(Config memory config) private {
        require(asset != address(0), "DAOKIT: INVALID_ASSET");
        require(block.timestamp < start, "DAOKIT: INVALID_START");
        require(duration > 0, "DAOKIT: INVALID_START");
        require(
            ERC165Checker.supportsERC165(strategy) &&
                ERC165Checker.supportsInterface(strategy, type(IIDOStrategy).interfaceId),
            "DAOKIT: INVALIDSTRATEGY"
        );

        if (hardCap > 0) {
            require(softCap < hardCap, "DAOKIT: INVALID_HARD_CAP");
        }
        require(bytes(uri).length > 0, "DAOKIT: INVALID_URI");

        currency = config.currency;
        asset = config.asset;
        start = config.start;
        duration = config.duration;
        strategy = config.strategy;
        whitelistOnly = config.whitelistOnly;
        softCap = config.softCap;
        hardCap = config.hardCap;
        individualCap = config.individualCap;
        uri = config.uri;
    }

    function addToWhitelist() external notCancelled {
        isWhitelisted[msg.sender] = true;

        emit AddToWhitelist(msg.sender);
    }

    function removeFromWhitelist() external notCancelled {
        isWhitelisted[msg.sender] = false;

        emit RemoveFromWhitelist(msg.sender);
    }

    /**
     * @notice Anyone can enroll by sending a certain `amount` of `currency` to this contract.
     */
    function enroll(uint256 amount) external payable notCancelled {
        require(amount > 0, "DAOKIT: INVALID_AMOUNT");
        require(start <= block.timestamp, "DAOKIT: NOT_STARTED");
        require(block.timestamp < start + duration, "DAOKIT: FINISHED");
        if (whitelistOnly) {
            require(isWhitelisted[msg.sender], "DAOKIT: NOT_WHITELISTED");
        }
        if (hardCap > 0) {
            require(totalAmount + amount <= hardCap, "DAOKIT: HARD_CAP_EXCEEDED");
        }
        if (individualCap > 0) {
            require(_amounts[msg.sender] + amount <= individualCap, "DAOKIT: INDIVIDUAL_CAP_EXCEEDED");
        }

        uint256 id = enrollments.length;
        Enrollment storage e = enrollments.push();
        e.amount = amount;
        e.account = msg.sender;
        e.timestamp = uint64(block.timestamp);

        totalAmount += amount;
        _amounts[msg.sender] += amount;

        emit Enroll(id, msg.sender, amount);
        currency.safeTransferFrom(msg.sender, address(this), amount);
    }

    /**
     * @notice Enrolled users can claim their `asset`s that correspond to `enrollmentIds` if the IDO finished
     *  successfully, which means it reached the soft cap if it exists.
     */
    function claim(uint256[] calldata enrollmentIds) external notCancelled {
        uint256[] memory tokenIds = new uint256[](enrollmentIds.length);
        uint256[] memory amounts = new uint256[](enrollmentIds.length);
        for (uint256 i; i < enrollmentIds.length; i++) {
            (uint256 tokenId, uint256 amount) = _claim(enrollmentIds[i]);
            tokenIds[i] = tokenId;
            amounts[i] = amount;
        }
        _offerAssets(msg.sender, tokenIds, amounts);
    }

    function _claim(uint256 id) private returns (uint256 tokenId, uint256 amount) {
        require(start + duration <= block.timestamp, "DAOKIT: NOT_FINISHED");
        require(softCap == 0 || softCap <= totalAmount, "DAOKIT: SOFT_CAP_NOT_REACHED");

        Enrollment storage e = enrollments[id];
        require(e.account == msg.sender, "DAOKIT: FORBIDDEN");
        require(!e.claimedOrRefunded, "DAOKIT: CLAIMED");
        e.claimedOrRefunded = true;

        (tokenId, amount) = IIDOStrategy(strategy).claimableAsset(e.amount, e.timestamp);
        emit Claim(msg.sender, tokenId, amount);
    }

    /**
     * @notice Enrolled users can get refunded with `enrollmentIds` if the IDO didn't finish  successfully, which means
     *  it didn't reach the soft cap.
     */
    function refund(uint256[] memory enrollmentIds) external notCancelled {
        for (uint256 i; i < enrollmentIds.length; i++) {
            _refund(enrollmentIds[i]);
        }
    }

    function _refund(uint256 id) private {
        require(start + duration <= block.timestamp, "DAOKIT: NOT_FINISHED");
        require(softCap > 0 && totalAmount < softCap, "DAOKIT: SOFT_CAP_REACHED");

        Enrollment storage e = enrollments[id];
        require(e.account == msg.sender, "DAOKIT: FORBIDDEN");
        require(!e.claimedOrRefunded, "DAOKIT: REFUNDED");
        e.claimedOrRefunded = true;

        uint256 _amount = e.amount;
        emit Refund(msg.sender, _amount);
        currency.safeTransfer(msg.sender, _amount);
    }

    /**
     * @notice Only `owner` can close the IDO after it finishes. If it was successful all the funds is sent to `owner,
     *  otherwise all `asset`s are returned to the `owner`.
     */
    function close(uint256[] memory tokenIds) external onlyOwner notCancelled {
        require(!closed, "DAOKIT: CLOSED");
        require(start + duration <= block.timestamp, "DAOKIT: NOT_FINISHED");

        closed = true;
        emit Close();
        if (softCap > 0 && totalAmount < softCap) {
            // If it failed
            _returnAssets(tokenIds);
        } else {
            // If it was successful
            address _currency = currency;
            _currency.safeTransfer(msg.sender, _currency.balanceOf(address(this)));
        }
    }
}
