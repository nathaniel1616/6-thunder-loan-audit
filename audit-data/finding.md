### [H-1] Updating the `exchangeRate` in the `ThunderLoan::deposit` function will lead to raise the fees up which will make LP unable to redeem their funds

**Description:** In the `ThunderLoan::deposit` function, exchangeRate is updated,

<details>
<summary> Code here </summary>

```javascript
    function deposit(IERC20 token, uint256 amount) external revertIfZero(amount) revertIfNotAllowedToken(token) {
        AssetToken assetToken = s_tokenToAssetToken[token];
        uint256 exchangeRate = assetToken.getExchangeRate();
        uint256 mintAmount = (amount * assetToken.EXCHANGE_RATE_PRECISION()) / exchangeRate;
        emit Deposit(msg.sender, token, amount);
        assetToken.mint(msg.sender, mintAmount);
  @>    uint256 calculatedFee = getCalculatedFee(token, amount);
  @>     assetToken.updateExchangeRate(calculatedFee);
        token.safeTransferFrom(msg.sender, address(assetToken), amount);
    }
```

</details>

**Impact:** The LP can redeem their funds after deposit.

**Proof of Concept:** The protocol makes money only by giving out flashloan and taking a fees .

1. In the `ThunderLoanTest.t.sol` test file , the `test_LP_DepositandFailsToRedeem` function illustrate a case where an LP makes a deposit and withdrawls at an instant.

```javascript
    function test_LP_DepositandFailsToRedeem() public setAllowedToken hasDeposits {
        vm.startPrank(liquidityProvider);
        vm.expectRevert();
        thunderLoan.redeem(tokenA, type(uint256).max);
        vm.stopPrank();
    }
```

2. in the in the terminal, run

```
$forge test --mt test_LP_DepositandFailsToRedeem -vvvvv
```

An expected revert occurs because the total balance of tokenA(which the the deposit made by the LP) in the `AssetToken` contract is `1e21` but updated exchangeRate increase the amount of Token A to `1.003e21` which is not avaible in the contract.



**Recommended Mitigation:** should remove these lines
```diff
 function deposit(IERC20 token, uint256 amount) external revertIfZero(amount) revertIfNotAllowedToken(token) {
        AssetToken assetToken = s_tokenToAssetToken[token];
        uint256 exchangeRate = assetToken.getExchangeRate();
        uint256 mintAmount = (amount * assetToken.EXCHANGE_RATE_PRECISION()) / exchangeRate;
        emit Deposit(msg.sender, token, amount);
        assetToken.mint(msg.sender, mintAmount);
-        uint256 calculatedFee = getCalculatedFee(token, amount);
-        assetToken.updateExchangeRate(calculatedFee);
        token.safeTransferFrom(msg.sender, address(assetToken), amount);
    }
```


### [H-2] ```ThunderLoan::s_flashLoanFee``` can be manipulated to reduce the fees during flashLoan .  This will reduce the expected fees the protocol makes on a flashloan

**Description:** The  ```ThunderLoan::s_flashLoanFee``` can be manipuated to reduce it the expected fee on an amonut during flashloan. 
1. The ```ThunderLoan::getCalculatedFee()``` function relys on TSwapPool as a price oracle to determine the price of Token A in Weth. The TSwapPool price can be manupilated when the a user swaper a large amount of TokenA to Weth . This  abundance of tokenA will lead to the reduction in the price of Token A relative to Weth. 
1. Since the ```ThunderLoan``` relies on TSwapPool to determine the price  of Token A when calculating ```s_flashLoanFee```, the fee will be reduced when calculating  a new fee for a the flashloan.


**Impact:** This will lead to a decrease in the expected ````s_flashLoanFee``` which accured by ThunderLoan.An attacker can manipulate this alot to reduce the  collatoralization of the protocol.

**Proof of Concept:** 
In a single block,
1. A attacker swaps a large amoount of tokenA to Weth on the TSwapPool. (user  can use the flashloan from thunderLoan or other flashloan providers) This manulipulation decreases the price of Token A relative to Weth.
2. the attacker then  takes a flashloan from thunderLoan at reduced fee

<details>
<Summary>  Code Here</Summary>
In the ```OracleManipuation.t.sol``` , check out the ```testFlashLoanOracle()``` test function.


```javascript
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
```
1. the ```OracleFlashLoanReceiver``` contract  in ``test/unit/audit/OracleFlashLoanReceiver.sol`` file  is the flashLoan receiver contract for the attacker
1. In the terminal , run ``forge test --mt testFlashLoanOracle -vv``
1. the attackFee(two flashloan calls each of 50 TokenA) is  less than the normal fee expected for 100 TokenA.
1. Run `cast --from-wei [feeamount]` in the terminal, to determine them in eth , eg `cast --from-wei 148073705159559194`


</details>


**Recommended Mitigation:**  
1. It is best to rely on  a ChainLink Price Oracle[https://docs.chain.link/docs/data-feeds/] to determine the price of Token A in Weth.(best practice).


### [H-3] The ```s_flashLoanFee``` can change unexpectedly when the ```ThunderLoan``` contract is upgraded to ``ThunderLoanUpgraded`` 

**Description:** 
1. The storage slot in the ```ThunderLoan``` is different from the storage slot in the ```ThunderLoanUpgraded```. The proxy implementation of the first ```ThunderLoan``` contract will be be the stroage slot in the ERC1967 contract proxy contract and not in the ```ThunderLoan``` contract.
2. When the ```ThunderLoan``` contract is upgraded to ```ThunderLoanUpgraded```, the storage slot of the ERC1967 proxy  contract will match  to the storage slots in the ```ThunderLoanUpgraded```.

In `ThunderLoan`,
s_flashLoanFee comes second  (in storage slot- 3)
```javascript
   // The fee in WEI, it should have 18 decimals. Each flash loan takes a flat fee of the token price.
    uint256 private s_feePrecision;
    uint256 private s_flashLoanFee; // 0.3% ETH fee
```
In the `ThunderLoanUpgraded`,
s_flashLoanFee comes first (in storage slot- 2)
```javascript
    uint256 private s_flashLoanFee; // 0.3% ETH fee
    uint256 public constant FEE_PRECISION = 1e18;
```
**Impact:** This change will the position arrangement will change the amount of `s_flashLoanFee` leading to unexpected `s_flashLoanFee` prices. 

**Proof of Concept:**
1. Inspect the ThunderLoan storage loan of ```s_flashLoanFee```
In the terminal  , `forge inspect ThunderLoan storage`  , the ``s_flashLoanFee`` storage slot will be 3
2. Inspect the ThunderLoanUpgraded storage loan of ```s_flashLoanFee```
In the terminal  , `forge inspect ThunderLoanUpgraded storage`  , the ``s_flashLoanFee`` storage slot will be 2

**Recommended Mitigation:**
1. ``ThunderLoanUpgraded`` storage slot should be the same as ``ThunderLoan`` storage slots. 
2. In ``ThunderLoanUpgraded`` contract, 

```diff
-    uint256 private s_flashLoanFee; // 0.3% ETH fee
-    uint256 public constant FEE_PRECISION = 1e18;

+    uint256 private emptySlot;    //expected empty storage slot 2 ,should not be  deleted in the contract
+    uint256 private s_flashLoanFee;
```
Note that, constants such `FEE_PRECISION` does not  have any storage slot , hence we would create an empty storage for slot 2 called `emptySlot`.




### [S-#] TITLE (Root Cause + Impact)

**Description:**

**Impact:**

**Proof of Concept:**

**Recommended Mitigation:**

