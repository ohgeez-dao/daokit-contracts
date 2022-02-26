// SPDX-License-Identifier: WTFPL

pragma solidity 0.8.12;

import "@openzeppelin/contracts/access/Ownable.sol";

abstract contract IDO is Ownable {
    address public currency;
    address public asset;
    uint64 public start;
    uint64 public duration;
    bool public whitelistOnly;
    uint256 public tokenIdCurrency;
    uint256 public softCap;
    uint256 public hardCap;
    uint256 public individualCap;
    string public uri;
    bool public cancelled;

    mapping(address => bool) public isWhitelisted;

    mapping(address => Enrollment) public enrollment;
    uint256 public totalAmount;

    modifier notCancelled {
        require(!cancelled, "DAOKIT: CANCELLED");
        _;
    }

    struct Enrollment {
        uint256 amount;
        uint64 lastTimestamp;
        bool withdrawnOrRefunded;
    }

    event Cancel();
    event AddToWhitelist(address indexed account);
    event RemoveFromWhitelist(address indexed account);
    event Enroll(address indexed account, uint256 amount);
    event Withdraw(address indexed account, uint256 tokenId, uint256 amount);
    event Refund(address indexed account, uint256 amount);
    event Adjust();

    constructor(
        address _owner,
        address _currency,
        address _asset,
        uint64 _start,
        uint64 _duration,
        bool _whitelistOnly,
        uint256 _tokenId,
        uint256 _softCap,
        uint256 _hardCap,
        uint256 _individualCap,
        string memory _uri
    ) {
        _transferOwnership(_owner);
        _updateParams(
            _currency,
            _asset,
            _start,
            _duration,
            _whitelistOnly,
            _tokenId,
            _softCap,
            _hardCap,
            _individualCap,
            _uri
        );
    }

    function getExchangeInfo(uint256 amount, uint64 lastTimestamp)
        public
        view
        virtual
        returns (uint256 tokenIdAsset, uint256 amountAsset);

    function _transferCurrency(
        address from,
        address to,
        uint256 tokenId,
        uint256 amount
    ) internal virtual;

    function _transferAsset(
        address from,
        address to,
        uint256 tokenId,
        uint256 amount
    ) internal virtual;

    function _withdrawCurrency() internal virtual;

    function _withdrawAsset() internal virtual;

    function cancel() external onlyOwner {
        require(!cancelled, "DAOKIT: CANCELLED");
        require(block.timestamp < start, "DAOKIT: STARTED");

        cancelled = true;
        emit Cancel();
        _withdrawAsset();
    }

    function updateParams(
        address _currency,
        address _asset,
        uint64 _start,
        uint64 _duration,
        bool _whitelistOnly,
        uint256 _tokenId,
        uint256 _softCap,
        uint256 _hardCap,
        uint256 _individualCap,
        string memory _uri
    ) public onlyOwner notCancelled {
        require(block.timestamp < start, "DAOKIT: STARTED");

        _updateParams(
            _currency,
            _asset,
            _start,
            _duration,
            _whitelistOnly,
            _tokenId,
            _softCap,
            _hardCap,
            _individualCap,
            _uri
        );
    }

    function _updateParams(
        address _currency,
        address _asset,
        uint64 _start,
        uint64 _duration,
        bool _whitelistOnly,
        uint256 _tokenIdCurrency,
        uint256 _softCap,
        uint256 _hardCap,
        uint256 _individualCap,
        string memory _uri
    ) internal {
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
        tokenIdCurrency = _tokenIdCurrency;
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
        _transferCurrency(msg.sender, address(this), tokenIdCurrency, amount);
    }

    function withdraw() external notCancelled {
        require(start + duration <= block.timestamp, "DAOKIT: NOT_FINISHED");
        require(softCap <= totalAmount, "DAOKIT: SOFT_CAP_NOT_REACHED");

        Enrollment storage e = enrollment[msg.sender];
        require(e.amount > 0, "DAOKIT: NOT_ENROLLED");
        require(!e.withdrawnOrRefunded, "DAOKIT: WITHDRAWN");

        (uint256 tokenIdAsset, uint256 amountAsset) = getExchangeInfo(e.amount, e.lastTimestamp);
        emit Withdraw(msg.sender, tokenIdAsset, amountAsset);
        _transferAsset(address(this), msg.sender, tokenIdAsset, amountAsset);
    }

    function refund() external notCancelled {
        require(start + duration <= block.timestamp, "DAOKIT: NOT_FINISHED");
        require(totalAmount < softCap, "DAOKIT: SOFT_CAP_EXCEEDED");

        Enrollment storage e = enrollment[msg.sender];
        require(e.amount > 0, "DAOKIT: NOT_ENROLLED");
        require(!e.withdrawnOrRefunded, "DAOKIT: REFUNDED");

        uint256 _amount = e.amount;
        emit Refund(msg.sender, _amount);
        _transferCurrency(address(this), msg.sender, tokenIdCurrency, _amount);
    }

    function adjust() external onlyOwner notCancelled {
        require(start + duration <= block.timestamp, "DAOKIT: NOT_FINISHED");

        emit Adjust();
        if (totalAmount < softCap) {
            _withdrawAsset(); // TODO
        } else {
            _withdrawCurrency(); // TODO
        }
    }
}
