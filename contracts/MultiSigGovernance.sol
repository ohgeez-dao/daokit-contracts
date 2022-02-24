// SPDX-License-Identifier: WTFPL

pragma solidity 0.8.12;

import "./libraries/Signatures.sol";

abstract contract MultiSigGovernance {
    uint256 internal immutable _CACHED_CHAIN_ID;
    bytes32 internal immutable _DOMAIN_SEPARATOR;

    mapping(address => bool) public isMember;
    address[] public members;
    uint128 public required;

    mapping(address => bool) internal _duplicate;

    event AddMember(address indexed member);
    event RemoveMember(address indexed member);
    event ChangeRequirement(uint128 required);

    modifier requirementMet(uint128 signatures) {
        require(
            (members.length < required && members.length == signatures) || (required != 0 && required <= signatures),
            "DAOKIT: REQUIREMENT_NOT_MET"
        );
        _;
    }

    constructor(address[] memory _members, uint128 _required) {
        required = _required;
        for (uint256 i; i < _members.length; i++) {
            address member = _members[i];
            isMember[member] = true;
            members.push(member);

            emit AddMember(member);
        }

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

    function membersLength() external view returns (uint256) {
        return members.length;
    }

    function _addMember(address member) internal {
        isMember[msg.sender] = true;
        members.push(msg.sender);

        emit AddMember(member);
    }

    function _removeMember(address member) internal {
        isMember[msg.sender] = false;
        for (uint256 i; i < members.length; i++) {
            if (members[i] == member) {
                members[i] = members[members.length - 1];
                members.pop();
            }
        }

        emit RemoveMember(member);
    }

    function _changeRequirement(uint128 _required) internal {
        required = _required;

        emit ChangeRequirement(_required);
    }

    function _verifySignatures(
        bytes32 hash,
        address[] memory signers,
        Signatures.Signature[] memory signatures
    ) internal {
        for (uint256 i; i < signers.length; i++) {
            address signer = signers[i];
            require(isMember[signer], "DAOKIT: FORBIDDEN");
            require(!_duplicate[signer], "DAOKIT: DUPLICATE_SIGNER");

            _duplicate[signer] = true;
        }
        for (uint256 i; i < signers.length; i++) {
            delete _duplicate[signers[i]];
        }
        Signatures.verifySignatures(DOMAIN_SEPARATOR(), hash, signers, signatures);
    }
}
