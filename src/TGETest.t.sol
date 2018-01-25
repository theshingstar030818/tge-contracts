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
    Wallet wallet;
    TRS trs;
    Vault vault;
    uint256 totalAvailableTokens;
    uint256 initialVestedReleasePercentage;
    uint256 saleStartTimestamp;
    uint256 saleEndTimestamp;
    uint256 precision = 10 ** 18;
    uint256 LSTRatePerEther = 48000;

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
        // Initialize variables
        totalAvailableTokens = 6 * (10 ** 9);
        initialVestedReleasePercentage = 25 * (10 ** 16);
        saleStartTimestamp = now;
        saleEndTimestamp = now + 10 days;
        // Deploy contracts
        tge = new TGE();
        trs = new TRS();
        // Link contracts
        tge.setTRSContract(address(trs));
        trs.setTGEContract(address(tge));
        // Initialize contracts
        tge.init(
          address(LST),
          LSTRatePerEther,
          address(ColdStorageWallet),
          address(Whitelist),
          saleStartTimestamp,
          saleEndTimestamp
        );

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
      assertTrue(Whitelist.whitelistAddress(address(TestUser)));
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
      assertTrue(Whitelist.whitelistAddress(address(TestUser)));
      assertEq(
        LST.balanceOf(address(TestUser)),
        0
      );
      assertEq(
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
      );
      // buy LST for 1 ether as TestUser
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
        trs.totalReservedTokensDuringTGE(),
        LSTRatePerEther * precision
      );
    }

    function testFail_BuyTokensIfPaused() public {
      // Whitelist TestUser
      Whitelist.whitelistAddress(address(TestUser));
      // Pause Sale contract
      tge.pause();
      // Buy LST as TestUser
      tge.buyTokens.value(1 ether)(address(TestUser));
    }

    function testFail_BuyAboveIndividualCap() public {
      // Whitelist TestUser address
      Whitelist.whitelistAddress(address(TestUser));
      // buy LST for 101 ether as TestUser
      tge.buyTokens.value(5001 ether)(address(TestUser));
    }

    function testFail_BuyAfterTotalCapHasReached() public {
      // Buy until total cap is reached
      for (uint contibutionCount = 1; contibutionCount < 6; contibutionCount++) {
        TestUser = new User();
        // Whitelist TestUser address
        Whitelist.whitelistAddress(address(TestUser));
        // buy LST for 101 ether as TestUser
        tge.buyTokens.value(5000 ether)(address(TestUser));
      }
      // Now the next buy should fail
      TestUser = new User();
      // Whitelist TestUser address
      Whitelist.whitelistAddress(address(TestUser));
      // buy LST for 101 ether as TestUser
      tge.buyTokens.value(5000 ether)(address(TestUser));
    }

    function test_BuyAfterChangingIndividualCap() public {
      // Whitelist TestUser address
      Whitelist.whitelistAddress(address(TestUser));
      // buy LST for 101 ether as TestUser
      tge.buyTokens.value(5000 ether)(address(TestUser));
      tge.setIndividualCap(9000 ether);
      tge.buyTokens.value(4000 ether)(address(TestUser));
    }

    function testFail_BuyAfterChangingIndividualCap() public {
      // Whitelist TestUser address
      Whitelist.whitelistAddress(address(TestUser));
      // buy LST for 101 ether as TestUser
      tge.buyTokens.value(5000 ether)(address(TestUser));
      tge.setIndividualCap(9000 ether);
      tge.buyTokens.value(5000 ether)(address(TestUser));
    }

    // Tests involving Vesting
    function test_DecisionVesting() public {
      // Whitelist TestUser address
      Whitelist.whitelistAddress(address(TestUser));
      // buy LST for 1 ether as TestUser
      tge.buyTokens.value(1 ether)(address(TestUser));
      // Confirm 1 ether has been contributed by TestUser
      // Confirm 24,000 LST has been reserved for TestUser
      assertEq(
        trs.reservedTokens(address(TestUser)),
        LSTRatePerEther * precision
      );
      assertEq(
        trs.getTotalReservedForVesting(),
        0
      );
      bool _vestingDecision = true;
      assert(tge.vestFor(address(TestUser), _vestingDecision));
      assertEq(
        trs.getTotalReservedForVesting(),
        LSTRatePerEther * precision
      );
    }

    function testFail_VestWhenPaused() public {
      // Whitelist TestUser address
      Whitelist.whitelistAddress(address(TestUser));
      // buy LST for 1 ether as TestUser
      tge.buyTokens.value(1 ether)(address(TestUser));
      // Confirm 1 ether has been contributed by TestUser
      // Confirm 24,000 LST has been reserved for TestUser
      assertEq(
        trs.reservedTokens(address(TestUser)),
        LSTRatePerEther * precision
      );
      // Pause Sale contract
      tge.pause();
      assert(tge.vestFor(address(TestUser), true));
    }

    function test_MultipleVestedContributors() public {
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
        tge.buyTokens.value(_amount * 1 ether)(address(AnotherUser));
        assert(tge.vestFor(address(AnotherUser), true));
      }

      // Whitelist TestUser address
      Whitelist.whitelistAddress(address(TestUser));
      // buy LST for 1 ether as TestUser
      tge.buyTokens.value(2 ether)(address(TestUser));
      totalContributions += 2;
      uint256 totalRemainingTokens = (totalAvailableTokens - totalContributions * LSTRatePerEther) * precision;
      assertEq(
        trs.totalAvailableTokens() - trs.totalReservedTokensDuringTGE(),
        totalRemainingTokens
      );
      assert(tge.vestFor(address(TestUser), true));
      uint256 totalVested = (totalContributions) * LSTRatePerEther * precision;
      assertEq(
        trs.getTotalReservedForVesting(),
        totalVested
      );
      uint256 amountVested = 2 * LSTRatePerEther * precision;
      assertEq(
        trs.reservedTokens(address(TestUser)),
        amountVested
      );
      /* uint256 expectedBonus = ((amountVested * totalRemainingBonus) / totalVested);
      assertEq(
        Sale.expectedTokensWithBonus(address(TestUser)),
        amountVested + expectedBonus
      ); */
    }

    function test_MinimumBonus() public {
      // Whitelist TestUser address
      Whitelist.whitelistAddress(address(TestUser));
      // buy LST for 1 ether as TestUser
      tge.buyTokens.value(1 ether)(address(TestUser));
      // Confirm 1 ether has been contributed by TestUser
      // Confirm 24,000 LST has been reserved for TestUser
      assertEq(
        trs.reservedTokens(address(TestUser)),
        LSTRatePerEther * precision
      );
      bool _vestingDecision = false;
      assertEq(
        trs.minimumBonusFor(address(TestUser), _vestingDecision),
        0
      );
      _vestingDecision = true;
      assert(tge.vestFor(address(TestUser), _vestingDecision));
      assertEq(
        trs.getTotalReservedForVesting(),
        LSTRatePerEther * precision
      );
      assertEq(
        trs.minimumBonusFor(address(TestUser), _vestingDecision),
        125 * LSTRatePerEther * precision / 100
      );
    }

}
