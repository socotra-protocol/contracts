pragma solidity ^0.8.11;
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./SocotraBranchManager.sol";

contract SocortaFactory {
    using Address for address;

    struct BranchInfo {
        address branchAddr;
        address parentToken;
        address issuer;
    }

    uint256 branchIds;

    mapping(uint256 => BranchInfo) branches;

    event SplitBranch(
        address branchAddr,
        address parentToken,
        address issuer,
        uint256 branchId
    );

    constructor() {}

    function splitBranch(address parentToken, uint256 amount) public {
        SocotraBranchManager branch = new SocotraBranchManager(
            parentToken,
            msg.sender
        );

        branches[branchIds] = BranchInfo({
            branchAddr: address(branch),
            parentToken: parentToken,
            issuer: msg.sender
        });
        IERC20(parentToken).transferFrom(msg.sender, address(branch), amount);
        emit SplitBranch(address(branch), parentToken, msg.sender, branchIds);
        branchIds++;
    }
}
