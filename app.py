import os
import sys

from web3 import Web3
import setup

def main():

    # SMART CONTRACT SETUP

    print("DEEP THOUGHT")

    web3, contract = setup.init()

    # Set the default account (so we don't need to set the "from" for every transaction call)
    index = int(input('insert your account index: '))
    web3.eth.defaultAccount = web3.eth.accounts[index]

    # CLI

    while 1:
        
        insert = int(input('MAIN PAGE - HOW DO YOU WANT TO CONTINUE?\n1 - subscribe\n2 - sign in\n3 - quit\n'))

        if insert == 3:

            break

        elif insert == 1:

            # Transact contract function (persisted to the blockchain). For every write function use "transact"
            contract.functions.subscribe().transact()
            print("now you are subscribed")
        
        else :

            while 1:

                insert = int (input ('WHO YOU ARE?\n1 - certifier\n2 - voter\n3 - submitter\n4 - go back to main page\n'))

                if insert == 4:

                    break

                elif insert == 1:

                    print(web3.fromWei(int(contract.functions.get_balance().call()) * (10 ** 6), 'ether'))

                elif input == 3:

                    print(web3.fromWei(int(contract.functions.get_balance().call()) * (10 ** 6), 'ether'))

                else :

                    print(web3.fromWei(int(contract.functions.get_balance().call()) * (10 ** 6), 'ether'))

            '''
            # Debug utilities
            # Call contract function (this is not persisted to the blockchain)
            print(web3.fromWei(int(contract.functions.get_balance().call()) * (10 ** 6), 'ether'))

            # Call contract function (this is not persisted to the blockchain)
            print(contract.functions.get_reputation().call())
            '''

            # To crate a sealed vote circa ????
            #prop_id = "0"
            #salt = "42"
            #hashedVote = Web3.solidityKeccak(['bytes32'], prop_id + "VoteOption.True" + salt)


if __name__ == "__main__":
    main()