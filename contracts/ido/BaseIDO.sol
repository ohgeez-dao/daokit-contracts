// SPDX-License-Identifier: WTFPL

pragma solidity 0.8.12;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import "./libraries/FungibleTokens.sol";
import "./Whitelist.sol";

/**
 * @notice Base IDO contract to support various asset standards (ERC20, ERC721, ERC1155 and more).
 */
abstract contract BaseIDO is Ownable, Whitelist {
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
     * @notice If this sets to true, only whitelisted accounts can call `enroll()`
     */
    bool public whitelistOnly;
    /**
     * @notice Minimum amount to raise. If `totalAmount` is less than this after the IDO finishes, raised amount will be
     * refunded to the participants using `refund()`.
     */
    uint128 public softCap;
    /**
     * @notice Maximum amount to raise.
     */
    uint128 public hardCap;
    /**
     * @notice Maximum amount than an account can participate with.
     */
    uint128 public individualCap;
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
    /**
     * @notice Additional data used for `claimableAsset()`
     */
    bytes public data;

    Enrollment[] public enrollments;
    uint128 public totalAmount;
    bool public cancelled;
    bool public closed;

    mapping(address => uint128) private _amounts;

    struct Config {
        address currency;
        address asset;
        uint64 start;
        uint64 duration;
        bool whitelistOnly;
        uint128 softCap;
        uint128 hardCap;
        uint128 individualCap;
        string uri;
        bytes data;
    }

    struct Enrollment {
        uint128 amount;
        address account;
        uint64 timestamp;
        bool claimedOrRefunded;
    }

    modifier notCancelled {
        require(!cancelled, "DAOKIT: CANCELLED");
        _;
    }

    modifier beforeStarted {
        require(block.timestamp < start, "DAOKIT: STARTED");
        _;
    }

    modifier afterFinished {
        require(start + duration <= block.timestamp, "DAOKIT: NOT_FINISHED");
        _;
    }

    event Cancel();
    event Enroll(uint256 id, address indexed account, uint128 amount);
    event Claim(uint256 id, address indexed account, uint256 tokenId, uint256 amount);
    event Refund(uint256 id, address indexed account, uint128 amount);
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
     * @notice This should return the tokenId and amount that can be claimed for `enrollAmount` at `timestamp`
     */
    function _claimableAsset(uint128 enrollAmount, uint64 timestamp)
        internal
        view
        virtual
        returns (uint256 claimableTokenId, uint256 claimableAmount);

    function addToWhitelist() external beforeStarted {
        _addToWhitelist();
    }

    function removeFromWhitelist() external beforeStarted {
        _removeFromWhitelist();
    }

    function addMerkleRoot(bytes32 merkleRoot) external onlyOwner {
        _addMerkleRoot(merkleRoot);
    }

    function removeMerkleRoot(bytes32 merkleRoot) external onlyOwner {
        _removeMerkleRoot(merkleRoot);
    }

    /**
     * @notice Only `owner` can cancel the IDO if it didn't start yet. All `asset`s of `tokenIds` that belongs to this
     *  contract will return to `owner`.
     */
    function cancel(uint256[] memory tokenIds) external onlyOwner notCancelled beforeStarted {
        cancelled = true;
        emit Cancel();
        _returnAssets(tokenIds);
    }

    /**
     * @notice Only `owner` can update the config if it didn't start yet.
     */
    function updateConfig(Config memory config) public onlyOwner notCancelled beforeStarted {
        _updateConfig(config);
    }

    function _updateConfig(Config memory config) internal virtual {
        require(config.asset != address(0), "DAOKIT: INVALID_ASSET");
        require(block.timestamp < config.start, "DAOKIT: INVALID_START");
        require(config.duration > 0, "DAOKIT: INVALID_DURATION");
        require(config.hardCap == 0 || config.softCap < config.hardCap, "DAOKIT: INVALID_HARD_CAP");
        require(bytes(config.uri).length > 0, "DAOKIT: INVALID_URI");

        currency = config.currency;
        asset = config.asset;
        start = config.start;
        duration = config.duration;
        whitelistOnly = config.whitelistOnly;
        softCap = config.softCap;
        hardCap = config.hardCap;
        individualCap = config.individualCap;
        uri = config.uri;
        data = config.data;
    }

    /**
     * @notice Anyone can enroll by sending a certain `amount` of `currency` to this contract. If `whitelistOnly` is on,
     *  then only accounts in the whitelist can do it.
     */
    function enroll(uint128 amount) external payable notCancelled {
        if (whitelistOnly) {
            require(isWhitelisted[msg.sender], "DAOKIT: NOT_WHITELISTED");
        }
        _enroll(amount);
    }

    /**
     * @notice Anyone can enroll by sending a certain `amount` of `currency` to this contract.
     */
    function enroll(
        uint128 amount,
        bytes32 merkleRoot,
        bytes32[] calldata merkleProof
    ) external payable notCancelled {
        require(isValidMerkleRoot[merkleRoot], "DAOKIT: INVALID_ROOT");
        require(verify(merkleRoot, keccak256(abi.encodePacked(msg.sender)), merkleProof), "DAOKIT: INVALID_PROOF");

        _enroll(amount);
    }

    function _enroll(uint128 amount) internal virtual {
        require(amount > 0, "DAOKIT: INVALID_AMOUNT");
        require(start <= block.timestamp, "DAOKIT: NOT_STARTED");
        require(block.timestamp < start + duration, "DAOKIT: FINISHED");
        require(hardCap == 0 || totalAmount + amount <= hardCap, "DAOKIT: HARD_CAP_EXCEEDED");
        require(
            individualCap == 0 || _amounts[msg.sender] + amount <= individualCap,
            "DAOKIT: INDIVIDUAL_CAP_EXCEEDED"
        );

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
    function claim(uint256[] calldata enrollmentIds) external notCancelled afterFinished {
        require(softCap == 0 || softCap <= totalAmount, "DAOKIT: SOFT_CAP_NOT_REACHED");

        uint256[] memory tokenIds = new uint256[](enrollmentIds.length);
        uint256[] memory amounts = new uint256[](enrollmentIds.length);
        for (uint256 i; i < enrollmentIds.length; i++) {
            (uint256 tokenId, uint256 amount) = _claim(enrollmentIds[i]);
            tokenIds[i] = tokenId;
            amounts[i] = amount;
        }
        _offerAssets(msg.sender, tokenIds, amounts);
    }

    function _claim(uint256 id) internal virtual returns (uint256 tokenId, uint256 amount) {
        Enrollment storage e = enrollments[id];
        require(e.account == msg.sender, "DAOKIT: FORBIDDEN");
        require(!e.claimedOrRefunded, "DAOKIT: CLAIMED");
        e.claimedOrRefunded = true;

        (tokenId, amount) = _claimableAsset(e.amount, e.timestamp);
        emit Claim(id, msg.sender, tokenId, amount);
    }

    /**
     * @notice Enrolled users can get refunded with `enrollmentIds` if the IDO didn't finish  successfully, which means
     *  it didn't reach the soft cap.
     */
    function refund(uint256[] memory enrollmentIds) external notCancelled afterFinished {
        require(softCap > 0 && totalAmount < softCap, "DAOKIT: SOFT_CAP_REACHED");

        for (uint256 i; i < enrollmentIds.length; i++) {
            _refund(enrollmentIds[i]);
        }
    }

    function _refund(uint256 id) internal virtual {
        Enrollment storage e = enrollments[id];
        require(e.account == msg.sender, "DAOKIT: FORBIDDEN");
        require(!e.claimedOrRefunded, "DAOKIT: REFUNDED");
        e.claimedOrRefunded = true;

        uint128 _amount = e.amount;
        emit Refund(id, msg.sender, _amount);
        currency.safeTransfer(msg.sender, _amount);
    }

    /**
     * @notice Only `owner` can close the IDO after it finishes. If it was successful all the funds are sent to `owner,
     *  otherwise all `asset`s are returned to the `owner`.
     */
    function close(uint256[] memory tokenIds) external onlyOwner notCancelled afterFinished {
        require(!closed, "DAOKIT: CLOSED");

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
