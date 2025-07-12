// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./interfaces/IClearingHouse.sol";
import "./interfaces/IVault.sol";
import "./PositionToken.sol";
import "./lib/AMMMathLib.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "../../01-registry/contracts/interfaces/ITradingCore.sol";
import "../../01-registry/contracts/interfaces/IRegistry.sol";

/**
 * @title ClearingHouse
 * @notice The main contract that manages trading logic, vAMM and positions.
 * @dev This contract is the orchestrator. It doesn't hold any funds itself.
 */
contract ClearingHouse is IClearingHouse, ITradingCore, ReentrancyGuard {

    // --- External dependencies ---
    IVault public immutable vault;
    PositionToken public immutable positionToken;
    IERC20 public immutable usdc;
    address public immutable registry;  // Registry reference for reserves synchronization

    // --- Multi-market vAMM state ---
    struct Market {
        uint256 reserve_vUSDC;
        uint256 reserve_vTokenX;
        IRegistry.MarketStatus status;  // Synchronized status from Registry
    }
    mapping(address => Market) public markets;

    // --- Position storage ---
    struct Position {
        address marketToken; // Which market this position is for
        uint256 collateral; // Amount of collateral in USDC
        Direction direction; // LONG or SHORT
        uint256 size; // Position size in vTokenX
        uint256 entryPrice; // Price when position was opened
        uint256 timestamp; // When position was opened
    }
    mapping(uint256 => Position) public positions;
    uint256 private _nextPositionId;
    
    // Number of open positions per market
    mapping(address => uint256) public openPositionCount;

    /**
     * @notice Initializes the ClearingHouse.
     */
    constructor(
        address _vaultAddress,
        address _positionTokenAddress,
        address _usdcAddress,
        address _registryAddress
    ) {
        vault = IVault(_vaultAddress);
        positionToken = PositionToken(_positionTokenAddress);
        usdc = IERC20(_usdcAddress);
        registry = _registryAddress;
        _nextPositionId = 1;
    }

    /**
     * @inheritdoc IClearingHouse
     */
    function openPosition(
        address marketToken,
        uint256 collateralAmount,
        Direction direction
    ) external override nonReentrant returns (uint256 positionId) {
        require(collateralAmount > 0, "ClearingHouse: Collateral must be positive");
        
        Market storage market = markets[marketToken];
        require(market.status == IRegistry.MarketStatus.Active, "ClearingHouse: Market not active");

        // --- Calculations (delegated to AMMMathLib) ---
        uint256 vTokenAmount;
        uint256 newReserve_vUSDC;
        uint256 newReserve_vTokenX;
        
        if (direction == Direction.LONG) {
            (vTokenAmount, newReserve_vUSDC, newReserve_vTokenX) = AMMMathLib.calculateLongOpen(
                collateralAmount, market.reserve_vUSDC, market.reserve_vTokenX
            );
        } else { // SHORT
            (vTokenAmount, newReserve_vUSDC, newReserve_vTokenX) = AMMMathLib.calculateShortOpen(
                collateralAmount, market.reserve_vUSDC, market.reserve_vTokenX
            );
        }
        
        positionId = _nextPositionId++;

        // Calculate entry price before opening position
        uint256 entryPrice = AMMMathLib.calculateMarkPrice(market.reserve_vUSDC, market.reserve_vTokenX);
        
        // Update reserves
        market.reserve_vUSDC = newReserve_vUSDC;
        market.reserve_vTokenX = newReserve_vTokenX;

        positions[positionId] = Position({
            marketToken: marketToken,
            collateral: collateralAmount,
            direction: direction,
            size: vTokenAmount,
            entryPrice: entryPrice,
            timestamp: block.timestamp
        });

        // Increment position count for this market
        openPositionCount[marketToken]++;

        // --- Interactions with other contracts ---
        usdc.transferFrom(msg.sender, address(this), collateralAmount);
        usdc.approve(address(vault), collateralAmount);
        vault.deposit(collateralAmount);
        positionToken.mint(msg.sender, positionId);

        // --- Emit event for indexing ---
        emit PositionOpened(
            positionId,
            msg.sender,
            marketToken,
            direction,
            collateralAmount,
            vTokenAmount,
            entryPrice,
            block.timestamp
        );
    }

    /**
     * @inheritdoc IClearingHouse
     */
    function closePosition(uint256 positionId) external override nonReentrant {
        Position storage pos = positions[positionId];
        address owner = positionToken.ownerOf(positionId);
        require(owner == msg.sender, "ClearingHouse: Caller is not the owner of the position");

        Market storage market = markets[pos.marketToken];

        // --- Calculations (delegated to AMMMathLib) ---
        int256 pnl;
        uint256 newReserve_vUSDC;
        uint256 newReserve_vTokenX;
        
        if (pos.direction == Direction.LONG) {
            (pnl, newReserve_vUSDC, newReserve_vTokenX) = AMMMathLib.calculateLongClose(
                pos.size, pos.collateral, market.reserve_vUSDC, market.reserve_vTokenX
            );
        } else { // SHORT
            (pnl, newReserve_vUSDC, newReserve_vTokenX) = AMMMathLib.calculateShortClose(
                pos.size, pos.collateral, market.reserve_vUSDC, market.reserve_vTokenX
            );
        }
        
        // Update reserves
        market.reserve_vUSDC = newReserve_vUSDC;
        market.reserve_vTokenX = newReserve_vTokenX;
        
        // Payment logic
        uint256 payoutAmount = 0;
        int256 totalToReturn = int256(pos.collateral) + pnl;

        if (totalToReturn > 0) {
            payoutAmount = uint256(totalToReturn);
        }
        
        // Decrement position count for this market
        openPositionCount[pos.marketToken]--;
        
        delete positions[positionId];
        
        // --- Interactions with other contracts ---
        positionToken.burn(positionId);
        if (payoutAmount > 0) {
            vault.withdraw(owner, payoutAmount);
        }

        // --- Emit event for indexing ---
        emit PositionClosed(
            positionId,
            owner,
            pnl,
            payoutAmount,
            block.timestamp
        );
    }

    // --- View functions ---

    /**
     * @inheritdoc IClearingHouse
     */
    function getMarkPrice(address marketToken) external view override returns (uint256 price) {
        Market storage market = markets[marketToken];
        return AMMMathLib.calculateMarkPrice(market.reserve_vUSDC, market.reserve_vTokenX);
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
            marketToken: pos.marketToken,
            collateral: pos.collateral,
            direction: pos.direction,
            size: pos.size,
            entryPrice: pos.entryPrice,
            timestamp: pos.timestamp
        });
    }

    /**
     * @inheritdoc IClearingHouse
     */
    function previewOpenPosition(
        address marketToken,
        uint256 collateralAmount,
        Direction direction
    ) external view override returns (uint256 vTokenAmount, uint256 entryPrice) {
        require(collateralAmount > 0, "ClearingHouse: Collateral must be positive");
        
        Market storage market = markets[marketToken];
        require(market.status == IRegistry.MarketStatus.Active, "ClearingHouse: Market not active");

        // Calculate entry price before trade impact
        entryPrice = AMMMathLib.calculateMarkPrice(market.reserve_vUSDC, market.reserve_vTokenX);

        // Calculate vToken amount that would be received
        if (direction == Direction.LONG) {
            (vTokenAmount,,) = AMMMathLib.calculateLongOpen(
                collateralAmount, market.reserve_vUSDC, market.reserve_vTokenX
            );
        } else { // SHORT
            (vTokenAmount,,) = AMMMathLib.calculateShortOpen(
                collateralAmount, market.reserve_vUSDC, market.reserve_vTokenX
            );
        }
    }

    // --- ITradingCore Implementation ---

    /**
     * @inheritdoc ITradingCore
     */
    function initializeMarket(address marketToken, uint256 vUSDC, uint256 vTokenX) external override {
        // Only Registry can initialize markets to maintain controlled market creation
        require(msg.sender == registry, "ClearingHouse: Only registry can initialize markets");
        require(marketToken != address(0), "ClearingHouse: Invalid market token");
        require(vUSDC > 0 && vTokenX > 0, "ClearingHouse: Invalid reserves");
        require(markets[marketToken].status == IRegistry.MarketStatus.None, "ClearingHouse: Market already exists");
        
        markets[marketToken] = Market({
            reserve_vUSDC: vUSDC,
            reserve_vTokenX: vTokenX,
            status: IRegistry.MarketStatus.Active
        });
    }

    /**
     * @inheritdoc ITradingCore
     */
    function freezePrice(address marketAddress) external override {
        // Only Registry can freeze markets for settlement process
        require(msg.sender == registry, "ClearingHouse: Only registry can freeze markets");
        
        // Freeze market by updating status to ClosingOnly
        Market storage market = markets[marketAddress];
        market.status = IRegistry.MarketStatus.ClosingOnly;
    }

    /**
     * @inheritdoc ITradingCore
     * @dev Returns true if there are any open positions for the given market.
     * This function now provides proper on-chain verification for market archiving safety.
     */
    function hasOpenPositions(address marketAddress) external view override returns (bool) {
        return openPositionCount[marketAddress] > 0;
    }

    /**
     * @inheritdoc ITradingCore
     */
    function updateReserves(address marketToken, uint256 vUSDC, uint256 vTokenX) external override {
        // Only Registry can push reserve updates to maintain synchronization
        require(msg.sender == registry, "ClearingHouse: Only registry can update reserves");
        require(markets[marketToken].status == IRegistry.MarketStatus.Active, "ClearingHouse: Market not active");
        require(vUSDC > 0 && vTokenX > 0, "ClearingHouse: Invalid reserves");
        
        // Update reserves from Registry - this maintains Registry as source of truth for admin changes
        markets[marketToken].reserve_vUSDC = vUSDC;
        markets[marketToken].reserve_vTokenX = vTokenX;
    }

    /**
     * @inheritdoc ITradingCore
     */
    function updateMarketStatus(address marketToken, uint8 status) external override {
        // Only Registry can push status updates to maintain synchronization
        require(msg.sender == registry, "ClearingHouse: Only registry can update market status");
        
        Market storage market = markets[marketToken];
        market.status = IRegistry.MarketStatus(status);
    }
}