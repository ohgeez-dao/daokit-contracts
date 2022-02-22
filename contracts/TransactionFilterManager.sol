// SPDX-License-Identifier: WTFPL

pragma solidity 0.8.12;

contract TransactionFilterManager {
    address[] public transactionFilters;

    event AddTransactionFilter(address indexed filter);
    event RemoveTransactionFilter(address indexed filter);

    /**
     * @notice This can be called by owner(`CommitteeGovernance`) to add a transaction filter. By adding a transaction
     * filter, owner can make transactions with specific `target` or `data` to fail.
     */
    function _addTransactionFilter(address filter) internal {
        transactionFilters.push(filter);

        emit AddTransactionFilter(filter);
    }

    /**
     * @notice This can be called by owner(`CommitteeGovernance`) to remove a transaction filter
     */
    function _removeTransactionFilter(address filter) internal {
        for (uint256 i; i < transactionFilters.length; i++) {
            if (transactionFilters[i] == filter) {
                transactionFilters[i] = transactionFilters[transactionFilters.length - 1];
                transactionFilters.pop();

                emit RemoveTransactionFilter(filter);
                return;
            }
        }
        revert("DAOKIT: INVALID_FILTER");
    }
}
