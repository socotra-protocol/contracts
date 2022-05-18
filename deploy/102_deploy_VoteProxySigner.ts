import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { parseEther } from "ethers/lib/utils";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts } = hre;
  const { deploy, getOrNull, log } = deployments;
  const { deployer } = await getNamedAccounts();

  const voteProxySigner = await getOrNull("VoteProxySigner");
  if (voteProxySigner) {
    log(`reusing VoteProxySigner at ${voteProxySigner.address}`);
  } else {
    log(`deployer address: ${deployer}`);
    await deploy("VoteProxySigner", {
      from: deployer,
      args: [deployer],
      log: true,
      skipIfAlreadyDeployed: true,
    });
  }
};
export default func;
func.tags = ["VoteProxySigner"];
