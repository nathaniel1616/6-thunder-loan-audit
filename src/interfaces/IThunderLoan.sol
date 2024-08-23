// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

// i  will review it in the main thunder.sol contract .
// @audit-info  the repay function is not implemenated on the thunder.sol contract .
//  in the thurder.sol contract the parameter of the repay function is diffrent.
//  function replay ( IERC20 token, uint256 amount ) external returns (bool)

interface IThunderLoan {
    function repay(address token, uint256 amount) external;
}

// ❌ will have to check again  on the thurder.sol contract
