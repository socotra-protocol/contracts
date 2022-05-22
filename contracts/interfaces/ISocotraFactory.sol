// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity >=0.8.0;

interface ISocotraFactory {
    function createVoteProxy(address issuer) external returns (address);

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
