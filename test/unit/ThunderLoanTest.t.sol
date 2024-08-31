// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { Test, console } from "forge-std/Test.sol";
import { BaseTest, ThunderLoan } from "./BaseTest.t.sol";
import { AssetToken } from "../../src/protocol/AssetToken.sol";
import { MockFlashLoanReceiver } from "../mocks/MockFlashLoanReceiver.sol";
import { ThunderLoanUpgraded } from "../../src/upgradedProtocol/ThunderLoanUpgraded.sol";

contract ThunderLoanTest is BaseTest {
    uint256 constant AMOUNT = 10e18;
    uint256 constant DEPOSIT_AMOUNT = AMOUNT * 100;
    address liquidityProvider = address(123);
    address user = address(456);
    MockFlashLoanReceiver mockFlashLoanReceiver;

    function setUp() public override {
        super.setUp();
        vm.prank(user);
        mockFlashLoanReceiver = new MockFlashLoanReceiver(address(thunderLoan));
    }

    function testInitializationOwner() public {
        assertEq(thunderLoan.owner(), address(this));
    }

    function testSetAllowedTokens() public {
        vm.prank(thunderLoan.owner());
        thunderLoan.setAllowedToken(tokenA, true);
        assertEq(thunderLoan.isAllowedToken(tokenA), true);
    }

    function testOnlyOwnerCanSetTokens() public {
        vm.prank(liquidityProvider);
        vm.expectRevert();
        thunderLoan.setAllowedToken(tokenA, true);
    }

    function testSettingTokenCreatesAsset() public {
        vm.prank(thunderLoan.owner());
        AssetToken assetToken = thunderLoan.setAllowedToken(tokenA, true);
        assertEq(address(thunderLoan.getAssetFromToken(tokenA)), address(assetToken));
    }

    function testCantDepositUnapprovedTokens() public {
        tokenA.mint(liquidityProvider, AMOUNT);
        tokenA.approve(address(thunderLoan), AMOUNT);
        vm.expectRevert(abi.encodeWithSelector(ThunderLoan.ThunderLoan__NotAllowedToken.selector, address(tokenA)));
        thunderLoan.deposit(tokenA, AMOUNT);
    }

    modifier setAllowedToken() {
        vm.prank(thunderLoan.owner());
        thunderLoan.setAllowedToken(tokenA, true);
        _;
    }

    function testDepositMintsAssetAndUpdatesBalance() public setAllowedToken {
        tokenA.mint(liquidityProvider, AMOUNT);

        vm.startPrank(liquidityProvider);
        tokenA.approve(address(thunderLoan), AMOUNT);
        thunderLoan.deposit(tokenA, AMOUNT);
        vm.stopPrank();

        AssetToken asset = thunderLoan.getAssetFromToken(tokenA);
        assertEq(tokenA.balanceOf(address(asset)), AMOUNT);
        assertEq(asset.balanceOf(liquidityProvider), AMOUNT);
    }

    modifier hasDeposits() {
        vm.startPrank(liquidityProvider);
        tokenA.mint(liquidityProvider, DEPOSIT_AMOUNT);
        tokenA.approve(address(thunderLoan), DEPOSIT_AMOUNT);
        thunderLoan.deposit(tokenA, DEPOSIT_AMOUNT);
        vm.stopPrank();
        _;
    }

    function testFlashLoan() public setAllowedToken hasDeposits {
        uint256 amountToBorrow = AMOUNT * 10;
        uint256 calculatedFee = thunderLoan.getCalculatedFee(tokenA, amountToBorrow);
        vm.startPrank(user);
        tokenA.mint(address(mockFlashLoanReceiver), AMOUNT);
        thunderLoan.flashloan(address(mockFlashLoanReceiver), tokenA, amountToBorrow, "");
        vm.stopPrank();

        assertEq(mockFlashLoanReceiver.getBalanceDuring(), amountToBorrow + AMOUNT);
        assertEq(mockFlashLoanReceiver.getBalanceAfter(), AMOUNT - calculatedFee);
    }

    ///////////////////////////////////////////////////////////////////////
    //////////                    Audit POC                     //////////
    ///////////////////////////////////////////////////////////////////////
    function test_canRedeem() public setAllowedToken hasDeposits {
        // in the hasDeposits modifier LP deposited ``DEPOSIT_AMOUNT`` of tokenA
        AssetToken assetToken = thunderLoan.getAssetFromToken(tokenA);

        uint256 startingAssetLP_BeforeFlashLoan = assetToken.balanceOf(liquidityProvider);
        console.log("startingAssetLP_BeforeFlashLoan", startingAssetLP_BeforeFlashLoan);

        uint256 startingLPTokenAmount =
            (assetToken.getExchangeRate() * startingAssetLP_BeforeFlashLoan) / assetToken.EXCHANGE_RATE_PRECISION();
        console.log("startingLPTokenAmount: ", startingLPTokenAmount);
        uint256 amountToBorrow = AMOUNT * 10;
        // uint256 calculatedFee = thunderLoan.getCalculatedFee(tokenA, amountToBorrow);
        vm.startPrank(user);
        tokenA.mint(address(mockFlashLoanReceiver), AMOUNT);
        thunderLoan.flashloan(address(mockFlashLoanReceiver), tokenA, amountToBorrow, "");
        vm.stopPrank();

        //LP redeeming their deposits

        vm.startPrank(liquidityProvider);
        thunderLoan.redeem(tokenA, startingAssetLP_BeforeFlashLoan);
        vm.stopPrank();
        uint256 endingAssetLP_AfterFlashLoan = assetToken.balanceOf(liquidityProvider);
        console.log("endingAssetLP_AfterFlashLoan   ", endingAssetLP_AfterFlashLoan);
        assertEq(endingAssetLP_AfterFlashLoan, 0);
        // expected token balance after the redeem
        // since the exchange rate has increased after the flashloan we get the new exchange rate
        uint256 expectedTokenAmount =
            (assetToken.getExchangeRate() * endingAssetLP_AfterFlashLoan) / assetToken.EXCHANGE_RATE_PRECISION();
        console.log("expectedTokenAmoun of LP: ", expectedTokenAmount);
        // assertGt(expectedTokenAmount, DEPOSIT_AMOUNT);
        assertEq(assetToken.balanceOf(liquidityProvider), 0);

        // assertEq(mockFlashLoanReceiver.getBalanceDuring(), amountToBorrow + AMOUNT);
        // assertEq(mockFlashLoanReceiver.getBalanceAfter(), AMOUNT - calculatedFee);
    }

    function test_LP_DepositandFailsToRedeem() public setAllowedToken hasDeposits {
        vm.startPrank(liquidityProvider);
        vm.expectRevert();
        thunderLoan.redeem(tokenA, type(uint256).max);
        vm.stopPrank();
    }

    /////   Updgradable  storage collisions    ////
    function test_storageCollisionsAfterUpgrade() public {
        // s_flashLoanFee before contract upgrade
        uint256 feeBeforeUpgrade = thunderLoan.getFee();
        console.log("feeBeforeUpgrade", feeBeforeUpgrade);

        /// the owner of the thunderLoan upgrades the contract
        vm.prank(thunderLoan.owner());
        ThunderLoanUpgraded thunderLoanUpgraded = new ThunderLoanUpgraded();
        thunderLoan.upgradeToAndCall(address(thunderLoanUpgraded), "");
        vm.stopPrank();

        // s_flashLoanFee after contract upgrade
        uint256 feeAfterUpgrade = thunderLoan.getFee();
        console.log("feeAfterUpgrade", feeAfterUpgrade);

        assert(feeBeforeUpgrade != feeAfterUpgrade);
    }
}
