// SPDX-License-Identifier: ISC

pragma solidity ^0.8.11;
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IDelegateRegistry.sol";
import "./SocotraVoteToken.sol";
import "./interfaces/ISocotraFactory.sol";
import "./interfaces/IVoteProxySigner.sol";

contract SocotraBranchManager is Ownable {
    enum ManagerState {
        NONE,
        PENDING,
        READY_OFF_CHAIN,
        READY_ON_CHAIN
    }

    struct BranchInfo {
        address parentTokenAddress;
        address voteTokenAddress;
        string name;
        string imageUrl;
    }

    struct MemberInfo {
        uint256 availableToken;
        uint256 totalToken;
        uint256 claimingToken;
        uint256 rewardAmount;
    }

    struct AllocationInput {
        address memberAddr;
        uint256 voteAmount;
        uint256 rewardAmount;
    }

    struct Payout {
        uint256 amount;
        address issuer;
        address receiver;
        string proof;
        bool isPaid;
    }
    ISocotraFactory public factory;

    ManagerState public managerState;

    BranchInfo public branchInfo;

    address public snapshotDelegation;
    address public voteProxy;

    uint256 public totalAllocation;
    mapping(address => MemberInfo) public members;

    mapping(uint256 => Payout) public payouts;
    uint256 public payoutCount;

    event ProxyRegistered(address proxy);
    event UpdateSnapshot(address newDelegation);
    event DelegateSpace(bytes32 spaceId);

    event RegisterMember(
        address memberAddr,
        uint256 voteAmount,
        uint256 rewardAmount
    );
    event ClaimToken(address memberAddr, uint256 tokenAmount);
    event RequestPayout(
        uint256 id,
        uint256 amount,
        address issuer,
        address receiver,
        string proof
    );
    event WithdrawPayout(uint256 id);
    event IssuePayout(uint256 id);

    function init(
        address _factory,
        address _parentToken,
        address _issuer,
        string memory _name,
        string memory _imageUrl,
        string memory _tokenName,
        string memory _tokenSymbol
    ) external {
        require(managerState == ManagerState.NONE, "Already initialized!");
        factory = ISocotraFactory(_factory);
        branchInfo.parentTokenAddress = _parentToken;
        branchInfo.name = _name;
        branchInfo.imageUrl = _imageUrl;
        snapshotDelegation = 0x469788fE6E9E9681C6ebF3bF78e7Fd26Fc015446;
        _transferOwnership(_issuer);
        _initToken(_tokenName, _tokenSymbol);
        managerState = ManagerState.PENDING;
    }

    function delegatesParentBySig(
        uint256 nonce,
        uint256 expiry,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external onlyOwner {
        require(
            managerState == ManagerState.READY_OFF_CHAIN,
            "NOT_INITIALIZED_STATE"
        );
        ERC20Votes(branchInfo.parentTokenAddress).delegateBySig(
            voteProxy,
            nonce,
            expiry,
            v,
            r,
            s
        );
        managerState = ManagerState.READY_ON_CHAIN;
    }

    /// @dev create vote proxy contract
    function registerSnapshotVoteProxy() public onlyOwner {
        require(managerState == ManagerState.PENDING, "NOT_PENDING_STATE");
        voteProxy = factory.createVoteProxy(owner());
        managerState = ManagerState.READY_OFF_CHAIN;
        emit ProxyRegistered(voteProxy);
    }

    /// @dev Update snapshot delegation address
    /// @param snapshotAddr new snapshot address
    function changeSnapshotDelegation(address snapshotAddr) public onlyOwner {
        snapshotDelegation = snapshotAddr;
        emit UpdateSnapshot(snapshotAddr);
    }

    /// @dev Delegate snapshot space id
    /// @param id snapshot space Id
    function delegateSpace(bytes32 id) external onlyOwner {
        require(
            uint8(managerState) >= uint8(ManagerState.READY_OFF_CHAIN),
            "NOT_INITIALIZED_VOTER"
        );
        IDelegateRegistry(snapshotDelegation).setDelegate(id, voteProxy);

        emit DelegateSpace(id);
    }

    /// @dev Delegate snapshot space id
    /// @param member voter address
    /// @param approval permission for voter
    function updateSigner(address member, bool approval) external onlyOwner {
        require(
            uint8(managerState) >= uint8(ManagerState.READY_OFF_CHAIN),
            "NOT_INITIALIZED_VOTER"
        );
        IVoteProxySigner(voteProxy).modifyTeam(member, approval);
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
        require(voteAmount > 0, "NON_ZERO_AMOUNT");
        uint256 totalParent = IERC20(branchInfo.parentTokenAddress).balanceOf(
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

        emit RegisterMember(memberAddr, voteAmount, rewardAmount);
    }

    /// @dev Batch add member allocation
    function addBatchAllocation(AllocationInput[] memory inputArr)
        external
        onlyOwner
    {
        require(inputArr.length < 10, "EXCEED_BATCH_LIMIT");
        for (uint256 i = 0; i < inputArr.length; i++) {
            addMemberAllocation(
                inputArr[i].memberAddr,
                inputArr[i].voteAmount,
                inputArr[i].rewardAmount
            );
        }
    }

    /// @dev member claim their token allocation
    /// @param amount amount of token they want to claim
    function memberClaimToken(uint256 amount) external {
        require(amount > 0, "NO_CLAIM_ZERO");
        MemberInfo storage member = members[msg.sender];
        require(amount <= member.availableToken, "EXCEED_CLAIM_LIMIT");
        member.availableToken -= amount;
        _issueTo(msg.sender, amount);
        emit ClaimToken(msg.sender, amount);
    }

    /// @dev member claim their token allocation
    /// @param amount amount of token they want to claim
    function withdrawUnClaim(uint256 amount) external onlyOwner {
        require(amount > 0, "NO_WITHDRAW_UNCLAIM_ZERO");
        uint256 totalParent = IERC20(branchInfo.parentTokenAddress).balanceOf(
            address(this)
        );
        require(amount <= totalParent - totalAllocation, "EXCEED_CLAIM_LIMIT");
        _parentTransfer(address(this), msg.sender, amount);
    }

    /// @dev Initialize Branch Vote Token
    /// @param _name name of subtoken
    /// @param _symbol symbol of subtoken
    function _initToken(string memory _name, string memory _symbol) internal {
        require(managerState == ManagerState.NONE, "NOT_IN_NONE_STATE");
        SocotraVoteToken voteToken = new SocotraVoteToken(_name, _symbol);
        branchInfo.voteTokenAddress = address(voteToken);
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
        IERC20(branchInfo.parentTokenAddress).transferFrom(
            from,
            target,
            amount
        );
    }

    /// @dev Transfer Branch Token
    /// @param from from address
    /// @param target target address
    /// @param amount amount of token
    function _voteTransfer(
        address from,
        address target,
        uint256 amount
    ) internal {
        IERC20(branchInfo.voteTokenAddress).transferFrom(from, target, amount);
    }

    /// @dev Issue subtoken
    /// @param target name of subtoken
    /// @param amount symbol of subtoken
    function _issueTo(address target, uint256 amount) internal {
        SocotraVoteToken(branchInfo.voteTokenAddress)._managerMint(
            target,
            amount
        );
    }

    /// @dev Burn subtoken
    /// @param target name of subtoken
    /// @param amount symbol of subtoken
    function _burnFrom(address target, uint256 amount) internal {
        SocotraVoteToken(branchInfo.voteTokenAddress)._managerBurn(
            target,
            amount
        );
    }

    /// @dev Request payout for member
    /// @param amount amount of vote token
    /// @param receiver receiver address
    /// @param proof proof of task such as link to evidence
    function requestPayout(
        uint256 amount,
        address receiver,
        string memory proof
    ) external {
        require(amount > 0, "NON_ZERO_AMOUNT");
        MemberInfo storage member = members[msg.sender];
        require(
            amount + member.claimingToken <= member.totalToken,
            "EXCEED_TOTAL"
        );
        member.claimingToken += amount;
        _voteTransfer(msg.sender, address(this), amount);
        payouts[payoutCount] = Payout({
            amount: amount,
            issuer: msg.sender,
            receiver: receiver,
            proof: proof,
            isPaid: false
        });
        emit RequestPayout(payoutCount, amount, msg.sender, receiver, proof);
        payoutCount++;
    }

    /// @dev Withdraw the payout
    /// @param payoutId id of requested payout
    function withdrawPayout(uint256 payoutId) external {
        MemberInfo storage member = members[msg.sender];
        Payout storage payout = payouts[payoutId];
        require(payout.isPaid == false, "ALREADY_PAYOUT");
        payout.isPaid = true;
        member.claimingToken -= payout.amount;
        _voteTransfer(address(this), payout.receiver, payout.amount);
        emit WithdrawPayout(payoutId);
    }

    /// @dev Subdao owner confirm to send fund to member
    /// @param payoutId id of requested payout
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
        member.totalToken -= payout.amount;
        payout.isPaid = true;
        _parentTransfer(address(this), payout.receiver, payoutAmount);
        emit IssuePayout(payoutId);
    }

    /// @dev Batch issue payout
    function batchIssuePayout(uint256[] memory payoutIds) public onlyOwner {
        require(payoutIds.length < 10, "EXCEED_PAYOUT_LIMIT");
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
