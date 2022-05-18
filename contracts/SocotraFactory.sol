pragma solidity ^0.8.11;
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./SocotraBranchManager.sol";

contract SocortaFactory {
    using Address for address;
    address[] public branches;

    mapping(address => address) issuers;

    constructor() {}

    modifier onlyIssuer(address contractAddress) {
        require(msg.sender == issuers[contractAddress]);
        _;
    }

    event Invoked(
        address indexed _target,
        uint256 indexed _value,
        bytes _data,
        bytes _returnValue
    );

    /**
     * @param _target                 Address of the smart contract to call
     * @param _value                  Quantity of Ether to provide the call (typically 0)
     * @param _data                   Encoded function selector and arguments
     * @return _returnValue           Bytes encoded return value
     */
    function invoke(
        address _target,
        uint256 _value,
        bytes calldata _data
    ) external onlyIssuer(_target) returns (bytes memory _returnValue) {
        _returnValue = _target.functionCallWithValue(_data, _value);

        emit Invoked(_target, _value, _data, _returnValue);

        return _returnValue;
    }

    function splitBranch(address parentToken, uint256 amount) public {
        SocotraBranchManager branch = new SocotraBranchManager(
            parentToken,
            msg.sender
        );

        issuers[address(token)] = msg.sender;
        branches.push(address(token));

        IERC20(parentToken).transferFrom(msg.sender, address(token), amount);
    }
}
