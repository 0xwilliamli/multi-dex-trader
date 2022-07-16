// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.13;

import "./MockUniswapV3Router.sol";

contract MockUniswapV3Quoter {
	MockUniswapV3Router immutable uniswapV3Router;

	constructor(MockUniswapV3Router _uniswapV3Router) {
		uniswapV3Router = _uniswapV3Router;
	}

	function estimateMinSwapUniswapV3(
		address,
		address,
		uint256 _amount,
		uint24
	) external view returns (uint256) {
		return uniswapV3Router.expectAmountIn(_amount);
	}

	function estimateMaxSwapUniswapV3(
		address,
		address,
		uint256 _amount,
		uint24
	) external view returns (uint256) {
		return uniswapV3Router.expectAmountOut(_amount);
	}
}
