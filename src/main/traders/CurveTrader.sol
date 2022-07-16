// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

import "../interfaces/IDexTrader.sol";
import "../interfaces/curve.finance/IStableSwap.sol";

import "../libraries/TransferHelper.sol";
import "./DexTraderBase.sol";

import "../models/CurveModels.sol";

import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

contract CurveTrader is IDexTrader, DexTraderBase {
	mapping(address => mapping(address => PoolInfo)) pools;

	error PoolInfoMissing();

	modifier checkPoolExist(address _tokenA, address _tokenB) {
		if (pools[_tokenA][_tokenB].pool == address(0))
			revert PoolInfoMissing();
		_;
	}

	function setUp() external initializer {
		__Ownable_init();
	}

	function registerPool(
		address tokenA,
		address tokenB,
		int128 indexA,
		int128 indexB,
		address pool
	)
		external
		checkNonZeroAddress2(tokenA, tokenB)
		checkNonZeroAddress(pool)
		onlyOwner
	{
		pools[tokenA][tokenB] = PoolInfo({
			pool: pool,
			indexA: indexA,
			indexB: indexB
		});
		pools[tokenB][tokenA] = PoolInfo({
			pool: pool,
			indexA: indexB,
			indexB: indexA
		});

		TransferHelper.safeApprove(tokenA, address(pool), type(uint256).max);
		TransferHelper.safeApprove(tokenB, address(pool), type(uint256).max);
	}

	function getPoolInfo(address tokenA, address tokenB)
		public
		view
		returns (PoolInfo memory)
	{
		return pools[tokenA][tokenB];
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
		checkPoolExist(tokenIn, tokenOut)
		returns (uint256 amountOut)
	{
		PoolInfo memory poolInfo = pools[tokenIn][tokenOut];
		IStableSwap pool = IStableSwap(poolInfo.pool);

		TransferHelper.safeTransferFrom(
			tokenIn,
			msg.sender,
			address(this),
			amountIn
		);

		amountOut = pool.exchange(
			poolInfo.indexA,
			poolInfo.indexB,
			amountIn,
			amountOutMin
		);

		TransferHelper.safeTransfer(tokenOut, msg.sender, amountOut);

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
		checkNonZero(amountOut)
		checkNonZeroAddress2(tokenIn, tokenOut)
		checkPoolExist(tokenIn, tokenOut)
		returns (uint256 amountIn)
	{
		PoolInfo memory poolInfo = pools[tokenIn][tokenOut];
		IStableSwap pool = IStableSwap(poolInfo.pool);

		// Expect 1.1 as the maximum rate for stable pairs
		amountIn = _min((amountOut * 110) / 100, amountInMax);

		TransferHelper.safeTransferFrom(
			tokenIn,
			msg.sender,
			address(this),
			amountIn
		);

		uint256 realAmountOut = pool.exchange(
			poolInfo.indexA,
			poolInfo.indexB,
			amountIn,
			amountOut
		);

		if (realAmountOut > amountOut) {
			uint256 spareAmountOut = realAmountOut - amountOut;
			uint256 spareAmountIn = pool.exchange(
				poolInfo.indexB,
				poolInfo.indexA,
				spareAmountOut,
				0
			);
			TransferHelper.safeTransfer(tokenIn, msg.sender, spareAmountIn);
			amountIn = amountIn - spareAmountIn;
		}

		TransferHelper.safeTransfer(tokenOut, msg.sender, amountOut);

		return amountIn;
	}

	function expectInputForExactOutput(
		address tokenIn,
		address tokenOut,
		uint256 amountOut
	) external view returns (uint256 expectedAmountIn) {
		PoolInfo memory poolInfo = pools[tokenIn][tokenOut];
		IStableSwap pool = IStableSwap(poolInfo.pool);

		uint256 poolAmountOut = pool.get_dy(
			poolInfo.indexA,
			poolInfo.indexB,
			amountOut
		);

		expectedAmountIn = (amountOut * amountOut) / poolAmountOut;

		return expectedAmountIn;
	}

	function expectOutputForExactInput(
		address tokenIn,
		address tokenOut,
		uint256 amountIn
	) external view returns (uint256 expectedAmountOut) {
		PoolInfo memory poolInfo = pools[tokenIn][tokenOut];
		IStableSwap pool = IStableSwap(poolInfo.pool);

		expectedAmountOut = pool.get_dy(
			poolInfo.indexA,
			poolInfo.indexB,
			amountIn
		);

		return expectedAmountOut;
	}

	function _min(uint256 a, uint256 b) internal pure returns (uint256) {
		return a < b ? a : b;
	}
}
