pragma solidity >=0.8.0 <0.9.0;

//import "github.com/provable-things/ethereum-api/blob/master/oraclizeAPI_0.5.sol";

/**
 * @title Oracle
 * @dev 
 */
contract Oracle /*is usingOraclize*/ {
    
    enum VoteOption {Unknown, True, False}

    enum PropositionStatus {Open, VotingClose, RevealingClose}
    
    uint max_voters;
    
    uint min_bounty;
    
    uint reward_pool;
    
    uint max_reputation;

    uint128 alfa;

    uint128 beta;
    
    struct Proposition {
        // Unique proposition ID
        uint256 id;
        
        // Content of the proposition
        bytes32 content;
        
        // Bounty attached to proposition (max stake is half bounty)
        uint bounty;
        
        // Decided outcome
        VoteOption decision;

        // Total voting value for each option
        mapping (VoteOption => uint) votes;
        
        // Total voting stake
        uint stakes_total;
        
        // Total certifing value for each option
        mapping (bool => uint) certificates;

        PropositionStatus status;
        
        uint256 num_voters;
        
        mapping (address => mapping (bool => uint256)) certifier_stakes;
        
        mapping(address => uint256) voters_stakes;

        mapping(address => bytes32) voters_sealedVotes;
        
        mapping(address => VoteOption) voters_unsealedVotes;
    }
    
    mapping (address => uint) balances;
    
    mapping (uint256 => Proposition) propositions;

    uint numPropositions;
    
    uint256[] proposition_list;
    
    mapping (address => uint) reputations;

    // Stake of a voter for a proposition    
    mapping (address => mapping(uint256 => uint)) voting_stakes;
    
    mapping (address => uint) certifing_stakes;
    
    constructor(){}
    
    function subscribe() public{
        balances[msg.sender] = msg.sender.balance/1000;
    }
    
    function submit_proposition(uint256 _prop_id, bytes32 _prop_content, uint256 _bounty) public {
        require (_bounty > min_bounty, "Bounty is too low, check the minimum bounty");
        require (balances[msg.sender] >= _bounty, "Not enough money to submit");
        Proposition storage p = propositions[numPropositions++];
        p.id =_prop_id;
        p.content = _prop_content;
        p.bounty = _bounty;
        p.decision = VoteOption.Unknown;
        p.stakes_total = 0;
        p.num_voters = 0;
        p.status = PropositionStatus.Open;
    }
    
    function certification_request(uint _stake) public {
        require (certifing_stakes[msg.sender] > 0, "Action already performed! Choose a proposition");
        require (balances[msg.sender] >= _stake, "Not enough money to certify");
        require (_stake >= get_min_certifing_stake(reputations[msg.sender]) );
        certifing_stakes[msg.sender] = _stake;
        balances[msg.sender] -= _stake;
    }
    
    function show_propositions() public {
        require (certifing_stakes[msg.sender] > 0, "Not a certifier! Make a request");
        //TODO
    }
    
    function certify_proposition(uint256 _prop_id, bool _vote) public {
        require (certifing_stakes[msg.sender] > 0, "Not a certifier! Make a request");
        
        // get the chosen proposition
        Proposition storage prop = propositions[_prop_id];
        
        // increment the vote and the relative pool
        uint stake = certifing_stakes[msg.sender];
        certifing_stakes[msg.sender] = 0;
        prop.certificates[_vote] += 1;
        //TODO
        //_vote ? prop.true_pool += stake : prop.false_pool += stake;
    }
    
    function voting_request(uint _stake) public returns (uint256) {
        require (_stake >= get_min_voting_stake(reputations[msg.sender]), "The stake is not enough for your reputation");
        require (balances[msg.sender] >= _stake, "Not enough money to vote");
        uint256 prop_id = get_proposition();
        voting_stakes[msg.sender][prop_id] = _stake;
        balances[msg.sender] -= _stake;
        return prop_id;
    }
    
    function vote(uint256 _prop_id, bytes32 _hashedVote) public {
        require (voting_stakes[msg.sender][_prop_id] > 0, "Not a voter of that proposition! Make a request");
        //uint stake = voting_stakes[msg.sender][_prop_id];
        //uint vote = normalize_vote_weight(stake, reputations[msg.sender]);
        voting_stakes[msg.sender][_prop_id] = 0;
        Proposition storage prop = propositions[_prop_id];
        require(prop.status == PropositionStatus.Open);
        prop.voters_sealedVotes[msg.sender] = _hashedVote;
        prop.voters_unsealedVotes[msg.sender] = VoteOption.Unknown;
        //prop.vote_stakes_total += stake; //TODO
        if (prop.num_voters >= max_voters){
            close_proposition(_prop_id);
        }
    }

    function result_proposition(uint256 _prop_id) public {
        Proposition storage prop = propositions[_prop_id];
        require(prop.status == PropositionStatus.RevealingClose);
        // calcola il totale dei voti
        // controllo risultato
        // dai i premi
    }

    function reveal_sealed_vote(
        uint256 _prop_id,
        bytes32 _salt
    )
        public
    {
        Proposition storage prop = propositions[_prop_id];
        require(prop.status == PropositionStatus.VotingClose);
        bytes32 hashedVote = prop.voters_sealedVotes[msg.sender];
        if(hashedVote == keccak256(abi.encodePacked(_prop_id, VoteOption.True, _salt))){
            // Vote was true
            prop.voters_unsealedVotes[msg.sender] = VoteOption.True;
        }else{
            // Vote was false
            prop.voters_unsealedVotes[msg.sender] = VoteOption.True;
        }
    }


    
    /**
    *Internal Functions*
    **/
    function close_proposition(uint256 _prop_id) internal {
        Proposition storage prop = propositions[_prop_id];
        require(prop.status == PropositionStatus.Open);
        prop.status = PropositionStatus.VotingClose;
    }

    function stop_revealing_proposition(uint256 _prop_id) internal {
        Proposition storage prop = propositions[_prop_id];
        require(prop.status == PropositionStatus.VotingClose);
        prop.status = PropositionStatus.RevealingClose;
    }

    
    function get_min_voting_stake(uint _rep) internal pure returns (uint) {
        return _rep*10;
        //TODO something better
    }
    
    function get_min_certifing_stake(uint _rep) internal pure returns (uint) {
        return _rep*100;
        //TODO something better
    }
    
    function normalize_vote_weight(uint _stake, uint _reputation) internal view returns(uint) {
        return alfa * sqrt(_stake) + (1 - alfa) * (_stake + _reputation);
    }

    function get_voter_reward(uint _stake, uint _reputation) internal view returns(uint) {
        return beta * (_stake * _stake) + (1 - beta) * (_stake + _reputation);
    }
    
    function get_proposition() internal view returns(uint256) {
        require(numPropositions > 0, "No propositions available");
        return proposition_list[0];
        //TODO make it a real random
    }
    
    function get_certifier_reward(uint256 _prop_id, address _certifier, bool _outcome) internal view returns(uint256){
        Proposition storage proposition = propositions[_prop_id];
        uint256 stake = proposition.certifier_stakes[_certifier][_outcome];
        return stake;
    }

    function random() internal pure returns (uint8) 
    {
        // real solution is to ask Oraclize but it costs $$$
        return uint8(uint256(keccak256(abi.encodePacked(block.difficulty)))%251);
    }

    function sqrt(uint x) internal pure returns (uint y) {
        uint z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }

    /*
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
