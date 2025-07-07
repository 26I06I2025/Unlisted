// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title ITokenFactory Interface
 * @dev Définit l'interface publique pour l'usine de création de tokens.
 */
interface ITokenFactory {
    /**
     * @dev Émis chaque fois qu'un nouveau contrat de token est déployé.
     * @param tokenAddress L'adresse du nouveau contrat MarketToken.
     * @param owner L'adresse qui a initié la création (l'admin de la factory).
     * @param name Le nom du nouveau token.
     * @param symbol Le symbole du nouveau token.
     */
    event TokenCreated(
        address indexed tokenAddress,
        address indexed owner,
        string name,
        string symbol
    );

    /**
     * @notice Déploie un nouveau contrat de token ERC20.
     * @param name Le nom complet du token à créer.
     * @param symbol Le symbole du token à créer.
     * @return tokenAddress L'adresse du contrat ERC20 nouvellement créé.
     */
    function createToken(string memory name, string memory symbol) external returns (address);
}