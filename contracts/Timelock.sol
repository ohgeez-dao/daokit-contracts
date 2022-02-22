// SPDX-License-Identifier: WTFPL

pragma solidity 0.8.12;

contract Timelock {
    uint64 public constant GRACE_PERIOD = 14 days;
    uint64 public constant MINIMUM_DELAY = 1 days;
    uint64 public constant MAXIMUM_DELAY = 30 days;

    uint64 public delay;
    mapping(bytes32 => bool) public queuedTransactions;

    event NewDelay(uint64 indexed newDelay);
    event CancelTransaction(
        bytes32 indexed txHash,
        address indexed target,
        uint256 value,
        string signature,
        bytes data,
        uint64 eta
    );
    event ExecuteTransaction(
        bytes32 indexed txHash,
        address indexed target,
        uint256 value,
        string signature,
        bytes data,
        uint64 eta
    );
    event QueueTransaction(
        bytes32 indexed txHash,
        address indexed target,
        uint256 value,
        string signature,
        bytes data,
        uint64 eta
    );

    constructor(uint64 _delay) {
        require(_delay >= MINIMUM_DELAY, "DAOKIT: DELAY_TOO_SHORT");
        require(_delay <= MAXIMUM_DELAY, "DAOKIT: DELAY_TOO_LONG");

        delay = _delay;
    }

    function _setDelay(uint64 _delay) internal {
        require(_delay >= MINIMUM_DELAY, "DAOKIT: DELAY_TOO_SHORT");
        require(_delay <= MAXIMUM_DELAY, "DAOKIT: DELAY_TOO_LONG");
        delay = _delay;

        emit NewDelay(delay);
    }

    function _queueTransaction(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint64 eta
    ) internal virtual returns (bytes32) {
        require(eta >= block.timestamp + delay, "DAOKIT: INVALID_ETA");

        bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));
        queuedTransactions[txHash] = true;

        emit QueueTransaction(txHash, target, value, signature, data, eta);
        return txHash;
    }

    function _cancelTransaction(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint64 eta
    ) internal virtual {
        bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));
        queuedTransactions[txHash] = false;

        emit CancelTransaction(txHash, target, value, signature, data, eta);
    }

    function _executeTransaction(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint64 eta
    ) internal virtual returns (bytes memory) {
        bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));
        require(queuedTransactions[txHash], "DAOKIT: INVALID_TRANSACTION");

        queuedTransactions[txHash] = false;

        bytes memory callData;
        if (bytes(signature).length == 0) {
            callData = data;
        } else {
            callData = abi.encodePacked(bytes4(keccak256(bytes(signature))), data);
        }

        (bool success, bytes memory returnData) = target.call{value: value}(callData);
        require(success, "DAOKIT: TRANSACTION_REVERTED");

        emit ExecuteTransaction(txHash, target, value, signature, data, eta);

        return returnData;
    }
}
