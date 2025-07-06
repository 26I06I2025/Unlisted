// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IClearingHouse
 * @notice L'interface principale du protocole de trading.
 * @dev Définit l'API publique pour interagir avec le système.
 */
interface IClearingHouse {
    /**
     * @notice Énumération pour définir la direction d'une position.
     */
    enum Direction {
        LONG,
        SHORT
    }

    /**
     * @notice Structure pour retourner les informations d'une position de manière lisible.
     * @param owner Le propriétaire actuel de la position (détenteur du NFT).
     * @param collateral Le montant du collatéral (en USDC) déposé.
     * @param direction La direction de la position (LONG ou SHORT).
     * @param size La taille de la position (en vToken).
     */
    struct PositionView {
        address owner;
        uint256 collateral;
        Direction direction;
        uint256 size;
    }

    /**
     * @notice Ouvre une nouvelle position de trading.
     * @param collateralAmount Le montant de collatéral (USDC) à déposer.
     * @param direction La direction souhaitée pour la position (LONG ou SHORT).
     * @return positionId L'ID unique de la position nouvellement créée (qui est aussi le tokenId du NFT).
     */
    function openPosition(
        uint256 collateralAmount,
        Direction direction
    ) external returns (uint256 positionId);

    /**
     * @notice Ferme une position de trading existante.
     * @dev Le PNL est calculé et les fonds (collatéral +/- PNL) sont envoyés au propriétaire de la position.
     * @param positionId L'ID de la position à fermer.
     */
    function closePosition(uint256 positionId) external;

    /**
     * @notice Récupère le prix actuel du marché tel que défini par le vAMM.
     * @return price Le prix actuel, représenté avec une précision de 18 décimales.
     */
    function getMarkPrice() external view returns (uint256 price);

    /**
     * @notice Récupère les informations détaillées d'une position spécifique.
     * @param positionId L'ID de la position à consulter.
     * @return La structure PositionView avec les détails de la position.
     */
    function getPosition(
        uint256 positionId
    ) external view returns (PositionView memory);
}