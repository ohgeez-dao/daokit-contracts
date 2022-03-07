// SPDX-License-Identifier: WTFPL

pragma solidity 0.8.12;

import "./BaseERC721IDO.sol";

/**
 * @notice This ERC721 IDO processes multiple english auctions for NFTs at the same time
 */
contract ConcurrentEnglishAuctionERC721IDO is BaseERC721IDO {
    mapping(uint256 => uint256) public currentBidId;

    constructor(address _owner, Config memory config) BaseERC721IDO(_owner, config) {
        // Empty
    }

    /**
     * @notice
     *  `reservePrice`: the starting price of each auction
     *  `minBidIncrement`: how many percentage should a new bid price be higher than the previous one
     *  `maxTokenId`: auction ends if tokenId is greater than this (0 means infinite)
     */
    function parseParams()
        public
        view
        returns (
            uint128 reservePrice,
            uint8 minBidIncrement,
            uint256 maxTokenId
        )
    {
        return abi.decode(params, (uint128, uint8, uint256));
    }

    function _bid(
        uint256 id,
        uint256 tokenId,
        uint128 amount
    ) internal override {
        (uint128 reservePrice, uint8 minBidIncrement, uint256 maxTokenId) = parseParams();
        require(tokenId < maxTokenId, "DAOKIT: INVALID_TOKEN_ID");

        uint256 _currentBidId = currentBidId[tokenId];
        currentBidId[tokenId] = id;
        if (_currentBidId == 0) {
            // No bid yet for currentTokenId
            require(reservePrice <= amount, "DAOKIT: UNDERBIDDEN");
        } else {
            BidInfo storage info = bids[_currentBidId];
            require((info.amount * minBidIncrement) / 100 <= amount, "DAOKIT: UNDERBIDDEN");
        }

        super._bid(id, tokenId, amount);
    }

    function _claimableAsset(uint256 bidId, BidInfo memory info) internal view override returns (uint256 amount) {
        require(currentBidId[info.tokenId] == bidId, "DAOKIT: INVALID_BID");

        return 1;
    }

    function _updateConfig(Config memory config) internal override {
        (, uint8 minBidIncrement, ) = abi.decode(config.params, (uint128, uint8, uint256));
        require(minBidIncrement > 0, "DAOKIT: INVALID_MIN_BID_INCREMENT");

        super._updateConfig(config);
    }
}
