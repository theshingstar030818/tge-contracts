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

  // Sale status as a boolean
  bool public saleEnded;
  uint256 public saleEndedAt = 0;

  struct Contribution {
    uint256 timestamp;
    uint256 WEIContributed;
    uint256 LST_WEI_rate;
  }

  mapping (address => Contribution[]) private contributions;
  mapping (address => uint256) public totalWeiContributed;

  modifier whileSaleIsActive() {
    require(!saleEnded);
    _;
  }

  modifier afterSaleHasEnded() {
    require(saleEnded && saleEndedAt != 0);
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
    bool nonZeroPurchase = msg.value != 0;
    return nonZeroPurchase;
  }

  // overriding PrivateSale#hasEnded to add cap logic
  // @return true if crowdsale event has ended
  function hasEnded() public view returns (bool) {
    return saleEnded;
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
  uint256 public totalVested;
  uint256 public totalBonus;
  uint256 public initialBonusPercentage;
  uint256 constant public precision = 10 ** 18;

  modifier whileVestingDecisionCanBeMade() {
    require((!saleEnded) || ((saleEndedAt != 0) && (now.sub(saleEndedAt) <= maxVestingDecisionOffsetAfterSaleEnd)));
    _;
  }

  modifier whenVestingDecisionCannotBeMade() {
    require((saleEndedAt != 0) && (now.sub(saleEndedAt) > maxVestingDecisionOffsetAfterSaleEnd));
    _;
  }

  modifier canWithdraw() {
    require((tokenWithdrawalActivated) && (saleEndedAt != 0) && (now.sub(saleEndedAt) > maxVestingDecisionOffsetAfterSaleEnd));
    _;
  }

  function PrivateSale(
      address _token,
      uint256 _rate,
      address _wallet,
      address _whitelist,
      uint256 _totalBonus,
      uint256 _initialBonusPercentage
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
    saleEnded = false;
    maxVestingDecisionOffsetAfterSaleEnd = 7 days;
    tokenWithdrawalActivated = false;
    totalBonus = _totalBonus;
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

  function endSale() whileSaleIsActive onlyOwner public returns(bool) {
    saleEnded = true;
    saleEndedAt = now;
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
    reserved[beneficiary] = reserved[beneficiary].add(tokens);
    totalReserved = totalReserved.add(tokens);
    TokenPurchase(beneficiary, weiAmount, tokens);

    forwardFunds();
  }

  function vest(bool _decision) whileVestingDecisionCanBeMade whenNotPaused public returns(bool) {
    require(reserved[msg.sender] > 0);
    uint256 tokens = reserved[msg.sender];
    if (_decision) {
      totalVested = totalVested.add(tokens);
    }
    else {
      totalVested = totalVested.sub(tokens);
    }
    vesting[msg.sender] = _decision;
    return true;
  }

  function withdraw() afterSaleHasEnded whenVestingDecisionCannotBeMade whenNotPaused public returns(bool) {
    uint256 tokens = reserved[msg.sender];
    // Update reserved accordingly
    reserved[msg.sender] = 0;
    uint256 withdrawableAmount = tokens;
    if (vesting[msg.sender]) {
      // Set vesting proportional to contribution
      uint256 bonusProportion = tokens.div(totalVested);
      uint256 bonusLST = totalBonus.mul(bonusProportion);
      tokens = tokens.add(bonusLST);
      // set withdrawable tokens to initialBonus
      withdrawableAmount = tokens.mul(initialBonusPercentage).mul(precision);
      // Reserve remaining tokens in TRS
      uint256 remainingAmount = tokens.sub(withdrawableAmount);
      require(TRSContract.reserveFor(msg.sender, remainingAmount));
    }
    withdraws[msg.sender] = withdrawableAmount;

    if (tokenWithdrawalActivated) {
      require(_performWithdraw(msg.sender));
    }
    return true;
  }

  function _performWithdraw(address _beneficiary) internal returns(bool) {
    uint256 _tokens = withdraws[_beneficiary];
    withdraws[_beneficiary] = 0;
    require(_tokens > 0);
    require(TRSContract.transferTokens(_beneficiary, _tokens));
    return true;
  }

  function unSubscribeFromTRS() whenNotPaused public returns(bool) {
    require(reserved[msg.sender] > 0);
    uint256 tokens = reserved[msg.sender];
    reserved[msg.sender] = 0;
    require(token.transfer(msg.sender, tokens));
    return true;
  }

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

  mapping (address => uint256) public reserved;
  mapping (address => uint256) public released;

  address[] subscriptions;

  uint256 public releaseCycles;

  uint constant public interval = 30 days;
  uint constant public precision = 10 ** 18;
  /**
   * Events
   */
  event Released(address indexed toWhom, uint amount);
  event Reserved(address indexed forWhom, uint amount);

  bool public initialized;

  bool public locked;
  uint256 public startedAt = 0;

  uint256 public cyclicalBonusPercentage;

  modifier preLock() { require(!locked && startedAt == 0); _; }

  /**
   * Lock called, deposits no longer available.
  */
  modifier postLock() { require(locked); _; }

  /**
    * Prestart, state is after lock, before start
    */
  modifier preStart() { require(locked && startedAt == 0); _; }

  /**
   * Start called, the savings contract is now finalized, and withdrawals
   * are now permitted.
   */
  modifier postStart() { require(locked && startedAt != 0); _; }

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
  	releaseCycles = _cycles;
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

  // reserve tokens to be released
  function reserveFor(address _beneficiary, uint256 tokens) public auth preLock whenNotPaused returns(bool) {
  	reserved[_beneficiary] = tokens;
  	subscriptions.push(_beneficiary);
  	Reserved(_beneficiary, tokens);
  	return true;
  }

  // transfer tokens
  function transferTokens(address _beneficiary, uint256 tokens) public auth whenNotPaused returns(bool) {
  	require(token.transfer(_beneficiary, tokens));
  	return true;
  }

  function getTotalSubscriptions() public constant returns(uint256) {
      return subscriptions.length;
  }


}
