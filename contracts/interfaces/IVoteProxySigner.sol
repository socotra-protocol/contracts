// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity >=0.8.0;

interface IVoteProxySigner {
    function bravoCastVote(
        address governor,
        uint256 proposalId,
        uint8 support
    ) external;

    function modifyTeam(address _member, bool _approval) external;

    struct BranchDetail {
        address branchAddr;
        address parentToken;
        address issuer;
    }
    event SplitBranch(
        address branchAddr,
        address parentToken,
        uint256 amount,
        address issuer,
        uint256 branchId
    );

    event CreateVoter(address owner, address issuer, address voter);
}
