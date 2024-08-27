// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.13 <0.8.20;

import "celo-foundry-8/Test.sol";

import { Utils08 } from "@test-sol/utils08.sol";
import { TestConstants } from "@test-sol/constants.sol";
import { MigrationsConstants } from "@migrations-sol/constants.sol";

import "@celo-contracts/common/interfaces/IRegistry.sol";
import "@celo-contracts/common/interfaces/IProxy.sol";
import "@celo-contracts/common/interfaces/ICeloToken.sol";
import "@celo-contracts/common/interfaces/IAccounts.sol";
import "@celo-contracts/common/interfaces/IEpochManager.sol";
import "@celo-contracts/common/interfaces/IEpochManagerEnabler.sol";

import "@celo-contracts/governance/interfaces/IValidators.sol";

import "@celo-contracts-8/common/interfaces/IPrecompiles.sol";

contract IntegrationTest is Test, TestConstants, Utils08 {
  IRegistry registry = IRegistry(REGISTRY_ADDRESS);

  uint256 constant RESERVE_BALANCE = 69411663406170917420347916; // current as of 08/20/24

  function setUp() public virtual {}

  /**
   * @notice Removes CBOR encoded metadata from the tail of the deployedBytecode.
   * @param data Bytecode including the CBOR encoded tail.
   * @return Bytecode without the CBOR encoded metadata.
   */
  function removeMetadataFromBytecode(bytes memory data) public pure returns (bytes memory) {
    // Ensure the data length is at least enough to contain the length specifier
    require(data.length >= 2, "Data too short to contain a valid CBOR length specifier");

    // Calculate the length of the CBOR encoded section from the last two bytes
    uint16 cborLength = uint16(uint8(data[data.length - 2])) *
      256 +
      uint16(uint8(data[data.length - 1]));

    // Ensure the length is valid (not greater than the data array length minus 2 bytes for the length field)
    require(cborLength <= data.length - 2, "Invalid CBOR length");

    // Calculate the new length of the data without the CBOR section
    uint newLength = data.length - 2 - cborLength;

    // Create a new byte array for the result
    bytes memory result = new bytes(newLength);

    // Copy data from the original byte array to the new one, excluding the CBOR section and its length field
    for (uint i = 0; i < newLength; i++) {
      result[i] = data[i];
    }

    return result;
  }
}

contract RegistryIntegrationTest is IntegrationTest, MigrationsConstants {
  IProxy proxy;

  function test_shouldHaveAddressInRegistry() public view {
    for (uint256 i = 0; i < contractsInRegistry.length; i++) {
      string memory contractName = contractsInRegistry[i];
      address contractAddress = registry.getAddressFor(keccak256(abi.encodePacked(contractName)));
      console2.log(contractName, "address in Registry is: ", contractAddress);
      assert(contractAddress != address(0));
    }
  }

  function test_shouldHaveCorrectBytecode() public {
    // Converting contract names to hashes for comparison
    bytes32 hashAccount = keccak256(abi.encodePacked("Accounts"));
    bytes32 hashElection = keccak256(abi.encodePacked("Election"));
    bytes32 hashEscrow = keccak256(abi.encodePacked("Escrow"));
    bytes32 hashFederatedAttestations = keccak256(abi.encodePacked("FederatedAttestations"));
    bytes32 hashGovernance = keccak256(abi.encodePacked("Governance"));
    bytes32 hashSortedOracles = keccak256(abi.encodePacked("SortedOracles"));
    bytes32 hashValidators = keccak256(abi.encodePacked("Validators"));
    bytes32 hashCeloToken = keccak256(abi.encodePacked("CeloToken"));
    bytes32 hashLockedCelo = keccak256(abi.encodePacked("LockedCelo"));
    bytes32 hashEpochManager = keccak256(abi.encodePacked("EpochManager"));

    for (uint256 i = 0; i < contractsInRegistry.length; i++) {
      // Read name from list of core contracts
      string memory contractName = contractsInRegistry[i];
      console2.log("Checking bytecode of:", contractName);

      // Skipping test for contracts that depend on linked libraries
      // This is a known limitation in Foundry at the moment:
      // Source: https://github.com/foundry-rs/foundry/issues/6120
      bytes32 hashContractName = keccak256(abi.encodePacked(contractName));
      if (
        hashContractName != hashAccount &&
        hashContractName != hashElection &&
        hashContractName != hashEscrow &&
        hashContractName != hashFederatedAttestations &&
        hashContractName != hashGovernance &&
        hashContractName != hashSortedOracles &&
        hashContractName != hashValidators &&
        hashContractName != hashCeloToken && // TODO: remove once GoldToken contract has been renamed to CeloToken
        hashContractName != hashLockedCelo && // TODO: remove once LockedGold contract has been renamed to LockedCelo
        hashContractName != hashEpochManager
      ) {
        // Get proxy address registered in the Registry
        address proxyAddress = registry.getAddressForStringOrDie(contractName);
        proxy = IProxy(address(uint160(proxyAddress)));

        // Get implementation address
        address implementationAddress = proxy._getImplementation();

        // Get bytecode from deployed contract
        bytes memory actualBytecodeWithMetadataOnDevchain = implementationAddress.code;
        bytes memory actualBytecodeOnDevchain = removeMetadataFromBytecode(
          actualBytecodeWithMetadataOnDevchain
        );

        string memory contractFileName = string(abi.encodePacked(contractName, ".sol"));
        // Get bytecode from build artifacts
        bytes memory expectedBytecodeWithMetadataFromArtifacts = vm.getDeployedCode(
          contractFileName
        );
        bytes memory expectedBytecodeFromArtifacts = removeMetadataFromBytecode(
          expectedBytecodeWithMetadataFromArtifacts
        );

        // Compare the bytecodes
        assertEq(
          actualBytecodeOnDevchain,
          expectedBytecodeFromArtifacts,
          "Bytecode does not match"
        );
      }
    }
  }
}

