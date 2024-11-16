// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./RuglessTreasury.sol";

contract RuglessStakingPool is ReentrancyGuard {
    IERC20 public tokenA;
    IERC20 public tokenB;
    address public feeRecipient;
    address public liquidityPool;
    uint256 public unstakeFeePercentage;

    struct Stake {
        uint256 amountA;
        uint256 amountB;
    }

    mapping(address => Stake) public stakes;
    uint256 public totalStakedA;
    uint256 public totalStakedB;

    event Staked(address indexed user, uint256 amountA, uint256 amountB);
    event Unstaked(
        address indexed user,
        uint256 amountA,
        uint256 amountB,
        uint256 fee
    );

    constructor(
        address _tokenA,
        address _tokenB,
        address _liquidityPool,
        uint256 _unstakeFeePercentage
    ) {
        require(
            _unstakeFeePercentage <= 100,
            "Fee percentage cannot exceed 100%"
        );
        tokenA = IERC20(_tokenA);
        tokenB = IERC20(_tokenB);
        RuglessTreasury treasury = new RuglessTreasury(_tokenA);
        feeRecipient = address(treasury);
        liquidityPool = _liquidityPool;
        unstakeFeePercentage = _unstakeFeePercentage;
    }

    modifier onlyLiquidityPool() {
        require(msg.sender == liquidityPool, "RuglessStakingPool: Caller is not a liquidity pool");
        _;
    }

    function stake(
        uint256 amountA,
        uint256 amountB,
        address user
    ) external onlyLiquidityPool {
        require(amountA > 0 && amountB > 0, "RuglessStakingPool: Cannot stake zero tokens");

        require(
            tokenA.transferFrom(user, address(this), amountA),
            "RuglessStakingPool: TokenA transfer failed"
        );
        require(
            tokenB.transferFrom(user, address(this), amountB),
            "RuglessStakingPool: TokenB transfer failed"
        );

        stakes[user].amountA += amountA;
        stakes[user].amountB += amountB;

        totalStakedA += amountA;
        totalStakedB += amountB;

        emit Staked(user, amountA, amountB);
    }

    function unstake() external nonReentrant {
        uint256 fee = (stakes[msg.sender].amountA * unstakeFeePercentage) / 100;
        uint256 userAmount = stakes[msg.sender].amountA - fee;

        totalStakedA -= stakes[msg.sender].amountA;
        totalStakedB -= stakes[msg.sender].amountB;

        require(tokenA.transfer(feeRecipient, fee), "RuglessStakingPool: Fee transfer failed");
        require(
            tokenA.transfer(msg.sender, userAmount),
            "RuglessStakingPool: TokenA transfer failed"
        );

        require(
            tokenB.transfer(msg.sender, stakes[msg.sender].amountB),
            "RuglessStakingPool: TokenB transfer failed"
        );

        emit Unstaked(
            msg.sender,
            stakes[msg.sender].amountA,
            stakes[msg.sender].amountB,
            fee
        );

        stakes[msg.sender].amountA = 0;
        stakes[msg.sender].amountB = 0;
    }

    function getStakedBalance(
        address user
    ) external view returns (uint256 amountA, uint256 amountB) {
        return (stakes[user].amountA, stakes[user].amountB);
    }
}
