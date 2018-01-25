pragma solidity ^0.4.17;

import "./base.sol";


contract LendroidSupportToken is MintableToken, PausableToken {

  string public constant name = "Lendroid Support Token";
  string public constant symbol = "LST";
  uint256 public constant decimals = 18;

  uint256 public constant MAX_SUPPLY = 12000000000 * (10 ** uint256(decimals));// 12 billion tokens, 18 decimal places

  /**
   * @dev Constructor that pauses tradability of tokens.
   */
  function LendroidSupportToken() public {
    paused = true;
    totalSupply = MAX_SUPPLY;
  }
}


contract ContributorWhitelist is HasNoEther, Destructible {
  mapping (address => bool) public authorized;
  mapping (address => bool) public whitelist;

  modifier auth() {
    require((msg.sender == owner) || (authorized[msg.sender]));
    _;
  }

  function setAuthority(address _address) public onlyOwner returns(bool) {
    authorized[_address] = true;
    return true;
  }

  function removeAuthority(address _address) public onlyOwner returns(bool) {
    authorized[_address] = false;
    return true;
  }

  function whitelistAddress(address _address) public onlyOwner returns(bool) {
    whitelist[_address] = true;
    return true;
  }

  function blacklistAddress(address _address) public onlyOwner returns(bool) {
    whitelist[_address] = false;
    return true;
  }

  function isWhitelisted(address _address) public auth view returns(bool) {
    return whitelist[_address];
  }

}


/**
 * @title BaseTGEContract
 * @dev BaseTGEContract is a base contract for managing a token crowdsale.
 * contributors can make token purchases and (if the canMint option is true)
 * the conact will assign them tokens based on a token per ETH rate.
 * Funds collected are forwarded to a coldStorageWallet as they arrive.
 */
