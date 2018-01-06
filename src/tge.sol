pragma solidity ^0.4.17;

import "./base.sol";


contract LendroidSupportToken is MintableToken, PausableToken {

  string public constant name = "Lendroid Support Token";
  string public constant symbol = "LST";
  uint8 public constant decimals = 18;

  uint256 public constant MAX_SUPPLY = 6000000000 * (10 ** uint256(decimals));// 6 billion tokens, 18 decimal places

  /**
   * @dev Constructor that pauses tradability of tokens.
   */
  function LendroidSupportToken() public {
    paused = true;
  }
}


contract ContributorWhitelist is HasNoEther {
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
 * @title BaseSale
 * @dev BaseSale is a base contract for managing a token crowdsale.
 * Investors can make token purchases and (if the canMint option is true)
 * the conact will assign them tokens based on a token per ETH rate.
 * Funds collected are forwarded to a coldStorageWallet as they arrive.
 */
contract BaseSale is Pausable {
  using SafeMath for uint256;

  // start and end timestamps (both inclusive) when sale is open
  uint256 public startTime;
  uint256 public endTime;

  // The token being sold
  LendroidSupportToken public token;

  // Contributor whitelist
  ContributorWhitelist public whitelist;

  // address where funds are collected
  address public wallet;

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
  }

  mapping (address => Contribution[]) private contributions;
  mapping (address => uint256) public totalWeiContributed;

  modifier whileSaleIsActive() {
    require(now <= endTime);
    _;
  }

  modifier afterSaleHasEnded() {
    require(now > endTime);
    _;
  }

  /**
   * @dev Function to set ContributorWhitelist address.
   * @return True if the operation was successful.
   */
  function setWhitelist(address _address) onlyOwner public returns (bool) {
    whitelist = ContributorWhitelist(_address);
    return true;
  }

  /**
   * @dev Function to set rate.
   * @return True if the operation was successful.
   */
  function setRate(uint256 _rate) onlyOwner public returns (bool) {
    rate = _rate;
    return true;
  }

  /**
   * @dev Function to set totalCap.
   * @return True if the operation was successful.
   */
  function setTotalCap(uint256 _capInWei) onlyOwner public returns (bool) {
    totalCap = _capInWei;
    return true;
  }

  /**
   * @dev Function to set individualCap.
   * @return True if the operation was successful.
   */
  function setIndividualCap(uint256 _capInWei) onlyOwner public returns (bool) {
    individualCap = _capInWei;
    return true;
  }

  /**
   * @dev Function to end the sale.
   * @return True if the operation was successful.
   */
  function endSale() onlyOwner public returns (bool) {
    endTime = now;
    return true;
  }

  function saveContribution(address beneficiary) internal {
    // save contribution
    Contribution memory _contribution = Contribution({
      timestamp: now,
      WEIContributed: msg.value,
      LST_WEI_rate: rate
    });
    contributions[beneficiary].push(_contribution);
  }

  // send ether to the fund collection wallet
  // override to create custom fund forwarding mechanisms
  function forwardFunds() internal {
    wallet.transfer(msg.value);
  }

  // @return true if the transaction can buy tokens
  function validPurchase() internal view returns (bool) {
    bool withinPeriod = now >= startTime && now <= endTime;
    bool nonZeroPurchase = msg.value != 0;
    return withinPeriod && nonZeroPurchase;
  }

  // overriding PrivateSale#hasEnded to add cap logic
  // @return true if crowdsale event has ended
  function hasEnded() public view returns (bool) {
    return now > endTime;
  }

  // Total contributions made by contributor
  function getTotalContributions(address _address) public view returns(uint256) {
    return contributions[_address].length;
  }

  // Detail about contribution
  function getContributionDetail (
        address _address,
        uint256 _index
      )
      public
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

  /**
   * @dev Transfer all Ether held by the contract to the owner.
   */
  function escapeHatchTransferRemainingBalance() whenPaused external onlyOwner {
    require(owner.send(this.balance));
  }
}


