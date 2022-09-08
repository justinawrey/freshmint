import NonFungibleToken from {{{ imports.NonFungibleToken }}}
import NFTQueue from {{{ imports.NFTQueue }}}
import {{ contractName }} from {{{ contractAddress }}}

transaction(
    {{#each fields}}
    {{ this.name }}: [{{ this.asCadenceTypeString }}],
    {{/each}}
) {
    
    let admin: &{{ contractName }}.Admin
    let queue: &{NFTQueue.Receiver}

    prepare(signer: AuthAccount) {
        self.admin = signer
            .borrow<&{{ contractName }}.Admin>(from: {{ contractName }}.AdminStoragePath)
            ?? panic("Could not borrow a reference to the NFT admin")
        
        self.queue = signer
            .getCapability({{ contractName }}.QueuePublicPath)!
            .borrow<&{NFTQueue.Receiver}>()
            ?? panic("Could not get receiver reference to the NFT queue")
    }

    execute {
        var i = 0
        
        while i < {{ fields.[0].name }}.length {

            let token <- self.admin.mintNFT(
                {{#each fields}}
                {{ this.name }}: {{ this.name }}[i],
                {{/each}}
            )
        
            self.queue.push(token: <- token)

            i = i +1
        }
    }
}
