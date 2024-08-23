// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.20;

// q what are you using t-swap pool , it has some know bugs
// i  this get the address of the pool from pool factory .sol

interface IPoolFactory {
    function getPool(address tokenAddress) external view returns (address);
}
