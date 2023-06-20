require("@nomiclabs/hardhat-ethers");

module.exports= {
  networks: {
    hardhat: {
      allowUnlimitedContractSize:true,
      chainId: 80001,
    },
  },
};