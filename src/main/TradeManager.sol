// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

import "./interfaces/IDexTrader.sol";
import "./interfaces/ITradeManager.sol";
import "./libraries/TransferHelper.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract TradeManager is ITradeManager, OwnableUpgradeable {
	mapping(address => mapping(address => TradeParams)) public params;

	uint256 public correctionRatioMultiplier; // 2 decimals, e.g. 100 = 1x
	uint256 public offsetTolerance; // 2 decimals, e.g. 100 = 1%

	modifier checkNonZero(uint256 _amount) {
		if (_amount == 0) revert ZeroAmountPassed();
		_;
	}

	modifier checkNonZero2(uint256 _amount0, uint256 _amount1) {
		if (_amount0 == 0 || _amount1 == 0) revert ZeroAmountPassed();
		_;
	}

	modifier checkNonZeroAddress(address _addr) {
		if (_addr == address(0)) revert ZeroAddressPassed();
		_;
	}

	modifier checkNonZeroAddress2(address _addr0, address _addr1) {
		if (_addr0 == address(0) || _addr1 == address(0))
			revert ZeroAddressPassed();
		_;
	}

	modifier tradePathExists(address _tokenIn, address _tokenOut) {
		if (params[_tokenIn][_tokenOut].path.length == 0)
			revert TradePathNotFound(_tokenIn, _tokenOut);
		_;
	}

	function setUp(
		uint256 _correctionRatioMultiplier,
		uint256 _offsetTolerance
	) external initializer {
		__Ownable_init();

		setCorrectionRatioMultiplier(_correctionRatioMultiplier);
		setOffsetTolerance(_offsetTolerance);
	}

	function setCorrectionRatioMultiplier(uint256 _correctionRatioMultiplier)
		public
		onlyOwner
	{
		require(
			_correctionRatioMultiplier > 100,
			"TradeManager: bad correction ratio multiplier"
		);
		correctionRatioMultiplier = _correctionRatioMultiplier;
	}

	function setOffsetTolerance(uint256 _offsetTolerance) public onlyOwner {
		offsetTolerance = _offsetTolerance;
	}

	function setCorrectionRatio(
		address _tokenIn,
		address _tokenOut,
		uint256 _correctionRatio
	)
		public
		tradePathExists(_tokenIn, _tokenOut)
		checkNonZero(_correctionRatio)
		onlyOwner
	{
		params[_tokenIn][_tokenOut].correctionRatio = _correctionRatio;
	}

	function setTradeParams(
		address _tokenIn,
		address _tokenOut,
		Swap[] memory _path,
		uint256 _defaultCorrectionRatio
	)
		public
		onlyOwner
		checkNonZeroAddress2(_tokenIn, _tokenOut)
		checkNonZero(_defaultCorrectionRatio)
	{
		uint256 pathLength = _path.length;

		if (pathLength == 0) revert ZeroPathLength();

		if (
			_path[0].tokenIn != _tokenIn ||
			_path[_path.length - 1].tokenOut != _tokenOut
		) revert PathMismatch();

		delete params[_tokenIn][_tokenOut].path;

		Swap[] storage path = params[_tokenIn][_tokenOut].path;

		for (uint256 i = 0; i < pathLength; i++) {
			path.push(_path[i]);
		}

		params[_tokenIn][_tokenOut].correctionRatio = _defaultCorrectionRatio;
	}

	function getTradeParams(address tokenIn, address tokenOut)
		external
		view
		returns (TradeParams memory)
	{
		return params[tokenIn][tokenOut];
	}

	function expectInputForExactOutput(
		address _tokenIn,
		address _tokenOut,
		uint256 _amountOut
	)
		public
		view
		tradePathExists(_tokenIn, _tokenOut)
		returns (uint256 expectedInAmount)
	{
		Swap[] memory path = params[_tokenIn][_tokenOut].path;

		uint256 swapAmount = _amountOut;
		uint256 i = path.length;
		do {
			i--;
			Swap memory swap = path[i];
			IDexTrader trader = IDexTrader(swap.trader);
			uint256 swapIn = trader.expectInputForExactOutput(
				swap.tokenIn,
				swap.tokenOut,
				swapAmount
			);
			swapAmount = swapIn;
		} while (i > 0);

		expectedInAmount =
			(swapAmount * params[_tokenIn][_tokenOut].correctionRatio) /
			1 ether;

		return expectedInAmount;
	}

	function expectOutputForExactInput(
		address _tokenIn,
		address _tokenOut,
		uint256 _amountIn
	)
		public
		view
		tradePathExists(_tokenIn, _tokenOut)
		returns (uint256 expectedOutAmount)
	{
		Swap[] memory path = params[_tokenIn][_tokenOut].path;

		uint256 swapAmount = _amountIn;

		for (uint256 i = 0; i < path.length; i++) {
			Swap memory swap = path[i];
			IDexTrader trader = IDexTrader(swap.trader);
			uint256 swapOut = trader.expectOutputForExactInput(
				swap.tokenIn,
				swap.tokenOut,
				swapAmount
			);
			swapAmount = swapOut;
		}

		expectedOutAmount = swapAmount;

		return expectedOutAmount;
	}

	function tradeExactInput(
		address _tokenIn,
		address _tokenOut,
		uint256 _amountIn,
		uint256 _amountOutMin
	)
		public
		checkNonZero(_amountIn)
		checkNonZeroAddress2(_tokenIn, _tokenOut)
		tradePathExists(_tokenIn, _tokenOut)
		returns (uint256 amountOut)
	{
		amountOut = _trade(_tokenIn, _tokenOut, _amountIn, msg.sender);

		if (amountOut < _amountOutMin) revert InsufficientTradeOutput();
	}

	function tradeExactOutput(
		address _tokenIn,
		address _tokenOut,
		uint256 _amountOut,
		uint256 _amountInMax
	)
		public
		checkNonZero2(_amountOut, _amountInMax)
		checkNonZeroAddress2(_tokenIn, _tokenOut)
		tradePathExists(_tokenIn, _tokenOut)
		returns (uint256 amountIn)
	{
		amountIn = expectInputForExactOutput(_tokenIn, _tokenOut, _amountOut);

		if (amountIn > _amountInMax) revert InsufficientTradeInput();

		uint256 amountOutReal = _trade(
			_tokenIn,
			_tokenOut,
			amountIn,
			msg.sender
		);

		if (amountOutReal < _amountOut) {
			_increaseCorrectionRatio(_tokenIn, _tokenOut);

			revert InsufficientTradeOutput();
		}

		uint256 offset = amountOutReal - _amountOut;
		if (offset > (_amountOut * offsetTolerance) / 10000) {
			_decreaseCorrectionRatio(_tokenIn, _tokenOut);
		}

		return amountIn;
	}

	function _trade(
		address _tokenIn,
		address _tokenOut,
		uint256 _amountIn,
		address _sender
	) internal returns (uint256 amountOut) {
		TransferHelper.safeTransferFrom(
			_tokenIn,
			_sender,
			address(this),
			_amountIn
		);

		Swap[] memory path = params[_tokenIn][_tokenOut].path;

		uint256 swapAmountIn = _amountIn;
		for (uint256 i; i < path.length; i++) {
			Swap memory swap = path[i];
			IDexTrader trader = IDexTrader(swap.trader);

			TransferHelper.safeApprove(
				swap.tokenIn,
				address(trader),
				swapAmountIn
			);

			uint256 swapAmountOut = trader.swapExactInputSinglePath(
				swap.tokenIn,
				swap.tokenOut,
				swapAmountIn,
				0
			);

			swapAmountIn = swapAmountOut;
		}

		amountOut = swapAmountIn;

		TransferHelper.safeTransfer(_tokenOut, _sender, amountOut);

		return amountOut;
	}

	function increaseCorrectionRatio(address _tokenIn, address _tokenOut)
		public
		onlyOwner
	{
		_increaseCorrectionRatio(_tokenIn, _tokenOut);
	}

	function _increaseCorrectionRatio(address _tokenIn, address _tokenOut)
		internal
	{
		params[_tokenIn][_tokenOut].correctionRatio =
			(params[_tokenIn][_tokenOut].correctionRatio *
				correctionRatioMultiplier) /
			100;
	}

	function decreaseCorrectionRatio(address _tokenIn, address _tokenOut)
		public
		onlyOwner
	{
		_decreaseCorrectionRatio(_tokenIn, _tokenOut);
	}

	function _decreaseCorrectionRatio(address _tokenIn, address _tokenOut)
		internal
	{
		uint256 newRatio = (params[_tokenIn][_tokenOut].correctionRatio /
			correctionRatioMultiplier) * 100;
		if (newRatio < 100) {
			return;
		}
		params[_tokenIn][_tokenOut].correctionRatio = newRatio;
	}
}
