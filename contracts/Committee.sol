// SPDX-License-Identifier: WTFPL

pragma solidity 0.8.12;

import "./libraries/EIP712s.sol";
import "./libraries/Signatures.sol";
import "./CommitteeGovernance.sol";

contract Committee is CommitteeGovernance {
    // keccak256("ExecuteTransactions(address[] target,uint256[] value,string[] signature,bytes[] data)");
    bytes32 public constant EXECUTE_TRANSACTIONS_TYPEHASH =
        0x856020ab5d9b506b35ac81d891a98f181668092deb245ac5cad22f698bdfa391;

    uint256 internal immutable _CACHED_CHAIN_ID;
    bytes32 internal immutable _DOMAIN_SEPARATOR;

    event ExecuteTransaction(
        bytes32 indexed txHash,
        address indexed target,
        uint256 value,
        string signature,
        bytes data
    );

    constructor(
        address _tokenAddress,
        uint128 _proposalQuorumMin,
        uint128 _proposalVotesMin,
        uint128 _committeeQuorum,
        address[] memory _committeeMembers
    ) CommitteeGovernance(_tokenAddress, _proposalQuorumMin, _proposalVotesMin, _committeeQuorum) {
        _CACHED_CHAIN_ID = block.chainid;
        _DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                // keccak256('EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)')
                0x8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f,
                keccak256(bytes(Strings.toHexString(uint160(address(this))))),
                0xc89efdaa54c0f20c7adf612882df0950f5a951637e0307cdcb4c672f298b8bc6, // keccak256(bytes("1"))
                block.chainid,
                address(this)
            )
        );
    }

    function DOMAIN_SEPARATOR() public view returns (bytes32) {
        bytes32 domainSeparator;
        if (_CACHED_CHAIN_ID == block.chainid) domainSeparator = _DOMAIN_SEPARATOR;
        else {
            domainSeparator = keccak256(
                abi.encode(
                    // keccak256('EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)')
                    0x8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f,
                    keccak256(bytes(Strings.toHexString(uint160(address(this))))),
                    0xc89efdaa54c0f20c7adf612882df0950f5a951637e0307cdcb4c672f298b8bc6, // keccak256(bytes("1"))
                    block.chainid,
                    address(this)
                )
            );
        }
        return domainSeparator;
    }

    function executeTransactions(
        address[] memory target,
        uint256[] memory value,
        string[] memory signature,
        bytes[] memory data,
        address[] memory signers,
        Signatures.Signature[] memory signatures
    ) external quorumReached(committeeMembers.length, committeeQuorum, uint128(signatures.length)) {
        bytes32 hash = keccak256(
            abi.encode(
                EXECUTE_TRANSACTIONS_TYPEHASH,
                keccak256(abi.encodePacked(target)),
                keccak256(abi.encodePacked(value)),
                EIP712s.hashStringArray(signature),
                EIP712s.hashBytesArray(data)
            )
        );
        _verifySigners(signers);
        Signatures.verifySignatures(DOMAIN_SEPARATOR(), hash, signers, signatures);

        for (uint256 i; i < target.length; i++) {
            require(target != address(this), "DAOKIT: INVALID_TARGET");

            bytes memory callData;
            if (bytes(signature[i]).length == 0) {
                callData = data;
            } else {
                callData = abi.encodePacked(bytes4(keccak256(bytes(signature[i]))), data[i]);
            }

            (bool success, bytes memory returnData) = target.call{value: value[i]}(callData);
            require(success, "DAOKIT: TRANSACTION_REVERTED");

            emit ExecuteTransaction(txHash, target, value, signature, data);
        }
    }
}
