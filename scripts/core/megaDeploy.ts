import dayjs from 'dayjs'
import * as dotenv from 'dotenv'
import { BigNumber } from 'ethers'
import { arrayify, parseEther } from 'ethers/lib/utils'
import { ethers, network, upgrades } from 'hardhat'

import { createData, executeTx } from '../../test/utils'
import {
  Dao__factory,
  DaoManager,
  DaoViewer__factory,
  DividendsModule__factory,
  DocumentSignModule,
  Factory__factory,
  LaunchpadModule,
  NamedToken__factory,
  PayrollModule,
  PrivateExitModule__factory,
  Shop__factory,
  SubscriptionManager,
  VestingModule,
  XDAO__factory,
  XDAOQuestAwards__factory
} from '../../typechain-types'

dotenv.config()

async function main() {
  await network.provider.request({ method: 'hardhat_reset', params: [] })

  const [signer, friend, address1, address2, address3] =
    await ethers.getSigners()

  const shop = await new Shop__factory(signer).deploy()

  console.log('Shop:', shop.address)

  const xdaoToken = await new XDAO__factory(signer).deploy()

  console.log('XDAO Token:', xdaoToken.address)

  const factory = await new Factory__factory(signer).deploy(
    shop.address,
    xdaoToken.address
  )

  console.log('Factory:', factory.address)

  console.log('Setting Factory Address to Shop')

  await shop.setFactory(factory.address)

  console.log('Success: Setting Factory Address to Shop')

  const daoViewer = await new DaoViewer__factory(signer).deploy()

  console.log('Dao Viewer:', daoViewer.address)

  await factory.create(
    'AloneDAO',
    'ALONE',
    51,
    [signer.address],
    [parseEther('10')]
  )

  await factory.create(
    'FriendsDAO',
    'FRIENDS',
    51,
    [signer.address, friend.address],
    [parseEther('10'), parseEther('10')]
  )

  await factory.create(
    'WithLP',
    'WITHLP',
    51,
    [signer.address],
    [parseEther('10')]
  )

  await factory.create(
    'PrivateDAO',
    'PRIVATE',
    51,
    [signer.address],
    [parseEther('10')]
  )

  await factory.create(
    'PublicDAO',
    'PUBLIC',
    51,
    [signer.address],
    [parseEther('10')]
  )

  await factory.create(
    'ComplexDAO',
    'COMPLEX',
    51,
    [signer.address],
    [parseEther('10')]
  )

  console.log('Deployed 6 DAOs')

  const usdc = await new NamedToken__factory(signer).deploy('USDC', 'USDC')

  console.log('USDC Token:', usdc.address)

  const btc = await new NamedToken__factory(signer).deploy('BTC', 'BTC')

  console.log('BTC Token:', btc.address)

  const sol = await new NamedToken__factory(signer).deploy('SOL', 'SOL')

  console.log('SOL Token:', sol.address)

  for (const i of [2, 3, 4, 5]) {
    await executeTx(
      await factory.daoAt(i),
      shop.address,
      'createLp',
      ['string', 'string'],
      ['LP', 'LP'],
      0,
      signer
    )
  }

  for (const i of [3, 5]) {
    await executeTx(
      await factory.daoAt(i),
      shop.address,
      'createPrivateOffer',
      ['address', 'address', 'uint256', 'uint256'],
      [
        signer.address,
        [usdc, btc, sol][i - 3].address,
        parseEther('1.6'),
        parseEther('3.5')
      ],
      0,
      signer
    )

    await executeTx(
      await factory.daoAt(i),
      shop.address,
      'createPrivateOffer',
      ['address', 'address', 'uint256', 'uint256'],
      [
        friend.address,
        [usdc, btc, sol][5 - i].address,
        parseEther('1.7'),
        parseEther('3.9')
      ],
      0,
      signer
    )

    await executeTx(
      await factory.daoAt(i),
      shop.address,
      'createPrivateOffer',
      ['address', 'address', 'uint256', 'uint256'],
      [
        signer.address,
        [usdc, btc, sol][5 - i].address,
        parseEther('2.6'),
        parseEther('4.2')
      ],
      0,
      signer
    )

    await executeTx(
      await factory.daoAt(i),
      shop.address,
      'disablePrivateOffer',
      ['uint256'],
      [2],
      0,
      signer
    )
  }

  for (const i of [4, 5]) {
    await executeTx(
      await factory.daoAt(i),
      shop.address,
      'initPublicOffer',
      ['bool', 'address', 'uint256'],
      ['true', [usdc, btc, sol][i - 4].address, parseEther('1.5')],
      0,
      signer
    )
  }

  const privateExitModule = await new PrivateExitModule__factory(
    signer
  ).deploy()

  console.log('PrivateExitModule:', privateExitModule.address)

  const dividendsModule = await new DividendsModule__factory(signer).deploy()

  console.log('DividendsModule:', dividendsModule.address)

  const launchpadModule = (await upgrades.deployProxy(
    await ethers.getContractFactory('LaunchpadModule')
  )) as LaunchpadModule

  await launchpadModule.setCoreAddresses(
    factory.address,
    shop.address,
    privateExitModule.address
  )

  console.log('LaunchpadModule:', launchpadModule.address)

  await executeTx(
    await factory.daoAt(5),
    launchpadModule.address,
    'initSale',
    [
      'address',
      'uint256',
      'bool[4]',
      'uint256',
      'uint256',
      'address[]',
      'uint256[]',
      'address[]'
    ],
    [
      usdc.address,
      parseEther('2'),
      [true, true, true, true],
      dayjs().add(3, 'day').unix(),
      parseEther('12'),
      [signer.address, friend.address],
      [parseEther('1.4'), parseEther('2.7')],
      []
    ],
    0,
    signer
  )

  const payrollModule = (await upgrades.deployProxy(
    await ethers.getContractFactory('PayrollModule'),
    [factory.address]
  )) as PayrollModule

  console.log('PayrollModule:', payrollModule.address)

  const documentSignModule = (await upgrades.deployProxy(
    await ethers.getContractFactory('DocumentSignModule'),
    [factory.address]
  )) as DocumentSignModule

  console.log('DocumentSignModule:', documentSignModule.address)

  const privateVestingModule = (await upgrades.deployProxy(
    await ethers.getContractFactory('VestingModule'),
    [
      usdc.address,
      dayjs().unix(),
      dayjs().add(1, 'week').unix() - dayjs().unix()
    ]
  )) as VestingModule

  console.log('VestingModule (Private Round):', privateVestingModule.address)

  const seedVestingModule = (await upgrades.deployProxy(
    await ethers.getContractFactory('VestingModule'),
    [
      sol.address,
      dayjs().subtract(1, 'week').unix(),
      dayjs().add(4, 'week').unix() - dayjs().unix()
    ]
  )) as VestingModule

  console.log('VestingModule (Seed Round):', seedVestingModule.address)

  await privateVestingModule.addAllocations(
    [signer.address, friend.address],
    [parseEther('1'), parseEther('2')]
  )

  await seedVestingModule.addAllocations([signer.address], [parseEther('5')])

  const subscriptionManager = (await upgrades.deployProxy(
    await ethers.getContractFactory('SubscriptionManager'),
    [
      xdaoToken.address,
      await factory.daoAt(0),
      BigNumber.from(2592000) // 30 days
    ]
  )) as SubscriptionManager

  console.log('SubscriptionManager:', subscriptionManager.address)

  const xdaoAwards = await new XDAOQuestAwards__factory(signer).deploy()
  await xdaoAwards.mintBatch(signer.address, [0, 1], [10, 10], '0x')

  console.log('ERC1155 XDAO Awards:', xdaoAwards.address)

  await subscriptionManager.grantRole(
    await subscriptionManager.MANAGER_ROLE(),
    friend.address
  )
  await subscriptionManager.editDurationPerToken(0, BigNumber.from(129600)) // 30 days per 20 tokens
  await subscriptionManager.editDurationPerToken(1, BigNumber.from(25920)) // 30 days per 100 tokens

  await subscriptionManager.editReceivableERC1155(
    xdaoAwards.address,
    0,
    0,
    BigNumber.from(2592000)
  ) // 30 days
  await subscriptionManager.editReceivableERC1155(
    xdaoAwards.address,
    1,
    1,
    BigNumber.from(7776000)
  ) // 90 days

  const daoManager = (await upgrades.deployProxy(
    await ethers.getContractFactory('DaoManager'),
    [factory.address]
  )) as DaoManager

  console.log('DaoManager:', daoManager.address)

  const AloneDAOAddress = await factory.daoAt(0)
  const AloneDAO = await Dao__factory.connect(await factory.daoAt(0), signer)

  await executeTx(
    AloneDAOAddress,
    AloneDAOAddress,
    'addPermitted',
    ['address'],
    [daoManager.address],
    0,
    signer
  )

  console.log('AloneDAO: added DaoManager to permitted')

  const timestamp = dayjs().unix()
  const targetList = [AloneDAOAddress, AloneDAOAddress, AloneDAOAddress]
  const dataList = [
    createData('mint', ['address', 'uint256'], [address1.address, 1]),
    createData('mint', ['address', 'uint256'], [address2.address, 2]),
    createData('mint', ['address', 'uint256'], [address3.address, 3])
  ]
  const valueList = [0, 0, 0]

  const data = createData(
    'addArgsHash',
    ['bytes32'],
    [
      await daoManager.calculateArgsHash(
        AloneDAOAddress,
        targetList,
        dataList,
        valueList
      )
    ]
  )

  const txHash = await AloneDAO.getTxHash(
    daoManager.address,
    data,
    0,
    0,
    timestamp
  )
  const signature = await signer.signMessage(arrayify(txHash))

  await daoManager.activate(
    AloneDAOAddress,
    targetList,
    dataList,
    valueList,
    0,
    timestamp,
    [signature]
  )

  const balance1 = await AloneDAO.balanceOf(address1.address)
  const balance2 = await AloneDAO.balanceOf(address2.address)
  const balance3 = await AloneDAO.balanceOf(address3.address)

  console.log('Balances:', balance1, balance2, balance3)

  console.log('Done')
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })
