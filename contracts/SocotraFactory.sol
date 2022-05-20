pragma solidity ^0.8.11;
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./SocotraSubdaoManager.sol";

contract SocortaFactory {
    using Address for address;

    struct BranchInfo {
        address branchAddr;
        address parentToken;
        address issuer;
    }

    uint256 branchIds;
    uint256 MIN_ISSUE_AMOUNT = 0;

    mapping(uint256 => BranchInfo) branches;

    event SplitBranch(
        address branchAddr,
        address parentToken,
        uint256 amount,
        address issuer,
        uint256 branchId
    );

    constructor() {}

    /// @dev create new branch for splint up subdao
    /// @param parentToken address of ERC20 token
    /// @param amount initial amount of parent token
    /// @param name name of subdao token
    /// @param symbol symbol of subdao token
    function splitBranch(
        address parentToken,
        uint256 amount,
        string memory name,
        string memory symbol
    ) public {
        require(amount > MIN_ISSUE_AMOUNT, "MUST_GREATER_THAN_MINIMUM");
        SocotraSubdaoManager branch = new SocotraSubdaoManager(
            parentToken,
            msg.sender,
            name,
            symbol
        );

        branches[branchIds] = BranchInfo({
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
    }
}
