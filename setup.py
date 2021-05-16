import json
from web3 import Web3, HTTPProvider

# truffle development blockchain address
ganache_blockchain_address = 'http://127.0.0.1:7545'
# Path to the compiled contract JSON file
compiled_contract_path = 'build/contracts/DeepThought.json'
# Deployed contract address (see `migrate` command output: `contract address`)
deployed_contract_address = '0xA5C9701b9634f613F6f77815C99F8f7b142FC211'

def init():

    # Client instance to interact with the blockchain
    web3 = Web3(HTTPProvider(ganache_blockchain_address))

    with open(compiled_contract_path) as file:
        contract_json = json.load(file)  # load contract info as JSON
        contract_abi = contract_json['abi']  # fetch contract's abi - necessary to call its functions

    # Fetch deployed contract reference
    contract = web3.eth.contract(address=deployed_contract_address, abi=contract_abi)
    return web3, contract