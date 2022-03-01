// SPDX-License-Identifier: WTFPL

pragma solidity 0.8.12;

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "./BaseIDO.sol";

/**
 * @notice In this IDO, the `asset` *MUST* conform to `IERC1155`.
 */
contract ERC1155IDO is BaseIDO {
    constructor(address _owner, Config memory config) BaseIDO(_owner, config) {
        // Empty
    }

    /**
     * @notice Transfers `asset`s of `tokenIds` to `to` address from `this` contract.
     */
    function _offerAssets(
        address to,
        uint256[] memory tokenIds,
        uint256[] memory amounts
    ) internal virtual override {
        IERC1155(asset).safeBatchTransferFrom(address(this), to, tokenIds, amounts, "");
    }

    /**
     * @notice Transfers all balance of ERC1155 `asset` from `this` contract to `owner`
     */
    function _returnAssets(uint256[] memory tokenIds) internal virtual override {
        address _asset = asset;
        address[] memory accounts = new address[](tokenIds.length);
        for (uint256 i; i < tokenIds.length; i++) {
            accounts[i] = address(this);
        }
        uint256[] memory amounts = IERC1155(_asset).balanceOfBatch(accounts, tokenIds);
        IERC1155(_asset).safeBatchTransferFrom(address(this), owner(), tokenIds, amounts, "");
    }
}
