pragma solidity ^0.4.17;

/**
 * @title SafeMath
 * @dev Math operations with safety checks that throw on error
 */
library SafeMath {
  function mul(uint256 a, uint256 b) internal pure returns (uint256) {
    if (a == 0) {
      return 0;
    }
    uint256 c = a * b;
    assert(c / a == b);
    return c;
  }

  function div(uint256 a, uint256 b) internal pure returns (uint256) {
    // assert(b > 0); // Solidity automatically throws when dividing by 0
    uint256 c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn't hold
    return c;
  }

  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    assert(b <= a);
    return a - b;
  }

  function add(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a + b;
    assert(c >= a);
    return c;
  }
}

/**
 * @title Ownable
 * @dev The Ownable contract has an owner address, and provides basic authorization control
 * functions, this simplifies the implementation of "user permissions".
 */
contract Ownable {
  address public owner;


  event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);


  /**
   * @dev The Ownable constructor sets the original `owner` of the contract to the sender
   * account.
   */
  function Ownable() public {
    owner = msg.sender;
  }

  /**
   * @dev Throws if called by any account other than the owner.
   */
  modifier onlyOwner() {
    require(msg.sender == owner);
    _;
  }

  /**
   * @dev Allows the current owner to transfer control of the contract to a newOwner.
   * @param newOwner The address to transfer ownership to.
   */
  function transferOwnership(address newOwner) public onlyOwner {
    require(newOwner != address(0));
    OwnershipTransferred(owner, newOwner);
    owner = newOwner;
  }

}


contract SimpleTGE is Ownable {
  using SafeMath for uint256;

  uint256 constant public precision = 10 ** 18;

  // start and end timestamps (both inclusive) when sale is open
  uint256 public publicTGEStartBlockTimeStamp;
  uint256 public publicTGEEndBlockTimeStamp;

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


  uint256 public TRSOffset = 7 days;
  mapping (address => bool) private hasVested;

  mapping (address => uint256) public weiContributed;
  mapping (address => uint256) private reservedTokens;

  address[] private contributors;
  mapping (address => uint256) private contributorIndex;

  modifier whilePublicTGEIsActive() {
    require(block.timestamp <= publicTGEEndBlockTimeStamp);
    _;
  }

  // send ether to the fund collection fundsWallet
  // override to create custom fund forwarding mechanisms
  function forwardFunds() internal {
    fundsWallet.transfer(msg.value);
  }

  // @return true if the transaction can buy tokens
  function validPurchase() internal view returns (bool) {
    bool withinPeriod = block.timestamp >= publicTGEStartBlockTimeStamp && block.timestamp <= publicTGEEndBlockTimeStamp;
    bool nonZeroPurchase = msg.value != 0;
    return withinPeriod && nonZeroPurchase;
  }

  /**
   * @dev Transfer all Ether held by the contract to the address specified by owner.
   */
  function reclaimEther(address _beneficiary) external onlyOwner {
    assert(_beneficiary.send(this.balance));
  }

  function init(
    uint256 _rate,
    address _fundsWallet,
    uint256 _publicTGEStartBlockTimeStamp,
    uint256 _publicTGEEndBlockTimeStamp,
    uint256 _individualCap,
    uint256 _totalCap
  ) onlyOwner external returns(bool) {
    require(_publicTGEStartBlockTimeStamp >= block.timestamp);
    require(_publicTGEEndBlockTimeStamp >= _publicTGEStartBlockTimeStamp);
    require(_rate > 0);
    require(_fundsWallet != address(0));

    rate = _rate;
    fundsWallet = _fundsWallet;
    publicTGEStartBlockTimeStamp = _publicTGEStartBlockTimeStamp;
    publicTGEEndBlockTimeStamp = _publicTGEEndBlockTimeStamp;
    individualCap = _individualCap * precision;
    totalCap = _totalCap * precision;
    return true;
  }

  // fallback function can be used to buy tokens
  function () external payable {
    contribute();
  }

  // low level token purchase function
  function contribute() public whilePublicTGEIsActive payable {
    require(msg.sender != address(0));
    require(block.timestamp >= publicTGEStartBlockTimeStamp && validPurchase());
    // update state
    weiContributed[msg.sender] = weiContributed[msg.sender].add(msg.value);
    require(weiContributed[msg.sender] <= individualCap);
    if ((contributors.length == 0) || (contributorIndex[msg.sender] == 0 && contributors[0] != msg.sender)) {
        contributorIndex[msg.sender] = contributors.length;
        contributors.push(msg.sender);
    }
    weiRaised = weiRaised.add(msg.value);
    require(weiRaised <= totalCap);
    // calculate token amount to be created
    // Reserve LST for beneficiary
    uint256 tokens = msg.value.mul(rate);
    reservedTokens[msg.sender] = reservedTokens[msg.sender].add(tokens);
    forwardFunds();
  }

  // Vesting logic
  // The following cases are checked for _beneficiary's actions:
  // 1. Had chosen not to vest previously, and chooses not to vest now
  // 2. Had chosen not to vest previously, and chooses to vest now
  // 3. Had chosen to vest previously, and chooses not to vest now
  // 4. Had chosen to vest previously, and chooses to vest now
  // 2 & 3 are valid cases
  // 1 and 4 are invalid because they are double-vesting actions
  function vest(bool _vestingDecision) external returns(bool) {
    bool existingDecision = hasVested[msg.sender];
    // Prevent double vesting
    if (existingDecision) {
      require(!_vestingDecision);
    }
    if (!existingDecision) {
      require(_vestingDecision);
    }
    // Ensure vesting cannot be done once TRS starts
    if (block.timestamp > publicTGEEndBlockTimeStamp) {
      require(block.timestamp.sub(publicTGEEndBlockTimeStamp) <= TRSOffset);
    }
    hasVested[msg.sender] = _vestingDecision;
    return true;
  }

  function getTotalContributors() external view returns(uint256) {
      return contributors.length;
  }

}
