# Oracle's Blockchain Research Project

### W.I.P. ORACLE STRUCTURE

```
Oracle interface {

    # proposition structure (id, text, stage, tags, bounty)
    # vote structure (id, address, sealedVote, unsealedVote)
    # other if necessary
    
    # certifiersPool
    # propositionList
    # votesForPropositionMap
    # certificationForPropositionMap
    # poolForPropositionMap
    # playersScoresForTag

    -   submitProposition(senderAddress, propositionID, propositionText, TTL, bounty)

    -   closeProposition(senderAddress, propositionID) ← after this voters have to unseal their votes, then the votes are weighted and we get result, then the rewards and reputation are distributed

    -   getPropositionList()

    -   certifyProposition(certifierAddress, propositionID, sealedVote, stake)

    -   ??se la puntata supera il bounty va tagliata e gli viene restituito il resto??

    -   stakeToVote(voterAddress, stake) ← now this address can vote

    -   getPropositionToVote(voterAddress) ← consume the stake and get proposition

    -   voteProposition(voterAddress, propositionID, sealedVote)

    -   unsealVote(voteId, keyword) ← for this example we can use unsealed votes and assume that the sealing vote procedure will be implemented in the future

    ….all the calculation methods for min and max stakes
        smin-voters dipende da reputation
        smax-voters dipende da bounty
        smin-certificanti = smax-voters + smin-voters
        smax-certificanti =smin-cert + qualcosa che dipende dal certifier pool

    ….all the calculation for distritbuting the rewards
        monetary rewards always >= 0 (superlinear sublinear like BRAINS)
        certifiers always get the reward first (from pool if there is a pool, or they get priority over voters when the stake is divided)

    ….all the calculation for updating reputation
        reputation starts at 1 for each topic and simply get decreased/incremented

}
```
