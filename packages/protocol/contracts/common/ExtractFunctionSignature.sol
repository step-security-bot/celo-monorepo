// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity >=0.8.7 <0.8.20;

library ExtractFunctionSignature {
  /**
   * @notice Extracts the first four bytes of a byte array.
   * @param input The byte array.
   * @return The first four bytes of `input`.
   */
  function extractFunctionSignature(bytes memory input) internal pure returns (bytes4) {
    return (bytes4(input[0]) |
      (bytes4(input[1]) >> 8) |
      (bytes4(input[2]) >> 16) |
      (bytes4(input[3]) >> 24));
  }
}
