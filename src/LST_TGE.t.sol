pragma solidity ^0.4.17;

import "ds-test/test.sol";
import "./base.sol";
import "./tge.sol";


contract User {}

contract Wallet {
  // Wallet contract to accept payment
  function() payable public {}
}


contract LST_TGE is DSTest {
    /*contracts*/
    User TestUser;
    Wallet ColdStorageWallet;
    LendroidSupportToken LST;
    ContributorWhitelist Whitelist;
    PrivateSale Sale;

    function setUp() public {
        // deploy TestUser
        TestUser = new User();
        // deploy ColdStorageWallet
        ColdStorageWallet = new Wallet();
        // deploy whitelist
        Whitelist = new ContributorWhitelist();
        // deploy LST
        LST = new LendroidSupportToken();
        // confirm owner has 3.6b LST
        assertEq(
          LST.balanceOf(this),
          3600000000000000000000000000
        );
        // TRANSFER 3.6B lST to ColdStorageWallet
        LST.transfer(address(ColdStorageWallet),3600000000000000000000000000);
        // confirm ColdStorageWallet has 3.6b lST
        assertEq(
          LST.balanceOf(address(ColdStorageWallet)),
          3600000000000000000000000000
        );
        // confirm owner has 0 lST now
        assertEq(
          LST.balanceOf(this),
          0
        );
        // pause LST transfer
        LST.pause();
        // deploy PrivateSale contract
        Sale = new PrivateSale(
          address(LST),
          24000,
          address(ColdStorageWallet),
          address(Whitelist)
        );
        // link PrivateSale to Whitelist
        Whitelist.setSaleContractAddress(address(Sale));
        // link PrivateSale to LST
        LST.setMintableOwner(address(Sale));
    }

    function testFail_UserNotWhitelisted() public {
      assertTrue(
        Whitelist.isWhitelisted(address(TestUser))
      );
    }

    function test_UserIsWhitelisted() public {
      Whitelist.whitelistAddress(address(TestUser));
      assertTrue(
        Whitelist.isWhitelisted(address(TestUser))
      );
    }

    function testFail_BuyTokensIfNotWhitelisted() public {
      // buy LST as TestUser
      Sale.buyTokens.value(1 ether)(address(TestUser));
    }

    function test_BuyTokensIfWhitelisted() public {
      // Whitelist TestUser address
      Whitelist.whitelistAddress(address(TestUser));
      assertEq(
        LST.balanceOf(address(TestUser)),
        0
      );
      // buy LST for 1 ether as TestUser
      Sale.buyTokens.value(1 ether)(address(TestUser));
      // Confirm 2,400 LST has been minted for TestUser
      assertEq(
        LST.balanceOf(address(TestUser)),
        24000000000000000000000
      );
      // Confirm 1 ether was transferred to ColdStorageWallet
      assertEq(
        ColdStorageWallet.balance,
        1 ether
      );
      // Confirm Sale contract has no ether
      assertEq(
        Sale.balance,
        0
      );
    }

}
