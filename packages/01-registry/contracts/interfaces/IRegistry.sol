// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IRegistry Interface
 * @dev Définit l'interface publique du contrat Registry.
 * Expose les types de données, les événements et les fonctions de lecture nécessaires
 * aux autres contrats du protocole pour interagir avec le Registry.
 */
interface IRegistry {
    /// @dev Enumération des états possibles pour un marché.
    enum MarketStatus {
        None, // État par défaut pour un marché inexistant
        Created,
        Active,
        Paused,
        ClosingOnly,
        Settled,
        Archived
    }

    /// @dev Événement émis lorsqu'un marché change de statut.
    event MarketStatusChanged(address indexed marketAddress, MarketStatus newStatus);

    /// @dev Événement émis lors de la définition des réserves d'un marché.
    event MarketReservesSet(address indexed marketAddress, uint256 vUSDC, uint256 vTokenX);

    /// @dev Événement émis lors de la modification des réserves d'un marché.
    event MarketReservesUpdated(address indexed marketAddress, uint256 oldUSDC, uint256 oldTokenX, uint256 newUSDC, uint256 newTokenX);

    /**
     * @notice Retourne le statut actuel d'un marché.
     * @param marketAddress L'adresse du marché à interroger.
     * @return MarketStatus Le statut actuel du marché.
     */
    function getMarketStatus(address marketAddress) external view returns (MarketStatus);

    /**
     * @notice Retourne le prix actuel d'un marché basé sur ses réserves.
     * @param marketAddress L'adresse du marché à interroger.
     * @return price Le prix actuel calculé (reserve_vUSDC / reserve_vTokenX).
     */
    function getMarketPrice(address marketAddress) external view returns (uint256 price);

    /**
     * @notice Retourne les réserves virtuelles d'un marché.
     * @param marketAddress L'adresse du marché à interroger.
     * @return vUSDC Les réserves virtuelles en USDC.
     * @return vTokenX Les réserves virtuelles en TokenX.
     */
    function getMarketReserves(address marketAddress) external view returns (uint256 vUSDC, uint256 vTokenX);
}