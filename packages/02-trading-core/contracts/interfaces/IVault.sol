// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IVault
 * @notice The interface for the Vault contract, which holds the collateral.
 * @dev Defines the functions that the ClearingHouse can call on the Vault.
 */
interface IVault {
    /**
     * @notice Deposits funds (USDC) into the Vault.
     * @dev Must only be callable by the ClearingHouse.
     * @param amount The amount of USDC to deposit.
     */
    function deposit(uint256 amount) external;

    /**
     * @notice Withdraws funds (USDC) from the Vault.
     * @dev Must only be callable by the ClearingHouse.
     * @param to The address of the recipient of the funds.
     * @param amount The amount of USDC to withdraw.
     */
    function withdraw(address to, uint256 amount) external;
}