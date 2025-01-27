import {{ contractName }} from {{{ contractAddress }}}

import NonFungibleToken from {{{ imports.NonFungibleToken }}}
import MetadataViews from {{{ imports.MetadataViews }}}

pub fun getOrCreateCollection(account: AuthAccount, collectionName: String): &{NonFungibleToken.CollectionPublic} {

    let storagePath = {{ contractName }}.getStoragePath(suffix: collectionName)

    if let collectionRef = account.borrow<&{NonFungibleToken.CollectionPublic}>(from: storagePath) {
        return collectionRef
    }

    let collection <- {{ contractName }}.createEmptyCollection()

    let collectionRef = &collection as &{NonFungibleToken.CollectionPublic}

    let publicPath = {{ contractName }}.getPublicPath(suffix: collectionName)
    let privatePath = {{ contractName }}.getPrivatePath(suffix: collectionName)

    account.save(<-collection, to: storagePath)

    account.link<&{{ contractName }}.Collection>(privatePath, target: storagePath)
    account.link<&{{ contractName }}.Collection{NonFungibleToken.CollectionPublic, {{ contractName }}.{{ contractName }}CollectionPublic, MetadataViews.ResolverCollection}>(publicPath, target: storagePath)
    
    return collectionRef
}

transaction(editionID: UInt64, count: Int, collectionName: String?) {
    
    let admin: &{{ contractName }}.Admin
    let collection: &{NonFungibleToken.CollectionPublic}

    prepare(signer: AuthAccount) {
        self.admin = signer.borrow<&{{ contractName }}.Admin>(from: {{ contractName }}.AdminStoragePath)
            ?? panic("Could not borrow a reference to the NFT admin")
        
        self.collection = getOrCreateCollection(
            account: signer,
            collectionName: collectionName ?? "Collection"
        )
    }

    execute {
        var i = 0

        while i < count {
            let token <- self.admin.mintNFT(editionID: editionID)

            self.collection.deposit(token: <- token)

            i = i + 1
        }
    }
}
