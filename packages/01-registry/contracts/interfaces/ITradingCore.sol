// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title ITradingCore Interface
 * @dev Définit les fonctions du contrat Trading Core que le Registry doit appeler.
 * Permet une communication découplée et sécurisée.
 */
interface ITradingCore {
    /**
     * @notice Ordonne au Trading Core de figer le prix d'un marché pour le règlement final.
     * @param marketAddress L'adresse du marché à geler.
     */
    function freezePrice(address marketAddress) external;

    /**
     * @notice Vérifie s'il existe des positions ouvertes pour un marché donné.
     * @dev Utilisé par le Registry avant d'autoriser l'archivage d'un marché.
     * @param marketAddress L'adresse du marché à vérifier.
     * @return bool Vrai s'il y a au moins une position ouverte, faux sinon.
     */
    function hasOpenPositions(address marketAddress) external view returns (bool);
}