contract SaftSale is BaseSale {

  function SaftSale(
    address _token,
    uint256 _rate,
    address _wallet,
    address _whitelist
  )
  public
  {
    require(_rate > 0);
    require(_wallet != address(0));

    token = LendroidSupportToken(_token);
    whitelist = ContributorWhitelist(_whitelist);
    rate = _rate;
    wallet = _wallet;

    totalCap = 25000 * (10**18);
    individualCap = 5000 * (10**18);
  }

  // fallback function can be used to buy tokens
  function () external payable {
    buySaft(msg.sender);
  }

  // low level token purchase function
  function buySaft(address beneficiary) whenNotPaused public payable {
    require(beneficiary != address(0));
    require(validPurchase());
    // Validate contributor has been whitelisted
    require(whitelist.isWhitelisted(beneficiary));

    uint256 weiAmount = msg.value;

    // update state
    totalWeiContributed[beneficiary] = totalWeiContributed[beneficiary].add(weiAmount);
    require(totalWeiContributed[beneficiary] <= individualCap);
    weiRaised = weiRaised.add(weiAmount);
    require(weiRaised <= totalCap);

    // Save the contribution for future reference
    saveContribution(beneficiary);
    forwardFunds();
  }
}


contract PrivateSale is BaseSale {
  event TokenPurchase(address indexed beneficiary, uint256 value, uint256 amount);

  // addresses for whom LSTs will be reserved following purchase
  mapping (address => uint256) public reserved;
  // Total LSTs that would be reserved during the sale. Useful for calculating
  // total bonus at end of sale
  uint256 public totalReserved;
  // addresses that choose to vest LST after end of sale
  mapping (address => bool) public vesting;
  // addresses that choose to withdraw LST after end of sale
  mapping (address => uint256) public withdraws;

  TokenReleaseScheduler public TRSContract;

  uint256 public maxVestingDecisionOffsetAfterSaleEnd;
  bool public tokenWithdrawalActivated;

  // Vesting and bonus stats
  uint256 public totalReservedForVesting;
  uint256 public totalBonus;
  uint256 public initialBonusPercentage;
  uint256 constant public precision = 10 ** 18;

  modifier whileVestingDecisionCanBeMade() {
    require((now <= endTime) || (now > endTime && now.sub(endTime) <= maxVestingDecisionOffsetAfterSaleEnd));
    _;
  }

  modifier whenVestingDecisionCannotBeMade() {
    require(now > endTime && now.sub(endTime) > maxVestingDecisionOffsetAfterSaleEnd);
    _;
  }

  modifier canWithdraw() {
    require((tokenWithdrawalActivated) && (now.sub(endTime) > maxVestingDecisionOffsetAfterSaleEnd));
    _;
  }

  function PrivateSale(
      address _token,
      uint256 _rate,
      address _wallet,
      address _whitelist,
      uint256 _totalBonus,
      uint256 _initialBonusPercentage,
      uint256 _startTime, uint256 _endTime
    )
    public
  {
    require(_startTime >= now);
    require(_endTime >= _startTime);
    require(_rate > 0);
    require(_wallet != address(0));

    token = LendroidSupportToken(_token);
    whitelist = ContributorWhitelist(_whitelist);
    rate = _rate;
    wallet = _wallet;
    startTime = _startTime;
    endTime = _endTime;

    totalCap = 25000 * (10**18);
    individualCap = 5000 * (10**18);
    maxVestingDecisionOffsetAfterSaleEnd = 7 days;
    tokenWithdrawalActivated = false;
    totalBonus = _totalBonus.mul(precision);
    initialBonusPercentage = _initialBonusPercentage;
  }

  function setTRSContract(address _address) onlyOwner public returns(bool) {
      TRSContract = TokenReleaseScheduler(_address);
      return true;
  }

  function setTokenWithdrawalActivation(bool _value) onlyOwner public returns(bool) {
      tokenWithdrawalActivated = _value;
      return true;
  }

  function setVestingDecisionOffset(uint256 _offset) onlyOwner public returns(bool) {
      maxVestingDecisionOffsetAfterSaleEnd = _offset;
      return true;
  }

  function finalizeBonus() afterSaleHasEnded onlyOwner public returns(bool) {
    totalBonus = totalBonus.sub(totalReserved);
    return true;
  }

  // fallback function can be used to buy tokens
  function () external payable {
    buyTokens(msg.sender);
  }

  // low level token purchase function
  function buyTokens(address beneficiary) whileSaleIsActive whenNotPaused public payable {
    require(beneficiary != address(0));
    require(validPurchase());
    // Validate contributor has been whitelisted
    require(whitelist.isWhitelisted(beneficiary));

    uint256 weiAmount = msg.value;

    // update state
    totalWeiContributed[beneficiary] = totalWeiContributed[beneficiary].add(weiAmount);
    require(totalWeiContributed[beneficiary] <= individualCap);
    weiRaised = weiRaised.add(weiAmount);
    require(weiRaised <= totalCap);

    // Save the contribution for future reference
    saveContribution(beneficiary);
    // calculate token amount to be created
    // Mint LST into beneficiary account
    uint256 tokens = weiAmount.mul(rate);
    require(totalBonus > tokens);
    reserved[beneficiary] = reserved[beneficiary].add(tokens);
    totalReserved = totalReserved.add(tokens);
    totalBonus = totalBonus.sub(tokens);
    TokenPurchase(beneficiary, weiAmount, tokens);

    forwardFunds();
  }

  function vest(bool _decision) public returns(bool) {
    return vestFor(msg.sender, _decision);
  }

  function vestFor(address _beneficiary, bool _decision) whileVestingDecisionCanBeMade whenNotPaused public returns(bool) {
    uint256 tokens = reserved[_beneficiary];
    require(tokens > 0);
    if (_decision && !vesting[_beneficiary]) {
      totalReservedForVesting = totalReservedForVesting.add(tokens);
    }
    if (!_decision && vesting[_beneficiary]) {
      totalReservedForVesting = totalReservedForVesting.sub(tokens);
    }
    vesting[_beneficiary] = _decision;
    return true;
  }

  function _calculateReserveWithBonus(address _beneficiary) internal constant returns(uint256) {
    uint256 reservedAmount = reserved[_beneficiary];
    uint256 bonusProportion = reservedAmount.div(totalReservedForVesting);
    uint256 bonusAmount = totalBonus.mul(bonusProportion).div(precision);
    /* uint256 reservedAmountWithBonus = reservedAmount.add(bonusAmount); */
    return bonusAmount;
  }

  function showBonusFor(address _beneficiary) constant public returns(uint256) {
    return _calculateReserveWithBonus(_beneficiary);
  }

  function withdraw() afterSaleHasEnded whenVestingDecisionCannotBeMade whenNotPaused public returns(bool) {
    // Get tokens reserved
    uint256 reservedAmount = reserved[msg.sender];
    // Initialize withdrawableAmount to the reservedAmount
    uint256 withdrawableAmount = reservedAmount;
    // If user chose to vest, set the withdrawable and reserved amounts
    // proportional to the vested percentage
    if (vesting[msg.sender]) {
      // Calculate vested proportion as a reservedAmount / totalReservedForVesting
      uint256 reservedAmountWithBonus = _calculateReserveWithBonus(msg.sender);
      // set withdrawableAmount to initialBonus
      withdrawableAmount = reservedAmountWithBonus.mul(initialBonusPercentage).div(precision);
      // Reserve remaining tokens in TRS
      uint256 remainingAmount = reservedAmountWithBonus.sub(withdrawableAmount);
      require(TRSContract.reserveFor(msg.sender, remainingAmount));
    }
    // Clear the reserve registry so sender cannot withdraw multiple times
    reserved[msg.sender] = 0;
    if (tokenWithdrawalActivated) {
      withdraws[msg.sender] = 0;
      require(TRSContract.transferTokens(msg.sender, withdrawableAmount));
    }
    else {
      withdraws[msg.sender] = withdrawableAmount;
    }
    return true;
  }

  function _performWithdraw(address _beneficiary) internal returns(bool) {
    uint256 _tokens = withdraws[_beneficiary];
    require(_tokens > 0);
    withdraws[_beneficiary] = 0;
    require(TRSContract.transferTokens(_beneficiary, _tokens));
    return true;
  }

  // TODO: BatchWithdraw

}


