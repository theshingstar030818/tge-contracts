pragma solidity ^0.4.18;

import "zeppelin-solidity/contracts/math/SafeMath.sol";
import "zeppelin-solidity/contracts/ownership/Ownable.sol";
import "zeppelin-solidity/contracts/token/ERC20/SafeERC20.sol";
import "./SimpleBountyAllocation.sol";
import "./LendroidSupportToken.sol";

/**
 * @title SimpleSyndicatorLSTDistribution
 * @dev SimpleSyndicatorLSTDistribution contract provides interface for the contributor to withdraw their allocations / initiate the vesting contract
 */
 contract SimpleBountyLSTDistribution is Ownable {
  using SafeMath for uint256;
  using SafeERC20 for LendroidSupportToken;

  SimpleBountyAllocation public SimpleBountyAllocationContract;
  LendroidSupportToken public token;

  bool public withdrawalActivated = false;

  struct allocation {
    uint256 LSTAllocated;
    bool hasWithdrawn;
  }
  // maps all allocations claimed by contributors
  mapping (address => allocation)  public allocations;

  /**
   * event for token transfer logging
   * @param beneficiary who is receiving the tokens
   * @param tokens amount of tokens given to the beneficiary
   */
  event LogLSTsWithdrawn(address beneficiary, uint256 tokens);

  function SimpleBountyLSTDistribution(
      address _SimpleBountyAllocationAddress,
      address _LSTAddress
    ) public {
    require(_SimpleBountyAllocationAddress != address(0));
    token = LendroidSupportToken(_LSTAddress);
    SimpleBountyAllocationContract = SimpleBountyAllocation(_SimpleBountyAllocationAddress);
  }

  // member function that can be called to release vested tokens periodically
  function releaseTokens(address beneficiary) public {
    require(beneficiary != 0x0);
    require(!allocations[beneficiary].hasWithdrawn);
    assert(withdrawalActivated);
    uint256 _LSTPurchased = SimpleBountyAllocationContract.contributions(beneficiary);
    allocations[beneficiary].hasWithdrawn = true;
    allocations[beneficiary].LSTAllocated = _LSTPurchased;
    token.safeTransfer(beneficiary, _LSTPurchased);
    LogLSTsWithdrawn(beneficiary, _LSTPurchased);
  }

  function escapeHatch() onlyOwner external {
    assert(token.transfer(owner, token.balanceOf(this)));
  }

  function activateWithdrawal() onlyOwner external {
    withdrawalActivated = true;
  }

}
