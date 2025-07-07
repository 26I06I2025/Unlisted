// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title MarketToken
 * @author [Your Name/Protocol Name]
 * @notice Contrat de base pour un token ERC20 représentant un marché.
 * @dev Ce contrat est destiné à être déployé par la TokenFactory.
 * Le propriétaire initial du contrat est le déployeur (la TokenFactory), qui peut
 * ensuite transférer la propriété si nécessaire.
 */
contract MarketToken is ERC20, Ownable {
    /**
     * @dev Le constructeur initialise le token ERC20 avec un nom et un symbole.
     * Il définit également le déployeur comme le propriétaire du contrat.
     * @param name Le nom complet du token (ex: "Gold").
     * @param symbol Le symbole du token (ex: "GLD").
     */
    constructor(string memory name, string memory symbol) ERC20(name, symbol) Ownable(msg.sender) {
        // Le constructeur Ownable(msg.sender) est appelé pour définir
        // l'adresse qui déploie ce contrat (la TokenFactory) comme propriétaire.
    }

    // NOTE: Si vous avez besoin de créer une offre initiale de jetons,
    // vous pouvez ajouter une fonction de "mint" ici, protégée par le
    // modifier `onlyOwner`. Par exemple:
    /*
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
    */
}