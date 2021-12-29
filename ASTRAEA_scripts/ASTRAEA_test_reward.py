'''
@Author: Italiano Lorenzo

@TEST STEPS:
start ASTRAEA_TEST_reward.py: python3 ASTRAEA_test_reward.py
'''

import ASTRAEA_setup
import random
import string
from time import time, sleep, asctime
import csv
from tqdm import tqdm
import subprocess
import atexit

process = 0


def exit_handler():
    print("\nExit data:", asctime())
    print("\nKilling all the processes..\n")
    if process.poll() is None:
        process.kill()


def create_id(n):
    id = ""

    for i in range(n):
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
        print("\nTest n.", k+1)
        print("\nStarting Ganache..")

        n_prop = 100
        voters = 20
        adv_control = 0.25
        accuracy = 0.95

        process = subprocess.Popen(["ganache-cli", "-a", str(voters+1), "-p", "7545"], stdout=subprocess.DEVNULL)
        sleep(10)
        start = time()

        prop_list = []
        voters_salt = []
        voters_vote = []
        voters_prop_voted = []
        rewards = []
        corrupted_prop = 0

        cert_target = 10
        voter_stake_max = 100
        certifier_stake_min = 200
        bounty = 1000
        closing_voting_stake = voter_stake_max * voters

        web3, contract = ASTRAEA_setup.set(voter_stake_max, cert_target, closing_voting_stake, certifier_stake_min)
        submitter = web3.eth.accounts[voters]

        ''' subscription phase'''
        for i in range(voters):
            voter = web3.eth.accounts[i]
            contract.functions.subscribe().transact({'from': voter})
            rewards.append(int(contract.functions.get_balance().call({'from': voter})))
        ''' propositions' submission '''
        print("\nSubmitting the propositions..")
        content = "The meaning of life is 42"

        # create n propositions
        contract.functions.subscribe().transact({'from': submitter})
        for i in tqdm(range(n_prop)):
            prop_id = create_id(8)
            prop_list.append(prop_id)
            contract.functions.submit_proposition(prop_id, bytes(content, 'utf-8'), bounty).transact({'from': submitter})
            # print("Prop ", i, " submitted: ", prop_id)

        target_prop_id = prop_list[random.randint(0, n_prop-1)]
        print("\nTarget Proposition is:", target_prop_id)

        ''' voting phase '''
        print("\n-- Voting Phase --")

        # each voter as to vote a number of times equal to |P| in order to close al the proposition
        for j in tqdm(range(n_prop)):

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
            voter = web3.eth.accounts[i % voters]
            contract.functions.reveal_voter_sealed_vote(voters_prop_voted[i], voters_vote[i], voters_salt[i]).transact({'from': voter})
    #        print("Revealing vote:", i)

        ''' Check how many propositions have been corrupted '''
        print("\nCounting the votes..\n")
        for i in tqdm(range(n_prop)):
            outcome = str(contract.functions.get_outcome(prop_list[i]).call(), 'utf-8')
            if "False" in outcome:
                corrupted_prop += 1

        print("\nGet the rewards")
        for i in tqdm(range(voters)):
            voter = web3.eth.accounts[i]
            rewards[i] = int(contract.functions.get_balance().call({'from': voter})) - rewards[i]
        outcome = str(contract.functions.get_outcome(target_prop_id).call(), 'utf-8')
        elapsed_time = time()-start

        print("-- RESULTS --\n")
        print("Propositions:", n_prop)
        print("Bounties:", bounty)
        print("Voters:", voters)
        print(f"Adversarial Control: {adv_control*100}%")
        print(f"Accuracy Voters: {accuracy*100}%")
        print("Target Proposition Outcome: ", outcome)
        print("Proposition Corrupted: ", corrupted_prop, "/", n_prop)
        print("Elapsed Time: ", elapsed_time)

        ''' save in ASTRAEA_rewards.csv '''

        #header = ['voters', 'propositions', 'accuracy', 'adv_control', 'prop_corrupted', 'target_corrupted', 'elapsed_time']

        data = [voters, n_prop, accuracy, adv_control, corrupted_prop, 1 if "False" in outcome else 0, round(elapsed_time, 2)]

        with open('../results/ASTRAEA_rewards.csv', 'a', encoding='UTF8', newline='') as f:
            writer = csv.writer(f)
            header = ['reward', 'adversarial', 'accuracy', 'stake']
            #writer.writerow(header)
            for i in range(voters):
                data = [rewards[i], 0 if i < voters - adv_control*voters else 1, accuracy if i < voters - adv_control*voters else 1, voter_stake_max]
                writer.writerow(data)

        process.terminate()
        if process.poll() is None:
            process.kill()
            sleep(2)


if __name__ == "__main__":
    main()

