import { SOLIDITY_08_PACKAGE } from '@celo/protocol/contractPackages'
import { CeloContractName } from '@celo/protocol/lib/registry-utils'
import {
  deploymentForCoreContract,
  getDeployedProxiedContract,
} from '@celo/protocol/lib/web3-utils'
import { config } from '@celo/protocol/migrationsConfig'
import { FreezerInstance, GoldTokenInstance, IRegistryInstance } from 'types/08'

const initializeArgs = async () => {
  return [config.registry.predeployedProxyAddress]
}

module.exports = deploymentForCoreContract<GoldTokenInstance>(
  web3,
  artifacts,
  CeloContractName.GoldToken,
  initializeArgs,
  async (goldToken: GoldTokenInstance) => {
    if (config.goldToken.frozen) {
      const freezer: FreezerInstance = await getDeployedProxiedContract<FreezerInstance>(
        'Freezer',
        artifacts
      )
      await freezer.freeze(goldToken.address)
    }
    const registry = await getDeployedProxiedContract<IRegistryInstance>('Registry', artifacts)
    await registry.setAddressFor(CeloContractName.CeloToken, goldToken.address)
  },
  SOLIDITY_08_PACKAGE
)
