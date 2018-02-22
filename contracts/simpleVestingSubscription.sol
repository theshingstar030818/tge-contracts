pragma solidity ^0.4.17;

import "zeppelin-solidity/contracts/ownership/Ownable.sol";


/**
 * @title SimpleVestingSubscription
 * @dev The SimpleVestingSubscription contract receives vesting decision from people
 * who have contributed non-ETH to the TGE. The allocations are received seperately
 * this contracts verifies two things:
 * that the  contributor have control of their address
 * the contributors vesting preference recorded.
**/
contract SimpleVestingSubscription is Ownable {

  // start and end timestamps (both inclusive) when TRS subscription is open
  uint256 public TRSSubscriptionStartBlockTimeStamp;

  uint256 public TRSSubscriptionEndBlockTimeStamp;


  address[] public contributors;
  struct Contribution {
    bool hasVested;
    bool verified;
  }

  mapping (address => Contribution)  public contributions;

  /**
   * @dev Transfer all Ether held by the contract to the address specified by owner.
   */
  function reclaimEther(address _beneficiary) external onlyOwner {
    _beneficiary.transfer(this.balance);
  }

  function getContributorsCount() public constant returns(uint count) {
    return contributors.length;
  }

  function SimpleVestingSubscription(uint256 _TRSSubscriptionStartBlockTimeStamp,uint256 _TRSSubscriptionEndBlockTimeStamp) public {
    require(_TRSSubscriptionStartBlockTimeStamp >= block.timestamp);
    require(_TRSSubscriptionEndBlockTimeStamp >= _TRSSubscriptionStartBlockTimeStamp);
    TRSSubscriptionStartBlockTimeStamp = _TRSSubscriptionStartBlockTimeStamp;
    TRSSubscriptionEndBlockTimeStamp = _TRSSubscriptionEndBlockTimeStamp;
  }

  function vestOrNot(bool _vestingDecision) internal {
    require(block.timestamp >= TRSSubscriptionStartBlockTimeStamp);
    require(block.timestamp <= TRSSubscriptionEndBlockTimeStamp);
    if (!contributions[msg.sender].verified){
      contributors.push(msg.sender);
    }
    contributions[msg.sender].hasVested = _vestingDecision;
    contributions[msg.sender].verified = true;

  }

  function optInToVesting() external returns(bool) {
    vestOrNot(true);
    return true;
  }

  function optOutOfVesting() external returns(bool) {
    vestOrNot(false);
    return true;
  }


}
