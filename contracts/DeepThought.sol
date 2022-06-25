pragma solidity >=0.8.0 <0.9.0;
// SPDX-License-Identifier: UNLICENSED

/*
 * @title: DeepThought
 * @dev: Voting and Reputation-based Oracle with the aim of verifying propositions
 */

contract DeepThought {

    /* ### GLOBAL VARIABLES ### */

    // List of all the prop_id
    uint256[] propositions_list;

    // List of closed/revealing prop_id
    uint256[] closed_revealing_propositions_list;

    // Map of all the prop_id > proposition
    mapping (uint256 => Proposition) proposition;

    // balance of each address
    mapping (address => uint256) balance;

    // Reputation of each address
    mapping (address => uint256) reputation;

    // Voter > prop_id | stake voter spent to vote a proposition  
    mapping (address => mapping(uint256 => uint256)) ask_to_vote_stake;
    
    // Certifier > prop_id | stake certifier spent to certify a proposition
    mapping (address => uint256) ask_to_certify_stake;

    // Voter > list of voted proposition
    mapping (address => uint256[]) voted_propositions;

    // Voter > list of certified proposition
    mapping (address => uint256[]) certified_propositions;

    // Voter > list of submitted proposition
    mapping (address => uint256[]) submitted_propositions;
    
    /* ### PARAMETERS OF THE ORACLE ### */

    // Minimum voter stake can pay for a vote
    uint256 min_voter_stake;

    // Maximum voter stake can pay for a vote
    uint256 max_voter_stake;

    // Minimum certifier stake can pay for a certification
    uint256 min_certifier_stake;

    // Maximum certifier stake can pay for a certification
    uint256 max_certifier_stake;
    
    // Minimum value of the bounty
    uint256 min_bounty;
    
    // Pool of money of Unknown proposition
    uint256 lost_reward_pool;
    
    // Maximum reputation value for a voter
    uint256 max_reputation;

    // Parameter for vote weight calculation
    uint256 alfa;

    // Parameter for reward calculation
    uint256 beta;

    // Parameter for the Scoreboard reward mechanism
    uint256 to_reward_perc;

    // Number of vote required to close a proposition
    uint256 n_max_votes;

    /* ### STRUCTURES ### */

    enum VoteOption {Unknown, True, False}

    enum PropositionStatus {Open, VotingClose, RevealingClose}

    struct Vote {

        VoteOption vote_unhashed;

        address voter;

        bytes32 vote_hashed;

        uint256 stake;

        uint256 prediction;

        uint256 score;

        uint256 vote_weigth;

    }
    
    struct Proposition {
        // Submitter address
        address submitter;

        // Unique proposition ID
        uint256 id;
        
        // Content of the proposition
        bytes32 content;
        
        // Bounty attached to proposition
        uint256 bounty;
        
        // Total certifications stake
        uint256 certifiers_stake_pool;

        //Total vote stake
        uint256 voters_stake_pool;

        // The status of the proposition Open > votingClosed > RevealClosed
        PropositionStatus status;

        // VoteOption > sum of votes weight for the specific VoteOption
        mapping (VoteOption => uint256) partial_outcome;

        // Decided outcome
        VoteOption outcome;

        // Array of votes
        Vote[] votes;

        // voter > index of the voter's votes in votes array 
        mapping (address => uint256[]) voted_indexes;

        // voter > reward earned on the proposition
        mapping (address => uint256) voter_earned_reward;
        
        // Total certifing value for each option
        mapping (VoteOption => uint256) certification;

        // List of the addresses who certified
        address[] certifiers_list;

        // Certifiers vote and stake (no need to divide it in multiple maps like for the voters since the vote is not sealed)
        mapping (address => mapping (VoteOption => uint256)) certifier_stake;

        // The certifier's vote hashed, before the revealing phase
        mapping (address => bytes32) certifier_hashedVote;

        // certifier > reward earned on the proposition
        mapping (address => uint256) certifier_earned_reward;

        // Scoreboard: importance order
        Vote[] scoreboard;

        // Votes submitting vote T
        uint256[] T_vote_indexes;
        
        // Votes submitting vote F
        uint256[] F_vote_indexes;
        
        //Certifiers submitting cert T
        address[] T_certifiers;

        //Certifiers submitting cert F
        address[] F_certifiers;

        //voter > final vote_weigth balance
        mapping(address => int256) vote_balance;

        //voter > has the reputation updated
        mapping(address => bool) rep_updated;
    }

    /* ### EVENTS ### */

    // Event to return the prop_id after the voting transaction 
    event return_id(uint256 prop_id);

    /* ### CONSTRUCTORS ### */
    
    constructor(uint256 _n_max_votes, uint256 _alfa, uint256 _beta){
        //n_max_votes = 3;
        n_max_votes = _n_max_votes;
        
        max_reputation = 100;
        
        lost_reward_pool = 0;
        
        //lfa = 70;
        alfa = _alfa;
        
        //beta = 30;
        beta = _beta;

        to_reward_perc = 50;

        min_voter_stake = 1;

        max_voter_stake = 10 ** 3;

        min_certifier_stake = 10 ** 3;

        max_certifier_stake = 10 ** 6;

        min_bounty = to_reward_perc * (beta * (max_voter_stake ** 2) + (100 - beta) * (max_voter_stake + max_voter_stake * sqrt(max_reputation * 10000)/100))/10000 * n_max_votes - min_voter_stake * n_max_votes;
    }

    /* ### WORKFLOW ### */
    // SUBMITTER: subscribe > set_min_bounty > submit_proposition > [wait for all to vote] > [wait for revealing or eventually result_proposition]
    // VOTER: subscribe > voting_request > vote > [wait for all to vote] > reveal_sealed_vote > [get the rewards when propositon is closed]
    // CERTIFIER: subscribe > certification_request > show_propositions > certify_proposition > [wait for all to vote] > reveal_sealed_vote > [get the rewards when propositon is closed]

    /* ### OUT FUNCTIONS ### */

    // ### Getters

    function get_balance() public view returns(uint256){
        return balance[msg.sender];
    }

    function get_reputation() public view returns(uint256){
        return reputation[msg.sender];
    }

    function get_min_bounty() public view returns(uint256){
        return min_bounty;
    }

    function get_min_stake_voter() public view returns (uint256){
        return min_voter_stake;
    }

    function get_max_stake_voter() public view returns (uint256){
        return max_voter_stake;
    }

    function get_min_stake_certifier() public view returns (uint256){
        return min_certifier_stake;
    }

    function get_max_stake_certifier() public view returns (uint256){
        return max_certifier_stake;
    }

    function get_number_propositions() public view returns (uint256){
        require (ask_to_certify_stake[msg.sender] > 0, "Not a certifier! Make a request");
        return propositions_list.length;
    }

    function get_prop_id_by_index(uint256 _i) public view returns (uint256){
        require (ask_to_certify_stake[msg.sender] > 0, "Not a certifier! Make a request");
        require (_i < propositions_list.length, "Out of bound");
        return propositions_list[_i];
    }

    function get_prop_content_by_prop_id(uint256 _prop_id) public view returns (bytes32){
        return proposition[_prop_id].content;
    }

    function get_number_voted_propositions() public view returns (uint256){
        return voted_propositions[msg.sender].length;
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
            if(proposition[_prop_id].status == PropositionStatus.VotingClose){
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

    function get_n_voted_times(uint256 _prop_id) public view returns (uint256){
        return proposition[_prop_id].voted_indexes[msg.sender].length;
    }

    /* ### UTILITY FUNCTIONS ### */

    // Generate a pseudo-random number from 0 to _max
    function random(uint256 _max) internal view returns (uint256) {
        return uint256(uint256(keccak256(abi.encodePacked(block.difficulty, block.timestamp, block.coinbase))) % _max);
    }

    // Get the square root of a number
    function sqrt(uint256 x) internal pure returns (uint256 y) {
        uint256 z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }

    // ### State Changer

    // Subscribe to the service and put founds in it
    function subscribe() public{
        require(balance[msg.sender] == 0, "Already subscribed!");

        balance[msg.sender] = msg.sender.balance;
        reputation[msg.sender] = 1;
    }
    
    // Submit a new proposition
    function submit_proposition(uint256 _prop_id, bytes32 _prop_content, uint256 _bounty) public {
        require (_bounty >= min_bounty, "Bounty is too low, check the minimum bounty");
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
    
    // Put your stake to be able to view the proposition as a certifier
    function certification_request(uint256 _stake) public {
        require (ask_to_certify_stake[msg.sender] == 0, "Action already performed! Choose a proposition");
        require (balance[msg.sender] >= _stake, "Not enough money to certify");
        require (_stake >= min_certifier_stake, "The stake is not enough for your reputation");
        require (_stake <= max_certifier_stake, "The stake is too high");

        ask_to_certify_stake[msg.sender] = _stake;
        balance[msg.sender] -= _stake;
    }
    
    // A certifier send his vote for a proposition
    function certify_proposition(uint256 _prop_id, bytes32 _hashed_vote) public {
        require (ask_to_certify_stake[msg.sender] > 0, "Not a certifier! Make a request");

        // Get the chosen proposition
        Proposition storage prop = proposition[_prop_id];

        // Increment the vote and move the stake to the proposition chosen
        prop.certifiers_list.push(msg.sender);
        uint256 stake = ask_to_certify_stake[msg.sender];
        ask_to_certify_stake[msg.sender] = 0;
        prop.certifier_hashedVote[msg.sender] = _hashed_vote;
        prop.certifiers_stake_pool += stake;
        prop.certifier_stake[msg.sender][VoteOption.Unknown] += stake;
        certified_propositions[msg.sender].push(_prop_id);
    }

    // reveal the certifier's vote for a proposition
    function reveal_certifier_hashed_vote(uint256 _prop_id, string memory _salt) public {
        Proposition storage prop = proposition[_prop_id];

        require(prop.status == PropositionStatus.VotingClose, "Proposition is not in the reveal phase!");

        bytes32 hashed_vote = prop.certifier_hashedVote[msg.sender];

        if(hashed_vote == keccak256(abi.encodePacked(_prop_id, true, _salt))){
            // Vote was true
            prop.certifier_stake[msg.sender][VoteOption.True] += prop.certifier_stake[msg.sender][VoteOption.Unknown];
            prop.T_certifiers.push(msg.sender);

        }else if(hashed_vote == keccak256(abi.encodePacked(_prop_id, false, _salt))){
            // Vote was false
            prop.certifier_stake[msg.sender][VoteOption.True] += prop.certifier_stake[msg.sender][VoteOption.Unknown];
            prop.F_certifiers.push(msg.sender);
        }else{
            revert("Wrong salt!!!");
        }
        prop.certifier_stake[msg.sender][VoteOption.Unknown] = 0;
    }
    
    // Put your stake to receive a random proposition (via event)
    function voting_request(uint256 _stake) public {
        require (_stake >= min_voter_stake, "The stake is not enough for your reputation");
        require (_stake <= max_voter_stake, "The stake is too high");
        require (balance[msg.sender] >= _stake, "Not enough money to vote");

        uint256 prop_id = find_random_proposition();
        ask_to_vote_stake[msg.sender][prop_id] = _stake;
        balance[msg.sender] -= _stake;

        //To return a value from a state changer function we emit an event
        emit return_id(prop_id);
    }
    
    // Vote for the proposition you received
    function vote(uint256 _prop_id, bytes32 _hashed_vote, uint256 _predictionPercent) public {
        require (ask_to_vote_stake[msg.sender][_prop_id] > 0, "Not a voter of that proposition! Make a request");

        // Get the proposition
        Proposition storage prop = proposition[_prop_id];
        require(prop.status == PropositionStatus.Open, "Voting phase is closed!");

        // Move the stake to the proposition and vote
        uint256 stake = ask_to_vote_stake[msg.sender][_prop_id];
        ask_to_vote_stake[msg.sender][_prop_id] = 0;

        prop.votes.push(Vote(VoteOption.Unknown, msg.sender, _hashed_vote, stake, _predictionPercent, 0, 0));
        prop.voted_indexes[msg.sender].push(prop.votes.length - 1);
        prop.voters_stake_pool += stake;

        if(prop.voted_indexes[msg.sender].length == 1){
            voted_propositions[msg.sender].push(_prop_id);
        }

        if (prop.votes.length >= n_max_votes){
            close_proposition(_prop_id);
        }
    }

    // Reveal the voter's vote for a proposition
    function reveal_voter_hashed_vote(uint256 _prop_id, string memory _salt, uint256 index) public {
        Proposition storage prop = proposition[_prop_id];
        require(prop.status == PropositionStatus.VotingClose, "Proposition is not in the reveal phase!");
        bytes32 hashed_vote = prop.votes[prop.voted_indexes[msg.sender][index]].vote_hashed;
        require(hashed_vote != "", "Vote already revealed!");
        
        if(hashed_vote == keccak256(abi.encodePacked(_prop_id, true, _salt))){
            // Vote was true
            prop.votes[prop.voted_indexes[msg.sender][index]].vote_unhashed = VoteOption.True;
            prop.T_vote_indexes.push(prop.voted_indexes[msg.sender][index]);

        }else if(hashed_vote == keccak256(abi.encodePacked(_prop_id, false, _salt))){
            // Vote was false
            prop.votes[prop.voted_indexes[msg.sender][index]].vote_unhashed = VoteOption.False;
            prop.F_vote_indexes.push(prop.voted_indexes[msg.sender][index]);

        }else{
            revert("Wrong salt!!!");
        }

        if(prop.F_vote_indexes.length + prop.T_vote_indexes.length == prop.votes.length){
            elaborate_result_proposition(_prop_id);
        }
    }
 
    /* ### INTERNAL FUNCTIONS ### */

    // This function has to be called to elaborate a proposition result. It calls other internal functions
    function elaborate_result_proposition(uint256 _prop_id) internal {
        stop_revealing_proposition(_prop_id);
        elaborate_votes_weight(_prop_id);
        elaborate_certifications_weight(_prop_id);
        set_outcome(_prop_id);
        //create_scoreboard(_prop_id);
        //distribute_rewards(_prop_id);
        distribute_reputation(_prop_id);
    }

    // Change status of proposition Open > VotingClosed
    function close_proposition(uint256 _prop_id) internal {
        Proposition storage prop = proposition[_prop_id];
        require(prop.status == PropositionStatus.Open, "Should be Open");
        prop.status = PropositionStatus.VotingClose;

        for(uint256 i = 0; i < propositions_list.length; i++){
            if(propositions_list[i] == _prop_id){
                closed_revealing_propositions_list.push(propositions_list[i]);
                propositions_list[i] = propositions_list[propositions_list.length - 1];
                propositions_list.pop();
            }
        }
    }

    // Change status of proposition VotingClosed > RevealingClosed
    function stop_revealing_proposition(uint256 _prop_id) internal {
        Proposition storage prop = proposition[_prop_id];
        require(prop.status == PropositionStatus.VotingClose, "Should be Reveal");

        // Check if all the certifiers have revealed, otherwise take their stake and put it in the lost_reward_pool
        for(uint i=0; i< prop.certifiers_list.length; i++){
            uint stake = prop.certifier_stake[prop.certifiers_list[i]][VoteOption.Unknown];
            if (stake > 0){
                lost_reward_pool += stake;
                prop.certifier_stake[prop.certifiers_list[i]][VoteOption.Unknown] = 0;
            }
        }

        //Set proposition state to RevealingClose (Closed)
        prop.status = PropositionStatus.RevealingClose;
    }

    function elaborate_votes_weight(uint256 _prop_id) internal{
        Proposition storage prop = proposition[_prop_id];
        require(prop.status == PropositionStatus.RevealingClose, "Should be Close");

        for(uint i=0; i < prop.T_vote_indexes.length; i++){
            uint256 vote_weigth = normalize_voter_vote_weight(prop.votes[prop.T_vote_indexes[i]]);
            prop.partial_outcome[VoteOption.True] += vote_weigth;
            prop.votes[prop.T_vote_indexes[i]].vote_weigth = vote_weigth;
        }

        for(uint i=0; i < prop.F_vote_indexes.length; i++){
            uint256 vote_weigth = normalize_voter_vote_weight(prop.votes[prop.F_vote_indexes[i]]);
            prop.partial_outcome[VoteOption.False] += vote_weigth;
            prop.votes[prop.F_vote_indexes[i]].vote_weigth = vote_weigth;
        }

    }

    function elaborate_certifications_weight(uint256 _prop_id) internal{
        Proposition storage prop = proposition[_prop_id];
        require(prop.status == PropositionStatus.RevealingClose, "Should be Close");

        for(uint i=0; i < prop.T_certifiers.length; i++){
            prop.certification[VoteOption.True] += normalize_certifier_vote_weight(prop.T_certifiers[i], _prop_id, true);
        }

        for(uint i=0; i < prop.F_certifiers.length; i++){
            prop.certification[VoteOption.False] += normalize_certifier_vote_weight(prop.F_certifiers[i], _prop_id, false);
        }
        
    }

    // Distribute the reputation to all the voters
    function distribute_reputation(uint256 _prop_id) internal {
        Proposition storage prop = proposition[_prop_id];
        require(prop.status == PropositionStatus.RevealingClose, "Should be Close");


        // Change the voters reputation according to the proposition outcome
        for(uint256 i = 0; i < prop.votes.length ; i++){
            address voter_addr = prop.votes[i].voter;
            if(prop.votes[i].vote_unhashed == prop.outcome){
                prop.vote_balance[voter_addr] += int256(prop.votes[i].vote_weigth);
            }else{
                if(prop.outcome != VoteOption.Unknown){
                    prop.vote_balance[voter_addr] -= int256(prop.votes[i].vote_weigth);
                }
            }
        }

        for(uint256 i = 0; i < prop.votes.length ; i++){
            address voter_addr = prop.votes[i].voter;
            if(prop.rep_updated[voter_addr] == false){
                if(prop.vote_balance[voter_addr] > 0){
                    increment_reputation(voter_addr);
                }else{
                    if(prop.vote_balance[voter_addr] < 0){
                        decrement_reputation(voter_addr);
                    }
                }
                prop.rep_updated[voter_addr] = true;
            }
        }



        for(uint256 j = 0; j < prop.certifiers_list.length; j++){
            address cert_addr = prop.certifiers_list[j];
            if(prop.certifier_stake[cert_addr][prop.outcome] > 0){
                increment_reputation(cert_addr);
            }else{
                if(prop.outcome != VoteOption.Unknown){
                    decrement_reputation(cert_addr);
                }
            }
        }
    }  

    // Distribute the rewards to all the voters and certifiers
    function distribute_rewards(uint256 _prop_id) internal {
        Proposition storage prop = proposition[_prop_id];
        require(prop.status == PropositionStatus.RevealingClose, "Should be Close");

        uint256 cert_reward_pool =  prop.certifiers_stake_pool;
        uint256 voters_reward_pool = prop.bounty + prop.voters_stake_pool;

        // redistribute the bounty to the submitter and the stake to all voters when the outcome is "Unknown"
        // store the stakes submitted by certifiers
        if(prop.outcome == VoteOption.Unknown){

            balance[prop.submitter] += prop.bounty;

            for(uint256 i = 0; i < prop.votes.length; i++){
                balance[prop.votes[i].voter] += prop.votes[i].stake;
                prop.voters_stake_pool -= prop.votes[i].stake;
            }
            for(uint256 i = 0; i < prop.certifiers_list.length; i++){
                lost_reward_pool += prop.certifier_stake[prop.certifiers_list[i]][VoteOption.True] + prop.certifier_stake[prop.certifiers_list[i]][VoteOption.False];
                prop.certifiers_stake_pool -= prop.certifier_stake[prop.certifiers_list[i]][VoteOption.True] + prop.certifier_stake[prop.certifiers_list[i]][VoteOption.False];
            }
        }
        else{
            if(prop.certifiers_list.length > 0){
                // Distribute rewards to certifiers
                uint256 prop_lost_reward_pool = lost_reward_pool/(propositions_list.length + 1);
                lost_reward_pool -= prop_lost_reward_pool;

                for(uint256 i = 0; i < prop.certifiers_list.length; i++){
                    address addr = prop.certifiers_list[i];
                    uint256 cert_reward = compute_certifier_reward(addr, _prop_id, prop_lost_reward_pool, cert_reward_pool);
                    if(prop.certifier_stake[addr][prop.outcome] > 0){
                        balance[addr] += cert_reward;
                        prop.certifier_earned_reward[addr] += cert_reward;
                        cert_reward_pool -= prop.certifier_stake[addr][prop.outcome];
                    }
                }
            }

            // Distribute rewards to voters
            for(uint256 i = 0; i < prop.scoreboard.length * to_reward_perc/100; i++){
                Vote storage vote_to_reward = prop.scoreboard[i];
                uint256 voter_reward = compute_voter_reward(vote_to_reward);
                if (voters_reward_pool > voter_reward){ //Check -> voter_reward_pool can't be negative
                    balance[vote_to_reward.voter] += voter_reward;
                    prop.voter_earned_reward[vote_to_reward.voter] += voter_reward;
                    voters_reward_pool -= voter_reward;
                }else break;
            }
            // the lost_reward pool receive the certification bounty part (if there aren't certificators) and the extra voter_reward_pool
            lost_reward_pool += voters_reward_pool + cert_reward_pool;
            voters_reward_pool = 0;
            cert_reward_pool = 0;
        }

        
    } 

    // Set the outcome based on the vote majority
    function set_outcome(uint256 _prop_id) internal {
        Proposition storage prop = proposition[_prop_id];
        require(prop.status == PropositionStatus.RevealingClose, "Should be Close");
        VoteOption voter_result = VoteOption.Unknown;
        VoteOption cert_result = VoteOption.Unknown;

        if(prop.partial_outcome[VoteOption.True] > prop.partial_outcome[VoteOption.False]) voter_result = VoteOption.True;
        else{
            if(prop.partial_outcome[VoteOption.False] > prop.partial_outcome[VoteOption.True]) voter_result = VoteOption.False;
        }

        if(prop.certification[VoteOption.True] > prop.certification[VoteOption.False]) cert_result = VoteOption.True;
        else{
            if(prop.certification[VoteOption.False] > prop.certification[VoteOption.True]) cert_result = VoteOption.False;
        }

        if(voter_result == cert_result || cert_result == VoteOption.Unknown) prop.outcome = voter_result;
    }  

    // Create the scoreboard
    function create_scoreboard(uint256 _prop_id) internal {
        Proposition storage prop = proposition[_prop_id];

        require(prop.status == PropositionStatus.RevealingClose, "Should be Close");

        address voter_addr;

        for(uint256 i = 0; i < prop.T_vote_indexes.length; i++){
           voter_addr = prop.votes[prop.T_vote_indexes[i]].voter;
           prop.votes[prop.T_vote_indexes[i]].score = assign_score(_prop_id, prop.votes[prop.T_vote_indexes[i]]);
           insert_scoreboard(_prop_id, prop.votes[prop.T_vote_indexes[i]]);
        }

        for(uint256 j = 0; j < prop.F_vote_indexes.length; j++){
           voter_addr = prop.votes[prop.F_vote_indexes[j]].voter;
           prop.votes[prop.F_vote_indexes[j]].score = assign_score(_prop_id, prop.votes[prop.F_vote_indexes[j]]);
           insert_scoreboard(_prop_id, prop.votes[prop.F_vote_indexes[j]]);
        }
    } 

    // In-order voters insert inside scoreboard, from the Higher to the Lower
    function insert_scoreboard(uint256 _prop_id, Vote storage this_vote) internal{
        Proposition storage prop = proposition[_prop_id];
        Vote storage to_write = this_vote;
        Vote storage store;
        for(uint i=0; i < prop.scoreboard.length; i++){
            if(to_write.score > prop.scoreboard[i].score){
                store = prop.scoreboard[i];
                prop.scoreboard[i] = to_write;
                to_write = store;
            }
        }
        
        prop.scoreboard.push(to_write);
    }  
    
    // Calculate the vote weight of a voter for a proposition
    function normalize_voter_vote_weight(Vote storage this_vote) internal view returns(uint256) {
        uint256 stake = this_vote.stake;
        uint256 rep = reputation[this_vote.voter];
        return ((alfa * sqrt(stake) + (100 - alfa) * (stake))/100) * sqrt(rep * 10000)/100;
    }

    // Calculate the vote weight of a certifier for a proposition
    function normalize_certifier_vote_weight(address _certifier, uint256 prop_id, bool _vote) internal view returns(uint256) {
        Proposition storage prop = proposition[prop_id];
        uint256 stake;
        if(_vote){
            stake = prop.certifier_stake[_certifier][VoteOption.True];
        }else{
            stake = prop.certifier_stake[_certifier][VoteOption.False];
        }
    
        uint256 rep = reputation[_certifier];
        return ((alfa * sqrt(stake) + (100 - alfa) * stake)/100) * sqrt(rep * 10000)/100;
    }

    // Calculate the reward of a voter for a proposition
    function compute_voter_reward(Vote storage this_vote) internal view returns(uint256) {
        uint256 stake = this_vote.stake;
        uint256 rep = reputation[this_vote.voter];
        return (beta * (stake ** 2) + (100 - beta) * (stake + stake * sqrt(rep * 10000)/100))/100;
    }

    // Calculate the reward of a certifier for a proposition
    function compute_certifier_reward(address _certifier, uint256 _prop_id, uint256 prop_lost_reward_pool, uint256 cert_reward_pool) internal view returns(uint256){
        Proposition storage prop = proposition[_prop_id];
        uint256 stake = prop.certifier_stake[_certifier][prop.outcome];

        uint256 addition = (prop_lost_reward_pool * stake)/cert_reward_pool;

        //certifier reward = stake

        return stake + addition;
    }
    
    // Return a random propositon for a voter
    function find_random_proposition() internal view returns(uint256) {
        require(propositions_list.length > 0, "No proposition available");
        return propositions_list[random(propositions_list.length)];
    }
    
    // Generate the scoreboard for a proposition
    function assign_score(uint _prop_id, Vote storage this_vote) internal view returns(uint){
        Proposition storage prop = proposition[_prop_id];
        require(prop.status == PropositionStatus.RevealingClose, "Proposition status should be RevealingClose!");
        uint pred_score;
        uint info_score;
        uint q = this_vote.prediction;
        VoteOption w = VoteOption.Unknown;
        uint pred_mean = prediction_mean(this_vote, _prop_id);
        w = prop.votes[random(prop.votes.length)].vote_unhashed; //MPPO
        pred_score = w == VoteOption.True ? 200 * q - q ** 2 : 10000 - q ** 2;
        info_score = pred_mean > q ? 10000 - (pred_mean - q) ** 2 : 10000 - (q - pred_mean) ** 2;
        return pred_score + info_score;
    }

    // Produce the arithmetic mean without the prediction of the voter itself (should be a geometric mean)
    function prediction_mean(Vote storage this_vote, uint256 _prop_id) internal view returns(uint256){
        Proposition storage _prop = proposition[_prop_id];
        uint256 i;
        uint256 tot = 0;
        uint256 num;
        if(this_vote.vote_unhashed == VoteOption.True){
            num = _prop.T_vote_indexes.length;
            if(num == 1){
                return 0;
            }
            for(i = 0; i < num; i++){
                tot += _prop.votes[_prop.T_vote_indexes[i]].prediction;
            }
        }else{
            num = _prop.F_vote_indexes.length;
            if(num == 1){
                return 100;
            }
            for(i = 0; i < num; i++){
               tot += _prop.votes[_prop.F_vote_indexes[i]].prediction;
            }
        }
        tot -= this_vote.prediction;
        num -= 1;
        require(num != 0 , "Division by zero!");
        return tot/num; 
    }
    
    // Increment the reputation of a voter
    function increment_reputation(address _voter) internal {
        uint256 rep = reputation[_voter];
        if (rep < max_reputation) {
            reputation[_voter] += 1;
        }
    }

    // Decrement the reputation of a voter
    function decrement_reputation(address _voter) internal {
        uint256 rep = reputation[_voter];
        if (rep > 1) {
            reputation[_voter] -= 1;
        }
    }

}
