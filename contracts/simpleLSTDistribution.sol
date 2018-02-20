pragma solidity ^0.4.18;

import "./dependencies/MintableToken.sol";
import "./dependencies/PausableToken.sol";
import "./dependencies/SafeMath.sol";
import "./dependencies/Ownable.sol";
import "./dependencies/TokenVesting.sol";
import "./SimpleTGE.sol";
import "./SimplePreTGE.sol";
import "./LendroidSupportToken.sol";

/**
 * @title simpleLSTDistribution
 * @dev simpleLSTDistribution contract provides interface for the contributor to withdraw their allocations / initiate the vesting contract
 */
contract simpleLSTDistribution is Ownable {
  using SafeMath for uint256;

  SimplePreTGE public SimplePreTGEContract;
  SimpleTGE public SimpleTGEContract;
  LendroidSupportToken public token;
  uint256 LSTRatePerWEI;
  //vesting related params
  // bonus multiplied to every vesting contributor's allocation
  uint256 vestingBonusMultiplier;
  uint256 vestingDuration;
  uint256 vestingStartTime;
  LendroidSupportToken public token;

  struct allocation {
    bool hasVested;
    uint256 weiContributed;
    uint256 LSTAllocated;
    bool hasWithdrawn;
  }
  // maps all allocations claimed by contributors
  mapping (address => bool)  public allocations;

  // map of address to token vesting contract
  mapping (address => TokenVesting) public vesting;

  /**
   * event for token transfer logging
   * @param beneficiary who is receiving the tokens
   * @param tokens amount of tokens given to the beneficiary
   */
  event LSTsWithdrawn(address beneficiary, uint256 tokens);

  /**
   * event for time vested token transfer logging
   * @param beneficiary who is receiving the time vested tokens
   * @param tokens amount of tokens that will be vested to the beneficiary
   * @param start unix timestamp at which the tokens will start vesting
   * @param cliff duration in seconds after start time at which vesting will start
   * @param duration total duration in seconds in which the tokens will be vested
   */
  event timeVestingLSTsWithdrawn(address beneficiary, uint256 tokens, uint256 start, uint256 cliff, uint256 duration);


  function withdraw(){
    require(!allocations[msg.sender].hasWithdrawn)
    // should have participated in the TGE or the pre-TGE
    require(SimpleTGEContract.contributions[msg.sender].weiContributed.add(SimplePreTGEContract.contributions[msg.sender].weiContributed) > 0);
    // make sure simpleTGE is over and the TRS subscription has ended
    require(block.timestamp > SimpleTGEContract.publicTGEEndBlockTimeStamp.add(SimpleTGEContract.TRSOffset));
    // allocations should be locked in the pre-TGE
    require(SimplePreTGEContract.allocationsLocked);

    // the same contributor could have contributed in the pre-tge and the tge, so we add the contributions.
    uint256 _totalWeiContribution = SimpleTGEContract.contributions[msg.sender].weiContributed.add(SimplePreTGEContract.contributions[msg.sender].weiContributed);
    // if the vesting decision is "yes" in any of the contracts, the contributor is vested.
    bool _vestingDecision = SimpleTGEContract.contributions[msg.sender].weiContributed || SimplePreTGEContract.contributions[msg.sender].weiContributed;

    allocations[msg.sender].hasWithdrawn = true;
    allocations[msg.sender].hasVested = _vestingDecision;
    allocations[msg.sender].weiContributed = _totalWeiContribution;

    if (!_vestingDecision){
      uint256 _lstAllocated = LSTRatePerETH.mul(_totalWeiContribution).mul(vestingBonusMultiplier);
      allocations[msg.sender].LSTAllocated = _lstAllocated;
      require(token.transfer(msg.sender, tokens));
      LSTsWithdrawn(beneficiary, tokens);
    }
    else{
      uint256 _lstAllocated = LSTRatePerETH.mul(_totalWeiContribution);
      allocations[msg.sender].LSTAllocated = _lstAllocated;

      uint256 _withdrawNow = _lstAllocated.div(10);
      uint256 _vestedPortion = _lstAllocated.sub(_withdrawNow);

      vesting[msg.sender] = new TokenVesting(msg.sender, vestingStartTime, vestingStartTime, vestingDuration, false);

      require(token.transfer(msg.sender, _withdrawNow));
      LSTsWithdrawn(beneficiary, _withdrawNow);
      require(token.transfer(address(vesting[msg.sender]), _vestedPortion));
      timeVestingLSTsWithdrawn(msg.sender, _vestedPortion, vestingStartTime, vestingStartTime, vestingDuration);

    }
  }

  function simpleLSTDistribution(_SimplePreTGEContract,_SimpleTGE, _LSTTokenAddress,_vestingDuration,_vestingStartTime) public {
    SimplePreTGEContract = _SimplePreTGEContract;
    SimpleTGE = _SimpleTGE;
    token = _LSTTokenAddress
    vestingBonusMultiplier = _vestingBonusMultiplier;
    vestingDuration = _vestingDuration;
    vestingStartTime = _vestingStartTime;
  }

}
