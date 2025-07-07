// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./MarketToken.sol";
import "./interfaces/ITokenFactory.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title TokenFactory
 * @author [Your Name/Protocol Name]
 * @notice Contrat usine pour déployer de nouveaux contrats MarketToken (ERC20).
 * @dev Seul le propriétaire de cette usine peut créer de nouveaux tokens.
 * Implémente l'interface ITokenFactory.
 */
contract TokenFactory is ITokenFactory, Ownable {
    
    // === Constructeur ===

    constructor() Ownable(msg.sender) {}

    // === Fonctions ===

    /**
     * @notice Déploie un nouveau contrat MarketToken et retourne son adresse.
     * @dev Implémente la fonction de l'interface ITokenFactory.
     * @param name Le nom complet du token à créer (ex: "Gold").
     * @param symbol Le symbole du token à créer (ex: "GLD").
     * @return tokenAddress L'adresse du contrat ERC20 nouvellement créé.
     */
    function createToken(string memory name, string memory symbol)
        external
        onlyOwner
        override
        returns (address)
    {
        // L'opérateur "new" déploie une nouvelle instance du contrat MarketToken.
        MarketToken newToken = new MarketToken(name, symbol);
        address tokenAddress = address(newToken);

        // On émet un événement pour que la création soit facilement traçable off-chain.
        emit TokenCreated(tokenAddress, msg.sender, name, symbol);

        // On retourne l'adresse du nouveau contrat pour que l'admin puisse
        // l'utiliser, par exemple pour l'enregistrer dans le Registry.
        return tokenAddress;
    }
}