contract BaseTGEContract is Pausable, Destructible {
  using SafeMath for uint256;

  // start and end timestamps (both inclusive) when sale is open
  uint256 public publicTGEStartTime;
  uint256 public publicTGEEndTime;

  // The token being sold
  LendroidSupportToken public token;

  // Contributor whitelist
  ContributorWhitelist public whitelist;

  // address where funds are collected
  address public fundsWallet;

  // how many token units a buyer gets per ether
  uint256 public rate;

  // amount of raised money in wei
  uint256 public weiRaised;

  // sale cap in wei
  uint256 public totalCap;

  // individual cap in wei
  uint256 public individualCap;

  struct Contribution {
    uint256 timestamp;
    uint256 WEIContributed;
    uint256 LST_WEI_rate;
    bool isPrivateTGE;
  }
  mapping (address => Contribution[]) private contributions;

  struct ContributionRemoved {
    uint256 timestamp;
    uint256 WEIRemoved;
    uint256 LST_WEI_rate;
    bool isPrivateTGE;
  }
  mapping (address => ContributionRemoved[]) private contributionsRemoved;

  mapping (address => uint256) public weiContributed;

  modifier whilePublicTGEIsActive() {
    require(now <= publicTGEEndTime);
    _;
  }

  /**
   * @dev Function to set ContributorWhitelist address.
   * @return True if the operation was successful.
   */
  function setWhitelist(address _address) onlyOwner external returns (bool) {
    whitelist = ContributorWhitelist(_address);
    return true;
  }

  /**
   * @dev Function to set rate.
   * @return True if the operation was successful.
   */
  function setRate(uint256 _rate) onlyOwner external returns (bool) {
    rate = _rate;
    return true;
  }

  /**
   * @dev Function to set totalCap.
   * @return True if the operation was successful.
   */
  function setTotalCap(uint256 _capInWei) onlyOwner external returns (bool) {
    totalCap = _capInWei;
    return true;
  }

  /**
   * @dev Function to set individualCap.
   * @return True if the operation was successful.
   */
  function setIndividualCap(uint256 _capInWei) onlyOwner external returns (bool) {
    individualCap = _capInWei;
    return true;
  }

  /**
   * @dev Function to end the sale.
   * @return True if the operation was successful.
   */
  function endPublicTGE() onlyOwner external returns (bool) {
    publicTGEEndTime = now;
    return true;
  }

  function saveContribution(address beneficiary, uint256 weiAmount, bool _isPrivateTGE) internal {
    // save contribution
    contributions[beneficiary].push(Contribution({
        timestamp: now,
        WEIContributed: weiAmount,
        LST_WEI_rate: rate,
        isPrivateTGE: _isPrivateTGE
      })
    );
  }

  function removeContribution(address beneficiary, uint256 weiAmount, bool _isPrivateTGE) internal {
    // save contribution
    contributionsRemoved[beneficiary].push(
      ContributionRemoved({
        timestamp: now,
        WEIRemoved: weiAmount,
        LST_WEI_rate: rate,
        isPrivateTGE: _isPrivateTGE
      })
    );
  }

  // send ether to the fund collection fundsWallet
  // override to create custom fund forwarding mechanisms
  function forwardFunds() internal {
    fundsWallet.transfer(msg.value);
  }

  // @return true if the transaction can buy tokens
  function validPurchase() internal view returns (bool) {
    bool withinPeriod = now >= publicTGEStartTime && now <= publicTGEEndTime;
    bool nonZeroPurchase = msg.value != 0;
    return withinPeriod && nonZeroPurchase;
  }

  // @return true if crowdsale event has ended
  function hasEnded() external view returns (bool) {
    return now > publicTGEEndTime;
  }

  // Total contributions made by contributor
  function getTotalContributions(address _address) external view returns(uint256) {
    return contributions[_address].length;
  }

  // Detail about contribution
  function getContributionDetail (
        address _address,
        uint256 _index
      )
      external
      view
      returns (
        uint256,
        uint256,
        uint256
      )
  {
    require(_index < contributions[_address].length);
    Contribution storage _contribution = contributions[_address][_index];
    return (
      _contribution.timestamp,
      _contribution.WEIContributed,
      _contribution.LST_WEI_rate
    );
  }

  // Total contributions removed from contributor
  function getTotalContributionsRemoved(address _address) external view returns(uint256) {
    return contributionsRemoved[_address].length;
  }

  // Detail about contribution
  function getContributionRemovedDetail (
        address _address,
        uint256 _index
      )
      external
      view
      returns (
        uint256,
        uint256,
        uint256
      )
  {
    require(_index < contributionsRemoved[_address].length);
    ContributionRemoved storage _contribution = contributionsRemoved[_address][_index];
    return (
      _contribution.timestamp,
      _contribution.WEIRemoved,
      _contribution.LST_WEI_rate
    );
  }

  /**
   * @dev Transfer all Ether held by the contract to the owner.
   */
  function escapeHatchTransferRemainingBalance() whenPaused external onlyOwner {
    owner.transfer(this.balance);
  }
}


