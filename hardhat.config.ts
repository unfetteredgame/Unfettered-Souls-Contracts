import {utils} from 'ethers';
require('dotenv').config();

import {task, HardhatUserConfig} from 'hardhat/config';
import '@typechain/hardhat';
import '@nomiclabs/hardhat-ethers';
import '@nomiclabs/hardhat-waffle';
import '@nomiclabs/hardhat-solhint';
import 'solidity-coverage';
import '@nomiclabs/hardhat-etherscan';
import {ethers} from 'ethers';
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
const config: HardhatUserConfig = {
  mocha: {
    timeout: 100000000,
  },
  solidity: {
    compilers: [
      {
        version: '0.5.0',
      },
      {
        version: '0.5.16',
      },
      {
        version: '0.8.3',
      },
      {
        version: '0.6.6',
      },
      {
        version: '0.8.12',
        settings: {},
      },
    ],
    settings: {
      optimizer: {
        enabled: false,
        runs: 200,
      },
    },
  },
  networks: {
    localhost: {
      chainId: 1337,
    },
    hardhat: {
      //gasPrice: 0,
      //initialBaseFeePerGas: 0,
      mining: {
        auto: true,
        interval: 3000,
      },
      forking: {
        // url: process.env.POLYGON_MAINNET_RPC_URL!,
        url: process.env.POLYGON_MAINNET_RPC_URL!,
      },
      accounts: [
        {privateKey: process.env.PRODUCTION_PRIVATE_KEY!, balance: ethers.utils.parseEther('10000').toString()},
      ],
      chainId: 1337,
      blockGasLimit: 900000000000,
      allowUnlimitedContractSize: true,
    },
    mumbai: {
      url: 'https://rpc-mumbai.maticvigil.com',
      accounts: {
        count: 30,
        mnemonic: process.env.MNEMONIC,
        path: "m/44'/60'/0'/0",
      },
      chainId: 80001,
    },
    polygon: {
      url: process.env.POLYGON_MAINNET_RPC_URL!,
      accounts: [process.env.PRODUCTION_PRIVATE_KEY!],
      chainId: 137,
    },
  },

  etherscan: {
    apiKey: {
      polygonMumbai: process.env.EXPLORER_API_KEY!,
      polygon: process.env.EXPLORER_API_KEY!,
    },
  },
};

export default config;
