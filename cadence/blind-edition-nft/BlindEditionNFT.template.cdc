import NonFungibleToken from {{{ imports.NonFungibleToken }}}
import MetadataViews from {{{ imports.MetadataViews }}}
import FungibleToken from {{{ imports.FungibleToken }}}

pub contract {{ contractName }}: NonFungibleToken {

    pub let version: String

    // Events
    //
    pub event ContractInitialized()
    pub event Withdraw(id: UInt64, from: Address?)
    pub event Deposit(id: UInt64, to: Address?)
    pub event Minted(id: UInt64)
    pub event Revealed(id: UInt64)
    pub event Burned(id: UInt64)
    pub event EditionCreated(edition: Edition)

    // Named Paths
    //
    pub let CollectionStoragePath: StoragePath
    pub let CollectionPublicPath: PublicPath
    pub let CollectionPrivatePath: PrivatePath
    pub let AdminStoragePath: StoragePath

    // totalSupply
    // The total number of {{ contractName }} NFTs that have been minted.
    //
    pub var totalSupply: UInt64

    // totalEditions
    // The total number of {{ contractName }} editions that have been created.
    //
    pub var totalEditions: UInt64

    // A placeholder image used to display NFTs that have not
    // yet been revealed.
    pub let placeholderImage: String

    pub struct Edition {
        pub let id: UInt64
        pub let size: UInt

        {{#each fields}}
        pub let {{ this.name }}: {{ this.asCadenceTypeString }}
        {{/each}}

        init(
            id: UInt64,
            size: UInt,
            {{#each fields}}
            {{ this.name }}: {{ this.asCadenceTypeString }},
            {{/each}}
        ) {
            self.id = id
            self.size = size

            {{#each fields}}
            self.{{ this.name }} = {{ this.name }}
            {{/each}}
        }
    }

    access(self) let editions: {UInt64: Edition}

    pub fun getEdition(id: UInt64): Edition? {
        return {{ contractName }}.editions[id]
    }

    pub struct EditionMember {
        pub let editionID: UInt64
        pub let editionSerial: UInt64
        pub let editionSalt: [UInt8]

        init(
            editionID: UInt64,
            editionSerial: UInt64,
            editionSalt: [UInt8],
        ) {
            self.editionID = editionID
            self.editionSerial = editionSerial
            self.editionSalt = editionSalt
        }

        pub fun getData(): Edition {
            return {{ contractName }}.getEdition(id: self.editionID)!
        }

        // Encode this edition object as a byte array.
        //
        // This can be used to hash the edition membership and verify its integrity.
        pub fun encode(): [UInt8] {
            return self.editionSalt
                .concat(self.editionID.toBigEndianBytes())
                .concat(self.editionSerial.toBigEndianBytes())
        }

        pub fun hash(): [UInt8] {
            return HashAlgorithm.SHA3_256.hash(self.encode())
        }
    }

    access(self) let editionMembers: {UInt64: EditionMember}

    pub fun getEditionMember(id: UInt64): EditionMember? {
        return {{ contractName }}.editionMembers[id]
    }

    pub resource NFT: NonFungibleToken.INFT {

        pub let id: UInt64

        // A hash of the NFT's edition membership.
        //
        // The edition hash is known at mint time and 
        // is generated by hashing the edition ID and
        // serial number for this NFT.
        pub let editionHash: [UInt8]

        init(
            id: UInt64,
            editionHash: [UInt8]
        ) {
            self.id = id
            self.editionHash = editionHash
        }

        // Return the edition that this NFT belongs to.
        //
        // This function returns nil if the edition membership has
        // not yet been revealed.
        pub fun getEdition(): EditionMember? {
            return {{ contractName }}.editionMembers[self.id]
        }

        pub fun getViews(): [Type] {
            {{#if views }}
            return [
                {{#each views}}
                {{{ this.cadenceTypeString }}}{{#unless @last}},{{/unless}}
                {{/each}}
            ]
            {{ else }}
            return []
            {{/if}}
        }

        pub fun resolveView(_ view: Type): AnyStruct? {
            {{#if views }}
            if let edition = self.getEdition() {
                let data = edition.getData()

                switch view {
                    {{#each views}}
                    case {{{ this.cadenceTypeString }}}:
                        {{#with this}}
                        {{> (lookup . "id") view=this metadata="data" }}
                        {{/with}}
                    {{/each}}
                }
            }

            switch view {
                case Type<MetadataViews.Display>():
                    return MetadataViews.Display(
                        name: "{{ contractName }}",
                        description: "This NFT is not yet revealed.",
                        thumbnail: MetadataViews.IPFSFile(
                            cid: {{ contractName }}.placeholderImage, 
                            path: nil
                        )
                    )
            }

            return nil
            {{ else }}
            return nil
            {{/if}}
        }

        destroy() {
            emit Burned(id: self.id)
        }
    }

    pub resource interface {{ contractName }}CollectionPublic {
        pub fun deposit(token: @NonFungibleToken.NFT)
        pub fun getIDs(): [UInt64]
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
        pub fun borrow{{ contractName }}(id: UInt64): &{{ contractName }}.NFT? {
            post {
                (result == nil) || (result?.id == id):
                    "Cannot borrow {{ contractName }} reference: The ID of the returned reference is incorrect"
            }
        }
    }

    pub resource Collection: {{ contractName }}CollectionPublic, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic {
        
        // dictionary of NFTs
        // NFT is a resource type with an `UInt64` ID field
        //
        pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}

        // withdraw
        // Removes an NFT from the collection and moves it to the caller
        //
        pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
            let token <- self.ownedNFTs.remove(key: withdrawID) ?? panic("missing NFT")

            emit Withdraw(id: token.id, from: self.owner?.address)

            return <- token
        }

        // deposit
        // Takes a NFT and adds it to the collections dictionary
        // and adds the ID to the id array
        //
        pub fun deposit(token: @NonFungibleToken.NFT) {
            let token <- token as! @{{ contractName }}.NFT

            let id: UInt64 = token.id

            // add the new token to the dictionary which removes the old one
            let oldToken <- self.ownedNFTs[id] <- token

            emit Deposit(id: id, to: self.owner?.address)

            destroy oldToken
        }

        // getIDs
        // Returns an array of the IDs that are in the collection
        //
        pub fun getIDs(): [UInt64] {
            return self.ownedNFTs.keys
        }

        // borrowNFT
        // Gets a reference to an NFT in the collection
        // so that the caller can read its metadata and call its methods
        //
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT {
            return (&self.ownedNFTs[id] as &NonFungibleToken.NFT?)!
        }

        // borrow{{ contractName }}
        // Gets a reference to an NFT in the collection as a {{ contractName }}.
        //
        pub fun borrow{{ contractName }}(id: UInt64): &{{ contractName }}.NFT? {
            if self.ownedNFTs[id] != nil {
                let ref = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
                return ref as! &{{ contractName }}.NFT
            }

            return nil
        }

        // destructor
        destroy() {
            destroy self.ownedNFTs
        }

        // initializer
        //
        init () {
            self.ownedNFTs <- {}
        }
    }

    // createEmptyCollection
    // public function that anyone can call to create a new empty collection
    //
    pub fun createEmptyCollection(): @NonFungibleToken.Collection {
        return <- create Collection()
    }

    // Admin
    // Resource that an admin can use to mint NFTs.
    //
    pub resource Admin {

        // createEdition
        //
        // Create a new NFT edition.
        //
        // This function does not mint any NFTs. It only creates the
        // edition data that will later be associated with minted NFTs.
        //
        pub fun createEdition(
            size: UInt,
            {{#each fields}}
            {{ this.name }}: {{ this.asCadenceTypeString }},
            {{/each}}
        ): UInt64 {
            let edition = Edition(
                id: {{ contractName }}.totalEditions,
                size: size,
                {{#each fields}}
                {{ this.name }}: {{ this.name }},
                {{/each}}
            )

            {{ contractName }}.editions[edition.id] = edition

            emit EditionCreated(edition: edition)

            {{ contractName }}.totalEditions = {{ contractName }}.totalEditions + (1 as UInt64)

            return edition.id
        }

        // mintNFT
        //
        // Mints a new NFT.
        //
        pub fun mintNFT(editionHash: [UInt8]): @{{ contractName }}.NFT {
            let nft <- create {{ contractName }}.NFT(
                id: {{ contractName }}.totalSupply,
                editionHash: editionHash,
            )

            emit Minted(id: nft.id)

            {{ contractName }}.totalSupply = {{ contractName }}.totalSupply + (1 as UInt64)

            return <- nft
        }

        pub fun revealNFT(
            id: UInt64,
            editionID: UInt64,
            editionSerial: UInt64,
            editionSalt: [UInt8]
        ) {
            pre {
                {{ contractName }}.editionMembers[id] == nil : "NFT has already been revealed"
            }

            let editionMember = EditionMember(
                editionID: editionID,
                editionSerial: editionSerial,
                editionSalt: editionSalt,
            )

            {{ contractName }}.editionMembers[id] = editionMember

            emit Revealed(id: id)
        }
    }

    pub fun getCollectionPublicPath(collectionName: String?): PublicPath {
        if let name = collectionName {
            return PublicPath(identifier: "{{ contractName }}Collection_".concat(name))!
        }

        return /public/{{ contractName }}Collection
    }

    pub fun getCollectionPrivatePath(collectionName: String?): PrivatePath {
        if let name = collectionName {
            return PrivatePath(identifier: "{{ contractName }}Collection_".concat(name))!
        }

        return /private/{{ contractName }}Collection
    }

    pub fun getCollectionStoragePath(collectionName: String?): StoragePath {
        if let name = collectionName {
            return StoragePath(identifier: "{{ contractName }}Collection_".concat(name))!
        }

        return /storage/{{ contractName }}Collection
    }

    priv fun initAdmin(admin: AuthAccount) {
        // Create an empty collection and save it to storage
        let collection <- {{ contractName }}.createEmptyCollection()
        
        admin.save(<- collection, to: {{ contractName }}.CollectionStoragePath)

        admin.link<&{{ contractName }}.Collection>({{ contractName }}.CollectionPrivatePath, target: {{ contractName }}.CollectionStoragePath)
        admin.link<&{{ contractName }}.Collection{NonFungibleToken.CollectionPublic, {{ contractName }}.{{ contractName }}CollectionPublic}>({{ contractName }}.CollectionPublicPath, target: {{ contractName }}.CollectionStoragePath)
        
        // Create an admin resource and save it to storage
        let adminResource <- create Admin()

        admin.save(<- adminResource, to: self.AdminStoragePath)
    }

    init({{#unless saveAdminResourceToContractAccount }}admin: AuthAccount, {{/unless}}placeholderImage: String) {

        self.version = "{{ freshmintVersion }}"

        self.CollectionPublicPath = {{ contractName }}.getCollectionPublicPath(collectionName: nil)
        self.CollectionStoragePath = {{ contractName }}.getCollectionStoragePath(collectionName: nil)
        self.CollectionPrivatePath = {{ contractName }}.getCollectionPrivatePath(collectionName: nil)

        self.AdminStoragePath = /storage/{{ contractName }}Admin

        self.placeholderImage = placeholderImage

        // Initialize the total supply
        self.totalSupply = 0

        // Initialize the total editions
        self.totalEditions = 0

        self.editions = {}
        self.editionMembers = {}
        
        self.initAdmin(admin: {{#if saveAdminResourceToContractAccount }}self.account{{ else }}admin{{/if}})

        emit ContractInitialized()
    }
}