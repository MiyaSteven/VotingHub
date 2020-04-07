// ProposalLibrary.cdc

pub contract ProposalLibrary {

    // Declare Proposal
    pub resource Proposal {
        pub let id: UInt64

        pub var metadata: {String: String}

        init(initID: UInt64) {
            self.id = initID
            self.metadata = {}
        }
    }

    // Declare ProposalReceiver
    pub resource interface ProposalReceiver {

        pub fun deposit(proposal: @Proposal)

        pub fun getIDs(): [UInt64]

        pub fun idExists(id: UInt64): Bool
    }

    // Declare Ballot
    pub resource Ballot: ProposalReceiver {

        pub var ownedProposals: @{UInt64: Proposal}

        init () {
            self.ownedProposals <- {}
        }

        // Withdraw
        pub fun withdraw(withdrawID: UInt64): @Proposal {
            let proposal <- self.ownedProposals.remove(key: withdrawID) ?? panic("missing Proposal")

            return <-proposal
        }

        // Deposit 
        pub fun deposit(proposal: @Proposal) {
            // add the new token to the dictionary which removes the old one
            let oldProposal <- self.ownedProposals[proposal.id] <- proposal
            destroy oldProposal
        }

        // Check ID
        pub fun idExists(id: UInt64): Bool {
            return self.ownedProposals[id] != nil
        }

        // Gets IDs
        pub fun getIDs(): [UInt64] {
            return self.ownedProposals.keys
        }

        // Destroys Proposal
        destroy() {
            destroy self.ownedProposals
        }
    }

    // Create new Ballot
    pub fun createEmptyBallot(): @Ballot {
        return <- create Ballot()
    }

    // Declare ProposalMinter
    pub resource ProposalMinter {

        // Proposal count by ID
        pub var idCount: UInt64

        init() {
            self.idCount = 1
        }

        // Mint new Proposal function
        pub fun mintProposal(recipient: &AnyResource{ProposalReceiver}) {

            // Create a new Proposal
            var newProposal <- create Proposal(initID: self.idCount)

            // Deposit
            recipient.deposit(proposal: <-newProposal)

            // Change ID
            self.idCount = self.idCount + UInt64(1)
        }
    }

  init() {
      // store an empty Ballot in account storage
      let oldBallot <- self.account.storage[Ballot] <- create Ballot()
      destroy oldBallot

      self.account.published[&AnyResource{ProposalReceiver}] = &self.account.storage[Ballot] as &AnyResource{ProposalReceiver}

      let oldMinter <- self.account.storage[ProposalMinter] <- create ProposalMinter()
        destroy oldMinter
  }
}
