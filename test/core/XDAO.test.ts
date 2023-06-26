import { expect } from "chai";
import { parseEther } from "ethers/lib/utils";
import { ethers } from "hardhat";

import { XDAO__factory } from "../../typechain-types";

describe("XDAO", () => {
	it("Successful Deploy", async () => {
		const xdao = await new XDAO__factory(
			(
				await ethers.getSigners()
			)[0],
		).deploy();

		expect(await xdao.balanceOf((await ethers.getSigners())[0].address))
			.to.eq(await xdao.totalSupply())
			.to.eq(parseEther("1000000000"));
	});
});
