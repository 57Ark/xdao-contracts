import { ethers, network, run, upgrades } from 'hardhat'

import { DaoManager } from '../../typechain-types'

async function main() {
  console.log(`Deploy Started with chain ID: ${network.config.chainId}`)

  const [signer] = await ethers.getSigners()

  console.log(`Account: ${signer.address}`)

  const DaoManager = (await upgrades.deployProxy(
    await ethers.getContractFactory('DaoManager'),
    ['0x72cc6E4DE47f673062c41C67505188144a0a3D84'],
    { kind: 'uups' }
  )) as DaoManager

  await DaoManager.deployed()

  console.log('DaoManager:', DaoManager.address)

  const implementationAddress = await upgrades.erc1967.getImplementationAddress(
    DaoManager.address
  )

  console.log('DaoManager Implementation:', implementationAddress)

  await new Promise((r) => setTimeout(r, 10000))

  try {
    await run('verify:verify', {
      address: implementationAddress,
      contract: 'contracts/modules/DaoManager.sol:DaoManager'
    })
  } catch {
    console.log('Verification problem (DaoManager)')
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })
