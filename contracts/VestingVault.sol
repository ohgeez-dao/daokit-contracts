// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (finance/VestingWallet.sol)
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract VestingVault is Ownable {
    using SafeERC20 for IERC20;

    event Create(
        uint256 indexed id,
        address indexed beneficiary,
        address indexed token,
        uint256 allocation,
        uint64 start,
        uint64 duration
    );
    event Cancel(uint256 indexed id, address indexed remainderRecipient, uint256 remainder);
    event Release(uint256 indexed id, uint256 amount);

    struct Vesting {
        bool cancelled;
        address beneficiary;
        address token;
        uint64 start;
        uint64 duration;
        uint256 allocation;
        uint256 released;
    }

    Vesting[] public vesting;

    constructor(address owner) {
        _transferOwnership(owner);
    }

    /**
     * @notice Calculates the amount of tokens that has already vested. Default implementation is a linear vesting curve.
     */
    function vestedAmount(uint256 id, uint64 timestamp) public view returns (uint256) {
        Vesting storage v = vesting[id];
        return _vestedAmount(v, timestamp);
    }

    function _vestedAmount(Vesting storage v, uint64 timestamp) internal view returns (uint256) {
        (uint64 _start, uint64 _duration) = (v.start, v.duration);
        if (timestamp < _start) {
            return 0;
        } else if (timestamp > _start + _duration) {
            return v.allocation;
        } else {
            return (v.allocation * (timestamp - _start)) / _duration;
        }
    }

    /**
     * @notice Create a vesting with owner, beneficiary, token, allocation, start timestamp and duration.
     */
    function create(
        address owner,
        address beneficiaryAddress,
        address tokenAddress,
        uint256 totalAllocation,
        uint64 startTimestamp,
        uint64 durationSeconds
    ) external payable onlyOwner returns (uint256 id) {
        require(owner != address(0), "DAOKIT: INVALID_OWNER");
        require(beneficiaryAddress != address(0), "DAOKIT: INVALID_BENEFICIARY");

        id = vesting.length;
        Vesting storage v = vesting.push();
        v.beneficiary = beneficiaryAddress;
        v.token = tokenAddress;
        v.allocation = totalAllocation;
        v.start = startTimestamp;
        v.duration = durationSeconds;

        emit Create(id, beneficiaryAddress, tokenAddress, totalAllocation, startTimestamp, durationSeconds);

        if (tokenAddress == address(0)) {
            require(msg.value == totalAllocation, "DAOKIT: INVALID_ALLOCATION");
        } else {
            IERC20(tokenAddress).safeTransferFrom(msg.sender, address(this), totalAllocation);
        }
    }

    /**
     * @notice Cancel an ongoing vesting with the vested amount sent to beneficiary and the rest to `remainderRecipient`
     */
    function cancel(uint256 id, address remainderRecipient) external onlyOwner {
        Vesting storage v = vesting[id];
        uint256 amount = _tryRelease(v);
        emit Release(id, amount);

        uint256 remainder = v.allocation - v.released;
        emit Cancel(id, remainderRecipient, remainder);

        v.cancelled = true;
        _transfer(v.token, remainderRecipient, remainder);
    }

    /**
     * @notice Release the token that have already vested.
     */
    function release(uint256 id) public returns (uint256 amount) {
        Vesting storage v = vesting[id];
        amount = _tryRelease(v);
        emit Release(id, amount);
        require(amount > 0, "DAOKIT: UNABLE_TO_RELEASE");
    }

    function _tryRelease(Vesting storage v) internal returns (uint256 amount) {
        require(!v.cancelled, "DAOKIT: CANCELLED");

        amount = _vestedAmount(v, uint64(block.timestamp)) - v.released;
        if (amount > 0) {
            v.released += amount;
            _transfer(v.token, v.beneficiary, amount);
        }
    }

    function _transfer(
        address token,
        address to,
        uint256 amount
    ) internal {
        if (token == address(0)) {
            Address.sendValue(payable(to), amount);
        } else {
            IERC20(token).safeTransfer(to, amount);
        }
    }
}
