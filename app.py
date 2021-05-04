import json
from web3 import Web3, HTTPProvider

# truffle development blockchain address
blockchain_address = 'http://127.0.0.1:7545'
# Client instance to interact with the blockchain
web3 = Web3(HTTPProvider(blockchain_address))
# Set the default account (so we don't need to set the "from" for every transaction call)
web3.eth.defaultAccount = web3.eth.accounts[0]

# Path to the compiled contract JSON file
compiled_contract_path = 'build/contracts/DeepThought.json'
# Deployed contract address (see `migrate` command output: `contract address`)
deployed_contract_address = '0x7983684267FDCB1Bb92c1bC24BF9F5D32F1DEabb'

with open(compiled_contract_path) as file:
    contract_json = json.load(file)  # load contract info as JSON
    contract_abi = contract_json['abi']  # fetch contract's abi - necessary to call its functions

# Fetch deployed contract reference
contract = web3.eth.contract(address=deployed_contract_address, abi=contract_abi)

# Call contract function (this is not persisted to the blockchain)
message = contract.functions.sayHello().call()

print(message)

# To crate a sealed vote circa ????
#prop_id = "0"
#salt = "42"
#hashedVote = Web3.solidityKeccak(['bytes32'], prop_id + "VoteOption.True" + salt)