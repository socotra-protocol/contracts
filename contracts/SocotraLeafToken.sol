pragma solidity ^0.8.11;
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract SocotraLeafTokenV0 is ERC20, Ownable {
    constructor(string memory _name, string memory _symbol)
        ERC20(_name, _symbol)
    {}

    /// @dev burn token by manager
    /// @param target target address
    /// @param amount amount to burn
    function _managerBurn(address target, uint256 amount) external onlyOwner {
        _burn(target, amount);
    }

    /// @dev mint token by manager
    /// @param target target address
    /// @param amount amount to mint
    function _managerMint(address target, uint256 amount) external onlyOwner {
        _mint(target, amount);
    }
}
