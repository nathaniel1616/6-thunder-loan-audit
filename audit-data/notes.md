# About the protocol in your own words

# diagrams

# ideas

# possible attack vectors

1. in `ThunderLoan.sol` can the LP just deposit which will increase the exchange rate and then withdrawl to optain high rates
   , can this be repeat to hype up the exchage rate

#

# Questions

1. // q what does exchnage fees increse for each deposit, will fees decrese when the is a withdrawl of assets ? `ThurnderLoan::deposit` function. it has been noted that fees should never decrease as it it the invariant

2. in the `AssetToken.sol` contract when have IERC20 underlying variable what is that?
   // q what of Wierd ERC20 token with 6 decimals like USDC
   wierd ERC20 with less decimals

# key words /special words

uint256 private s_exchangeRate; ===>> means when s_exchangeRate =2 ,
it means for 1 asset token where are two underlying tokens

# Contract Invariants

1. In `AssetToken.sol` exchange rate should always be increasing
   this is the equation `uint256 newExchangeRate = s_exchangeRate * (totalSupply() + fee) / totalSupply();`
   How big the fee is should be divided by the total supply. However what if the LP decides to withdraw and burn the their asset tokens
   the total supply of the asset should decrease
