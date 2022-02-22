// SPDX-License-Identifier: WTFPL

pragma solidity 0.8.12;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/ITransactionFilter.sol";
import "./CoreTeamGovernance.sol";
import "./TransactionFilterManager.sol";

contract DAOWallet is CoreTeamGovernance, TransactionFilterManager, Ownable {
    constructor(
        address _owner,
        uint64 _delay,
        uint128 _coreTeamQuorum,
        address[] memory _coreMembers
    ) CoreTeamGovernance(_delay, _coreTeamQuorum, _coreMembers) {
        _transferOwnership(_owner);
    }

    receive() external payable {
        // Empty
    }

    function addTransactionFilter(address filter) external onlyOwner {
        _addTransactionFilter(filter);
    }

    function removeTransactionFilter(address filter) external onlyOwner {
        _removeTransactionFilter(filter);
    }

    function _queueTransaction(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint64 eta
    ) internal override returns (bytes32) {
        for (uint256 i; i < transactionFilters.length; i++) {
            bool rejected = ITransactionFilter(transactionFilters[i]).shouldRejectTransaction(
                target,
                value,
                signature,
                data
            );
            require(!rejected, "DAOKIT: TRANSACTION_REJECTED");
        }
        return super._queueTransaction(target, value, signature, data, eta);
    }

    /**
     * @notice This can be called by owner(`CommitteeGovernance`) to cancel a queued transaction
     */
    function cancelTransaction(
        address target,
        uint256 value,
        string calldata signature,
        bytes calldata data,
        uint64 eta
    ) external onlyOwner {
        _cancelTransaction(target, value, signature, data, eta);
    }
}
