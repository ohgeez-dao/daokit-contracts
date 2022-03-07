// SPDX-License-Identifier: WTFPL

pragma solidity 0.8.12;

import "./BaseERC721IDO.sol";

/**
 * @notice This ERC721 IDO schedules periodic english auctions for NFTs starting from tokenId 0
 */
contract PeriodicEnglishAuctionERC721IDO is BaseERC721IDO {
    uint256 public constant INVALID_TOKEN_ID = type(uint256).max;

    mapping(uint256 => uint64) public deadline;
    mapping(uint256 => uint256) public currentBidId;
    uint256 internal _tokenId;

    constructor(address _owner, Config memory config) BaseERC721IDO(_owner, config) {
        // Empty
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

    function currentTokenId() public view returns (uint256) {
        uint256 tokenId = _tokenId;
        return tokenId + deadline[tokenId] < uint64(block.timestamp) ? 1 : 0;
    }

    function _bid(uint256 id, uint128 amount) internal override {
        (uint128 reservePrice, uint64 auction, uint56 extension, uint8 minBidIncrement, ) = parseParams();

        uint64 timestamp = uint64(block.timestamp);
        uint256 tokenId = _tokenId;
        if (deadline[tokenId] < timestamp) {
            tokenId += 1;
            _tokenId = tokenId;
            deadline[tokenId] = timestamp + auction;
        }
        uint256 _currentBidId = currentBidId[tokenId];
        if (_currentBidId == 0) {
            // No bid yet for currentTokenId
            require(reservePrice <= amount, "DAOKIT: UNDERBIDDEN");
        } else {
            BidInfo storage info = bids[_currentBidId];
            require((info.amount * minBidIncrement) / 100 <= amount, "DAOKIT: UNDERBIDDEN");

            if (deadline[tokenId] - extension < timestamp) {
                deadline[tokenId] = timestamp + extension;
            }
        }

        currentBidId[tokenId] = id;

        super._bid(id, amount);
    }

    function _claim(uint256 bidId, BidInfo storage info) internal override returns (uint256 tokenId, uint256 amount) {
        require(currentBidId[_tokenId] == bidId, "DAOKIT: INVALID_BID");
        // TODO: check if tokenId's auction finished

        return super._claim(bidId, info);
    }

    /**
     * @notice Param `bidAmount` is ignored.
     */
    function _claimableAsset(uint128, uint64 timestamp)
        internal
        view
        override
        returns (uint256 claimableTokenId, uint256 claimableAmount)
    {
        return (currentBidId[_tokenId], 0); // TODO
    }

    function _updateConfig(Config memory config) internal override {
        super._updateConfig(config);
    }
}
