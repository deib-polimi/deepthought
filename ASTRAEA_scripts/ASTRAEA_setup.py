import json
from web3 import Web3, HTTPProvider

# truffle development blockchain address
ganache_blockchain_address = 'http://127.0.0.1:7545'
# Path to the compiled contract JSON file
compiled_contract_path = '../build/contracts/ASTRAEA.json'
# Deployed contract address (see `migrate` command output: `contract address`)
deployed_contract_address = '0x6aEe96064Ba720cd58A218c7E52ea6cF091D5282'


''' Use when constructor has not parameters '''
def init():

    # Client instance to interact with the blockchain
    web3 = Web3(HTTPProvider(ganache_blockchain_address, request_kwargs={'timeout': 100}))

    with open(compiled_contract_path) as file:
        contract_json = json.load(file)  # load contract info as JSON
        contract_abi = contract_json['abi']  # fetch contract's abi - necessary to call its functions

    # Fetch deployed contract reference
    contract = web3.eth.contract(address=deployed_contract_address, abi=contract_abi)
    return web3, contract


''' Use it to pass the parameters to the constructor '''
def set(voter_stake_max, cert_target, closing_voting_stake, certifier_stake_min):
    # truffle development blockchain address

    # Client instance to interact with the blockchain
    web3 = Web3(HTTPProvider(ganache_blockchain_address,  request_kwargs={'timeout': 500}))

    with open(compiled_contract_path) as file:
        contract_json = json.load(file)  # load contract info as JSON
        contract_abi = contract_json['abi']  # fetch contract's abi - necessary to call its functions
        contract_bytecode = contract_json['bytecode']

    # Fetch deployed contract reference
    contract = web3.eth.contract(bytecode=contract_bytecode, abi=contract_abi)
    web3.eth.defaultAccount = web3.eth.accounts[0]
    tx_hash = contract.constructor(voter_stake_max, cert_target, closing_voting_stake, certifier_stake_min).transact()
    tx_receipt = web3.eth.waitForTransactionReceipt(tx_hash)
    address = tx_receipt.contractAddress
    contract = web3.eth.contract(address=address, abi=contract_abi)
    return web3, contract
