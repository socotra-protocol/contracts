pragma solidity ^0.8.11;
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./SocotraLeafToken.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IDelegateRegistry.sol";
import "./VoteProxySigner.sol";

contract SocotraBranchManager is Ownable {
    enum ManagerState {
        NONE,
        PENDING,
        INITIALIZED
    }

    address parentAddress;

    struct Payout {
        uint256 amount;
        uint256 leafIndex;
        address receiver;
        bytes proof;
        bool isPaid;
    }

    ManagerState managerState;

    address snapshotDelegation = 0x469788fE6E9E9681C6ebF3bF78e7Fd26Fc015446;
    address voteProxy;

    uint256 public totalAllocPoint;
    uint256 registerTokens;

    mapping(uint256 => Payout) payouts;
    uint256 payoutIds;

    mapping(address => uint256) depositInfos;
    mapping(address => uint256) rewardInfos;
    uint256 totalReward;
    uint256 totalToken;

    mapping(uint256 => TokenMetadata) leafs;
    uint256 leafsCount;

    struct TokenMetadata {
        address tokenAddress;
        uint256 rewardPoint;
    }

    event ProxyRegistered(address proxy);
    event UpdateSnapshot(address newDelegation);

    event RegisterLeaf();

    constructor(address _parentToken, address _issuer) {
        parentAddress = _parentToken;
        _transferOwnership(_issuer);
        managerState = ManagerState.PENDING;
    }

    /// @dev create vote proxy contract
    function registerSnapshotVoteProxy() public onlyOwner {
        require(managerState == ManagerState.PENDING, "NOT_PENDING_STATE");
        VoteProxySigner proxy = new VoteProxySigner(owner());
        voteProxy = address(proxy);
        managerState = ManagerState.INITIALIZED;
        emit ProxyRegistered(address(proxy));
    }

    /// @dev Update snapshot delegation address
    /// @param snapshotAddr new snapshot address
    function changeSnapshotDelegation(address snapshotAddr) public onlyOwner {
        snapshotDelegation = snapshotAddr;
        emit UpdateSnapshot(snapshotAddr);
    }

    /// @dev Delegate snapshot space id
    /// @param id snapshot space Id
    function delegateSpace(bytes32 id) public onlyOwner {
        require(
            managerState == ManagerState.INITIALIZED,
            "NOT_INITIALIZED_VOTER"
        );
        IDelegateRegistry(snapshotDelegation).setDelegate(
            id,
            snapshotDelegation
        );
    }

    /// @dev Transfer Parent Token
    /// @param from from address
    /// @param target target address
    /// @param amount amount of token
    function _parentTransfer(
        address from,
        address target,
        uint256 amount
    ) internal {
        IERC20(parentAddress).transferFrom(from, target, amount);
    }

    /// @dev Transfer Parent Token
    /// @param _rewardPoint reward allocation for address
    /// @param _name name of subtoken
    /// @param _symbol symbol of subtoken
    function addLeaf(
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

    /// @dev Issue subtoken
    /// @param leafIndex reward allocation for address
    /// @param target name of subtoken
    /// @param amount symbol of subtoken
    function issueTo(
        uint256 leafIndex,
        address target,
        uint256 amount
    ) public onlyOwner {
        TokenMetadata memory fragement = leafs[leafIndex];
        SocotraLeafTokenV0(fragement.tokenAddress)._managerMint(target, amount);
    }

    /// @dev Burn subtoken
    /// @param leafIndex reward allocation for address
    /// @param target name of subtoken
    /// @param amount symbol of subtoken
    function _burnFrom(
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
        totalReward += rewardAmount;
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
        _burnFrom(payout.leafIndex, address(this), payout.amount);
        uint256 payoutAmount = calPayoutAmount(payout.amount);
        payout.isPaid = true;
        _parentTransfer(address(this), payout.receiver, payoutAmount);
    }

    function calPayoutAmount(uint256 amount) public view returns (uint256) {
        return (amount * totalReward) / totalAllocPoint;
    }
}
