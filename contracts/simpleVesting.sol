pragma solidity ^0.4.18;

import "./dependencies/MintableToken.sol";
import "./dependencies/PausableToken.sol";
import "./dependencies/SafeMath.sol";
import "./dependencies/Ownable.sol";
import "./dependencies/TokenVesting.sol";

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
    totalSupply = MAX_SUPPLY;
  }
}


/**
 * @title simpleLSTVesting
 * @dev simpleLSTVesting contract creates LendroidSupportToken and
 * provides interface for the owner to mint tokens to appropriate share holders.
 */
contract simpleLSTVesting is Ownable {
  using SafeMath for uint256;

  // The token being minted.
  LendroidSupportToken public token;

  // map of address to token vesting contract
  mapping (address => TokenVesting) public vesting;

  /**
   * event for token mint logging
   * @param beneficiary who is receiving the tokens
   * @param tokens amount of tokens given to the beneficiary
   */
  event LSTsMinted(address beneficiary, uint256 tokens);

  /**
   * event for time vested token mint logging
   * @param beneficiary who is receiving the time vested tokens
   * @param tokens amount of tokens that will be vested to the beneficiary
   * @param start unix timestamp at which the tokens will start vesting
   * @param cliff duration in seconds after start time at which vesting will start
   * @param duration total duration in seconds in which the tokens will be vested
   */
  event timeVestingLSTsMinted(address beneficiary, uint256 tokens, uint256 start, uint256 cliff, uint256 duration);

  /**
   * event for air drop token mint loggin
   * @param beneficiary who is receiving the airdrop tokens
   * @param tokens airdropped
   */
  event airdropLSTsMinted(address beneficiary, uint256 tokens);

  /**
   * @dev Creates a new simpleLSTVesting contract
   */
  function simpleLSTVesting() public {
    token = new LendroidSupportToken();
  }

  // member function to mint tokens to a beneficiary
  function mintTokens(address beneficiary, uint256 tokens) public onlyOwner {
    require(beneficiary != 0x0);
    require(tokens > 0);

    require(token.mint(beneficiary, tokens));
    LSTsMinted(beneficiary, tokens);
  }

  // member function to mint time based vesting tokens to a beneficiary
  function mintTokensWithTimeBasedVesting(address beneficiary, uint256 tokens, uint256 start, uint256 cliff, uint256 duration) public onlyOwner {
    require(beneficiary != 0x0);
    require(tokens > 0);

    vesting[beneficiary] = new TokenVesting(beneficiary, start, cliff, duration, false);
    require(token.mint(address(vesting[beneficiary]), tokens));

    timeVestingLSTsMinted(beneficiary, tokens, start, cliff, duration);
  }

  function mintAirDropTokens(uint256 tokens, address[] addresses) public onlyOwner {
    require(tokens > 0);
    for (uint256 i = 0; i < addresses.length; i++) {
      require(token.mint(addresses[i], tokens));
      airdropLSTsMinted(addresses[i], tokens);
    }
  }

  // member function to finish the minting process
  function finishAllocation() public onlyOwner {
    require(token.finishMinting());
  }

  // member function that can be called to release vested tokens periodically
  function releaseVestedTokens(address beneficiary) public {
    require(beneficiary != 0x0);

    TokenVesting tokenVesting = vesting[beneficiary];
    tokenVesting.release(token);
  }

  // transfer token ownership after allocation
  function transferTokenOwnership(address owner) public onlyOwner {
    require(token.mintingFinished());
    token.transferOwnership(owner);
  }
}
