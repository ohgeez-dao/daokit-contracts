// SPDX-License-Identifier: WTFPL

pragma solidity 0.8.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./BaseIDO.sol";

/**
 * @notice In this IDO, the `asset` *MUST* conform to `IERC20`
 */
contract ERC20IDO is BaseIDO {
    using SafeERC20 for IERC20;

    constructor(address _owner, Config memory config) BaseIDO(_owner, config) {
        // Empty
    }

    /**
     * @notice Transfers `amount` of ERC20 `currency` to `to` address. Parameter `tokenId` is ignored.
     */
    function _offerAsset(
        address to,
        uint256,
        uint256 amount
    ) internal override {
        IERC20(asset).safeTransferFrom(address(this), to, amount);
    }

    /**
     * @notice Transfers all balance of ERC20 `asset` from `this` contract to `to` address
     */
    function _returnAssets(address to, uint256[] memory) internal override {
        address _currency = currency;
        IERC20(_currency).safeTransfer(to, IERC20(_currency).balanceOf(address(this)));
    }
}