contract TGE is BaseTGEContract {

  // External contracts
  TRS public TRSContract;
  Wallet public WalletContract;

  uint256 constant public precision = 10 ** 18;
  uint256 public TRSOffset = 7 days;
  mapping (address => bool) private hasVested;

  modifier onlyTRS() {
    require((address(TRSContract) != 0) && (msg.sender == address(TRSContract)));
    _;
  }

  modifier onlyOwnerOrTRS() {
    require((msg.sender == owner) || ((address(TRSContract) != 0) && (msg.sender == address(TRSContract))));
    _;
  }

  function setTRSContract(address _address) onlyOwner external returns(bool) {
    TRSContract = TRS(_address);
    return true;
  }

  modifier onlyWallet() {
    require((address(WalletContract) != 0) && (msg.sender == address(WalletContract)));
    _;
  }

  function setWalletContract(address _address) onlyOwner external returns(bool) {
      WalletContract = Wallet(_address);
      return true;
  }

  function setTRSOffset(uint256 _offset) onlyOwner external returns(bool) {
      TRSOffset = _offset;
      return true;
  }

  function init(
    address _token,
    uint256 _rate,
    address _fundsWallet,
    address _whitelist,
    uint256 _publicTGEStartTime, uint256 _publicTGEEndTime
  ) onlyOwner external returns(bool) {
    require(_publicTGEStartTime >= now);
    require(_publicTGEEndTime >= _publicTGEStartTime);
    require(_rate > 0);
    require(_fundsWallet != address(0));

    token = LendroidSupportToken(_token);
    whitelist = ContributorWhitelist(_whitelist);
    rate = _rate;
    fundsWallet = _fundsWallet;
    publicTGEStartTime = _publicTGEStartTime;
    publicTGEEndTime = _publicTGEEndTime;

    totalCap = 25000 * precision;
    individualCap = 5000 * precision;
    return true;
  }

  // fallback function can be used to buy tokens
  function () external payable {
    _reserveTokens(msg.sender, msg.value);
  }

  // low level token purchase function
  function buyTokens(address beneficiary) external payable {
    _reserveTokens(beneficiary, msg.value);
  }

  function _reserveTokens(address _beneficiary, uint256 weiAmount) whilePublicTGEIsActive whenNotPaused internal {
    require(_beneficiary != address(0));
    require((now < publicTGEStartTime) || (now >= publicTGEStartTime && validPurchase()));
    // Validate contributor has been whitelisted
    require(whitelist.isWhitelisted(_beneficiary));
    // update state
    weiContributed[_beneficiary] = weiContributed[_beneficiary].add(weiAmount);
    require(weiContributed[_beneficiary] <= individualCap);
    if (now >= publicTGEStartTime) {
      weiRaised = weiRaised.add(weiAmount);
      require(weiRaised <= totalCap);
    }
    /* weiRaised = weiRaised.add(weiAmount);
    require(weiRaised <= totalCap); */
    // Save the contribution for future reference
    bool isPrivateTGE = now < publicTGEStartTime;
    saveContribution(_beneficiary, weiAmount, isPrivateTGE);
    // calculate token amount to be created
    // Mint LST into beneficiary account
    uint256 tokens = weiAmount.mul(rate);
    bool vestingDecision = hasVested[_beneficiary];
    require(WalletContract.updateReservedTokens(_beneficiary, tokens, vestingDecision, false));
    forwardFunds();
  }

  function bulkReserveTokensForAddresses(address[] addrs, uint256[] tokenAmounts, bool[] _vestingDecisions) onlyOwner external returns(bool) {
    require(addrs.length <= 100);
    require((addrs.length == tokenAmounts.length) && (addrs.length == _vestingDecisions.length));
    for (uint i=0; i<addrs.length; i++) {
      require(WalletContract.updateReservedTokens(addrs[i], tokenAmounts[i], _vestingDecisions[i], false));
      saveContribution(addrs[i], 0, true);
    }
    return true;
  }

  function bulkRemoveReservedTokensForAddresses(address[] addrs, uint256[] tokenAmounts) onlyOwner external returns(bool) {
    require(addrs.length <= 100);
    require(addrs.length == tokenAmounts.length);
    bool vestingDecision;
    for (uint i=0; i<addrs.length; i++) {
      removeContribution(addrs[i], 0, true);
      vestingDecision = hasVested[addrs[i]];
      require(WalletContract.decrementReservedTokens(addrs[i], tokenAmounts[i], vestingDecision));
    }
    return true;
  }

  // Vesting logic
  // The following cases are checked for _beneficiary's actions:
  // 1. Had chosen not to vest previously, and chooses not to vest now
  // 2. Had chosen not to vest previously, and chooses to vest now
  // 3. Had chosen to vest previously, and chooses not to vest now
  // 4. Had chosen to vest previously, and chooses to vest now
  // 2 & 3 are valid cases
  // 1 and 4 are invalid because they are double-vesting actions
  function vest(bool _decision) external returns(bool) {
    return _vest(msg.sender, _decision);
  }

  function _vest(address _beneficiary, bool _decision) internal whenNotPaused returns(bool) {
    bool periodDuringPublicTGE = now <= publicTGEEndTime;
    bool periodDuringTRSOffset = (now > publicTGEEndTime) && (now.sub(publicTGEEndTime) <= TRSOffset);
    require(periodDuringPublicTGE || periodDuringTRSOffset);
    // Prevent double vesting
    bool doubleVesingDecision = hasVested[_beneficiary] && _decision;
    bool doubleNonVestingDecision = !hasVested[_beneficiary] && !_decision;
    require(!doubleVesingDecision || !doubleNonVestingDecision);
    // Update totalReservedForVesting based on vesting decision
    require(WalletContract.updateReservedTokens(_beneficiary, 0, _decision, true));
    hasVested[_beneficiary] = _decision;
    return true;
  }

  function vestFor(address _beneficiary, bool _decision) external onlyOwner returns(bool) {
    return _vest(_beneficiary, _decision);
  }

  function isVestedContributor(address _beneficiary) external view onlyOwnerOrTRS returns(bool) {
    return hasVested[_beneficiary];
  }

}


