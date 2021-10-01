const t = require("@onflow/types");
const fcl = require("@onflow/fcl");
const FlowService = require("./flowService");
const fs = require("fs/promises");
const path = require("path");
const config = require("getconfig");

const nonFungibleTokenPath = '"../contracts/NonFungibleToken.cdc"';

// TODO Get this dynamically from the minty-deployment.json...
const nftContractPath = '"../contracts/CoolCats.cdc"';

class FlowMinter {
  constructor() {
    this.flowService = null;
    this.nonFungibleTokenAddress = null;
    this.nftContractAddress = null;
    this._initialized = false;
  }

  async init() {
    if (this._initialized) {
      return;
    }

    this.flowService = new FlowService(
      config.adminFlowAccount,
      config.adminFlowPrivateKey,
      0 // account index (keyId)
    );
    // The address of the NFT contract interface
    this.nonFungibleTokenAddress = config.nonFungibleTokenAddress;
    // The address of the new custom NFT contract
    this.nftContractAddress = config.adminFlowAccount;
    this._initialized = true;
  }

  setupAccount = async () => {
    const authorization = this.flowService.authorizeMinter();

    let transaction = await fs.readFile(
      path.join(__dirname, `./cadence/transactions/setup_account.cdc`),
      "utf8"
    );

    transaction = transaction
      .replace(
        nonFungibleTokenPath,
        fcl.withPrefix(this.nonFungibleTokenAddress)
      )
      .replace(nftContractPath, fcl.withPrefix(this.nftContractAddress));

    return this.flowService.sendTx({
      transaction,
      args: [],
      authorizations: [authorization],
      payer: authorization,
      proposer: authorization
    });
  };

  mint = async (recipient, metadata) => {
    console.log(metadata);

    const authorization = this.flowService.authorizeMinter();

    let transaction = await fs.readFile(
      path.join(__dirname, `./cadence/transactions/mint.cdc`),
      "utf8"
    );

    transaction = transaction
      .replace(
        nonFungibleTokenPath,
        fcl.withPrefix(this.nonFungibleTokenAddress)
      )
      .replace(nftContractPath, fcl.withPrefix(this.nftContractAddress));

    return this.flowService.sendTx({
      transaction,
      args: [fcl.arg(recipient, t.Address), fcl.arg(metadata, t.String)],
      authorizations: [authorization],
      payer: authorization,
      proposer: authorization
    });
  };

  transfer = async (recipient, itemID) => {
    const authorization = this.flowService.authorizeMinter();

    let transaction = await fs.readFile(
      path.join(__dirname, "./cadence/transactions/transfer.cdc"),
      "utf8"
    );

    transaction = transaction
      .replace(
        nonFungibleTokenPath,
        fcl.withPrefix(this.nonFungibleTokenAddress)
      )
      .replace(nftContractPath, fcl.withPrefix(this.nftContractAddress));

    return this.flowService.sendTx({
      transaction,
      args: [fcl.arg(recipient, t.Address), fcl.arg(itemID, t.UInt64)],
      authorizations: [authorization],
      payer: authorization,
      proposer: authorization
    });
  };
}

module.exports = FlowMinter;