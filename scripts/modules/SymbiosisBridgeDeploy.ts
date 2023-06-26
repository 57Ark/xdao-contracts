import "dotenv/config";

import { existsSync, renameSync, unlinkSync } from "fs";
import { ethers, network, run, upgrades } from "hardhat";

import { SymbiosisBridge } from "../../typechain-types";

const { deployProxy } = upgrades;
const chainId = network.config.chainId;

interface SymbiosisBridgeAgruments {
	metaRouter: string;
	metaRouterGateway: string;
}

const feeAddress = process.env.BRIDGE_FEE_ADDRESS;
const feeRate = 50;
const ownerAddress = process.env.XDAO_DEPLOYER;

const NETWORK_ARGUMENTS: Record<number, SymbiosisBridgeAgruments> = {
	1: {
		metaRouter: "0xB9E13785127BFfCc3dc970A55F6c7bF0844a3C15",
		metaRouterGateway: "0x03B7551EB0162c838a10c2437b60D1f5455b9554",
	},
	56: {
		metaRouter: "0x8D602356c7A6220CDE24BDfB4AB63EBFcb0a9b5d",
		metaRouterGateway: "0xe2faC824615538C3A9ae704c75582cD1AbdD7cdf",
	},
	137: {
		metaRouter: "0x733D33FA01424F83E9C095af3Ece80Ed6fa565F1",
		metaRouterGateway: "0xF3273BD35e4Ad4fcd49DabDee33582b41Cbb9d77",
	},
	43114: {
		metaRouter: "0xE5E68630B5B759e6C701B70892AA8324b71e6e20",
		metaRouterGateway: "0x25821A21C2E3455967229cADCA9b6fdd4A80a40b",
	},
	10: {
		metaRouter: "0xcE8f24A58D85eD5c5A6824f7be1F8d4711A0eb4C",
		metaRouterGateway: "0xAdB2d3b711Bb8d8Ea92ff70292c466140432c278",
	},
	42161: {
		metaRouter: "0xcE8f24A58D85eD5c5A6824f7be1F8d4711A0eb4C",
		metaRouterGateway: "0xAdB2d3b711Bb8d8Ea92ff70292c466140432c278",
	},
	1337: {
		metaRouter: "0x733D33FA01424F83E9C095af3Ece80Ed6fa565F1",
		metaRouterGateway: "0xF3273BD35e4Ad4fcd49DabDee33582b41Cbb9d77",
	},
};

const deleteLocalManifest = () => {
	existsSync(`.openzeppelin/unknown-${chainId}.json`) &&
		unlinkSync(`.openzeppelin/unknown-${chainId}.json`);
};

const renameLocalManifest = (contractName: string) => {
	renameSync(
		`.openzeppelin/unknown-${chainId}.json`,
		`.openzeppelin/${contractName}/unknown-${chainId}.json`,
	);
};

const main = async () => {
	if (!chainId) {
		console.log("ChainId undefined");
		return;
	}

	try {
		deleteLocalManifest();
		// eslint-disable-next-line no-empty
	} catch {}

	console.log(`Deploy Started with chain ID: ${chainId}`);

	const [signer] = await ethers.getSigners();

	console.log(`Account: ${signer.address}`);
	console.log(`Network: ${network.name}-${chainId}`);

	console.log(`Bridge Fee Address: ${feeAddress}`);

	const symbiosisAddresses = NETWORK_ARGUMENTS[chainId];

	if (!symbiosisAddresses) {
		console.log("Symbiosis Addresses undefined");
		return;
	}

	const { metaRouter, metaRouterGateway } = symbiosisAddresses;

	const symbiosisBridge = (await deployProxy(
		await ethers.getContractFactory("SymbiosisBridge"),
		[ownerAddress, metaRouter, metaRouterGateway, feeAddress, feeRate],
	)) as SymbiosisBridge;

	await symbiosisBridge.deployed();

	console.log({ symbiosisBridge: symbiosisBridge.address });

	console.log("LaunchpadModule: SetCoreAddresses Success");

	const implementationAddress = await upgrades.erc1967.getImplementationAddress(
		symbiosisBridge.address,
	);

	console.log(
		`SymbiosisBridge implementation address: ${implementationAddress}`,
	);

	console.log(
		`SymbiosisBridge owner address: ${await symbiosisBridge.owner()}`,
	);

	try {
		renameLocalManifest("SymbiosisBridge");
		// eslint-disable-next-line no-empty
	} catch {}

	await new Promise((r) => setTimeout(r, 10000));

	try {
		await run("verify:verify", {
			address: implementationAddress,
			contract: "contracts/modules/SymbiosisBridge.sol:SymbiosisBridge",
		});
	} catch {
		console.log(`Verification problem (SymbiosisBridge)`);
	}
};

main().catch((error) => {
	console.error(error);
	process.exitCode = 1;
});
