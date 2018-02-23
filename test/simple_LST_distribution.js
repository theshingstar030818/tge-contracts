var SimpleLSTDistribution = artifacts.require("SimpleLSTDistribution");
var SimplePreTGE = artifacts.require("SimplePreTGE");
var SimpleTGE = artifacts.require("SimpleTGE");
var LendroidSupportToken = artifacts.require("LendroidSupportToken");

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

should reject withdrawal if TGE / TRS subscription is still running
should reject withdrawal if allocations are not locked in the pre-TGE
should reject withdrawal request if the requester has not contributed in the pre-TGE and TGE
should mint exactly 100% of the allocated tokens to the contributors address if they have not vested
should reject withdrawal if user has already successfully run withdraw function once.
should calculate _totalWeiContribution by adding contributions by an address to both pre-TGE and TGE contracts
should properly save the hasWithdrawn parameter for the contributor in allocations dict
should properly save the vesting decision parameter for the contributor allocations dict
should properly save the weiContributed parameter for the contributor allocations dict
should calculate the _lstAllocated based on the rate and the weiContributed and save it in the allocations dict
should mint exactly 10% of the allocated tokens to the contributors address if they have vested
should mint exactly 90% of the allocated tokens to the contributors tokenvesting address if they have vested

should compute vesting decision if vesting decision is true in either of the pre-TGE and TGE contracts
should allow withdrawal from the tokenvesting contract according to the release schedule

---
All withdrawals are called by msg.sender only
----
should allow only the respective contributor to access their tokenvesting withdrawal
should only allow the respective contributor to run withdrawal function for themselves
should only allow the respective contributor to run release function in the tokenvesting contract for themselves

*/


