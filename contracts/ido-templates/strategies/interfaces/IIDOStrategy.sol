// SPDX-License-Identifier: WTFPL

pragma solidity >=0.5.0;

import "@openzeppelin/contracts/utils/introspection/ERC165.sol";

interface IIDOStrategy is IERC165 {
    function claimableAsset(uint256 enrollAmount, uint64 lastTimestamp)
        external
        view
        returns (uint256 claimableTokenId, uint256 claimableAmount);
}
