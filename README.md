# Oracle's Blockchain Research Project

https://codeburst.io/deploy-a-smart-contract-using-python-how-to-b62de0124b
https://eth-brownie.readthedocs.io/en/stable/quickstart.html

# token-mix

A bare-bones implementation of the Ethereum [ERC-20 standard](https://eips.ethereum.org/EIPS/eip-20), written in [Solidity](https://github.com/ethereum/solidity).

For [Vyper](https://github.com/vyperlang/vyper), check out [`vyper-token-mix`](https://github.com/brownie-mix/vyper-token-mix).

## Installation

1. [Install Brownie](https://eth-brownie.readthedocs.io/en/stable/install.html), if you haven't already.

2. Download the mix.

    ```bash
    brownie bake token
    ```

## Basic Use

This mix provides a [simple template](contracts/Token.sol) upon which you can build your own token, as well as unit tests providing 100% coverage for core ERC20 functionality.

To interact with a deployed contract in a local environment, start by opening the console:

```bash
brownie console
```

Next, deploy a test token:

```python
>>> token = Token.deploy("Test Token", "TST", 18, 1e21, {'from': accounts[0]})

Transaction sent: 0x4a61edfaaa8ba55573603abd35403cf41291eca443c983f85de06e0b119da377
  Gas price: 0.0 gwei   Gas limit: 12000000
  Token.constructor confirmed - Block: 1   Gas used: 521513 (4.35%)
  Token deployed at: 0xd495633B90a237de510B4375c442C0469D3C161C
```

You now have a token contract deployed, with a balance of `1e21` assigned to `accounts[0]`:

```python
>>> token
<Token Contract '0xd495633B90a237de510B4375c442C0469D3C161C'>

>>> token.balanceOf(accounts[0])
1000000000000000000000

>>> token.transfer(accounts[1], 1e18, {'from': accounts[0]})
Transaction sent: 0xb94b219148501a269020158320d543946a4e7b9fac294b17164252a13dce9534
  Gas price: 0.0 gwei   Gas limit: 12000000
  Token.transfer confirmed - Block: 2   Gas used: 51668 (0.43%)

<Transaction '0xb94b219148501a269020158320d543946a4e7b9fac294b17164252a13dce9534'>
```

## Testing

To run the tests:

```bash
brownie test
```

The unit tests included in this mix are very generic and should work with any ERC20 compliant smart contract. To use them in your own project, all you must do is modify the deployment logic in the [`tests/conftest.py::token`](tests/conftest.py) fixture.

## Resources

To get started with Brownie:

* Check out the other [Brownie mixes](https://github.com/brownie-mix/) that can be used as a starting point for your own contracts. They also provide example code to help you get started.
* ["Getting Started with Brownie"](https://medium.com/@iamdefinitelyahuman/getting-started-with-brownie-part-1-9b2181f4cb99) is a good tutorial to help you familiarize yourself with Brownie.
* For more in-depth information, read the [Brownie documentation](https://eth-brownie.readthedocs.io/en/stable/).


Any questions? Join our [Gitter](https://gitter.im/eth-brownie/community) channel to chat and share with others in the community.

## License

This project is licensed under the [MIT license](LICENSE).


### W.I.P. ORACLE STRUCTURE

```
Oracle interface {

    # proposition structure (id, text, stage, tags, bounty)
    # vote structure (id, address, sealedVote, unsealedVote)
    # other if necessary
    
    # certifiersPool
    # propositionList
    # votesForPropositionMap
    # certificationForPropositionMap
    # poolForPropositionMap
    # playersScoresForTag

    -   submitProposition(senderAddress, propositionID, propositionText, TTL, bounty)

    -   closeProposition(senderAddress, propositionID) ← after this voters have to unseal their votes, then the votes are weighted and we get result, then the rewards and reputation are distributed

    -   getPropositionList()

    -   certifyProposition(certifierAddress, propositionID, sealedVote, stake)

    -   ??se la puntata supera il bounty va tagliata e gli viene restituito il resto??

    -   stakeToVote(voterAddress, stake) ← now this address can vote

    -   getPropositionToVote(voterAddress) ← consume the stake and get proposition

    -   voteProposition(voterAddress, propositionID, sealedVote)

    -   unsealVote(voteId, keyword) ← for this example we can use unsealed votes and assume that the sealing vote procedure will be implemented in the future

    ….all the calculation methods for min and max stakes
        smin-voters dipende da reputation
        smax-voters dipende da bounty
        smin-certificanti = smax-voters + smin-voters
        smax-certificanti =smin-cert + qualcosa che dipende dal certifier pool

    ….all the calculation for distritbuting the rewards
        monetary rewards always >= 0 (superlinear sublinear like BRAINS)
        certifiers always get the reward first (from pool if there is a pool, or they get priority over voters when the stake is divided)

    ….all the calculation for updating reputation
        reputation starts at 1 for each topic and simply get decreased/incremented

}
```
