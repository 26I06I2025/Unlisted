// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./interfaces/IClearingHouse.sol";
import "./interfaces/IVault.sol";
import "./PositionToken.sol";
import "./lib/AMMMathLib.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title ClearingHouse
 * @notice The main contract that manages trading logic, vAMM and positions.
 * @dev This contract is the orchestrator. It doesn't hold any funds itself.
 */
contract ClearingHouse is IClearingHouse, ReentrancyGuard {

    // --- External dependencies ---
    IVault public immutable vault;
    PositionToken public immutable positionToken;
    IERC20 public immutable usdc;

    // --- vAMM (Virtual Automated Market Maker) state ---
    uint256 public reserve_vUSDC;
    uint256 public reserve_vTokenX;

    // --- Position storage ---
    struct Position {
        uint256 collateral; // Amount of collateral in USDC
        Direction direction; // LONG or SHORT
        uint256 size; // Position size in vTokenX
    }
    mapping(uint256 => Position) public positions;
    uint256 private _nextPositionId;

    /**
     * @notice Initializes the ClearingHouse.
     * @dev The vAMM's k is not stored, it's implicit in the reserves.
     */
    constructor(
        address _vaultAddress,
        address _positionTokenAddress,
        address _usdcAddress,
        uint256 _initial_vUSDC,
        uint256 _initial_vTokenX
    ) {
        vault = IVault(_vaultAddress);
        positionToken = PositionToken(_positionTokenAddress);
        usdc = IERC20(_usdcAddress);
        reserve_vUSDC = _initial_vUSDC;
        reserve_vTokenX = _initial_vTokenX;
        _nextPositionId = 1;
    }

    /**
     * @inheritdoc IClearingHouse
     */
    function openPosition(
        uint256 collateralAmount,
        Direction direction
    ) external override nonReentrant returns (uint256 positionId) {
        require(collateralAmount > 0, "ClearingHouse: Collateral must be positive");

        // --- Calculations (delegated to AMMMathLib) ---
        uint256 vTokenAmount;
        uint256 newReserve_vUSDC;
        uint256 newReserve_vTokenX;
        
        if (direction == Direction.LONG) {
            (vTokenAmount, newReserve_vUSDC, newReserve_vTokenX) = AMMMathLib.calculateLongOpen(
                collateralAmount, reserve_vUSDC, reserve_vTokenX
            );
        } else { // SHORT
            (vTokenAmount, newReserve_vUSDC, newReserve_vTokenX) = AMMMathLib.calculateShortOpen(
                collateralAmount, reserve_vUSDC, reserve_vTokenX
            );
        }
        
        // Update reserves
        reserve_vUSDC = newReserve_vUSDC;
        reserve_vTokenX = newReserve_vTokenX;

        positionId = _nextPositionId++;

        positions[positionId] = Position({
            collateral: collateralAmount,
            direction: direction,
            size: vTokenAmount
        });

        // --- Interactions with other contracts ---
        usdc.transferFrom(msg.sender, address(this), collateralAmount);
        usdc.approve(address(vault), collateralAmount);
        vault.deposit(collateralAmount);
        positionToken.mint(msg.sender, positionId);
    }

    /**
     * @inheritdoc IClearingHouse
     */
    function closePosition(uint256 positionId) external override nonReentrant {
        Position storage pos = positions[positionId];
        address owner = positionToken.ownerOf(positionId);
        require(owner == msg.sender, "ClearingHouse: Caller is not the owner of the position");

        // --- Calculations (delegated to AMMMathLib) ---
        int256 pnl;
        uint256 newReserve_vUSDC;
        uint256 newReserve_vTokenX;
        
        if (pos.direction == Direction.LONG) {
            (pnl, newReserve_vUSDC, newReserve_vTokenX) = AMMMathLib.calculateLongClose(
                pos.size, pos.collateral, reserve_vUSDC, reserve_vTokenX
            );
        } else { // SHORT
            (pnl, newReserve_vUSDC, newReserve_vTokenX) = AMMMathLib.calculateShortClose(
                pos.size, pos.collateral, reserve_vUSDC, reserve_vTokenX
            );
        }
        
        // Update reserves
        reserve_vUSDC = newReserve_vUSDC;
        reserve_vTokenX = newReserve_vTokenX;
        
        // MODIFIED: Payment logic greatly simplified and secured thanks to int256.
        uint256 payoutAmount = 0;
        int256 totalToReturn = int256(pos.collateral) + pnl;

        if (totalToReturn > 0) {
            payoutAmount = uint256(totalToReturn);
        }
        
        delete positions[positionId];
        
        // --- Interactions with other contracts ---
        positionToken.burn(positionId);
        if (payoutAmount > 0) {
            vault.withdraw(owner, payoutAmount);
        }
    }

    // --- View functions ---

    /**
     * @inheritdoc IClearingHouse
     */
    function getMarkPrice() external view override returns (uint256 price) {
        return AMMMathLib.calculateMarkPrice(reserve_vUSDC, reserve_vTokenX);
    }

    /**
     * @inheritdoc IClearingHouse
     */
    function getPosition(
        uint256 positionId
    ) external view override returns (PositionView memory) {
        Position storage pos = positions[positionId];
        require(pos.collateral > 0, "Position does not exist");
        address owner = positionToken.ownerOf(positionId);
        return PositionView({
            owner: owner,
            collateral: pos.collateral,
            direction: pos.direction,
            size: pos.size
        });
    }
}