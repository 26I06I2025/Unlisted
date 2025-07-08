// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IClearingHouse
 * @notice The main interface of the trading protocol.
 * @dev Defines the public API for interacting with the system.
 */
interface IClearingHouse {
    /**
     * @notice Enumeration to define the direction of a position.
     */
    enum Direction {
        LONG,
        SHORT
    }

    /**
     * @notice Structure to return position information in a readable format.
     * @param owner The current owner of the position (NFT holder).
     * @param marketToken The market token this position is for.
     * @param collateral The amount of collateral (in USDC) deposited.
     * @param direction The direction of the position (LONG or SHORT).
     * @param size The size of the position (in vToken).
     * @param entryPrice The price when position was opened.
     * @param timestamp When the position was opened.
     */
    struct PositionView {
        address owner;
        address marketToken;
        uint256 collateral;
        Direction direction;
        uint256 size;
        uint256 entryPrice;
        uint256 timestamp;
    }

    // === EVENTS ===
    
    /**
     * @notice Emitted when a new position is opened
     * @param positionId The unique ID of the position
     * @param user The address that opened the position
     * @param marketToken The market token being traded
     * @param direction LONG or SHORT
     * @param collateral Amount of USDC collateral deposited
     * @param size Position size in vTokenX
     * @param entryPrice Price at which the position was opened
     * @param timestamp When the position was opened
     */
    event PositionOpened(
        uint256 indexed positionId,
        address indexed user,
        address indexed marketToken,
        Direction direction,
        uint256 collateral,
        uint256 size,
        uint256 entryPrice,
        uint256 timestamp
    );

    /**
     * @notice Emitted when a position is closed
     * @param positionId The unique ID of the position
     * @param user The address that closed the position
     * @param pnl Profit/Loss in USDC (can be negative)
     * @param payout Total amount paid out to user
     * @param timestamp When the position was closed
     */
    event PositionClosed(
        uint256 indexed positionId,
        address indexed user,
        int256 pnl,
        uint256 payout,
        uint256 timestamp
    );

    /**
     * @notice Opens a new trading position.
     * @param marketToken The market token to trade (e.g., ETH, BTC).
     * @param collateralAmount The amount of collateral (USDC) to deposit.
     * @param direction The desired direction for the position (LONG or SHORT).
     * @return positionId The unique ID of the newly created position (which is also the NFT tokenId).
     */
    function openPosition(
        address marketToken,
        uint256 collateralAmount,
        Direction direction
    ) external returns (uint256 positionId);

    /**
     * @notice Closes an existing trading position.
     * @dev The PNL is calculated and funds (collateral +/- PNL) are sent to the position owner.
     * @param positionId The ID of the position to close.
     */
    function closePosition(uint256 positionId) external;

    /**
     * @notice Retrieves the current market price as defined by the vAMM.
     * @param marketToken The market token to get the price for.
     * @return price The current price, represented with 18 decimal precision.
     */
    function getMarkPrice(address marketToken) external view returns (uint256 price);

    /**
     * @notice Retrieves detailed information of a specific position.
     * @param positionId The ID of the position to query.
     * @return The PositionView structure with the position details.
     */
    function getPosition(
        uint256 positionId
    ) external view returns (PositionView memory);
}