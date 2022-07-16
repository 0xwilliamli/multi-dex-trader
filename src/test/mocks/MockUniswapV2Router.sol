// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

contract MockUniswapV2Router {
	uint256 private swapRate = 3; // swapRate = reserve1 / reserve0

	modifier checkValidPath(address[] calldata path) {
		require(
			path.length > 1,
			"MockUniswapV2Router: path len must be greater than 1"
		);
		require(
			path[0] != address(0) && path[path.length - 1] != address(0),
			"MockUniswapV2Router: path contains zero address"
		);

		_;
	}

	constructor() {}

	function swapExactTokensForTokens(
		uint256 amountIn,
		uint256 amountOutMin,
		address[] calldata path,
		address to,
		uint256 deadline
	) external checkValidPath(path) returns (uint256[] memory amounts) {
		require(
			deadline >= block.timestamp,
			"MockUniswapV2Router: too late tansaction"
		);

		IERC20 tokenIn = IERC20(path[0]);
		IERC20 tokenOut = IERC20(path[path.length - 1]);

		uint256 amountOut = calcAmountOut(amountIn);

		require(
			amountOut >= amountOutMin,
			"MockUniswapV2Router: insufficient output amount"
		);

		tokenIn.transferFrom(msg.sender, address(this), amountIn);

		tokenOut.transfer(to, amountOut);

		amounts = new uint256[](path.length);
		amounts[0] = amountIn;
		amounts[amounts.length - 1] = amountOut;

		return amounts;
	}

	function swapTokensForExactTokens(
		uint256 amountOut,
		uint256 amountInMax,
		address[] calldata path,
		address to,
		uint256 deadline
	) external returns (uint256[] memory amounts) {
		require(
			deadline >= block.timestamp,
			"MockUniswapV2Router: too late tansaction"
		);

		IERC20 tokenIn = IERC20(path[0]);
		IERC20 tokenOut = IERC20(path[path.length - 1]);

		uint256 amountIn = calcAmountIn(amountOut);

		require(
			amountIn <= amountInMax,
			"MockUniswapV2Router: insufficient input amount"
		);

		tokenIn.transferFrom(msg.sender, address(this), amountIn);

		tokenOut.transfer(to, amountOut);

		amounts = new uint256[](path.length);
		amounts[0] = amountIn;
		amounts[amounts.length - 1] = amountOut;

		return amounts;
	}

	function getAmountsIn(uint256 amountOut, address[] calldata path)
		external
		view
		checkValidPath(path)
		returns (uint256[] memory amounts)
	{
		amounts = new uint256[](path.length);
		amounts[0] = calcAmountIn(amountOut);

		return amounts;
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
