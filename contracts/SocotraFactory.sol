// SPDX-License-Identifier: ISC

pragma solidity ^0.8.11;
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "./SocotraBranchManager.sol";
import "./VoteProxySigner.sol";
import "./interfaces/ISocotraFactory.sol";

contract SocotraFactory is ISocotraFactory {
    using Address for address;
    address public immutable socotraBranchManagerImplementation;
    address public immutable voteProxyImplementation;

    uint256 branchIds;
    uint256 MIN_ISSUE_AMOUNT = 0;

    mapping(uint256 => BranchDetail) branches;

    constructor() {
        voteProxyImplementation = address(new VoteProxySigner());
        socotraBranchManagerImplementation = address(
            new SocotraBranchManager()
        );
    }

    /// @dev create new branch for splint up subdao
    /// @param parentToken address of ERC20 token
    /// @param amount initial amount of parent token
    /// @param name name of subdao
    /// @param imageUrl link to url of subdao's image
    /// @param tokenName name of subdao token
    /// @param tokenSymbol symbol of subdao token
    function splitBranch(
        address parentToken,
        uint256 amount,
        string memory name,
        string memory imageUrl,
        string memory tokenName,
        string memory tokenSymbol
    ) public returns (address) {
        require(amount > MIN_ISSUE_AMOUNT, "MUST_GREATER_THAN_MINIMUM");
        SocotraBranchManager branch = SocotraBranchManager(
            Clones.clone(socotraBranchManagerImplementation)
        );
        branch.init(
            address(this),
            parentToken,
            msg.sender,
            name,
            imageUrl,
            tokenName,
            tokenSymbol
        );

        branches[branchIds] = BranchDetail({
            branchAddr: address(branch),
            parentToken: parentToken,
            issuer: msg.sender
        });
        IERC20(parentToken).transferFrom(msg.sender, address(branch), amount);
        emit SplitBranch(
            address(branch),
            parentToken,
            amount,
            msg.sender,
            branchIds
        );
        branchIds++;
        return address(branch);
    }

    function createVoteProxy(address issuer) public returns (address) {
        VoteProxySigner voter = VoteProxySigner(
            Clones.clone(voteProxyImplementation)
        );
        voter.init(msg.sender, issuer);
        emit CreateVoter(msg.sender, issuer, address(voter));
        return address(voter);
    }
}
