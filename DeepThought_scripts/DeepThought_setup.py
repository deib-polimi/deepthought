import json
from web3 import Web3, HTTPProvider

# truffle development blockchain address
ganache_blockchain_address = 'http://127.0.0.1:7545'
# Path to the compiled contract JSON file
compiled_contract_path = '../build/contracts/DeepThought.json'
# Deployed contract address (see `migrate` command output: `contract address`)
deployed_contract_address = '0xfC17361df08A02728b59925C9c39B80869aF13Eb'

def init():

    # Client instance to interact with the blockchain
    web3 = Web3(HTTPProvider(ganache_blockchain_address))

    with open(compiled_contract_path) as file:
        contract_json = json.load(file)  # load contract info as JSON
        contract_abi = contract_json['abi']  # fetch contract's abi - necessary to call its functions

    # Fetch deployed contract reference
    contract = web3.eth.contract(address=deployed_contract_address, abi=contract_abi)
    return web3, contract


def test_init(n_max_votes, alfa, beta):
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
    tx_hash = contract.constructor(n_max_votes, alfa, beta).transact()
    tx_receipt = web3.eth.waitForTransactionReceipt(tx_hash)
    address = tx_receipt.contractAddress
    contract = web3.eth.contract(address=address, abi=contract_abi)
    return web3, contract
