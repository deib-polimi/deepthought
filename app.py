import os
import sys

import setup

# Constant to normalize the ETH amount (in the smart contract we divide the account bilance with this constant)
currencyNormalizer = 10 ** 6

def main():

    # SMART CONTRACT SETUP

    print("DEEP THOUGHT")

    web3, contract = setup.init()

    # Set the default account (so we don't need to set the "from" for every transaction call)
    index = int(input('insert your account index: '))
    web3.eth.defaultAccount = web3.eth.accounts[index]
    print('Your account info: ')
    print('Balance: ' + str(web3.fromWei(int(contract.functions.get_balance().call()) * currencyNormalizer, 'ether')) + ' ETH')
    print('Reputation: ' + str(contract.functions.get_reputation().call()))

    # CLI

    while 1:
        
        insert = int(input('\nMAIN MENU\nHOW DO YOU WANT TO CONTINUE?\n1 - Subscribe\n2 - Sign in\n3 - Your account info\n4 - Quit\nEnter here: '))

        if insert == 4:

            break

        elif insert == 3:

            print('\nYour account info: ')
            print('Balance: ' + str(web3.fromWei(int(contract.functions.get_balance().call()) * currencyNormalizer, 'ether')) + ' ETH')
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

                insert = int(input ('\nROLE MENU\nWHAT ROLE DO YOU WANT TO TAKE?\n1 - Certifier\n2 - Voter\n3 - Submitter\n4 - Your account info\n5 - Go back to main page\nEnter here: '))

                if insert == 5:

                    break

                elif insert == 4:
                    
                    print('\nYour account info: ')
                    print('Balance: ' + str(web3.fromWei(int(contract.functions.get_balance().call()) * currencyNormalizer, 'ether')) + ' ETH')
                    print('Reputation: ' + str(contract.functions.get_reputation().call()))


                elif insert == 1:

                    min_stake_certifier = str(int(contract.functions.get_min_stake_certifier().call()) * currencyNormalizer)
                    min_stake_certifier = str(int(contract.functions.get_max_stake_certifier().call()) * currencyNormalizer)

                elif insert == 2:

                    insert = input("\nDo you want to make a vote request? (y/n) ")
                    if insert == 'y':

                        min_stake_voter = str(int(contract.functions.get_min_stake_voter().call()) * currencyNormalizer)
                        max_stake_voter = str(int(contract.functions.get_max_stake_voter().call()) * currencyNormalizer)

                        print('\nVOTING REQUEST')
                        stake = int(input('stake (wei) [' + min_stake_voter + ' wei, ' + max_stake_voter + ' wei]: '))

                        tx_hash = contract.functions.voting_request(int(stake/currencyNormalizer)).transact()
                        # receive the prop_id from a transaction event
                        prop_id = int(web3.eth.getTransactionReceipt(tx_hash)['logs'][0]['data'],16)
                        prop_content = str(contract.functions.get_prop_content(prop_id).call(),'utf-8')
                        print('\nYou can vote the proposition ' + str(prop_id) + ' (content: "' + prop_content + '")')

                        insert = input('Do you want to vote this proposition? (y/n) ')
                        if insert == 'y':
                            vote = input('Vote (True/False): ')
                            prediction = input('Prediction: ')
                            
                            # To crate a sealed vote circa ????
                            #salt = "42"
                            #hashedVote = Web3.solidityKeccak(['bytes32'], prop_id + "VoteOption.True" + salt)

                else :

                    min_bounty = str(web3.fromWei(int(contract.functions.get_min_bounty().call()) * currencyNormalizer, 'ether'))

                    print("\nSUBMIT A PROPOSITION")
                    prop_id = int(input('proposition id: '))
                    prop_content = input('proposition content: ')
                    bounty = float(input('bounty (ETH) [' + min_bounty + ' ETH, your balance]: '))
                    prediction = int(input('prediction: '))

                    contract.functions.submit_proposition(prop_id, bytes(prop_content, 'utf-8'), int(bounty * (10 ** 18)/currencyNormalizer), prediction).transact()

            '''
            # Debug utilities
            # Call contract function (this is not persisted to the blockchain)
            print('Balance: ' + str(web3.fromWei(int(contract.functions.get_balance().call()) * currencyNormalizer, 'ether')))

            # Call contract function (this is not persisted to the blockchain)
            print('Reputation' + str(contract.functions.get_reputation().call()))
            '''


if __name__ == "__main__":
    main()