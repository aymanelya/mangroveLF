require('@nomiclabs/hardhat-waffle');

const fs = require('fs');
const pk = fs.readFileSync('.secret').toString().trim();

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task('accounts', 'Prints the list of accounts', async (taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  solidity: '0.8.13',
  settings: {
    remappings: [
      'mgv_src/=node_modules/@mangrovedao/mangrove-core/src/',
      'mgv_lib/=node_modules/@mangrovedao/mangrove-core/lib/',
      'mgv_test/=node_modules/@mangrovedao/mangrove-core/test/',
      'mgv_script/=node_modules/@mangrovedao/mangrove-core/script/'
    ],
    optimizer: {
      enabled: true,
      runs: 200,
    },
  },
  mocha: {
    timeout: 400000,
  },
  networks: {
    hardhat: {
      allowUnlimitedContractSize: true,
      chainId: 80001,
      forking: {
        url: 'https://rpc.ankr.com/polygon_mumbai',
        chainId: 80001,
        accounts: [pk],
      },
    },
    polygon: {
      url: 'http://localhost:8545',
      accounts: [pk],
    },
    mumbai: {
      url: 'https://rpc.ankr.com/polygon_mumbai',
      accounts: [pk],
    },
    local: {
      url: 'http://127.0.0.1:8545/',
      // accounts: [pk],
      accounts: [
        '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80',
      ],
    },

    // bscMainnet: {
    //   url: "https://bsc-dataseed.binance.org/",
    //   gasPrice: 5000000000,
    //   accounts: [pk]
    // }
  },
};
