// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");

async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled
  // await hre.run('compile');

  // We get the contract to deploy
  const MangroveMaker = await hre.ethers.getContractFactory("MangroveMaker");
  const signers = await ethers.getSigners();
  const deployer = signers[0];


  let MGRV = "0xd1805f6Fe12aFF69D4264aE3e49ef320895e2D8b";
  let initialSpread = 100;
  let initialVolume = 5111458023868900;
  let initialTenacity = 10;
  let initialPairs = [["0x87acc29a0c619cC99921A1d3DE71f389B5e93C12", "0xd92412a3dAa84795F5dD4156BE7B5279161A5876"]];
  let initialOtherDexFactory = "0x5757371414417b8C6CAad45bAeF941aBc7d3Ab32";
  let initialOtherDexFees = 30;
  const contract = await MangroveMaker.deploy(MGRV, initialSpread, initialVolume, initialTenacity, initialPairs,initialOtherDexFactory, initialOtherDexFees,deployer.address);

  await contract.deployed();

  console.log("contract deployed to:", contract.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
