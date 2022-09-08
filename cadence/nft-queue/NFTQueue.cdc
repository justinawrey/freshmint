import NonFungibleToken from {{{ imports.NonFungibleToken }}}

pub contract NFTQueue {

    pub resource interface Provider {
        pub fun length(): Int
        pub fun pop(): @NonFungibleToken.NFT
    }

    pub resource interface Receiver {
		pub fun push(token: @NonFungibleToken.NFT)
    }
    
    pub resource Queue: Receiver, Provider {

        access(self) let ids: [UInt64]
        access(self) let collection: Capability<&{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>

        init(
            _ collection: Capability<&{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>
        ) {
            self.ids = []
            self.collection = collection
        }

        pub fun length(): Int {
            return self.ids.length
        }

        pub fun push(token: @NonFungibleToken.NFT) {
            let collection = self.collection.borrow()!

            self.ids.append(token.id)

            collection.deposit(token: <- token)
        }

        pub fun pop(): @NonFungibleToken.NFT {
            let collection = self.collection.borrow()!

            while self.ids.length > 0 {
                let id = self.ids.removeFirst()

                // Note: we use borrowNFT because it is the cheapest
                // way to check if an NFT exists in a collection
                // without triggering a panic.
                if collection.borrowNFT(id: id) != nil {
                    return <- collection.withdraw(withdrawID: id)
                }
            }

            panic("queue is empty")
        }

    }

    pub fun createEmptyQueue(
        _ collection: Capability<&{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>
    ): @Queue {
        return <- create Queue(collection)
    }
}
