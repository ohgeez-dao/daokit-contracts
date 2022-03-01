// SPDX-License-Identifier: WTFPL

pragma solidity 0.8.12;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "./BaseIDO.sol";

/**
 * @notice In this IDO, the `asset` *MUST* conform to `IERC721`.
 */
contract ERC721IDO is BaseIDO {
    constructor(address _owner, Config memory config) BaseIDO(_owner, config) {
        // Empty
    }

    /**
     * @notice Transfers `asset`s of `tokenIds` to `to` address from `this` contract. Parameter `amounts` is ignored.
     */
    function _offerAssets(
        address to,
        uint256[] memory tokenIds,
        uint256[] memory
    ) internal virtual override {
        address _asset = asset;
        for (uint256 i; i < tokenIds.length; i++) {
            IERC721(_asset).safeTransferFrom(address(this), to, tokenIds[i]);
        }
    }

    /**
     * @notice Transfers all balance of ERC721 `asset` from `this` contract to `owner`
     */
    function _returnAssets(uint256[] memory tokenIds) internal virtual override {
        address _asset = asset;
        for (uint256 i; i < tokenIds.length; i++) {
            IERC721(_asset).safeTransferFrom(address(this), owner(), tokenIds[i]);
        }
    }
}
