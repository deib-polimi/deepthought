'''
TEST STEPS:
1) start ganache-cli: ganache-cli --a 100 -p 7545
2) start ASTRAEA_TEST.py: py ASTRAEA_test.py
'''

import ASTRAEA_setup
import random
import string
from time import time


def create_id(n):
    id = ""

    for i in range(n):
        id += random.choice(string.digits)

    id_list = list(id)
    random.SystemRandom().shuffle(id_list)
    id = ''.join(id_list)
    return int(id)


def main():
    start = time()

    n_prop = 100
    voters = 100
    adv_control = 0.25
    accuracy = 0.95
    prop_list = []
    voters_salt = []
    voters_vote = []
    voters_prop_voted = []
    corrupted_prop = 0

    cert_target = 10
    voter_stake_max = 10
    certifier_stake_min = 100
    closing_voting_stake = voter_stake_max * voters

    web3, contract = ASTRAEA_setup.set(voter_stake_max, cert_target, closing_voting_stake, certifier_stake_min)
    submitter = web3.eth.accounts[0]

    ''' subscription phase'''
    for i in range(voters):
        voter = web3.eth.accounts[i]
        contract.functions.subscribe().transact({'from': voter})

    ''' propositions' submission '''
    print("Submitting the propositions..\n")
    content = "The meaning of life is 42"

    # create n propositions
    for i in range(n_prop):
        prop_id = create_id(8)
        prop_list.append(prop_id)
        contract.functions.submit_proposition(prop_id, bytes(content, 'utf-8'), 100).transact({'from': submitter})
        # print("Prop ", i, " submitted: ", prop_id)

    target_prop_id = prop_list[random.randint(0,n_prop-1)]
    print("Target Proposition is:", target_prop_id)

    ''' voting phase '''
    print("-- Voting Phase --\n")

    # each voter as to vote a number of times equal to |P| in order to close al the proposition
    for j in range(n_prop):

        # honest voters
        for i in range(voters - int(adv_control*voters)):
            voter = web3.eth.accounts[i]
            tx_hash = contract.functions.voting_request(voter_stake_max).transact({'from': voter})
            prop_id = int(web3.eth.waitForTransactionReceipt(tx_hash)['logs'][0]['data'], 16)
            #prop_id = int(web3.eth.getTransactionReceipt(tx_hash)['logs'][0]['data'], 16)
            voters_prop_voted.append(prop_id)
            salt = str(create_id(5))
            voters_salt.append(salt)
            vote_id = create_id(8)
            voters_vote.append(vote_id)
            vote = random.random() < accuracy
            hashed_vote = web3.solidityKeccak(['uint256', 'bool', 'string'], [prop_id, vote, salt])
            contract.functions.vote(prop_id, hashed_vote, vote_id).transact({'from': voter})
            # print("Voter ", i, " has voted for the ", j + 1, " time(s)")

        # adversarial voters
        for i in range(voters - int(adv_control*voters), voters):
            voter = web3.eth.accounts[i]
            tx_hash = contract.functions.voting_request(voter_stake_max).transact({'from': voter})
            prop_id = int(web3.eth.waitForTransactionReceipt(tx_hash)['logs'][0]['data'], 16)
            #prop_id = int(web3.eth.getTransactionReceipt(tx_hash)['logs'][0]['data'], 16)
            voters_prop_voted.append(prop_id)
            salt = str(create_id(5))
            voters_salt.append(salt)
            vote_id = create_id(8)
            voters_vote.append(vote_id)
            hashed_vote = web3.solidityKeccak(['uint256', 'bool', 'string'], [prop_id, False, salt])
            contract.functions.vote(prop_id, hashed_vote, vote_id).transact({'from': voter})
            # print("Voter ", i, " has voted for the ", j + 1, " time(s)")

        print("Votes submitted:", (j+1)*voters )

    # CLOSE PROPOSITION IS NOW AUTOMATIC
    # makes the voter phase finish here (setup the contract)
    #for i in range(n_prop):
        #print("Closing Proposition ", i, ": ", prop_list[i])
    #    contract.functions.close_proposition(prop_list[i]).transact({'from': submitter})
        #print("Prop ", prop_list[i], " phase: ", str(contract.functions.get_prop_state(prop_list[i]).call(), 'utf-8'))
    #print("Closing Target Proposition : ", target_prop_id)
    #contract.functions.close_proposition(target_prop_id).transact({'from': submitter})
    #print("Prop ", target_prop_id, " phase: ", str(contract.functions.get_prop_state(target_prop_id).call(), 'utf-8'))'''

    ''' Reveal Phase '''
    print("-- Reveal Phase --\n")
    for i in range(voters * n_prop):
        voter = web3.eth.accounts[i % n_prop]
        contract.functions.reveal_voter_sealed_vote(voters_prop_voted[i], voters_vote[i], voters_salt[i]).transact({'from': voter})
        #print("Voter ", i, " has revealed")

    end = time()

    ''' Check how many propositions have been corrupted '''
    print("Counting the votes..\n")
    for i in range(n_prop):
        outcome = str(contract.functions.get_outcome(prop_list[i]).call(), 'utf-8')
        if "False" in outcome:
            corrupted_prop += 1

    outcome = str(contract.functions.get_outcome(target_prop_id).call(), 'utf-8')
    elapsed_time = end-start

    print("-- RESULTS --\n")
    print("Target Proposition Outcome: ", outcome)
    print("Proposition Corrupted: ", corrupted_prop, "/", n_prop)
    print("Elapsed Time: ", elapsed_time)


if __name__ == "__main__":
    main()

