import { SOLIDITY_08_PACKAGE } from '@celo/protocol/contractPackages'
import { CeloContractName } from '@celo/protocol/lib/registry-utils'
import {
  deploymentForCoreContract,
  getDeployedProxiedContract,
} from '@celo/protocol/lib/web3-utils'
import { RegistryInstance } from 'types'
import { AccountsInstance } from 'types/08'

const initializeArgs = async (): Promise<[string]> => {
  const registry: RegistryInstance = await getDeployedProxiedContract<RegistryInstance>(
    'Registry',
    artifacts
  )
  return [registry.address]
}

module.exports = deploymentForCoreContract<AccountsInstance>(
  web3,
  artifacts,
  CeloContractName.Accounts,
  initializeArgs,
  async (accounts: AccountsInstance) => {
    await accounts.setEip712DomainSeparator()
  },
  SOLIDITY_08_PACKAGE
)
