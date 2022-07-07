pragma solidity  >=0.8.0 <0.9.0;


/*
 * @title: ASTRAEA
 * @dev:   Voting-based Oracle with the aim of verifying propositions
 * SPDX-License-Identifier: UNLICENSED
 */
contract ASTRAEA {

    /* ### PARAMETERS OF THE ORACLE ### */

    // Maximum number of voters (number of voters to close the proposition)
    uint max_n_votes;

    // Maximum voter stake
    uint voter_stake_max;

    // Minimum certifier stake
    uint certifier_stake_min;

    // Reward pool for paying certifiers, splitted into True and False (Rt/Rf)
    mapping (VoteOption => uint) certifier_reward_pool;

    // Number of certification the reward_pool should have founds for (Tao)
    uint tao;

    // List of all the prop_id
    uint256[] propositions_list;

    // List of closed/revealing prop_id
    uint256[] not_open_propositions_list;

    // Map of all the prop_id > proposition
    mapping (uint256 => Proposition) proposition;

    // Balance of each address
    mapping (address => uint256) balance;

    // Voter > prop_id > stake to check if he staked something so he can see which proposition he was assign to
    mapping (address => mapping(uint256 => uint256)) vote_stake_request;

    // Certifier > stake to check if he staked something so he can see the proposition list
    mapping (address => uint256) certifier_stake_request;

    // Voter > list of voted proposition
    mapping (address => uint256[]) voted_propositions;

    // Voter > list of certified proposition
    mapping (address => uint256[]) certified_propositions;

    // Voter > list of submitted proposition
    mapping (address => uint256[]) submitted_propositions;

    constructor(uint _voter_stake_max, uint _cert_stake_min, uint _max_n_votes, uint _tao){
        /*max_n_votes = ;
        tao = ;
        voter_stake_max = ;
        certifier_stake_min = ;*/
        max_n_votes = _max_n_votes;
        tao = _tao;
        voter_stake_max = _voter_stake_max;
        certifier_stake_min = _cert_stake_min;
    }


    /* ### STRUCTURES ### */

    enum VoteOption {Unknown, True, False}

    enum PropositionStatus {Open, Reveal, Close}

    struct Vote {

        VoteOption vote_unsealed;

        bytes32 vote_sealed;

        uint256 stake;

        bool revealed;

    }

    struct Proposition {
        // Unique proposition ID
        uint256 id;

        // Submitter address
        address submitter;

        // Content of the proposition
        bytes32 content;

        // Bounty attached to proposition which is used to reward voters
        uint256 bounty;

        // voter > reward earned with this proposition
        mapping (address => uint256) voter_earned_reward;

        // certifier > reward earned with this proposition
        mapping (address => uint256) certifier_earned_reward;

        // The status of the proposition Open > votingClosed > RevealClosed
        PropositionStatus status;

        // VoteOption > sum of votes weight for the specific VoteOption
        mapping (VoteOption => uint256) vote_balance;

        // Decided outcome
        VoteOption outcome;

        // --- VOTERS VARIABLES ---

        // Total voting stake
        uint256 voters_stake_pool;

        // Array of votes
        Vote[] votes;

        // voter > index of the voter's votes in votes array 
        mapping (address => uint256[]) voted_indexes;

        address[] voters;

        // Voters' stake (after reveal)
        mapping(address => mapping (VoteOption => uint256)) voter_stake;

        // Votes submitting vote T
        uint256[] T_vote_indexes;
        
        // Votes submitting vote F
        uint256[] F_vote_indexes;

        // --- CERTIFIERS VARIABLES ---

        // Total certificating stake
        uint256 certifiers_stake_pool;

        // Certifiers stake divided by the opinion
        mapping (VoteOption => uint256) certificates;

        // List of the addresses who certified
        address[] certifiers_list;

        // Certifiers sealed vote
        mapping (address => bytes32) certifier_sealedVote;

        // Certifiers vote and stake
        mapping (address => mapping (VoteOption => uint256)) certifier_stake;

        // Certifiers submitting True certification
        address[] T_certifiers;

        // Certifiers submitting False certification
        address[] F_certifiers;

    }

    /* ### EVENTS ### */

    // Event to return the prop_id after the voting transaction
    event return_id(uint256 prop_id);

    /* ### OUT FUNCTIONS ### */

    // ### Getters

    function get_balance() public view returns(uint256){
        return balance[msg.sender];
    }


    function get_max_stake_voter() public view returns (uint256){
        return voter_stake_max;
    }

    function get_min_stake_certifier() public view returns (uint256){
        return certifier_stake_min;
    }

    function get_number_propositions() public view returns (uint256){
        require (certifier_stake_request[msg.sender] > 0, "Not a certifier! Make a request");
        return propositions_list.length;
    }

    function get_prop_id_by_index(uint256 _i) public view returns (uint256){
        require (certifier_stake_request[msg.sender] > 0, "Not a certifier! Make a request");
        require (_i < propositions_list.length, "Out of bound");
        return propositions_list[_i];
    }

    function get_prop_content_by_prop_id(uint256 _prop_id) public view returns (bytes32){
        return proposition[_prop_id].content;
    }

    function get_prop_bounty_by_prop_id(uint256 _prop_id) public view returns (uint256){
        return proposition[_prop_id].bounty;
    }

    function get_number_voted_propositions() public view returns (uint256){
        return voted_propositions[msg.sender].length;
    }

    function get_n_voted_times(uint256 _prop_id) public view returns (uint256){
        return proposition[_prop_id].voted_indexes[msg.sender].length;
    }

    function get_number_submitted_propositions() public view returns (uint256){
        return submitted_propositions[msg.sender].length;
    }

    function get_number_certified_propositions() public view returns (uint256){
        return certified_propositions[msg.sender].length;
    }

    function get_voted_prop_id(uint256 index) public view returns (uint256){
        return voted_propositions[msg.sender][index];
    }

    function get_certified_prop_id(uint256 index) public view returns (uint256){
        return certified_propositions[msg.sender][index];
    }

    function get_submitted_prop_id(uint256 index) public view returns (uint256){
        return submitted_propositions[msg.sender][index];
    }

    function get_prop_state(uint256 _prop_id) public view returns (bytes32){
        if (proposition[_prop_id].status == PropositionStatus.Open){
            return bytes32("Open");
        }
        else{
            if(proposition[_prop_id].status == PropositionStatus.Reveal){
                return bytes32("Reveal");
            }
            else{
                return bytes32("Close");
            }
        }
    }

    function get_outcome(uint256 _prop_id) public view returns (bytes32){
        if (proposition[_prop_id].outcome == VoteOption.True){
            return bytes32("True");
        }
        else{
            if(proposition[_prop_id].outcome == VoteOption.False){
                return bytes32("False");
            }
            else{
                return bytes32("Unknown");
            }
        }
    }

    function get_reward_voter_by_prop_id(uint256 _prop_id) public view returns (uint256){
        return proposition[_prop_id].voter_earned_reward[msg.sender];
    }

    function get_reward_certifier_by_prop_id(uint256 _prop_id) public view returns (uint256){
        return proposition[_prop_id].certifier_earned_reward[msg.sender];
    }

    // ### State Changer

    // Subscribe to the service and put founds in it
    function subscribe() public{
        require(balance[msg.sender] == 0, "Already subscribed!");
        balance[msg.sender] = msg.sender.balance;
    }

    /* ### SUBMITTER ### */

    // Submit a new proposition
    function submit_proposition(uint256 _prop_id, bytes32 _prop_content, uint256 _bounty) public {
        require (balance[msg.sender] >= _bounty, "Not enough money to submit");
        propositions_list.push(_prop_id);
        Proposition storage prop = proposition[_prop_id];
        prop.id =_prop_id;
        prop.submitter = msg.sender;
        prop.content = _prop_content;
        prop.bounty = _bounty;

        prop.status = PropositionStatus.Open;
        prop.outcome = VoteOption.Unknown;

        balance[msg.sender] -= _bounty;

        submitted_propositions[msg.sender].push(_prop_id);
    }

    /* ### VOTER ### */

     // Put your stake to receive a random proposition (via event)
    function voting_request(uint256 _stake) public {
        require (_stake <= voter_stake_max, "The stake is too high");
        require (balance[msg.sender] >= _stake, "Not enough money to vote");
        uint256 prop_id = find_random_proposition();
        vote_stake_request[msg.sender][prop_id] = _stake;
        balance[msg.sender] -= _stake;

        //To return a value from a state changer function we emit an event
        emit return_id(prop_id);
    }

    // Vote for the proposition you received
    function vote(uint256 _prop_id, bytes32 _hashed_vote) public {
        require (vote_stake_request[msg.sender][_prop_id] > 0, "Not a voter of that proposition! Make a request");

        // Get the proposition
        Proposition storage prop = proposition[_prop_id];
        require(prop.status == PropositionStatus.Open, "Voting phase is closed!");

        // Move the stake to the proposition and vote
        uint256 stake = vote_stake_request[msg.sender][_prop_id];
        vote_stake_request[msg.sender][_prop_id] = 0;
        prop.votes.push(Vote(VoteOption.Unknown, _hashed_vote, stake, false));
        prop.voted_indexes[msg.sender].push(prop.votes.length - 1);
        prop.voters_stake_pool += stake;

        if(prop.voted_indexes[msg.sender].length == 1){
            voted_propositions[msg.sender].push(_prop_id);
            prop.voters.push(msg.sender);
        }

        // If the max stake for a proposition is reached, the voting phase is closed
        if (prop.votes.length >= max_n_votes){
            close_proposition(_prop_id);
        }

    }

    // Reveal the voter's vote for a proposition
    function reveal_voter_sealed_vote(uint256 _prop_id, string memory _salt,  uint index) public {
        Proposition storage prop = proposition[_prop_id];
        require(prop.status == PropositionStatus.Reveal, "Proposition is not in the reveal phase!");
        bytes32 hashed_vote = prop.votes[prop.voted_indexes[msg.sender][index]].vote_sealed;
        require(prop.votes[prop.voted_indexes[msg.sender][index]].revealed == false, "Vote already revealed!");
        
        uint stake = prop.votes[prop.voted_indexes[msg.sender][index]].stake;
        if(hashed_vote == keccak256(abi.encodePacked(_prop_id, true, _salt))){
            // Vote was true
            prop.votes[prop.voted_indexes[msg.sender][index]].vote_unsealed = VoteOption.True;
            prop.T_vote_indexes.push(prop.voted_indexes[msg.sender][index]);
            prop.vote_balance[VoteOption.True] += stake;
            prop.voter_stake[msg.sender][VoteOption.True] += stake;

        }else if(hashed_vote == keccak256(abi.encodePacked(_prop_id, false, _salt))){
            // Vote was false
            prop.votes[prop.voted_indexes[msg.sender][index]].vote_unsealed = VoteOption.False;
            prop.F_vote_indexes.push(prop.voted_indexes[msg.sender][index]);
            prop.vote_balance[VoteOption.False] += stake;
            prop.voter_stake[msg.sender][VoteOption.False] += stake;
        }else{
            revert("Wrong salt!!!");
        }

        prop.votes[prop.voted_indexes[msg.sender][index]].revealed = true;
        if(prop.F_vote_indexes.length + prop.T_vote_indexes.length == prop.votes.length){
            elaborate_result_proposition(_prop_id);
        }
    }

    // Set the outcome based on the vote majority
    function set_outcome(uint256 _prop_id) internal {
        Proposition storage prop = proposition[_prop_id];
        require(prop.status == PropositionStatus.Close, "Should be Close");
        VoteOption voter_result = VoteOption.Unknown;
        VoteOption cert_result = VoteOption.Unknown;
        if(prop.vote_balance[VoteOption.True] > prop.vote_balance[VoteOption.False]) voter_result = VoteOption.True;
        if(prop.vote_balance[VoteOption.False] > prop.vote_balance[VoteOption.True]) voter_result = VoteOption.False;
        if(prop.certificates[VoteOption.True] > prop.certificates[VoteOption.False]) cert_result = VoteOption.True;
        if(prop.certificates[VoteOption.False] > prop.certificates[VoteOption.True]) cert_result = VoteOption.False;

        if(voter_result == cert_result || cert_result == VoteOption.Unknown) prop.outcome = voter_result;
    }

    /* ### CERTIFIER ###*/

    // Put your stake to be able to view the proposition as a certifier
    function certification_request(uint256 _stake) public {
        require (certifier_stake_request[msg.sender] == 0, "Action already performed! Choose a proposition");
        require (balance[msg.sender] >= _stake, "Not enough money to certify");
        require (_stake >= certifier_stake_min, "The stake is not enough!");
        certifier_stake_request[msg.sender] = _stake;
        balance[msg.sender] -= _stake;
    }

    // A certifier send his vote for a proposition
    function certify_proposition(uint256 _prop_id, bytes32 _hashed_vote) public {
        require (certifier_stake_request[msg.sender] > 0, "Not a certifier! Make a request");
        // Get the chosen proposition
        Proposition storage prop = proposition[_prop_id];
        // Increment the vote and move the stake to the proposition chosen
        prop.certifiers_list.push(msg.sender);
        uint256 stake = certifier_stake_request[msg.sender];
        certifier_stake_request[msg.sender] = 0;
        prop.certifier_sealedVote[msg.sender] = _hashed_vote;
        prop.certifiers_stake_pool += stake;
        prop.certifier_stake[msg.sender][VoteOption.Unknown] += stake;
        certified_propositions[msg.sender].push(_prop_id);
    }

    // Reveal the certifier's vote for a proposition
    function reveal_certifier_sealed_vote(uint256 _prop_id, string memory _salt) public {
        Proposition storage prop = proposition[_prop_id];
        require(prop.status == PropositionStatus.Reveal, "Proposition is not in the reveal phase!");
        bytes32 hashed_vote = prop.certifier_sealedVote[msg.sender];
        uint256 stake = prop.certifier_stake[msg.sender][VoteOption.Unknown];
        if(hashed_vote == keccak256(abi.encodePacked(_prop_id, true, _salt))){
            // Vote was true
            prop.certifier_stake[msg.sender][VoteOption.True] += stake;
            prop.T_certifiers.push(msg.sender);
            prop.certificates[VoteOption.True] += stake;
        }else if(hashed_vote == keccak256(abi.encodePacked(_prop_id, false, _salt))){
            // Vote was false
            prop.certifier_stake[msg.sender][VoteOption.True] += stake;
            prop.F_certifiers.push(msg.sender);
            prop.certificates[VoteOption.False] += stake;
        }else{
            revert("Wrong salt!!!");
        }
        prop.certifier_stake[msg.sender][VoteOption.Unknown] = 0;
    }


    /* ### INTERNAL FUNCTION ### */


    // This function has to be called to elaborate a proposition result. It calls other internal functions
    function elaborate_result_proposition(uint256 _prop_id) internal {
        stop_revealing_proposition(_prop_id);
        set_outcome(_prop_id);
        distribute_reward(_prop_id); 
    }

     // Change status of proposition Open > VotingClosed
    function close_proposition(uint256 _prop_id) internal {
        Proposition storage prop = proposition[_prop_id];
        require(prop.status == PropositionStatus.Open, "Should be Open");
        prop.status = PropositionStatus.Reveal;

        for(uint256 i = 0; i < propositions_list.length; i++){
            if(propositions_list[i] == _prop_id){
                not_open_propositions_list.push(propositions_list[i]);
                propositions_list[i] = propositions_list[propositions_list.length - 1];
                propositions_list.pop();
            }
        }
    }

    // Change status of proposition VotingClosed > RevealingClosed
    function stop_revealing_proposition(uint256 _prop_id) internal {
        Proposition storage prop = proposition[_prop_id];
        require(prop.status == PropositionStatus.Reveal, "Should be Reveal");

        //check if all the certifiers have revealed, otherwise take their stake and put it in the lost_reward_pool
        for(uint i = 0; i< prop.certifiers_list.length; i++){
            uint stake = prop.certifier_stake[prop.certifiers_list[i]][VoteOption.Unknown];
            if (stake > 0){
                certifier_reward_pool[VoteOption.False] += stake/2;
                certifier_reward_pool[VoteOption.True] += stake/2;
                prop.certifier_stake[prop.certifiers_list[i]][VoteOption.Unknown] = 0;
            }
        }
        prop.status = PropositionStatus.Close;
    }

    function distribute_reward(uint256 _prop_id) internal {
        Proposition storage prop = proposition[_prop_id];
        require(prop.status == PropositionStatus.Close, "Should be Close");
        uint256 reward;
        address addr;

        // voters
        for (uint i = 0; i < prop.voters.length; i++){
            addr = prop.voters[i];
            
            reward = reward_voter(addr, _prop_id);
            prop.voter_earned_reward[addr] = reward;
            balance[addr] += reward;

        }

        // certifiers
        for (uint i = 0; i < prop.certifiers_list.length; i++){
            addr = prop.certifiers_list[i];
            reward = reward_certifier(addr, _prop_id);
            prop.certifier_earned_reward[addr] = reward;
            balance[addr] += reward;
            certifier_reward_pool[prop.outcome] -= certifier_reward_pool[prop.outcome]/tao;

        }

        // submitter: if the outcome is unknown, he gets back the bounty
        balance[prop.submitter] += (prop.outcome == VoteOption.Unknown) ? prop.bounty : 0;
    }

    // Compute the reward of a voter
    function reward_voter(address _voter, uint256 prop_id) internal returns(uint256){
        Proposition storage prop = proposition[prop_id];
        require(prop.status == PropositionStatus.Close, "Should be Close");
        VoteOption outcome = prop.outcome;
        uint256 reward;
        uint256 stake;
        VoteOption opposite = (outcome == VoteOption.True) ? VoteOption.False : VoteOption.True;

        // Voter is rewarded if his vote agrees with the outcome, eventual penalties go in the reward_pool
        if(outcome != VoteOption.Unknown){
            stake = prop.voter_stake[_voter][outcome];
            reward = stake + (stake * prop.bounty) / prop.vote_balance[outcome];
            certifier_reward_pool[opposite] += prop.voter_stake[_voter][opposite];
        }

        // otherwise if the outcome is Unknown, gets back his stake
        else{
            reward = prop.voter_stake[_voter][VoteOption.True] + prop.voter_stake[_voter][VoteOption.False];
        }

        prop.voter_stake[_voter][VoteOption.True] = 0;
        prop.voter_stake[_voter][VoteOption.False] = 0;

        return reward;
    }

    // Compute the reward of a certifier
    function reward_certifier(address _cert, uint256 prop_id) internal returns(uint256){
        Proposition storage prop = proposition[prop_id];
        require(prop.status == PropositionStatus.Close, "Should be Close");
        VoteOption outcome = prop.outcome;
        uint256 reward;
        uint256 stake;
        VoteOption opposite = (outcome == VoteOption.True) ? VoteOption.False : VoteOption.True;

        // Certifier is rewarded if the certification agrees with the outcome, eventual penalties and unclaimed bounties go in the reward_pool
        if(outcome != VoteOption.Unknown){
            stake = prop.certifier_stake[_cert][outcome];
            reward = (stake * certifier_reward_pool[outcome]) / (tao * prop.certificates[outcome]) + stake;
            certifier_reward_pool[opposite] += prop.certifier_stake[_cert][opposite] + prop.certifier_stake[_cert][VoteOption.Unknown];
        }

        // otherwise if the outcome is Unknown, loses everything
        else{
            reward = 0;
            certifier_reward_pool[opposite] += certifier_reward_pool[outcome]/tao;
        }

        prop.certifier_stake[_cert][VoteOption.Unknown] = 0;
        prop.certifier_stake[_cert][VoteOption.True] = 0;
        prop.certifier_stake[_cert][VoteOption.False] = 0;

        return reward;
    }

    /// ### VIEWS

    // Return a random proposition for a voter
    function find_random_proposition() internal view returns(uint256) {
        require(propositions_list.length > 0, "No proposition available");
        return propositions_list[random(propositions_list.length)];
    }

    // Generate a pseudo-random number from 0 to _max
    function random(uint256 _max) internal view returns (uint8)
    {
        return uint8(uint256(keccak256(abi.encodePacked(block.difficulty, block.timestamp, block.coinbase))) % _max);
    }
}
