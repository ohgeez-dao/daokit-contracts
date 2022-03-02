// SPDX-License-Identifier: WTFPL

pragma solidity 0.8.12;

import "./BaseERC20IDO.sol";

/**
 * @notice This ERC20 IDO always returns the same `claimableAmount` for a same `enrollAmount`.
 *  (claimableAmount = enrollAmount * ratio / RATIO_PRECISION)
 */
contract FixedPriceERC20IDO is BaseERC20IDO {
    uint64 public constant RATIO_PRECISION = 10 ^ 18;

    constructor(address _owner, Config memory config) BaseERC20IDO(_owner, config) {
        // Empty
    }

    /**
     * @notice How many assets will be exchange per one currency token
     */
    function ratio() public view returns (uint64) {
        return abi.decode(data, (uint64));
    }

    /**
     * @notice Param `timestamp` is ignored.
     */
    function _claimableAsset(uint128 enrollAmount, uint64)
        internal
        view
        override
        returns (uint256 claimableTokenId, uint256 claimableAmount)
    {
        return (0, (enrollAmount * ratio()) / RATIO_PRECISION);
    }

    function _updateConfig(Config memory config) internal override {
        uint64 _ratio = abi.decode(config.data, (uint64));
        require(_ratio > 0, "DAOKIT: INVALID_RATIO");

        super._updateConfig(config);
    }
}
