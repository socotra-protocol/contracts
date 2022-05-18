pragma solidity ^0.8.11;
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./SocotraLeafToken.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract SocotraBranchManager is Ownable {
    address parentAddress;

    struct Payout {
        uint256 amount;
        uint256 leafIndex;
        address receiver;
        bytes proof;
        bool isPaid;
    }

    uint256 public totalAllocPoint;
    uint256 registerTokens;

    mapping(uint256 => Payout) payouts;
    uint256 payoutIds;

    mapping(address => uint256) depositInfos;
    mapping(address => uint256) rewardInfos;
    uint256 totalReward;

    mapping(uint256 => TokenMetadata) leafs;
    uint256 leafsCount;

    struct TokenMetadata {
        address tokenAddress;
        uint256 rewardPoint;
    }

    event Invoked(
        address indexed module,
        address indexed target,
        uint256 indexed value,
        bytes data
    );

    constructor(address _parentToken, address _issuer) {
        parentAddress = _parentToken;
        _transferOwnership(_issuer);
    }

    function _parentTransfer(
        address from,
        address target,
        uint256 amount
    ) internal {
        IERC20(parentAddress).transferFrom(from, target, amount);
    }

    function addFragment(
        uint256 _rewardPoint,
        string memory _name,
        string memory _symbol
    ) external onlyOwner {
        SocotraLeafTokenV0 leaf = new SocotraLeafTokenV0(_name, _symbol);
        leafs[leafsCount] = TokenMetadata({
            tokenAddress: address(leaf),
            rewardPoint: _rewardPoint
        });
        totalAllocPoint += _rewardPoint;
        leafsCount++;
    }

    function issueTo(
        uint256 leafIndex,
        address target,
        uint256 amount
    ) public onlyOwner {
        TokenMetadata memory fragement = leafs[leafIndex];
        SocotraLeafTokenV0(fragement.tokenAddress)._managerMint(target, amount);
    }

    function burnFrom(
        uint256 leafIndex,
        address target,
        uint256 amount
    ) internal {
        TokenMetadata memory fragement = leafs[leafIndex];
        SocotraLeafTokenV0(fragement.tokenAddress)._managerBurn(target, amount);
    }

    function depositParentAndAllocateReward(
        uint256 depositAmount,
        uint256 rewardAmount
    ) public {
        require(depositAmount != 0, "NON_ZERO_DEPOSIT");
        require(
            depositInfos[msg.sender] + depositAmount >=
                rewardInfos[msg.sender] + rewardAmount,
            "EXCEED_DEPOSIT_VALUE"
        );
        _parentTransfer(msg.sender, address(this), depositAmount);
        depositInfos[msg.sender] += depositAmount;
        rewardInfos[msg.sender] += rewardAmount;
    }

    function withdrawParent(uint256 withdrawAmount, uint256 rewardAmount)
        public
    {
        require(withdrawAmount != 0, "NON_ZERO_WITHDRAW");
        require(
            depositInfos[msg.sender] - withdrawAmount >= 0 &&
                depositInfos[msg.sender] - withdrawAmount >= rewardAmount,
            "EXCEED_DEPOSIT_VALUE"
        );

        _parentTransfer(address(this), msg.sender, withdrawAmount);
        depositInfos[msg.sender] -= withdrawAmount;
        rewardInfos[msg.sender] += rewardAmount;
    }

    function requestPayout(
        uint256 amount,
        uint256 leafIndex,
        address receiver,
        bytes memory proof
    ) public {
        require(amount > 0, "NO_ZERO_PAYPOUT");
        IERC20(leafs[leafIndex].tokenAddress).transferFrom(
            msg.sender,
            address(this),
            amount
        );
        payouts[payoutIds] = Payout({
            amount: amount,
            leafIndex: leafIndex,
            receiver: receiver,
            proof: proof,
            isPaid: false
        });
    }

    function withdrawPayout(uint256 payoutId) public {
        Payout storage payout = payouts[payoutId];
        TokenMetadata memory leaf = leafs[payout.leafIndex];
        payout.isPaid = true;
        IERC20(leaf.tokenAddress).transferFrom(
            address(this),
            payout.receiver,
            payout.amount
        );
    }

    function issuePayout(uint256 payoutId) external onlyOwner {
        Payout storage payout = payouts[payoutId];
        require(payout.isPaid == false, "ALREADY_PAYOUT");
        burnFrom(payout.leafIndex, address(this), payout.amount);
        uint256 payoutAmount = calPayoutAmount(payout.amount);
        payout.isPaid = true;
        _parentTransfer(address(this), payout.receiver, payoutAmount);
    }

    function calPayoutAmount(uint256 amount) public view returns (uint256) {
        return (amount * totalReward) / totalAllocPoint;
    }
}
