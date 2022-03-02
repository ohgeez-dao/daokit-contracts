// SPDX-License-Identifier: WTFPL

pragma solidity 0.8.12;

import "./BaseERC1155IDO.sol";

interface IERC1155Mintable {
    function mint(
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) external;
}

/**
 * @notice In this IDO, the `asset` *MUST* conform to `IERC1155` and `IERC1155Mintable` for offering via minting.
 */
abstract contract BaseERC1155MintableIDO is BaseERC1155IDO {
    constructor(address _owner, Config memory config) BaseERC1155IDO(_owner, config) {
        // Empty
    }

    /**
     * @notice If the owner of the `tokenId` exists then transfer it otherwise mint it to `to` address from `this`
     *  contract.
     */
    function _offerAssets(
        address to,
        uint256[] memory tokenIds,
        uint256[] memory amounts
    ) internal override {
        address _asset = asset;
        for (uint256 i; i < tokenIds.length; i++) {
            IERC1155Mintable(_asset).mint(to, tokenIds[i], amounts[i], "");
        }
    }
}
