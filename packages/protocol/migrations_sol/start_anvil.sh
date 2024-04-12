#!/usr/bin/env bash
set -euo pipefail


if nc -z localhost $ANVIL_PORT; then
  echo "Port already used"
  # TODO aff flag to kill the process using the port
  kill $(lsof -i tcp:$ANVIL_PORT | tail -n 1 | awk '{print $2}')
  echo "Killed previous Anvil"
fi

# --disable-default-create2-deployer --no-rate-limit
anvil --port $ANVIL_PORT --gas-limit 50000000 --steps-tracing --code-size-limit 245760 &
# ANVIL_PID=`lsof -i tcp:8545 | tail -n 1 | awk '{print $2}'`
export ANVIL_PID=$!

echo "Waiting Anvil to launch on $ANVIL_PORT..."


while ! nc -z localhost $ANVIL_PORT; do
  sleep 0.1 # wait for 1/10 of the second before check again
done

# enabled logging
cast rpc anvil_setLoggingEnabled true --rpc-url http://127.0.0.1:$ANVIL_PORT

echo "Anvil launched"
sleep 1

# TODO get this from the json
PROXY_BYTECODE=0x60806040526004361061004a5760003560e01c806303386ba31461015e57806342404e07146101e0578063bb913f4114610211578063d29d44ee14610244578063f7e6af8014610277575b604080517f656970313936372e70726f78792e696d706c656d656e746174696f6e000000008152905190819003601c0190206000190180546001600160a01b0381166100d5576040805162461bcd60e51b8152602060048201526015602482015274139bc8125b5c1b195b595b9d185d1a5bdb881cd95d605a1b604482015290519081900360640190fd5b6100de8161028c565b61012a576040805162461bcd60e51b8152602060048201526018602482015277496e76616c696420636f6e7472616374206164647265737360401b604482015290519081900360640190fd5b60405136810160405236600082376000803683855af43d604051818101604052816000823e82801561015a578282f35b8282fd5b6101de6004803603604081101561017457600080fd5b6001600160a01b03823516919081019060408101602082013564010000000081111561019f57600080fd5b8201836020820111156101b157600080fd5b803590602001918460018302840111640100000000831117156101d357600080fd5b5090925090506102c8565b005b3480156101ec57600080fd5b506101f56103f8565b604080516001600160a01b039092168252519081900360200190f35b34801561021d57600080fd5b506101de6004803603602081101561023457600080fd5b50356001600160a01b0316610432565b34801561025057600080fd5b506101de6004803603602081101561026757600080fd5b50356001600160a01b031661055c565b34801561028357600080fd5b506101f56105cc565b6000813f7fc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a4708181148015906102c057508115155b949350505050565b6102d06105cc565b6001600160a01b0316336001600160a01b03161461032c576040805162461bcd60e51b815260206004820152601460248201527339b2b73232b9103bb0b9903737ba1037bbb732b960611b604482015290519081900360640190fd5b61033583610432565b60006060846001600160a01b031684846040518083838082843760405192019450600093509091505080830381855af49150503d8060008114610394576040519150601f19603f3d011682016040523d82523d6000602084013e610399565b606091505b509092509050816103f1576040805162461bcd60e51b815260206004820152601e60248201527f696e697469616c697a6174696f6e2063616c6c6261636b206661696c65640000604482015290519081900360640190fd5b5050505050565b604080517f656970313936372e70726f78792e696d706c656d656e746174696f6e000000008152905190819003601c019020600019015490565b61043a6105cc565b6001600160a01b0316336001600160a01b031614610496576040805162461bcd60e51b815260206004820152601460248201527339b2b73232b9103bb0b9903737ba1037bbb732b960611b604482015290519081900360640190fd5b604080517f656970313936372e70726f78792e696d706c656d656e746174696f6e000000008152905190819003601c019020600019016104d58261028c565b610521576040805162461bcd60e51b8152602060048201526018602482015277496e76616c696420636f6e7472616374206164647265737360401b604482015290519081900360640190fd5b8181556040516001600160a01b038316907fab64f92ab780ecbf4f3866f57cee465ff36c89450dcce20237ca7a8d81fb7d1390600090a25050565b6105646105cc565b6001600160a01b0316336001600160a01b0316146105c0576040805162461bcd60e51b815260206004820152601460248201527339b2b73232b9103bb0b9903737ba1037bbb732b960611b604482015290519081900360640190fd5b6105c9816105fc565b50565b604080517232b4b8189c9b1b97383937bc3c9730b236b4b760691b81529051908190036013019020600019015490565b6001600160a01b03811661064b576040805162461bcd60e51b815260206004820152601160248201527006f776e65722063616e6e6f74206265203607c1b604482015290519081900360640190fd5b604080517232b4b8189c9b1b97383937bc3c9730b236b4b760691b8152905190819003601301812060001901828155906001600160a01b038316907f50146d0e3c60aa1d17a70635b05494f864e86144a2201275021014fbf08bafe290600090a2505056fea265627a7a72315820be6974f7197174b1a0ffb1cc44bcc6387062be493bd56fe9e2be228cb00fb24464736f6c63430005110032

# cast rpc eth_getStorageAt --rpc-url http://127.0.0.1:8545 0x037A5D00E894d857Dd4eE9500ABa00032B5669BE
# cast rpc anvil_impersonateAccount --rpc-url http://127.0.0.1:8545 0x0000000000000000000000000000000000000000

# Set's the bytecode of a Poxy to the registry address
echo "Setting Registry Proxy"
cast rpc anvil_setCode --rpc-url http://127.0.0.1:$ANVIL_PORT 0x000000000000000000000000000000000000ce10 $PROXY_BYTECODE
# Sets the storage of the registry so that it has an owner we control
REGISTRY_OWNER_ADDRESS="f39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
# pasition is bytes32(uint256(keccak256("eip1967.proxy.admin")) - 1);
echo "Setting Registry owner"
cast rpc anvil_setStorageAt --rpc-url http://127.0.0.1:$ANVIL_PORT 0x000000000000000000000000000000000000ce10 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103 "0x000000000000000000000000$REGISTRY_OWNER_ADDRESS"

# echo "Deploying libraries"

# set cheat codes, likely with another script
# Deploy libraries
# why is this recompiling everything?
