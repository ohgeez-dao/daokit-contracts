// SPDX-License-Identifier: WTFPL

pragma solidity 0.8.12;

import "./libraries/EIP712s.sol";
import "./libraries/Signatures.sol";
import "./Timelock.sol";
import "./MultiSigGovernance.sol";

contract CoreTeam is Timelock, MultiSigGovernance {
    // keccak256("QueueTransactions(address[] target,uint256[] value,string[] signature,bytes[] data,uint64[] eta)");
    bytes32 public constant QUEUE_TRANSACTIONS_TYPEHASH =
        0xb4c35086675bb65432758e1391df7d84e686ccfdfa7e7be39250320aa1a67355;
    // keccak256("CancelTransactions(address[] target,uint256[] value,string[] signature,bytes[] data,uint64[] eta)");
    bytes32 public constant CANCEL_TRANSACTIONS_TYPEHASH =
        0xfb3dc1e5b5409e1cc1de0693d7ee84a4f7d85a5192bf0cb142f4652689f838b7;

    modifier calledBySelf {
        require(msg.sender == address(this), "DAOKIT: FORBIDDEN");
        _;
    }

    constructor(
        uint64 _delay,
        address[] memory _members,
        uint128 _required
    ) Timelock(_delay) MultiSigGovernance(members, _required) {
        // Empty
    }

    /**
     * @notice This function needs to be called by itself, which means it needs to be done by `queueTransactions()` and
     * `executeTransactions()` with this address as `target`
     */
    function addMember(address member) external calledBySelf {
        _addMember(member);
    }

    /**
     * @notice This function needs to be called by itself, which means it needs to be done by `queueTransactions()` and
     * `executeTransactions()` with this address as `target`
     */
    function removeMember(address member) external calledBySelf {
        _removeMember(member);
    }

    /**
     * @notice This function needs to be called by itself, which means it needs to be done by `queueTransactions()` and
     * `executeTransactions()` with this address as `target`
     */
    function changeRequirement(uint128 _required) external calledBySelf {
        _changeRequirement(_required);
    }

    /**
     * @notice Core team can call this to queue multiple transactions with a number of signatures higher than quorum
     */
    function queueTransactions(
        address[] memory target,
        uint256[] memory value,
        string[] memory signature,
        bytes[] memory data,
        uint64[] memory eta,
        address[] memory signers,
        Signatures.Signature[] memory signatures
    ) external requirementMet(uint128(signatures.length)) {
        bytes32 hash = keccak256(
            abi.encode(
                QUEUE_TRANSACTIONS_TYPEHASH,
                keccak256(abi.encodePacked(target)),
                keccak256(abi.encodePacked(value)),
                EIP712s.hashStringArray(signature),
                EIP712s.hashBytesArray(data),
                keccak256(abi.encodePacked(eta))
            )
        );
        _verifySignatures(hash, signers, signatures);

        for (uint256 i; i < target.length; i++) {
            _queueTransaction(target[i], value[i], signature[i], data[i], eta[i]);
        }
    }

    /**
     * @notice Core team can call this to cancel multiple transactions with a number of signatures higher than quorum
     */
    function cancelTransactions(
        address[] memory target,
        uint256[] memory value,
        string[] memory signature,
        bytes[] memory data,
        uint64[] memory eta,
        address[] memory signers,
        Signatures.Signature[] memory signatures
    ) external requirementMet(uint128(signatures.length)) {
        bytes32 hash = keccak256(
            abi.encode(
                CANCEL_TRANSACTIONS_TYPEHASH,
                keccak256(abi.encodePacked(target)),
                keccak256(abi.encodePacked(value)),
                EIP712s.hashStringArray(signature),
                EIP712s.hashBytesArray(data),
                keccak256(abi.encodePacked(eta))
            )
        );
        _verifySignatures(hash, signers, signatures);

        for (uint256 i; i < target.length; i++) {
            _cancelTransaction(target[i], value[i], signature[i], data[i], eta[i]);
        }
    }

    /**
     * @notice Anyone can call this to execute queued transactions that passed their eta
     */
    function executeTransactions(
        address[] memory target,
        uint256[] memory value,
        string[] memory signature,
        bytes[] memory data,
        uint64[] memory eta
    ) external {
        for (uint256 i; i < target.length; i++) {
            _executeTransaction(target[i], value[i], signature[i], data[i], eta[i]);
        }
    }
}
