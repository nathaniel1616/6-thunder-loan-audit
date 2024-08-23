// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.20;

// q what are you using t-swap pool , it has some know bugs
// q what are the risks involved  in using a central contract as an oracle ?

// i  this is to get the price of 1 weth in pool token
interface ITSwapPool {
    function getPriceOfOnePoolTokenInWeth() external view returns (uint256);
}

// ✅
