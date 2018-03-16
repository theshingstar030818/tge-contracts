pragma solidity ^0.4.17;

import "zeppelin-solidity/contracts/ownership/Ownable.sol";

contract SimpleSyndicatorPreTGE is Ownable {

  struct Contribution {
    bool hasVested;
    uint256 LSTPurchased;
  }
  mapping (address => Contribution)  public contributions;

  function reserveTokensForAddress(address addr_, uint256 LSTPurchased_, bool vestingDecision_) onlyOwner external returns(bool) {
    contributions[addr_].LSTPurchased = LSTPurchased_;
    contributions[addr_].hasVested = vestingDecision_;
    return true;
  }

  function bulkReserveTokensForAddresses(address[] addrs, uint256[] LSTPurchases, bool[] _vestingDecisions) onlyOwner external returns(bool) {
    require((addrs.length == LSTPurchases.length) && (addrs.length == _vestingDecisions.length));
    for (uint i=0; i<addrs.length; i++) {
      require(contributions[addrs[i]].LSTPurchased == 0);
      contributions[addrs[i]].LSTPurchased = LSTPurchases[i];
      contributions[addrs[i]].hasVested = _vestingDecisions[i];
    }
    return true;
  }

}
