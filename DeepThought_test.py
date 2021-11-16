'''
@Author: Italiano Lorenzo and Di Gennaro Marco

@TEST STEPS:
1) start ganache-cli: ganache-cli --a 100 -p 7545
2) start DEEP_THOUGHT_TEST.py: py DeepThought_test.py
'''

import DeepThought_setup
import random
import string
from time import time, sleep
import csv
from tqdm import tqdm
import subprocess
import atexit
import math

process = 0


def exit_handler():
    print("Killing all the processes..")
    if process.poll() is None:
        process.kill()


def create_id(n):
    id = ""

    for _ in range(n):
        id += random.choice(string.digits)

    id_list = list(id)
    random.SystemRandom().shuffle(id_list)
    id = ''.join(id_list)
    return int(id)


def main():
    print("""    ,.   .---. ,--,--'.-,--.     ,.  .-,--.     ,.  
   / |   \___  `- |    `|__/    / |   `\__     / |  
  /~~|-.     \  , |    )| \    /~~|-.  /      /~~|-.
,'   `-' `---'  `-'    `'  ` ,'   `-' '`--' ,'   `-'""")
    global process
    atexit.register(exit_handler)
    for k in range(1):
        print("Test n.", k+1)
        print("\nStarting Ganache..")

        process = subprocess.Popen(["ganache-cli", "-a", "100", "-p", "7545"], shell=True, stdout=subprocess.DEVNULL)
        sleep(5)
        start = time()

        n_prop = 2
        voters = 10
        adv_control = 0.25
        accuracy = 0.95
        prop_list = []
        voters_salt = []
        voters_prop_voted = []

        voter_revealed = {}

        corrupted_prop = 0

        const_prediction_true = 77
        const_prediction_false = 33

        web3, contract = DeepThought_setup.test_init()
        submitter = web3.eth.accounts[0]

        ''' subscription phase'''
        for i in range(voters):
            voter = web3.eth.accounts[i]
            contract.functions.subscribe().transact({'from': voter})

        ''' propositions' submission '''
        print("\nSubmitting the propositions..")
        content = "deepthought"

        # create n propositions
        for i in tqdm(range(n_prop)):
            prop_id = create_id(8)
            prop_list.append(prop_id)
            min_bounty = (web3.fromWei(int(contract.functions.get_min_bounty().call()), 'ether'))
            contract.functions.submit_proposition(prop_id, bytes(content, 'utf-8'), int(min_bounty * (10 ** 18))).transact({'from': submitter})
            # print("Prop ", i, " submitted: ", prop_id)

        target_prop_id = prop_list[random.randint(0, n_prop-1)]
        print("\nTarget Proposition is:", target_prop_id)

        ''' voting phase '''
        print("\n-- Voting Phase --")

        # each voter as to vote a number of times equal to |P| in order to close al the proposition
        for _ in tqdm(range(n_prop)):
        
            max_stake_voter = contract.functions.get_max_stake_voter().call()

            # honest voters
            for i in range(voters - int(adv_control*voters)):
                
                voter = web3.eth.accounts[i]
                tx_hash = contract.functions.voting_request(max_stake_voter).transact({'from': voter})
                prop_id = int(web3.eth.waitForTransactionReceipt(tx_hash)['logs'][0]['data'], 16)
                if prop_id not in voters_prop_voted:
                    voters_prop_voted.append(prop_id)
                    salt = str(create_id(5))
                    voters_salt.append(salt)
                else:
                    index = voters_prop_voted.index(prop_id)
                    salt = voters_salt[index]
                    voters_prop_voted.append(prop_id)
                    voters_salt.append(salt)
                vote = random.random() < accuracy
                hashed_vote = web3.solidityKeccak(['uint256', 'bool', 'string'], [prop_id, vote, salt])
                contract.functions.vote(prop_id, hashed_vote, (const_prediction_true if vote else const_prediction_false)).transact({'from': voter})

            # adversarial voters
            for i in range(voters - int(adv_control*voters), voters):
                voter = web3.eth.accounts[i]
                tx_hash = contract.functions.voting_request(max_stake_voter).transact({'from': voter})
                prop_id = int(web3.eth.waitForTransactionReceipt(tx_hash)['logs'][0]['data'], 16)
                if prop_id not in voters_prop_voted:
                    voters_prop_voted.append(prop_id)
                    salt = str(create_id(5))
                    voters_salt.append(salt)
                else:
                    index = voters_prop_voted.index(prop_id)
                    salt = voters_salt[index]
                    voters_prop_voted.append(prop_id)
                    voters_salt.append(salt)

                hashed_vote = web3.solidityKeccak(['uint256', 'bool', 'string'], [prop_id, False, salt])
                contract.functions.vote(prop_id, hashed_vote, const_prediction_false).transact({'from': voter})

            #print("Votes submitted:", (j+1)*voters )

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
        print("\n-- Reveal Phase --")
        for i in tqdm(range(voters * n_prop)):
            if(math.floor(i/voters) == 0):
                voter_revealed[i % voters] = []
            voter = web3.eth.accounts[i % voters]

            if(prop_id not in voter_revealed[i % voters]):
                contract.functions.reveal_voter_hashed_vote(voters_prop_voted[i], voters_salt[i]).transact({'from': voter})
                voter_revealed[i % voters].append(prop_id)
    #        print("Revealing vote:", i)
            #if i % 1000 == 0:
             #   print("Revealing vote:", i)

        end = time()

        ''' Check how many propositions have been corrupted '''
        print("\nCounting the votes..\n")
        for i in tqdm(range(n_prop)):
            outcome = str(contract.functions.get_outcome(prop_list[i]).call(), 'utf-8')
            if "False" in outcome:
                corrupted_prop += 1

        outcome = str(contract.functions.get_outcome(target_prop_id).call(), 'utf-8')
        elapsed_time = end-start

        print("-- RESULTS --\n")
        print("Propositions:", n_prop)
        print("Voters:", voters)
        print(f"Adversarial Control: {adv_control*100}%")
        print(f"Accuracy Voters: {accuracy*100}%")
        print("Target Proposition Outcome: ", outcome)
        print("Proposition Corrupted: ", corrupted_prop, "/", n_prop)
        print("Elapsed Time: ", elapsed_time)

        ''' save in results.csv '''

        #header = ['voters', 'propositions', 'accuracy', 'adv_control', 'prop_corrupted', 'target_corrupted', 'elapsed_time']

        data = [voters, n_prop, accuracy, adv_control, corrupted_prop, 1 if "False" in outcome else 0, round(elapsed_time, 2)]

        with open('results.csv', 'a', encoding='UTF8', newline='') as f:
            writer = csv.writer(f)
            #writer.writerow(header)
            writer.writerow(data)

        process.terminate()
        if process.poll() is None:
            process.kill()
            sleep(2)


if __name__ == "__main__":
    main()

