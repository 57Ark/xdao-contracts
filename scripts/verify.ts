import { network, run, upgrades } from "hardhat";

async function main() {
  console.log(`Verification Started with chain ID: ${network.config.chainId}`);

  try {
    await run("verify:verify", {
      address: "0xCA49EcF7e7bb9bBc9D1d295384663F6BA5c0e366",
      contract: "contracts/core/Shop.sol:Shop",
    });
  } catch (e) {
    console.log("Verification problem (Shop):", e);
  }

  try {
    await run("verify:verify", {
      address: "0x71eebA415A523F5C952Cc2f06361D5443545Ad28",
      contract: "contracts/core/XDAOPeg.sol:XDAOPeg",
    });
  } catch (e) {
    console.log("Verification problem (XDAOPeg):", e);
  }

  try {
    await run("verify:verify", {
      address: "0x72cc6E4DE47f673062c41C67505188144a0a3D84",
      constructorArguments: [
        "0xCA49EcF7e7bb9bBc9D1d295384663F6BA5c0e366",
        "0x71eebA415A523F5C952Cc2f06361D5443545Ad28",
      ],
      contract: "contracts/core/Factory.sol:Factory",
    });
  } catch (e) {
    console.log("Verification problem (Factory):", e);
  }

  try {
    await run("verify:verify", {
      address: "0x3730Bdc5DDF4286A8778dcB19dA638db1Da981Ad",
      contract: "contracts/viewers/DaoViewer.sol:DaoViewer",
    });
  } catch (e) {
    console.log("Verification problem (DaoViewer):", e);
  }

  try {
    await run("verify:verify", {
      address: "0xe642859C00BeD165bD6e36a60Dc94F9b5184D01f",
      contract: "contracts/modules/PrivateExitModule.sol:PrivateExitModule",
    });
  } catch (e) {
    console.log("Verification problem (PrivateExitModule):", e);
  }

  try {
    await run("verify:verify", {
      address: "0xB42DD79C056d4b511c07c29d4c35403b47bE29B9",
      contract: "contracts/modules/DividendsModule.sol:DividendsModule",
    });
  } catch (e) {
    console.log("Verification problem (DividendsModule):", e);
  }

  try {
    await run("verify:verify", {
      address: await upgrades.erc1967.getImplementationAddress(
        "0x41185246595EAdE95ec0acF9aDF6417fE7a94F39"
      ),
      contract: "contracts/modules/LaunchpadModule.sol:LaunchpadModule",
    });
  } catch (e) {
    console.log("Verification problem (LaunchpadModule):", e);
  }

  try {
    await run("verify:verify", {
      address: await upgrades.erc1967.getImplementationAddress(
        "0x31B407eE1960d6DaC4273Bf57c5FC1CCdF53469d"
      ),
      contract: "contracts/modules/PayrollModule.sol:PayrollModule",
    });
  } catch (e) {
    console.log("Verification problem (PayrollModule):", e);
  }

  try {
    await run("verify:verify", {
      address: "0x7A8F181eB94594A6f47EEee5AA23ed6D8DC7563b",
      contract: "contracts/viewers/AdvancedViewer.sol:AdvancedViewer",
      constructorArguments: [
        "0x72cc6E4DE47f673062c41C67505188144a0a3D84",
        "0x3730Bdc5DDF4286A8778dcB19dA638db1Da981Ad",
      ],
    });
  } catch (e) {
    console.log("Verification problem (AdvancedViewer):", e);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
