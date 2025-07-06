// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

/**
 * @title PositionToken
 * @notice Un contrat ERC721 (NFT) pour représenter la propriété des positions de trading.
 * @dev Ce contrat est un simple wrapper autour du standard ERC721 d'OpenZeppelin.
 * Sa seule logique personnalisée est de s'assurer que seul le ClearingHouse peut
 * créer (mint) ou détruire (burn) des tokens.
 */
contract PositionToken is ERC721 {
    // L'adresse du contrat ClearingHouse, le seul autorisé à gérer les tokens.
    address public immutable clearingHouse;

    /**
     * @dev Le modifier qui vérifie si l'appelant est bien le ClearingHouse.
     */
    modifier onlyClearingHouse() {
        require(msg.sender == clearingHouse, "PositionToken: Caller is not the ClearingHouse");
        _;
    }

    /**
     * @notice Le constructeur.
     * @param _clearingHouse L'adresse du contrat ClearingHouse à autoriser.
     */
    constructor(address _clearingHouse) ERC721("DeFi Protocol Position", "DPP") {
        require(_clearingHouse != address(0), "PositionToken: Invalid ClearingHouse address");
        clearingHouse = _clearingHouse;
    }

    /**
     * @notice Crée un nouveau NFT de position.
     * @dev Ne peut être appelé que par le ClearingHouse lorsqu'une position est ouverte.
     * @param to L'adresse du nouveau propriétaire de la position.
     * @param tokenId L'ID unique de la nouvelle position.
     */
    function mint(address to, uint256 tokenId) external onlyClearingHouse {
        _mint(to, tokenId);
    }

    /**
     * @notice Détruit un NFT de position existant.
     * @dev Ne peut être appelé que par le ClearingHouse lorsqu'une position est fermée.
     * @param tokenId L'ID de la position à détruire.
     */
    function burn(uint256 tokenId) external onlyClearingHouse {
        _burn(tokenId);
    }
}