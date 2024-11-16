import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import { ethers } from "hardhat";

const name = 'RLSS'
const symbol = 'RLSS'
const initialSupply = ethers.parseEther('1000000')

const TokenModule = buildModule("Token", (m) => {
  const token = m.contract("Token", [name, symbol, initialSupply]);
  return { token };
});

export default TokenModule;
