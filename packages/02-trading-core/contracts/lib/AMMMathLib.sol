// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./FixedPointMathLib.sol";

/**
 * @title AMMMathLib
 * @notice Pure mathematical functions for AMM trading calculations
 * @dev This library contains all the trading logic without any state management.
 * All functions are pure and can be tested independently.
 */
library AMMMathLib {
    using FixedPointMathLib for uint256;

    /**
     * @notice Calculates the vTokenX amount and new reserves for a LONG position opening
     * @param collateralAmount Amount of USDC collateral provided
     * @param reserve_vUSDC Current vUSDC reserves
     * @param reserve_vTokenX Current vTokenX reserves
     * @return vTokenAmount Amount of vTokenX received
     * @return newReserve_vUSDC New vUSDC reserves after trade
     * @return newReserve_vTokenX New vTokenX reserves after trade
     */
    function calculateLongOpen(
        uint256 collateralAmount,
        uint256 reserve_vUSDC,
        uint256 reserve_vTokenX
    ) internal pure returns (
        uint256 vTokenAmount,
        uint256 newReserve_vUSDC,
        uint256 newReserve_vTokenX
    ) {
        // Calculate how much vTokenX we get for the collateral
        vTokenAmount = FixedPointMathLib.getAmountOut(collateralAmount, reserve_vUSDC, reserve_vTokenX);
        require(vTokenAmount <= reserve_vTokenX, "AMM: Insufficient vTokenX liquidity");
        
        // Calculate new reserves
        newReserve_vUSDC = reserve_vUSDC + collateralAmount;
        newReserve_vTokenX = reserve_vTokenX - vTokenAmount;
    }

    /**
     * @notice Calculates the vTokenX amount and new reserves for a SHORT position opening
     * @param collateralAmount Amount of USDC collateral provided
     * @param reserve_vUSDC Current vUSDC reserves
     * @param reserve_vTokenX Current vTokenX reserves
     * @return vTokenAmount Amount of vTokenX to "sell"
     * @return newReserve_vUSDC New vUSDC reserves after trade
     * @return newReserve_vTokenX New vTokenX reserves after trade
     */
    function calculateShortOpen(
        uint256 collateralAmount,
        uint256 reserve_vUSDC,
        uint256 reserve_vTokenX
    ) internal pure returns (
        uint256 vTokenAmount,
        uint256 newReserve_vUSDC,
        uint256 newReserve_vTokenX
    ) {
        // Calculate how much vTokenX to "sell" to get the collateral amount
        vTokenAmount = FixedPointMathLib.getAmountIn(collateralAmount, reserve_vTokenX, reserve_vUSDC);
        require(vTokenAmount <= reserve_vTokenX, "AMM: Insufficient vTokenX liquidity");
        
        // Calculate new reserves
        newReserve_vUSDC = reserve_vUSDC - collateralAmount;
        newReserve_vTokenX = reserve_vTokenX + vTokenAmount;
    }

    /**
     * @notice Calculates PnL and new reserves for a LONG position closing
     * @param positionSize Size of the position in vTokenX
     * @param collateral Original collateral amount
     * @param reserve_vUSDC Current vUSDC reserves
     * @param reserve_vTokenX Current vTokenX reserves
     * @return pnl Profit/Loss in USDC (can be negative)
     * @return newReserve_vUSDC New vUSDC reserves after trade
     * @return newReserve_vTokenX New vTokenX reserves after trade
     */
    function calculateLongClose(
        uint256 positionSize,
        uint256 collateral,
        uint256 reserve_vUSDC,
        uint256 reserve_vTokenX
    ) internal pure returns (
        int256 pnl,
        uint256 newReserve_vUSDC,
        uint256 newReserve_vTokenX
    ) {
        // Calculate how much vUSDC we get back by selling the vTokenX
        uint256 vUsdcOut = FixedPointMathLib.getAmountOut(positionSize, reserve_vTokenX, reserve_vUSDC);
        require(vUsdcOut <= reserve_vUSDC, "AMM: Insufficient vUSDC liquidity");
        
        // Calculate PnL
        pnl = int256(vUsdcOut) - int256(collateral);
        
        // Calculate new reserves
        newReserve_vUSDC = reserve_vUSDC - vUsdcOut;
        newReserve_vTokenX = reserve_vTokenX + positionSize;
    }

    /**
     * @notice Calculates PnL and new reserves for a SHORT position closing
     * @param positionSize Size of the position in vTokenX
     * @param collateral Original collateral amount
     * @param reserve_vUSDC Current vUSDC reserves
     * @param reserve_vTokenX Current vTokenX reserves
     * @return pnl Profit/Loss in USDC (can be negative)
     * @return newReserve_vUSDC New vUSDC reserves after trade
     * @return newReserve_vTokenX New vTokenX reserves after trade
     */
    function calculateShortClose(
        uint256 positionSize,
        uint256 collateral,
        uint256 reserve_vUSDC,
        uint256 reserve_vTokenX
    ) internal pure returns (
        int256 pnl,
        uint256 newReserve_vUSDC,
        uint256 newReserve_vTokenX
    ) {
        // Calculate how much vUSDC it costs to buy back the vTokenX
        uint256 vUsdcCost = FixedPointMathLib.getAmountIn(positionSize, reserve_vUSDC, reserve_vTokenX);
        require(positionSize <= reserve_vTokenX, "AMM: Insufficient vTokenX liquidity");
        
        // Calculate PnL (profit if buyback costs less than original collateral)
        pnl = int256(collateral) - int256(vUsdcCost);
        
        // Calculate new reserves
        newReserve_vUSDC = reserve_vUSDC + vUsdcCost;
        newReserve_vTokenX = reserve_vTokenX - positionSize;
    }

    /**
     * @notice Calculates the current mark price from reserves
     * @param reserve_vUSDC Current vUSDC reserves
     * @param reserve_vTokenX Current vTokenX reserves
     * @return price Current mark price with 18 decimals precision
     */
    function calculateMarkPrice(
        uint256 reserve_vUSDC,
        uint256 reserve_vTokenX
    ) internal pure returns (uint256 price) {
        require(reserve_vTokenX > 0, "AMM: No vTokenX liquidity");
        return reserve_vUSDC.div(reserve_vTokenX);
    }
} 