import NonFungibleToken from "../contracts/NonFungibleToken.cdc"
import {{name}} from "../contracts/{{name}}.cdc"

pub struct AccountItem {
  pub let tokenId: UInt64
  pub let metadata: String
  pub let owner: Address

  init(tokenId: UInt64, metadata: String, owner: Address) {
    self.tokenId = tokenId
    self.metadata = metadata
    self.owner = owner
  }
}

pub fun fetch(address: Address, id: UInt64): AccountItem? {
  if let col = getAccount(address).getCapability<&{{name}}.Collection{NonFungibleToken.CollectionPublic, {{name}}.{{name}}CollectionPublic}>({{name}}.CollectionPublicPath).borrow() {
    if let item = col.borrow{{name}}(id: id) {
      return AccountItem(tokenId: id, metadata: item.metadata, owner: address)
    }
  }

  return nil
}

pub fun main(keys: [String], addresses: [Address], ids: [UInt64]): {String: AccountItem?} {
  let r: {String: AccountItem?} = {}
  var i = 0
  while i < keys.length {
    let key = keys[i]
    let address = addresses[i]
    let id = ids[i]
    r[key] = fetch(address: address, id: id)
    i = i + 1
  }
  return r
}
