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
     * @param collateral The amount of collateral (in USDC) deposited.
     * @param direction The direction of the position (LONG or SHORT).
     * @param size The size of the position (in vToken).
     */
    struct PositionView {
        address owner;
        uint256 collateral;
        Direction direction;
        uint256 size;
    }

    /**
     * @notice Opens a new trading position.
     * @param collateralAmount The amount of collateral (USDC) to deposit.
     * @param direction The desired direction for the position (LONG or SHORT).
     * @return positionId The unique ID of the newly created position (which is also the NFT tokenId).
     */
    function openPosition(
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
     * @return price The current price, represented with 18 decimal precision.
     */
    function getMarkPrice() external view returns (uint256 price);

    /**
     * @notice Retrieves detailed information of a specific position.
     * @param positionId The ID of the position to query.
     * @return The PositionView structure with the position details.
     */
    function getPosition(
        uint256 positionId
    ) external view returns (PositionView memory);
}