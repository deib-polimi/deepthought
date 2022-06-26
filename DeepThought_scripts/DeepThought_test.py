'''
@Author: Di Gennaro Marco

@TEST STEPS:
start DeepThought_TEST.py: py DeepThought_test.py
'''

import DeepThought_setup
import random
import string
from time import time, sleep
import csv
from tqdm import tqdm
import subprocess
import atexit

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
    print('''\n8""""8               ""8""                                    
8    8 eeee eeee eeeee 8   e   e eeeee e   e eeeee e   e eeeee
8e   8 8    8    8   8 8e  8   8 8  88 8   8 8   8 8   8   8  
88   8 8eee 8eee 8eee8 88  8eee8 8   8 8e  8 8e    8eee8   8e 
88   8 88   88   88    88  88  8 8   8 88  8 88 "8 88  8   88 
88eee8 88ee 88ee 88    88  88  8 8eee8 88ee8 88ee8 88  8   88 \n''')
    global process
    atexit.register(exit_handler)
    for k in range(20):
        print("Test n.", k+1)
        print("\nStarting Ganache..")

        process = subprocess.Popen(["ganache-cli", "-a", "20", "-p", "7545"], stdout=subprocess.DEVNULL)
        sleep(10)
        start = time()

        n_prop = 100
        voters = 20

        accuracy = 0.80
        adv_control = 0.35


        # Smart Contract parameters
        alfa = 70
        beta = 30

        prop_list = []
        
        corrupted_prop = 0

        const_prediction_true = 77
        const_prediction_false = 33

        web3, contract = DeepThought_setup.test_init(voters, alfa, beta)
        submitter = web3.eth.accounts[0]

        ''' subscription phase'''
        for i in range(voters):
            voter = web3.eth.accounts[i]
            contract.functions.subscribe().transact({'from': voter})

        ''' propositions' submission '''
        print("\nSubmitting the propositions..")
        content = "deepthought"
        min_bounty = int(contract.functions.get_min_bounty().call())

        # create n propositions
        for i in tqdm(range(n_prop)):
            prop_id = create_id(8)
            prop_list.append(prop_id)
            contract.functions.submit_proposition(prop_id, bytes(content, 'utf-8'), min_bounty).transact({'from': submitter})
            # print("Prop ", i, " submitted: ", prop_id)

        voter_to_prop_salts={v:{} for v in range(voters)}

        target_prop_id = prop_list[random.randint(0, n_prop-1)]
        print("\nTarget Proposition is:", target_prop_id)

        ''' voting phase '''
        print("\n-- Voting Phase --")

        max_stake_voter = contract.functions.get_max_stake_voter().call()

        # each voter as to vote a number of times equal to |P| in order to close al the proposition
        for _ in tqdm(range(n_prop)):

            # honest voters
            for i in range(voters - int(adv_control*voters)):
                
                voter = web3.eth.accounts[i]
                tx_hash = contract.functions.voting_request(max_stake_voter).transact({'from': voter})
                prop_id = int(web3.eth.waitForTransactionReceipt(tx_hash)['logs'][0]['data'], 16)

                
                salt = str(create_id(5))
                if(prop_id not in voter_to_prop_salts[i].keys()):
                    voter_to_prop_salts[i][prop_id] = []
                voter_to_prop_salts[i][prop_id].append(salt)

                vote = random.random() < accuracy
                hashed_vote = web3.solidityKeccak(['uint256', 'bool', 'string'], [prop_id, vote, salt])
                contract.functions.vote(prop_id, hashed_vote, (const_prediction_true if vote else const_prediction_false)).transact({'from': voter})

            # adversarial voters
            for i in range(voters - int(adv_control*voters), voters):
                voter = web3.eth.accounts[i]
                tx_hash = contract.functions.voting_request(max_stake_voter).transact({'from': voter})
                prop_id = int(web3.eth.waitForTransactionReceipt(tx_hash)['logs'][0]['data'], 16)
                
                salt = str(create_id(5))
                if(prop_id not in voter_to_prop_salts[i].keys()):
                    voter_to_prop_salts[i][prop_id] = []
                voter_to_prop_salts[i][prop_id].append(salt)

                hashed_vote = web3.solidityKeccak(['uint256', 'bool', 'string'], [prop_id, False, salt])
                contract.functions.vote(prop_id, hashed_vote, const_prediction_false).transact({'from': voter})


        ''' Reveal Phase '''
        print("\n-- Reveal Phase --")
        for i in tqdm(range(voters)):
            voter = web3.eth.accounts[i]
            for prop_id in voter_to_prop_salts[i].keys():
                 for j in range(len(voter_to_prop_salts[i][prop_id])):
                    contract.functions.reveal_voter_hashed_vote(prop_id, voter_to_prop_salts[i][prop_id][j], j).transact({'from': voter})

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

        #header = ['voters', 'propositions', 'accuracy', 'adv_control', 'prop_corrupted', 'target_corrupted', 'elapsed_time','alfa','beta']

        data = [voters, n_prop, accuracy, adv_control, corrupted_prop, 1 if "False" in outcome else 0, round(elapsed_time, 2), alfa, beta]

        with open('../results/results_DeepThought.csv', 'a', encoding='UTF8', newline='') as f:
            writer = csv.writer(f)
            #writer.writerow(header)
            writer.writerow(data)

        process.terminate()
        if process.poll() is None:
            process.kill()
            sleep(2)


if __name__ == "__main__":
    main()

