import * as fs from "fs";
import { network } from "hardhat";

async function main() {
  console.log(`Verification Started with chain ID: ${network.config.chainId}`);

  // yarn hardhat run ./contracts/core/Shop.sol > flattened.sol

  let flattened = fs.readFileSync("flattened.sol", "utf8");

  flattened = flattened.replace(
    /SPDX-License-Identifier:/gm,
    "License-Identifier:"
  );
  flattened = `// SPDX-License-Identifier: MIXED\n\n${flattened}`;
  flattened = flattened.replace(
    /pragma experimental ABIEncoderV2;\n/gm,
    (
      (i) => (m: string) =>
        !i++ ? m : ""
    )(0)
  );

  fs.writeFileSync("flattened.sol", flattened);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
