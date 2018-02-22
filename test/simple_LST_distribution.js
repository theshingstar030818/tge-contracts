var SimpleLSTDistribution = artifacts.require("SimpleLSTDistribution");
var SimplePreTGE = artifacts.require("SimplePreTGE");
var SimpleTGE = artifacts.require("SimpleTGE");

const BigNumber = web3.BigNumber;
require('chai')
  .use(require('chai-as-promised'))
  .use(require('chai-bignumber')(BigNumber))
  .should();

function advanceBlock () {
  return new Promise((resolve, reject) => {
    web3.currentProvider.sendAsync({
      jsonrpc: '2.0',
      method: 'evm_mine',
      id: Date.now(),
    }, (err, res) => {
      return err ? reject(err) : resolve(res);
    });
  });
};

function increaseTime (duration) {
  const id = Date.now();

  return new Promise((resolve, reject) => {
    web3.currentProvider.sendAsync({
      jsonrpc: '2.0',
      method: 'evm_increaseTime',
      params: [duration],
      id: id,
    }, err1 => {
      if (err1) return reject(err1);

      web3.currentProvider.sendAsync({
        jsonrpc: '2.0',
        method: 'evm_mine',
        id: id + 1,
      }, (err2, res) => {
        return err2 ? reject(err2) : resolve(res);
      });
    });
  });
};

const duration = {
  seconds: function (val) { return val; },
  minutes: function (val) { return val * this.seconds(60); },
  hours: function (val) { return val * this.minutes(60); },
  days: function (val) { return val * this.hours(24); },
  weeks: function (val) { return val * this.days(7); },
  years: function (val) { return val * this.days(365); },
};
/*

should reject withdrawal request if the requester has not contributed in the pre-TGE and TGE

should reject withdrawal if user has already successfully run withdraw function once.
should reject withdrawal if TGE / TRS subscription is still running
should reject withdrawal if allocations are not locked in the pre-TGE

should calculate _totalWeiContribution by adding contributions by an address to both pre-TGE and TGE contracts
should compute vesting decision if vesting decision is true in either of the pre-TGE and TGE contracts

should properly save the hasWithdrawn parameter for the contributor in allocations dict
should properly save the vesting decision parameter for the contributor allocations dict
should properly save the weiContributed parameter for the contributor allocations dict
should calculate the _lstAllocated based on the rate and the weiContributed and save it in the allocations dict

should mint exactly 100% of the allocated tokens to the contributors address if they have not vested
should mint exactly 10% of the allocated tokens to the contributors address if they have vested
should mint exactly 90% of the allocated tokens to the contributors tokenvesting address if they have vested
should allow only the respective contributor to access their tokenvesting withdrawal

should allow withdrawal from the tokenvesting contract according to the release schedule

should only allow the respective contributor to run withdrawal function for themselves
should only allow the respective contributor to run release function in the tokenvesting contract for themselves

*/


contract("SimpleLSTDistribution", function(accounts) {
  const _SimplePreTGEAddress = accounts[1];
  const _SimpleTGEAddress = accounts[2];
  const _LSTTokenAddress = accounts[3];
  const _vestingBonusMultiplier = 5000000;
  const _vestingDuration = 31536000;
  const _vestingStartTime = 1519323884;

  const preTGEAddresses = [
    accounts[1],
    accounts[2],
    accounts[3]
  ];
  const preTGEWeiContributions = [
    50000,
    500000,
    5000000,
  ];
  const preTGEVestingDecisions = [
    true,
    false,
    true,
  ];

  const fundsWallet = accounts[4];
  const individualCapInWei = 10;
  const totalCapInWei = 15;

  // These variables are updated by the beforeEach hook for each test
  mostRecentStartTime = 0;
  mostRecentEndTime = 0;

  // TODO how many accounts do we get access to via accounts?
  const validWhiteListAddresses = [
    accounts[1],
    accounts[2],
    accounts[5]
  ];


  function blockTimeStamp()  {
    return web3.eth.getBlock('latest').timestamp;
  };

  beforeEach(async function() {
    const startTime = blockTimeStamp()+1;
    // Give all tests a 5 minute buffer to complete
    const endTime = startTime + 300;

    let SimplePreTGEContract = await SimplePreTGE.new();
    await SimplePreTGEContract.bulkReserveTokensForAddresses(preTGEAddresses,preTGEWeiContributions,preTGEVestingDecisions);

    let SimpleTGEContract = await SimpleTGE.new(fundsWallet, startTime, endTime, individualCapInWei, totalCapInWei);
    await SimpleTGEContract.whitelistAddresses(validWhiteListAddresses);
    //for (var i = 0; i < validWhiteListAddresses.length; i++) {
    //  const address = validWhiteListAddresses[i];
    //  await SimpleTGEContract.contributeAndVest({value: 1, from: address});
    //}
    //await SimpleTGEContract.contributeWithoutVesting({value: 3, from: validWhiteListAddresses[1]});

    await increaseTime(duration.seconds(5));
    await advanceBlock();

//    this.contract = await SimpleLSTDistribution.new(SimplePreTGEContract, SimpleTGEContract, _LSTTokenAddress, _vestingBonusMultiplier, _vestingDuration, _vestingStartTime);

  });

  it("should not deploy the contract if _SimplePreTGEAddress is not a valid address", async function() {
    this.contract = await SimpleLSTDistribution.new(0, _SimpleTGEAddress, _LSTTokenAddress, _vestingBonusMultiplier, _vestingDuration, _vestingStartTime).should.be.rejectedWith('revert');
  });

  it("should not deploy the contract if _SimpleTGEAddress is not a valid address", async function() {
    this.contract = await SimpleLSTDistribution.new(_SimplePreTGEAddress, 0, _LSTTokenAddress, _vestingBonusMultiplier, _vestingDuration, _vestingStartTime).should.be.rejectedWith('revert');
  });

  it("should not deploy the contract if _LSTTokenAddress is not a valid address", async function() {
    this.contract = await SimpleLSTDistribution.new(_SimplePreTGEAddress, _SimpleTGEAddress, 0, _vestingBonusMultiplier, _vestingDuration, _vestingStartTime).should.be.rejectedWith('revert');
  });

  it("should not deploy the contract if _vestingBonusMultiplier is less than 1000000", async function() {
    this.contract = await SimpleLSTDistribution.new(_SimplePreTGEAddress, _SimpleTGEAddress, _LSTTokenAddress, 100000, _vestingDuration, _vestingStartTime).should.be.rejectedWith('revert');
  });

  it("should not deploy the contract if _vestingBonusMultiplier is not more than 10000000", async function() {
    this.contract = await SimpleLSTDistribution.new(_SimplePreTGEAddress, _SimpleTGEAddress, _LSTTokenAddress, 10000001, _vestingDuration, _vestingStartTime).should.be.rejectedWith('revert');
  });

  it("should not deploy the contract if _vestingDuration is 0", async function() {
    this.contract = await SimpleLSTDistribution.new(_SimplePreTGEAddress, _SimpleTGEAddress, _LSTTokenAddress, _vestingBonusMultiplier, 0, _vestingStartTime).should.be.rejectedWith('revert');
  });

  it("should not deploy the contract if _vestingStartTime is earlier than the current blocks timestamp", async function() {
    this.contract = await SimpleLSTDistribution.new(_SimplePreTGEAddress, _SimpleTGEAddress, _LSTTokenAddress, _vestingBonusMultiplier, _vestingDuration, 0).should.be.rejectedWith('revert');
  });




});
