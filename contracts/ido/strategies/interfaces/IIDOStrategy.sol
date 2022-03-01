// SPDX-License-Identifier: WTFPL

pragma solidity >=0.5.0;

import "@openzeppelin/contracts/utils/introspection/ERC165.sol";

interface IIDOStrategy is IERC165 {
    function isValidData(bytes memory data) external view returns (bool);

    function claimableAsset(
        bytes memory data,
        uint256 enrollAmount,
        uint64 timestamp
    ) external view returns (uint256 claimableTokenId, uint256 claimableAmount);
}
