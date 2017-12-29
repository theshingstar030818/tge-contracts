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
        // confirm owner has 0 LST
        assertEq(
          LST.balanceOf(this),
          0
        );
        // confirm ColdStorageWallet has 0 lST
        assertEq(
          LST.balanceOf(address(ColdStorageWallet)),
          0
        );
        // deploy PrivateSale contract
        Sale = new PrivateSale(
          address(LST),
          24000,
          address(ColdStorageWallet),
          address(Whitelist)
        );
        // link PrivateSale to Whitelist
        Whitelist.setAuthority(address(Sale));
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
      assertEq(
        Sale.totalWeiContributed(address(TestUser)),
        0
      );
      assertEq(
        Sale.weiRaised(),
        0
      );
      // buy LST for 1 ether as TestUser
      Sale.buyTokens.value(1 ether)(address(TestUser));
      // Confirm 1 ether has been contributed by TestUser
      assertEq(
        Sale.totalWeiContributed(address(TestUser)),
        1 ether
      );
      // Confirm 24,000 LST has been minted for TestUser
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
      // Confirm weiRaised has been updated on Sale contract
      assertEq(
        Sale.weiRaised(),
        1 ether
      );
    }

    function testFail_BuyTokensIfPaused() public {
      // Whitelist TestUser
      Whitelist.whitelistAddress(address(TestUser));
      // Pause Sale contract
      Sale.pause();
      // Buy LST as TestUser
      Sale.buyTokens.value(1 ether)(address(TestUser));
    }

    function testFail_BuyAboveIndividualCap() public {
      // Whitelist TestUser address
      Whitelist.whitelistAddress(address(TestUser));
      // buy LST for 101 ether as TestUser
      Sale.buyTokens.value(5001 ether)(address(TestUser));
    }

    function testFail_BuyAfterTotalCapHasReached() public {
      // Buy until total cap is reached
      for (uint contibutionCount = 1; contibutionCount < 6; contibutionCount++) {
        TestUser = new User();
        // Whitelist TestUser address
        Whitelist.whitelistAddress(address(TestUser));
        // buy LST for 101 ether as TestUser
        Sale.buyTokens.value(5000 ether)(address(TestUser));
      }
      // Now the next buy should fail
      TestUser = new User();
      // Whitelist TestUser address
      Whitelist.whitelistAddress(address(TestUser));
      // buy LST for 101 ether as TestUser
      Sale.buyTokens.value(5000 ether)(address(TestUser));
    }

    function test_BuyAfterChangingIndividualCap() public {
      // Whitelist TestUser address
      Whitelist.whitelistAddress(address(TestUser));
      // buy LST for 101 ether as TestUser
      Sale.buyTokens.value(5000 ether)(address(TestUser));
      Sale.setIndividualCap(9000 ether);
      Sale.buyTokens.value(4000 ether)(address(TestUser));
    }

    function testFail_BuyAfterChangingIndividualCap() public {
      // Whitelist TestUser address
      Whitelist.whitelistAddress(address(TestUser));
      // buy LST for 101 ether as TestUser
      Sale.buyTokens.value(5000 ether)(address(TestUser));
      Sale.setIndividualCap(9000 ether);
      Sale.buyTokens.value(5000 ether)(address(TestUser));
    }

}
