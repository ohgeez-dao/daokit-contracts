// SPDX-License-Identifier: WTFPL

pragma solidity 0.8.12;

import "./BaseERC20IDO.sol";

contract DutchAuctionERC20IDO is BaseERC20IDO {
    uint64 public constant RATIO_PRECISION = 10 ^ 18;

    uint64 public finalRatio;

    constructor(address _owner, Config memory config) BaseERC20IDO(_owner, config) {
        // Empty
    }

    /**
     * @notice How many assets will be exchange per one currency token in the beginning and in the end
     */
    function parseParams() public view returns (uint64 initialRatio, uint64 reserveRatio) {
        return abi.decode(params, (uint64, uint64));
    }

    function finished() public view override returns (bool) {
        return expired() || hardCap <= _weightedTotalAmount();
    }

    function _claimableAsset(uint128 bidAmount, uint64)
        internal
        view
        override
        returns (uint256 claimableTokenId, uint256 claimableAmount)
    {
        return (0, (uint256(bidAmount) * finalRatio) / RATIO_PRECISION);
    }

    function _updateConfig(Config memory config) internal override {
        require(config.hardCap > 0, "DAOKIT: HARD_CAP_TOO_LOW");

        (uint64 initialRatio, uint64 reserveRatio) = abi.decode(config.params, (uint64, uint64));
        require(0 < initialRatio, "DAOKIT: INVALID_INITIAL_RATIO");
        require(initialRatio < reserveRatio, "DAOKIT: INVALID_RESERVE_RATIO");

        super._updateConfig(config);
    }

    function _bid(uint128 amount) internal override {
        super._bid(amount);

        finalRatio = _ratioAt(uint64(block.timestamp));
    }

    function _amountAvailable(address account, uint128 amount) internal view override returns (uint128) {
        uint128 amountAvailable = super._amountAvailable(account, amount);
        uint128 weightedTotalAmount = _weightedTotalAmount();
        uint128 _hardCap = hardCap;
        if (_hardCap <= weightedTotalAmount) {
            return 0;
        } else if (_hardCap - weightedTotalAmount < amountAvailable) {
            return amountAvailable - _hardCap + weightedTotalAmount;
        } else {
            return amountAvailable;
        }
    }

    function _weightedTotalAmount() private view returns (uint128) {
        return uint128((uint256(totalAmount) * _ratioAt(uint64(block.timestamp))) / RATIO_PRECISION);
    }

    function _ratioAt(uint64 timestamp) private view returns (uint64) {
        (uint64 initialRatio, uint64 reserveRatio) = parseParams();
        if (timestamp <= start) {
            return initialRatio;
        } else if (start + duration <= timestamp) {
            return reserveRatio;
        } else {
            uint64 delta = reserveRatio - initialRatio;
            uint64 elapsed = timestamp - start;
            return initialRatio + (delta * elapsed) / duration;
        }
    }
}
