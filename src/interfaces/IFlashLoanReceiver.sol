// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.20;

// @audit info : unused import  in the production code
// this import is only used in the mock contract test and hence can should be import directly form IThunderLoan.sol,
// check out the the mock contract "/test/mocks/MockFlashLoanReceiver.sol"
import { IThunderLoan } from "./IThunderLoan.sol";

/**
 * @dev Inspired by Aave:
 * https://github.com/aave/aave-v3-core/blob/master/contracts/flashloan/interfaces/IFlashLoanReceiver.sol
 */
interface IFlashLoanReceiver {
    // @audit info where is the natSpec?
    // we need to understand what each paramters is doing
    // how the call is going to be executed
    function executeOperation(
        address token,
        uint256 amount,
        uint256 fee,
        address initiator,
        bytes calldata params
    )
        external
        returns (bool);
}
