pragma solidity >=0.7.0 <0.9.0;
//import 'openzeppelin-solidity/contracts/math/SafeMath.sol';

/**
 * @title Oracle
 * @dev 
 */
contract Oracle {
//    using SafeMath for uint;
    
    enum VoteOption {Unknown, True, False}
    
    uint max_voters;
    
    uint min_bounty;
    
    uint reward_pool;
    
    uint max_reputation;
    
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
        
        uint256 num_voters;
        
        mapping (address => mapping (bool => uint256)) certifier_stakes;
        
        mapping(address => mapping (VoteOption => uint256)) voters_stakes;
        
    }
    
    mapping (address => uint) balances;
    
    mapping (uint256 => Proposition) propositions;
    
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
        // TODO 
        propositions[_prop_id] = Proposition(_prop_id, _prop_content, _bounty, VoteOption.Unknown, 0);
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
        _vote ? prop.true_pool += stake : prop.false_pool += stake;
    }
    
    function voting_request(uint _stake) public returns (uint256) {
        require (_stake >= get_min_voting_stake(reputations[msg.sender]), "The stake is not enough for your reputation");
        require (balances[msg.sender] >= _stake, "Not enough money to vote");
        uint256 prop_id = get_proposition();
        Proposition storage prop = propositions[prop_id];
        voting_stakes[msg.sender][prop_id] = _stake;
        balances[msg.sender] -= _stake;
        return prop_id;
    }
    
    function vote(uint256 _prop_id, VoteOption _vote) public {
        require (voting_stakes[msg.sender][_prop_id] > 0, "Not a voter of that proposition! Make a request");
        uint stake = voting_stakes[msg.sender][_prop_id];
        uint vote = normalize_vote_weight(stake, reputations[msg.sender]);
        voting_stakes[msg.sender][_prop_id] = 0;
        Proposition storage prop = propositions[_prop_id];
        prop.votes[_vote] += vote;
        prop.vote_stakes_total += stake; //TODO
        if (prop.num_voters >= max_voters){
            close_proposition(_prop_id);
        }
    }
    
    /**
    *Internal Functions*
    **/
    function close_proposition(uint _prop_id) internal {
        
    }
    
    function get_min_voting_stake(uint _rep) internal pure returns (uint) {
        return _rep*10;
        //TODO something better
    }
    
    function get_min_certifing_stake(uint _rep) internal pure returns (uint) {
        return _rep*100;
        //TODO something better
    }
    
    function normalize_vote_weight(uint _stake, uint reputation) internal pure returns(uint) {
        return _stake*reputation/0.8;
        //TODO something better
    }
    
    function get_proposition() internal returns(uint256) {
        require(proposition_list.lenght > 0, "No propositions available");
        return proposition_list[0];
        //TODO make it a real random
    }
    
    function get_certifier_reward(uint256 _prop_id, address _certifier, bool _outcome) internal returns(uint256){
        Proposition storage proposition = propositions[_prop_id];
        uint256 stake = proposition.certifier_stakes[_certifier][_outcome];
        return stake;
    }
}
