// SPDX-License-Identifier: WTFPL

pragma solidity 0.8.12;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import "./BaseIDO.sol";

interface IERC721Mintable {
    function mint(address to, uint256 tokenId) external;
}

/**
 * @notice In this IDO, the `asset` *MUST* conform to `IERC721` and `IERC721Enumeralbe` (and optionally
 *  `IERC721Mintable` for offering via minting).
 */
abstract contract BaseERC721IDO is BaseIDO {
    /**
     * @notice If the owner of the `tokenId` exists then transfer it otherwise mint it to `to` address from `this`
     *  contract. Parameter `amount` is ignored.
     */
    function _offerAsset(
        address to,
        uint256 tokenId,
        uint256
    ) internal override {
        address _asset = asset;
        if (IERC721(_asset).ownerOf(tokenId) == address(0)) {
            IERC721Mintable(_asset).mint(to, tokenId);
        } else {
            IERC721(_asset).safeTransferFrom(address(this), to, tokenId);
        }
    }

    /**
     * @notice Transfers all balance of ERC721 `asset` from `this` contract to `to` address
     */
    function _returnAssets(address to) internal override {
        address _asset = asset;
        uint256 balance = IERC721(_asset).balanceOf(address(this));
        for (uint256 i; i < balance; i++) {
            uint256 tokenId = IERC721Enumerable(_asset).tokenOfOwnerByIndex(address(this), i);
            IERC721(_asset).safeTransferFrom(address(this), to, tokenId);
        }
    }
}
