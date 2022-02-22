// SPDX-License-Identifier: WTFPL

pragma solidity 0.8.12;

import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";

library Signatures {
    struct Signature {
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    function verifySignatures(
        bytes32 domainSeparator,
        bytes32 hash,
        address[] memory signers,
        Signature[] memory signatures
    ) internal view {
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, hash));

        for (uint256 i; i < signers.length; i++) {
            address signer = signers[i];
            bytes memory sig = abi.encodePacked(signatures[i].r, signatures[i].s, signatures[i].v);
            require(SignatureChecker.isValidSignatureNow(signer, digest, sig), "DAOKIT: INVALID_SIGNATURE");
        }
    }
}
