// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

// What would you do for this?
// What are the invariants?
// 1. Asset exchange rate should always increase
// 2. The protocol should never lose liquidity provider deposits, it should always go up

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";

// import from mocks

import {BuffMockPoolFactory} from "../mocks/BuffMockPoolFactory.sol";
import {BuffMockTSwap} from "../mocks/BuffMockTSwap.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";

contract Invariant is StdInvariant,Test {

    //setup 
    function setUp()external  {

    }
 }
