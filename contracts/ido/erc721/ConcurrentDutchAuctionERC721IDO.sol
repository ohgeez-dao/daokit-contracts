// SPDX-License-Identifier: WTFPL

pragma solidity 0.8.12;

import "./BaseERC721IDO.sol";

/**
 * @notice This ERC721 IDO processes multiple dutch auctions for NFTs at the same time
 */
contract ConcurrentDutchAuctionERC721IDO is BaseERC721IDO {
    mapping(uint256 => uint128) public finalPrice;

    constructor(address _owner, Config memory config) BaseERC721IDO(_owner, config) {
        // Empty
    }

    /**
     * @notice
     *  `initialPrice`: the starting price of each auction
     *  `reservePrice`: the starting price of each auction
     *  `maxTokenId`: auction ends if tokenId is greater than this (0 means infinite)
     */
    function parseParams()
        public
        view
        returns (
            uint64 initialPrice,
            uint64 reservePrice,
            uint256 maxTokenId
        )
    {
        return abi.decode(params, (uint64, uint64, uint256));
    }

    function _updateConfig(Config memory config) internal override {
        (uint128 initialPrice, uint128 reservePrice, uint256 maxTokenId) = abi.decode(
            config.params,
            (uint128, uint128, uint256)
        );
        require(0 < initialPrice, "DAOKIT: INVALID_INITIAL_PRICE");
        require(reservePrice < initialPrice, "DAOKIT: INVALID_RESERVE_PRICE");
        require(maxTokenId > 0, "DAOKIT: INVALID_MAX_TOKEN_ID");

        super._updateConfig(config);
    }

    function finished(uint256 tokenId) public view override returns (bool) {
        return expired(tokenId) || finalPrice[tokenId] > 0;
    }

    function _bid(
        uint256 id,
        uint256 tokenId,
        uint128 amount
    ) internal override {
        require(amount > 0, "DAOKIT: INVALID_AMOUNT");
        require(started(tokenId), "DAOKIT: NOT_STARTED");
        require(!finished(tokenId), "DAOKIT: FINISHED");

        (, , uint256 maxTokenId) = parseParams();
        require(tokenId < maxTokenId, "DAOKIT: INVALID_TOKEN_ID");

        uint128 price = _priceAt(uint64(block.timestamp));
        totalRaised += price;
        finalPrice[tokenId] = price;
        emit Bid(id, msg.sender, tokenId, price);
        _transferCurrency(price);

        emit Claim(id, msg.sender, tokenId, 1);
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = tokenId;
        _offerAssets(msg.sender, tokenIds, new uint256[](1));
    }

    function _claimableAsset(uint256, BidInfo memory) internal pure override returns (uint256 amount) {
        return 0; // Break claim() on purpose
    }

    function _priceAt(uint64 timestamp) private view returns (uint128) {
        (uint128 initialPrice, uint128 reservePrice, ) = parseParams();
        if (timestamp <= start) {
            return initialPrice;
        } else if (start + duration <= timestamp) {
            return reservePrice;
        } else {
            uint128 delta = reservePrice - initialPrice;
            uint128 elapsed = timestamp - start;
            return initialPrice + (delta * elapsed) / duration;
        }
    }
}
