// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./RuglessStakingPool.sol";

contract RuglessLiquidityPool is ReentrancyGuard {
    IERC20 public tokenA;
    IERC20 public tokenB;
    RuglessStakingPool public stakingPool;

    uint256 public reserveA;
    uint256 public reserveB;

    uint256 public maxStakePercentageA;
    uint256 public swapFeePercentage;

    mapping(address => uint256) public liquidityProvidersA;
    mapping(address => uint256) public liquidityProvidersB;

    event LiquidityAdded(
        address indexed provider,
        uint256 amountA,
        uint256 amountB
    );
    event LiquidityRemoved(
        address indexed provider,
        uint256 amountA,
        uint256 amountB
    );
    event SwapAForB(
        address indexed swapper,
        uint256 amountAIn,
        uint256 amountBOut,
        uint256 fee
    );
    event SwapBForA(
        address indexed swapper,
        uint256 amountBIn,
        uint256 amountAOut,
        uint256 fee
    );

    constructor(
        address _tokenA,
        address _tokenB,
        uint256 _swapFeePercentage,
        uint256 _unstakeFeePercentage,
        uint256 _maxStakePercentageA
    ) {
        tokenA = IERC20(_tokenA);
        tokenB = IERC20(_tokenB);
        swapFeePercentage = _swapFeePercentage;
        stakingPool = new RuglessStakingPool(
            address(tokenA),
            address(tokenB),
            address(this),
            _unstakeFeePercentage
        );
        maxStakePercentageA = _maxStakePercentageA;
    }

    function addLiquidity(
        uint256 amountA,
        uint256 amountB
    ) external nonReentrant {
        require(
            amountA > 0 && amountB > 0,
            "RuglessLiquidityPool: Amounts must be greater than zero"
        );

        require(
            tokenA.transferFrom(msg.sender, address(this), amountA),
            "RuglessLiquidityPool: Token A transfer failed"
        );
        require(
            tokenB.transferFrom(msg.sender, address(this), amountB),
            "RuglessLiquidityPool: Token B transfer failed"
        );

        liquidityProvidersA[msg.sender] += amountA;
        liquidityProvidersB[msg.sender] += amountB;

        reserveA += amountA;
        reserveB += amountB;

        emit LiquidityAdded(msg.sender, amountA, amountB);
    }

    function removeLiquidity(
        uint256 amountA,
        uint256 amountB
    ) external nonReentrant {
        require(
            amountA > 0 && amountB > 0,
            "RuglessLiquidityPool: Amounts must be greater than zero"
        );
        require(
            liquidityProvidersA[msg.sender] >= amountA,
            "RuglessLiquidityPool: Not enough Token A liquidity"
        );
        require(
            liquidityProvidersB[msg.sender] >= amountB,
            "RuglessLiquidityPool: Not enough Token B liquidity"
        );

        liquidityProvidersA[msg.sender] -= amountA;
        liquidityProvidersB[msg.sender] -= amountB;

        reserveA -= amountA;
        reserveB -= amountB;

        require(
            tokenA.transfer(msg.sender, amountA),
            "RuglessLiquidityPool: Token A transfer failed"
        );
        require(
            tokenB.transfer(msg.sender, amountB),
            "RuglessLiquidityPool: Token B transfer failed"
        );

        emit LiquidityRemoved(msg.sender, amountA, amountB);
    }

    function swapAForB(
        uint256 amountA,
        uint256 minAmountB
    ) external nonReentrant {
        require(
            amountA > 0,
            "RuglessLiquidityPool: Amount must be greater than zero"
        );
        require(reserveB > 0, "RuglessLiquidityPool: No liquidity for Token B");

        uint256 amountB = (amountA * reserveB) / (reserveA + amountA);
        uint256 fee = (amountB * swapFeePercentage) / 100;
        amountB -= fee;

        require(amountB >= minAmountB, "Slippage exceeded");

        reserveA += amountA;
        reserveB -= amountB;

        require(
            tokenA.transferFrom(msg.sender, address(this), amountA),
            "RuglessLiquidityPool: Token A transfer failed"
        );
        require(
            tokenB.transfer(msg.sender, amountB),
            "RuglessLiquidityPool: Token B transfer failed"
        );

        emit SwapAForB(msg.sender, amountA, amountB, fee);
    }

    function swapBForA(
        uint256 amountB,
        uint256 minAmountA,
        bool isStake
    ) external nonReentrant {
        require(
            amountB > 0,
            "RuglessLiquidityPool: Amount must be greater than zero"
        );
        require(reserveA > 0, "RuglessLiquidityPool: No liquidity for Token A");

        uint256 amountA = (amountB * reserveA) / (reserveB + amountB);
        uint256 fee = (amountA * swapFeePercentage) / 100;
        amountA -= fee;

        require(
            amountA >= minAmountA,
            "RuglessLiquidityPool: Slippage exceeded"
        );

        if (isStake) {
            require(
                (stakingPool.totalStakedA() + amountA) <
                    (maxStakePercentageA * reserveA) / 100,
                "RuglessLiquidityPool: Stake amount exceeds limit"
            );
            stakingPool.stake(amountA, amountB, msg.sender);
        } else {
            reserveB += amountB;
            reserveA -= amountA;

            require(
                tokenB.transferFrom(msg.sender, address(this), amountB),
                "RuglessLiquidityPool: Token B transfer failed"
            );
            require(
                tokenA.transfer(msg.sender, amountA),
                "RuglessLiquidityPool: Token A transfer failed"
            );
            emit SwapBForA(msg.sender, amountB, amountA, fee);
        }
    }

    function totalReserveA() public view returns (uint256) {
        return reserveA + stakingPool.totalStakedA();
    }

    function totalReserveB() public view returns (uint256) {
        return reserveB + stakingPool.totalStakedB();
    }
}
