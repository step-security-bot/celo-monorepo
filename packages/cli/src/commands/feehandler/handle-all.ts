import { BaseCommand } from '../../base'
import { displaySendTx } from '../../utils/cli'
import { Flags } from '../../utils/command'

export default class HandleAll extends BaseCommand {
  static description =
    'Distributes the available tokens for all registered tokens to the beneficiaries.'

  static flags = {
    ...BaseCommand.flags,
    from: Flags.address({ required: true, description: "Initiator's address" }),
  }

  static examples = ['handle-all --from 0x5409ed021d9299bf6814279a6a1411a7e866a631']

  async run() {
    const res = this.parse(HandleAll)
    const from: string = res.flags.from
    this.kit.defaultAccount = from
    const feeHandler = await this.kit.contracts.getFeeHandler()
    await displaySendTx('handleAll', feeHandler.handleAll(), {}, 'TokensDistributed')
  }
}
