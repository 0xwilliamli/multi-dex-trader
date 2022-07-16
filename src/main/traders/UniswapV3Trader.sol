// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

import "../interfaces/IDexTrader.sol";
import "../libraries/TransferHelper.sol";
import "./DexTraderBase.sol";

import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "uniswap-quoter/contracts/interfaces/IQuoter.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract UniswapV3Trader is IDexTrader, DexTraderBase {
	uint24 public poolFee;
	uint256 public maxTxDuration;

	ISwapRouter public uniswapV3Router;
	IQuoter public v3Quoter;

	function setUp(address _uniswapV3Router, address _v3Quoter)
		external
		initializer
		checkNonZeroAddress2(_uniswapV3Router, _v3Quoter)
	{
		__Ownable_init();

		poolFee = 3000; // 0.3%
		maxTxDuration = 15;
		uniswapV3Router = ISwapRouter(_uniswapV3Router);
		v3Quoter = IQuoter(_v3Quoter);
	}

	function setPoolFee(uint24 _poolFee) public onlyOwner {
		poolFee = _poolFee;
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
			IERC20(tokenIn).allowance(address(this), address(uniswapV3Router)) <
			amountIn
		) {
			TransferHelper.safeApprove(
				tokenIn,
				address(uniswapV3Router),
				type(uint256).max
			);
		}

		ISwapRouter.ExactInputSingleParams memory params = ISwapRouter
			.ExactInputSingleParams({
				tokenIn: tokenIn,
				tokenOut: tokenOut,
				fee: poolFee,
				recipient: msg.sender,
				deadline: block.timestamp + maxTxDuration,
				amountIn: amountIn,
				amountOutMinimum: amountOutMin,
				sqrtPriceLimitX96: 0
			});

		amountOut = uniswapV3Router.exactInputSingle(params);

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
			IERC20(tokenIn).allowance(address(this), address(uniswapV3Router)) <
			amountInMax
		) {
			TransferHelper.safeApprove(
				tokenIn,
				address(uniswapV3Router),
				type(uint256).max
			);
		}

		ISwapRouter.ExactOutputSingleParams memory params = ISwapRouter
			.ExactOutputSingleParams({
				tokenIn: tokenIn,
				tokenOut: tokenOut,
				fee: poolFee,
				recipient: msg.sender,
				deadline: block.timestamp + maxTxDuration,
				amountOut: amountOut,
				amountInMaximum: amountInMax,
				sqrtPriceLimitX96: 0
			});

		amountIn = uniswapV3Router.exactOutputSingle(params);

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
		// Using uinswap quoter by Sandrones team
		expectedAmountIn = v3Quoter.estimateMinSwapUniswapV3(
			tokenIn,
			tokenOut,
			amountOut,
			poolFee
		);

		return expectedAmountIn;
	}

	function expectOutputForExactInput(
		address tokenIn,
		address tokenOut,
		uint256 amountIn
	) external view returns (uint256 expectedAmountOut) {
		// Using uinswap quoter by Sandrones team
		expectedAmountOut = v3Quoter.estimateMaxSwapUniswapV3(
			tokenIn,
			tokenOut,
			amountIn,
			poolFee
		);

		return expectedAmountOut;
	}
}
