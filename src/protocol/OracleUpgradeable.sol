// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.20;

import { ITSwapPool } from "../interfaces/ITSwapPool.sol";
import { IPoolFactory } from "../interfaces/IPoolFactory.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

//@audit-info natspec documentation missing
//i   using intilaize is the best way to set up a constrouctor in an implementation contract
// read more on this on openzeppelin docs.
// chech out on this youtube video  https://www.youtube.com/watch?v=XmxfB5JOt1Q&list=PL-XC037coXeXNDlUy6b132Ap97BlXKpGo&index=3
contract OracleUpgradeable is Initializable {
    error Oracle__CantBeZeroAddress();

    address private s_poolFactory;

    // @audit-info need to do zero address check
    function __Oracle_init(address poolFactoryAddress) internal onlyInitializing {
        __Oracle_init_unchained(poolFactoryAddress);
    }

    function __Oracle_init_unchained(address poolFactoryAddress) internal onlyInitializing {
        if (poolFactoryAddress == address(0)) {
            revert Oracle__CantBeZeroAddress();
        }
        s_poolFactory = poolFactoryAddress;
    }
    // e wow , we are calling an external contract, possible renetracy attack
    // can the price be manipulated ?
    // how about with token with differnt decimals values like USDC

    function getPriceInWeth(address token) public view returns (uint256) {
        address swapPoolOfToken = IPoolFactory(s_poolFactory).getPool(token); // e this is the external call
        return ITSwapPool(swapPoolOfToken).getPriceOfOnePoolTokenInWeth(); // e  this is also an external call
    }

    // fuction has the repeated , same as  ``getPriceInWeth`` function above
    // @audit-info repeated fucntion
    function getPrice(address token) external view returns (uint256) {
        return getPriceInWeth(token);
    }

    function getPoolFactoryAddress() external view returns (address) {
        return s_poolFactory;
    }
}
