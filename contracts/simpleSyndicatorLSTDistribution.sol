pragma solidity ^0.4.18;

import "zeppelin-solidity/contracts/math/SafeMath.sol";
import "zeppelin-solidity/contracts/ownership/Ownable.sol";
import "zeppelin-solidity/contracts/token/ERC20/TokenVesting.sol";
import "./SimpleSyndicatorPreTGE.sol";
import "./LendroidSupportToken.sol";

/**
 * @title SimpleSyndicatorLSTDistribution
 * @dev SimpleSyndicatorLSTDistribution contract provides interface for the contributor to withdraw their allocations / initiate the vesting contract
 */
contract simpleSyndicatorLSTDistribution is Ownable {
  using SafeMath for uint256;

  SimpleSyndicatorPreTGE public SimpleSyndicatorPreTGEContract;
  LendroidSupportToken public token;
  //vesting related params
  // bonus multiplied to every vesting contributor's allocation
  uint256 public vestingBonusMultiplier;
  uint256 public vestingBonusMultiplierPrecision = 1000000;
  uint256 public vestingDuration;
  uint256 public vestingStartTime;

  struct allocation {
    bool shouldVest;
    uint256 LSTAllocated;
    bool hasWithdrawn;
  }
  // maps all allocations claimed by contributors
  mapping (address => allocation)  public allocations;

  // map of address to token vesting contract
  mapping (address => TokenVesting) public vesting;

  /**
   * event for token transfer logging
   * @param beneficiary who is receiving the tokens
   * @param tokens amount of tokens given to the beneficiary
   */
  event LogLSTsWithdrawn(address beneficiary, uint256 tokens);

  /**
   * event for time vested token transfer logging
   * @param beneficiary who is receiving the time vested tokens
   * @param tokens amount of tokens that will be vested to the beneficiary
   * @param start unix timestamp at which the tokens will start vesting
   * @param cliff duration in seconds after start time at which vesting will start
   * @param duration total duration in seconds in which the tokens will be vested
   */
  event LogTimeVestingLSTsWithdrawn(address beneficiary, uint256 tokens, uint256 start, uint256 cliff, uint256 duration);

  function SimpleSyndicatorLSTDistribution(
      address _SimpleSyndicatorPreTGEAddress,
      uint256 _vestingBonusMultiplier,
      uint256 _vestingDuration,
      uint256 _vestingStartTime,
      address _LSTAddress
    ) public {

    require(_SimpleSyndicatorPreTGEAddress != address(0));
    require(_vestingBonusMultiplier >= 1000000);
    require(_vestingBonusMultiplier <= 10000000);
    require(_vestingDuration > 0);
    require(_vestingStartTime > block.timestamp);

    token = LendroidSupportToken(_LSTAddress);
    // token = new LendroidSupportToken();

    SimpleSyndicatorPreTGEContract = SimpleSyndicatorPreTGE(_SimpleSyndicatorPreTGEAddress);
    vestingBonusMultiplier = _vestingBonusMultiplier;
    vestingDuration = _vestingDuration;
    vestingStartTime = _vestingStartTime;
  }

  function withdraw() external {
    require(!allocations[msg.sender].hasWithdrawn);
    // allocations should be locked in the pre-TGE
    require(SimpleSyndicatorPreTGEContract.allocationsLocked());
    bool _shouldVest;
    uint256 _LSTPurchased;
    (_shouldVest, _LSTPurchased) = SimpleSyndicatorPreTGEContract.contributions(msg.sender);
    allocations[msg.sender].hasWithdrawn = true;
    allocations[msg.sender].shouldVest = _shouldVest;
    uint256 _lstAllocated;
    if (!_shouldVest) {
      allocations[msg.sender].LSTAllocated = _LSTPurchased;

      token.safeTransfer(msg.sender, _lstAllocated);
      //require(token.mint(msg.sender, _lstAllocated));

      LogLSTsWithdrawn(msg.sender, _lstAllocated);
    }
    else {
      _lstAllocated = _LSTPurchased.mul(vestingBonusMultiplier).div(vestingBonusMultiplierPrecision);
      allocations[msg.sender].LSTAllocated = _lstAllocated;
      uint256 _withdrawNow = _lstAllocated.div(10);
      uint256 _vestedPortion = _lstAllocated.sub(_withdrawNow);
      vesting[msg.sender] = new TokenVesting(msg.sender, vestingStartTime, 0, vestingDuration, false);

      token.safeTransfer(msg.sender, _withdrawNow);
      //require(token.mint(msg.sender, _withdrawNow));
      LogLSTsWithdrawn(msg.sender, _withdrawNow);
      //require(token.mint(address(vesting[msg.sender]), _vestedPortion));
      LogTimeVestingLSTsWithdrawn(address(vesting[msg.sender]), _vestedPortion, vestingStartTime, 0, vestingDuration);

    }
  }

  // member function that can be called to release vested tokens periodically
  function releaseVestedTokens(address beneficiary) public {
    require(beneficiary != 0x0);

    TokenVesting tokenVesting = vesting[beneficiary];
    tokenVesting.release(token);
  }

  function escapeHatch() onlyOwner external {
    token.safeTransfer(owner, token.balanceOf(this));
  }


}
