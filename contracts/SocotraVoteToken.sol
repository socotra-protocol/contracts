// SPDX-License-Identifier: ISC

pragma solidity ^0.8.11;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20VotesComp.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract SocotraVoteToken is ERC20, ERC20Permit, ERC20VotesComp, Ownable {
    constructor(string memory _name, string memory _symbol)
        ERC20(_name, _symbol)
        ERC20Permit(_name)
    {}

    // The functions below are overrides required by Solidity.

    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20, ERC20Votes) {
        super._afterTokenTransfer(from, to, amount);
    }

    function _mint(address to, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        super._mint(to, amount);
    }

    function _burn(address account, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        super._burn(account, amount);
    }

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
