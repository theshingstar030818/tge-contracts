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


 contract PausableDestructible is Ownable{

   event Pause();
   event Unpause();

   bool public paused = false;

   /**
    * @dev Modifier to make a function callable only when the contract is not paused.
    */
   modifier whenNotPaused() {
     require(!paused);
     _;
   }

   /**
    * @dev Modifier to make a function callable only when the contract is paused.
    */
   modifier whenPaused() {
     require(paused);
     _;
   }

   /**
    * @dev called by the owner to pause, triggers stopped state
    */
   function pause() onlyOwner whenNotPaused external {
     paused = true;
     Pause();
   }

   /**
    * @dev called by the owner to unpause, returns to normal state
    */
   function unpause() onlyOwner whenPaused external {
     paused = false;
     Unpause();
   }

   /**
    * @dev Transfers the current balance to the owner and terminates the contract.
    */
   function reclaimEtherOrDestroy(bool _destroy) external onlyOwner whenPaused returns(bool) {
     if (_destroy) {
       selfdestruct(owner);
       return true;
     }
     /* else {
       owner.transfer(this.balance);
       return true;
     } */
     return false;
   }

 }




contract PausableDestructibleHasNoEther is PausableDestructible {

   /**
   * @dev Constructor that rejects incoming Ether
   * @dev The `payable` flag is added so we can access `msg.value` without compiler warning. If we
   * leave out payable, then Solidity will allow inheriting contracts to implement a payable
   * constructor. By doing it this way we prevent a payable constructor from working. Alternatively
   * we could use assembly to access msg.value.
   */
   function PausableDestructibleHasNoEther() public payable {
     require(msg.value == 0);
   }

   /**
    * @dev Disallows direct send by settings a default function without the `payable` flag.
    */
   function() external {}

}


contract ContributorWhitelist is PausableDestructibleHasNoEther {

  SimpleTGE public TGEContract;

  mapping (address => bool) public whitelist;

  modifier onlyOwnerOrTGE() {
    require((msg.sender == owner) || ((address(TGEContract) != 0) && (msg.sender == address(TGEContract))));
    _;
  }

  function setTGEContract(address _address) onlyOwner external returns(bool) {
      TGEContract = SimpleTGE(_address);
      return true;
  }

  function whitelistAddress(address _address) external onlyOwner returns(bool) {
    whitelist[_address] = true;
    return true;
  }

  function blacklistAddress(address _address) external onlyOwner returns(bool) {
    whitelist[_address] = false;
    return true;
  }

  function bulkWhitelistAddresses(address[] addrs) external onlyOwner returns(bool) {
    require(addrs.length <= 100);
    for (uint i=0; i<addrs.length; i++) {
      whitelist[addrs[i]] = true;
    }
    return true;
  }

  function isWhitelisted(address _address) external onlyOwnerOrTGE view returns(bool) {
    return whitelist[_address];
  }

}



contract SimpleTGE is Ownable {
  using SafeMath for uint256;

  // start and end timestamps (both inclusive) when sale is open
  uint256 public publicTGEStartBlockTimeStamp;
  uint256 public publicTGEEndBlockTimeStamp;

  // address where funds are collected
  address public fundsWallet;

  // amount of raised money in wei
  uint256 public weiRaised;

  // sale cap in wei
  uint256 public totalCapInWei;

  // individual cap in wei
  uint256 public individualCapInWei;

  // contract that holds the whitelisted address
  ContributorWhitelist public whitelist;

  uint256 public TRSOffset = 7 days;


  address[] public contributors;
  struct Contribution {
    bool hasVested;
    uint256 weiContributed;
  }
  mapping (address => Contribution)  public contributions;


  modifier whilePublicTGEIsActive() {
    require(block.timestamp >= publicTGEStartBlockTimeStamp && block.timestamp <= publicTGEEndBlockTimeStamp);

    _;
  }


  function setWhitelist(address _address) onlyOwner external returns (bool) {
    whitelist = ContributorWhitelist(_address);
    return true;
  }



  /**
   * @dev Transfer all Ether held by the contract to the address specified by owner.
   */
  function reclaimEther(address _beneficiary) external onlyOwner {
    _beneficiary.transfer(this.balance);
  }

  function SimpleTGE (address _fundsWallet,uint256 _publicTGEStartBlockTimeStamp,uint256 _publicTGEEndBlockTimeStamp,uint256 _individualCapInWei,uint256 _totalCapInWei) {
    require(_publicTGEStartBlockTimeStamp >= block.timestamp);
    require(_publicTGEEndBlockTimeStamp >= _publicTGEStartBlockTimeStamp);
    require(_fundsWallet != address(0));
    require(_individualCapInWei > 0);
    require(_totalCapInWei > 0);

    fundsWallet = _fundsWallet;
    publicTGEStartBlockTimeStamp = _publicTGEStartBlockTimeStamp;
    publicTGEEndBlockTimeStamp = _publicTGEEndBlockTimeStamp;
    individualCapInWei = _individualCapInWei;
    totalCapInWei = _totalCapInWei;
  }

  // allows changing the individual cap.
  function changeindividualCapInWei(uint256 _individualCapInWei) onlyOwner external returns(bool) {
      require(_individualCapInWei > 0);
      individualCapInWei = _individualCapInWei;
      return true;
  }



  // low level token purchase function
  function contribute(bool _vestingDecision) internal{
    //validations
    require(msg.sender != address(0));
    require(msg.value != 0);
    require(whitelist.isWhitelisted(msg.sender));
    require(weiRaised  + msg.value <= totalCapInWei);
    require(contributions[msg.sender].weiContributed  + msg.value <= individualCapInWei);


    if ((contributors.length == 0) || (contributors[0] != msg.sender)) {
        contributors.push(msg.sender);
    }

    contributions[msg.sender].weiContributed = contributions[msg.sender].weiContributed.add(msg.value);

    weiRaised = weiRaised.add(msg.value);
    contributions[msg.sender].hasVested = _vestingDecision;
    fundsWallet.transfer(msg.value);
  }

  function contributeAndVest() external whilePublicTGEIsActive payable {
    bool _vestingDecision = true;
    contribute(_vestingDecision);
  }

  function contributeWithoutVesting() public whilePublicTGEIsActive payable {
    bool _vestingDecision = false;
    contribute(_vestingDecision);
  }

  // fallback function can be used to buy tokens
  function () external payable {
    contributeWithoutVesting();
  }
  // Vesting logic
  // The following cases are checked for _beneficiary's actions:
  function vest(bool _vestingDecision) external returns(bool) {
    bool existingDecision = contributions[msg.sender].hasVested;
    require(existingDecision != _vestingDecision);
    // Ensure vesting cannot be done once TRS starts
    if (block.timestamp > publicTGEEndBlockTimeStamp) {
      require(block.timestamp.sub(publicTGEEndBlockTimeStamp) <= TRSOffset);
    }
    contributions[msg.sender].hasVested = _vestingDecision;
    return true;
  }

}
