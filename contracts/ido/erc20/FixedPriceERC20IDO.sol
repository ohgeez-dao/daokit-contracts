// SPDX-License-Identifier: WTFPL

pragma solidity 0.8.12;

import "./BaseERC20IDO.sol";

/**
 * @notice This ERC20 IDO always returns the same `claimableAmount` for a same `bidAmount`.
 *  (claimableAmount = bidAmount * ratio / RATIO_PRECISION)
 */
contract FixedPriceERC20IDO is BaseERC20IDO {
    uint64 public constant RATIO_PRECISION = 10 ^ 18;

    constructor(address _owner, Config memory config) BaseERC20IDO(_owner, config) {
        // Empty
    }

    /**
     * @notice How many assets will be exchange per one currency token
     */
    function parseParams() public view returns (uint64 ratio) {
        return abi.decode(params, (uint64));
    }

    function _claimableAsset(uint256, BidInfo memory info) internal view override returns (uint256 amount) {
        return (info.amount * parseParams()) / RATIO_PRECISION;
    }

    function _updateConfig(Config memory config) internal override {
        uint64 _ratio = abi.decode(config.params, (uint64));
        require(_ratio > 0, "DAOKIT: INVALID_RATIO");

        super._updateConfig(config);
    }
}
