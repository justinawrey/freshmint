import NonFungibleToken from {{{ imports.NonFungibleToken }}}
import FungibleToken from {{{ imports.FungibleToken }}}
import NFTQueue from {{{ imports.NFTQueue }}}

pub contract NFTClaimSale {

    pub let version: String

    pub event Claimed(nftType: Type, nftID: UInt64)

    pub let SaleCollectionStoragePath: StoragePath
    pub let SaleCollectionPublicPath: PublicPath

    pub resource interface SaleCollectionPublic {
        pub fun getIDs(): [String]
        pub fun borrowSale(id: String): &Sale
    }

    pub resource SaleCollection: SaleCollectionPublic {

        access(self) let sales: @{String: Sale}

        init () {
            self.sales <- {}
        }

        destroy() {
            destroy self.sales
        }

        pub fun insert(_ sale: @Sale) {
            let oldSale <- self.sales[sale.id] <- sale
            destroy oldSale
        }

        pub fun remove(saleID: String): @Sale {
            let sale <- self.sales.remove(key: saleID) ?? panic("sale does not exist")
            return <- sale
        }

        pub fun getIDs(): [String] {
            return self.sales.keys
        }
        
        pub fun borrowSale(id: String): &Sale {
            return (&self.sales[id] as &Sale?)!
        }
    }

    pub resource interface SalePublic {
        pub let id: String
        pub let price: UFix64
        pub let size: Int
        pub fun supply(): Int
        pub fun isActive(): Bool
        pub fun claim(payment: @FungibleToken.Vault): @NonFungibleToken.NFT
    }

    pub resource Sale: SalePublic {

        access(self) let nftType: Type
        access(self) let queue: Capability<&{NFTQueue.Provider}>
        access(self) let paymentReceiver: Capability<&{FungibleToken.Receiver}>

        pub let id: String
        pub let price: UFix64
        pub let size: Int

        init(
            id: String,
            nftType: Type,
            queue: Capability<&{NFTQueue.Provider}>,
            paymentReceiver: Capability<&{FungibleToken.Receiver}>,
            paymentPrice: UFix64
        ) {
            self.id = id
            self.nftType = nftType
            self.queue = queue
            self.paymentReceiver = paymentReceiver
            self.price = paymentPrice
            self.size = queue.borrow()!.length()
        }

        pub fun supply(): Int {
            let queue = self.queue.borrow()!
            return queue.length()
        }

        pub fun isActive(): Bool {
            return self.supply() != 0
        }

        pub fun claim(payment: @FungibleToken.Vault): @NonFungibleToken.NFT {
            pre {
                payment.balance == self.price: "payment vault does not contain requested price"
            }

            let queue = self.queue.borrow()!

            if queue.length() == 0 {
                panic("Sale is sold out")
            }

            let receiver = self.paymentReceiver.borrow()!

            receiver.deposit(from: <- payment)

            let nft <- queue.pop()

            emit Claimed(nftType: self.nftType, nftID: nft.id)

            return <- nft
        }
    }

    pub fun createEmptySaleCollection(): @SaleCollection {
        return <- create SaleCollection()
    }

    pub fun createSale(
        id: String,
        nftType: Type,
        queue: Capability<&{NFTQueue.Provider}>,
        paymentReceiver: Capability<&{FungibleToken.Receiver}>,
        paymentPrice: UFix64
    ): @Sale {
        return <- create Sale(
            id: id,
            nftType: nftType,
            queue: queue,
            paymentReceiver: paymentReceiver,
            paymentPrice: paymentPrice
        )
    }

    init() {
        self.version = "{{ freshmintVersion }}"

        self.SaleCollectionStoragePath = /storage/NFTClaimSale
        self.SaleCollectionPublicPath = /public/NFTClaimSale
    }
}
