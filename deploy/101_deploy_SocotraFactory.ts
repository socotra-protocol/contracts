import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { parseEther } from "ethers/lib/utils";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts } = hre;
  const { deploy, getOrNull, log } = deployments;
  const { deployer } = await getNamedAccounts();

  const socotraFactory = await getOrNull("SocotraFactory");
  if (socotraFactory) {
    log(`reusing Socotra Factory at ${socotraFactory.address}`);
  } else {
    log(`deployer address: ${deployer}`);
    await deploy("SocotraFactory", {
      from: deployer,
      log: true,
      skipIfAlreadyDeployed: true,
    });
  }
};
export default func;
func.tags = ["SocotraFactory"];
