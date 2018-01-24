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
    TGE tge;
    TRS trs;
    uint256 totalAvailableTokens;
    uint256 initialVestedReleasePercentage;
    uint256 saleStartTimestamp;
    uint256 saleEndTimestamp;
    uint256 precision = 10 ** 18;
    uint256 LSTRatePerEther = 24000;

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
        // deploy TGE contract
        totalAvailableTokens = 6 * (10 ** 9);
        initialVestedReleasePercentage = 25 * (10 ** 16);
        saleStartTimestamp = now;
        saleEndTimestamp = now + 10 days;
        tge = new TGE();
        tge.init(
          address(LST),
          24000,
          address(ColdStorageWallet),
          address(Whitelist),
          saleStartTimestamp,
          saleEndTimestamp
        );
        trs = new TRS();
        trs.init(
          totalAvailableTokens,
          initialVestedReleasePercentage
        );
        // link TGE to Whitelist
        Whitelist.setAuthority(address(tge));
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
      tge.buyTokens.value(1 ether)(address(TestUser));
    }

    function test_BuyTokensIfWhitelisted() public {
      // Whitelist TestUser address
      Whitelist.whitelistAddress(address(TestUser));
      assertEq(
        LST.balanceOf(address(TestUser)),
        0
      );
      /* assertEq(
        tge.weiContributed(address(TestUser)),
        0
      );
      assertEq(
        tge.weiRaised(),
        0
      );
      // Confirm totalAvailableTokens has been reduced by the LST reserved
      assertEq(
        trs.totalAvailableTokens(),
        totalAvailableTokens * precision
      ); */
      /* // buy LST for 1 ether as TestUser
      tge.buyTokens.value(1 ether)(address(TestUser));
      // Confirm 1 ether has been contributed by TestUser
      assertEq(
        tge.weiContributed(address(TestUser)),
        1 ether
      );
      // Confirm 24,000 LST has been reserved for TestUser
      assertEq(
        trs.reservedTokens(address(TestUser)),
        LSTRatePerEther * precision
      );
      // Confirm No LST has been minted separately for TestUser
      assertEq(
        LST.balanceOf(address(TestUser)),
        0
      );
      // Confirm 1 ether was transferred to ColdStorageWallet
      assertEq(
        ColdStorageWallet.balance,
        1 ether
      );
      // Confirm Sale contract has no ether
      assertEq(
        tge.balance,
        0
      );
      // Confirm weiRaised has been updated on Sale contract
      assertEq(
        tge.weiRaised(),
        1 ether
      );
      // Confirm totalAvailableTokens has been reduced by the LST reserved
      assertEq(
        trs.totalAvailableTokens(),
        (totalAvailableTokens - LSTRatePerEther) * precision
      ); */
    }

    /* function testFail_BuyTokensIfPaused() public {
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
    } */

    /* function testFail_BuyAfterTotalCapHasReached() public {
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
    } */

    /* function testFail_BuyAfterChangingIndividualCap() public {
      // Whitelist TestUser address
      Whitelist.whitelistAddress(address(TestUser));
      // buy LST for 101 ether as TestUser
      Sale.buyTokens.value(5000 ether)(address(TestUser));
      Sale.setIndividualCap(9000 ether);
      Sale.buyTokens.value(5000 ether)(address(TestUser));
    } */

    /* // Tests involving Vesting
    function test_DecisionVesting() public {
      // Whitelist TestUser address
      Whitelist.whitelistAddress(address(TestUser));
      // buy LST for 1 ether as TestUser
      Sale.buyTokens.value(1 ether)(address(TestUser));
      // Confirm 1 ether has been contributed by TestUser
      // Confirm 24,000 LST has been reserved for TestUser
      assertEq(
        Sale.reserved(address(TestUser)),
        LSTRatePerEther * precision
      );
      assertEq(
        Sale.totalReservedForVesting(),
        0
      );
      assert(!Sale.vesting(address(TestUser)));
      assertEq(
        Sale.expectedTokensWithBonus(address(TestUser)),
        LSTRatePerEther * precision
      );
      bool _vestingDecision = true;
      assert(Sale.vestFor(address(TestUser), _vestingDecision));
      assertEq(
        Sale.totalReservedForVesting(),
        LSTRatePerEther * precision
      );
      assert(Sale.vesting(address(TestUser)));
      assertEq(
        Sale.expectedTokensWithBonus(address(TestUser)),
        totalAvailableTokens * precision
      );
    }

    function test_ReservedWithBonus() public {
      User AnotherUser;
      uint256 totalContributions = 0;
      uint256 _amount;
      for (uint256 _i = 1; _i < 201; _i++) {
        AnotherUser = new User();
        // Whitelist TestUser address
        Whitelist.whitelistAddress(address(AnotherUser));
        // buy LST for 101 ether as TestUser
        _amount = (_i+5);
        totalContributions += _amount;
        Sale.buyTokens.value(_amount * 1 ether)(address(AnotherUser));
        assert(Sale.vestFor(address(AnotherUser), true));
      }

      // Whitelist TestUser address
      Whitelist.whitelistAddress(address(TestUser));
      // buy LST for 1 ether as TestUser
      Sale.buyTokens.value(2 ether)(address(TestUser));
      assert(Sale.vestFor(address(TestUser), true));
      uint256 totalVested = (totalContributions + 2) * LSTRatePerEther * precision;
      assertEq(
        Sale.totalReservedForVesting(),
        totalVested
      );
      uint256 amountVested = 2 * LSTRatePerEther * precision;
      assertEq(
        Sale.reserved(address(TestUser)),
        amountVested
      );
      uint256 totalRemainingBonus = (totalAvailableTokens * precision) - totalVested;
      assertEq(
        Sale.totalAvailableTokens(),
        totalRemainingBonus
      );
      uint256 expectedBonus = ((amountVested * totalRemainingBonus) / totalVested);
      assert(Sale.vesting(address(TestUser)));
      assertEq(
        Sale.expectedTokensWithBonus(address(TestUser)),
        amountVested + expectedBonus
      );
    } */

}
