// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./interfaces/IReader.sol";
import "./interfaces/IClearingHouse.sol";
import "./ClearingHouse.sol";

/**
 * @title Reader
 * @notice Provides batch reads and enriched data from ClearingHouse
 * @dev This contract aggregates multiple calls and performs calculations for better frontend UX
 */
contract Reader is IReader {
    ClearingHouse public immutable clearingHouse;

    /**
     * @notice Initialize the Reader with ClearingHouse address
     * @param _clearingHouse Address of the ClearingHouse contract
     */
    constructor(address _clearingHouse) {
        require(_clearingHouse != address(0), "Reader: Invalid ClearingHouse address");
        clearingHouse = ClearingHouse(_clearingHouse);
    }

    /**
     * @inheritdoc IReader
     */
    function getPositionsWithPnL(uint256[] calldata positionIds) 
        external view override returns (PositionWithPnL[] memory positions) {
        
        positions = new PositionWithPnL[](positionIds.length);
        
        for (uint256 i = 0; i < positionIds.length; i++) {
            positions[i] = getPositionWithPnL(positionIds[i]);
        }
    }

    /**
     * @inheritdoc IReader
     */
    function getPositionWithPnL(uint256 positionId) 
        public view override returns (PositionWithPnL memory position) {
        
        // Get position data from ClearingHouse
        IClearingHouse.PositionView memory pos = clearingHouse.getPosition(positionId);
        
        // Calculate current market price
        uint256 currentPrice = clearingHouse.getMarkPrice(pos.marketToken);
        
        // Calculate unrealized PnL
        int256 unrealizedPnl = _calculateUnrealizedPnL(
            pos.direction,
            pos.size,
            pos.entryPrice,
            currentPrice
        );

        // Return enriched position data
        position = PositionWithPnL({
            positionId: positionId,
            owner: pos.owner,
            marketToken: pos.marketToken,
            collateral: pos.collateral,
            direction: pos.direction,
            size: pos.size,
            entryPrice: pos.entryPrice,
            currentPrice: currentPrice,
            unrealizedPnl: unrealizedPnl,
            timestamp: pos.timestamp
        });
    }

    /**
     * @inheritdoc IReader
     */
    function getMarketData(address marketToken) 
        external view override returns (MarketData memory market) {
        
        // Get market info from ClearingHouse
        (uint256 reserve_vUSDC, uint256 reserve_vTokenX, bool isActive) = clearingHouse.markets(marketToken);
        
        // Calculate current price
        uint256 currentPrice = clearingHouse.getMarkPrice(marketToken);

        market = MarketData({
            marketToken: marketToken,
            currentPrice: currentPrice,
            reserve_vUSDC: reserve_vUSDC,
            reserve_vTokenX: reserve_vTokenX,
            isActive: isActive
        });
    }

    /**
     * @inheritdoc IReader
     */
    function getMarketsData(address[] calldata marketTokens) 
        external view override returns (MarketData[] memory markets) {
        
        markets = new MarketData[](marketTokens.length);
        
        for (uint256 i = 0; i < marketTokens.length; i++) {
            markets[i] = this.getMarketData(marketTokens[i]);
        }
    }

    /**
     * @notice Calculate unrealized PnL for a position
     * @dev Simple calculation: (currentPrice - entryPrice) * size for LONG,
     *      (entryPrice - currentPrice) * size for SHORT
     * @param direction LONG or SHORT
     * @param size Position size in vTokenX
     * @param entryPrice Price when position was opened
     * @param currentPrice Current market price
     * @return pnl Unrealized PnL (can be negative)
     */
    function _calculateUnrealizedPnL(
        IClearingHouse.Direction direction,
        uint256 size,
        uint256 entryPrice,
        uint256 currentPrice
    ) internal pure returns (int256 pnl) {
        if (direction == IClearingHouse.Direction.LONG) {
            // LONG: profit if current > entry
            pnl = int256(currentPrice) - int256(entryPrice);
        } else {
            // SHORT: profit if current < entry  
            pnl = int256(entryPrice) - int256(currentPrice);
        }
        
        // Multiply by position size (with proper scaling)
        pnl = (pnl * int256(size)) / int256(1e18);
    }
} 