pragma solidity >=0.8.0 <0.9.0;
// SPDX-License-Identifier: UNLICENSED


/**
 * @title DeepThought
 * @dev 
 */
contract DeepThought /*is usingOraclize*/ {
    
    // ### PARAMETERS OF THE ORACLE
    
    // Number of votes required to close a proposition
    uint64 max_voters;
    
    // Minimum value of the bounty
    uint64 min_bounty;
    
    // Pool of money of Unknown propositions
    uint256 lost_reward_pool;

    // Divider of lost_reward_pool being distributed to certifiers
    uint256 lost_reward_pool_split;
    
    // Maximum reputation value for a voter
    uint16 max_reputation;

    // Parameter for vote weight calculation
    uint16 alfa;

    // Parameter for reward calculation
    uint16 beta;

    // ### GLOBAL VARIABLES

    // List of all the prop_id
    uint256[] proposition_list;

    // List of closed/revealing prop_id
    uint256[] old_proposition_list;

    // Map of all the prop_id > propositions
    mapping (uint256 => Proposition) propositions;

    // Balances of each address
    mapping (address => uint256) balances;

    // Reputation of each address
    mapping (address => uint256) reputations;

    // Voter > prop_id > stake to check if he staked something so he can see which proposition he was assign to  
    mapping (address => mapping(uint256 => uint256)) ask_to_vote_stakes;
    
    // Certifier > stake to check if he staked something so he can see the proposition list
    mapping (address => uint256) ask_to_certify_stakes;

    mapping (address => uint256[]) voted_propositions;

    mapping (address => uint256[]) certified_propositions;

    mapping (address => uint256[]) submitted_propositions;

    // ### STRUCTURES

    enum VoteOption {Unknown, True, False}

    enum PropositionStatus {Open, VotingClose, RevealingClose}
    
    struct Proposition {
        // Unique proposition ID
        uint256 id;

        // Submitter address
        address submitter;
        
        // Content of the proposition
        bytes32 content;
        
        // Bounty attached to proposition (max stake is half bounty)
        uint256 bounty;
        
        // Total voting stake
        uint256 stakes_total;

        mapping (address => uint256) voters_reward;

        mapping (address => uint256) certifiers_reward;

        // The status of the proposition Open > votingClosed > RevealClosed
        PropositionStatus status;

        // Decided outcome
        VoteOption decision;

        // Total voting value for each option
        mapping (VoteOption => uint256) votes;
        
        // Total certifing value for each option
        mapping (VoteOption => uint256) certificates;

        // List of the addresses who certified
        address[] certifiers_list;
        
        // Certifiers vote and stake (no need to divide it in multiple maps like for the voters since the vote is not sealed)
        mapping (address => mapping (VoteOption => uint256)) certifier_stakes;

        // List of the addresses who voted
        address[] voters_list;
        
        // Voters certainty for the outcome
        mapping(address => uint256) prediction_cert;
        
        // Voters stake
        mapping(address => uint256) voters_stakes;

        // Voters sealed vote
        mapping(address => bytes32) voters_sealedVotes;

        // Voters unsealed vote
        mapping(address => VoteOption) voters_unsealedVotes;

        // Scoreboard: importance order
        address[] scoreboard;
        
        // Score for each voter
        mapping(address => uint256) scores;

        // Voters submitting vote T
        address[] T_voters;
        
        // Voters submitting vote F
        address[] F_voters;
        
        //Certifiers submitting cert T
        address[] T_certifiers;

        //Certifiers submitting cert F
        address[] F_certifiers;
    }

    // ### EVENTS

    event return_id(uint256 prop_id);

    // ### CONSTRUCTORS
    
    constructor(){
        // Initialize the parameters of the oracle
        max_voters = 3;
        
        // the max reputation reachable for voters
        max_reputation = 100;
        
        // the minimum bounty is 100 times the max bid of certification (with max_rep = 100 is about 2 * 10**16 wei ~ 0.02 ETH ~ 50$)
        min_bounty = uint64(get_max_certifing_stake() * 50);
        
        lost_reward_pool = 0;

        lost_reward_pool_split = 100;
        
        alfa = 70; // %
        
        beta = 30; // %

    }

    // ### THE WORKFLOW SHOULD BE:
    // SUBMITTER: subscribe > submit_proposition > [wait for all to vote] > [wait for revealing or eventually result_proposition]
    // VOTER: subscribe > voting_request > vote > [wait for all to vote] > reveal_sealed_vote > [get the rewards when propositon is closed]
    // CERTIFIER: subscribe > certification_request > show_propositions > certify_proposition > [get the rewards when propositon is closed]

    // ### OUT FUNCTIONS

    // ### Getters

    function get_balance() public view returns(uint256){
        return balances[msg.sender];
    }

    function get_reputation() public view returns(uint256){
        return reputations[msg.sender];
    }

    function get_min_bounty() public view returns(uint256){
        return min_bounty;
    }

    function get_min_stake_voter() public view returns (uint256){
        return get_min_voting_stake(msg.sender);
    }

    function get_max_stake_voter() public view returns (uint256){
        return get_max_voting_stake();
    }

    function get_min_stake_certifier() public view returns (uint256){
        return get_min_certifing_stake(msg.sender);
    }

    function get_max_stake_certifier() public view returns (uint256){
        return get_max_certifing_stake();
    }


    // A certifier who staked can see all the propositions
    function get_max_number_of_propositions() public view returns (uint256){
        require (ask_to_certify_stakes[msg.sender] > 0, "Not a certifier! Make a request");
        return proposition_list.length;
    }

    function show_propositions(uint256 _i) public view returns (uint256){
        require (ask_to_certify_stakes[msg.sender] > 0, "Not a certifier! Make a request");
        require (_i < proposition_list.length, "Out of bound");
        return proposition_list[_i];
    }

    function get_prop_content(uint256 _prop_id) public view returns (bytes32){
        return propositions[_prop_id].content;
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
        if (propositions[_prop_id].status == PropositionStatus.Open){
            return bytes32("Open");
        }
        else{
            if(propositions[_prop_id].status == PropositionStatus.VotingClose){
                return bytes32("Reveal");
            }
            else{
                return bytes32("Close");
            }
        }
    }

    function get_outcome(uint256 _prop_id) public view returns (bytes32){
        if (propositions[_prop_id].decision == VoteOption.True){
            return bytes32("True");
        }
        else{
            if(propositions[_prop_id].decision == VoteOption.False){
                return bytes32("False");
            }
            else{
                return bytes32("Unknown");
            }
        }
    }

    function get_reward_voter_by_prop_id(uint256 _prop_id) public view returns (uint256){
        return propositions[_prop_id].voters_reward[msg.sender];
    }

    function get_reward_certifier_by_prop_id(uint256 _prop_id) public view returns (uint256){
        return propositions[_prop_id].certifiers_reward[msg.sender];
    }

    // ### State Changer

    // Subscribe to the service and put founds in it
    function subscribe() public{
        require(balances[msg.sender] == 0, "Already subscribed!");
        balances[msg.sender] = msg.sender.balance/(10 ** 6);
        reputations[msg.sender] = 1;
    }
    
    // Submit a new proposition
    function submit_proposition(uint256 _prop_id, bytes32 _prop_content, uint256 _bounty) public {
        require (_bounty > min_bounty, "Bounty is too low, check the minimum bounty");
        require (balances[msg.sender] >= _bounty, "Not enough money to submit");
        proposition_list.push(_prop_id);
        Proposition storage p = propositions[_prop_id];
        p.id =_prop_id;
        p.submitter = msg.sender;
        p.content = _prop_content;
        p.bounty = _bounty;
        p.status = PropositionStatus.Open;
        p.decision = VoteOption.Unknown;

        balances[msg.sender] -= _bounty;

        submitted_propositions[msg.sender].push(_prop_id);
    }
    
    // Put your stake to be able to view the propositions as a certifier
    function certification_request(uint256 _stake) public {
        require (ask_to_certify_stakes[msg.sender] == 0, "Action already performed! Choose a proposition");
        require (balances[msg.sender] >= _stake, "Not enough money to certify");
        require (_stake >= get_min_certifing_stake(msg.sender), "The stake is not enough for your reputation");
        require (_stake <= get_max_certifing_stake(), "The stake is too high");
        ask_to_certify_stakes[msg.sender] = _stake;
        balances[msg.sender] -= _stake;
    }
    
    // A certifier send his vote for a proposition
    function certify_proposition(uint256 _prop_id, bool _vote) public {
        require (ask_to_certify_stakes[msg.sender] > 0, "Not a certifier! Make a request");
        // Get the chosen proposition
        Proposition storage prop = propositions[_prop_id];
        // Increment the vote and move the stake to the proposition chosen
        prop.certifiers_list.push(msg.sender);
        uint256 stake = ask_to_certify_stakes[msg.sender];
        ask_to_certify_stakes[msg.sender] = 0;
        prop.certifier_stakes[msg.sender][_vote? VoteOption.True : VoteOption.False] += stake;
        prop.stakes_total += stake;
        if(_vote){
            prop.certificates[VoteOption.True] += normalize_certifier_vote_weight(msg.sender, _prop_id, _vote);
            prop.T_certifiers.push(msg.sender);
        }else{
            prop.certificates[VoteOption.False] += normalize_certifier_vote_weight(msg.sender, _prop_id, _vote);
            prop.F_certifiers.push(msg.sender);
        }

        certified_propositions[msg.sender].push(_prop_id);
    }
    
    // Put your stake to receive a random proposition (via event)
    function voting_request(uint256 _stake) public {
        require (_stake >= get_min_voting_stake(msg.sender), "The stake is not enough for your reputation");
        require (_stake <= get_max_voting_stake(), "The stake is too high");
        require (balances[msg.sender] >= _stake, "Not enough money to vote");
        uint256 prop_id = get_proposition();
        ask_to_vote_stakes[msg.sender][prop_id] = _stake;
        balances[msg.sender] -= _stake;

        //To return a value from a state changer function we emit an event
        emit return_id(prop_id);
    }
    
    // Vote for the proposition you received
    function vote(uint256 _prop_id, bytes32 _hashedVote, uint256 _predictionPercent) public {
        require (ask_to_vote_stakes[msg.sender][_prop_id] > 0, "Not a voter of that proposition! Make a request");
        // Get the propositon
        Proposition storage prop = propositions[_prop_id];
        require(prop.status == PropositionStatus.Open, "Voting phase is closed!");
        // Move the stake to the proposition and vote
        uint256 stake = ask_to_vote_stakes[msg.sender][_prop_id];
        ask_to_vote_stakes[msg.sender][_prop_id] = 0;
        prop.voters_list.push(msg.sender);
        prop.voters_sealedVotes[msg.sender] = _hashedVote;
        prop.voters_unsealedVotes[msg.sender] = VoteOption.Unknown;
        prop.voters_stakes[msg.sender] = stake;
        prop.stakes_total += stake;
        prop.prediction_cert[msg.sender] = _predictionPercent;
        // If the max_voters number is reached the voting phase is closed
        if (prop.voters_list.length >= max_voters){
            close_proposition(_prop_id);
        }

        voted_propositions[msg.sender].push(_prop_id);
    }

    // Reveal the vote for a proposition
    function reveal_sealed_vote(uint256 _prop_id, string memory _salt) public {
        Proposition storage prop = propositions[_prop_id];
        require(prop.status == PropositionStatus.VotingClose, "Proposition is not in the reveal phase!");
        bytes32 hashedVote = prop.voters_sealedVotes[msg.sender];
        if(hashedVote == keccak256(abi.encodePacked(_prop_id, true, _salt))){
            // Vote was true
            prop.voters_unsealedVotes[msg.sender] = VoteOption.True;
            prop.T_voters.push(msg.sender);
            prop.votes[VoteOption.True] += normalize_voter_vote_weight(msg.sender, _prop_id);
        }else if(hashedVote == keccak256(abi.encodePacked(_prop_id, false, _salt))){
            // Vote was false
            prop.voters_unsealedVotes[msg.sender] = VoteOption.False;
            prop.F_voters.push(msg.sender);
            prop.votes[VoteOption.False] += normalize_voter_vote_weight(msg.sender, _prop_id);
        }else{
            revert("Wrong salt!!!");
        }

        if(prop.F_voters.length + prop.T_voters.length == prop.voters_list.length){
            elaborate_result_proposition(_prop_id);
        }
    }
 
    // ### INTERNAL FUNCTIONS 

    function elaborate_result_proposition(uint256 _prop_id) internal {
        stop_revealing_proposition(_prop_id);
        set_decision(_prop_id);
        create_scoreboard(_prop_id);
        distribute_rewards(_prop_id); 
        distribute_reputation(_prop_id);
    }

    // Change status of proposition Open > VotingClosed
    function close_proposition(uint256 _prop_id) internal {
        Proposition storage prop = propositions[_prop_id];
        require(prop.status == PropositionStatus.Open);
        prop.status = PropositionStatus.VotingClose;

        for(uint256 i = 0; i < proposition_list.length; i++){
            if(proposition_list[i] == _prop_id){
                old_proposition_list.push(proposition_list[i]);
                proposition_list[i] = proposition_list[proposition_list.length - 1];
                proposition_list.pop();
            }
        }
    }

    // Change status of proposition VotingClosed > RevealingClosed
    function stop_revealing_proposition(uint256 _prop_id) internal {
        Proposition storage prop = propositions[_prop_id];
        require(prop.status == PropositionStatus.VotingClose);
        prop.status = PropositionStatus.RevealingClose;
    }

    // Distribute the reputation to all the voters
    function distribute_reputation(uint256 _prop_id) internal {
        Proposition storage prop = propositions[_prop_id];
        require(prop.status == PropositionStatus.RevealingClose);

        for(uint256 i = 0; i < prop.voters_list.length; i++){
            address voter_addr = prop.voters_list[i];
            if(prop.voters_unsealedVotes[voter_addr] == prop.decision){
                increment_reputation(voter_addr);
            }else{
                if(prop.decision != VoteOption.Unknown){
                    decrement_reputation(voter_addr);
                }
            }
        }
        for(uint256 j = 0; j < prop.certifiers_list.length; j++){
            address cert_addr = prop.certifiers_list[j];
            if(prop.certifier_stakes[cert_addr][prop.decision] > 0){
                increment_reputation(cert_addr);
            }else{
                if(prop.decision != VoteOption.Unknown){
                    decrement_reputation(cert_addr);
                }
            }
        }
    }  

    // Distribute the rewards to all the voters and certifiers
    function distribute_rewards(uint256 _prop_id) internal {
        Proposition storage prop = propositions[_prop_id];
        require(prop.status == PropositionStatus.RevealingClose);
        uint256 reward_pool = prop.stakes_total + prop.bounty;

        for(uint256 i = 0; i < prop.certifiers_list.length; i++){
            address addr = prop.certifiers_list[i];
            uint256 cert_reward = get_certifier_reward(addr, _prop_id);
            if(prop.certifier_stakes[addr][prop.decision] > 0){
                balances[addr] += cert_reward;
                prop.certifiers_reward[addr] += cert_reward;
                reward_pool -= cert_reward - uint256(lost_reward_pool/lost_reward_pool_split);
                lost_reward_pool -= uint256(lost_reward_pool/lost_reward_pool_split);
            }
        }
        
        for(uint256 i = 0; i < prop.scoreboard.length; i++){
            address addr = prop.scoreboard[i];
            uint256 voter_reward = get_voter_reward(addr, _prop_id);
            if (reward_pool - voter_reward > 0){
                balances[addr] += voter_reward;
                prop.voters_reward[addr] += voter_reward;
                reward_pool -= voter_reward;
            }
        }

        // redistribute the stake to all voters when the outcome is "Unknown"
        if(prop.decision == VoteOption.Unknown){
            for(uint256 i = 0; i < prop.voters_list.length; i++){
                balances[prop.voters_list[i]] += prop.voters_stakes[prop.voters_list[i]];
            }
        }
        else{
            lost_reward_pool += reward_pool;
        }

        
    } 

    // Set the decision based on the vote majority
    function set_decision(uint256 _prop_id) internal {
        Proposition storage prop = propositions[_prop_id];
        require(prop.status == PropositionStatus.RevealingClose);
        VoteOption voter_result = VoteOption.Unknown;
        VoteOption cert_result = VoteOption.Unknown;
        if(prop.votes[VoteOption.True] > prop.votes[VoteOption.False]) voter_result = VoteOption.True;
        if(prop.votes[VoteOption.False] > prop.votes[VoteOption.True]) voter_result = VoteOption.False;
        if(prop.certificates[VoteOption.True] > prop.certificates[VoteOption.False]) cert_result = VoteOption.True;
        if(prop.certificates[VoteOption.False] > prop.certificates[VoteOption.True]) cert_result = VoteOption.False;

        if(voter_result == cert_result || cert_result == VoteOption.Unknown) prop.decision = voter_result;
    }  

    // Create the scoreboard
    function create_scoreboard(uint256 _prop_id) internal {
        Proposition storage prop = propositions[_prop_id];
        require(prop.status == PropositionStatus.RevealingClose);
        address voter_addr;
        for(uint256 i = 0; i < prop.T_voters.length; i++){
           voter_addr = prop.T_voters[i];
           prop.scoreboard.push(voter_addr);
           prop.scores[voter_addr] = assign_score(_prop_id, voter_addr); 
        }
        for(uint256 j = 0; j < prop.F_voters.length; j++){
           voter_addr = prop.F_voters[j];
           prop.scoreboard.push(voter_addr);
           prop.scores[voter_addr] = assign_score(_prop_id, voter_addr); 
        }

        order_scoreboard(_prop_id);
    } 

    // Order scoreboard to get highest scores first
    function order_scoreboard(uint256 _prop_id) internal{
        Proposition storage prop = propositions[_prop_id];
        require(prop.status == PropositionStatus.RevealingClose);  
        require(prop.decision == VoteOption.True || prop.decision == VoteOption.False || prop.decision == VoteOption.Unknown);
        quickSort(prop.scoreboard, int(0), int(prop.scoreboard.length - 1), _prop_id);
    }   

    // Calculate the minimum stake for a voter
    function get_min_voting_stake(address _voter) internal view returns (uint256) {
        return stake_function(reputations[_voter]);
    }

    // Calculate the maximum stake for a voter
    function get_max_voting_stake() internal view returns (uint256) {
        return stake_function(max_reputation);
    }
    
    // Calculate the minimum stake for a certifier
    function get_min_certifing_stake(address _certifier) internal view returns (uint256) {
        return stake_function(reputations[_certifier] + max_reputation);
    }
    
    // Calculate the maximum stake for a certifier
    function get_max_certifing_stake() internal view returns (uint256) {
        return stake_function(2 * max_reputation * 10);
    }
    
    // Function used to calculate all the stake boundaries
    // It represents a parabola with V=(1,1)
    function stake_function(uint256 _rep) internal pure returns (uint256){
        return 100 * (_rep ** 2 - 2 * (_rep - 1));
    }
    
    // Calculate the vote weight of a voter for a proposition
    function normalize_voter_vote_weight(address _voter, uint256 prop_id) internal view returns(uint256) {
        Proposition storage p = propositions[prop_id];
        uint256 stake = p.voters_stakes[_voter];
        uint256 reputation = reputations[_voter];
        return alfa * sqrt(stake) + (100 - alfa) * (stake + reputation);
    }

    // Calculate the vote weight of a certifier for a proposition
    function normalize_certifier_vote_weight(address _certifier, uint256 prop_id, bool _vote) internal view returns(uint256) {
        Proposition storage p = propositions[prop_id];
        uint256 stake;
        if(_vote){
            stake = p.certifier_stakes[_certifier][VoteOption.True];
        }else{
            stake = p.certifier_stakes[_certifier][VoteOption.False];
        }
    
        uint256 reputation = reputations[_certifier];
        return alfa * sqrt(stake) + (100 - alfa) * (stake + reputation); 
    }

    // Calculate the reward of a voter for a proposition
    function get_voter_reward(address _voter, uint256 prop_id) internal view returns(uint256) {
        Proposition storage p = propositions[prop_id];
        uint256 stake = p.voters_stakes[_voter];
        uint256 reputation = reputations[_voter];
        return beta * (stake ** 2) + (100 - beta) * (stake + reputation);
    }

    // Calculate the reward of a certifier for a proposition
    function get_certifier_reward(address _certifier, uint256 _prop_id) internal view returns(uint256){
        Proposition storage p = propositions[_prop_id];
        uint256 stake = p.certifier_stakes[_certifier][p.decision];
        uint256 reputation = reputations[_certifier];
        return beta * (stake ** 2) + (100 - beta) * (stake + reputation + max_reputation) + uint256(lost_reward_pool/lost_reward_pool_split);
    }
    
    // Return a random propositon for a voter
    function get_proposition() internal view returns(uint256) {
        require(proposition_list.length > 0, "No propositions available");
        return proposition_list[random(proposition_list.length)];
    }
    
    // Generate the scoreboard for a proposition
    function assign_score(uint _prop_id, address _voter) internal view returns(uint){
        Proposition storage prop = propositions[_prop_id];
        require(prop.status == PropositionStatus.RevealingClose, "Proposition status should be RevealingClose!");
        uint pred_score;
        uint info_score;
        uint q = prop.prediction_cert[_voter];
        VoteOption w = VoteOption.Unknown;
        while(w == VoteOption.Unknown)
        {
            w = prop.voters_unsealedVotes[prop.voters_list[random(prop.voters_list.length)]];
        }
        pred_score = w == VoteOption.True ? 200 * q - q ** 2 : 10000 - q ** 2;
        uint pred_mean = prediction_mean(_voter, _prop_id);
        info_score = pred_mean > 0? 10000 - (pred_mean - q) ** 2 : 10000 - q ** 2;
        return pred_score + info_score;
    }

    // Produce the aritmetic mean without the prediction of the voter itself
    function prediction_mean(address _voter, uint256 _prop_id) internal view returns(uint256){
        Proposition storage _prop = propositions[_prop_id];
        uint256 i;
        uint256 tot = 0;
        uint256 num;
        if(_prop.voters_unsealedVotes[_voter] == VoteOption.True){
            num = _prop.T_voters.length;
            for(i = 0; i < num; i++){
                tot += _prop.prediction_cert[_prop.T_voters[i]];
            }
        }else{
            num = _prop.F_voters.length;
            for(i = 0; i < num; i++){
               tot += _prop.prediction_cert[_prop.F_voters[i]];
            }
        }
        tot -= _prop.prediction_cert[_voter];
        require(num != 0 , "Division by zero!");
        return tot/num; 
    }
    
    // Increment the reputation of a voter
    function increment_reputation(address _voter) internal {
        uint256 rep = reputations[_voter];
        if (rep < max_reputation) {
            reputations[_voter] += 1;
        }
    }

    // Decrement the reputation of a voter
    function decrement_reputation(address _voter) internal {
        uint256 rep = reputations[_voter];
        if (rep > 1) {
            reputations[_voter] -= 1;
        }
    }

    // ### UTILITY FUNCTIONS

    // Generate a pseudo-random number from 0 to _max
    function random(uint256 _max) internal view returns (uint8) 
    {
        return uint8(uint256(keccak256(abi.encodePacked(block.difficulty, block.timestamp, block.coinbase))) % _max);
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
    
    // RIP n-rooth :(

    // Quicksorting scoreboard addresses comparing their scores
    function quickSort(address[] memory _arr, int _left, int _right, uint256 _prop_id) internal{
        int i = _left;
        int j = _right;
        if(i==j) return;
        Proposition storage prop = propositions[_prop_id];
        address pivot = _arr[uint256(_left + (_right - _left) / 2)];
        uint256 pivot_score = prop.scores[pivot];
        while (i <= j) {
            while (prop.scores[_arr[uint256(i)]] < pivot_score) i++;
            while (pivot_score < prop.scores[_arr[uint256(j)]]) j--;
            if (i <= j) {
                (_arr[uint256(i)], _arr[uint256(j)]) = (_arr[uint256(j)], _arr[uint256(i)]);
                i++;
                j--;
            }
        }
        if (_left < j)
            quickSort(_arr, _left, j, _prop_id);
        if (i < _right)
            quickSort(_arr, i, _right, _prop_id);
    }

}
