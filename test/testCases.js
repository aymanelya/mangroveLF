const { expect } = require('chai');
const { Mangrove } = require('@mangrovedao/mangrove.js');

const orderABI = require('./mangroveOrderABI.json');
// const BigNumber = require('bignumber.js');

const takerAccount = {
  address: '0x8626f6940e2eb28930efb4cef49b2d1f2c9c1199',
  privateKey:
    '0xdf57089febbacf7ba0bc227dafbffa9fc08a93fdc68e1e42411a14efcf23656e',
};
let MGRV = '0xd1805f6Fe12aFF69D4264aE3e49ef320895e2D8b';

let globalPairs = [];

function hex_to_ascii(str1) {
  var hex = str1.toString();
  var str = '';
  for (var n = 0; n < hex.length; n += 2) {
    str += String.fromCharCode(parseInt(hex.substr(n, 2), 16));
  }
  return str;
}

let deployerAddress;

describe('MangroveMaker', function () {
  let MangroveMaker;
  let contract;

  // This runs before each test and deploys a new instance of the contract
  beforeEach(async function () {
    const MangroveMaker = await ethers.getContractFactory('MangroveMaker');

    const signers = await ethers.getSigners();
    const deployer = signers[1];
    deployerAddress = deployer.address;
    console.log('Deployer address:', deployer.address);

    // Fetch current gas price from the network
    const gasPrice = await ethers.provider.getGasPrice();
    console.log(`Current gas price: ${gasPrice.toString()}`);

    // [
    //   {
    //     address: '0x193163EeFfc795F9d573b171aB12cCDdE10392e8',
    //     name: 'WMATIC',
    //   },
    //   {
    //     address: '0xf402f6197d979F0A4cba61596921a3d762520570',
    //     name: 'WBTC',
    //   },
    //   {
    //     address: '0xe8099699aa4A79d89dBD20A63C50b7d35ED3CD9e',
    //     name: 'USDT',
    //   },
    // ];

    // Example values for testing
    let MGRV = '0xd1805f6Fe12aFF69D4264aE3e49ef320895e2D8b';
    let initialSpreads = [2];
    let initialVolumes = [200e6]; //in USDT
    let initialTenacities = [10];
    let initialPairs = [
      [
        '0x193163EeFfc795F9d573b171aB12cCDdE10392e8',
        '0xe8099699aa4A79d89dBD20A63C50b7d35ED3CD9e',
      ],
    ];
    let initialOtherDexFactory = '0x5757371414417b8C6CAad45bAeF941aBc7d3Ab32';
    let initialOtherDexRouter = '0x8954AfA98594b838bda56FE4C12a09D7739D179b';
    // let initialOtherDexFees = 30;

    const transaction = await MangroveMaker.getDeployTransaction(
      MGRV,
      initialSpreads,
      initialVolumes,
      initialTenacities,
      initialPairs,
      initialOtherDexFactory,
      initialOtherDexRouter,
      // initialOtherDexFees,
      deployer.address
    );
    // const gasLimit = transaction.gasLimit;
    // console.log(`Gas limit for deployment: ${gasLimit.toString()}`);

    contract = await deployer.sendTransaction(transaction);
    const receipt = await contract.wait();
    contract = await MangroveMaker.deploy(
      MGRV,
      initialSpreads,
      initialVolumes,
      initialTenacities,
      initialPairs,
      initialOtherDexFactory,
      initialOtherDexRouter,
      // initialOtherDexFees,
      deployer.address
    );

    console.log(`Gas used for deployment: ${receipt.gasUsed.toString()}`);
    console.log(
      `Total cost of deployment: ${receipt.gasUsed.mul(gasPrice).toString()}`
    );
    console.log('contract address:', contract.address);
  });

  it('Should update the data correctly', async function () {
    // Example update values
    let newSpreads = [2];
    let newVolumes = [200e6]; //in USDT
    let newTenacities = [20];
    let newPairs = [
      [
        '0x193163EeFfc795F9d573b171aB12cCDdE10392e8',
        '0xe8099699aa4A79d89dBD20A63C50b7d35ED3CD9e',
      ],
    ];
    let newOtherDexFactory = '0x5757371414417b8C6CAad45bAeF941aBc7d3Ab32';
    let newOtherDexRouter = '0x8954AfA98594b838bda56FE4C12a09D7739D179b';
    // let newOtherDexFees = 30;
    // let newOtherDexRouter = "0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff";

    const tx = await contract.updateParams(
      newSpreads,
      newVolumes,
      newTenacities,
      newPairs,
      newOtherDexFactory,
      newOtherDexRouter
      // newOtherDexFees
    );
    // const receipt = await tx.wait();
    // const logs = receipt.events;
    // console.log(logs);

    globalPairs = newPairs;

    const pairs = await contract.getTrackedPairs();
    for (let i = 0; i < newPairs.length; i++) {
      expect(pairs[i][0]).to.equal(newPairs[i][0]);
      expect(pairs[i][1]).to.equal(newPairs[i][1]);
    }
  });
  it('Should create initial offers correctly and snipe them and withdraw', async function () {
    const res = await contract.createInitialOffers({
      value: ethers.utils.parseEther('0.6'),
    });

    const takerWallet = new ethers.Wallet(
      takerAccount.privateKey,
      ethers.provider
    );
    // Connect the API to Mangrove
    const mgv = await Mangrove.connect({ signer: takerWallet });

    // Connect mgv to a DAI, USDC market
    const market = await mgv.market({ base: 'WMATIC', quote: 'USDT' });
    console.log('***** BALANCES BEFORE MINTS ******');
    console.log('MATIC');
    console.log(
      'deployer',
      ethers.utils.formatEther(
        await ethers.provider.getBalance(deployerAddress)
      )
    );
    console.log(
      'contract',
      ethers.utils.formatEther(
        await ethers.provider.getBalance(contract.address)
      )
    );
    console.log(
      'taker',
      ethers.utils.formatEther(
        await ethers.provider.getBalance(takerWallet.address)
      )
    );
    console.log('WMATIC');
    console.log('deployer', await market.base.balanceOf(deployerAddress));
    console.log('contract', await market.base.balanceOf(contract.address));
    console.log('taker', await market.base.balanceOf(takerWallet.address));
    console.log('USDT');
    console.log('deployer', await market.quote.balanceOf(deployerAddress));
    console.log('contract', await market.quote.balanceOf(contract.address));
    console.log('taker', await market.quote.balanceOf(takerWallet.address));

    // Mint enough tokens for the taker's wallet
    await market.quote.contract.mintTo(
      // minting USDT if you are on testnet
      takerWallet.address,
      ethers.utils.parseUnits('1000', market.quote.decimals)
    );

    await market.base.contract.mintTo(
      // minting WMATIC if you are on testnet
      takerWallet.address,
      ethers.utils.parseUnits('1000', market.base.decimals)
    );
    console.log('***** BALANCES AFTER MINTS ******');
    console.log('MATIC');
    console.log(
      'deployer',
      ethers.utils.formatEther(
        await ethers.provider.getBalance(deployerAddress)
      )
    );
    console.log(
      'contract',
      ethers.utils.formatEther(
        await ethers.provider.getBalance(contract.address)
      )
    );
    console.log(
      'taker',
      ethers.utils.formatEther(
        await ethers.provider.getBalance(takerWallet.address)
      )
    );
    console.log('WMATIC');
    console.log('deployer', await market.base.balanceOf(deployerAddress));
    console.log('contract', await market.base.balanceOf(contract.address));
    console.log('taker', await market.base.balanceOf(takerWallet.address));
    console.log('USDT');
    console.log('deployer', await market.quote.balanceOf(deployerAddress));
    console.log('contract', await market.quote.balanceOf(contract.address));
    console.log('taker', await market.quote.balanceOf(takerWallet.address));

    const offerLists = await contract.getOfferLists();
    for (let i = 0; i < globalPairs.length; i++) {
      for (let j = 0; j < offerLists[i].length; j++) {
        let isAsk;
        const offerId = parseInt(offerLists[i][j]);
        console.log(offerId);
        // // Get all the info about the offer
        let offer = await market.getSemibook('asks').offerInfo(offerId);
        isAsk = offer.price ? true : false;
        if (!isAsk) {
          offer = await market.getSemibook('bids').offerInfo(offerId);
        }
        // // Log offer to see what data in holds
        console.log(offer);
        // continue;
        // // Approve Mangrove to take USDC from your account
        await mgv.approveMangrove('USDT');
        await mgv.approveMangrove('WMATIC');

        // // Snipe the offer using the information about the offer.
        let snipePromises = await market.snipe({
          targets: [
            {
              offerId: offer.id,
              takerWants: offer.gives,
              takerGives: offer.wants,
              gasLimit: offer.gasreq, // not mandatory
            },
          ],
          ba: isAsk ? 'asks' : 'bids',
        });
        let result = await snipePromises.result;

        // Log the result of snipe

        console.log(result);

        const MGRV_CONTRACT = new ethers.Contract(
          MGRV,
          orderABI,
          ethers.provider
        );

        for (let log of result.txReceipt.logs) {
          try {
            let parsedLog = MGRV_CONTRACT.interface.parseLog(log);
            if (parsedLog.name == 'PosthookFail') {
              console.log(parsedLog);
              console.log(
                `********** DECODED POSTHOOKFAIL ***********\n${ethers.utils.parseBytes32String(
                  parsedLog.args[parsedLog.args.length - 1]
                )}\n*********************************`
              );
            }
          } catch (error) {
            // console.log('Failed to parse log: ', error.toString());
          }
        }

        cconsole.log('***** BALANCES AFTER SNIPES ******');
        console.log('MATIC');
        console.log(
          'deployer',
          ethers.utils.formatEther(
            await ethers.provider.getBalance(deployerAddress)
          )
        );
        console.log(
          'contract',
          ethers.utils.formatEther(
            await ethers.provider.getBalance(contract.address)
          )
        );
        console.log(
          'taker',
          ethers.utils.formatEther(
            await ethers.provider.getBalance(takerWallet.address)
          )
        );
        console.log('WMATIC');
        console.log('deployer', await market.base.balanceOf(deployerAddress));
        console.log('contract', await market.base.balanceOf(contract.address));
        console.log('taker', await market.base.balanceOf(takerWallet.address));
        console.log('USDT');
        console.log('deployer', await market.quote.balanceOf(deployerAddress));
        console.log('contract', await market.quote.balanceOf(contract.address));
        console.log('taker', await market.quote.balanceOf(takerWallet.address));

        // await contract.withdraw(
        //   0,
        //   market.base.address,
        //   false,
        // );
        // console.log("MATIC")
        // console.log("deployer",ethers.utils.formatEther(await (ethers.provider.getBalance(deployerAddress))))
        // console.log("contract",ethers.utils.formatEther(await (ethers.provider.getBalance(contract.address))))
        // console.log("taker",ethers.utils.formatEther(await (ethers.provider.getBalance(takerWallet.address))))
        // console.log("WMATIC")
        // console.log("deployer",await market.base.balanceOf(deployerAddress))
        // console.log("contract",await market.base.balanceOf(contract.address))
        // console.log("taker",await market.base.balanceOf(takerWallet.address))
        // console.log("USDT")
        // console.log("deployer",await market.quote.balanceOf(deployerAddress))
        // console.log("contract",await market.quote.balanceOf(contract.address))
        // console.log("taker",await market.quote.balanceOf(takerWallet.address))

        // await contract.withdraw(
        //   0,
        //   market.quote.address,
        //   false,
        // );
        // console.log("MATIC")
        // console.log("deployer",ethers.utils.formatEther(await (ethers.provider.getBalance(deployerAddress))))
        // console.log("contract",ethers.utils.formatEther(await (ethers.provider.getBalance(contract.address))))
        // console.log("taker",ethers.utils.formatEther(await (ethers.provider.getBalance(takerWallet.address))))
        // console.log("WMATIC")
        // console.log("deployer",await market.base.balanceOf(deployerAddress))
        // console.log("contract",await market.base.balanceOf(contract.address))
        // console.log("taker",await market.base.balanceOf(takerWallet.address))
        // console.log("USDT")
        // console.log("deployer",await market.quote.balanceOf(deployerAddress))
        // console.log("contract",await market.quote.balanceOf(contract.address))
        // console.log("taker",await market.quote.balanceOf(takerWallet.address))
        // await contract.withdraw(
        //   0,
        //   "0",
        //   true,
        // );
        // console.log("MATIC")
        // console.log("deployer",ethers.utils.formatEther(await (ethers.provider.getBalance(deployerAddress))))
        // console.log("contract",ethers.utils.formatEther(await (ethers.provider.getBalance(contract.address))))
        // console.log("taker",ethers.utils.formatEther(await (ethers.provider.getBalance(takerWallet.address))))
        // console.log("WMATIC")
        // console.log("deployer",await market.base.balanceOf(deployerAddress))
        // console.log("contract",await market.base.balanceOf(contract.address))
        // console.log("taker",await market.base.balanceOf(takerWallet.address))
        // console.log("USDT")
        // console.log("deployer",await market.quote.balanceOf(deployerAddress))
        // console.log("contract",await market.quote.balanceOf(contract.address))
        // console.log("taker",await market.quote.balanceOf(takerWallet.address))
      }
    }
  });
});
