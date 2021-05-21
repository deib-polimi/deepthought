import os
import sys

import setup

def get_info(web3, contract):

    print('\nYour account info: ')
    print('Balance: ' + str(web3.fromWei(int(contract.functions.get_balance().call()), 'ether')) + ' ETH')
    print('Reputation: ' + str(contract.functions.get_reputation().call()))

def main():

    # SMART CONTRACT SETUP

    print("DEEP THOUGHT")

    web3, contract = setup.init()

    # Set the default account (so we don't need to set the "from" for every transaction call)
    index = int(input('insert your account index: '))
    web3.eth.defaultAccount = web3.eth.accounts[index]

    get_info(web3,contract)

    # CLI

    while 1:
        
        insert = int(input('\nMAIN MENU\nHOW DO YOU WANT TO CONTINUE?\n1 - Subscribe\n2 - Sign in\n3 - Your account info\n4 - Quit\nEnter here: '))

        if insert == 4: #QUIT

            break

        elif insert == 3: #INFO

            get_info(web3,contract)

        elif insert == 1: #SUBSCRIBE

            # Transact contract function (persisted to the blockchain). For every write function use "transact"
            contract.functions.subscribe().transact()
            print("Now you are subscribed!")
        
        elif insert == 2 : #SIGN IN

            while 1:

                # ONCE SUBSCRIBED THE WORKFLOW SHOULD BE:
                # SUBMITTER: submit_proposition > [wait for all to vote] > [wait for revealing or eventually result_proposition]
                # VOTER: voting_request > vote > [wait for all to vote] > reveal_sealed_vote > [get the rewards when propositon is closed]
                # CERTIFIER: certification_request > show_propositions > certify_proposition > [get the rewards when propositon is closed]

                insert = int(input ('\nROLE MENU\nWHAT ROLE DO YOU WANT TO TAKE?\n1 - Certifier\n2 - Voter\n3 - Submitter\n4 - Your account info\n5 - Go back to MAIN MENU\nEnter here: '))

                if insert == 5: #GO BACK

                    break

                elif insert == 4: #INFO
                    
                    get_info(web3,contract)

                elif insert == 1: #CERTIFY

                    insert = int(input("\nCERTIFIER MENU\n1 - Make a certification request\n2 - Show certified propositions state\n3 - Go back to the MAIN MENU\n"))

                    if insert == 1: #CERTIFICATION REQUEST

                        
                        min_stake_certifier = str(web3.fromWei(contract.functions.get_min_stake_certifier().call(), 'ether'))
                        max_stake_certifier = str(web3.fromWei(contract.functions.get_max_stake_certifier().call(), 'ether'))

                        print('\nCERTIFICATION REQUEST')
                        stake = float(input('stake (wei) [' + min_stake_certifier + ' ETH, ' + max_stake_certifier + ' ETH]: '))

                        contract.functions.certification_request(int(stake * (10 ** 18))).transact()

                        print('\nPROPOSITION YOU CAN CERTIFY\nProposition id : content')

                        max_prop_num = int(contract.functions.get_max_number_of_propositions().call())

                        for i in range(0, max_prop_num):
                            prop_id = int(contract.functions.show_propositions(i).call())
                            content = str(contract.functions.get_prop_content(prop_id).call(),'utf-8')
                            
                            print(str(prop_id) + ' : ' + content)

                        prop_id = int(input('\nWhich proposition do you want to certify?\nProposition id: '))

                        #TODO : if we make hashed the certifier vote we have to change the following code block
                        while insert != 'True' and insert != 'False':
                            insert = input('Vote (True/False): ')

                        if insert == 'True': vote = True
                        elif insert == 'False': vote = False

                        contract.functions.certify_proposition(prop_id, vote).transact()
                        print("Nice! your certification has been recorded")

                    elif insert == 2: #CERTIFIED STATUS
                        
                        certified_prop_num = int(contract.functions.get_number_certified_propositions().call())

                        print('\nPROPOSITION ID -> STATUS')

                        for i in range (0, certified_prop_num):
                            prop_id = int(contract.functions.get_certified_prop_id(i).call())
                            status = str(contract.functions.get_prop_state(prop_id).call(), 'utf-8')

                            out = str(prop_id) + ' -> ' + status
                            if (status.startswith('Close')):
                                result = str(contract.functions.get_outcome(prop_id).call(),'utf-8')
                                earned = str(web3.fromWei(contract.functions.get_reward_certifier_by_prop_id(prop_id).call(), 'ether'))
                                out += ' (result: ' + result + '), (earned: ' + earned + ' ETH)'

                            print(out)

                    elif insert == 3: #GO BACK

                        break

                elif insert == 2: #VOTE

                    insert = int(input("\nVOTER MENU\n1 - Make a vote request\n2 - Show voted propositions state\n3 - Go back to the MAIN MENU\n"))

                    if insert == 1: #VOTE REQUEST

                        min_stake_voter = str(contract.functions.get_min_stake_voter().call())
                        max_stake_voter = str(contract.functions.get_max_stake_voter().call())

                        print('\nVOTING REQUEST')
                        stake = int(input('stake (wei) [' + min_stake_voter + ' wei, ' + max_stake_voter + ' wei]: '))

                        tx_hash = contract.functions.voting_request(stake).transact()

                        # receive the prop_id from a transaction event
                        prop_id = int(web3.eth.getTransactionReceipt(tx_hash)['logs'][0]['data'],16)
                        prop_content = str(contract.functions.get_prop_content(prop_id).call(),'utf-8')
                        print('\nYou can vote the proposition ' + str(prop_id) + ' (content: "' + prop_content + '")')

                        print("\nVOTE THE PROPOSITION")
                        
                        while insert != 'True' and insert != 'False':
                            insert = input('Vote (True/False): ')

                        if insert == 'True': vote = True
                        elif insert == 'False': vote = False

                        prediction = int(input('Prediction [0 %,100 %] (your prediction on the proposition truthfulness): '))
                        salt = input('Insert your salt (REMEMBER IT!): ')
                            
                        hashedVote = web3.solidityKeccak(['uint256','bool','string'], [prop_id, vote, salt])

                        contract.functions.vote(prop_id, hashedVote, prediction).transact()
                        print("Nice! your vote has been recorded")

                    elif insert == 2: #VOTED STATUS
                        
                        voted_prop_num = contract.functions.get_number_voted_propositions().call()
                        reveal = False
                        print('\nPROPOSITION ID -> STATUS')

                        for i in range (0, voted_prop_num):
                            prop_id = int(contract.functions.get_voted_prop_id(i).call())
                            status = str(contract.functions.get_prop_state(prop_id).call(), 'utf-8')

                            reveal = status.startswith('Reveal')

                            out = str(prop_id) + ' -> ' + status
                            if (status.startswith('Close')):
                                result = str(contract.functions.get_outcome(prop_id).call(),'utf-8')
                                earned = str(int(contract.functions.get_reward_voter_by_prop_id(prop_id).call()))
                                out += ' (result: ' + result + '), (earned: ' + earned + ' wei)'

                            print(out)

                        if reveal:
                            insert = input('Do you want to reveal your vote about the "Reveal" proposition?(y/n): ')
                            if insert == 'y':
                                prop_id = int(input('Proposition id: '))
                                salt = bytes(input('Insert your salt to reveal your vote (YOU HAD TO REMEMBER IT!): '),'utf-8')

                                contract.functions.reveal_sealed_vote(prop_id, salt).transact()

                    elif insert == 3: #GO BACK

                        break


                elif insert == 3 : #SUBMIT

                    insert = int(input("\nSUBMITTER MENU\n1 - Submit a proposition\n2 - Show submitted propositions state\n"))

                    if insert == 1: #SUBMITTING

                        contract.functions.set_min_bounty().transact()
                        min_bounty = str(web3.fromWei(int(contract.functions.get_min_bounty().call()), 'ether'))

                        print("\nSUBMIT A PROPOSITION")
                        prop_id = int(input('proposition id: '))
                        prop_content = input('proposition content: ')
                        bounty = float(input('bounty (ETH) [' + min_bounty + ' ETH, your balance]: '))

                        contract.functions.submit_proposition(prop_id, bytes(prop_content, 'utf-8'), int(bounty * (10 ** 18))).transact()
                    
                    elif insert == 2: #SUBMITTED STATE

                        submitted_prop_num = contract.functions.get_number_submitted_propositions().call()
                        print('\nPROPOSITION ID -> STATUS')

                        for i in range (0, submitted_prop_num):
                            prop_id = int(contract.functions.get_submitted_prop_id(i).call())
                            status = str(contract.functions.get_prop_state(prop_id).call(), 'utf-8')

                            out = str(prop_id) + ' -> ' + status
                            if (status.startswith('Close')):
                                result = str(contract.functions.get_outcome(prop_id).call(),'utf-8')
                                out += ' (result: ' + result + ')'

                            print(out)


if __name__ == "__main__":
    main()
