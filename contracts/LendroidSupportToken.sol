pragma solidity ^0.4.18;

import "zeppelin-solidity/contracts/token/ERC20/MintableToken.sol";
import "zeppelin-solidity/contracts/token/ERC20/PausableToken.sol";


contract LendroidSupportToken is MintableToken, PausableToken {

  string public constant name = "Lendroid Support Token";
  string public constant symbol = "LST";
  uint256 public constant decimals = 18;
  uint256 public constant MAX_SUPPLY = 12000000000 * (10 ** uint256(decimals));// 12 billion tokens, 18 decimal places

  /**
   * @dev Constructor that pauses tradability of tokens.
   */
  function LendroidSupportToken() public {
    paused = true;
  }


  /**
   * @dev totalSupply is set via the minting process
   */

  function mint(address to, uint256 amount) onlyOwner public returns (bool) {
    require(totalSupply_ + amount <= MAX_SUPPLY);
    return super.mint(to, amount);
  }

}
