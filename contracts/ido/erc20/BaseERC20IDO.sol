// SPDX-License-Identifier: WTFPL

pragma solidity 0.8.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../BaseIDO.sol";

/**
 * @notice In this IDO, the `asset` *MUST* conform to `IERC20`
 */
abstract contract BaseERC20IDO is BaseIDO {
    using SafeERC20 for IERC20;

    constructor(address _owner, Config memory config) BaseIDO(_owner, config) {
        // Empty
    }

    /**
     * @notice Transfers amount of ERC20 `asset` to `to` address. Parameter `tokenIds` is ignored.
     */
    function _offerAssets(
        address to,
        uint256[] memory,
        uint256[] memory amounts
    ) internal virtual override {
        for (uint256 i; i < amounts.length; i++) {
            IERC20(asset).safeTransferFrom(address(this), to, amounts[i]);
        }
    }

    /**
     * @notice Transfers all balance of ERC20 `asset` from `this` contract to `owner`
     */
    function _returnAssets(uint256[] memory) internal virtual override {
        IERC20(asset).safeTransfer(owner(), IERC20(asset).balanceOf(address(this)));
    }
}
