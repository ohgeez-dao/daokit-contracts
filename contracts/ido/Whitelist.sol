// SPDX-License-Identifier: WTFPL

pragma solidity 0.8.12;

import "./MerkleProof.sol";

abstract contract Whitelist is MerkleProof {
    mapping(address => bool) public isWhitelisted;
    mapping(bytes32 => bool) public isValidMerkleRoot;

    event AddToWhitelist(address indexed account);
    event RemoveFromWhitelist(address indexed account);
    event AddMerkleRoot(bytes32 indexed merkleRoot);
    event RemoveMerkleRoot(bytes32 indexed merkleRoot);

    function _addToWhitelist() internal {
        isWhitelisted[msg.sender] = true;

        emit AddToWhitelist(msg.sender);
    }

    function _removeFromWhitelist() internal {
        isWhitelisted[msg.sender] = false;

        emit RemoveFromWhitelist(msg.sender);
    }

    function _addMerkleRoot(bytes32 merkleRoot) internal {
        isValidMerkleRoot[merkleRoot] = true;

        emit AddMerkleRoot(merkleRoot);
    }

    function _removeMerkleRoot(bytes32 merkleRoot) internal {
        isValidMerkleRoot[merkleRoot] = false;

        emit RemoveMerkleRoot(merkleRoot);
    }
}
