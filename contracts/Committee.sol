// SPDX-License-Identifier: WTFPL

pragma solidity 0.8.12;

import "./libraries/EIP712s.sol";
import "./libraries/Signatures.sol";
import "./VotingGovernance.sol";
import "./MultiSigGovernance.sol";

contract Committee is VotingGovernance, MultiSigGovernance {
    // keccak256("ExecuteTransactions(address[] target,uint256[] value,string[] signature,bytes[] data)");
    bytes32 public constant EXECUTE_TRANSACTIONS_TYPEHASH =
        0x856020ab5d9b506b35ac81d891a98f181668092deb245ac5cad22f698bdfa391;

    event ExecuteTransaction(address indexed target, uint256 value, string signature, bytes data);

    modifier calledBySelf {
        require(msg.sender == address(this), "DAOKIT: FORBIDDEN");
        _;
    }

    constructor(
        address _tokenAddress,
        uint128 _quorumMin,
        uint128 _votesMin,
        address[] memory _members,
        uint128 _required
    ) VotingGovernance(_tokenAddress, _quorumMin, _votesMin) MultiSigGovernance(members, _required) {
        // Empty
    }

    /**
     * @notice This function needs to be called by itself, which means it needs to be done by `submitProposal()` and
     * `executeProposal()`
     */
    function addMember(address member) external calledBySelf {
        _addMember(member);
    }

    /**
     * @notice This function needs to be called by itself, which means it needs to be done by `submitProposal()` and
     * `executeProposal()`
     */
    function removeMember(address member) external calledBySelf {
        _removeMember(member);
    }

    /**
     * @notice This function needs to be called by itself, which means it needs to be done by `submitProposal()` and
     * `executeProposal()`
     */
    function changeRequirement(uint128 _required) external calledBySelf {
        _changeRequirement(_required);
    }

    function executeTransactions(
        address[] memory target,
        uint256[] memory value,
        string[] memory signature,
        bytes[] memory data,
        address[] memory signers,
        Signatures.Signature[] memory signatures
    ) external requirementMet(uint128(signatures.length)) {
        bytes32 hash = keccak256(
            abi.encode(
                EXECUTE_TRANSACTIONS_TYPEHASH,
                keccak256(abi.encodePacked(target)),
                keccak256(abi.encodePacked(value)),
                EIP712s.hashStringArray(signature),
                EIP712s.hashBytesArray(data)
            )
        );
        _verifySignatures(hash, signers, signatures);

        for (uint256 i; i < target.length; i++) {
            require(target[i] != address(this), "DAOKIT: INVALID_TARGET");

            bytes memory callData;
            if (bytes(signature[i]).length == 0) {
                callData = data[i];
            } else {
                callData = abi.encodePacked(bytes4(keccak256(bytes(signature[i]))), data[i]);
            }

            (bool success, ) = target[i].call{value: value[i]}(callData);
            require(success, "DAOKIT: TRANSACTION_REVERTED");

            emit ExecuteTransaction(target[i], value[i], signature[i], data[i]);
        }
    }
}
