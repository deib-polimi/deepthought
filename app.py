import os
import sys

import setup

# Constant to normalize the ETH amount (in the smart contract we divide the account bilance with this constant)
ethNormalizer = 10 ** 6

def main():

    # SMART CONTRACT SETUP

    print("DEEP THOUGHT")

    web3, contract = setup.init()

    # Set the default account (so we don't need to set the "from" for every transaction call)
    index = int(input('insert your account index: '))
    web3.eth.defaultAccount = web3.eth.accounts[index]
    print('Your account info: ')
    print('Balance: ' + str(web3.fromWei(int(contract.functions.get_balance().call()) * ethNormalizer, 'ether')))
    print('Reputation: ' + str(contract.functions.get_reputation().call()))

    # CLI

    while 1:
        
        insert = int(input('\nMAIN MENU\nHOW DO YOU WANT TO CONTINUE?\n1 - Subscribe\n2 - Sign in\n3 - Your account info\n4 - Quit\nEnter here: '))

        if insert == 4:

            break

        elif insert == 3:

            print('\nYour account info: ')
            print('Balance: ' + str(web3.fromWei(int(contract.functions.get_balance().call()) * ethNormalizer, 'ether')))
            print('Reputation: ' + str(contract.functions.get_reputation().call()))

        elif insert == 1:

            # Transact contract function (persisted to the blockchain). For every write function use "transact"
            contract.functions.subscribe().transact()
            print("Now you are subscribed!")
        
        else :

            while 1:

                # ONCE SUBSCRIBED THE WORKFLOW SHOULD BE:
                # SUBMITTER: submit_proposition > [wait for all to vote] > [wait for revealing or eventually result_proposition]
                # VOTER: voting_request > vote > [wait for all to vote] > reveal_sealed_vote > [get the rewards when propositon is closed]
                # CERTIFIER: certification_request > show_propositions > certify_proposition > [get the rewards when propositon is closed]

                insert = int (input ('\nROLE MENU\nWHAT ROLE DO YOU WANT TO TAKE?\n1 - Certifier\n2 - Voter\n3 - Submitter\n4 - Your account info\n5 - Go back to main page\nEnter here: '))

                if insert == 5:

                    break

                elif insert == 4:
                    
                    print('\nYour account info: ')
                    print('Balance: ' + str(web3.fromWei(int(contract.functions.get_balance().call()) * ethNormalizer, 'ether')))
                    print('Reputation: ' + str(contract.functions.get_reputation().call()))


                elif insert == 1:

                    print('1')

                elif input == 2:

                    print('2')

                else :

                    print("\nSUBMIT A PROPOSITION")
                    prop_id = int(input('proposition id: '))
                    prop_content = input('proposition content: ')
                    bounty = float(input('bounty (ETH): '))
                    prediction = int(input('prediction: '))

                    contract.functions.submit_proposition(prop_id, bytes(prop_content, 'utf-8'), int(bounty * (10 ** 18)/ethNormalizer), prediction).transact()

            '''
            # Debug utilities
            # Call contract function (this is not persisted to the blockchain)
            print('Balance: ' + str(web3.fromWei(int(contract.functions.get_balance().call()) * ethNormalizer, 'ether')))

            # Call contract function (this is not persisted to the blockchain)
            print('Reputation' + str(contract.functions.get_reputation().call()))
            '''

            # To crate a sealed vote circa ????
            #prop_id = "0"
            #salt = "42"
            #hashedVote = Web3.solidityKeccak(['bytes32'], prop_id + "VoteOption.True" + salt)


if __name__ == "__main__":
    main()