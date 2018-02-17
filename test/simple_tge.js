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

contract("SimpleTGE", function(accounts) {
  const fundsWallet = accounts[4];
  const individualCapInWei = 10;
  const totalCapInWei = 15;

  // These variables are updated by the beforeEach hook for each test
  mostRecentStartTime = 0;
  mostRecentEndTime = 0;

  const validUnwhitelistedAddresses = [
    accounts[0]
  ];

  // TODO how many accounts do we get access to via accounts?
  const validWhiteListAddresses = [
    accounts[1],
    accounts[2]
  ];

  const validBlackListAddresses = [
    accounts[3]
  ];

  function blockTimeStamp()  {
    return web3.eth.getBlock('latest').timestamp;
  };

  beforeEach(async function() {
    const startTime = blockTimeStamp()+1;
    // Give all tests a 5 minute buffer to complete
    const endTime = startTime + 300;

    mostRecentStartTime = startTime;
    mostRecentEndTime = endTime;
    this.contract = await SimpleTGE.new(fundsWallet, startTime, endTime, individualCapInWei, totalCapInWei);
    await this.contract.whitelistAddresses(validWhiteListAddresses);
    // Make sure we whitelist the blacklist addresses before blacklisting them to make sure that
    // blacklisting actually works and the transactions aren't just failing because the addresses
    // were never whitelisted in the first place.
    await this.contract.whitelistAddresses(validBlackListAddresses);
    await this.contract.blacklistAddresses(validBlackListAddresses);

    // Make sure that at least 5 seconds have elapsed AND a new block has been mined
    // before continuiing into test code to make sure we're in a block that is definitely
    // past the startTime.
    await increaseTime(duration.seconds(5));
    await advanceBlock();
  });

    it("should not deploy the contract if the start time is less than the current block's timestamp", async function() {
      const startTime = blockTimeStamp()-duration.hours(1);
      const endTime = startTime + 300;
      this.contract = await SimpleTGE.new(fundsWallet, startTime, endTime, individualCapInWei, totalCapInWei).should.be.rejectedWith('invalid opcode');
    });

    it("should not deploy the contract if the end time is less than or equal to the start time", async function() {
      const startTime = blockTimeStamp()+duration.hours(1);
      let endTime = startTime;
      this.contract = await SimpleTGE.new(fundsWallet, startTime, endTime, individualCapInWei, totalCapInWei).should.be.rejectedWith('invalid opcode');

      endTime = startTime-10000;
      this.contract = await SimpleTGE.new(fundsWallet, startTime, endTime, individualCapInWei, totalCapInWei).should.be.rejectedWith('invalid opcode');
    });

    it("should not deploy the contract if the fundsWallet is not a valid address", async function() {
      const startTime = blockTimeStamp()+duration.hours(1);
      const endTime = startTime + 300;
      this.contract = await SimpleTGE.new(0, startTime, endTime, individualCapInWei, totalCapInWei).should.be.rejectedWith('invalid opcode');
    });

    it("should not deploy the contract if the individualCapInWei is not greater than zero", async function() {
      const startTime = blockTimeStamp()+duration.hours(1);
      const endTime = startTime + 300;
      this.contract = await SimpleTGE.new(fundsWallet, startTime, endTime, 0, totalCapInWei).should.be.rejectedWith('invalid opcode');
    });

    it("should not deploy the contract if the totalCapInWei is not greater than zero", async function() {
      const startTime = blockTimeStamp()+duration.hours(1);
      const endTime = startTime + 300;
      this.contract = await SimpleTGE.new(fundsWallet, startTime, endTime, individualCapInWei, 0).should.be.rejectedWith('invalid opcode');
    });

  it("should have an owner", async function() {
    assert.equal(await this.contract.owner(), accounts[0]);
  });

  // TODO would it be easier to reset the balances for each account after each it?
  // We may already be doing this having trouble actually running the tests
  it("should create the contract with the correct properties", async function() {
    assert.equal(await this.contract.fundsWallet(), fundsWallet);
    assert.equal(await this.contract.publicTGEStartBlockTimeStamp(), mostRecentStartTime);
    // assert.isAtLeast(await this.contract.publicTGEStartBlockTimeStamp(), blockTimeStamp());
    assert.equal(await this.contract.publicTGEEndBlockTimeStamp(), mostRecentEndTime);
    // assert.isAtLeast(await this.contract.publicTGEEndBlockTimeStamp(), await this.contract.publicTGEStartBlockTimeStamp());
    assert.equal(await this.contract.individualCapInWei(), individualCapInWei);
    assert.isAbove(await this.contract.individualCapInWei(), 0);
    assert.equal(await this.contract.totalCapInWei(), totalCapInWei);
    assert.isAbove(await this.contract.totalCapInWei(), 0);
    assert.equal(await this.contract.owner(), accounts[0]);
  });

  it("should allow contributing with vesting and honor whitelist/blacklist", async function() {
    const initialFundsWalletBalance = await web3.eth.getBalance(await this.contract.fundsWallet());
  
    for (var i = 0; i < validWhiteListAddresses.length; i++) {
      const address = validWhiteListAddresses[i];
      await this.contract.contributeAndVest({value: 0, from: address}).should.be.rejectedWith('invalid opcode');
      await this.contract.contributeAndVest({value: 1, from: address});
      assert.equal(await this.contract.contributors(i), address);

      const contribution = await this.contract.contributions(address);
      assert.equal(contribution[0], true);
      assert.equal(contribution[1], 1);

      assert.equal(await this.contract.weiRaised(), i+1);
      
      const newFundsWalletBalance = await web3.eth.getBalance(await this.contract.fundsWallet());
      const expectedNewFundsWalletBalance = initialFundsWalletBalance.plus(i+1);
      assert.equal(newFundsWalletBalance.String, expectedNewFundsWalletBalance.String);
    };

    for (var i = 0; i < validUnwhitelistedAddresses.length; i++) {
      const address = validUnwhitelistedAddresses[i];
      await this.contract.contributeAndVest({value: 1, from: address}).should.be.rejectedWith('invalid opcode');
      assert.equal(await this.contract.contributors(i), validWhiteListAddresses[i]);

      const contribution = await this.contract.contributions(address);
      assert.equal(contribution[0], false);
      assert.equal(contribution[1], 0);

      assert.equal(await this.contract.weiRaised(), validWhiteListAddresses.length);

      const newFundsWalletBalance = await web3.eth.getBalance(await this.contract.fundsWallet());
      const expectedNewFundsWalletBalance = initialFundsWalletBalance.plus(validWhiteListAddresses.length+1);
      assert.equal(newFundsWalletBalance.String, expectedNewFundsWalletBalance.String);
    };

    for (var i = 0; i < validBlackListAddresses.length; i++) {
      const address = validBlackListAddresses[i];
      await this.contract.contributeAndVest({value: 1, from: address}).should.be.rejectedWith('invalid opcode');
      assert.equal(await this.contract.contributors(i), validWhiteListAddresses[i]);

      const contribution = await this.contract.contributions(address);
      assert.equal(contribution[0], false);
      assert.equal(contribution[1], 0);

      assert.equal(await this.contract.weiRaised(), validWhiteListAddresses.length);

      const newFundsWalletBalance = await web3.eth.getBalance(await this.contract.fundsWallet());
      const expectedNewFundsWalletBalance = initialFundsWalletBalance.plus(validWhiteListAddresses.length+1);
      assert.equal(newFundsWalletBalance.String, expectedNewFundsWalletBalance.String);
    };
  });

  it("should allow contributing without vesting and honor whitelist/blacklist", async function() {
    const initialFundsWalletBalance = await web3.eth.getBalance(await this.contract.fundsWallet());
  
    for (var i = 0; i < validWhiteListAddresses.length; i++) {
      const address = validWhiteListAddresses[i];
      await this.contract.contributeAndVest({value: 0, from: address}).should.be.rejectedWith('invalid opcode');
      await this.contract.contributeWithoutVesting({value: 1, from: address});
      assert.equal(await this.contract.contributors(i), address);

      const contribution = await this.contract.contributions(address);
      assert.equal(contribution[0], false);
      assert.equal(contribution[1], 1);

      assert.equal(await this.contract.weiRaised(), i+1);
      
      const newFundsWalletBalance = await web3.eth.getBalance(await this.contract.fundsWallet());
      const expectedNewFundsWalletBalance = initialFundsWalletBalance.plus(i+1);
      assert.equal(newFundsWalletBalance.String, expectedNewFundsWalletBalance.String);
    };

    for (var i = 0; i < validUnwhitelistedAddresses.length; i++) {
      const address = validUnwhitelistedAddresses[i];
      await this.contract.contributeWithoutVesting({value: 1, from: address}).should.be.rejectedWith('invalid opcode');
      assert.equal(await this.contract.contributors(i), validWhiteListAddresses[i]);

      const contribution = await this.contract.contributions(address);
      assert.equal(contribution[0], false);
      assert.equal(contribution[1], 0);

      assert.equal(await this.contract.weiRaised(), validWhiteListAddresses.length);

      const newFundsWalletBalance = await web3.eth.getBalance(await this.contract.fundsWallet());
      const expectedNewFundsWalletBalance = initialFundsWalletBalance.plus(validWhiteListAddresses.length+1);
      assert.equal(newFundsWalletBalance.String, expectedNewFundsWalletBalance.String);
    };

    for (var i = 0; i < validBlackListAddresses.length; i++) {
      const address = validBlackListAddresses[i];
      await this.contract.contributeWithoutVesting({value: 1, from: address}).should.be.rejectedWith('invalid opcode');
      assert.equal(await this.contract.contributors(i), validWhiteListAddresses[i]);

      const contribution = await this.contract.contributions(address);
      assert.equal(contribution[0], false);
      assert.equal(contribution[1], 0);

      assert.equal(await this.contract.weiRaised(), validWhiteListAddresses.length);

      const newFundsWalletBalance = await web3.eth.getBalance(await this.contract.fundsWallet());
      const expectedNewFundsWalletBalance = initialFundsWalletBalance.plus(validWhiteListAddresses.length+1);
      assert.equal(newFundsWalletBalance.String, expectedNewFundsWalletBalance.String);
    };
  });

  it("should reject contributions before and after TGE has started/end", async function() {
    // Need to manually setup the contracts for this test case
    const startTime = blockTimeStamp()+duration.days(100);
    const endTime = startTime + 300;
    this.contract = await SimpleTGE.new(fundsWallet, startTime, endTime, individualCapInWei, totalCapInWei);
    await this.contract.whitelistAddresses(validWhiteListAddresses);

    // Before TGE, should be rejected
    await this.contract.contributeAndVest({value: 1, from: validWhiteListAddresses[0]}).should.be.rejectedWith('invalid opcode');
    await increaseTime(duration.days(100));
    await advanceBlock();

    // During TGE so should be accepted
    await this.contract.contributeAndVest({value: 1, from: validWhiteListAddresses[0]})

    // After TGE, should be rejected
    await increaseTime(301);
    await advanceBlock();
    await this.contract.contributeAndVest({value: 1, from: validWhiteListAddresses[0]}).should.be.rejectedWith('invalid opcode');
  });

  it("should handle duplicate contributions correctly", async function() {
    const contributor = validWhiteListAddresses[0];

    await this.contract.contributeAndVest({value: 1, from: contributor});
    let contributors0 = await this.contract.contributors(0);
    assert.equal(contributors0, contributor);
    await this.contract.contributors(1).should.be.rejectedWith('invalid opcode');

    await this.contract.contributeAndVest({value: 1, from: contributor});
    contributors0 = await this.contract.contributors(0);
    assert.equal(contributors0, contributor);
    // Make sure the contributor only appears in the contributors array once    
    await this.contract.contributors(1).should.be.rejectedWith('invalid opcode');

    // Make sure the contributors balance is properly updated
    let contribution = await this.contract.contributions(contributor);
    // Should be marked for vesting
    assert.equal(contribution[0], true);
    // 1 wei each contribution * 2 contribitions = 2
    assert.equal(contribution[1], 2);
  });

  it("should honor the individual cap", async function() {
    const contributor = validWhiteListAddresses[0];
    
    await this.contract.contributeAndVest({value: individualCapInWei-1, from: contributor});
    let contribution = await this.contract.contributions(contributor);
    assert.equal(contribution[0], true);
    assert.equal(contribution[1], individualCapInWei-1);
    assert.equal(await this.contract.weiRaised(), individualCapInWei-1);
    
    await this.contract.contributeAndVest({value: 1, from: contributor});
    contribution = await this.contract.contributions(contributor);
    assert.equal(contribution[0], true);
    assert.equal(contribution[1], individualCapInWei);
    assert.equal(await this.contract.weiRaised(), individualCapInWei);

    await this.contract.contributeAndVest({value: 1, from: contributor}).should.be.rejectedWith('invalid opcode');
    contribution = await this.contract.contributions(contributor);
    assert.equal(contribution[0], true);
    assert.equal(contribution[1], individualCapInWei);
    assert.equal(await this.contract.weiRaised(), individualCapInWei);
  });

  it("should not allow an individual who has never contributed to exceed the individualCapInWei", async function () {
    const contributor = validWhiteListAddresses[0];
    
    await this.contract.contributeAndVest({value: individualCapInWei+1, from: contributor}).should.be.rejectedWith('invalid opcode');
    await this.contract.contributors(0).should.be.rejectedWith('invalid opcode');
    contribution = await this.contract.contributions(contributor);
    assert.equal(contribution[0], false);
    assert.equal(contribution[1], 0);
    assert.equal(await this.contract.weiRaised(), 0);
  });

  it("should not allow any contribution to be made if the totalCapInWei has been exceeded even if individualCapInWei amount is valid", async function () {
    // Make sure the test is valid using the defined contstants
    assert.equal(individualCapInWei * 2 > totalCapInWei, true);
    await this.contract.contributeAndVest({value: individualCapInWei, from: validWhiteListAddresses[0]});
    let contribution = await this.contract.contributions(validWhiteListAddresses[0]);
    assert.equal(contribution[0], true);
    assert.equal(contribution[1], individualCapInWei);
    assert.equal(await this.contract.weiRaised(), individualCapInWei);

    await this.contract.contributeAndVest({value: individualCapInWei, from: validWhiteListAddresses[1]}).should.be.rejectedWith('invalid opcode');
    contribution = await this.contract.contributions(validWhiteListAddresses[1]);
    assert.equal(contribution[0], false);
    assert.equal(contribution[1], 0);
    assert.equal(await this.contract.weiRaised(), individualCapInWei);
  });

  it("should allow the owner but not a non-owner to update the individualCapInWei", async function() {
    // Verif constants are valid for this test case
    assert.equal(accounts[0] != accounts[3], true);
    assert.equal(await this.contract.owner(), accounts[0]);

    await this.contract.changeIndividualCapInWei(totalCapInWei-1, {from: accounts[0]});
    assert.equal(await this.contract.individualCapInWei(), totalCapInWei-1);

    await this.contract.changeIndividualCapInWei(totalCapInWei-2, {from: accounts[3]}).should.be.rejectedWith('invalid opcode');
    assert.equal(await this.contract.individualCapInWei(), totalCapInWei-1);
  });

  it("should not allow the individualCapInWei to exceed the totalCapInWei", async function() {
    assert.equal(await this.contract.owner(), accounts[0]);
  
    await this.contract.changeIndividualCapInWei(totalCapInWei+1, {from: accounts[0]}).should.be.rejectedWith('invalid opcode');
    assert.equal(await this.contract.individualCapInWei(), individualCapInWei);
  });

  it("should call contributeWithoutVesting when ether is sent to contract without data", async function() {
    let contributor = validWhiteListAddresses[0];

    await web3.eth.sendTransaction({from: contributor, to: this.contract.address, value: web3.toWei(1, 'wei'), gas: 4000000});
    let contribution = await this.contract.contributions(contributor);
    assert.equal(contribution[0], false);
    assert.equal(contribution[1], 1);

    assert.equal(await this.contract.contributors(0), contributor);
    this.contract.contributors(1).should.be.rejectedWith('invalid opcode');

    assert.equal(await this.contract.weiRaised(), 1);
  });

  it("should allow reclaimEther to be called by the owner, but not by anybody else", async function() {
    // Verif constants are valid for this test case
    assert.equal(accounts[0] != accounts[3], true);
    assert.equal(await this.contract.owner(), accounts[0]);

    let existingContractBalance = await web3.eth.getBalance(this.contract.address);
    let existingOwnerBalance = await web3.eth.getBalance(accounts[2]);

    await this.contract.reclaimEther(accounts[2], {from: accounts[0]});
    assert.equal(await web3.eth.getBalance(accounts[2]).String, existingOwnerBalance.add(existingContractBalance).String);
    assert.equal(await web3.eth.getBalance(this.contract.address), 0);

    await this.contract.reclaimEther(accounts[3], {from: accounts[3]}).should.be.rejectedWith('invalid opcode');
  });

  it("should allow contributors to change their initial vesting decision", async function() {
    let contributor = validWhiteListAddresses[0];
    await this.contract.contributeAndVest({value: 1, from: contributor});
    let contribution = await this.contract.contributions(contributor);
    assert.equal(contribution[0], true);
    assert.equal(contribution[1], 1);

    await this.contract.vest(false, {from: contributor});
    contribution = await this.contract.contributions(contributor);
    assert.equal(contribution[0], false);
    assert.equal(contribution[1], 1);

    // It shouldn't succeed if its already at the value they're trying to set it to
    await this.contract.vest(false, {from: contributor}).should.be.rejectedWith('invalid opcode');
  });

  it("should not allow contributors to change their initial vesting decision if they're not whitelisted", async function() {
    let contributor = validUnwhitelistedAddresses[0];
    await this.contract.contributeAndVest({value: 1, from: contributor}).should.be.rejectedWith('invalid opcode');
  });

  it("should not allow contributors to change their initial vesting decision if they're blacklisted", async function() {
    let contributor = validBlackListAddresses[0];
    await this.contract.contributeAndVest({value: 1, from: contributor}).should.be.rejectedWith('invalid opcode');
  });

  it("should not allow contributors to change their vesting decision if they have not contributed yet", async function() {
    let contributor = validWhiteListAddresses[0];
    // Verify they haven't contributed yet
    let contribution = await this.contract.contributions(contributor);
    assert.equal(contribution[0], false);
    assert.equal(contribution[1], 0);

    await this.contract.vest(false, {from: contributor}).should.be.rejectedWith('invalid opcode');
    await this.contract.vest(true, {from: contributor}).should.be.rejectedWith('invalid opcode');
  });

  it("should not allow contributors to change their vesting decision before the TGE has started", async function() {
    // Have to manually setup the contract for this test case
    const startTime = blockTimeStamp()+duration.days(100);
    const endTime = startTime + 300;
    this.contract = await SimpleTGE.new(fundsWallet, startTime, endTime, individualCapInWei, totalCapInWei);
    await this.contract.whitelistAddresses(validWhiteListAddresses);


    let contributor = validWhiteListAddresses[0];
    await this.contract.contributeAndVest({value: 1, from: contributor}).should.be.rejectedWith('invalid opcode');
  });

  it("should not allow contributors to change their initial vesting decision once TRS has started", async function() {
    let contributor = validWhiteListAddresses[0];
    await this.contract.contributeAndVest({value: 1, from: contributor});
    let contribution = await this.contract.contributions(contributor);
    assert.equal(contribution[0], true);
    assert.equal(contribution[1], 1);

    // Make sure they can contribute up to an hour before TRS starting
    const tgeDuration = mostRecentEndTime-mostRecentStartTime;
    await increaseTime(tgeDuration+duration.hours(24*5)-duration.hours(1));
    await advanceBlock();
    await this.contract.vest(false, {from: contributor});
    contribution = await this.contract.contributions(contributor);
    assert.equal(contribution[0], false);
    assert.equal(contribution[1], 1);

    // Make sure they cannot contribute after TRS has started (one additional hour since we were already one hour before)
    await increaseTime(duration.hours(1)+duration.seconds(1));
    await advanceBlock();
    await this.contract.vest(true, {from: contributor}).should.be.rejectedWith('invalid opcode');
    contribution = await this.contract.contributions(contributor);
    assert.equal(contribution[0], false);
    assert.equal(contribution[1], 1);
  });
});