contract Wallet is HasNoEther, Pausable, Destructible {

  using SafeMath for uint256;
  Vault public VaultContract;
  TGE public TGEContract;
  TRS public TRSContract;

  mapping (address => bool) private hasWithdrawnBeforeTRS;

  bool public tokenWithdrawalActivated = false;

  // Total LSTs that would be reserved during the sale. Useful for calculating
  // total bonus at end of sale
  uint256 private totalReservedForVesting;
  uint256 private totalWithdrawableBeforeTRS;
  // Bonus counters
  uint256 public totalAvailableTokens;
  uint256 public totalReservedTokensDuringTGE;
  uint256 public initialVestedReleasePercentage;
  uint256 private bonusMultiplier;

  // addresses for whom LSTs will be reserved following purchase
  mapping (address => uint256) private reservedTokens;
  mapping (address => uint256) private releasedTokens;

  // withdrawable LST after end of sale
  mapping (address => uint256) private withdrawable;

  modifier onlyTGE() {
    require((address(TGEContract) != 0) && (msg.sender == address(TGEContract)));
    _;
  }

  modifier onlyTRS() {
    require((address(TRSContract) != 0) && (msg.sender == address(TRSContract)));
    _;
  }

  modifier onlyOwnerOrTRS() {
    require((msg.sender == owner) || ((address(TRSContract) != 0) && (msg.sender == address(TRSContract))));
    _;
  }

  function init(uint256 _totalLST, uint256 _initialBonusPercentage) onlyOwner external returns(bool) {
    totalAvailableTokens = _totalLST * TGEContract.precision();
    initialVestedReleasePercentage = _initialBonusPercentage;
    return true;
  }

  function setVaultContract(address _address) onlyOwner external returns(bool) {
      VaultContract = Vault(_address);
      return true;
  }

  function setTGEContract(address _address) onlyOwner external returns(bool) {
      TGEContract = TGE(_address);
      return true;
  }

  function setTRSContract(address _address) onlyOwner external returns(bool) {
      TRSContract = TRS(_address);
      return true;
  }

  function setTokenWithdrawalActivation(bool _value) onlyOwner external returns(bool) {
      tokenWithdrawalActivated = _value;
      return true;
  }

  function setBonusMultiplier() onlyOwner external returns(bool) {
      bonusMultiplier = totalAvailableTokens.mul(initialVestedReleasePercentage).div(totalReservedForVesting);
      return true;
  }

  function setReservedTokenAmount(address _beneficiary, uint256 _value) onlyOwner external returns(bool) {
      reservedTokens[_beneficiary] = _value;
      return true;
  }

  function setReleasedTokenAmount(address _beneficiary, uint256 _value) onlyOwner external returns(bool) {
      releasedTokens[_beneficiary] = _value;
      return true;
  }

  function setwithdrawableTokenAmount(address _beneficiary, uint256 _value) onlyOwner external returns(bool) {
      withdrawable[_beneficiary] = _value;
      return true;
  }

  // _updateOnlyTotal is true only when called by TGE.vest()
  function updateReservedTokens(address _beneficiary, uint256 _tokens, bool _vestingDecision, bool _updateOnlyTotal) external onlyTGE returns(bool) {
    if (_updateOnlyTotal) {
      if (_vestingDecision) {
        totalReservedForVesting = totalReservedForVesting.add(reservedTokens[_beneficiary]);
      }
      else {
        totalReservedForVesting = totalReservedForVesting.sub(reservedTokens[_beneficiary]);
      }
    }
    else {
      totalReservedTokensDuringTGE = totalReservedTokensDuringTGE.add(_tokens);
      reservedTokens[_beneficiary] = reservedTokens[_beneficiary].add(_tokens);
      if (_vestingDecision) {
        totalReservedForVesting = totalReservedForVesting.add(_tokens);
      }
    }
    return true;
  }

  function decrementReservedTokens(address _beneficiary, uint256 _tokens, bool _vestingDecision) external onlyTGE returns(bool) {
    totalReservedTokensDuringTGE = totalReservedTokensDuringTGE.sub(_tokens);
    reservedTokens[_beneficiary] = reservedTokens[_beneficiary].sub(_tokens);
    if (_vestingDecision) {
      totalReservedForVesting = totalReservedForVesting.sub(_tokens);
    }
    return true;
  }

  function _withdraw(address _beneficiary) internal returns(bool) {
    uint256 publicTGEEndTime = TGEContract.publicTGEEndTime();
    uint trsOffset = TGEContract.TRSOffset();
    if (now > publicTGEEndTime && now.sub(publicTGEEndTime) > trsOffset) {
      require(!hasWithdrawnBeforeTRS[_beneficiary]);
      require(reservedTokens[_beneficiary] > 0);
      hasWithdrawnBeforeTRS[_beneficiary] = true;
      // Initialize withdrawableAmount to the reservedAmount
      if (TGEContract.isVestedContributor(_beneficiary)) {
        // Calculate vested proportion as a reservedAmount / totalReservedForVesting
        assert(bonusMultiplier != 0);
        uint256 reservedAmountWithBonus = reservedTokens[_beneficiary].mul(bonusMultiplier).div(TGEContract.precision());
        // set withdrawableAmount to initialBonus
        withdrawable[_beneficiary] = reservedAmountWithBonus;
        // Reserve remaining tokens in TRS
        reservedTokens[_beneficiary] = reservedAmountWithBonus.sub(withdrawable[_beneficiary]);
      }
      else {
        withdrawable[_beneficiary] = reservedTokens[_beneficiary];
        // Clear the reserve registry for unvested contributor
        reservedTokens[_beneficiary] = 0;
      }
      totalWithdrawableBeforeTRS = totalWithdrawableBeforeTRS.add(withdrawable[_beneficiary]);
    }
    if (tokenWithdrawalActivated && withdrawable[_beneficiary] > 0) {
      require(VaultContract.transferTokens(_beneficiary, withdrawable[_beneficiary]));
      withdrawable[_beneficiary] = 0;
    }
    return true;
  }

  function withdraw() external whenNotPaused returns(bool) {
    return _withdraw(msg.sender);
  }

  function withdrawFor(address _beneficiary) external onlyOwner returns(bool) {
    return _withdraw(_beneficiary);
  }

  // BulkWithdraw
  function bulkWithdraw(address[] addrs) onlyOwner external returns(bool) {
    require(addrs.length <= 100);
    for (uint i=0; i<addrs.length; i++) {
      if (tokenWithdrawalActivated && withdrawable[addrs[i]] > 0) {
        require(VaultContract.transferTokens(addrs[i], withdrawable[addrs[i]]));
        withdrawable[addrs[i]] = 0;
      }
    }
    return true;
  }

  function _stats(address _beneficiary) internal view returns(uint256, uint256, uint256) {
      return (
        reservedTokens[_beneficiary],
        releasedTokens[_beneficiary],
        withdrawable[_beneficiary]
      );
  }

  function getStats(address _beneficiary) external onlyOwnerOrTRS view returns(uint256, uint256, uint256) {
    return _stats(_beneficiary);
  }

  function myStats() external view returns(uint256, uint256, uint256) {
    return _stats(msg.sender);
  }

  function updateStats(address _beneficiary, uint256 _releaseIncrement, uint256 _withdrawableAmount) external onlyTRS returns(bool) {
    releasedTokens[_beneficiary] = releasedTokens[_beneficiary].add(_releaseIncrement);
    withdrawable[_beneficiary] = _withdrawableAmount;
    totalAvailableTokens = totalAvailableTokens.sub(_releaseIncrement);
    return true;
  }

  function getTotalReservedForVesting() external onlyOwner view returns(uint256) {
    return totalReservedForVesting;
  }

  function getBonusMultiplier() onlyOwner external view returns(uint256) {
      return bonusMultiplier;
  }

  function hasContributorWithdrawnBeforeTRS(address _beneficiary) onlyOwner external view returns(bool) {
    return hasWithdrawnBeforeTRS[_beneficiary];
  }

}


