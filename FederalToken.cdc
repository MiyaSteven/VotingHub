// FederalToken.cdc

pub contract FederalToken {

    // Total supply of all tokens in existence.
    pub var totalSupply: UInt64

    // Provider
    pub resource interface Provider {

        // Withdraw from vault
        pub fun withdraw(amount: UInt64): @Vault {
            post {
                // `result` refers to the return value of the function
                result.balance == amount: "Withdrawal amount must be the same as the balance of the withdrawn Vault"
            }
        }
    }

    // Receiver 
	pub resource interface Receiver {
		pub var balance: UInt64

        // Deposit
        pub fun deposit(from: @Vault) {
            pre {
                from.balance > UInt64(0): "Deposit balance must be positive"
            }
        }
    }

    // Vault
    pub resource Vault: Receiver {
        
        pub var balance: UInt64

        init(balance: UInt64) {
            self.balance = balance
        }

        pub fun withdraw(amount: UInt64): @Vault {
            self.balance = self.balance - amount
            return <-create Vault(balance: amount)
        }
        
        pub fun deposit(from: @Vault) {
            self.balance = self.balance + from.balance
            destroy from
        }
    }

    // Create Empty Vault
    pub fun createEmptyVault(): @Vault {
        return <-create Vault(balance: 0)
    }

	//  Minter
    pub resource TokenMinter {

		// Function that mints new tokens and deposits into an account's vault
        pub fun mintTokens(amount: UInt64, recipient: &AnyResource{Receiver}) {
			      FederalToken.totalSupply = FederalToken.totalSupply + UInt64(amount)
            recipient.deposit(from: <-create Vault(balance: amount))
        }
    }

    init() {
        self.totalSupply = 0

        // Create the Vault with the initial balance and put it into storage.
        let oldVault <- self.account.storage[Vault] <- create Vault(balance: 0)
        destroy oldVault

        // Create a TokenMinter resource object and put it into storage.
		let oldMinter <- self.account.storage[TokenMinter] <- create TokenMinter()
        destroy oldMinter
    }
}
