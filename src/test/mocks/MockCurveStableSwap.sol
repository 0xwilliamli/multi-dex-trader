// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MockCurveStableSwap {
	uint256 private swapRate = 1; // swapRate = reserve1 / reserve0

	address[] private _coins;

	function coins(uint256 index) external view returns (address) {
		return _coins[index];
	}

	constructor(address[] memory _tokens) {
		_coins = new address[](_tokens.length);
		for (uint256 i; i < _tokens.length; i++) {
			_coins[i] = _tokens[i];
		}
	}

	function get_dy(
		int128 i,
		int128 j,
		uint256 _dx
	) external view returns (uint256) {
		return calcAmountOut(i, j, _dx);
	}

	function exchange(
		int128 i,
		int128 j,
		uint256 _dx,
		uint256 _min_dy
	) external returns (uint256) {
		IERC20 tokenIn = IERC20(_coins[uint128(i)]);
		IERC20 tokenOut = IERC20(_coins[uint128(j)]);

		uint256 dy = calcAmountOut(i, j, _dx);

		require(
			dy >= _min_dy,
			"MockCurveStableSwap: insufficient output amount"
		);

		tokenIn.transferFrom(msg.sender, address(this), _dx);

		tokenOut.transfer(msg.sender, dy);

		return dy;
	}

	function calcAmountOut(
		int128 i,
		int128,
		uint256 amountIn
	) internal view returns (uint256 amountOut) {
		if (i == 0) return calcAmountAtoB(amountIn);
		else return calcAmountBtoA(amountIn);
	}

	function calcAmountBtoA(uint256 amountB)
		internal
		view
		returns (uint256 amountA)
	{
		return amountB / swapRate;
	}

	function calcAmountAtoB(uint256 amountA)
		internal
		view
		returns (uint256 amountB)
	{
		return amountA * swapRate;
	}
}