contract TokenReleaseScheduler is HasNoEther, Pausable {

  using SafeMath for uint256;

  mapping (address => bool) public authorized;

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

  LendroidSupportToken public token;
  uint256 public totalReserved;
  mapping (address => uint256) public reserved;
  mapping (address => uint256) public released;

  address[] reservations;

  uint256 public totalReleaseCycles;

  // the total remaining value
	uint public remainder;

	/**
	 * Total tokens owned by the contract after locking, and possibly
	 * updated by the foundation after subsequent sales.
	 */
	uint public total;

  uint constant public interval = 30 days;
  uint constant public precision = 10 ** 18;
  /**
   * Events
   */
  event Released(address indexed toWhom, uint amount);
  event Reserved(address indexed forWhom, uint amount);

  bool public initialized;

  bool public locked;
  uint256 public startTime = 0;

  uint256 public cyclicalBonusPercentage;

  modifier preLock() { require(!locked && startTime == 0); _; }

  /**
   * Lock called, deposits no longer available.
  */
  modifier postLock() { require(locked); _; }

  /**
    * Prestart, state is after lock, before start
    */
  modifier preStart() { require(locked && startTime == 0); _; }

  /**
   * Start called, the savings contract is now finalized, and withdrawals
   * are now permitted.
   */
  modifier postStart() { require(locked && startTime != 0); _; }

  /**
   * Uninitialized state, before init is called. Mainly used as a guard to
   * finalize periods and t0special.
   */
  modifier setupIncomplete() { require(!initialized); _; }

  /**
   * Post initialization state, mainly used to guarantee that
   * periods and t0special have been set properly before starting
   * the withdrawal process.
   */
  modifier setupCompleted() { require(initialized); _; }

  /**
   * Initialization function, should be called after contract deployment. The
   * addition of this function allows contract compilation to be simplified
   * to one contract, instead of two.
   *
   * periods and t0special are finalized, and effectively invariant, after
   * init is called for the first time.
   */
  function setup(
      uint256 _cycles,
      uint256 _cyclicalBonusPercentage,
      address _tokenAddress
    ) public onlyOwner setupIncomplete
  {
  	require(_cycles != 0);
  	totalReleaseCycles = _cycles;
  	cyclicalBonusPercentage = _cyclicalBonusPercentage;
  	token = LendroidSupportToken(_tokenAddress);
	}

  function completeSetup() public onlyOwner {
    initialized = true;
  }

  /**
   * Lock is called by the owner to lock the savings contract
   * so that no more deposits may be made.
   */
  function lock() public onlyOwner {
	  locked = true;
  }

  /**
	 * Starts the distribution of savings, it should be called
	 * after lock(), once all of the bonus tokens are send to this contract,
	 * and multiMint has been called.
	 */
	function start() onlyOwner setupCompleted preStart public {
		startTime = now;
		uint256 tokenBalance = token.balanceOf(this);
		total = tokenBalance;
		remainder = tokenBalance;
	}

	/**
	 * Check withdrawal is live, useful for checking whether
	 * the savings contract is "live", withdrawal enabled, started.
	 */
	function isStarted() constant public returns(bool) {
		return locked && startTime != 0;
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
	 * it will return invalid data before the postStart state. It is
	 * up to the user to manually check that the contract is in
	 * postStart state.
	 */
	function cycleAt(uint256 _timestamp) constant public returns(uint256) {
		/**
		 * Lower bound, consider period 0 to be the time between
		 * start() and startBlockTimestamp
		 */
		if (startTime > _timestamp)
			return 0;

		/**
		 * Calculate the appropriate period, and set an upper bound of
		 * periods - 1.
		 */
		uint256 c = ((_timestamp - startTime) / interval) + 1;
		if (c > totalReleaseCycles)
			c = totalReleaseCycles;
		return c;
	}

	// what withdrawal period are we in?
	// returns the cycle number from [0, totalReleaseCycles)
	function currentCycle() constant public returns(uint256) {
		return cycleAt(now);
	}

  // reserve tokens to be released
  function reserveFor(address _beneficiary, uint256 _tokens) public auth preLock whenNotPaused returns(bool) {
    // sanity checks
    require(_tokens > 0);
    // Add _beneficiary to reservations list if they haven't been added already
    if (reserved[_beneficiary] > 0) {
      uint256 reservedAmount = reserved[_beneficiary];
      totalReserved = totalReserved.sub(reservedAmount);
    }
    else {
      reservations.push(_beneficiary);
    }
    reserved[_beneficiary] = _tokens;
  	totalReserved = totalReserved.add(_tokens);
  	Reserved(_beneficiary, _tokens);
  	return true;
  }

  // transfer tokens
  function transferTokens(address _beneficiary, uint256 tokens) public auth whenNotPaused returns(bool) {
  	_performTokenTransfer(_beneficiary, tokens);
  	return true;
  }

  // internal function that does actual transfer tokens
  function _performTokenTransfer(address _beneficiary, uint256 tokens) internal {
  	require(token.transfer(_beneficiary, tokens));
  }

  /**
	 * Used to refund users who accidentaly transferred tokens to this
	 * contract, only available before contract is locked
	 */
	function refundTokens(address addr, uint amount) onlyOwner preLock public returns(bool) {
    require(reserved[addr] == 0);
		_performTokenTransfer(addr, amount);
    return true;
	}

  function getTotalReservations() public constant returns(uint256) {
      return reservations.length;
  }

  // Release logic
  // release releases tokens to the sender
	// release can be called at most once per release cycle
	function release() whenNotPaused public returns(bool) {
		return releaseTo(msg.sender);
	}

	/**
	 * Calculates the fraction of total (one-off + monthly) withdrawable
	 * given the current timestamp. No guards due to function being constant.
	 * Will output invalid data until the postStart state. It is up to the user
	 * to manually confirm contract is in postStart state.
	 */
	function availableForReleaseAt(uint256 _timestamp) constant public returns (uint256) {
		/**
		 * Calculate the total withdrawable, giving a numerator with range:
		 * [0.25 * 10 ** 18, 1 * 10 ** 18]
		 */
		return (cycleAt(_timestamp) * precision) / (totalReleaseCycles);
	}

	/**
	 * Business logic of _releaseTo, the code is separated this way mainly for
	 * testing. We can inject and test parameters freely without worrying about the
	 * blockchain model.
	 *
	 * NOTE: Since function is constant, no guards are applied. This function will give
	 * invalid outputs unless in postStart state. It is up to user to manually check
	 * that the correct state is given (isStart() == true)
	 */
	function _releaseTo(
      uint256 _reservedAmount,
      uint256 _withdrawnAmount,
      uint256 _timestamp,
      uint256 _total
    )
    constant public returns (uint256)
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
		uint256 withdrawable = ((_reservedAmount * fraction * _total) / totalReserved) / precision;

		// check that we can withdraw something
		if (withdrawable > _withdrawnAmount) {
			return withdrawable - _withdrawnAmount;
		}
		return 0;
	}

	/**
	 * Public facing releaseTo, injects business logic with
	 * the correct model.
	 */
	function releaseTo(address addr) postStart whenNotPaused public returns (bool) {
		uint _reservedAmount = reserved[addr];
		uint _releasedAmount = released[addr];

		uint diff = _releaseTo(_reservedAmount, _releasedAmount, now, total);

		// release could not be made
		if (diff == 0) {
			return false;
		}

		// check that we cannot withdraw more than max
		require((diff + _releasedAmount) <= ((_reservedAmount * total) / totalReserved));

		// transfer and increment
    _performTokenTransfer(addr, diff);

		released[addr] = released[addr].add(diff);
		remainder = remainder.sub(diff);
		Released(addr, diff);
		return true;
	}

	// force withdrawal to many addresses
	function bulkRelease(address[] addrs) whenNotPaused public {
		for (uint i=0; i<addrs.length; i++)
			releaseTo(addrs[i]);
	}

}
