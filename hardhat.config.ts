import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";

const config: HardhatUserConfig = {
  solidity: "0.8.28",
  paths: {
    sources: "./packages",
    tests: "./packages/02-trading-core/test", // Retour à la config qui marche
  },
};

export default config;
