// VotingHub.cdc

import FederalToken from 0x01
import ProposalLibrary from 0x02

pub contract VotingHub {

    // Event when a Proposal is up For Vote
    pub event ForVote(id: UInt64, reward: UInt64)

    // Event for changing the reward for a Proposal
    pub event RewardChanged(id: UInt64, newReward: UInt64)
    
    // Event when Proposal voting ends
    pub event ProposalCompleted(id: UInt64, reward: UInt64)

    // Event for Withdrawing Proposals
    pub event ListingWithdrawn(id: UInt64)

    // Declare Public Proposal Listing
    pub resource interface PublicListing {
        pub fun vote(proposalID: UInt64, recipient: &AnyResource{ProposalLibrary.ProposalReceiver}, mintTokens: @FederalToken.Vault)
        pub fun idReward(proposalID: UInt64): UInt64?
        pub fun getIDs(): [UInt64]
    }

    // Declare Ballot
    pub resource Ballot: PublicListing {

        // Dictionary of the Proposals
        pub var forVoting: @{UInt64: ProposalLibrary.Proposal}

        // Dictionary of the Rewards
        pub var reward: {UInt64: UInt64}

        // Declare the voting transaction
        access(account) let ownerVault: &AnyResource{FederalToken.Receiver}

        init (vault: &AnyResource{FederalToken.Receiver}) {
            self.forVoting <- {}
            self.ownerVault = vault
            self.reward = {}
        }

        // Withdraw Proposal
        pub fun withdraw(proposalID: UInt64): @ProposalLibrary.Proposal {

            // Remove the reward
            self.reward.remove(key: proposalID)

            // Remove and return the Proposal
            let proposal <- self.forVoting.remove(key: proposalID) ?? panic("missing Proposal")
            return <-proposal
        }

        // Declare function to find Proposals to Vote on
        pub fun proposalForVoting(proposal: @ProposalLibrary.Proposal, reward: UInt64) {
            let id = proposal.id

            // Store the reward in the reward array
            self.reward[id] = reward

            // Put the Proposal into the the ForVote dictionary
            let oldProposal <- self.forVoting[id] <- proposal
            destroy oldProposal

            emit ForVote(id: id, reward: reward)
        }

        // Function to change reward
        pub fun changeReward(proposalID: UInt64, newReward: UInt64) {
            self.reward[proposalID] = newReward

            emit RewardChanged(id: proposalID, newReward: newReward)
        }

        // Function to vote for a proposal
        pub fun vote(proposalID: UInt64, recipient: &AnyResource{ProposalLibrary.ProposalReceiver}, mintTokens: @FederalToken.Vault) {
            pre {

                self.forVoting[proposalID] != nil && self.reward[proposalID] != nil:
                    "No token matching this ID for vote!"
                
                mintTokens.balance >= (self.reward[proposalID] ?? UInt64(0)):
                    "No more tokens to vote for this Proposal!"
            }

            // Get the reward out of the Proposal
            if let reward = self.reward[proposalID] {
                self.reward[proposalID] = nil
                
                // Deposit the Federal Tokens into the Proposal
                self.ownerVault.deposit(from: <-mintTokens)

                // Deposit the Proposal into the Ballot
                recipient.deposit(proposal: <-self.withdraw(proposalID: proposalID))

                emit ProposalCompleted(id: proposalID, reward: reward)
            }
        }

        // Function to search by Reward 
        pub fun idReward(proposalID: UInt64): UInt64? {
            return self.reward[proposalID]
        }

        // Function to get Proposal by ID
        pub fun getIDs(): [UInt64] {
            return self.forVoting.keys
        }

        destroy() {
            destroy self.forVoting
        }
    }

    // Create new Ballot
    pub fun createBallot(ownerVault: &AnyResource{FederalToken.Receiver}): @Ballot {
        return <- create Ballot(vault: ownerVault)
    }
}
