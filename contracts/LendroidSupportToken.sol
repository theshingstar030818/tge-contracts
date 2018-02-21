pragma solidity ^0.4.18;

import "zeppelin-solidity/contracts/token/ERC20/MintableToken.sol";
import "zeppelin-solidity/contracts/token/ERC20/PausableToken.sol";


contract LendroidSupportToken is MintableToken, PausableToken {

  address ownerContract;

  string public constant name = "Lendroid Support Token";
  string public constant symbol = "LST";
  uint256 public constant decimals = 18;

  uint256 public constant MAX_SUPPLY = 12000000000 * (10 ** uint256(decimals));// 12 billion tokens, 18 decimal places

  /**
   * @dev Throws if called by any account other than the owner.
   */
  modifier onlyOwnerOrContractOwner() {
    require((msg.sender == owner) || ((ownerContract != address(0)) && (msg.sender == ownerContract)));
    _;
  }

  function setOwnerContract(address contractAddress) external onlyOwner returns(bool) {
    ownerContract = contractAddress;
    return true;
  }

  /**
   * @dev Constructor that pauses tradability of tokens.
   */
  function LendroidSupportToken() public {
    paused = true;
    totalSupply_ = MAX_SUPPLY;
  }

  /**
   * @dev Function to mint tokens
   * @param _to The address that will receive the minted tokens.
   * @param _amount The amount of tokens to mint.
   * @return A boolean that indicates if the operation was successful.
   */
  function mint(address _to, uint256 _amount) onlyOwnerOrContractOwner canMint public returns (bool) {
    totalSupply_ = totalSupply_.add(_amount);
    balances[_to] = balances[_to].add(_amount);
    Mint(_to, _amount);
    Transfer(address(0), _to, _amount);
    return true;
  }
}
