pragma solidity ^0.4.17;

import "zeppelin-solidity/contracts/ownership/Ownable.sol";

contract SimpleBountyAllocation is Ownable {

  struct Contribution {
    uint256 LSTPurchased;
  }
  mapping (address => Contribution)  public contributions;

  function reserveTokensForAddress(address addr_, uint256 LSTPurchased_) onlyOwner external returns(bool) {
    contributions[addr_].LSTPurchased = LSTPurchased_;
    return true;
  }

  function bulkReserveTokensForAddresses(address[] addrs, uint256[] LSTPurchases) onlyOwner external returns(bool) {
    require(addrs.length == LSTPurchases.length);
    for (uint i=0; i<addrs.length; i++) {
      require(contributions[addrs[i]].LSTPurchased == 0);
      contributions[addrs[i]].LSTPurchased = LSTPurchases[i];
    }
    return true;
  }

}
