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

contract SimpleVestingSubscription is Ownable {
  using SafeMath for uint256;

  // start and end timestamps (both inclusive) when sale is open
  uint256 public publicTGEStartBlockTimeStamp;

  uint256 public publicTGEEndBlockTimeStamp;

  // how long the TRS subscription is open after the TGE.
  uint256 public TRSOffset = 5 days;

  address[] public contributors;
  struct Contribution {
    bool hasVested;
  }
  mapping (address => Contribution)  public contributions;

  /**
   * @dev Transfer all Ether held by the contract to the address specified by owner.
   */
  function reclaimEther(address _beneficiary) external onlyOwner {
    _beneficiary.transfer(this.balance);
  }

  function SimpleVestingSubscription (uint256 _publicTGEStartBlockTimeStamp,uint256 _publicTGEEndBlockTimeStamp) {
    require(_publicTGEStartBlockTimeStamp >= block.timestamp);
    require(_publicTGEEndBlockTimeStamp >= _publicTGEStartBlockTimeStamp);
    publicTGEStartBlockTimeStamp = _publicTGEStartBlockTimeStamp;
    publicTGEEndBlockTimeStamp = _publicTGEEndBlockTimeStamp;
  }

  // Vesting logic
  // The following cases are checked for _beneficiary's actions:
  function vest(bool _vestingDecision) external returns(bool) {
    bool existingDecision = contributions[msg.sender].hasVested;
    require(existingDecision != _vestingDecision);
    require(block.timestamp >= publicTGEStartBlockTimeStamp);
    // Ensure vesting cannot be done once TRS starts
    if (block.timestamp > publicTGEEndBlockTimeStamp) {
      require(block.timestamp.sub(publicTGEEndBlockTimeStamp) <= TRSOffset);
    }
    contributions[msg.sender].hasVested = _vestingDecision;
    return true;
  }
}
