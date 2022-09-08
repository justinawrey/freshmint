import { ContractImports } from '../config';
import TemplateGenerator from './TemplateGenerator';

export class NFTQueueGenerator extends TemplateGenerator {
  static contract({ imports }: { imports: ContractImports }): string {
    return this.generate('../../../cadence/nft-queue/NFTQueue.cdc', {
      imports,
    });
  }
}
