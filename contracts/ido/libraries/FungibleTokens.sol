// SPDX-License-Identifier: WTFPL

pragma solidity 0.8.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";

library FungibleTokens {
    using SafeERC20 for IERC20;

    function balanceOf(address token, address account) internal view returns (uint256 balance) {
        if (token == address(0)) {
            return account.balance;
        } else {
            return IERC20(token).balanceOf(account);
        }
    }

    function safeTransfer(
        address token,
        address to,
        uint256 amount
    ) internal {
        if (token == address(0)) {
            Address.sendValue(payable(to), amount);
        } else {
            IERC20(token).safeTransfer(to, amount);
        }
    }

    function safeTransferFrom(
        address token,
        address from,
        address to,
        uint256 amount
    ) internal {
        if (token == address(0)) {
            if (from == address(this)) {
                Address.sendValue(payable(to), amount);
            } else if (to == address(this)) {
                require(msg.value == amount, "DAOKIT: INSUFFICIENT_ETH");
            } else {
                revert("DAOKIT: UNREACHABLE");
            }
        } else {
            IERC20(token).safeTransferFrom(from, to, amount);
        }
    }
}
