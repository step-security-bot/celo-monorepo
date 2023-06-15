pragma solidity ^0.5.13;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-solidity/contracts/utils/EnumerableSet.sol";
import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "openzeppelin-solidity/contracts/math/Math.sol";

import "./UsingRegistry.sol";

import "../common/interfaces/IFeeHandlerSeller.sol";
import "../stability/interfaces/ISortedOracles.sol";
import "../common/FixidityLib.sol";
import "../common/Initializable.sol";
import "./FeeHandlerSeller.sol";

import "../uniswap/interfaces/IUniswapV2RouterMin.sol";
import "../uniswap/interfaces/IUniswapV2FactoryMin.sol";

contract UniswapFeeHandlerSeller is IFeeHandlerSeller, FeeHandlerSeller {
  using SafeMath for uint256;
  using FixidityLib for FixidityLib.Fraction;
  using EnumerableSet for EnumerableSet.AddressSet;

  mapping(address => EnumerableSet.AddressSet) private routerAddresses;
  uint256 constant MAX_TIMESTAMP_BLOCK_EXCHANGE = 20;

  event ReceivedQuote(address indexed tokneAddress, address indexed router, uint256 quote);
  event RouterUsed(address router);
  event RouterAddressSet(address token, address router);
  event RouterAddressRemoved(address token, address router);

  /**
   * @notice Sets initialized == true on implementation contracts.
   * @param test Set to true to skip implementation initialisation.
   */
  constructor(bool test) public Initializable(test) {}

  // without this line the contract can't receive native Celo transfers
  function() external payable {}

  /**
   * @notice Returns the storage, major, minor, and patch version of the contract.
   * @return Storage version of the contract.
   * @return Major version of the contract.
   * @return Minor version of the contract.
   * @return Patch version of the contract.
   */
  function getVersionNumber() external pure returns (uint256, uint256, uint256, uint256) {
    return (1, 1, 0, 0);
  }

  /**
    * @notice Allows owner to set the router for a token.
    * @param token Address of the token to set.
    * @param router The new router.
    */
  function setRouter(address token, address router) external onlyOwner {
    _setRouter(token, router);
  }

  function _setRouter(address token, address router) private {
    require(router != address(0), "Router can't be address zero");
    routerAddresses[token].add(router);
    emit RouterAddressSet(token, router);
  }

  /**
    * @notice Allows owner to remove a router for a token.
    * @param token Address of the token.
    * @param router Address of the router to remove.
    */
  function removeRouter(address token, address router) external onlyOwner {
    routerAddresses[token].remove(router);
    emit RouterAddressRemoved(token, router);
  }

  /**
    * @notice Get the list of routers for a token.
    * @param token The address of the token to query.
    * @return An array of all the allowed router.
    */
  function getRoutersForToken(address token) external view returns (address[] memory) {
    return routerAddresses[token].values;
  }

  /**
  * @dev Calculates the minimum amount of tokens that can be received for a given amount of sell tokens, 
          taking into account the slippage and the rates of the sell token and CELO token on the Uniswap V2 pair.
  * @param sellTokenAddress The address of the sell token.
  * @param maxSlippage The maximum slippage allowed.
  * @param amount The amount of sell tokens to be traded.
  * @param bestRouter The Uniswap V2 router with the best price.
  * @return The minimum amount of tokens that can be received.
  */
  function calculateAllMinAmount(
    address sellTokenAddress,
    uint256 maxSlippage,
    uint256 amount,
    IUniswapV2RouterMin bestRouter
  ) private view returns (uint256) {
    ISortedOracles sortedOracles = getSortedOracles();
    uint256 minReports = minimumReports[sellTokenAddress];

    require(
      sortedOracles.numRates(sellTokenAddress) >= minReports,
      "Number of reports for token not enough"
    );

    uint256 minimalSortedOracles = 0;
    // if minimumReports for this token is zero, assume the check is not needed
    if (minReports > 0) {
      (uint256 rateNumerator, uint256 rateDenominator) = sortedOracles.medianRate(sellTokenAddress);

      minimalSortedOracles = calculateMinAmount(
        rateNumerator,
        rateDenominator,
        amount,
        maxSlippage
      );
    }

    IERC20 celoToken = getGoldToken();
    address pair = IUniswapV2FactoryMin(bestRouter.factory()).getPair(
      sellTokenAddress,
      address(celoToken)
    );
    uint256 minAmountPair = calculateMinAmount(
      IERC20(sellTokenAddress).balanceOf(pair),
      celoToken.balanceOf(pair),
      amount,
      maxSlippage
    );

    return Math.max(minAmountPair, minimalSortedOracles);
  }

  // This function explicitly defines few variables because it was getting error "stack too deep"
  function sell(
    address sellTokenAddress,
    address buyTokenAddress,
    uint256 amount,
    uint256 maxSlippage // as fraction,
  ) external {
    require(
      buyTokenAddress == registry.getAddressForOrDie(GOLD_TOKEN_REGISTRY_ID),
      "Buy token can only be gold token"
    );

    require(
      routerAddresses[sellTokenAddress].values.length > 0,
      "routerAddresses should be non empty"
    );

    // An improvement to this function would be to allow the user to pass a path as argument
    // and if it generates a better outcome that the ones enabled that gets used
    // and the user gets a reward

    IERC20 celoToken = getGoldToken();

    IUniswapV2RouterMin bestRouter;
    uint256 bestRouterQuote = 0;

    address[] memory path = new address[](2);

    for (uint256 i = 0; i < routerAddresses[sellTokenAddress].values.length; i++) {
      address poolAddress = routerAddresses[sellTokenAddress].get(i);
      IUniswapV2RouterMin router = IUniswapV2RouterMin(poolAddress);

      path[0] = sellTokenAddress;
      path[1] = address(celoToken);

      // Using the second return value becuase it's the last argument,
      // the previous values show how many tokens are exchanged in each path
      // so the first value would be equivalent to balanceToBurn
      uint256 wouldGet = router.getAmountsOut(amount, path)[1];

      emit ReceivedQuote(sellTokenAddress, poolAddress, wouldGet);
      if (wouldGet > bestRouterQuote) {
        bestRouterQuote = wouldGet;
        bestRouter = router;
      }
    }

    require(bestRouterQuote != 0, "Can't exchange with zero quote");

    uint256 minAmount = 0;
    if (maxSlippage != 0) {
      minAmount = calculateAllMinAmount(sellTokenAddress, maxSlippage, amount, bestRouter);
    }

    IERC20(sellTokenAddress).approve(address(bestRouter), amount);
    bestRouter.swapExactTokensForTokens(
      amount,
      minAmount,
      path,
      address(this),
      block.timestamp + MAX_TIMESTAMP_BLOCK_EXCHANGE
    );

    celoToken.transfer(msg.sender, celoToken.balanceOf(address(this)));
    emit RouterUsed(address(bestRouter));
    emit TokenSold(sellTokenAddress, buyTokenAddress, amount);
  }
}
