#!/usr/bin/env bash
set -euo pipefail

# Slashing tests

# For testing a particular branch of Geth repo (usually, on Circle CI)
# Usage: ci_test_exit.sh checkout <branch_of_geth_repo_to_test>
# For testing the local Geth dir (usually, for manual testing)
# Usage: ci_test_exit.sh local <location_of_local_geth_dir>

export TS_NODE_FILES=true
if [ "${1}" == "checkout" ]; then
    # Test master by default.
    BRANCH_TO_TEST=${2:-"master"}
    echo "Checking out geth at branch ${BRANCH_TO_TEST}..."
    ./node_modules/.bin/mocha --node-option loader=ts-node/esm src/e2e-tests/slashing_tests.ts --branch ${BRANCH_TO_TEST}
elif [ "${1}" == "local" ]; then
    export GETH_DIR="${2}"
    echo "Testing using local geth dir ${GETH_DIR}..."
    ./node_modules/.bin/mocha --localgeth ${GETH_DIR} --node-option loader=ts-node/esm,experimental-specifier-resolution=node ./src/e2e-tests/slashing_tests.ts
fi
