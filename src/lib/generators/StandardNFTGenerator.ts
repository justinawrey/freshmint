import * as metadata from '../metadata';
import { ContractImports } from '../config';
import TemplateGenerator from './TemplateGenerator';

export class StandardNFTGenerator extends TemplateGenerator {
  static contract({
    imports,
    contractName,
    schema,
    saveAdminResourceToContractAccount,
  }: {
    imports: ContractImports;
    contractName: string;
    schema: metadata.Schema;
    saveAdminResourceToContractAccount?: boolean;
  }): string {
    return this.generate('../../../cadence/standard-nft/StandardNFT.template.cdc', {
      imports,
      contractName,
      fields: schema.getFieldList(),
      views: schema.views,
      saveAdminResourceToContractAccount: saveAdminResourceToContractAccount ?? false,
    });
  }

  static deploy(): string {
    return this.generate('../../../cadence/standard-nft/transactions/deploy.cdc', {});
  }

  static mint({
    imports,
    contractName,
    contractAddress,
    schema,
  }: {
    imports: ContractImports;
    contractName: string;
    contractAddress: string;
    schema: metadata.Schema;
  }): string {
    return this.generate('../../../cadence/standard-nft/transactions/mint.template.cdc', {
      imports,
      contractName,
      contractAddress,
      fields: schema.getFieldList(),
    });
  }

  static mintWithClaimKey({
    imports,
    contractName,
    contractAddress,
    schema,
  }: {
    imports: ContractImports;
    contractName: string;
    contractAddress: string;
    schema: metadata.Schema;
  }): string {
    return this.generate('../../../cadence/standard-nft/transactions/mint_with_claim_key.template.cdc', {
      imports,
      contractName,
      contractAddress,
      fields: schema.getFieldList(),
    });
  }
}
