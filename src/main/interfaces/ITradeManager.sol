// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

import "../models/TradeManagerModels.sol";

interface ITradeManager {
	error InsufficientTradeInput();

	error InsufficientTradeOutput();

	error TradePathNotFound(address from, address to);

	error ZeroAmountPassed();

	error ZeroAddressPassed();

	error ZeroPathLength();

	error PathMismatch();

	error InvalidCorrectionRatio();

	function correctionRatioMultiplier() external view returns (uint256);

	function offsetTolerance() external view returns (uint256);

	function getTradeParams(address tokenIn, address tokenOut)
		external
		view
		returns (TradeParams memory);

	function expectInputForExactOutput(
		address _tokenIn,
		address _tokenOut,
		uint256 _amountOut
	) external returns (uint256 expectedInAmount);

	function tradeExactInput(
		address _tokenIn,
		address _tokenOut,
		uint256 _amountIn,
		uint256 _amountOutMin
	) external returns (uint256 amountOut);

	function tradeExactOutput(
		address _tokenIn,
		address _tokenOut,
		uint256 _amountOut,
		uint256 _amountInMax
	) external returns (uint256 amountIn);
}
