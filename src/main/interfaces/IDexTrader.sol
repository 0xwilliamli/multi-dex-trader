// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

interface IDexTrader {
	/// @notice swapExactInputSinglePath swaps a fixed amount of input token for a maximum possible amount of output token
	/// @dev The calling address must approve this contract to spend at least `amountIn` worth of its input token for this function to succeed.
	/// @param amountIn The exact amount of input token that will be swapped for output token.
	/// @param amountOutMin The amount of output token we are willing to receive by spending the specified amount of input token.
	/// @return amountOut The amount of output token received.
	function swapExactInputSinglePath(
		address tokenIn,
		address tokenOut,
		uint256 amountIn,
		uint256 amountOutMin
	) external returns (uint256 amountOut);

	/// @notice swapExactOutputSinglePath swaps a minimum possible amount of input token for a fixed amount of output token.
	/// @dev The calling address must approve this contract to spend its input token for this function to succeed. As the amount of input input token is variable,
	/// the calling address will need to approve for a slightly higher amount, anticipating some variance.
	/// @param amountOut The exact amount of output token to receive from the swap.
	/// @param amountInMax The amount of input token we are willing to spend to receive the specified amount of output token.
	/// @return amountIn The amount of input token actually spent in the swap.
	function swapExactOutputSinglePath(
		address tokenIn,
		address tokenOut,
		uint256 amountOut,
		uint256 amountInMax
	) external returns (uint256 amountIn);

	/// @notice expectInputForExactOutput calculates an expected amount of input token to be spent in order to receive exact output token amount.
	/// @dev It returns a rough expected amount and it can be often not so exact.
	/// @param amountOut The amount of output token we are willing to receive by swap.
	/// @return expectedAmountIn The amount of input token that should be spent in the swap.
	function expectInputForExactOutput(
		address tokenIn,
		address tokenOut,
		uint256 amountOut
	) external view returns (uint256 expectedAmountIn);

	/// @notice expectOutputForExactInput calculates an expected amount of output token to be received when swapping exact input token amount.
	/// @dev It returns a rough expected amount and it can be often not so exact.
	/// @param amountIn The amount of input token we are going to swap.
	/// @return expectedAmountOut The amount of output token to be received by swap.
	function expectOutputForExactInput(
		address tokenIn,
		address tokenOut,
		uint256 amountIn
	) external view returns (uint256 expectedAmountOut);
}
