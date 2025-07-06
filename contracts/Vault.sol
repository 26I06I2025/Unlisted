// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./interfaces/IVault.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title Vault
 * @notice Simple contract that secures all collateral (USDC) of the protocol.
 * @dev This contract is deliberately "dumb". Its only security relies on the fact
 * that only the ClearingHouse can call its deposit and withdrawal functions.
 */
contract Vault is IVault {
    // The address of the ClearingHouse contract, which is the only one authorized to manage funds.
    // "immutable" means this address is set once and for all at creation and can never be changed.
    // This is safer and less expensive in gas.
    address public immutable clearingHouse;

    // The interface of the USDC token used as collateral.
    IERC20 public immutable usdc;

    /**
     * @dev The modifier that checks if the caller is the ClearingHouse.
     */
    modifier onlyClearingHouse() {
        require(msg.sender == clearingHouse, "Vault: Caller is not the ClearingHouse");
        _;
    }

    /**
     * @notice The constructor is called only once during contract deployment.
     * @param _clearingHouse The address of the ClearingHouse contract to authorize.
     * @param _usdc The address of the USDC token contract.
     */
    constructor(address _clearingHouse, address _usdc) {
        require(_clearingHouse != address(0), "Vault: Invalid ClearingHouse address");
        require(_usdc != address(0), "Vault: Invalid USDC address");
        clearingHouse = _clearingHouse;
        usdc = IERC20(_usdc);
    }

    /**
     * @notice Receives USDC from the ClearingHouse and stores it in this contract.
     * @inheritdoc IVault
     */
    function deposit(uint256 amount) external override onlyClearingHouse {
        // The ClearingHouse has already taken funds from the user.
        // Now, it transfers these funds from itself to the Vault to secure them.
        usdc.transferFrom(clearingHouse, address(this), amount);
    }

    /**
     * @notice Sends USDC from the Vault to a recipient.
     * @inheritdoc IVault
     */
    function withdraw(address to, uint256 amount) external override onlyClearingHouse {
        // Send funds directly to the final recipient (the user closing their position).
        usdc.transfer(to, amount);
    }
}