// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../../../02-trading-core/contracts/interfaces/IClearingHouse.sol";

/**
 * @title IReader
 * @notice Interface for the Reader contract - provides batch reads and enriched data
 * @dev This contract aggregates data from ClearingHouse for better frontend performance
 */
interface IReader {
    /**
     * @notice Structure for position data enriched with current PnL
     * @param positionId The unique ID of the position
     * @param owner The current owner of the position
     * @param marketToken The market token being traded
     * @param collateral Amount of USDC collateral deposited
     * @param direction LONG or SHORT
     * @param size Position size in vTokenX
     * @param entryPrice Price when position was opened
     * @param currentPrice Current market price
     * @param unrealizedPnl Current unrealized PnL (can be negative)
     * @param timestamp When the position was opened
     */
    struct PositionWithPnL {
        uint256 positionId;
        address owner;
        address marketToken;
        uint256 collateral;
        IClearingHouse.Direction direction;
        uint256 size;
        uint256 entryPrice;
        uint256 currentPrice;
        int256 unrealizedPnl;
        uint256 timestamp;
    }

    /**
     * @notice Structure for market data aggregation
     * @param marketToken The market token address
     * @param currentPrice Current market price
     * @param reserve_vUSDC Current vUSDC reserves
     * @param reserve_vTokenX Current vTokenX reserves
     * @param isActive Whether the market is active for trading
     */
    struct MarketData {
        address marketToken;
        uint256 currentPrice;
        uint256 reserve_vUSDC;
        uint256 reserve_vTokenX;
        bool isActive;
    }

    /**
     * @notice Batch read multiple positions with real-time PnL calculation
     * @param positionIds Array of position IDs to read
     * @return positions Array of positions with current PnL data
     */
    function getPositionsWithPnL(uint256[] calldata positionIds) 
        external view returns (PositionWithPnL[] memory positions);

    /**
     * @notice Get single position with real-time PnL calculation
     * @param positionId The position ID to read
     * @return position Position data with current PnL
     */
    function getPositionWithPnL(uint256 positionId) 
        external view returns (PositionWithPnL memory position);

    /**
     * @notice Get comprehensive market data
     * @param marketToken The market token to get data for
     * @return market Complete market information
     */
    function getMarketData(address marketToken) 
        external view returns (MarketData memory market);

    /**
     * @notice Batch read market data for multiple markets
     * @param marketTokens Array of market tokens
     * @return markets Array of market data
     */
    function getMarketsData(address[] calldata marketTokens) 
        external view returns (MarketData[] memory markets);
} 