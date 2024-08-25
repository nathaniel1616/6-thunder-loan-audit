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
