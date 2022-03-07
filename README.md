# DAOKit Contracts

[![License: WTFPL](http://www.wtfpl.net/wp-content/uploads/2012/12/wtfpl-badge-3.png)](http://www.wtfpl.net/)

This project provides a proper set of tools to solve problems of current DAOs.

## Problems of current DAOs
1. Treasury is controlled by only a few people (core team)
2. Salary/grant payout from treasury isn’t managed transparently
3. Progress of each sub-project isn’t tracked on-chain
4. Role/duty of each member is unclear & their performance isn't checked on-chain

## To-do
- [x] Core team can start a fundraising choosing between `FixedPriceSale`, `EnglishAuction` or `DxutchAuction`
- [x] Anyone can buy DAO tokens with ETH(or native coin)
- [x] If fundraising succeeded, participants can withdraw DAO tokens
- [x] If fundraising failed, participants can be refunded their ETH(or native coin)
- [] Raised fund can be sent to DAO treasury
- [ ] Raised fund can be used to add liquidity combined with equivalent worth DAO tokens
- [x] Core team can add/remove members or change quorum with a delay (min. 1 day) with signatures >= quorum
- [x] Core team can queue a tx from the treasury with a delay (min. 1 day) with signatures >= quorum
- [x] Core team can cancel a tx that was queued with signatures >= quorum
- [x] Core team can start or stop vesting contracts
- [x] Anyone can execute a tx that was queued and has passed the eta
- [x] Committee can cancel a queued tx with signatures >= quorum
- [x] Committee can add/remove tx filter with signatures >= quorum (to disallow certain intention of core team)
- [ ] Add various transaction filters (which tokens to disallow, how much amount to limit)
- [x] DAO community can propose a vote to add/remove committee members or change quorum
- [ ] DAO community can propose a vote to remove core team members
- [x] DAO community can cast a vote with tokens locked up until the end of the vote
- [x] Anyone can execute a proposal if it passed the quorum and vote succeeded
- [ ] Contractors should periodically submit the progress of the project
- [ ] Committee can stop a vesting contract if the contractor isn't fulfilling their duty

## License

Distributed under the WTFPL License. See `LICENSE` for more information.

## Contact

* [LevX](https://twitter.com/LevxApp/)
