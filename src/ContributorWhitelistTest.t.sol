pragma solidity ^0.4.17;

import "ds-test/test.sol";
import "./base.sol";
import "./tge.sol";


contract Wallet {
  // Wallet contract to accept payment
  function() payable public {}
}


contract ContributorWhitelistTest is DSTest {
    ContributorWhitelist whitelist;

    function setUp() public {
        whitelist = new ContributorWhitelist();
    }


    function test_OnlyOwnerOrCrowdSaleContract() public {
      LendroidSupportToken LST = new LendroidSupportToken();
      Wallet ColdStorageWallet = new Wallet();
      PrivateSale sale = new PrivateSale(
        address(LST),
        24000,
        address(ColdStorageWallet),
        address(whitelist)
      );
      // Assert owner is current contract
      assertEq(
        whitelist.owner(),
        this
      );
      // link PrivateSale to Whitelist
      whitelist.setSaleContractAddress(address(sale));
      assertEq(
        whitelist.saleContract(),
        address(sale)
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
