// SPDX-License-Identifier: WTFPL

pragma solidity 0.8.12;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./libraries/FungibleTokens.sol";

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
    mapping(address => Enrollment) public enrollment;
    uint256 public totalAmount;
    bool public cancelled;
    bool public closed;

    modifier notCancelled {
        require(!cancelled, "DAOKIT: CANCELLED");
        _;
    }

    struct Enrollment {
        uint256 amount;
        uint64 lastTimestamp;
        bool withdrawnOrRefunded;
    }

    event Cancel(address to);
    event AddToWhitelist(address indexed account);
    event RemoveFromWhitelist(address indexed account);
    event Enroll(address indexed account, uint256 amount);
    event Withdraw(address indexed account, uint256 tokenId, uint256 amount);
    event Refund(address indexed account, uint256 amount);
    event Close(address to);

    constructor(
        address _owner,
        address _currency,
        address _asset,
        uint64 _start,
        uint64 _duration,
        bool _whitelistOnly,
        uint256 _softCap,
        uint256 _hardCap,
        uint256 _individualCap,
        string memory _uri
    ) {
        _transferOwnership(_owner);
        _updateParams(_currency, _asset, _start, _duration, _whitelistOnly, _softCap, _hardCap, _individualCap, _uri);
    }

    function getExchangeInfo(uint256 amount, uint64 lastTimestamp)
        public
        view
        virtual
        returns (uint256 tokenIdAsset, uint256 amountAsset);

    /**
     * @notice This is called when the `asset` is initially offered to `to` address for a given `tokenId` and `amount`
     * only if the IDO was successful, when `totalAmount` > `hardCap`.
     */
    function _offerAsset(
        address to,
        uint256 tokenId,
        uint256 amount
    ) internal virtual;

    /**
     * @notice This is called when the IDO was `cancelled` or `closed` so that assets need to be returned
     */
    function _returnAssets(address to) internal virtual;

    function cancel(address to) external onlyOwner {
        require(!cancelled, "DAOKIT: CANCELLED");
        require(block.timestamp < start, "DAOKIT: STARTED");

        cancelled = true;
        emit Cancel(to);
        _returnAssets(to);
    }

    function updateParams(
        address _currency,
        address _asset,
        uint64 _start,
        uint64 _duration,
        bool _whitelistOnly,
        uint256 _softCap,
        uint256 _hardCap,
        uint256 _individualCap,
        string memory _uri
    ) public onlyOwner notCancelled {
        require(block.timestamp < start, "DAOKIT: STARTED");

        _updateParams(_currency, _asset, _start, _duration, _whitelistOnly, _softCap, _hardCap, _individualCap, _uri);
    }

    function _updateParams(
        address _currency,
        address _asset,
        uint64 _start,
        uint64 _duration,
        bool _whitelistOnly,
        uint256 _softCap,
        uint256 _hardCap,
        uint256 _individualCap,
        string memory _uri
    ) internal {
        require(_asset != address(0), "DAOKIT: INVALID_ASSET");
        require(block.timestamp < _start, "DAOKIT: INVALID_START");
        require(_duration > 0, "DAOKIT: INVALID_START");
        if (_hardCap > 0) {
            require(_softCap < _hardCap, "DAOKIT: INVALID_HARD_CAP");
        }
        require(bytes(_uri).length > 0, "DAOKIT: INVALID_URI");

        currency = _currency;
        asset = _asset;
        start = _start;
        duration = _duration;
        whitelistOnly = _whitelistOnly;
        softCap = _softCap;
        hardCap = _hardCap;
        individualCap = _individualCap;
        uri = _uri;
    }

    function addToWhitelist() external notCancelled {
        isWhitelisted[msg.sender] = true;

        emit AddToWhitelist(msg.sender);
    }

    function removeFromWhitelist() external notCancelled {
        isWhitelisted[msg.sender] = false;

        emit RemoveFromWhitelist(msg.sender);
    }

    function enroll(uint256 amount) external payable notCancelled {
        require(start <= block.timestamp, "DAOKIT: NOT_STARTED");
        require(block.timestamp < start + duration, "DAOKIT: FINISHED");
        if (whitelistOnly) {
            require(isWhitelisted[msg.sender], "DAOKIT: NOT_WHITELISTED");
        }
        if (hardCap > 0) {
            require(totalAmount + amount <= hardCap, "DAOKIT: HARD_CAP_EXCEEDED");
        }

        Enrollment storage e = enrollment[msg.sender];
        if (individualCap > 0) {
            require(e.amount + amount <= individualCap, "DAOKIT: INDIVIDUAL_CAP_EXCEEDED");
        }
        e.amount += amount;
        e.lastTimestamp = uint64(block.timestamp);
        totalAmount += amount;

        emit Enroll(msg.sender, amount);
        currency.safeTransferFrom(msg.sender, address(this), amount);
    }

    function withdraw() external notCancelled {
        require(start + duration <= block.timestamp, "DAOKIT: NOT_FINISHED");
        require(softCap <= totalAmount, "DAOKIT: SOFT_CAP_NOT_REACHED");

        Enrollment storage e = enrollment[msg.sender];
        require(e.amount > 0, "DAOKIT: NOT_ENROLLED");
        require(!e.withdrawnOrRefunded, "DAOKIT: WITHDRAWN");

        (uint256 tokenIdAsset, uint256 amountAsset) = getExchangeInfo(e.amount, e.lastTimestamp);
        emit Withdraw(msg.sender, tokenIdAsset, amountAsset);
        _offerAsset(msg.sender, tokenIdAsset, amountAsset);
    }

    function refund() external notCancelled {
        require(start + duration <= block.timestamp, "DAOKIT: NOT_FINISHED");
        require(totalAmount < softCap, "DAOKIT: SOFT_CAP_EXCEEDED");

        Enrollment storage e = enrollment[msg.sender];
        require(e.amount > 0, "DAOKIT: NOT_ENROLLED");
        require(!e.withdrawnOrRefunded, "DAOKIT: REFUNDED");

        uint256 _amount = e.amount;
        emit Refund(msg.sender, _amount);
        currency.safeTransfer(msg.sender, _amount);
    }

    function close(address to) external onlyOwner notCancelled {
        require(!closed, "DAOKIT: CLOSED");
        require(start + duration <= block.timestamp, "DAOKIT: NOT_FINISHED");

        closed = true;
        emit Close(to);
        if (totalAmount < softCap) {
            _returnAssets(to);
        } else {
            address _currency = currency;
            _currency.safeTransferFrom(address(this), to, _currency.balanceOf(address(this)));
        }
    }
}
