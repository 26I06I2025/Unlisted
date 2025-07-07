// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title FixedPointMathLib
 * @author (Inspired by Solmate and other proven DeFi libraries)
 * @notice A library for performing fixed-point calculations with 18 decimals.
 * @dev Uses WAD (1e18) to represent decimal numbers.
 */
library FixedPointMathLib {
    // The WAD constant represents 1.0 with 18 decimals (10^18).
    // This is the standard used in most DeFi protocols for precision.
    uint256 private constant WAD = 1e18;

    /**
     * @notice Multiplies two fixed-point numbers (with 18 decimals).
     * @param a The first number.
     * @param b The second number.
     * @return The product, scaled to WAD.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0 || b == 0) {
            return 0;
        }
        // Prevent overflow before multiplication
        require(a <= type(uint256).max / b, "Math: mul overflow");

        // (a * WAD) * (b * WAD) / WAD = a * b * WAD
        // To return to WAD scale, we divide by WAD
        return (a * b) / WAD;
    }

    /**
     * @notice Divides two fixed-point numbers (with 18 decimals).
     * @param a The numerator.
     * @param b The denominator.
     * @return The quotient, scaled to WAD.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        // Prevent division by zero
        require(b > 0, "Math: div by zero");

        // To preserve precision, we multiply the numerator by WAD before division.
        // (a * WAD) / (b * WAD) * WAD = (a * WAD) / b
        return (a * WAD) / b;
    }

    /**
     * @notice Calculates the output amount for a given input amount in an AMM x*y=k.
     * @param amountIn The amount of the token entering the pool.
     * @param reserveIn The reserve of the token entering, before the swap.
     * @param reserveOut The reserve of the token exiting, before the swap.
     * @return amountOut The amount of the token exiting the pool.
     */
    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) internal pure returns (uint256 amountOut) {
        require(amountIn > 0, "AMM: insufficient input amount");
        require(reserveIn > 0 && reserveOut > 0, "AMM: insufficient liquidity");

        // The standard AMM formula: amountOut = (amountIn * reserveOut) / (reserveIn + amountIn)
        // We perform the multiplication first to preserve precision
        uint256 numerator = amountIn * reserveOut;
        uint256 denominator = reserveIn + amountIn;
        amountOut = numerator / denominator;

        return amountOut;
    }
}