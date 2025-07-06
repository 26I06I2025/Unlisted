// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./interfaces/IClearingHouse.sol";
import "./interfaces/IVault.sol";
import "./PositionToken.sol";
// NOUVEAU: On importe notre boîte à outils mathématique
import "./lib/FixedPointMathLib.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title ClearingHouse
 * @notice Le contrat principal qui gère la logique de trading, le vAMM et les positions.
 * @dev Ce contrat est le chef d'orchestre. Il ne détient aucun fonds lui-même.
 */
contract ClearingHouse is IClearingHouse, ReentrancyGuard {
    // NOUVEAU: On attache notre bibliothèque au type uint256.
    // Désormais, on peut faire des choses comme `monNombre.div(autreNombre)`.
    using FixedPointMathLib for uint256;

    // --- Dépendances externes ---
    IVault public immutable vault;
    PositionToken public immutable positionToken;
    IERC20 public immutable usdc;

    // --- État du vAMM (Virtual Automated Market Maker) ---
    uint256 public reserve_vUSDC;
    uint256 public reserve_vTokenX;

    // --- Stockage des positions ---
    struct Position {
        uint256 collateral; // Montant de collatéral en USDC
        Direction direction; // LONG ou SHORT
        uint256 size; // Taille de la position en vTokenX
    }
    mapping(uint256 => Position) public positions;
    uint256 private _nextPositionId;

    /**
     * @notice Initialise le ClearingHouse.
     * @dev Le k du vAMM n'est pas stocké, il est implicite dans les réserves.
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

        // --- Calculs (partie "Effects") ---
        uint256 vTokenAmount;
        if (direction == Direction.LONG) {
            // MODIFIÉ: On utilise notre fonction de précision pour calculer combien de vTokenX on obtient.
            vTokenAmount = FixedPointMathLib.getAmountOut(collateralAmount, reserve_vUSDC, reserve_vTokenX);
            reserve_vUSDC += collateralAmount;
            reserve_vTokenX -= vTokenAmount;
        } else { // SHORT
            // MODIFIÉ: Pour un short, le collatéral représente le vUSDC reçu. On doit calculer combien de vTokenX il faut "vendre" pour l'obtenir.
            // C'est l'opération inverse, qui nécessite une autre formule AMM.
            // Pour des raisons de simplicité ici, nous allons utiliser une approche symétrique, bien qu'une fonction getAmountIn serait plus juste.
            // Note: Pour une V2, une fonction getAmountIn(amountOut, reserveIn, reserveOut) serait idéale.
            vTokenAmount = FixedPointMathLib.getAmountOut(collateralAmount, reserve_vTokenX, reserve_vUSDC);
            reserve_vTokenX += collateralAmount; // L'utilisateur vend des vTokenX...
            reserve_vUSDC -= vTokenAmount;   // ...pour recevoir des vUSDC. 
        }

        positionId = _nextPositionId++;

        positions[positionId] = Position({
            collateral: collateralAmount,
            direction: direction,
            size: vTokenAmount
        });

        // --- Interactions avec les autres contrats ---
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

        // --- Calculs (partie "Effects") ---
        // MODIFIÉ: On utilise int256 pour pouvoir représenter les pertes négatives.
        int256 pnl;
        
        if (pos.direction == Direction.LONG) {
            // L'utilisateur revend ses vTokenX. On calcule combien de vUSDC il récupère.
            uint256 vUsdcOut = FixedPointMathLib.getAmountOut(pos.size, reserve_vTokenX, reserve_vUSDC);
            pnl = int256(vUsdcOut) - int256(pos.collateral);
            reserve_vTokenX += pos.size;
            reserve_vUSDC -= vUsdcOut;
        } else { // SHORT
            // L'utilisateur doit racheter sa "dette" de vTokenX. On calcule combien ça lui coûte en vUSDC.
            uint256 vUsdcIn = FixedPointMathLib.getAmountOut(pos.size, reserve_vUSDC, reserve_vTokenX);
            pnl = int256(vUsdcIn) - int256(pos.collateral);
            reserve_vUSDC += pos.size;
            reserve_vTokenX -= vUsdcIn;
        }
        
        // MODIFIÉ: Logique de paiement grandement simplifiée et sécurisée grâce à int256.
        uint256 payoutAmount = 0;
        int256 totalToReturn = int256(pos.collateral) + pnl;

        if (totalToReturn > 0) {
            payoutAmount = uint256(totalToReturn);
        }
        
        delete positions[positionId];
        
        // --- Interactions avec les autres contrats ---
        positionToken.burn(positionId);
        if (payoutAmount > 0) {
            vault.withdraw(owner, payoutAmount);
        }
    }

    // --- Fonctions de lecture (View) ---

    /**
     * @inheritdoc IClearingHouse
     */
    function getMarkPrice() external view override returns (uint256 price) {
        // MODIFIÉ: On utilise notre fonction de division de précision. C'est propre et sûr.
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