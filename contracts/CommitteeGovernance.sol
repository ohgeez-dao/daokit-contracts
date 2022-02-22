// SPDX-License-Identifier: WTFPL

pragma solidity 0.8.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract CommitteeGovernance {
    using SafeERC20 for IERC20;

    enum VoteType {
        Against,
        For,
        Abstain
    }

    enum ProposalStatus {
        Open,
        Cancelled,
        Failed,
        Executed
    }

    uint64 public constant MINIMUM_DELAY = 1 days;

    /**
     * @notice Token to be used for proposal voting
     */
    address public immutable tokenAddress;
    /**
     * @notice Minimum number of votes required to pass a proposal
     */
    uint128 public immutable proposalQuorumMin;
    /**
     * @notice Minimum number of votes required for submitting a proposal
     */
    uint128 public immutable proposalVotesMin;

    mapping(address => bool) public isCommitteeMember;
    address[] public committeeMembers;
    uint128 public committeeQuorum;
    mapping(bytes32 => Proposal) public proposals;

    event AddCommitteeMember(address indexed member);
    event RemoveCommitteeMember(address indexed member);
    event ChangeCommitteeQuorum(uint128 quorum);
    event SubmitProposal(bytes32 indexed hash);
    event CancelProposal(bytes32 indexed hash);
    event ExecuteProposal(bytes32 indexed hash, address executor);
    event CastVote(bytes32 indexed hash, address voter, uint128 votes, VoteType indexed voteType);
    event WithdrawTokens(bytes32 indexed hash, address withdrawer, uint128 amount);

    struct Proposal {
        address proposer;
        bytes[] data;
        uint64 startBlock;
        uint64 endBlock;
        uint128 quorum;
        uint128 againstVotes;
        uint128 forVotes;
        uint128 abstainVotes;
        mapping(address => uint128) votes;
        ProposalStatus status;
    }

    modifier calledBySelf {
        require(msg.sender == address(this), "DAOKIT: FORBIDDEN");
        _;
    }

    constructor(
        address _tokenAddress,
        uint128 _proposalQuorumMin,
        uint128 _proposalVotesMin,
        uint128 _committeeQuorum,
        address[] memory _committeeMembers
    ) {
        tokenAddress = _tokenAddress;
        proposalQuorumMin = _proposalQuorumMin;
        proposalVotesMin = _proposalVotesMin;

        committeeQuorum = _committeeQuorum;
        for (uint256 i; i < _committeeMembers.length; i++) {
            address member = _committeeMembers[i];
            isCommitteeMember[member] = true;
            committeeMembers.push(member);

            emit AddCommitteeMember(member);
        }
    }

    function hashProposal(
        address proposer,
        bytes[] memory data,
        uint64 startBlock,
        uint64 endBlock,
        uint128 quorum
    ) public pure returns (bytes32) {
        return keccak256(abi.encode(proposer, keccak256(abi.encode(data)), startBlock, endBlock, quorum));
    }

    /**
     * @notice This function needs to be called by itself, which means it needs to be done by `submitProposal()` and
     * `executeProposal()`
     */
    function addCommitteeMember(address committeeMember) external calledBySelf {
        isCommitteeMember[msg.sender] = true;
        committeeMembers.push(msg.sender);

        emit AddCommitteeMember(committeeMember);
    }

    /**
     * @notice This function needs to be called by itself, which means it needs to be done by `submitProposal()` and
     * `executeProposal()`
     */
    function removeCommitteeMember(address committeeMember) external calledBySelf {
        isCommitteeMember[msg.sender] = false;
        for (uint256 i; i < committeeMembers.length; i++) {
            if (committeeMembers[i] == committeeMember) {
                committeeMembers[i] = committeeMembers[committeeMembers.length - 1];
                committeeMembers.pop();
            }
        }

        emit RemoveCommitteeMember(committeeMember);
    }

    /**
     * @notice This function needs to be called by itself, which means it needs to be done by `submitProposal()` and
     * `executeProposal()`
     */
    function changeCommitteeQuorum(uint128 quorum) external calledBySelf {
        committeeQuorum = quorum;

        emit ChangeCommitteeQuorum(quorum);
    }

    /**
     * @notice Anyone can submit a proposal to add/remove committee member or change committee quorum
     */
    function submitProposal(
        bytes[] memory data,
        uint64 startBlock,
        uint64 endBlock,
        uint128 quorum,
        uint128 votes,
        VoteType voteType
    ) external {
        require(startBlock > 0, "DAOKIT: INVALID_START_BLOCK");
        require(endBlock >= block.timestamp + MINIMUM_DELAY, "DAOKIT: INVALID_END_BLOCK");
        require(quorum >= proposalQuorumMin, "DAOKIT: INVALID_QUORUM");
        require(votes >= proposalVotesMin, "DAOKIT: INSUFFICIENT_VOTES");

        bytes32 hash = hashProposal(msg.sender, data, startBlock, endBlock, quorum);
        Proposal storage proposal = proposals[hash];
        require(proposal.startBlock == 0, "DAOKIT: DUPLICATE_PROPOSAL");
        proposal.proposer = msg.sender;
        proposal.data = data;
        proposal.startBlock = startBlock;
        proposal.endBlock = endBlock;
        proposal.quorum = quorum;

        emit SubmitProposal(hash);

        _castVote(proposal, hash, votes, voteType);
    }

    /**
     * @notice Anyone can cast a vote for a proposal by locking up tokens
     */
    function castVote(
        bytes32 hash,
        uint128 votes,
        VoteType voteType
    ) external {
        Proposal storage proposal = proposals[hash];
        require(proposal.proposer != address(0), "DAOKIT: INVALID_HASH");
        require(proposal.endBlock > block.timestamp, "DAOKIT: EXPIRED");
        require(proposal.status == ProposalStatus.Open, "DAOKIT: NOT_OPEN");
        require(proposal.votes[msg.sender] == 0, "DAOKIT: VOTE_CASTED");

        _castVote(proposal, hash, votes, voteType);
    }

    function _castVote(
        Proposal storage proposal,
        bytes32 hash,
        uint128 votes,
        VoteType voteType
    ) internal {
        IERC20(tokenAddress).safeTransferFrom(msg.sender, address(this), votes);

        if (voteType == VoteType.Against) {
            proposal.againstVotes += votes;
        } else if (voteType == VoteType.For) {
            proposal.forVotes += votes;
        } else {
            proposal.abstainVotes += votes;
        }
        proposal.votes[msg.sender] = votes;

        emit CastVote(hash, msg.sender, votes, voteType);
    }

    /**
     * @notice Proposer can cancel a submitted proposal
     */
    function cancelProposal(bytes32 hash) external {
        Proposal storage proposal = proposals[hash];
        require(proposal.proposer == msg.sender, "DAOKIT: INVALID_HASH");
        require(proposal.endBlock > block.timestamp, "DAOKIT: EXPIRED");
        require(proposal.status == ProposalStatus.Open, "DAOKIT: NOT_OPEN");
        require(!_quorumReached(proposal), "DAOKIT: QUORUM_REACHED");

        proposal.status = ProposalStatus.Cancelled;

        emit CancelProposal(hash);
    }

    /**
     * @notice Anyone can execute a proposal that passed its quorum and whose `forVotes` is greater than `againstVotes`
     */
    function executeProposal(bytes32 hash) external {
        Proposal storage proposal = proposals[hash];
        require(proposal.status == ProposalStatus.Open, "DAOKIT: INVALID_STATUS");
        require(_quorumReached(proposal), "DAOKIT: QUORUM_NOT_REACHED");
        require(_voteSucceeded(proposal), "DAOKIT: VOTE_FAILED");

        proposal.status = ProposalStatus.Executed;

        for (uint256 i; i < proposal.data.length; i++) {
            (bool success, ) = address(this).call(proposal.data[i]);
            require(success, "DAOKIT: TRANSACTION_REVERTED");
        }

        emit ExecuteProposal(hash, msg.sender);
    }

    /**
     * @notice Voters can withdraw their tokens they locked up if the proposal deadline has passed
     */
    function withdrawTokens(bytes32 hash) external {
        Proposal storage proposal = proposals[hash];
        // if the vote has ended or quorum reached but vote failed
        if (proposal.endBlock <= block.timestamp && (!_quorumReached(proposal) || !_voteSucceeded(proposal))) {
            proposal.status = ProposalStatus.Failed;
        } else {
            require(proposal.status != ProposalStatus.Open, "DAOKIT: INVALID_STATUS");
        }

        uint128 votes = proposal.votes[msg.sender];
        require(votes > 0, "DAOKIT: VOTE_NOT_CASTED");

        proposal.votes[msg.sender] = 0;
        IERC20(tokenAddress).safeTransfer(msg.sender, votes);

        emit WithdrawTokens(hash, msg.sender, votes);
    }

    function _quorumReached(Proposal storage proposal) internal view returns (bool) {
        return proposal.quorum <= proposal.forVotes + proposal.abstainVotes;
    }

    function _voteSucceeded(Proposal storage proposal) internal view returns (bool) {
        return proposal.forVotes > proposal.againstVotes;
    }
}
