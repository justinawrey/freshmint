import NonFungibleToken from {{{ imports.NonFungibleToken }}}

// The NFTQueue contract provides an NFT collection
// that operates as a first-in-first-out (FIFO) queue.
//
// NFTs can be removed from a Queue in the same order in 
// which they are inserted.
//
pub contract NFTQueue {
 
    // Provider is published as a capability and can be used
    // to withdraw (i.e. pop) NFTs from a queue.
    //
    pub resource interface Provider {
        pub fun length(): Int
        pub fun pop(): @NonFungibleToken.NFT
    }

    // Receiver is published as a capability and can be used
    // to deposit (i.e. insert) NFTs into a queue.
    //
    pub resource interface Receiver {
		pub fun push(token: @NonFungibleToken.NFT)
    }
    
    // Queue is a implemented as a wrapper around a 
    // NonFungibleToken.Collection resource.
    //
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

        // Push inserts an NFT at the end of queue.
        //
        pub fun push(token: @NonFungibleToken.NFT) {
            let collection = self.collection.borrow()!

            self.ids.append(token.id)

            collection.deposit(token: <- token)
        }

        // Pop removes an NFT from the start of the queue.
        //
        pub fun pop(): @NonFungibleToken.NFT {
            let collection = self.collection.borrow()!

            // Because the queue is backed by a collection,
            // it is possible to remove an NFT from the collection
            // without also removing it from the ID array.
            //
            // This loop will remove NFT IDs from the ID array
            // until it finds a matching NFT in the collection.
            //
            // The worst-case runtime of this loop is bounded by O(N),
            // where N is the number of IDs in the queue.
            //
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
