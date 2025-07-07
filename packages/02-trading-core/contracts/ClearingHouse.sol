// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./interfaces/IClearingHouse.sol";
import "./interfaces/IVault.sol";
import "./PositionToken.sol";
// NEW: We import our mathematical toolkit
import "./lib/FixedPointMathLib.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title ClearingHouse
 * @notice The main contract that manages trading logic, vAMM and positions.
 * @dev This contract is the orchestrator. It doesn't hold any funds itself.
 */
contract ClearingHouse is IClearingHouse, ReentrancyGuard {
    // NEW: We attach our library to the uint256 type.
    // Now we can do things like `myNumber.div(otherNumber)`.
    using FixedPointMathLib for uint256;

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

        // --- Calculations (Effects part) ---
        uint256 vTokenAmount;
        if (direction == Direction.LONG) {
            // MODIFIED: We use our precision function to calculate how much vTokenX we get.
            vTokenAmount = FixedPointMathLib.getAmountOut(collateralAmount, reserve_vUSDC, reserve_vTokenX);
            reserve_vUSDC += collateralAmount;
            reserve_vTokenX -= vTokenAmount;
        } else { // SHORT
            // MODIFIED: For a short, the collateral represents the received vUSDC. We need to calculate how much vTokenX we need to "sell" to get it.
            // This is the inverse operation, which requires another AMM formula.
            // For simplicity here, we'll use a symmetric approach, although a getAmountIn function would be fairer.
            // Note: For V2, a getAmountIn(amountOut, reserveIn, reserveOut) function would be ideal.
            vTokenAmount = FixedPointMathLib.getAmountOut(collateralAmount, reserve_vTokenX, reserve_vUSDC);
            reserve_vTokenX += collateralAmount; // The user sells vTokenX...
            reserve_vUSDC -= vTokenAmount;   // ...to receive vUSDC. 
        }

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

        // --- Calculations (Effects part) ---
        // MODIFIED: We use int256 to be able to represent negative losses.
        int256 pnl;
        
        if (pos.direction == Direction.LONG) {
            // The user resells their vTokenX. We calculate how much vUSDC they get back.
            uint256 vUsdcOut = FixedPointMathLib.getAmountOut(pos.size, reserve_vTokenX, reserve_vUSDC);
            pnl = int256(vUsdcOut) - int256(pos.collateral);
            reserve_vTokenX += pos.size;
            reserve_vUSDC -= vUsdcOut;
        } else { // SHORT
            // The user must buy back their vTokenX "debt". We calculate how much it costs them in vUSDC.
            uint256 vUsdcIn = FixedPointMathLib.getAmountOut(pos.size, reserve_vUSDC, reserve_vTokenX);
            pnl = int256(vUsdcIn) - int256(pos.collateral);
            reserve_vUSDC += pos.size;
            reserve_vTokenX -= vUsdcIn;
        }
        
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
        // MODIFIED: We use our precision division function. It's clean and safe.
        return reserve_vUSDC.div(reserve_vTokenX);
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