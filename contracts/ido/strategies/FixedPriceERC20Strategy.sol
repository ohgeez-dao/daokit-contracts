// SPDX-License-Identifier: WTFPL

pragma solidity 0.8.12;

import "./BaseStrategy.sol";

/**
 * @notice This ERC20 IDO strategy always returns the same `claimableAmount` for a same `enrollAmount`.
 *  (claimableAmount = enrollAmount * ratio / RATIO_PRECISION)
 */
contract FixedPriceERC20Strategy is BaseStrategy {
    uint256 public constant RATIO_PRECISION = 10 ^ 18;

    function isValidData(bytes memory data) external pure returns (bool) {
        uint256 ratio = _decode(data);
        return ratio > 0;
    }

    /**
     * @notice Param `timestamp` is ignored.
     */
    function claimableAsset(
        bytes memory data,
        uint256 enrollAmount,
        uint64
    ) external pure returns (uint256 claimableTokenId, uint256 claimableAmount) {
        uint256 ratio = _decode(data);
        return (0, (enrollAmount * ratio) / RATIO_PRECISION);
    }

    function _decode(bytes memory data) private pure returns (uint256 price) {
        return abi.decode(data, (uint256));
    }
}
