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

    /**
     * @notice Retourne le statut actuel d'un marché.
     * @param marketAddress L'adresse du marché à interroger.
     * @return MarketStatus Le statut actuel du marché.
     */
    function getMarketStatus(address marketAddress) external view returns (MarketStatus);
}