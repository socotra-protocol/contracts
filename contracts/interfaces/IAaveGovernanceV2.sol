// SPDX-License-Identifier: agpl-3.0
pragma solidity >=0.7.5;
pragma abicoder v2;

interface IAaveGovernanceV2 {
    enum ProposalState {
        Pending,
        Canceled,
        Active,
        Failed,
        Succeeded,
        Queued,
        Expired,
        Executed
    }

    struct Vote {
        bool support;
        uint248 votingPower;
    }

    /**
     * @dev emitted when a proposal is canceled
     * @param id Id of the proposal
     **/
    event ProposalCanceled(uint256 id);

    /**
     * @dev emitted when a proposal is queued
     * @param id Id of the proposal
     * @param executionTime time when proposal underlying transactions can be executed
     * @param initiatorQueueing address of the initiator of the queuing transaction
     **/
    event ProposalQueued(
        uint256 id,
        uint256 executionTime,
        address indexed initiatorQueueing
    );
    /**
     * @dev emitted when a proposal is executed
     * @param id Id of the proposal
     * @param initiatorExecution address of the initiator of the execution transaction
     **/
    event ProposalExecuted(uint256 id, address indexed initiatorExecution);
    /**
     * @dev emitted when a vote is registered
     * @param id Id of the proposal
     * @param voter address of the voter
     * @param support boolean, true = vote for, false = vote against
     * @param votingPower Power of the voter/vote
     **/
    event VoteEmitted(
        uint256 id,
        address indexed voter,
        bool support,
        uint256 votingPower
    );

    event GovernanceStrategyChanged(
        address indexed newStrategy,
        address indexed initiatorChange
    );

    event VotingDelayChanged(
        uint256 newVotingDelay,
        address indexed initiatorChange
    );

    event ExecutorAuthorized(address executor);

    event ExecutorUnauthorized(address executor);

    /**
     * @dev Cancels a Proposal,
     * either at anytime by guardian
     * or when proposal is Pending/Active and threshold no longer reached
     * @param proposalId id of the proposal
     **/
    function cancel(uint256 proposalId) external;

    /**
     * @dev Queue the proposal (If Proposal Succeeded)
     * @param proposalId id of the proposal to queue
     **/
    function queue(uint256 proposalId) external;

    /**
     * @dev Execute the proposal (If Proposal Queued)
     * @param proposalId id of the proposal to execute
     **/
    function execute(uint256 proposalId) external payable;

    /**
     * @dev Function allowing msg.sender to vote for/against a proposal
     * @param proposalId id of the proposal
     * @param support boolean, true = vote for, false = vote against
     **/
    function submitVote(uint256 proposalId, bool support) external;

    /**
     * @dev Function to register the vote of user that has voted offchain via signature
     * @param proposalId id of the proposal
     * @param support boolean, true = vote for, false = vote against
     * @param v v part of the voter signature
     * @param r r part of the voter signature
     * @param s s part of the voter signature
     **/
    function submitVoteBySignature(
        uint256 proposalId,
        bool support,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    /**
     * @dev Set new GovernanceStrategy
     * Note: owner should be a timelocked executor, so needs to make a proposal
     * @param governanceStrategy new Address of the GovernanceStrategy contract
     **/
    function setGovernanceStrategy(address governanceStrategy) external;

    /**
     * @dev Set new Voting Delay (delay before a newly created proposal can be voted on)
     * Note: owner should be a timelocked executor, so needs to make a proposal
     * @param votingDelay new voting delay in seconds
     **/
    function setVotingDelay(uint256 votingDelay) external;

    /**
     * @dev Add new addresses to the list of authorized executors
     * @param executors list of new addresses to be authorized executors
     **/
    function authorizeExecutors(address[] memory executors) external;

    /**
     * @dev Remove addresses to the list of authorized executors
     * @param executors list of addresses to be removed as authorized executors
     **/
    function unauthorizeExecutors(address[] memory executors) external;

    /**
     * @dev Let the guardian abdicate from its priviledged rights
     **/
    function __abdicate() external;

    /**
     * @dev Getter of the current GovernanceStrategy address
     * @return The address of the current GovernanceStrategy contracts
     **/
    function getGovernanceStrategy() external view returns (address);

    /**
     * @dev Getter of the current Voting Delay (delay before a created proposal can be voted on)
     * Different from the voting duration
     * @return The voting delay in seconds
     **/
    function getVotingDelay() external view returns (uint256);

    /**
     * @dev Returns whether an address is an authorized executor
     * @param executor address to evaluate as authorized executor
     * @return true if authorized
     **/
    function isExecutorAuthorized(address executor)
        external
        view
        returns (bool);

    /**
     * @dev Getter the address of the guardian, that can mainly cancel proposals
     * @return The address of the guardian
     **/
    function getGuardian() external view returns (address);

    /**
     * @dev Getter of the proposal count (the current number of proposals ever created)
     * @return the proposal count
     **/
    function getProposalsCount() external view returns (uint256);

    /**
     * @dev Getter of the Vote of a voter about a proposal
     * Note: Vote is a struct: ({bool support, uint248 votingPower})
     * @param proposalId id of the proposal
     * @param voter address of the voter
     * @return The associated Vote memory object
     **/
    function getVoteOnProposal(uint256 proposalId, address voter)
        external
        view
        returns (Vote memory);

    /**
     * @dev Get the current state of a proposal
     * @param proposalId id of the proposal
     * @return The current state if the proposal
     **/
    function getProposalState(uint256 proposalId)
        external
        view
        returns (ProposalState);
}
