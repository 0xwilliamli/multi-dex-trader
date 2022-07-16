// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

import "../interfaces/IDexTrader.sol";
import "../libraries/TransferHelper.sol";
import "./DexTraderBase.sol";

import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract UniswapV2Trader is IDexTrader, DexTraderBase {
	uint256 public maxTxDuration;

	IUniswapV2Router02 public uniswapV2Router;

	function setUp(address _uniswapV2Router)
		external
		initializer
		checkNonZeroAddress(_uniswapV2Router)
	{
		__Ownable_init();

		maxTxDuration = 15;
		uniswapV2Router = IUniswapV2Router02(_uniswapV2Router);
	}

	function setMaxTxDuration(uint256 _maxTxDuration) public onlyOwner {
		maxTxDuration = _maxTxDuration;
	}

	function swapExactInputSinglePath(
		address tokenIn,
		address tokenOut,
		uint256 amountIn,
		uint256 amountOutMin
	)
		external
		override
		checkNonZero(amountIn)
		checkNonZeroAddress2(tokenIn, tokenOut)
		returns (uint256 amountOut)
	{
		TransferHelper.safeTransferFrom(
			tokenIn,
			msg.sender,
			address(this),
			amountIn
		);

		if (
			IERC20(tokenIn).allowance(address(this), address(uniswapV2Router)) <
			amountIn
		) {
			TransferHelper.safeApprove(
				tokenIn,
				address(uniswapV2Router),
				type(uint256).max
			);
		}

		address[] memory path = new address[](2);
		path[0] = tokenIn;
		path[1] = tokenOut;

		uint256[] memory amounts = uniswapV2Router.swapExactTokensForTokens(
			amountIn,
			amountOutMin,
			path,
			msg.sender,
			block.timestamp + maxTxDuration
		);

		amountOut = amounts[amounts.length - 1];

		return amountOut;
	}

	function swapExactOutputSinglePath(
		address tokenIn,
		address tokenOut,
		uint256 amountOut,
		uint256 amountInMax
	)
		external
		override
		checkNonZero2(amountOut, amountInMax)
		checkNonZeroAddress2(tokenIn, tokenOut)
		returns (uint256 amountIn)
	{
		TransferHelper.safeTransferFrom(
			tokenIn,
			msg.sender,
			address(this),
			amountInMax
		);

		if (
			IERC20(tokenIn).allowance(address(this), address(uniswapV2Router)) <
			amountInMax
		) {
			TransferHelper.safeApprove(
				tokenIn,
				address(uniswapV2Router),
				type(uint256).max
			);
		}

		address[] memory path = new address[](2);
		path[0] = tokenIn;
		path[1] = tokenOut;

		uint256[] memory amounts = uniswapV2Router.swapTokensForExactTokens(
			amountOut,
			amountInMax,
			path,
			msg.sender,
			block.timestamp + maxTxDuration
		);

		amountIn = amounts[0];

		if (amountIn < amountInMax) {
			TransferHelper.safeTransfer(
				tokenIn,
				msg.sender,
				amountInMax - amountIn
			);
		}

		return amountIn;
	}

	function expectInputForExactOutput(
		address tokenIn,
		address tokenOut,
		uint256 amountOut
	) external view returns (uint256 expectedAmountIn) {
		address[] memory path = new address[](2);
		path[0] = tokenIn;
		path[1] = tokenOut;

		uint256[] memory amounts = uniswapV2Router.getAmountsIn(
			amountOut,
			path
		);

		expectedAmountIn = amounts[0];

		return expectedAmountIn;
	}

	function expectOutputForExactInput(
		address tokenIn,
		address tokenOut,
		uint256 amountIn
	) external view returns (uint256 expectedAmountOut) {
		address[] memory path = new address[](2);
		path[0] = tokenIn;
		path[1] = tokenOut;

		uint256[] memory amounts = uniswapV2Router.getAmountsOut(
			amountIn,
			path
		);

		expectedAmountOut = amounts[1];

		return expectedAmountOut;
	}
}
