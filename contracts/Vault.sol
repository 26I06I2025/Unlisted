// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./interfaces/IVault.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title Vault
 * @notice Contrat simple qui sécurise tous les collatéraux (USDC) du protocole.
 * @dev Ce contrat est délibérément "stupide". Sa seule sécurité repose sur le fait
 * que seul le ClearingHouse peut appeler ses fonctions de dépôt et de retrait.
 */
contract Vault is IVault {
    // L'adresse du contrat ClearingHouse, qui est le seul autorisé à gérer les fonds.
    // "immutable" signifie que cette adresse est définie une fois pour toutes à la création et ne peut plus jamais être changée.
    // C'est plus sûr et moins coûteux en gas.
    address public immutable clearingHouse;

    // L'interface du token USDC utilisé comme collatéral.
    IERC20 public immutable usdc;

    /**
     * @dev Le modifier qui vérifie si l'appelant est bien le ClearingHouse.
     */
    modifier onlyClearingHouse() {
        require(msg.sender == clearingHouse, "Vault: Caller is not the ClearingHouse");
        _;
    }

    /**
     * @notice Le constructeur est appelé une seule fois lors du déploiement du contrat.
     * @param _clearingHouse L'adresse du contrat ClearingHouse à autoriser.
     * @param _usdc L'adresse du contrat du token USDC.
     */
    constructor(address _clearingHouse, address _usdc) {
        require(_clearingHouse != address(0), "Vault: Invalid ClearingHouse address");
        require(_usdc != address(0), "Vault: Invalid USDC address");
        clearingHouse = _clearingHouse;
        usdc = IERC20(_usdc);
    }

    /**
     * @notice Reçoit des USDC depuis le ClearingHouse et les stocke dans ce contrat.
     * @inheritdoc IVault
     */
    function deposit(uint256 amount) external override onlyClearingHouse {
        // Le ClearingHouse a déjà pris les fonds de l'utilisateur.
        // Maintenant, il transfère ces fonds de lui-même vers le Vault pour les sécuriser.
        usdc.transferFrom(clearingHouse, address(this), amount);
    }

    /**
     * @notice Envoie des USDC depuis le Vault vers un destinataire.
     * @inheritdoc IVault
     */
    function withdraw(address to, uint256 amount) external override onlyClearingHouse {
        // Envoie les fonds directement au destinataire final (l'utilisateur qui ferme sa position).
        usdc.transfer(to, amount);
    }
}