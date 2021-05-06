pragma solidity >=0.8.0 <0.9.0;
// SPDX-License-Identifier: UNLICENSED

//import "github.com/provable-things/ethereum-api/blob/master/oraclizeAPI_0.5.sol";

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
    uint reward_pool;
    
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
        address[]certifiers_list;
        
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
    }
    
    constructor(){
        // Initialize the parameters of the oracle
        max_voters = 1;
        min_bounty = 0;
        reward_pool = 0;
        max_reputation = 100;
        alfa = 70; // %
        beta = 30; // %
    }
    
    // Subscribe to the service and put founds in it
    function subscribe() public{
        balances[msg.sender] = msg.sender.balance/1000;
    }

    // ### THE WORKFLOW SHOULD BE:
    // SUBMITTER: subscribe > submit_proposition > [wait for all to vote] > [wait for revealing or eventually result_proposition]
    // VOTER: subscribe > voting_request > vote > [wait for all to vote] > reveal_sealed_vote > [get the rewards when propositon is closed]
    // CERTIFIER: subscribe > certification_request > show_propositions > certify_proposition > [get the rewards when propositon is closed]

    //TODO: Functions to put more money into the balances or retrive it all

    //TODO: All the necessary checks at the beginning of the functions

    //TODO: Functions to retrive the data with python, if necessary (maybe it shouldn't since they are public and free on the chain)
    
    // Submit a new proposition
    function submit_proposition(uint256 _prop_id, bytes32 _prop_content, uint256 _bounty) public {
        require (_bounty > min_bounty, "Bounty is too low, check the minimum bounty");
        require (balances[msg.sender] >= _bounty, "Not enough money to submit");
        num_propositions += 1;
        proposition_list.push(num_propositions);
        Proposition storage p = propositions[num_propositions];
        p.id =_prop_id;
        p.content = _prop_content;
        p.bounty = _bounty;
        p.decision = VoteOption.Unknown;
        p.stakes_total = 0;
        p.num_voters = 0;
        p.status = PropositionStatus.Open;
        p.submitter = msg.sender;
        //TODO: initialize missing variables
    }
    
    // Put your stake to be able to view the propositions as a certifier
    function certification_request(uint _stake) public {
        require (ask_to_certify_stakes[msg.sender] > 0, "Action already performed! Choose a proposition");
        require (balances[msg.sender] >= _stake, "Not enough money to certify");
        require (_stake >= get_min_certifing_stake(msg.sender));
        require (_stake <= get_max_certifing_stake(msg.sender));
        ask_to_certify_stakes[msg.sender] = _stake;
        balances[msg.sender] -= _stake;
    }
    
    // A certifier who staked can see all the propositions
    function show_propositions() public {
        require (ask_to_certify_stakes[msg.sender] > 0, "Not a certifier! Make a request");
        //TODO: return the list of all the propositions
    }
    
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
    }
    
    // Put your stake to receive a random proposition
    function voting_request(uint _stake) public returns (uint256) {
        require (_stake >= get_min_voting_stake(msg.sender), "The stake is not enough for your reputation");
        require (_stake <= get_max_voting_stake(msg.sender), "The stake is not enough for your reputation");
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
        //TODO: calc votes total using the unsealed_votes map normalizing them and populating the prop.votes map with the totals
        //TODO: check the result of the proposition using prop.votes and prop.certificates maps and populate the prop.decision variable
        //TODO: calculate the scoreboard (assign_score function to be used)
        //TODO: distribute the rewards iterating the scoreboard (get_voter_reward and get_certifier_reward to be used)
    }

    // Reveal the vote for a proposition
    function reveal_sealed_vote(uint256 _prop_id, bytes32 _salt) public {
        Proposition storage prop = propositions[_prop_id];
        require(prop.status == PropositionStatus.VotingClose, "Proposition is not in the reveal phase!");
        bytes32 hashedVote = prop.voters_sealedVotes[msg.sender];
        if(hashedVote == keccak256(abi.encodePacked(_prop_id, VoteOption.True, _salt))){
            // Vote was true
            prop.voters_unsealedVotes[msg.sender] = VoteOption.True;
        }else{
            // Vote was false
            prop.voters_unsealedVotes[msg.sender] = VoteOption.True;
        }
        //TODO: create the num_revealed_votes in the proposition structure,
        // if this number is equal to the voters close the revealing phase automatically
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

    // Calculate the minimum stake for a voter
    function get_min_voting_stake(address _voter) internal view returns (uint) {
        return reputations[_voter]*10;
        //TODO something better
    }

    // Calculate the maximum stake for a voter
    function get_max_voting_stake(address _voter) internal view returns (uint) {
        return get_min_voting_stake(_voter) + 100;
        //TODO something better
    }
    
    // Calculate the minimum stake for a certifier
    function get_min_certifing_stake(address _certifier) internal view returns (uint) {
        return reputations[_certifier]*100;
        //TODO something better
    }
    
    // Calculate the maximum stake for a certifier
    function get_max_certifing_stake(address _certifier) internal view returns (uint) {
        return get_min_certifing_stake(_certifier) + 100;
        //TODO something better
    }
    
    // Calculate the vote weight of a voter for a proposition
    function normalize_voter_vote_weight(address _voter, uint256 prop_id) internal view returns(uint) {
        Proposition storage p = propositions[prop_id];
        uint256 stake = p.voters_stakes[_voter];
        uint reputation = reputations[_voter];
        return alfa * sqrt(stake) + (1 - alfa) * (stake + reputation);
        //TODO: Something better
    }

    // Calculate the vote weight of a certifier for a proposition
    function normalize_certifier_vote_weight(address _certifier, uint256 prop_id, bool _vote) internal view returns(uint) {
        Proposition storage p = propositions[prop_id];
        uint256 stake = p.certifier_stakes[_certifier][_vote? VoteOption.True : VoteOption.False];
        uint reputation = reputations[_certifier];
        return alfa * sqrt(stake) + (1 - alfa) * (stake + reputation);
        //TODO: Something better
    }

    // Calculate the reward of a voter for a proposition
    function get_voter_reward(address _voter, uint256 prop_id) internal view returns(uint) {
        Proposition storage p = propositions[prop_id];
        uint predictionCert = p.prediction_cert[_voter];
        uint256 stake = p.voters_stakes[_voter];
        uint reputation = reputations[_voter];
        return beta * (stake * stake) + (1 - beta) * (stake + reputation);
        //TODO: something better since it has to get information from the scoreboard
    }

    // Calculate the reward of a certifier for a proposition
    function get_certifier_reward(address _certifier, uint256 _prop_id, bool _outcome) internal view returns(uint){
        Proposition storage p = propositions[_prop_id];
        uint256 stake = p.certifier_stakes[_certifier][_outcome? VoteOption.True : VoteOption.False];
        uint reputation = reputations[_certifier];
        return beta * (stake * stake) + (1 - beta) * (stake + reputation);
        //TODO: something better since it has to get information from the scoreboard
    }
    
    // Return a random propositon for a voter
    function get_proposition() internal view returns(uint256) {
        require(num_propositions > 0, "No propositions available");
        return proposition_list[random(num_propositions)];
    }
    
    // Generate the scoreboard for a proposition
    // TODO: make it work
    function assign_score(uint _prop_id, address _voter, bool _outcome) internal returns(uint){
        Proposition storage prop = propositions[_prop_id];
        require(prop.status == PropositionStatus.VotingClose);
        uint result;
        uint q = prop.prediction_cert[_voter];
        if(_outcome)
        {
            result = prop.voters_unsealedVotes[_voter]==VoteOption.True ? 2*q-q*q : 1-q*q;
        }
        else
        {
            result = prop.voters_unsealedVotes[_voter]==VoteOption.False ? 2*q-q*q : 1-q*q;
        }
        return result;
    }

    // Generate a pseudo-random number from 0 to _max
    function random(uint _max) internal view returns (uint8) 
    {
        // real solution is to ask Oraclize but it costs $$$
        return uint8(uint256(keccak256(abi.encodePacked(block.difficulty))) % _max);
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

    /*

    // ### CODE TO ASK ORACLIZE FOR A RANDOM NUMBER

    uint256 constant MAX_INT_FROM_BYTE = 256;
    uint256 constant NUM_RANDOM_BYTES_REQUESTED = 7;
    event LogNewProvableQuery(string description);
    event generatedRandomNumber(uint256 randomNumber);
    constructor()
        public
    {
        oraclize_setProof(proofType_Ledger);
        update();
    }
    function __callback(
        bytes32 _queryId,
        string memory _result,
        bytes memory _proof
    )
        public
    {
        require(msg.sender == oraclize_cbAddress());
        if (oraclize_randomDS_proofVerify__returnCode(_queryId, _result, _proof) != 0) {
            //The proof verification has failed! Handle this case
        } else {
            //The proof verifiction has passed!
            uint256 ceiling = (MAX_INT_FROM_BYTE ** NUM_RANDOM_BYTES_REQUESTED) - 1;
            uint256 randomNumber = uint256(keccak256(abi.encodePacked(_result))) % ceiling;
            emit generatedRandomNumber(randomNumber);
        }
    }
    function update()
        payable
        public
    {
        uint256 QUERY_EXECUTION_DELAY = 0; // NOTE: The datasource currently does not support delays > 0!
        uint256 GAS_FOR_CALLBACK = 200000;
        oraclize_newRandomDSQuery(
            QUERY_EXECUTION_DELAY,
            NUM_RANDOM_BYTES_REQUESTED,
            GAS_FOR_CALLBACK
        );
        emit LogNewProvableQuery("Provable query was sent, standing by for the answer...");
    }*/
}
