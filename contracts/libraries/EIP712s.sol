// SPDX-License-Identifier: WTFPL

pragma solidity 0.8.12;

library EIP712s {
    function hashStringArray(string[] memory array) internal pure returns (bytes32) {
        bytes32[] memory hashes = new bytes32[](array.length);
        for (uint256 i; i < array.length; i++) {
            hashes[i] = keccak256(abi.encodePacked(array[i]));
        }
        return keccak256(abi.encodePacked(hashes));
    }

    function hashBytesArray(bytes[] memory array) internal pure returns (bytes32) {
        bytes32[] memory hashes = new bytes32[](array.length);
        for (uint256 i; i < array.length; i++) {
            hashes[i] = keccak256(abi.encodePacked(array[i]));
        }
        return keccak256(abi.encodePacked(hashes));
    }
}
