import ASTRAEA_setup
import random
import string


def create_id(n):
    id = ""

    for i in range(n):
        id += random.choice(string.digits)

    id_list = list(id)
    random.SystemRandom().shuffle(id_list)
    id = ''.join(id_list)
    return int(id)


def main():
    target_prop_id = create_id()
    prop_list = []
    closing_voting_stake = 100
    cert_target = 10
    voter_stake_max = 50
    certifier_stake_min = 100
    voters = 100
    adv_control = 0.25
    accuracy = 0.8
    voters_salt = []
    voters_prop_voted = []
    web3, contract = ASTRAEA_setup.set(closing_voting_stake, cert_target, voter_stake_max, certifier_stake_min)
    submitter = web3.eth.accounts[0]
    contract.functions.subscribe().transact({'from': submitter})

    ''' propositions' submission '''
    content = "The meaning of life is 42"
    bounty = 5000
    # create 99 bait propositions and one proposition, which is the target of the test
    for i in range(100):
        prop_id = create_id(8)
        prop_list.append(prop_id)
        contract.functions.submit_proposition(prop_id, bytes("NTR", 'utf-8'), 100).transact({'from': submitter})
        print("Prop "+ str(i) + " submitted: " + str(prop_id))
    contract.functions.submit_proposition(target_prop_id, bytes(content, 'utf-8'), bounty).transact({'from': submitter})
    print("Target Proposition Submitted: " + str(target_prop_id))

    ''' voting phase '''
    # the submitter will vote as well (as honest voter)
    tx_hash = contract.functions.voting_request(voter_stake_max).transact(submitter)
    prop_id = int(web3.eth.getTransactionReceipt(tx_hash)['logs'][0]['data'], 16)
    voters_prop_voted.append(prop_id)
    salt = create_id(5)
    vote_id = create_id(5) # we can use the same for everyone
    voters_salt.append(salt)
    vote = random.random() < accuracy
    hashed_vote = web3.solidityKeccak(['uint256', 'bool', 'string'], [prop_id, vote, salt])
    contract.functions.vote(prop_id, hashed_vote, vote_id)

    # honest voters
    for i in range(1, voters - int(adv_control*voters)):
        voter = web3.eth.accounts[i]
        contract.functions.subscribe().transact({'from': voter})
        tx_hash = contract.functions.voting_request(voter_stake_max).transact(voter)
        prop_id = int(web3.eth.getTransactionReceipt(tx_hash)['logs'][0]['data'], 16)
        voters_prop_voted.append(prop_id)
        salt = create_id(5)
        voters_salt.append(salt)
        vote = random.random() < accuracy
        hashed_vote = web3.solidityKeccak(['uint256', 'bool', 'string'], [prop_id, vote, salt])
        contract.functions.vote(prop_id, hashed_vote, vote_id)

    # adversarial voters
    for i in range(voters - int(adv_control*voters), voters):
        voter = web3.eth.accounts[i]
        tx_hash = contract.functions.voting_request(voter_stake_max).transact(voter)
        prop_id = int(web3.eth.getTransactionReceipt(tx_hash)['logs'][0]['data'], 16)
        voters_prop_voted.append(prop_id)
        salt = create_id(5)
        voters_salt.append(salt)
        hashed_vote = web3.solidityKeccak(['uint256', 'bool', 'string'], [prop_id, False, salt])
        contract.functions.vote(prop_id, hashed_vote, vote_id)

    # makes the voter phase finish here (setup the contract)

    '''Reveal Phase'''


if __name__ == "__main__":
    main()