contract EpochManagerIntegrationTest is IntegrationTest, MigrationsConstants {
  ICeloToken celoToken;
  IAccounts accountsContract;
  IValidators validatorsContract;
  IEpochManager epochManager;
  IEpochManagerEnabler epochManagerEnabler;

  address reserveAddress;
  address unreleasedTreasury;
  address randomAddress;

  uint256 firstEpochNumber = 100;
  uint256 firstEpochBlock = 100;
  address[] firstElected;
  address[] validatorsList;

  function setUp() public override {
    super.setUp();
    randomAddress = actor("randomAddress");

    validatorsContract = IValidators(registry.getAddressForStringOrDie("Validators"));

    validatorsList = validatorsContract.getRegisteredValidators();

    unreleasedTreasury = registry.getAddressForStringOrDie("CeloUnreleasedTreasure");
    reserveAddress = registry.getAddressForStringOrDie("Reserve");

    // mint to the reserve
    celoToken = ICeloToken(registry.getAddressForStringOrDie("GoldToken"));

    vm.deal(address(0), CELO_SUPPLY_CAP);
    vm.prank(address(0));
    celoToken.mint(reserveAddress, RESERVE_BALANCE);

    vm.prank(address(0));
    celoToken.mint(randomAddress, L1_MINTED_CELO_SUPPLY - RESERVE_BALANCE); // mint outstanding l1 supply before L2.

    epochManager = IEpochManager(registry.getAddressForStringOrDie("EpochManager"));
    epochManagerEnabler = IEpochManagerEnabler(
      registry.getAddressForStringOrDie("EpochManagerEnabler")
    );
  }

  function test_IsSetupCorrect() public {
    assertEq(
      registry.getAddressForStringOrDie("EpochManagerEnabler"),
      epochManager.epochManagerEnabler()
    );
    assertEq(
      registry.getAddressForStringOrDie("EpochManagerEnabler"),
      address(epochManagerEnabler)
    );
    assertEq(address(epochManagerEnabler), epochManager.epochManagerEnabler());
  }

  function test_Reverts_whenSystemNotInitialized() public {
    vm.expectRevert("Epoch system not initialized");
    epochManager.startNextEpochProcess();
  }

  function test_Reverts_WhenEndOfEpochHasNotBeenReached() public {
    // fund treasury
    vm.prank(address(0));
    celoToken.mint(unreleasedTreasury, L2_INITIAL_STASH_BALANCE);

    uint256 l1EpochNumber = IPrecompiles(address(validatorsContract)).getEpochNumber();

    vm.prank(address(epochManagerEnabler));
    epochManager.initializeSystem(l1EpochNumber, block.number, validatorsList);

    vm.expectRevert("Epoch is not ready to start");
    epochManager.startNextEpochProcess();
  }

  function test_Reverts_whenAlreadyInitialized() public {
    _MockL2Migration(validatorsList);

    vm.prank(address(0));
    vm.expectRevert("Epoch system already initialized");
    epochManager.initializeSystem(100, block.number, firstElected);
  }

  // XXX(soloseng): fails because EpochManager is not yet permissioned by stableToken to mint
  function test_SetsCurrentRewardBlock() public {
    _MockL2Migration(validatorsList);

    blockTravel(vm, 43200);
    timeTravel(vm, DAY);

    uint256 _currentEpoch = epochManager.getCurrentEpochNumber();

    epochManager.startNextEpochProcess();

    (, , , uint256 _currentRewardsBlock) = epochManager.getCurrentEpoch();

    assertEq(_currentRewardsBlock, block.number - 1);
  }

  function _MockL2Migration(address[] memory _validatorsList) internal {
    for (uint256 i = 0; i < _validatorsList.length; i++) {
      firstElected.push(_validatorsList[i]);
    }

    uint256 l1EpochNumber = IPrecompiles(address(validatorsContract)).getEpochNumber();

    vm.prank(address(0));
    celoToken.mint(unreleasedTreasury, L2_INITIAL_STASH_BALANCE);

    deployCodeTo("Registry.sol", abi.encode(false), PROXY_ADMIN_ADDRESS);

    vm.prank(address(epochManagerEnabler));

    epochManager.initializeSystem(l1EpochNumber, block.number, firstElected);
  }
}
