// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title FixedPointMathLib
 * @author (Inspiré par Solmate et d'autres bibliothèques DeFi éprouvées)
 * @notice Une bibliothèque pour effectuer des calculs à point fixe avec 18 décimales.
 * @dev Utilise WAD (1e18) pour représenter les nombres décimaux.
 */
library FixedPointMathLib {
    // La constante WAD représente 1.0 avec 18 décimales (10^18).
    // C'est le standard utilisé dans la plupart des protocoles DeFi pour la précision.
    uint256 private constant WAD = 1e18;

    /**
     * @notice Multiplie deux nombres à point fixe (avec 18 décimales).
     * @param a Le premier nombre.
     * @param b Le second nombre.
     * @return Le produit, à l'échelle WAD.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0 || b == 0) {
            return 0;
        }
        // Prévention de l'overflow avant la multiplication
        require(a <= type(uint256).max / b, "Math: mul overflow");

        // (a * WAD) * (b * WAD) / WAD = a * b * WAD
        // Pour revenir à l'échelle WAD, on divise par WAD
        return (a * b) / WAD;
    }

    /**
     * @notice Divise deux nombres à point fixe (avec 18 décimales).
     * @param a Le numérateur.
     * @param b Le dénominateur.
     * @return Le quotient, à l'échelle WAD.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        // Prévention de la division par zéro
        require(b > 0, "Math: div by zero");

        // Pour préserver la précision, on multiplie le numérateur par WAD avant la division.
        // (a * WAD) / (b * WAD) * WAD = (a * WAD) / b
        return (a * WAD) / b;
    }

    /**
     * @notice Calcule le montant de sortie pour un montant d'entrée donné dans un AMM x*y=k.
     * @param amountIn Le montant du token qui entre dans le pool.
     * @param reserveIn La réserve du token qui entre, avant l'échange.
     * @param reserveOut La réserve du token qui sort, avant l'échange.
     * @return amountOut Le montant du token qui sort du pool.
     */
    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) internal pure returns (uint256 amountOut) {
        require(amountIn > 0, "AMM: insufficient input amount");
        require(reserveIn > 0 && reserveOut > 0, "AMM: insufficient liquidity");

        // La formule standard pour un AMM : amountOut = (amountIn * reserveOut) / (reserveIn + amountIn)
        // On effectue la multiplication d'abord pour préserver la précision
        uint256 numerator = amountIn * reserveOut;
        uint256 denominator = reserveIn + amountIn;
        amountOut = numerator / denominator;

        return amountOut;
    }
}