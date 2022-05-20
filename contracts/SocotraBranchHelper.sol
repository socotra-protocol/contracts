// SPDX-License-Identifier: ISC

pragma solidity ^0.8.7;

library SocotraBranchHelper {
    function calPayoutAmount(
        uint256 claimAmount,
        uint256 totalMemberToken,
        uint256 totalMemberReward
    ) public pure returns (uint256) {
        return (claimAmount * totalMemberReward) / totalMemberToken;
    }
}
