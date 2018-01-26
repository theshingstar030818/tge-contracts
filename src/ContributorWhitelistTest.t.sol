pragma solidity ^0.4.17;

import "ds-test/test.sol";
import "./base.sol";
import "./tge.sol";


contract ColdWallet {
  // Wallet contract to accept payment
  function() payable public {}
}


contract ContributorWhitelistTest is DSTest {
    ContributorWhitelist whitelist;

    function setUp() public {
        whitelist = new ContributorWhitelist();
    }

    function test_OnlyOwnerOrCrowdTGEContract() public {
      LendroidSupportToken LST = new LendroidSupportToken();
      ColdWallet ColdStorageWallet = new ColdWallet();
      uint256 saleStartTimestamp = now;
      uint256 saleEndTimestamp = now + 10 days;
      TGE tge = new TGE();
      tge.init(
        address(LST),
        24000,
        address(ColdStorageWallet),
        address(whitelist),
        saleStartTimestamp,
        saleEndTimestamp
      );
      // Assert owner is current contract
      assertEq(
        whitelist.owner(),
        this
      );
      // link PrivateTGE to Whitelist
      whitelist.setAuthority(address(tge));
      assertTrue(
        whitelist.authorized(address(tge))
      );
    }

    function test_whitelistAddress() public {
      assertTrue(
        !whitelist.isWhitelisted(address(this))
      );
      whitelist.whitelistAddress(this);
      assertTrue(
        whitelist.isWhitelisted(address(this))
      );
    }

    function test_blacklistAddress() public {
      assertTrue(
        !whitelist.isWhitelisted(address(this))
      );
      whitelist.whitelistAddress(this);
      assertTrue(
        whitelist.isWhitelisted(address(this))
      );
      whitelist.blacklistAddress(this);
      assertTrue(
        !whitelist.isWhitelisted(address(this))
      );
    }

}
