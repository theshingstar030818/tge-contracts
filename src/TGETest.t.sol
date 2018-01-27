pragma solidity ^0.4.17;

import "ds-test/test.sol";
import "./base.sol";
import "./tge.sol";


contract User {}

  contract ColdWallet {
    // Wallet contract to accept payment
    function() payable public {}
  }


contract LST_TGE is DSTest {

    /*contracts*/
    User TestUser;
    ColdWallet ColdStorageWallet;
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
        ColdStorageWallet = new ColdWallet();
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
        wallet = new Wallet();
        trs = new TRS();
        vault = new Vault();
        // Link contracts
        tge.setWalletContract(address(wallet));
        wallet.setTGEContract(address(tge));
        wallet.setTRSContract(address(trs));
        wallet.setVaultContract(address(vault));
        trs.setWalletContract(address(wallet));
        trs.setVaultContract(address(vault));
        vault.setWalletContract(address(wallet));
        vault.setToken(address(LST));
        // Initialize contracts
        tge.init(
          address(LST),
          LSTRatePerEther,
          address(ColdStorageWallet),
          address(Whitelist),
          saleStartTimestamp,
          saleEndTimestamp
        );

        wallet.init(
          totalAvailableTokens,
          initialVestedReleasePercentage
        );
        // link TGE to Whitelist
        Whitelist.setTGEContract(address(tge));
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
      uint256 reserved_;
      uint256 released_;
      uint256 withdrawable_;
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
        wallet.totalAvailableTokens(),
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
      (reserved_, released_, withdrawable_) = wallet.getStats(address(TestUser));
      assertEq(
        reserved_,
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
        wallet.totalReservedTokensDuringTGE(),
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
      uint256 reserved_;
      uint256 released_;
      uint256 withdrawable_;
      // Whitelist TestUser address
      Whitelist.whitelistAddress(address(TestUser));
      // buy LST for 1 ether as TestUser
      tge.buyTokens.value(1 ether)(address(TestUser));
      // Confirm 1 ether has been contributed by TestUser
      // Confirm 24,000 LST has been reserved for TestUser
      (reserved_, released_, withdrawable_) = wallet.getStats(address(TestUser));
      assertEq(
        reserved_,
        LSTRatePerEther * precision
      );
      assertEq(
        wallet.getTotalReservedForVesting(),
        0
      );
      bool _vestingDecision = true;
      assert(tge.vestFor(address(TestUser), _vestingDecision));
      assertEq(
        wallet.getTotalReservedForVesting(),
        LSTRatePerEther * precision
      );
    }

    function testFail_VestWhenPaused() public {
      uint256 reserved_;
      uint256 released_;
      uint256 withdrawable_;
      // Whitelist TestUser address
      Whitelist.whitelistAddress(address(TestUser));
      // buy LST for 1 ether as TestUser
      tge.buyTokens.value(1 ether)(address(TestUser));
      // Confirm 1 ether has been contributed by TestUser
      // Confirm 24,000 LST has been reserved for TestUser
      (reserved_, released_, withdrawable_) = wallet.getStats(address(TestUser));
      assertEq(
        reserved_,
        LSTRatePerEther * precision
      );
      // Pause Sale contract
      tge.pause();
      assert(tge.vestFor(address(TestUser), true));
    }

    function testFail_DoubleVestTrue() public {
      // Whitelist TestUser address
      Whitelist.whitelistAddress(address(TestUser));
      // buy LST for 1 ether as TestUser
      tge.buyTokens.value(1 ether)(address(TestUser));
      assert(tge.vestFor(address(TestUser), true));
      assert(tge.vestFor(address(TestUser), true));
    }

    function testFail_DoubleVestFalse() public {
      // Whitelist TestUser address
      Whitelist.whitelistAddress(address(TestUser));
      // buy LST for 1 ether as TestUser
      tge.buyTokens.value(1 ether)(address(TestUser));
      assert(tge.vestFor(address(TestUser), false));
      assert(tge.vestFor(address(TestUser), false));
    }

    function test_MultipleVestedContributors() public {
      User AnotherUser;
      uint256 totalContributions = 0;
      uint256 _amount;
      uint256 reserved_;
      uint256 released_;
      uint256 withdrawable_;
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
        wallet.totalAvailableTokens() - wallet.totalReservedTokensDuringTGE(),
        totalRemainingTokens
      );
      assert(tge.vestFor(address(TestUser), true));
      uint256 totalVested = (totalContributions) * LSTRatePerEther * precision;
      assertEq(
        wallet.getTotalReservedForVesting(),
        totalVested
      );
      uint256 amountVested = 2 * LSTRatePerEther * precision;
      (reserved_, released_, withdrawable_) = wallet.getStats(address(TestUser));
      assertEq(
        reserved_,
        amountVested
      );
    }

    function test_WithdrawalWithoutVesting() public {
      uint256 reserved_;
      uint256 released_;
      uint256 withdrawable_;
      // Whitelist TestUser address
      Whitelist.whitelistAddress(address(TestUser));
      // buy LST for 1 ether as TestUser
      tge.buyTokens.value(1 ether)(address(TestUser));
      tge.endPublicTGE();
      assert(tge.setTRSOffset(0));
      assertEq(
        wallet.getTotalReservedForVesting(),
        0
      );
      (reserved_, released_, withdrawable_) = wallet.getStats(address(TestUser));
      assertEq(
        reserved_,
        1 * LSTRatePerEther * precision
      );
      assertEq(
        released_,
        0
      );
      assertEq(
        withdrawable_,
        0
      );
      // Confirm vesting decision
      assert(!tge.isVestedContributor(address(TestUser)));
      // Withdraw
      assert(wallet.withdrawFor(address(TestUser)));
      (reserved_, released_, withdrawable_) = wallet.getStats(address(TestUser));
      assertEq(
        reserved_,
        0
      );
      assertEq(
        released_,
        0
      );
      assertEq(
        withdrawable_,
        1 * LSTRatePerEther * precision
      );
    }

    function testFail_WithdrawTwiceBeforeTRSStart() public {
      // Whitelist TestUser address
      Whitelist.whitelistAddress(address(TestUser));
      // buy LST for 1 ether as TestUser
      tge.buyTokens.value(1 ether)(address(TestUser));
      tge.endPublicTGE();
      assert(tge.setTRSOffset(0));
      assert(!tge.isVestedContributor(address(TestUser)));
      // Withdraw
      assert(wallet.withdrawFor(address(TestUser)));
      assert(wallet.withdrawFor(address(TestUser)));
    }

    function test_WithdrawalWithVesting() public {
      uint256 vestingAmount = 1 * LSTRatePerEther * precision;
      uint256 reserved_;
      uint256 released_;
      uint256 withdrawable_;
      // Whitelist TestUser address
      Whitelist.whitelistAddress(address(TestUser));
      // buy LST for 1 ether as TestUser
      tge.buyTokens.value(1 ether)(address(TestUser));
      tge.endPublicTGE();
      assert(tge.setTRSOffset(0));
      assertEq(
        wallet.getTotalReservedForVesting(),
        0
      );
      (reserved_, released_, withdrawable_) = wallet.getStats(address(TestUser));
      assertEq(
        reserved_,
        vestingAmount
      );
      assertEq(
        released_,
        0
      );
      assertEq(
        withdrawable_,
        0
      );
      // Vest
      bool _vestingDecision = true;
      assert(tge.vestFor(address(TestUser), _vestingDecision));
      // Confirm vesting decision
      assert(tge.isVestedContributor(address(TestUser)));
      uint256 totalVestedAmount = wallet.getTotalReservedForVesting();
      uint256 totalNonVestedAmount = wallet.totalReservedTokensDuringTGE() - totalVestedAmount;
      uint256 totalDistributableAmount = wallet.totalAvailableTokens() - totalNonVestedAmount;
      // Withdraw
      assert(wallet.setBonusMultiplier());
      /* uint256 bonusFraction = totalAvailableTokens * precision / vestingAmount;
      assertEq(
        wallet.getBonusMultiplier(),
        bonusFraction * precision
      ); */
      assert(wallet.withdrawFor(address(TestUser)));
      (reserved_, released_, withdrawable_) = wallet.getStats(address(TestUser));
      uint256 expectedReservedAmountWithBonus = vestingAmount * (totalDistributableAmount) / totalVestedAmount;
      assertEq(
        reserved_,
        expectedReservedAmountWithBonus * (75 * 10**16) / precision
      );
      assertEq(
        released_,
        0
      );
      assertEq(
        withdrawable_,
        expectedReservedAmountWithBonus * (25 * 10**16) / precision
      );
    }

    function test_WithdrawalWithMultipleVestedContributors() public {
      User AnotherUser;
      uint256 _amount;
      uint256 reserved_;
      uint256 released_;
      uint256 withdrawable_;
      for (uint256 _i = 1; _i < 201; _i++) {
        AnotherUser = new User();
        // Whitelist TestUser address
        Whitelist.whitelistAddress(address(AnotherUser));
        // buy LST for 101 ether as TestUser
        _amount = (_i+5);
        tge.buyTokens.value(_amount * 1 ether)(address(AnotherUser));
        if (_i % 2 == 0) {
          assert(tge.vestFor(address(AnotherUser), true));
        }
      }

      // Whitelist TestUser address
      Whitelist.whitelistAddress(address(TestUser));
      // buy LST for 1 ether as TestUser
      tge.buyTokens.value(2 ether)(address(TestUser));
      assert(tge.vestFor(address(TestUser), true));
      
      uint256 vestingAmount = 2 * LSTRatePerEther * precision;
      (reserved_, released_, withdrawable_) = wallet.getStats(address(TestUser));
      assertEq(
        reserved_,
        vestingAmount
      );
      tge.endPublicTGE();
      assert(tge.setTRSOffset(0));
      // Withdraw
      assert(wallet.setBonusMultiplier());


      uint256 totalVestedAmount = wallet.getTotalReservedForVesting();
      uint256 totalNonVestedAmount = wallet.totalReservedTokensDuringTGE() - totalVestedAmount;
      uint256 totalDistributableAmount = wallet.totalAvailableTokens() - totalNonVestedAmount;

      uint256 bonusMultiplier = totalDistributableAmount * precision / totalVestedAmount;

      assert(wallet.withdrawFor(address(TestUser)));
      (reserved_, released_, withdrawable_) = wallet.getStats(address(TestUser));
      uint256 expectedReservedAmountWithBonus = vestingAmount * bonusMultiplier / precision;
      assertEq(
        reserved_,
        expectedReservedAmountWithBonus * (75 * 10**16) / precision
      );
      assertEq(
        released_,
        0
      );
      assertEq(
        withdrawable_,
        expectedReservedAmountWithBonus * (25 * 10**16) / precision
      );
    }

}
