import json
from web3 import Web3, HTTPProvider

# truffle development blockchain address
ganache_blockchain_address = 'http://127.0.0.1:7545'
# Path to the compiled contract JSON file
compiled_contract_path = 'build/contracts/DeepThought.json'
# Deployed contract address (see `migrate` command output: `contract address`)
deployed_contract_address = '0x6A36E68ff85af58d84b311AdbBA83201A9Ea154E'

# Client instance to interact with the blockchain
web3 = Web3(HTTPProvider(ganache_blockchain_address))
# Set the default account (so we don't need to set the "from" for every transaction call)
web3.eth.defaultAccount = web3.eth.accounts[0]

with open(compiled_contract_path) as file:
    contract_json = json.load(file)  # load contract info as JSON
    contract_abi = contract_json['abi']  # fetch contract's abi - necessary to call its functions

# Fetch deployed contract reference
contract = web3.eth.contract(address=deployed_contract_address, abi=contract_abi)

# Transact contract function (persisted to the blockchain). For every write function use "transact"
message = contract.functions.subscribe().transact()

print(message)

# Call contract function (this is not persisted to the blockchain)
message = contract.functions.get_balance().call()

print(message)

# Call contract function (this is not persisted to the blockchain)
message = contract.functions.get_reputation().call()

print(message)

# To crate a sealed vote circa ????
#prop_id = "0"
#salt = "42"
#hashedVote = Web3.solidityKeccak(['bytes32'], prop_id + "VoteOption.True" + salt)