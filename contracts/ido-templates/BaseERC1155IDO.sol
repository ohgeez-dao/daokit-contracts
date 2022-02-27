// SPDX-License-Identifier: WTFPL

pragma solidity 0.8.12;

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "./BaseIDO.sol";

interface IERC1155Mintable {
    function mint(
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) external;
}

/**
 * @notice In this IDO, the `asset` *MUST* conform to `IERC1155` (and optionally `IERC1155Mintable` for offering via
 *  minting).
 */
abstract contract BaseERC1155IDO is BaseIDO {
    /**
     * @notice If the owner of the `tokenId` exists then transfer it otherwise mint it to `to` address from `this`
     *  contract.
     */
    function _offerAsset(
        address to,
        uint256 tokenId,
        uint256 amount
    ) internal override {
        address _asset = asset;
        if (IERC1155(_asset).balanceOf(address(this), tokenId) == 0) {
            IERC1155Mintable(_asset).mint(to, tokenId, amount, "");
        } else {
            IERC1155(_asset).safeTransferFrom(address(this), to, tokenId, amount, "");
        }
    }

    /**
     * @notice Transfers all balance of ERC1155 `asset` from `this` contract to `to` address
     */
    function _returnAssets(address to) internal override {
        address _asset = asset;
        IERC1155(_asset).safeTransferFrom(address(this), to, 0, IERC1155(_asset).balanceOf(address(this), 0), ""); // TODO
    }
}
