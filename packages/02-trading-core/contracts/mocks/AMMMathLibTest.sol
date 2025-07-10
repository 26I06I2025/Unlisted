// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../lib/AMMMathLib.sol";

/**
 * @title AMMMathLibTest
 * @notice Test contract to expose AMMMathLib functions for testing
 * @dev This contract is only used for testing the pure functions in AMMMathLib
 */
contract AMMMathLibTest {
    
    function calculateMarkPrice(
        uint256 reserve_vUSDC,
        uint256 reserve_vTokenX
    ) external pure returns (uint256) {
        return AMMMathLib.calculateMarkPrice(reserve_vUSDC, reserve_vTokenX);
    }

    function calculateLongOpen(
        uint256 collateralAmount,
        uint256 reserve_vUSDC,
        uint256 reserve_vTokenX
    ) external pure returns (
        uint256 vTokenAmount,
        uint256 newReserve_vUSDC,
        uint256 newReserve_vTokenX
    ) {
        return AMMMathLib.calculateLongOpen(collateralAmount, reserve_vUSDC, reserve_vTokenX);
    }

    function calculateShortOpen(
        uint256 collateralAmount,
        uint256 reserve_vUSDC,
        uint256 reserve_vTokenX
    ) external pure returns (
        uint256 vTokenAmount,
        uint256 newReserve_vUSDC,
        uint256 newReserve_vTokenX
    ) {
        return AMMMathLib.calculateShortOpen(collateralAmount, reserve_vUSDC, reserve_vTokenX);
    }

    function calculateLongClose(
        uint256 positionSize,
        uint256 collateral,
        uint256 reserve_vUSDC,
        uint256 reserve_vTokenX
    ) external pure returns (
        int256 pnl,
        uint256 newReserve_vUSDC,
        uint256 newReserve_vTokenX
    ) {
        return AMMMathLib.calculateLongClose(positionSize, collateral, reserve_vUSDC, reserve_vTokenX);
    }

    function calculateShortClose(
        uint256 positionSize,
        uint256 collateral,
        uint256 reserve_vUSDC,
        uint256 reserve_vTokenX
    ) external pure returns (
        int256 pnl,
        uint256 newReserve_vUSDC,
        uint256 newReserve_vTokenX
    ) {
        return AMMMathLib.calculateShortClose(positionSize, collateral, reserve_vUSDC, reserve_vTokenX);
    }
} 