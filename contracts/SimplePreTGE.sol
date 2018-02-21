pragma solidity ^0.4.17;

import "./dependencies/ownership/Ownable.sol";

contract SimplePreTGE is Ownable {

  bool public allocationsLocked;

  struct Contribution {
    bool hasVested;
    uint256 weiContributed;
  }
  mapping (address => Contribution)  public contributions;

  function disableAllocationModificationsForEver() external onlyOwner returns(bool) {
    allocationsLocked = true;
  }

  function bulkReserveTokensForAddresses(address[] addrs, uint256[] weiContributions, bool[] _vestingDecisions) onlyOwner external returns(bool) {
    require(!allocationsLocked);
    require((addrs.length == weiContributions.length) && (addrs.length == _vestingDecisions.length));
    for (uint i=0; i<addrs.length; i++) {
      contributions[addrs[i]].weiContributed = weiContributions[i];
      contributions[addrs[i]].hasVested = _vestingDecisions[i];
    }
    return true;
  }

}
