pragma solidity ^0.8.11;
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./SocotraVoteToken.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IDelegateRegistry.sol";
import "./VoteProxySigner.sol";

contract SocotraSubdaoManager is Ownable {
    enum ManagerState {
        NONE,
        PENDING,
        INITIALIZED
    }

    struct SubdaoInfo {
        address parentTokenAddress;
        address voteTokenAddress;
        string imageUrl;
    }

    struct MemberInfo {
        uint256 availableToken;
        uint256 totalToken;
        uint256 claimingToken;
        uint256 rewardAmount;
    }

    struct Payout {
        uint256 amount;
        address issuer;
        address receiver;
        bytes proof;
        bool isPaid;
    }

    ManagerState managerState;

    SubdaoInfo public subdaoInfo;

    address snapshotDelegation = 0x469788fE6E9E9681C6ebF3bF78e7Fd26Fc015446;
    address voteProxy;

    uint256 public totalAllocation;
    mapping(address => MemberInfo) members;

    mapping(uint256 => Payout) payouts;
    uint256 payoutCount;

    mapping(address => uint256) depositInfos;
    mapping(address => uint256) rewardInfos;
    uint256 totalReward;
    uint256 totalToken;

    event ProxyRegistered(address proxy);
    event UpdateSnapshot(address newDelegation);

    event RegisterLeaf();

    constructor(
        address _parentToken,
        address _issuer,
        string memory _tokenName,
        string memory _tokenSymbol
    ) {
        subdaoInfo.parentTokenAddress = _parentToken;
        _transferOwnership(_issuer);
        _initToken(_tokenName, _tokenSymbol);
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

    /// @dev Add allocation for member
    /// @param memberAddr address of a member
    /// @param voteAmount amount of voting token member can claim
    /// @param rewardAmount amount of parent token member can claim as reward
    function addMemberAllocation(
        address memberAddr,
        uint256 voteAmount,
        uint256 rewardAmount
    ) public onlyOwner {
        uint256 totalParent = IERC20(subdaoInfo.parentTokenAddress).balanceOf(
            address(this)
        );
        require(
            totalAllocation + rewardAmount <= totalParent,
            "NOT_EXCEED_TOKEN_LIMIT"
        );
        MemberInfo storage member = members[memberAddr];
        member.availableToken += voteAmount;
        member.totalToken += voteAmount;
        member.rewardAmount += rewardAmount;
        totalAllocation += rewardAmount;
    }

    //TODO add batch allocation

    /// @dev member claim their token allocation
    /// @param amount amount of token they want to claim
    function memberClaimToken(uint256 amount) external {
        require(amount > 0, "NO_CLAIM_ZERO");
        MemberInfo storage member = members[msg.sender];
        require(amount <= member.availableToken, "EXCEED_CLAIM_LIMIT");
        member.availableToken -= amount;
        _issueTo(msg.sender, amount);
    }

    /// @dev member claim their token allocation
    /// @param amount amount of token they want to claim
    function withdrawUnClaim(uint256 amount) external onlyOwner {
        require(amount > 0, "NO_WITHDRAW_UNCLAIM_ZERO");
        uint256 totalParent = IERC20(subdaoInfo.parentTokenAddress).balanceOf(
            address(this)
        );
        require(amount <= totalParent - totalAllocation, "EXCEED_CLAIM_LIMIT");
        _parentTransfer(address(this), msg.sender, amount);
    }

    /// @dev Initialize Subdao Vote Token
    /// @param _name name of subtoken
    /// @param _symbol symbol of subtoken
    function _initToken(string memory _name, string memory _symbol) internal {
        require(managerState == ManagerState.NONE, "NOT_IN_NONE_STATE");
        SocotraVoteToken voteToken = new SocotraVoteToken(_name, _symbol);
        subdaoInfo.voteTokenAddress = address(voteToken);
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
        IERC20(subdaoInfo.parentTokenAddress).transferFrom(
            from,
            target,
            amount
        );
    }

    /// @dev Transfer Subdao Token
    /// @param from from address
    /// @param target target address
    /// @param amount amount of token
    function _subdaoTransfer(
        address from,
        address target,
        uint256 amount
    ) internal {
        IERC20(subdaoInfo.voteTokenAddress).transferFrom(from, target, amount);
    }

    /// @dev Issue subtoken
    /// @param target name of subtoken
    /// @param amount symbol of subtoken
    function _issueTo(address target, uint256 amount) internal {
        SocotraVoteToken(subdaoInfo.voteTokenAddress)._managerMint(
            target,
            amount
        );
    }

    /// @dev Burn subtoken
    /// @param target name of subtoken
    /// @param amount symbol of subtoken
    function _burnFrom(address target, uint256 amount) internal {
        SocotraVoteToken(subdaoInfo.voteTokenAddress)._managerBurn(
            target,
            amount
        );
    }

    function requestPayout(
        uint256 amount,
        address receiver,
        bytes memory proof
    ) external {
        require(amount > 0, "NO_ZERO_PAYPOUT");
        MemberInfo storage member = members[msg.sender];
        require(
            amount + member.claimingToken <= member.totalToken,
            "EXCEED_TOTAL"
        );
        member.claimingToken += amount;
        _subdaoTransfer(msg.sender, address(this), amount);
        payouts[payoutCount] = Payout({
            amount: amount,
            issuer: msg.sender,
            receiver: receiver,
            proof: proof,
            isPaid: false
        });
    }

    function withdrawPayout(uint256 payoutId) external {
        MemberInfo storage member = members[msg.sender];
        Payout storage payout = payouts[payoutId];
        require(payout.isPaid == false, "ALREADY_PAYOUT");
        payout.isPaid = true;
        member.claimingToken -= payout.amount;
        _subdaoTransfer(address(this), payout.receiver, payout.amount);
    }

    function issuePayout(uint256 payoutId) public onlyOwner {
        Payout storage payout = payouts[payoutId];
        require(payout.isPaid == false, "ALREADY_PAYOUT");
        _burnFrom(address(this), payout.amount);
        MemberInfo storage member = members[payout.issuer];

        uint256 payoutAmount = calPayoutAmount(
            payout.amount,
            member.totalToken,
            member.rewardAmount
        );
        member.rewardAmount -= payoutAmount;
        member.claimingToken -= payout.amount;
        payout.isPaid = true;
        _parentTransfer(address(this), payout.receiver, payoutAmount);
    }

    function batchIssuePayout(uint256[] memory payoutIds) public onlyOwner {
        for (uint256 i = 0; i < payoutIds.length; i++) {
            issuePayout(payoutIds[i]);
        }
    }

    function calPayoutAmount(
        uint256 claimAmount,
        uint256 totalMemberToken,
        uint256 totalMemberReward
    ) public pure returns (uint256) {
        return (claimAmount * totalMemberReward) / totalMemberToken;
    }
}
