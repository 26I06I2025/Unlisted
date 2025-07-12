// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/ITradingCore.sol";
import "./interfaces/IRegistry.sol";

/**
 * @title Registry
 * @author [Your Name/Protocol Name]
 * @notice Ce contrat gère le cycle de vie des marchés négociables sur le protocole.
 * @dev Il fonctionne comme la source de vérité pour l'état des marchés.
 * Seul le propriétaire (Owner) peut effectuer des actions administratives.
 */
contract Registry is IRegistry, Ownable {
    // === Variables d'État ===

    ITradingCore public tradingCore;

    struct Market {
        string name;
        string symbol;
        MarketStatus status;
        uint256 reserve_vUSDC;     // Réserves virtuelles USDC
        uint256 reserve_vTokenX;   // Réserves virtuelles TokenX
        uint256 createdAt;         // Timestamp de création
    }

    mapping(address => Market) public markets;

    // === Événements ===

    event MarketCreated(address indexed marketAddress, string name, string symbol);
    event TradingCoreAddressSet(address indexed newTradingCoreAddress);

    // === Modifiers ===

    modifier marketExists(address _marketAddress) {
        require(markets[_marketAddress].status != MarketStatus.None, "Registry: Market does not exist");
        _;
    }

    modifier marketIsInStatus(address _marketAddress, MarketStatus _status) {
        require(markets[_marketAddress].status == _status, "Registry: Invalid market status");
        _;
    }

    // === Constructeur ===

    constructor() Ownable(msg.sender) {}

    // === Fonctions Administratives ===

    /**
     * @notice Définit l'adresse du contrat Trading Core. Essentiel pour la communication.
     * @param _tradingCoreAddress L'adresse du contrat Trading Core déployé.
     */
    function setTradingCoreAddress(address _tradingCoreAddress) external onlyOwner {
        require(_tradingCoreAddress != address(0), "Registry: Zero address for Trading Core");
        tradingCore = ITradingCore(_tradingCoreAddress);
        emit TradingCoreAddressSet(_tradingCoreAddress);
    }

    /**
     * @notice Crée un nouveau marché avec des réserves initiales définissant le prix.
     * @param _marketAddress L'adresse du token qui représentera ce marché.
     * @param _name Le nom complet du marché (ex: "Ethereum Natif").
     * @param _symbol Le symbole du marché (ex: "N-ETH").
     * @param _reserve_vUSDC Les réserves virtuelles initiales en USDC.
     * @param _reserve_vTokenX Les réserves virtuelles initiales en TokenX.
     */
    function createMarket(
        address _marketAddress, 
        string memory _name, 
        string memory _symbol,
        uint256 _reserve_vUSDC,
        uint256 _reserve_vTokenX
    ) external onlyOwner {
        require(markets[_marketAddress].status == MarketStatus.None, "Registry: Market already exists");
        require(_reserve_vUSDC > 0, "Registry: vUSDC reserves must be positive");
        require(_reserve_vTokenX > 0, "Registry: vTokenX reserves must be positive");
        
        markets[_marketAddress] = Market({
            name: _name,
            symbol: _symbol,
            status: MarketStatus.Created,
            reserve_vUSDC: _reserve_vUSDC,
            reserve_vTokenX: _reserve_vTokenX,
            createdAt: block.timestamp
        });
        
        // Initialize market in Trading Core
        if (address(tradingCore) != address(0)) {
            tradingCore.initializeMarket(_marketAddress, _reserve_vUSDC, _reserve_vTokenX);
        }
        
        emit MarketCreated(_marketAddress, _name, _symbol);
        emit MarketStatusChanged(_marketAddress, MarketStatus.Created);
        emit MarketReservesSet(_marketAddress, _reserve_vUSDC, _reserve_vTokenX);
    }

    /**
     * @notice Ajuste les réserves d'un marché pour modifier son prix.
     * @dev Seul l'owner peut modifier les prix. Le marché doit exister.
     * @param _marketAddress L'adresse du marché à modifier.
     * @param _newReserve_vUSDC Les nouvelles réserves virtuelles en USDC.
     * @param _newReserve_vTokenX Les nouvelles réserves virtuelles en TokenX.
     */
    function adjustMarketReserves(
        address _marketAddress,
        uint256 _newReserve_vUSDC,
        uint256 _newReserve_vTokenX
    ) external onlyOwner marketExists(_marketAddress) {
        require(_newReserve_vUSDC > 0, "Registry: vUSDC reserves must be positive");
        require(_newReserve_vTokenX > 0, "Registry: vTokenX reserves must be positive");
        
        Market storage market = markets[_marketAddress];
        uint256 oldUSDC = market.reserve_vUSDC;
        uint256 oldTokenX = market.reserve_vTokenX;
        
        market.reserve_vUSDC = _newReserve_vUSDC;
        market.reserve_vTokenX = _newReserve_vTokenX;
        
        // Synchronize reserves with Trading Core
        if (address(tradingCore) != address(0)) {
            tradingCore.updateReserves(_marketAddress, _newReserve_vUSDC, _newReserve_vTokenX);
        }
        
        emit MarketReservesUpdated(_marketAddress, oldUSDC, oldTokenX, _newReserve_vUSDC, _newReserve_vTokenX);
    }

    /**
     * @notice Active un marché pour le trading.
     * @dev Le marché doit être dans l'état "Created".
     * @param _marketAddress L'adresse du marché à activer.
     */
    function listMarket(address _marketAddress) external onlyOwner marketIsInStatus(_marketAddress, MarketStatus.Created) {
        markets[_marketAddress].status = MarketStatus.Active;
        emit MarketStatusChanged(_marketAddress, MarketStatus.Active);
    }

    /**
     * @notice Met en pause l'ouverture de nouvelles positions sur un marché.
     * @dev Le marché doit être "Active". La fermeture de positions reste possible.
     * @param _marketAddress L'adresse du marché à mettre en pause.
     */
    function pauseMarket(address _marketAddress) external onlyOwner marketIsInStatus(_marketAddress, MarketStatus.Active) {
        markets[_marketAddress].status = MarketStatus.Paused;
        emit MarketStatusChanged(_marketAddress, MarketStatus.Paused);
    }

    /**
     * @notice Réactive un marché mis en pause.
     * @dev Le marché doit être "Paused".
     * @param _marketAddress L'adresse du marché à réactiver.
     */
    function resumeMarket(address _marketAddress) external onlyOwner marketIsInStatus(_marketAddress, MarketStatus.Paused) {
        markets[_marketAddress].status = MarketStatus.Active;
        emit MarketStatusChanged(_marketAddress, MarketStatus.Active);
    }

    /**
     * @notice Démarre le processus de fin de vie d'un marché.
     * @dev Le marché passe en mode "Clôture Uniquement". Irréversible.
     * @param _marketAddress L'adresse du marché à délester.
     */
    function startShutdownProcess(address _marketAddress) external onlyOwner marketExists(_marketAddress) {
        require(
            markets[_marketAddress].status == MarketStatus.Active || markets[_marketAddress].status == MarketStatus.Paused,
            "Registry: Market not active or paused"
        );
        markets[_marketAddress].status = MarketStatus.ClosingOnly;
        emit MarketStatusChanged(_marketAddress, MarketStatus.ClosingOnly);
    }

    /**
     * @notice Règle un marché, fige le prix et active le mode de réclamation.
     * @dev Doit être appelé après une période de grâce. Appelle `freezePrice` sur le Trading Core.
     * @param _marketAddress L'adresse du marché à régler.
     */
    function settleMarket(address _marketAddress) external onlyOwner marketIsInStatus(_marketAddress, MarketStatus.ClosingOnly) {
        tradingCore.freezePrice(_marketAddress);
        markets[_marketAddress].status = MarketStatus.Settled;
        emit MarketStatusChanged(_marketAddress, MarketStatus.Settled);
    }
    
    /**
     * @notice Archive un marché réglé.
     * @dev Ne peut être appelé que si le Trading Core confirme qu'il n'y a plus de positions ouvertes.
     * @param _marketAddress L'adresse du marché à archiver.
     */
    function archiveMarket(address _marketAddress) external onlyOwner marketIsInStatus(_marketAddress, MarketStatus.Settled) {
        require(!tradingCore.hasOpenPositions(_marketAddress), "Registry: Positions still open");
        markets[_marketAddress].status = MarketStatus.Archived;
        emit MarketStatusChanged(_marketAddress, MarketStatus.Archived);
    }

    // === Fonctions de Lecture Publiques ===

    /**
     * @notice Implémentation de l'interface IRegistry.
     */
    function getMarketStatus(address _marketAddress) public view override returns (MarketStatus) {
        return markets[_marketAddress].status;
    }

    /**
     * @notice Retourne les réserves virtuelles d'un marché.
     * @param marketAddress L'adresse du marché à interroger.
     * @return vUSDC Les réserves virtuelles en USDC.
     * @return vTokenX Les réserves virtuelles en TokenX.
     */
    function getMarketReserves(address marketAddress) external view returns (uint256 vUSDC, uint256 vTokenX) {
        Market storage market = markets[marketAddress];
        require(market.status != MarketStatus.None, "Market does not exist");
        return (market.reserve_vUSDC, market.reserve_vTokenX);
    }
}