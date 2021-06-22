# Oracle's Blockchain Research Project

- https://dev.to/gcrsaldanha/deploy-a-smart-contract-on-ethereum-with-python-truffle-and-web3py-5on
- https://dev.to/gcrsaldanha/persist-data-to-the-ethereum-blockchain-using-python-truffle-and-ganache-47lb

To compile:
```
truffle compile
```

To compile and deploy the contract (remember to check the address in truffle-config.js to match the Ganache one)
```
truffle migrate
```

Copy and past `truffle migrate` command output: `contract address` into the setup.py code (update the `deployed_contract_address` value).

To execute stuff (remember to check blockchain and contract addresses to match the Ganache ones)
```
python app.py
```