// SPDX-License-Identifier: WTFPL

pragma solidity 0.8.12;

import "./BaseERC721IDO.sol";

/**
 * @notice This ERC721 IDO schedules periodic english auctions for NFTs starting from tokenId 0
 */
contract PeriodicEnglishAuctionERC721IDO is BaseERC721IDO {
    mapping(uint256 => Auction) public auctions;

    struct Auction {
        uint64 deadline;
        uint256 currentBidId;
    }

    constructor(address _owner, Config memory config) BaseERC721IDO(_owner, config) {
        // Empty
    }

    function expired(uint256 tokenId) public view override returns (bool) {
        uint64 deadline = auctions[tokenId].deadline;
        return 0 < deadline && deadline <= uint64(block.timestamp);
    }

    /**
     * @notice
     *  `reservePrice`: the starting price of each auction
     *  `auctionDuration`: each auction is open for this seconds basically
     *  `extensionDuration`: if a bid is made within this seconds in the end of an auction, then its time is extended
     *  `minBidIncrement`: how many percentage should a new bid price be higher than the previous one
     *  `maxTokenId`: auction ends if tokenId is greater than this (0 means infinite)
     */
    function parseParams()
        public
        view
        returns (
            uint128 reservePrice,
            uint64 auctionDuration,
            uint56 extensionDuration,
            uint8 minBidIncrement,
            uint256 maxTokenId
        )
    {
        return abi.decode(params, (uint128, uint64, uint56, uint8, uint256));
    }

    function _bid(
        uint256 id,
        uint256 tokenId,
        uint128 amount
    ) internal override {
        (uint128 reservePrice, uint64 duration, uint56 extension, uint8 minBidIncrement, ) = parseParams();

        uint64 _now = uint64(block.timestamp);
        Auction storage auction = auctions[tokenId];
        uint256 _currentBidId = auction.currentBidId;
        auction.currentBidId = id;
        if (_currentBidId == 0) {
            // No bid yet for currentTokenId
            require(reservePrice <= amount, "DAOKIT: UNDERBIDDEN");

            auction.deadline = start + duration;
        } else {
            BidInfo storage info = bids[_currentBidId];
            require((info.amount * minBidIncrement) / 100 <= amount, "DAOKIT: UNDERBIDDEN");

            if (auction.deadline - extension < _now) {
                auction.deadline = _now + extension;
            }
        }

        super._bid(id, tokenId, amount);
    }

    function _claimableAsset(uint256 bidId, BidInfo memory info) internal view override returns (uint256 amount) {
        Auction storage auction = auctions[info.tokenId];
        require(auction.deadline < uint64(block.timestamp), "DAOKIT: AUCTION_NOT_FINISHED");
        require(auction.currentBidId == bidId, "DAOKIT: INVALID_BID");

        return 1;
    }

    function _updateConfig(Config memory config) internal override {
        (, uint64 auctionDuration, , uint8 minBidIncrement, ) = abi.decode(
            config.params,
            (uint128, uint64, uint56, uint8, uint256)
        );
        require(auctionDuration > 0, "DAOKIT: INVALID_AUCTION_DURATION");
        require(minBidIncrement > 0, "DAOKIT: INVALID_MIN_BID_INCREMENT");

        super._updateConfig(config);
    }
}
