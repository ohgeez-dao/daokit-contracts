// SPDX-License-Identifier: WTFPL

pragma solidity 0.8.12;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./libraries/FungibleTokens.sol";
import "./Whitelist.sol";

/**
 * @notice Base IDO contract to support various asset standards (ERC20, ERC721, ERC1155 and more).
 */
abstract contract BaseIDO is Ownable, Whitelist {
    using SafeERC20 for IERC20;
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
     * @notice If this sets to true, only whitelisted accounts can call `bid()`
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
     * @notice Additional params used for inheriting contracts
     */
    bytes public params;

    BidInfo[] public bids;
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
        bytes params;
    }

    struct BidInfo {
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
        require(!started(), "DAOKIT: STARTED");
        _;
    }

    modifier afterFinished {
        require(finished(), "DAOKIT: NOT_FINISHED");
        _;
    }

    event Cancel();
    event Bid(uint256 id, address indexed account, uint128 amount);
    event Claim(uint256 id, address indexed account, uint256 tokenId, uint256 amount);
    event Refund(uint256 id, address indexed account, uint128 amount);
    event Close();

    constructor(address _owner, Config memory config) {
        _transferOwnership(_owner);
        _updateConfig(config);
    }

    function started() public view virtual returns (bool) {
        return start <= block.timestamp;
    }

    function expired() public view virtual returns (bool) {
        return start + duration <= block.timestamp;
    }

    function finished() public view virtual returns (bool) {
        return expired() || (hardCap > 0 && hardCap <= totalAmount);
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
     * @notice This should return the tokenId and amount that can be claimed for `bidAmount` at `timestamp`
     */
    function _claimableAsset(uint128 bidAmount, uint64 timestamp)
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
        params = config.params;
    }

    /**
     * @notice Anyone can bid by sending a certain `amount` of `currency` to this contract. If `whitelistOnly` is on,
     *  then only accounts in the whitelist can do it.
     */
    function bid(uint128 amount) external payable notCancelled {
        if (whitelistOnly) {
            require(isWhitelisted[msg.sender], "DAOKIT: NOT_WHITELISTED");
        }
        _bid(amount);
    }

    /**
     * @notice Anyone can bid by sending a certain `amount` of `currency` to this contract.
     */
    function bid(
        uint128 amount,
        bytes32 merkleRoot,
        bytes32[] calldata merkleProof
    ) external payable notCancelled {
        require(isValidMerkleRoot[merkleRoot], "DAOKIT: INVALID_ROOT");
        require(verify(merkleRoot, keccak256(abi.encodePacked(msg.sender)), merkleProof), "DAOKIT: INVALID_PROOF");

        _bid(amount);
    }

    function _bid(uint128 amount) internal virtual {
        require(amount > 0, "DAOKIT: INVALID_AMOUNT");
        require(started(), "DAOKIT: NOT_STARTED");
        require(!finished(), "DAOKIT: FINISHED");

        uint128 amountAvailable = _amountAvailable(msg.sender, amount);

        uint256 id = bids.length;
        BidInfo storage info = bids.push();
        info.amount = amountAvailable;
        info.account = msg.sender;
        info.timestamp = uint64(block.timestamp);

        totalAmount += amountAvailable;
        _amounts[msg.sender] += amountAvailable;

        emit Bid(id, msg.sender, amountAvailable);

        address _currency = currency;
        if (_currency == address(0)) {
            require(amountAvailable <= msg.value, "DAOKIT: INSUFFICIENT_ETH");
            if (amountAvailable < msg.value) {
                Address.sendValue(payable(msg.sender), msg.value - amountAvailable);
            }
        } else {
            IERC20(_currency).safeTransferFrom(msg.sender, address(this), amountAvailable);
        }
    }

    function _amountAvailable(address account, uint128 amount) internal view virtual returns (uint128) {
        uint128 lastAmount = _amounts[account];
        if (individualCap > 0 && individualCap < lastAmount + amount) {
            return individualCap - lastAmount;
        }
        return amount;
    }

    /**
     * @notice Users who bid can claim their `asset`s that correspond to `bidIds` if the IDO finished
     *  successfully, which means it reached the soft cap if it exists.
     */
    function claim(uint256[] calldata bidIds) external notCancelled afterFinished {
        require(softCap == 0 || softCap <= totalAmount, "DAOKIT: SOFT_CAP_NOT_REACHED");

        uint256[] memory tokenIds = new uint256[](bidIds.length);
        uint256[] memory amounts = new uint256[](bidIds.length);
        for (uint256 i; i < bidIds.length; i++) {
            (uint256 tokenId, uint256 amount) = _claim(bidIds[i]);
            tokenIds[i] = tokenId;
            amounts[i] = amount;
        }
        _offerAssets(msg.sender, tokenIds, amounts);
    }

    function _claim(uint256 id) internal virtual returns (uint256 tokenId, uint256 amount) {
        BidInfo storage info = bids[id];
        require(info.account == msg.sender, "DAOKIT: FORBIDDEN");
        require(!info.claimedOrRefunded, "DAOKIT: CLAIMED");
        info.claimedOrRefunded = true;

        (tokenId, amount) = _claimableAsset(info.amount, info.timestamp);
        emit Claim(id, msg.sender, tokenId, amount);
    }

    /**
     * @notice Users who bid can get refunded with `bidIds` if the IDO didn't finish  successfully, which means
     *  it didn't reach the soft cap.
     */
    function refund(uint256[] memory bidIds) external notCancelled afterFinished {
        require(softCap > 0 && totalAmount < softCap, "DAOKIT: SOFT_CAP_REACHED");

        for (uint256 i; i < bidIds.length; i++) {
            _refund(bidIds[i]);
        }
    }

    function _refund(uint256 id) internal virtual {
        BidInfo storage info = bids[id];
        require(info.account == msg.sender, "DAOKIT: FORBIDDEN");
        require(!info.claimedOrRefunded, "DAOKIT: REFUNDED");
        info.claimedOrRefunded = true;

        uint128 _amount = info.amount;
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
