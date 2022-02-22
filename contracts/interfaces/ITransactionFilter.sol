// SPDX-License-Identifier: WTFPL

pragma solidity >=0.5.0;

interface ITransactionFilter {
    function shouldRejectTransaction(
        address target,
        uint256 value,
        string calldata signature,
        bytes calldata data
    ) external view returns (bool rejected);
}
