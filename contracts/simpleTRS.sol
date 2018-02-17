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

contract simpleTRS is Ownable {

  struct Allocation {
    // total LST allocated for the participant
    uint256 LSTAllocated;
    // total LST remaining to be withdrawn
    uint256 LSTBalance;
    bool vested;
  }
  mapping (address => Allocation[]) private allocations;
  bool allocationsLocked;

  uint256[] listOfCliffs = [1518667210,1518753610,1518840010,1518926410];
  uint256[] releaseSchedules = [25,50,75,100];

  function simpleTRS(){
    allocationsLocked = false;
  }

  function disableAllocationModificationsForEver() external onlyOwner returns(bool) {
    allocationsLocked = true;
  }

  function modifyAllocations(address[] addrs,uint256[] amounts, bool[] vested) external onlyOwner returns(bool) {
    require(!allocationsLocked);
    require(addrs.length <= 100);
    require(addrs.length == amounts.length);
    require(addrs.length == vested.length);

    for (uint i=0; i<addrs.length; i++) {
      require(addrs[i] != address(0));
      require(amounts[i] != 0);
      allocations[addrs[i]].LSTAllocated = amounts[i];
      allocations[addrs[i]].LSTBalance = amounts[i];
      allocations[addrs[i]].vested = vested[i];
    }
    return true;
  }

  function currentVestedPercentage(){
    for (uint i=0; i<listOfCliffs.length; i++) {
      if (now<listOfCliffs[i]){
        if (i==0){
          return 0;
        }
        return releaseSchedules[i-1];
      }
    }
  }


  function withdraw(uint256 amount){
    require(allocationsLocked);

    if (!allocations[msg.sender].vested){
      require(allocations[msg.sender].LSTBalance >= amount);
      allocations[msg.sender].LSTBalance = allocations[msg.sender].LSTBalance.sub(amount);
        // transfer LST
      }
    }
    else{
      uint256 availableAllocatedBalance = currentVestedPercentage().mul(allocations[msg.sender].LSTAllocated).div(100);
      uint256 availableWithdrawableBalance = availableAllocatedBalance.sub( allocations[msg.sender].LSTAllocated.sub(allocations[msg.sender].LSTBalance) )

      require(availableWithdrawableBalance >= amount);
      allocations[msg.sender].LSTBalance = allocations[msg.sender].LSTBalance.sub(amount);
      // transfer LST

    }



}
