// SPDX-License-Identifier: WTFPL

pragma solidity 0.8.12;

import "./interfaces/IIDOStrategy.sol";

abstract contract BaseStrategy is IIDOStrategy {
    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == type(IERC165).interfaceId || interfaceId == type(IIDOStrategy).interfaceId;
    }
}
