const { expect } = require("chai");

describe("MangroveMaker", function () {
  let MangroveMaker;
  let contract;

  // This runs before each test and deploys a new instance of the contract
  beforeEach(async function () {
    MangroveMaker = await ethers.getContractFactory("MangroveMaker");

    // Example values for testing
    let initialMgv = "0xd1805f6Fe12aFF69D4264aE3e49ef320895e2D8b";
    let initialSpread = 100;
    let initialVolume = 5111458023868900;
    let initialTenacity = 10;
    let initialPairs = [["0x87acc29a0c619cC99921A1d3DE71f389B5e93C12", "0xd92412a3dAa84795F5dD4156BE7B5279161A5876"]];
    let initialOtherDexFactory = "0x5757371414417b8C6CAad45bAeF941aBc7d3Ab32";
    let initialOtherDexFees = 30
    // let initialOtherDexRouter = "0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff";
    
    contract = await MangroveMaker.deploy(initialMgv, initialSpread, initialVolume, initialTenacity, initialPairs,initialOtherDexFactory, initialOtherDexFees);
});
it("Should update the data correctly", async function () {
  // Example update values
  let newMgv = "0xd1805f6Fe12aFF69D4264aE3e49ef320895e2D8b";
  let newSpread = 200;
  let newVolume = 5111458023868900;
  let newTenacity = 20;
  let newPairs = [["0x87acc29a0c619cC99921A1d3DE71f389B5e93C12", "0xd92412a3dAa84795F5dD4156BE7B5279161A5876"]];
  let newOtherDexFactory = "0x5757371414417b8C6CAad45bAeF941aBc7d3Ab32";
  let newOtherDexFees = 30
  // let newOtherDexRouter = "0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff";

  const tx = await contract.updateData(newMgv, newSpread, newVolume, newTenacity, newPairs, newOtherDexFactory,newOtherDexFees);
  // const receipt = await tx.wait();
  // const logs = receipt.events;
  // console.log(logs);


  expect(await contract.mgv()).to.equal(newMgv);
  expect(await contract.spread()).to.equal(newSpread);
  expect(await contract.volume()).to.equal(newVolume);
  expect(await contract.tenacity()).to.equal(newTenacity);
  expect(await contract.otherDexFactory()).to.equal(newOtherDexFactory);
  expect(await contract.otherDexFees()).to.equal(newOtherDexFees);
  // expect(await contract.otherDexRouter()).to.equal(newOtherDexRouter);

  let pairs = await contract.getTrackedPairs();

  for(let i=0; i<newPairs.length; i++) {
    expect(pairs[i][0]).to.equal(newPairs[i][0]);
    expect(pairs[i][1]).to.equal(newPairs[i][1]);
  }
  
});
it("Should create offers correctly",async function(){
      await contract.createOffers();

  });

});
