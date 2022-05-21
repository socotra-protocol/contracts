import { expect } from "chai";
import { ethers, deployments, getUnnamedAccounts } from "hardhat";
import { SocotraFactory } from "../build/typechain";

const setup = deployments.createFixture(async () => {
  await deployments.fixture("SocotraFactory");
  const { deploy, getOrNull, log } = deployments;
  const socotraFactory = await getOrNull("SocotraFactory");
  if (socotraFactory) {
    const contracts = {
      SocotraFactory: <SocotraFactory>(
        await ethers.getContractAt("SocotraFactory", socotraFactory.address)
      ),
    };
    const [deployer] = await ethers.getSigners();
    return {
      ...contracts,
      deployer,
    };
  }
});
describe("SocotraFactory", function () {
  it("can split branch", async function () {
    const result = await setup();
    const deployer = result?.deployer;
    const socotraFactory = result?.SocotraFactory;
    await socotraFactory?.splitBranch();
  });
});
