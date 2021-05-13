pragma solidity >=0.8.0 <0.9.0;
// SPDX-License-Identifier: UNLICENSED


/**
 * @title Oracle
 * @dev 
 */
contract Oracle /*is usingOraclize*/ {
    
    // ### PARAMETERS OF THE ORACLE
    
    // Number of votes required to close a proposition
    uint max_voters;
    
    // Minimum value of the bounty
    uint min_bounty;
    
    // Pool of money of Unknown propositions
    uint lost_reward_pool;

    //
    uint lost_reward_pool_split;
    
    // Maximum reputation value for a voter
    uint max_reputation;

    // Parameter for vote weight calculation
    uint128 alfa;

    // Parameter for reward calculation
    uint128 beta;

    // ### GLOBAL VARIABLES
    
    // Number of propositions (used to iterate the list)
    uint num_propositions;

    // List of all the prop_id
    uint256[] proposition_list;

    // Map of all the prop_id > propositions
    mapping (uint256 => Proposition) propositions;

    // Balances of each address
    mapping (address => uint) balances;

    // Reputation of each address
    mapping (address => uint) reputations;

    // Voter > prop_id > stake to check if he staked something so he can see which proposition he was assign to  
    mapping (address => mapping(uint256 => uint256)) ask_to_vote_stakes;
    
    // Certifier > stake to check if he staked something so he can see the proposition list
    mapping (address => uint256) ask_to_certify_stakes;

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
        uint bounty;
        
        // between 0 to 100
        uint prediction;
        
        // Total voting stake
        uint stakes_total;

        // The status of the proposition Open > votingClosed > RevealClosed
        PropositionStatus status;

        // Decided outcome
        VoteOption decision;

        // Total voting value for each option
        mapping (VoteOption => uint) votes;
        
        // Total certifing value for each option
        mapping (VoteOption => uint) certificates;

        // Number of people who certified (used to iterate map)
        uint256 num_certifiers;

        // List of the addresses who certified
        address[] certifiers_list;
        
        // Certifiers vote and stake (no need to divide it in multiple maps like for the voters since the vote is not sealed)
        mapping (address => mapping (VoteOption => uint256)) certifier_stakes;
        
        // Current number of people who voted
        uint256 num_voters;

        // List of the addresses who voted
        address[] voters_list;
        
        // Voters certainty for the outcome
        mapping(address => uint) prediction_cert;
        
        // Voters stake
        mapping(address => uint256) voters_stakes;

        // Voters sealed vote
        mapping(address => bytes32) voters_sealedVotes;

        // Voters unsealed vote
        mapping(address => VoteOption) voters_unsealedVotes;
        
        // Number of scores (to iterate scoreboard)
        uint num_scoreboard;

        // Scoreboard: importance order
        address[] scoreboard;
        
        // Score for each voter
        mapping(address => uint) scores;
        
        // Number of true voters (to iterate following list)
        uint num_T_voters;

        // Voters submitting vote T
        address[] T_voters;

        // Number of false voters (to iterate following list)
        uint num_F_voters;
        
        // Voters submitting vote F
        address[] F_voters;

        // Number of true certifiers (to iterate following list)
        uint num_T_certifiers;
        
        //Certifiers submitting cert T
        address[] T_certifiers;
        
        // Number of false certifiers (to iterate following list)
        uint num_F_certifiers;

        //Certifiers submitting cert F
        address[] F_certifiers;
    }
    
    constructor(){
        // Initialize the parameters of the oracle
        max_voters = 1;
        
        // the max reputation reachable for voters
        max_reputation = 100;
        
        // the minimum bounty is 100 times the max bid of certification (with max_rep = 100 is about 10**16 wei ~ 50$)
        min_bounty = get_max_certifing_stake() * 100;
        
        lost_reward_pool = 0;

        lost_reward_pool_split = 100;
        
        alfa = 70; // %
        
        beta = 30; // %

    }
    
    // Subscribe to the service and put founds in it
    function subscribe() public{
        balances[msg.sender] = msg.sender.balance/(10 ** 6);
    }

    // ### THE WORKFLOW SHOULD BE:
    // SUBMITTER: subscribe > submit_proposition > [wait for all to vote] > [wait for revealing or eventually result_proposition]
    // VOTER: subscribe > voting_request > vote > [wait for all to vote] > reveal_sealed_vote > [get the rewards when propositon is closed]
    // CERTIFIER: subscribe > certification_request > show_propositions > certify_proposition > [get the rewards when propositon is closed]

    //TODO: All the necessary checks at the beginning of the functions

    //TODO: Functions to retrive the data with python, if necessary (maybe it shouldn't since they are public and free on the chain)
    
    // Submit a new proposition
    function submit_proposition(uint256 _prop_id, bytes32 _prop_content, uint256 _bounty, uint128 _prediction) public {
        require (_bounty > min_bounty, "Bounty is too low, check the minimum bounty");
        require (balances[msg.sender] >= _bounty, "Not enough money to submit");
        num_propositions += 1;
        proposition_list.push(num_propositions);
        Proposition storage p = propositions[num_propositions];
        p.id =_prop_id;
        p.submitter = msg.sender;
        p.content = _prop_content;
        p.bounty = _bounty;
        p.prediction = _prediction;
        p.status = PropositionStatus.Open;
        p.decision = VoteOption.Unknown;
    }
    
    // Put your stake to be able to view the propositions as a certifier
    function certification_request(uint _stake) public {
        require (ask_to_certify_stakes[msg.sender] > 0, "Action already performed! Choose a proposition");
        require (balances[msg.sender] >= _stake, "Not enough money to certify");
        require (_stake >= get_min_certifing_stake(msg.sender), "The stake is not enough for your reputation");
        require (_stake <= get_max_certifing_stake(), "The stake is too high");
        ask_to_certify_stakes[msg.sender] = _stake;
        balances[msg.sender] -= _stake;
    }
    
    // A certifier who staked can see all the propositions
    /*function show_propositions() public returns (){
        require (ask_to_certify_stakes[msg.sender] > 0, "Not a certifier! Make a request");
    }*/
    
    // A certifier send his vote for a proposition
    function certify_proposition(uint256 _prop_id, bool _vote) public {
        require (ask_to_certify_stakes[msg.sender] > 0, "Not a certifier! Make a request");
        // Get the chosen proposition
        Proposition storage prop = propositions[_prop_id];
        // Increment the vote and move the stake to the proposition chosen
        prop.num_certifiers++;
        prop.certifiers_list.push(msg.sender);
        uint256 stake = ask_to_certify_stakes[msg.sender];
        ask_to_certify_stakes[msg.sender] = 0;
        prop.certifier_stakes[msg.sender][_vote? VoteOption.True : VoteOption.False] += stake;
        prop.stakes_total += stake;
        prop.certificates[_vote? VoteOption.True : VoteOption.False] += normalize_certifier_vote_weight(msg.sender, _prop_id, _vote);
        if(_vote){
            prop.T_certifiers.push(msg.sender);
            prop.num_T_certifiers++;
        }else{
            prop.F_certifiers.push(msg.sender);
            prop.num_F_certifiers++;
        }
    }
    
    // Put your stake to receive a random proposition
    function voting_request(uint _stake) public returns (uint256) {
        require (_stake >= get_min_voting_stake(msg.sender), "The stake is not enough for your reputation");
        require (_stake <= get_max_voting_stake(), "The stake is too high");
        require (balances[msg.sender] >= _stake, "Not enough money to vote");
        uint256 prop_id = get_proposition();
        ask_to_vote_stakes[msg.sender][prop_id] = _stake;
        balances[msg.sender] -= _stake;
        return prop_id;
    }
    
    // Vote for the proposition you received
    function vote(uint256 _prop_id, bytes32 _hashedVote, uint _predictionPercent) public {
        require (ask_to_vote_stakes[msg.sender][_prop_id] > 0, "Not a voter of that proposition! Make a request");
        // Get the propositon
        Proposition storage prop = propositions[_prop_id];
        require(prop.status == PropositionStatus.Open, "Voting phase is closed!");
        // Move the stake to the proposition and vote
        uint256 stake = ask_to_vote_stakes[msg.sender][_prop_id];
        ask_to_vote_stakes[msg.sender][_prop_id] = 0;
        prop.num_voters++;
        prop.voters_list.push(msg.sender);
        prop.voters_sealedVotes[msg.sender] = _hashedVote;
        prop.voters_unsealedVotes[msg.sender] = VoteOption.Unknown;
        prop.voters_stakes[msg.sender] = stake;
        prop.stakes_total += stake;
        prop.prediction_cert[msg.sender] = _predictionPercent;
        // If the max_voters number is reached the voting phase is closed
        if (prop.num_voters >= max_voters){
            close_proposition(_prop_id);
        }
    }

    // The submitter can stop the revealing and resolve the proposition
    function result_proposition(uint256 _prop_id) public {
        Proposition storage prop = propositions[_prop_id];
        require(prop.status == PropositionStatus.VotingClose, "Proposition is not in the reveal phase!");
        require(prop.submitter == msg.sender, "This is not your proposition, you can't close it");
        stop_revealing_proposition(_prop_id);
        set_decision(_prop_id);
        create_scoreboard(_prop_id);
        distribute_rewards(_prop_id);
        distribute_reputation(_prop_id);
    }

    // Reveal the vote for a proposition
    function reveal_sealed_vote(uint256 _prop_id, bytes32 _salt) public {
        Proposition storage prop = propositions[_prop_id];
        require(prop.status == PropositionStatus.VotingClose, "Proposition is not in the reveal phase!");
        bytes32 hashedVote = prop.voters_sealedVotes[msg.sender];
        if(hashedVote == keccak256(abi.encodePacked(_prop_id, VoteOption.True, _salt))){
            // Vote was true
            prop.voters_unsealedVotes[msg.sender] = VoteOption.True;
            prop.num_T_voters++;
            prop.T_voters.push(msg.sender);
            prop.votes[VoteOption.True] += normalize_voter_vote_weight(msg.sender, _prop_id);
        }else{
            // Vote was false
            prop.voters_unsealedVotes[msg.sender] = VoteOption.False;
            prop.num_F_voters++;
            prop.F_voters.push(msg.sender);
            prop.votes[VoteOption.False] += normalize_voter_vote_weight(msg.sender, _prop_id);
        }
        if(prop.num_F_voters + prop.num_T_voters == prop.num_voters){
            stop_revealing_proposition(_prop_id);
        }
    }
 
    // ### INTERNAL FUNCTIONS 

    // Change status of proposition Open > VotingClosed
    function close_proposition(uint256 _prop_id) internal {
        Proposition storage prop = propositions[_prop_id];
        require(prop.status == PropositionStatus.Open);
        prop.status = PropositionStatus.VotingClose;
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
        for(uint i = 0; i < prop.num_voters; i++){
            address voter_addr = prop.voters_list[i];
            if(prop.voters_unsealedVotes[voter_addr] == prop.decision){
                increment_reputation(voter_addr);
            }else{
                decrement_reputation(voter_addr);
            }
        }
        for(uint j = 0; j < prop.num_certifiers; j++){
            address cert_addr = prop.certifiers_list[j];
            if(prop.certifier_stakes[cert_addr][prop.decision] > 0){
                increment_reputation(cert_addr);
            }else{
                decrement_reputation(cert_addr);
            }
        }
    }  

    // Distribute the rewards to all the voters and certifiers
    function distribute_rewards(uint256 _prop_id) internal {
        Proposition storage prop = propositions[_prop_id];
        require(prop.status == PropositionStatus.RevealingClose);
        
        uint reward_pool = prop.stakes_total + prop.bounty;

        for(uint i = 0; i < prop.num_certifiers; i++){
            address addr = prop.certifiers_list[i];
            uint cert_reward = get_certifier_reward(addr, _prop_id);

            if(prop.certifier_stakes[addr][prop.decision] > 0){
                balances[addr] += cert_reward;
                reward_pool -= cert_reward - lost_reward_pool/lost_reward_pool_split;
                lost_reward_pool -= lost_reward_pool/lost_reward_pool_split;
            }
        }

        for(uint i = 0; i < prop.num_scoreboard; i++){
            address addr = prop.scoreboard[i];
            uint voter_reward = get_voter_reward(addr, _prop_id);
            if (reward_pool - voter_reward > 0){
                balances[addr] += voter_reward;
                reward_pool -= voter_reward;
            }
        }

        lost_reward_pool += reward_pool;
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
        if(voter_result == cert_result){
            prop.decision = cert_result;
        }else{
            prop.decision = VoteOption.Unknown;
        }
    }  

    // Create the scoreboard
    function create_scoreboard(uint256 _prop_id) internal {
        Proposition storage prop = propositions[_prop_id];
        require(prop.status == PropositionStatus.RevealingClose);  
        require(prop.decision == VoteOption.True || prop.decision == VoteOption.False || prop.decision == VoteOption.Unknown);
        for(uint i = 0; i < prop.num_T_voters; i++){
           address voter_addr = prop.T_voters[i];
           prop.num_scoreboard++;
           prop.scoreboard.push(voter_addr);
           prop.scores[voter_addr] = assign_score(_prop_id, voter_addr);
        }
        for(uint j = 0; j < prop.num_F_voters; j++){
           address voter_addr = prop.F_voters[j];
           prop.num_scoreboard++;
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
    function get_min_voting_stake(address _voter) internal view returns (uint) {
        return stake_function(reputations[_voter]);
    }

    // Calculate the maximum stake for a voter
    function get_max_voting_stake() internal view returns (uint) {
        return stake_function(max_reputation);
    }
    
    // Calculate the minimum stake for a certifier
    function get_min_certifing_stake(address _certifier) internal view returns (uint) {
        return stake_function(reputations[_certifier] + max_reputation);
    }
    
    // Calculate the maximum stake for a certifier
    function get_max_certifing_stake() internal view returns (uint) {
        return stake_function(2 * max_reputation * 10);
    }
    
    // Function used to calculate all the stake boundaries
    // It represents a parabola with V=(1,1)
    function stake_function(uint _rep) internal pure returns (uint){
        return 100 * (_rep ** 2 - 2 * (_rep - 1));
    }
    
    // Calculate the vote weight of a voter for a proposition
    function normalize_voter_vote_weight(address _voter, uint256 prop_id) internal view returns(uint) {
        Proposition storage p = propositions[prop_id];
        uint256 stake = p.voters_stakes[_voter];
        uint reputation = reputations[_voter];
        return alfa * sqrt(stake) + (100 - alfa) * (stake + reputation);
    }

    // Calculate the vote weight of a certifier for a proposition
    function normalize_certifier_vote_weight(address _certifier, uint256 prop_id, bool _vote) internal view returns(uint) {
        Proposition storage p = propositions[prop_id];
        uint256 stake = p.certifier_stakes[_certifier][_vote ? VoteOption.True : VoteOption.False];
        uint reputation = reputations[_certifier];
        return alfa * sqrt(stake) + (100 - alfa) * (stake + reputation);
        //TODO: IS IT USEFUL?! 
    }

    // Calculate the reward of a voter for a proposition
    function get_voter_reward(address _voter, uint256 prop_id) internal view returns(uint) {
        Proposition storage p = propositions[prop_id];
        //uint predictionCert = p.prediction_cert[_voter];
        uint256 stake = p.voters_stakes[_voter];
        uint reputation = reputations[_voter];
        return beta * (stake ** 2) + (100 - beta) * (stake + reputation);
    }

    // Calculate the reward of a certifier for a proposition
    function get_certifier_reward(address _certifier, uint256 _prop_id) internal view returns(uint){
        Proposition storage p = propositions[_prop_id];
        uint256 stake = p.certifier_stakes[_certifier][p.decision];
        uint reputation = reputations[_certifier];
        return beta * (stake ** 2) + (100 - beta) * (stake + reputation + max_reputation) + lost_reward_pool/lost_reward_pool_split;
    }
    
    // Return a random propositon for a voter
    function get_proposition() internal view returns(uint256) {
        require(num_propositions > 0, "No propositions available");
        return proposition_list[random(num_propositions)];
    }
    
    // Generate the scoreboard for a proposition
    function assign_score(uint _prop_id, address _voter) internal view returns(uint){
        Proposition storage prop = propositions[_prop_id];
        require(prop.status == PropositionStatus.VotingClose);
        uint pred_score;
        uint info_score;
        uint q = prop.prediction_cert[_voter];
        if(prop.decision == VoteOption.True)
        {
            pred_score = prop.voters_unsealedVotes[_voter]==VoteOption.True ? 200 * q - q ** 2 : 10000 - q ** 2;
        }
        else if(prop.decision == VoteOption.False)
        {
            pred_score = prop.voters_unsealedVotes[_voter]==VoteOption.False ? 200 * q - q ** 2 : 10000 - q ** 2;
        }
        info_score = 10000 - (prediction_mean(_voter, prop) - prop.prediction_cert[_voter]) ** 2;
        return pred_score + info_score;
    }

    // Produce the geometric mean without the predicion of the voter itself
    function prediction_mean(address _voter, Proposition storage _prop) internal view returns(uint){
        uint8 i;
        uint tot = 1;
        uint num;
        if(_prop.voters_unsealedVotes[_voter] == VoteOption.True){
            //TODO: check vote
            num = _prop.T_voters.length;
            for(i = 0; i < num; i ++){
                tot *= _prop.prediction_cert[_prop.T_voters[i]];
            }
        }else{
            num = _prop.F_voters.length;
            for(i = 0; i < num; i ++){
               tot *= _prop.prediction_cert[_prop.F_voters[i]];
            }
        }
        tot /= _prop.prediction_cert[_voter];
        return nthRoot(tot, num, 0, 1000);
    }
    
    // Increment the reputation of a voter
    function increment_reputation(address _voter) internal {
        uint rep = reputations[_voter];
        if (rep < max_reputation) {
            reputations[_voter] += 1;
        }
    }

    // Decrement the reputation of a voter
    function decrement_reputation(address _voter) internal {
        uint rep = reputations[_voter];
        if (rep > 1) {
            reputations[_voter] -= 1;
        }
    }

    // ### UTILITY FUNCTIONS

    // Generate a pseudo-random number from 0 to _max
    function random(uint _max) internal view returns (uint8) 
    {
        return uint8(uint256(keccak256(abi.encodePacked(block.difficulty, block.timestamp, block.coinbase))) % _max);
    }

    // Get the square root of a number
    function sqrt(uint x) internal pure returns (uint y) {
        uint z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }
    
    // Get the n-root of a number
    function nthRoot(uint _a, uint _n, uint _dp, uint _maxIts) pure public returns(uint) {
        assert (_n > 1);
        // The scale factor is a crude way to turn everything into integer calcs.
        // Actually do (a * (10 ^ ((dp + 1) * n))) ^ (1/n)
        // We calculate to one extra dp and round at the end
        uint one = 10 ** (1 + _dp);
        uint a0 = one ** _n * _a;
        // Initial guess: 1.0
        uint xNew = one;
        uint iter = 0;
        uint x = 0;
        while (xNew != x && iter < _maxIts) {
            x = xNew;
            uint t0 = x ** (_n - 1);
            if (x * t0 > a0) {
                xNew = x - (x - a0 / t0) / _n;
            } else {
                xNew = x + (a0 / t0 - x) / _n;
            }
            ++iter;
        }
        // Round to nearest in the last dp.
        return (xNew + 5) / 10;
    }

    // Quicksorting scoreboard addresses comparing their scores
    function quickSort(address[] memory _arr, int _left, int _right, uint256 _prop_id) internal{
        int i = _left;
        int j = _right;
        if(i==j) return;
        Proposition storage prop = propositions[_prop_id];
        address pivot = _arr[uint(_left + (_right - _left) / 2)];
        uint pivot_score = prop.scores[pivot];
        while (i <= j) {
            while (prop.scores[_arr[uint(i)]] < pivot_score) i++;
            while (pivot_score < prop.scores[_arr[uint(j)]]) j--;
            if (i <= j) {
                (_arr[uint(i)], _arr[uint(j)]) = (_arr[uint(j)], _arr[uint(i)]);
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
