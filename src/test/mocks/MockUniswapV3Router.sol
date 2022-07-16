// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";

contract MockUniswapV3Router {
	uint256 private swapRate = 3; // swapRate = reserve1 / reserve0

	constructor() {}

	function exactInputSingle(
		ISwapRouter.ExactInputSingleParams calldata params
	) external payable returns (uint256 amountOut) {
		require(
			params.deadline >= block.timestamp,
			"MockUniswapV3Router: too late tansaction"
		);

		IERC20 tokenIn = IERC20(params.tokenIn);
		IERC20 tokenOut = IERC20(params.tokenOut);

		amountOut = calcAmountOut(params.amountIn);

		require(
			amountOut >= params.amountOutMinimum,
			"MockUniswapV3Router: insufficient output amount"
		);

		tokenIn.transferFrom(msg.sender, address(this), params.amountIn);

		tokenOut.transfer(params.recipient, amountOut);

		return amountOut;
	}

	function exactOutputSingle(
		ISwapRouter.ExactOutputSingleParams calldata params
	) external payable returns (uint256 amountIn) {
		require(
			params.deadline >= block.timestamp,
			"MockUniswapV3Router: too late tansaction"
		);

		IERC20 tokenIn = IERC20(params.tokenIn);
		IERC20 tokenOut = IERC20(params.tokenOut);

		amountIn = calcAmountIn(params.amountOut);

		require(
			amountIn <= params.amountInMaximum,
			"MockUniswapV3Router: insufficient input amount"
		);

		tokenIn.transferFrom(msg.sender, address(this), amountIn);

		tokenOut.transfer(params.recipient, params.amountOut);

		return amountIn;
	}

	function expectAmountIn(uint256 amountOut)
		external
		view
		returns (uint256 amountIn)
	{
		return calcAmountIn(amountOut);
	}

	function expectAmountOut(uint256 amountIn)
		external
		view
		returns (uint256 amountOut)
	{
		return calcAmountOut(amountIn);
	}

	function calcAmountIn(uint256 amountOut)
		internal
		view
		returns (uint256 amountIn)
	{
		return amountOut / swapRate;
	}

	function calcAmountOut(uint256 amountIn)
		internal
		view
		returns (uint256 amountOut)
	{
		return amountIn * swapRate;
	}
}
