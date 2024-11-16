import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const tokenA = '0x767086C259C5EbbA6c62d1d0337Ad57F8c643981'
const tokenB = '0x78F2e051d15497023beCAd1092fb7289d2fDd224'
const swapFeePercentage = '3'
const unstakeFeePercentage = '10'
const maxStakePercentageA = '25'

const RuglessLiquidityPoolModule = buildModule("RuglessLiquidityPool", (m) => {
  const ruglessLiquidityPool = m.contract("RuglessLiquidityPool", [tokenA, tokenB, swapFeePercentage, unstakeFeePercentage, maxStakePercentageA]);
  return { ruglessLiquidityPool };
});

export default RuglessLiquidityPoolModule;
