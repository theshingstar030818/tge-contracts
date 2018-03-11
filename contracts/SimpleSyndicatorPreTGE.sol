pragma solidity ^0.4.17;

import "zeppelin-solidity/contracts/ownership/Ownable.sol";

contract SimpleSyndicatorPreTGE is Ownable {

  bool public allocationsLocked;

  struct Contribution {
    bool hasVested;
    uint256 LSTPurchased;
  }
  mapping (address => Contribution)  public contributions;

  function disableAllocationModificationsForEver() external onlyOwner returns(bool) {
    allocationsLocked = true;
  }

  function bulkReserveTokensForAddresses(address[] addrs, uint256[] LSTPurchases, bool[] _vestingDecisions) onlyOwner external returns(bool) {
    require(!allocationsLocked);
    require((addrs.length == LSTPurchases.length) && (addrs.length == _vestingDecisions.length));
    for (uint i=0; i<addrs.length; i++) {
      contributions[addrs[i]].LSTPurchased = LSTPurchases[i];
      contributions[addrs[i]].hasVested = _vestingDecisions[i];
    }
    return true;
  }

}
