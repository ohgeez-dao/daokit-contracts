// SPDX-License-Identifier: WTFPL

pragma solidity 0.8.12;

import "./libraries/EIP712s.sol";
import "./libraries/Signatures.sol";
import "./Timelock.sol";

contract CoreTeamGovernance is Timelock {
    // keccak256("QueueTransactions(address[] target,uint256[] value,string[] signature,bytes[] data,uint64[] eta)");
    bytes32 public constant QUEUE_TRANSACTIONS_TYPEHASH =
        0xb4c35086675bb65432758e1391df7d84e686ccfdfa7e7be39250320aa1a67355;
    // keccak256("CancelTransactions(address[] target,uint256[] value,string[] signature,bytes[] data,uint64[] eta)");
    bytes32 public constant CANCEL_TRANSACTIONS_TYPEHASH =
        0xfb3dc1e5b5409e1cc1de0693d7ee84a4f7d85a5192bf0cb142f4652689f838b7;

    uint256 internal immutable _CACHED_CHAIN_ID;
    bytes32 internal immutable _DOMAIN_SEPARATOR;

    mapping(address => bool) public isCoreMember;
    address[] public coreMembers;
    uint128 public coreTeamQuorum;

    mapping(address => bool) internal _duplicate;

    event AddCoreMember(address indexed member);
    event RemoveCoreMember(address indexed member);
    event ChangeCoreTeamQuorum(uint128 quorum);

    modifier calledBySelf {
        require(msg.sender == address(this), "DAOKIT: FORBIDDEN");
        _;
    }

    modifier quorumReached(
        uint256 membersCount,
        uint128 quorum,
        uint128 votes
    ) {
        require(
            (membersCount < quorum && membersCount == votes) || (quorum != 0 && quorum <= votes),
            "DAOKIT: QUORUM_NOT_REACHED"
        );
        _;
    }

    constructor(
        uint64 _delay,
        uint128 _coreTeamQuorum,
        address[] memory _coreMembers
    ) Timelock(_delay) {
        coreTeamQuorum = _coreTeamQuorum;
        for (uint256 i; i < _coreMembers.length; i++) {
            address coreMember = _coreMembers[i];
            isCoreMember[coreMember] = true;
            coreMembers.push(coreMember);

            emit AddCoreMember(coreMember);
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

    /**
     * @notice This function needs to be called by itself, which means it needs to be done by `queueTransactions()` and
     * `executeTransactions()` with this address as `target`
     */
    function addCoreMember(address coreMember) external calledBySelf {
        isCoreMember[msg.sender] = true;
        coreMembers.push(msg.sender);

        emit AddCoreMember(coreMember);
    }

    /**
     * @notice This function needs to be called by itself, which means it needs to be done by `queueTransactions()` and
     * `executeTransactions()` with this address as `target`
     */
    function removeCoreMember(address coreMember) external calledBySelf {
        require(isCoreMember[coreMember], "DAOKIT: INVALID_EXECUTOR");

        isCoreMember[msg.sender] = false;
        for (uint256 i; i < coreMembers.length; i++) {
            if (coreMembers[i] == coreMember) {
                coreMembers[i] = coreMembers[coreMembers.length - 1];
                coreMembers.pop();
            }
        }

        emit RemoveCoreMember(coreMember);
    }

    /**
     * @notice This function needs to be called by itself, which means it needs to be done by `queueTransactions()` and
     * `executeTransactions()` with this address as `target`
     */
    function changeCoreTeamQuorum(uint128 quorum) external calledBySelf {
        coreTeamQuorum = quorum;

        emit ChangeCoreTeamQuorum(quorum);
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
    ) external quorumReached(coreMembers.length, coreTeamQuorum, uint128(signatures.length)) {
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
        _verifySigners(signers);
        Signatures.verifySignatures(DOMAIN_SEPARATOR(), hash, signers, signatures);

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
    ) external quorumReached(coreMembers.length, coreTeamQuorum, uint128(signatures.length)) {
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
        _verifySigners(signers);
        Signatures.verifySignatures(DOMAIN_SEPARATOR(), hash, signers, signatures);

        for (uint256 i; i < target.length; i++) {
            _cancelTransaction(target[i], value[i], signature[i], data[i], eta[i]);
        }
    }

    function _verifySigners(address[] memory signers) internal {
        for (uint256 i; i < signers.length; i++) {
            address signer = signers[i];
            require(isCoreMember[signer], "DAOKIT: FORIBDDEN");
            require(!_duplicate[signer], "DAOKIT: DUPLICATE_SIGNER");

            _duplicate[signer] = true;
        }
        for (uint256 i; i < signers.length; i++) {
            delete _duplicate[signers[i]];
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
