// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IVault
 * @notice L'interface pour le contrat Vault, qui détient les collatéraux.
 * @dev Définit les fonctions que le ClearingHouse peut appeler sur le Vault.
 */
interface IVault {
    /**
     * @notice Dépose des fonds (USDC) dans le Vault.
     * @dev Doit uniquement être appelable par le ClearingHouse.
     * @param amount Le montant d'USDC à déposer.
     */
    function deposit(uint256 amount) external;

    /**
     * @notice Retire des fonds (USDC) du Vault.
     * @dev Doit uniquement être appelable par le ClearingHouse.
     * @param to L'adresse du destinataire des fonds.
     * @param amount Le montant d'USDC à retirer.
     */
    function withdraw(address to, uint256 amount) external;
}