import NonFungibleToken from {{{ imports.NonFungibleToken }}}
import MetadataViews from {{{ imports.MetadataViews }}}
import FungibleToken from {{{ imports.FungibleToken }}}
import FreshmintMetadataViews from {{{ imports.FreshmintMetadataViews }}}

pub contract {{ contractName }}: NonFungibleToken {

    pub let version: String

    pub event ContractInitialized()
    pub event Withdraw(id: UInt64, from: Address?)
    pub event Deposit(id: UInt64, to: Address?)
    pub event Minted(id: UInt64, editionHash: [UInt8])
    pub event Revealed(id: UInt64, editionID: UInt64, editionSerial: UInt64)
    pub event Burned(id: UInt64)
    pub event EditionCreated(edition: Edition)

    pub let CollectionStoragePath: StoragePath
    pub let CollectionPublicPath: PublicPath
    pub let CollectionPrivatePath: PrivatePath
    pub let AdminStoragePath: StoragePath

    /// The total number of {{ contractName }} NFTs that have been minted.
    ///
    pub var totalSupply: UInt64

    /// The total number of {{ contractName }} editions that have been created.
    ///
    pub var totalEditions: UInt64

    /// A placeholder image used to display NFTs that have not yet been revealed.
    pub let placeholderImage: String

    pub struct Metadata {
    
        {{#each fields}}
        pub let {{ this.name }}: {{ this.asCadenceTypeString }}
        {{/each}}

        init(
            {{#each fields}}
            {{ this.name }}: {{ this.asCadenceTypeString }},
            {{/each}}
        ) {
            {{#each fields}}
            self.{{ this.name }} = {{ this.name }}
            {{/each}}
        }
    }

    pub struct Edition {

        pub let id: UInt64
        pub let size: UInt
        pub let metadata: Metadata

        init(
            id: UInt64,
            size: UInt,
            metadata: Metadata
        ) {
            self.id = id
            self.size = size
            self.metadata = metadata
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

        /// Encode this edition object as a byte array.
        ///
        /// This can be used to hash the edition membership and verify its integrity.
        ///
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

    pub resource NFT: NonFungibleToken.INFT, MetadataViews.Resolver {

        pub let id: UInt64

        /// A hash of the NFT's edition membership.
        ///
        /// The edition hash is known at mint time and 
        /// is generated by hashing the edition ID and
        /// serial number for this NFT.
        ///
        pub let editionHash: [UInt8]

        init(editionHash: [UInt8]) {
            self.id = self.uuid
            self.editionHash = editionHash
        }

        /// Return the edition that this NFT belongs to.
        ///
        /// This function returns nil if the edition membership has
        /// not yet been revealed.
        ///
        pub fun getEdition(): EditionMember? {
            return {{ contractName }}.editionMembers[self.id]
        }

        pub fun getViews(): [Type] {
            if self.getEdition() != nil {
                return [
                    {{#each views}}
                    {{{ this.cadenceTypeString }}}{{#unless @last }},{{/unless}}
                    {{/each}}
                ]
            }

            return [
                {{#each views}}
                {{#unless this.requiresMetadata }}
                {{{ this.cadenceTypeString }}},
                {{/unless}}
                {{/each}}
                Type<MetadataViews.Display>(),
                Type<FreshmintMetadataViews.BlindNFT>()
            ]
        }

        pub fun resolveView(_ view: Type): AnyStruct? {
            {{#if views }}
            if let editionMember = self.getEdition() {
                let edition = editionMember.getData()

                switch view {
                    {{#each views}}
                    {{> viewCase view=this metadata="edition.metadata" }}
                    {{/each}}
                }

                return nil
            }
            {{ else }}
            if self.getEdition() != nil {
                return nil
            }
            {{/if}}

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
                case Type<FreshmintMetadataViews.BlindNFT>():
                    return FreshmintMetadataViews.BlindNFT(metadataHash: self.editionHash)
                {{#each views}}
                {{#unless this.requiresMetadata }}
                {{> viewCase view=this }}
                {{/unless}}
                {{/each}}
            }

            return nil
        }

        {{#each views}}
        {{#if this.cadenceResolverFunction }}
        {{> (lookup . "id") view=this contractName=../contractName }}
        
        {{/if}}
        {{/each}}
        destroy() {
            {{ contractName }}.totalSupply = {{ contractName }}.totalSupply - (1 as UInt64)

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

    pub resource Collection: {{ contractName }}CollectionPublic, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection {
        
        /// A dictionary of all NFTs in this collection indexed by ID.
        ///
        pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}

        init () {
            self.ownedNFTs <- {}
        }

        /// Remove an NFT from the collection and move it to the caller.
        ///
        pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
            let token <- self.ownedNFTs.remove(key: withdrawID) 
                ?? panic("Requested NFT to withdraw does not exist in this collection")

            emit Withdraw(id: token.id, from: self.owner?.address)

            return <- token
        }

        /// Deposit an NFT into this collection.
        ///
        pub fun deposit(token: @NonFungibleToken.NFT) {
            let token <- token as! @{{ contractName }}.NFT

            let id: UInt64 = token.id

            // add the new token to the dictionary which removes the old one
            let oldToken <- self.ownedNFTs[id] <- token

            emit Deposit(id: id, to: self.owner?.address)

            destroy oldToken
        }

        /// Return an array of the NFT IDs in this collection.
        ///
        pub fun getIDs(): [UInt64] {
            return self.ownedNFTs.keys
        }

        /// Return a reference to an NFT in this collection.
        ///
        /// This function panics if the NFT does not exist in this collection.
        ///
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT {
            return (&self.ownedNFTs[id] as &NonFungibleToken.NFT?)!
        }

        /// Return a reference to an NFT in this collection
        /// typed as {{ contractName }}.NFT.
        ///
        /// This function returns nil if the NFT does not exist in this collection.
        ///
        pub fun borrow{{ contractName }}(id: UInt64): &{{ contractName }}.NFT? {
            if self.ownedNFTs[id] != nil {
                let ref = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
                return ref as! &{{ contractName }}.NFT
            }

            return nil
        }

        /// Return a reference to an NFT in this collection
        /// typed as MetadataViews.Resolver.
        ///
        /// This function panics if the NFT does not exist in this collection.
        ///
        pub fun borrowViewResolver(id: UInt64): &AnyResource{MetadataViews.Resolver} {
            let nft = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
            let nftRef = nft as! &{{ contractName }}.NFT
            return nftRef as &AnyResource{MetadataViews.Resolver}
        }

        destroy() {
            destroy self.ownedNFTs
        }
    }

    /// Return a new empty collection.
    ///
    pub fun createEmptyCollection(): @NonFungibleToken.Collection {
        return <- create Collection()
    }

    /// The administrator resource used to create editions,
    /// mint and reveal NFTs.
    ///
    pub resource Admin {

        /// Create a new NFT edition.
        ///
        /// This function does not mint any NFTs. It only creates the
        /// edition data that will later be associated with minted NFTs.
        ///
        pub fun createEdition(
            size: UInt,
            {{#each fields}}
            {{ this.name }}: {{ this.asCadenceTypeString }},
            {{/each}}
        ): UInt64 {
            let metadata = Metadata(
                {{#each fields}}
                {{ this.name }}: {{ this.name }},
                {{/each}}
            )

            let edition = Edition(
                id: {{ contractName }}.totalEditions,
                size: size,
                metadata: metadata
            )

            {{ contractName }}.editions[edition.id] = edition

            emit EditionCreated(edition: edition)

            {{ contractName }}.totalEditions = {{ contractName }}.totalEditions + (1 as UInt64)

            return edition.id
        }

        /// Mint a new NFT.
        ///
        /// To mint a blind edition NFT, specify its edition hash
        /// that can later be used to verify the revealed NFT's 
        /// edition ID and serial number.
        ///
        pub fun mintNFT(editionHash: [UInt8]): @{{ contractName }}.NFT {
            let nft <- create {{ contractName }}.NFT(editionHash: editionHash)

            emit Minted(id: nft.id, editionHash: editionHash)

            {{ contractName }}.totalSupply = {{ contractName }}.totalSupply + (1 as UInt64)

            return <- nft
        }

        /// Reveal a minted NFT.
        ///
        /// To reveal an NFT, publish its edition ID, serial number
        /// and unique salt value.
        ///
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

            emit Revealed(
                id: id,
                editionID: editionID,
                editionSerial: editionSerial
            )
        }
    }

    /// Return a public path that is scoped to this contract.
    ///
    pub fun getPublicPath(suffix: String): PublicPath {
        return PublicPath(identifier: "{{ contractName }}_".concat(suffix))!
    }

    /// Return a private path that is scoped to this contract.
    ///
    pub fun getPrivatePath(suffix: String): PrivatePath {
        return PrivatePath(identifier: "{{ contractName }}_".concat(suffix))!
    }

    /// Return a storage path that is scoped to this contract.
    ///
    pub fun getStoragePath(suffix: String): StoragePath {
        return StoragePath(identifier: "{{ contractName }}_".concat(suffix))!
    }

    priv fun initAdmin(admin: AuthAccount) {
        // Create an empty collection and save it to storage
        let collection <- {{ contractName }}.createEmptyCollection()

        admin.save(<- collection, to: {{ contractName }}.CollectionStoragePath)

        admin.link<&{{ contractName }}.Collection>({{ contractName }}.CollectionPrivatePath, target: {{ contractName }}.CollectionStoragePath)

        admin.link<&{{ contractName }}.Collection{NonFungibleToken.CollectionPublic, {{ contractName }}.{{ contractName }}CollectionPublic, MetadataViews.ResolverCollection}>({{ contractName }}.CollectionPublicPath, target: {{ contractName }}.CollectionStoragePath)
        
        // Create an admin resource and save it to storage
        let adminResource <- create Admin()

        admin.save(<- adminResource, to: self.AdminStoragePath)
    }

    init({{#unless saveAdminResourceToContractAccount }}admin: AuthAccount, {{/unless}}placeholderImage: String) {

        self.version = "{{ freshmintVersion }}"

        self.CollectionPublicPath = {{ contractName }}.getPublicPath(suffix: "Collection")
        self.CollectionStoragePath = {{ contractName }}.getStoragePath(suffix: "Collection")
        self.CollectionPrivatePath = {{ contractName }}.getPrivatePath(suffix: "Collection")

        self.AdminStoragePath = {{ contractName }}.getStoragePath(suffix: "Admin")

        self.placeholderImage = placeholderImage

        self.totalSupply = 0
        self.totalEditions = 0

        self.editions = {}
        self.editionMembers = {}
        
        self.initAdmin(admin: {{#if saveAdminResourceToContractAccount }}self.account{{ else }}admin{{/if}})

        emit ContractInitialized()
    }
}
