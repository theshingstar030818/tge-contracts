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
  PrivateSale public saleContract;
  mapping (address => bool) whitelist;

  modifier onlyOwnerOrCrowdSaleContract() {
    require((msg.sender == owner) || (msg.sender == address(saleContract)));
    _;
  }

  function setSaleContractAddress(address _address) public onlyOwner returns(bool) {
    saleContract = PrivateSale(_address);
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

  function isWhitelisted(address _address) public onlyOwnerOrCrowdSaleContract view returns(bool) {
    return whitelist[_address];
  }

}


/**
 * @title Crowdsale
 * @dev Crowdsale is a base contract for managing a token crowdsale.
 * Crowdsales have a start and end timestamps, where investors can make
 * token purchases and the crowdsale will assign them tokens based
 * on a token per ETH rate. Funds collected are forwarded to a wallet
 * as they arrive.
 */
contract PrivateSale is Pausable {
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
  uint256 public totalCap = 25000 * (10**18);

  // individual cap in wei
  uint256 public individualCap = 5000 * (10**18);

  struct Contribution {
    uint256 timestamp;
    uint256 WEIContributed;
    uint256 LST_WEI_rate;
  }

  mapping (address => Contribution[]) private contributions;
  mapping (address => uint256) public totalWeiContributed;

  /**
   * event for token purchase logging
   * @param purchaser who paid for the tokens
   * @param beneficiary who got the tokens
   * @param value weis paid for purchase
   * @param amount amount of tokens purchased
   */
  event TokenPurchase(address indexed purchaser, address indexed beneficiary, uint256 value, uint256 amount);

  function PrivateSale(
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
  }

  // fallback function can be used to buy tokens
  function () external payable {
    buyTokens(msg.sender);
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

  // low level token purchase function
  function buyTokens(address beneficiary) whenNotPaused public payable {
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
    saveContribution();
    // calculate token amount to be created
    // Mint LST into beneficiary account
    uint256 tokens = weiAmount.mul(rate);
    token.mint(beneficiary, tokens);
    TokenPurchase(msg.sender, beneficiary, weiAmount, tokens);

    forwardFunds();
  }

  function saveContribution() internal {
    // save contribution
    Contribution memory _contribution = Contribution({
      timestamp: now,
      WEIContributed: msg.value,
      LST_WEI_rate: rate
    });
    contributions[msg.sender].push(_contribution);
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
    return paused;
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