contract("SimpleLSTDistribution", function(accounts) {

  const _LSTTokenAddress = accounts[3];
  const _vestingBonusMultiplier = 2000000;
  const _vestingDuration = 31536000;


  const ownerAddress = accounts[0];
  //contributors
  const contributorPreTGENotVesting = accounts[1];
  const contributorPreTGEVesting = accounts[2];
  const contributorTGENotVesting = accounts[3];
  const contributorTGEVesting = accounts[4];
  const contributorPreTGEAndTGENotVesting = accounts[5];
  const contributorPreTGEAndTGEVesting = accounts[6];
  const notContributed = accounts[7];

  const contributorPreTGEVestingTGENotVesting = accounts[8];
  const contributorPreTGENotVestingTGEVesting = accounts[9];


  const preTGEAddresses = [
    contributorPreTGENotVesting,
    contributorPreTGEVesting,
    contributorPreTGEAndTGENotVesting,
    contributorPreTGEAndTGEVesting,
    contributorPreTGEVestingTGENotVesting,
    contributorPreTGENotVestingTGEVesting
  ];
  const preTGEWeiContributions = [
    5000000,
    5000000,
    5000000,
    5000000,
    5000000,
    5000000
  ];
  const preTGEVestingDecisions = [
    false,
    true,
    false,
    true,
    true,
    false
  ];

  const fundsWallet = accounts[4];
  const individualCapInWei = 10;
  const totalCapInWei = 15;

  // These variables are updated by the beforeEach hook for each test
  mostRecentStartTime = 0;
  mostRecentEndTime = 0;

  const TGEContributorVesting = [
    contributorTGEVesting,
    contributorPreTGEAndTGEVesting,
    contributorPreTGENotVestingTGEVesting
  ];

  const TGEContributorNotVesting = [
    contributorTGENotVesting,
    contributorPreTGEAndTGENotVesting,
    contributorPreTGEVestingTGENotVesting
  ];

  function blockTimeStamp()  {
    return web3.eth.getBlock('latest').timestamp;
  };

  beforeEach(async function() {
    const startTime = blockTimeStamp()+1;
    // Give all tests a 5 minute buffer to complete
    const endTime = startTime + 300;
    this.SimplePreTGEContract = await SimplePreTGE.new();
    await this.SimplePreTGEContract.bulkReserveTokensForAddresses(preTGEAddresses,preTGEWeiContributions,preTGEVestingDecisions);
    this.SimpleTGEContract = await SimpleTGE.new(fundsWallet, startTime, endTime, individualCapInWei, totalCapInWei);
    await this.SimpleTGEContract.whitelistAddresses(TGEContributorVesting);
    await this.SimpleTGEContract.whitelistAddresses(TGEContributorNotVesting);

    await increaseTime(duration.seconds(5));
    await advanceBlock();

    for (var i = 0; i < TGEContributorVesting.length; i++) {
      const address = TGEContributorVesting[i];
      await this.SimpleTGEContract.contributeAndVest({value: 1, from: address});
    }
    for (var i = 0; i < TGEContributorNotVesting.length; i++) {
      const address = TGEContributorNotVesting[i];
      await this.SimpleTGEContract.contributeWithoutVesting({value: 1, from: address});
    }

    const _useVestingStartTime = startTime + 60;
    this.contract = await SimpleLSTDistribution.new(this.SimplePreTGEContract.address, this.SimpleTGEContract.address,  _vestingBonusMultiplier, _vestingDuration, _useVestingStartTime);

    this.token = LendroidSupportToken.at(await this.contract.token());

  });


  it("should not deploy the contract if _SimplePreTGEAddress is not a valid address", async function() {
    let TGEStartTime = await this.SimpleTGEContract.publicTGEStartBlockTimeStamp();
    let _vestingStartTime = TGEStartTime + 60;
    this.contract = await SimpleLSTDistribution.new(0, this.SimpleTGEContract.address,  _vestingBonusMultiplier, _vestingDuration, _vestingStartTime).should.be.rejectedWith('revert');

  });

  it("should not deploy the contract if _SimpleTGEAddress is not a valid address", async function() {
    let TGEStartTime = await this.SimpleTGEContract.publicTGEStartBlockTimeStamp();
    let _vestingStartTime = TGEStartTime + 60;
    this.contract = await SimpleLSTDistribution.new(this.SimplePreTGEContract.address, 0,   _vestingBonusMultiplier, _vestingDuration, _vestingStartTime).should.be.rejectedWith('revert');
  });

  it("should not deploy the contract if _vestingBonusMultiplier is less than 1000000", async function() {
    let TGEStartTime = await this.SimpleTGEContract.publicTGEStartBlockTimeStamp();
    let _vestingStartTime = TGEStartTime + 60;
    this.contract = await SimpleLSTDistribution.new(this.SimplePreTGEContract.address, this.SimpleTGEContract.address,   100000, _vestingDuration, _vestingStartTime).should.be.rejectedWith('revert');
  });

  it("should not deploy the contract if _vestingBonusMultiplier is not more than 10000000", async function() {
    let TGEStartTime = await this.SimpleTGEContract.publicTGEStartBlockTimeStamp();
    let _vestingStartTime = TGEStartTime + 60;
    this.contract = await SimpleLSTDistribution.new(this.SimplePreTGEContract.address, this.SimpleTGEContract.address,   10000001, _vestingDuration, _vestingStartTime).should.be.rejectedWith('revert');
  });

  it("should not deploy the contract if _vestingDuration is 0", async function() {
    let TGEStartTime = await this.SimpleTGEContract.publicTGEStartBlockTimeStamp();
    let _vestingStartTime = TGEStartTime + 60;
    this.contract = await SimpleLSTDistribution.new(this.SimplePreTGEContract.address, this.SimpleTGEContract.address,   _vestingBonusMultiplier, 0, _vestingStartTime).should.be.rejectedWith('revert');
  });

  it("should not deploy the contract if _vestingStartTime is earlier than the current blocks timestamp", async function() {
    let TGEStartTime = await this.SimpleTGEContract.publicTGEStartBlockTimeStamp();
    let _vestingStartTime = TGEStartTime + 60;
    this.contract = await SimpleLSTDistribution.new(this.SimplePreTGEContract.address, this.SimpleTGEContract.address,   _vestingBonusMultiplier, _vestingDuration, 0).should.be.rejectedWith('revert');
  });




  it("should reject withdrawal request if TRS is still active", async function() {
    await this.SimplePreTGEContract.disableAllocationModificationsForEver({from:ownerAddress});
    assert.equal(await this.SimplePreTGEContract.allocationsLocked(), true ,'Allocations should be disabled in pre-TGE');
    let contribution = await this.SimplePreTGEContract.contributions(contributorPreTGENotVesting);
    assert.equal(contribution[0], false);
    assert.equal(contribution[1], 5000000);
    const TRSEndsAT = parseInt(await this.SimpleTGEContract.publicTGEEndBlockTimeStamp()) + parseInt(await this.SimpleTGEContract.TRSOffset());
    assert.isBelow(blockTimeStamp(),TRSEndsAT);
    await this.contract.withdraw({from:contributorPreTGENotVesting}).should.be.rejectedWith('revert');
  });


  it("should reject withdrawal request if pre-TGE allocationsLocked is not locked", async function() {
    assert.equal(await this.SimplePreTGEContract.allocationsLocked(), false ,'Allocations should still be allowed in pre-TGE');
    let contribution = await this.SimplePreTGEContract.contributions(contributorPreTGENotVesting);
    assert.equal(contribution[0], false);
    assert.equal(contribution[1], 5000000);
    await increaseTime(duration.days(6));
    await advanceBlock();
    const TRSEndsAT = parseInt(await this.SimpleTGEContract.publicTGEEndBlockTimeStamp()) + parseInt(await this.SimpleTGEContract.TRSOffset());
    assert.isAbove(blockTimeStamp(),TRSEndsAT);
    await this.contract.withdraw({from:contributorPreTGENotVesting}).should.be.rejectedWith('revert');
  });



  it("should reject withdrawal request if the requester has not contributed in the pre-TGE and TGE", async function() {

    await this.SimplePreTGEContract.disableAllocationModificationsForEver({from:ownerAddress});
    assert.equal(await this.SimplePreTGEContract.allocationsLocked(), true ,'Allocations should be disabled in pre-TGE');
    let contributionInPreTGE = await this.SimplePreTGEContract.contributions(notContributed);
    let contributionInTGE = await this.SimpleTGEContract.contributions(notContributed);
    assert.equal(contributionInPreTGE[0], false);
    assert.equal(contributionInPreTGE[1], 0);
    assert.equal(contributionInTGE[0], false);
    assert.equal(contributionInTGE[1], 0);
    await increaseTime(duration.days(6));
    await advanceBlock();
    const TRSEndsAT = parseInt(await this.SimpleTGEContract.publicTGEEndBlockTimeStamp()) + parseInt(await this.SimpleTGEContract.TRSOffset());
    assert.isAbove(blockTimeStamp(),TRSEndsAT);
    await this.contract.withdraw({from:notContributed}).should.be.rejectedWith('revert');

  });


  it("should mint exactly 100% of the allocated tokens to the contributors address if they have not vested", async function() {

    await this.SimplePreTGEContract.disableAllocationModificationsForEver({from:ownerAddress});
    assert.equal(await this.SimplePreTGEContract.allocationsLocked(), true ,'Allocations should be disabled in pre-TGE');
    let contributionInPreTGE = await this.SimplePreTGEContract.contributions(contributorPreTGENotVesting);
    let contributionInTGE = await this.SimpleTGEContract.contributions(contributorPreTGENotVesting);
    assert.equal(contributionInPreTGE[0], false);
    assert.equal(contributionInPreTGE[1], 5000000);
    assert.equal(contributionInTGE[0], false);
    assert.equal(contributionInTGE[1], 0);
    await increaseTime(duration.days(6));
    await advanceBlock();
    const TRSEndsAT = parseInt(await this.SimpleTGEContract.publicTGEEndBlockTimeStamp()) + parseInt(await this.SimpleTGEContract.TRSOffset());
    assert.isAbove(blockTimeStamp(),TRSEndsAT);
    await this.contract.withdraw({from:contributorPreTGENotVesting});
    let allocation = await this.contract.allocations(contributorPreTGENotVesting);
    assert.equal(allocation[0], false);
    assert.equal(allocation[1], 5000000);
    assert.equal(allocation[3], true,"should properly save the hasWithdrawn parameter for the contributor in allocations dict");
    const LSTRatePerWEI = await this.contract.LSTRatePerWEI();
    const tokenBalance = await this.token.balanceOf(contributorPreTGENotVesting);
    assert.equal(tokenBalance.toNumber(), LSTRatePerWEI.toNumber() * (allocation[1].toNumber()));


  });

  it("should reject withdrawal if user(not vesting) has already successfully run withdraw function once.", async function() {

    await this.SimplePreTGEContract.disableAllocationModificationsForEver({from:ownerAddress});
    assert.equal(await this.SimplePreTGEContract.allocationsLocked(), true ,'Allocations should be disabled in pre-TGE');
    let contributionInPreTGE = await this.SimplePreTGEContract.contributions(contributorPreTGENotVesting);
    let contributionInTGE = await this.SimpleTGEContract.contributions(contributorPreTGENotVesting);
    assert.equal(contributionInPreTGE[0], false);
    assert.equal(contributionInPreTGE[1], 5000000);
    assert.equal(contributionInTGE[0], false);
    assert.equal(contributionInTGE[1], 0);
    await increaseTime(duration.days(6));
    await advanceBlock();
    const TRSEndsAT = parseInt(await this.SimpleTGEContract.publicTGEEndBlockTimeStamp()) + parseInt(await this.SimpleTGEContract.TRSOffset());
    assert.isAbove(blockTimeStamp(),TRSEndsAT);
    await this.contract.withdraw({from:contributorPreTGENotVesting});
    let allocation = await this.contract.allocations(contributorPreTGENotVesting);
    assert.equal(allocation[0], false);
    assert.equal(allocation[1], 5000000);
    assert.equal(allocation[3], true);
    const LSTRatePerWEI = await this.contract.LSTRatePerWEI();
    const tokenBalance = await this.token.balanceOf(contributorPreTGENotVesting);
    assert.equal(tokenBalance.toNumber(), LSTRatePerWEI.toNumber() * (allocation[1].toNumber()));

    await this.contract.withdraw({from:contributorPreTGENotVesting}).should.be.rejectedWith('revert');;

  });

  it("should calculate _totalWeiContribution by adding contributions by an address to both pre-TGE and TGE contracts", async function() {

    await this.SimplePreTGEContract.disableAllocationModificationsForEver({from:ownerAddress});
    assert.equal(await this.SimplePreTGEContract.allocationsLocked(), true ,'Allocations should be disabled in pre-TGE');
    let contributionInPreTGE = await this.SimplePreTGEContract.contributions(contributorPreTGEAndTGENotVesting);
    let contributionInTGE = await this.SimpleTGEContract.contributions(contributorPreTGEAndTGENotVesting);
    assert.equal(contributionInPreTGE[0], false);
    assert.equal(contributionInPreTGE[1], 5000000);
    assert.equal(contributionInTGE[0], false);
    assert.equal(contributionInTGE[1], 1);
    await increaseTime(duration.days(6));
    await advanceBlock();
    const TRSEndsAT = parseInt(await this.SimpleTGEContract.publicTGEEndBlockTimeStamp()) + parseInt(await this.SimpleTGEContract.TRSOffset());
    assert.isAbove(blockTimeStamp(),TRSEndsAT);
    await this.contract.withdraw({from:contributorPreTGEAndTGENotVesting});
    let allocation = await this.contract.allocations(contributorPreTGEAndTGENotVesting);
    assert.equal(allocation[0], false);
    assert.equal(allocation[1], 5000001);
    assert.equal(allocation[3], true);
    const LSTRatePerWEI = await this.contract.LSTRatePerWEI();
    const tokenBalance = await this.token.balanceOf(contributorPreTGEAndTGENotVesting);
    assert.equal(tokenBalance.toNumber(), LSTRatePerWEI.toNumber() * (allocation[1].toNumber()));


  });


  it("should mint exactly 10% (address) / 90% (vesting contract) of the allocated tokens to the contributor if they have vested", async function() {

    await this.SimplePreTGEContract.disableAllocationModificationsForEver({from:ownerAddress});
    assert.equal(await this.SimplePreTGEContract.allocationsLocked(), true ,'Allocations should be disabled in pre-TGE');
    let contributionInPreTGE = await this.SimplePreTGEContract.contributions(contributorPreTGEVesting);
    let contributionInTGE = await this.SimpleTGEContract.contributions(contributorPreTGEVesting);
    assert.equal(contributionInPreTGE[0], true);
    assert.equal(contributionInPreTGE[1], 5000000);
    assert.equal(contributionInTGE[0], false);
    assert.equal(contributionInTGE[1], 0);
    await increaseTime(duration.days(6));
    await advanceBlock();
    let TRSEndsAT = parseInt(await this.SimpleTGEContract.publicTGEEndBlockTimeStamp()) + parseInt(await this.SimpleTGEContract.TRSOffset());
    assert.isAbove(blockTimeStamp(),TRSEndsAT);
    let LSTRatePerWEI = await this.contract.LSTRatePerWEI();
    let vestingBonusMultiplierPrecision = await this.contract.vestingBonusMultiplierPrecision();
    await this.contract.withdraw({from:contributorPreTGEVesting});
    let allocation = await this.contract.allocations(contributorPreTGEVesting);
    assert.equal(allocation[0], true);
    assert.equal(allocation[1], 5000000);
    assert.equal(allocation[2], allocation[1] * LSTRatePerWEI * _vestingBonusMultiplier / vestingBonusMultiplierPrecision);
    assert.equal(allocation[3], true);
    let tokenBalance = await this.token.balanceOf(contributorPreTGEVesting);
    let contributorVestingContract = await this.contract.vesting(contributorPreTGEVesting);
    let vestingcontractTokenBalance = await this.token.balanceOf(contributorVestingContract);

    assert.equal(tokenBalance.toNumber(), (allocation[1] * LSTRatePerWEI * _vestingBonusMultiplier * 0.1 / vestingBonusMultiplierPrecision) ,"should mint exactly 10% of the allocated tokens to the contributors address if they have vested" );
    assert.equal(vestingcontractTokenBalance.toNumber(), (allocation[1] * LSTRatePerWEI * _vestingBonusMultiplier * 0.9 / vestingBonusMultiplierPrecision) ,"should mint exactly 90% of the allocated tokens to the contributors tokenvesting address if they have vested" );

    // trying double withdrawal should fail
    await this.contract.withdraw({from:contributorPreTGEVesting}).should.be.rejectedWith('revert');

  });


    it("should compute vesting decision if vesting decision is true in either of the pre-TGE and TGE contracts", async function() {

      await this.SimplePreTGEContract.disableAllocationModificationsForEver({from:ownerAddress});
      assert.equal(await this.SimplePreTGEContract.allocationsLocked(), true ,'Allocations should be disabled in pre-TGE');

      // vested on Pre-TGE not in TGE
      let contributionInPreTGE = await this.SimplePreTGEContract.contributions(contributorPreTGEVestingTGENotVesting);
      let contributionInTGE = await this.SimpleTGEContract.contributions(contributorPreTGEVestingTGENotVesting);
      assert.equal(contributionInPreTGE[0], true);
      assert.equal(contributionInPreTGE[1], 5000000);
      assert.equal(contributionInTGE[0], false);
      assert.equal(contributionInTGE[1], 1);
      await increaseTime(duration.days(6));
      await advanceBlock();
      let TRSEndsAT = parseInt(await this.SimpleTGEContract.publicTGEEndBlockTimeStamp()) + parseInt(await this.SimpleTGEContract.TRSOffset());
      let LSTRatePerWEI = await this.contract.LSTRatePerWEI();
      let vestingBonusMultiplierPrecision = await this.contract.vestingBonusMultiplierPrecision();

      assert.isAbove(blockTimeStamp(),TRSEndsAT);
      await this.contract.withdraw({from:contributorPreTGEVestingTGENotVesting});
      let allocation = await this.contract.allocations(contributorPreTGEVestingTGENotVesting);


      assert.equal(allocation[0], true,"should properly save the vesting decision parameter for the contributor allocations dict");
      assert.equal(allocation[1], 5000001,"should properly save the weiContributed parameter for the contributor allocations dict");
      assert.equal(allocation[2], allocation[1] * LSTRatePerWEI * _vestingBonusMultiplier / vestingBonusMultiplierPrecision);
      assert.equal(allocation[3], true);
      let tokenBalance = await this.token.balanceOf(contributorPreTGEVestingTGENotVesting);
      let contributorVestingContract = await this.contract.vesting(contributorPreTGEVestingTGENotVesting);
      let vestingcontractTokenBalance = await this.token.balanceOf(contributorVestingContract);

      assert.equal(tokenBalance.toNumber(), (allocation[1] * LSTRatePerWEI * _vestingBonusMultiplier * 0.1 / vestingBonusMultiplierPrecision) ,"should mint exactly 10% of the allocated tokens to the contributors address if they have vested" );
      assert.equal(vestingcontractTokenBalance.toNumber(), (allocation[1] * LSTRatePerWEI * _vestingBonusMultiplier * 0.9 / vestingBonusMultiplierPrecision) ,"should mint exactly 90% of the allocated tokens to the contributors tokenvesting address if they have vested" );

      // not vested on Pre-TGE vested in TGE
      contributionInPreTGE = await this.SimplePreTGEContract.contributions(contributorPreTGENotVestingTGEVesting);
      contributionInTGE = await this.SimpleTGEContract.contributions(contributorPreTGENotVestingTGEVesting);
      assert.equal(contributionInPreTGE[0], false);
      assert.equal(contributionInPreTGE[1], 5000000);
      assert.equal(contributionInTGE[0], true);
      assert.equal(contributionInTGE[1], 1);
      await increaseTime(duration.days(6));
      await advanceBlock();
      assert.isAbove(blockTimeStamp(),TRSEndsAT);
      await this.contract.withdraw({from:contributorPreTGENotVestingTGEVesting});
      allocation = await this.contract.allocations(contributorPreTGENotVestingTGEVesting);

      assert.equal(allocation[0], true,"should properly save the vesting decision parameter for the contributor allocations dict");
      assert.equal(allocation[1], 5000001,"should properly save the weiContributed parameter for the contributor allocations dict");
      assert.equal(allocation[2], allocation[1] * LSTRatePerWEI * _vestingBonusMultiplier / vestingBonusMultiplierPrecision);
      assert.equal(allocation[3], true);
      tokenBalance = await this.token.balanceOf(contributorPreTGENotVestingTGEVesting);
      contributorVestingContract = await this.contract.vesting(contributorPreTGENotVestingTGEVesting);
      vestingcontractTokenBalance = await this.token.balanceOf(contributorVestingContract);

      assert.equal(tokenBalance.toNumber(), (allocation[1] * LSTRatePerWEI * _vestingBonusMultiplier * 0.1 / vestingBonusMultiplierPrecision) ,"should mint exactly 10% of the allocated tokens to the contributors address if they have vested" );
      assert.equal(vestingcontractTokenBalance.toNumber(), (allocation[1] * LSTRatePerWEI * _vestingBonusMultiplier * 0.9 / vestingBonusMultiplierPrecision) ,"should mint exactly 90% of the allocated tokens to the contributors tokenvesting address if they have vested" );



    });


    it("should allow withdrawal from the tokenvesting contract according to the release schedule", async function() {

      await this.SimplePreTGEContract.disableAllocationModificationsForEver({from:ownerAddress});
      assert.equal(await this.SimplePreTGEContract.allocationsLocked(), true ,'Allocations should be disabled in pre-TGE');
      let contributionInPreTGE = await this.SimplePreTGEContract.contributions(contributorPreTGEVesting);
      let contributionInTGE = await this.SimpleTGEContract.contributions(contributorPreTGEVesting);
      assert.equal(contributionInPreTGE[0], true);
      assert.equal(contributionInPreTGE[1], 5000000);
      assert.equal(contributionInTGE[0], false);
      assert.equal(contributionInTGE[1], 0);
      await increaseTime(duration.days(6));
      await advanceBlock();
      let TRSEndsAT = parseInt(await this.SimpleTGEContract.publicTGEEndBlockTimeStamp()) + parseInt(await this.SimpleTGEContract.TRSOffset());
      assert.isAbove(blockTimeStamp(),TRSEndsAT);
      let LSTRatePerWEI = await this.contract.LSTRatePerWEI();
      let vestingBonusMultiplierPrecision = await this.contract.vestingBonusMultiplierPrecision();
      await this.contract.withdraw({from:contributorPreTGEVesting});
      let allocation = await this.contract.allocations(contributorPreTGEVesting);
      assert.equal(allocation[0], true);
      assert.equal(allocation[1], 5000000);
      assert.equal(allocation[2], allocation[1] * LSTRatePerWEI * _vestingBonusMultiplier / vestingBonusMultiplierPrecision);
      assert.equal(allocation[3], true);
      let tokenBalance = await this.token.balanceOf(contributorPreTGEVesting);
      let contributorVestingContract = await this.contract.vesting(contributorPreTGEVesting);
      let vestingcontractTokenBalance = await this.token.balanceOf(contributorVestingContract);

      assert.equal(tokenBalance.toNumber(), (allocation[1] * LSTRatePerWEI * _vestingBonusMultiplier * 0.1 / vestingBonusMultiplierPrecision) ,"should mint exactly 10% of the allocated tokens to the contributors address if they have vested" );
      assert.equal(vestingcontractTokenBalance.toNumber(), (allocation[1] * LSTRatePerWEI * _vestingBonusMultiplier * 0.9 / vestingBonusMultiplierPrecision) ,"should mint exactly 90% of the allocated tokens to the contributors tokenvesting address if they have vested" );

      // trying double withdrawal should fail
      await this.contract.withdraw({from:contributorPreTGEVesting}).should.be.rejectedWith('revert');

      await increaseTime(duration.seconds(_vestingDuration+100));
      await advanceBlock();

      await this.contract.releaseVestedTokens({from:contributorPreTGEVesting});


      tokenBalance = await this.token.balanceOf(contributorPreTGEVesting);
      vestingcontractTokenBalance = await this.token.balanceOf(contributorVestingContract);

      let contributerTokenBalanceShouldBe = (allocation[1] * LSTRatePerWEI * _vestingBonusMultiplier * (1) / vestingBonusMultiplierPrecision);
      let contributerVestedBalanceShouldBe = (allocation[1] * LSTRatePerWEI * _vestingBonusMultiplier * (0) / vestingBonusMultiplierPrecision);

      assert.equal(tokenBalance.toNumber(), contributerTokenBalanceShouldBe,"12 months in contributor runs release")
      assert.equal(vestingcontractTokenBalance.toNumber(), contributerVestedBalanceShouldBe,"12 months in there should be this much left in the vesting contract")



    });





});