contract TRS is HasNoEther, Pausable, Destructible {

  using SafeMath for uint256;

  // External contracts
  TGE public TGEContract;
  Wallet public WalletContract;
  Vault public VaultContract;

  // TRS Schedule counters
  uint256 public totalReleaseCycles;
  uint constant public scheduleInterval = 30 days;
  bool public scheduleConfigured;
  bool public scheduleLocked;
  uint256 public scheduleStartTime = 0;
  uint256 public cyclicalVestedReleasePercentage;

  modifier onlyTGE() {
    require((address(TGEContract) != 0) && (msg.sender == address(TGEContract)));
    _;
  }

  modifier onlyWallet() {
    require((address(WalletContract) != 0) && (msg.sender == address(WalletContract)));
    _;
  }

  modifier preScheduleLock() { require(!scheduleLocked && scheduleStartTime == 0); _; }

  /**
   * Lock called, deposits no longer available.
  */
  modifier postScheduleLock() { require(scheduleLocked); _; }

  /**
    * Prestart, state is after lock, before start
    */
  modifier preScheduleStart() { require(scheduleLocked && scheduleStartTime == 0); _; }

  /**
   * Start called, the TRS contract is now finalized, and withdrawals
   * are now permitted.
   */
  modifier postScheduleStart() { require(scheduleLocked && scheduleStartTime != 0); _; }

  /**
   * Uninitialized state, before init is called. Mainly used as a guard to
   * finalize periods and t0special.
   */
  modifier scheduleConfigurationIncomplete() { require(!scheduleConfigured); _; }

  /**
   * Post initialization state, mainly used to guarantee that
   * periods and t0special have been set properly before starting
   * the withdrawal process.
   */
  modifier scheduleConfigurationCompleted() { require(scheduleConfigured); _; }

  function setTGEContract(address _address) onlyOwner external returns(bool) {
      TGEContract = TGE(_address);
      return true;
  }

  function setVaultContract(address _address) onlyOwner external returns(bool) {
      VaultContract = Vault(_address);
      return true;
  }

  function setWalletContract(address _address) onlyOwner external returns(bool) {
      WalletContract = Wallet(_address);
      return true;
  }

  // Release logic

  /**
  * Initialization function, should be called after contract deployment. The
  * addition of this function allows contract compilation to be simplified
  * to one contract, instead of two.
  *
  * periods and t0special are finalized, and effectively invariant, after
  * init is called for the first time.
  */
  function configureSchedule(
      uint256 _cycles,
      uint256 _cyclicalWithdrawalPercentage
    ) external onlyOwner scheduleConfigurationIncomplete
  {
  	require(_cycles != 0);
  	totalReleaseCycles = _cycles;
  	cyclicalVestedReleasePercentage = _cyclicalWithdrawalPercentage;
	}

  function completeScheduleConfiguration() external onlyOwner {
    scheduleConfigured = true;
  }

  /**
  * Lock is called by the owner to lock the TRS contract
  * so that no more deposits may be made.
  */
  function lockSchedule() external onlyOwner {
	  scheduleLocked = true;
  }

  /**
	 * Starts the distribution of reserved tokens, it should be called
	 * after lock(), once all of the bonus tokens are send to this contract,
	 * and multiMint has been called.
	 */
	function startSchedule() onlyOwner scheduleConfigurationCompleted preScheduleStart external returns(bool) {
    /* totalAvailableTokens = totalAvailableTokens.sub(totalWithdrawableBeforeTRS); */
    scheduleStartTime = now;
    return true;
	}

	/**
	 * Check withdrawal is live, useful for checking whether
	 * the TRS contract is "live", withdrawal enabled, started.
	 */
	function hasScheduleStarted() external view whenNotPaused returns(bool) {
		return scheduleLocked && scheduleStartTime != 0;
	}

  /**
	 * Calculates the monthly period, starting after the startBlockTimestamp,
	 * periodAt will return 0 for all timestamps before startBlockTimestamp.
	 *
	 * Therefore period 0 is the range of time in which we have called start(),
	 * but have not yet passed startBlockTimestamp. Period 1 is the
	 * first monthly period, and so-forth all the way until the last
	 * period == periods.
	 *
	 * NOTE: not guarded since no state modifications are made. However,
	 * it will return invalid data before the postScheduleStart state. It is
	 * up to the user to manually check that the contract is in
	 * postScheduleStart state.
	 */
	function cycleAt(uint256 _timestamp) public view returns(uint256) {
		/**
		 * Lower bound, consider period 0 to be the time between
		 * start() and startBlockTimestamp
		 */
		if (scheduleStartTime > _timestamp)
			return 0;

		/**
		 * Calculate the appropriate period, and set an upper bound of
		 * periods - 1.
		 */
		uint256 c = ((_timestamp - scheduleStartTime) / scheduleInterval) + 1;
		if (c > totalReleaseCycles)
			c = totalReleaseCycles;
		return c;
	}

	// what withdrawal period are we in?
	// returns the cycle number from [0, totalReleaseCycles)
	function currentCycle() public view returns(uint256) {
		return cycleAt(now);
	}

  // release releases tokens to the sender
	// release can be called at most once per release cycle
	function release() external whenNotPaused returns(bool) {
		return releaseTo(msg.sender);
	}

	/**
	 * Calculates the fraction of total (one-off + monthly) withdrawableAmount
	 * given the current timestamp. No guards due to function being constant.
	 * Will output invalid data until the postScheduleStart state. It is up to the user
	 * to manually confirm contract is in postScheduleStart state.
	 */
	function availableForReleaseAt(uint256 _timestamp) public view returns (uint256) {
		/**
		 * Calculate the total withdrawableAmount, giving a numerator with range:
		 * [0.25 * 10 ** 18, 1 * 10 ** 18]
		 */
		return (cycleAt(_timestamp) * TGEContract.precision()) / (totalReleaseCycles);
	}

	/**
	 * Business logic of _releaseTo, the code is separated this way mainly for
	 * testing. We can inject and test parameters freely without worrying about the
	 * blockchain model.
	 *
	 * NOTE: Since function is constant, no guards are applied. This function will give
	 * invalid outputs unless in postScheduleStart state. It is up to user to manually check
	 * that the correct state is given (isStart() == true)
	 */
	function _releaseTo(
      uint256 _reservedAmount,
      uint256 _withdrawnAmount,
      uint256 _timestamp
    )
    view public returns (uint256)
  {
		uint256 fraction = availableForReleaseAt(_timestamp);

		/**
		 * There are concerns that the multiplication could possibly
		 * overflow, however this should not be the case if we calculate
		 * the upper bound based on our known parameters:
		 *
		 * Lets assume the minted token amount to be 500 million (reasonable),
		 * given a precision of 8 decimal places, we get:
		 * deposited[addr] = 5 * (10 ** 8) * (10 ** 8) = 5 * (10 ** 16)
		 *
		 * The max for fraction = 10 ** 18, and the max for total is
		 * also 5 * (10 ** 16).
		 *
		 * Therefore:
		 * deposited[addr] * fraction * total = 2.5 * (10 ** 51)
		 *
		 * The maximum for a uint256 is = 1.15 * (10 ** 77)
		 */
		uint256 withdrawableAmount = _reservedAmount.mul(fraction).div(TGEContract.precision());

		// check that we can withdraw something
		if (withdrawableAmount > _withdrawnAmount) {
			return withdrawableAmount - _withdrawnAmount;
		}
		return 0;
	}

	/**
	 * Public facing releaseTo, injects business logic with
	 * the correct model.
	 */
	function releaseTo(address addr) postScheduleStart whenNotPaused public returns (bool) {
		uint256 _reservedAmount;
    uint256 _releasedAmount;
    uint256 _withdrawableAmount;
    (_reservedAmount, _releasedAmount, _withdrawableAmount) = WalletContract.getStats(addr);
		uint256 diff = _releaseTo(_reservedAmount, _releasedAmount, now);

		// release could not be made
		if (diff == 0) {
			return false;
		}

		// check that we cannot withdraw more than max
		require((diff + _releasedAmount) <= _reservedAmount);

		// transfer and increment
    if (WalletContract.tokenWithdrawalActivated()) {
      require(VaultContract.transferTokens(addr, diff));
    }
    else {
      _withdrawableAmount = diff;
    }
    require(WalletContract.updateStats(addr, diff, _withdrawableAmount));
		return true;
	}

	// force withdrawal to many addresses
	function bulkRelease(address[] addrs) external onlyOwner whenNotPaused returns(bool) {
		for (uint i=0; i<addrs.length; i++) {
      releaseTo(addrs[i]);
    }
			return true;
	}

}


contract Vault is HasNoEther, Pausable, Destructible {

  using SafeMath for uint256;

  Wallet public WalletContract;
  LendroidSupportToken public token;

  modifier onlyWallet() {
    require((address(WalletContract) != 0) && (msg.sender == address(WalletContract)));
    _;
  }

  function setWalletContract(address _address) onlyOwner external returns(bool) {
      WalletContract = Wallet(_address);
      return true;
  }

  function setToken(address _address) onlyOwner external returns(bool) {
      token = LendroidSupportToken(_address);
      return true;
  }

  // transfer tokens
  function _transferTokens(address _beneficiary, uint256 tokens) internal returns(bool) {
  	require(token.transfer(_beneficiary, tokens));
  	return true;
  }

  function transferTokens(address _beneficiary, uint256 tokens) external onlyWallet whenNotPaused returns(bool) {
  	_transferTokens(_beneficiary, tokens);
  }

  function transferTokensTo(address _beneficiary, uint256 tokens) external onlyOwner returns(bool) {
  	_transferTokens(_beneficiary, tokens);
  }

}
