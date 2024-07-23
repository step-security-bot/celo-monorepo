// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity >=0.5.13 <0.8.20;

contract Constants {
  uint256 public constant FIXED1 = 1e24;
  uint256 public constant MINUTE = 60;
  uint256 public constant HOUR = 60 * MINUTE;
  uint256 public constant DAY = 24 * HOUR;
  uint256 public constant MONTH = 30 * DAY;
  uint256 constant WEEK = 7 * DAY;
  uint256 public constant YEAR = 365 * DAY;

  // contract names
  string constant ElectionContract = "Election";
  string constant SortedOraclesContract = "SortedOracles";
  string constant StableTokenContract = "StableToken";
  string constant GoldTokenContract = "GoldToken";
  string constant CeloTokenContract = "CeloToken";
  string constant FreezerContract = "Freezer";
  string constant AccountsContract = "Accounts";
  string constant LockedGoldContract = "LockedGold";
  string constant LockedCeloContract = "LockedCelo";
  string constant ValidatorsContract = "Validators";
  string constant GovernanceContract = "Governance";
}
