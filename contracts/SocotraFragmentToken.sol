pragma solidity ^0.8.11;
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

contract SocotraFragmentToken is ERC1155, Ownable {
    enum TokenState {
        NONE,
        PENDING,
        INITIALIZED
    }

    struct ParentInfo {
        address parentAddress;
        uint256 tokenId;
        bool isERC1155;
    }

    struct Payout {
        uint256 tokenId;
        uint256 amount;
        address receiver;
        bytes proof;
        bool isPaid;
    }

    TokenState public tokenState;

    address public controller;
    uint256 public totalAllocPoint;
    ParentInfo public parent;
    uint256 registeredId;
    mapping(uint256 => Payout) payouts;
    uint256 payoutIds;
    mapping(uint256 => TokenMetadata) tokenInfos;

    struct TokenMetadata {
        uint256 totalSupply;
        uint256 rewardPoint;
        address tokenOwner;
    }

    constructor(
        address _controller,
        address _parentToken,
        uint256 _tokenId,
        bool _isERC1155,
        address _issuer
    ) ERC1155("") {
        controller = _controller;
        parent.parentAddress = _parentToken;
        parent.tokenId = _tokenId;
        parent.isERC1155 = _isERC1155;
        tokenState = TokenState.PENDING;
        _transferOwnership(_issuer);
    }

    modifier onlyReadyState() {
        require(tokenState == TokenState.INITIALIZED);
        _;
    }

    modifier onlyNotReadyState() {
        require(tokenState != TokenState.INITIALIZED);
        _;
    }

    modifier onlyTokenOwner(uint256 tokenId, address _owner) {
        require(_owner == tokenInfos[tokenId].tokenOwner, "NOT_TOKEN_OWNER");
        _;
    }

    modifier onlyController() {
        require(msg.sender == controller, "NOT_CONTROLLER");
        _;
    }

    function _withdrawParentERC20(address target)
        public
        onlyController
        onlyNotReadyState
    {
        uint256 amount = IERC20(parent.parentAddress).balanceOf(address(this));
        IERC20(parent.parentAddress).transferFrom(
            address(this),
            target,
            amount
        );
    }

    function _withdrawParentERC1155(address target)
        public
        onlyController
        onlyNotReadyState
    {
        uint256 amount = IERC1155(parent.parentAddress).balanceOf(
            address(this),
            parent.tokenId
        );
        IERC1155(parent.parentAddress).safeTransferFrom(
            address(this),
            target,
            parent.tokenId,
            amount,
            ""
        );
    }

    function _parentTransferTo(address target, uint256 amount) internal {
        if (parent.isERC1155) {
            IERC1155(parent.parentAddress).safeTransferFrom(
                address(this),
                target,
                parent.tokenId,
                amount,
                ""
            );
        } else {
            IERC20(parent.parentAddress).transferFrom(
                address(this),
                target,
                amount
            );
        }
    }

    function _registerToken(uint256 rewardPoint, address tokenOwner)
        external
        onlyReadyState
        onlyController
    {
        tokenInfos[registeredId].rewardPoint = rewardPoint;
        tokenInfos[registeredId].tokenOwner = tokenOwner;
        _setApprovalForAll(controller, tokenOwner, true);
        totalAllocPoint += rewardPoint;
        registeredId++;
    }

    function _controllerBurn(
        address target,
        uint256 tokenId,
        uint256 amount
    ) external onlyController {
        _burn(target, tokenId, amount);
    }

    function _controllerMint(
        address target,
        uint256 tokenId,
        uint256 amount,
        bytes memory data
    ) external onlyController {
        _mint(target, tokenId, amount, data);
    }

    function calPayoutAmount(uint256 tokenId, uint256 amount)
        public
        view
        returns (uint256)
    {
        uint256 totalAmount = getParentAmount();
        return
            (amount * tokenInfos[tokenId].rewardPoint * totalAmount) /
            totalAllocPoint;
    }

    function getParentAmount() public view returns (uint256) {
        if (parent.isERC1155) {
            return
                IERC1155(parent.parentAddress).balanceOf(
                    address(this),
                    parent.tokenId
                );
        }
        return IERC20(parent.parentAddress).balanceOf(address(this));
    }

    function requestPayout(
        uint256 tokenId,
        uint256 amount,
        address receiver,
        bytes memory proof
    ) public {
        require(amount > 0, "NO_ZERO_PAYPOUT");
        safeTransferFrom(msg.sender, address(this), tokenId, amount, "");
        payouts[payoutIds] = Payout({
            tokenId: tokenId,
            amount: amount,
            receiver: receiver,
            proof: proof,
            isPaid: false
        });
    }

    function withdrawPayout(uint256 payoutId) public {
        Payout storage payout = payouts[payoutId];
        payout.isPaid = true;
        safeTransferFrom(
            address(this),
            payout.receiver,
            payout.tokenId,
            payout.amount,
            ""
        );
    }

    function issuePayout(uint256 payoutId) external onlyController {
        Payout storage payout = payouts[payoutId];
        require(payout.isPaid == false, "ALREADY_PAYOUT");
        _burn(address(this), payout.tokenId, payout.amount);
        uint256 payoutAmount = calPayoutAmount(payout.tokenId, payout.amount);
        _parentTransferTo(payout.receiver, payoutAmount);
        payout.isPaid = true;
    }
}
