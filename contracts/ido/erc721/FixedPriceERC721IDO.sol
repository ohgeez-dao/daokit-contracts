// SPDX-License-Identifier: WTFPL

pragma solidity 0.8.12;

import "./BaseERC721MintableIDO.sol";

/**
 * @notice In this ERC721 IDO, every NFT is sold in same price.
 */
contract FixedPriceERC721IDO is BaseERC721MintableIDO {
    mapping(uint256 => bool) public soldOut;

    constructor(address _owner, Config memory config) BaseERC721MintableIDO(_owner, config) {
        // Empty
    }

    /**
     * @notice How many assets will be exchange per one currency token
     */
    function parseParams() public view returns (uint128 ratio) {
        return abi.decode(params, (uint128));
    }

    function _bid(
        uint256 id,
        uint256 tokenId,
        uint128 amount
    ) internal override {
        require(started(), "DAOKIT: NOT_STARTED");
        require(!finished(), "DAOKIT: FINISHED");
        require(!soldOut[tokenId], "DAOKIT: SOLD_OUT");

        bids.push(); // Add empty BidInfo to increase bid id

        uint128 price = parseParams();
        require(amount == price, "DAOKIT: INVALID_AMOUNT");

        totalRaised += price;
        soldOut[tokenId] = true;
        emit Bid(id, msg.sender, tokenId, price);
        _pullCurrency(price);

        emit Claim(id, msg.sender, tokenId, 1);
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = tokenId;
        _offerAssets(msg.sender, tokenIds, new uint256[](1));
    }

    function _claimableAsset(uint256, BidInfo memory) internal pure override returns (uint256 amount) {
        return 0; // Break claim() on purpose
    }

    function _updateConfig(Config memory config) internal override {
        uint64 _ratio = abi.decode(config.params, (uint64));
        require(_ratio > 0, "DAOKIT: INVALID_RATIO");

        super._updateConfig(config);
    }
}
