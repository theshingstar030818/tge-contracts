pragma solidity ^0.4.17;

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
