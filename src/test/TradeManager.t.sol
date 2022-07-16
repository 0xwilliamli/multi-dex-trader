// SPDX-License-Identifier: SEE LICENSE IN LICENSE

pragma solidity ^0.8.13;

import { BaseTest, console } from "./base/BaseTest.t.sol";
import "../main/TradeManager.sol";

import "../main/traders/UniswapV2Trader.sol";
import "./mocks/MockUniswapV2Router.sol";

import "../main/traders/UniswapV3Trader.sol";
import "./mocks/MockUniswapV3Router.sol";
import "./mocks/MockUniswapV3Quoter.sol";

import "../main/traders/CurveTrader.sol";
import "./mocks/MockCurveStableSwap.sol";

import "./mocks/MockERC20.sol";

contract TradeManagerTest is BaseTest {
	bytes private constant REVERT_ZERO_AMOUNT =
		abi.encodeWithSignature("ZeroAmountPassed()");
	bytes private constant REVERT_ZERO_PATH_LENGTH =
		abi.encodeWithSignature("ZeroPathLength()");
	bytes private constant REVERT_ZERO_ADDRESS =
		abi.encodeWithSignature("ZeroAddressPassed()");
	string private constant REVERT_TRADE_PATH_NOT_FOUND =
		"TradePathNotFound(address,address)";
	bytes private constant REVERT_PATH_MISMATCH =
		abi.encodeWithSignature("PathMismatch()");
	bytes private constant REVERT_INSUFFICIENT_TRADE_INPUT =
		abi.encodeWithSignature("InsufficientTradeInput()");
	bytes private constant REVERT_INSUFFICIENT_TRADE_OUTPUT =
		abi.encodeWithSignature("InsufficientTradeOutput()");

	uint256 private constant defaultCorrectionRatio = 1 ether;

	TradeManager private underTest;
	UniswapV2Trader private uniswapV2Trader;
	UniswapV3Trader private uniswapV3Trader;
	CurveTrader private curveTrader;
	MockUniswapV2Router private mockUniswapV2Router;
	MockUniswapV3Router private mockUniswapV3Router;
	MockUniswapV3Quoter private mockUniswapV3Quoter;
	MockCurveStableSwap private mockCurveStableSwap;

	MockERC20 private tokenIn;
	MockERC20 private tokenOut;

	Swap[] private swapPath;

	address private owner;
	address private user;

	function setUp() public {
		vm.warp(10000);

		underTest = new TradeManager();
		uniswapV2Trader = new UniswapV2Trader();
		uniswapV3Trader = new UniswapV3Trader();
		curveTrader = new CurveTrader();

		owner = accountsDb.PUBLIC_KEYS(0);
		user = accountsDb.PUBLIC_KEYS(1);

		MockERC20[] memory path = new MockERC20[](4);
		path[0] = new MockERC20("Token 0", "T0");
		path[1] = new MockERC20("Token 1", "T1");
		path[2] = new MockERC20("Token 2", "T2");
		path[3] = new MockERC20("Token 3", "T3");

		mockUniswapV2Router = new MockUniswapV2Router();

		mockUniswapV3Router = new MockUniswapV3Router();
		mockUniswapV3Quoter = new MockUniswapV3Quoter(mockUniswapV3Router);

		address[] memory curvePair = new address[](2);
		curvePair[0] = address(path[2]);
		curvePair[1] = address(path[3]);
		mockCurveStableSwap = new MockCurveStableSwap(curvePair);

		uint256 EnoughBigAmount = 1000000000 ether;
		path[0].mint(user, EnoughBigAmount);
		path[1].mint(address(mockUniswapV2Router), EnoughBigAmount);
		path[2].mint(address(mockUniswapV3Router), EnoughBigAmount);
		path[3].mint(address(mockCurveStableSwap), EnoughBigAmount);

		swapPath.push(
			Swap({
				trader: address(uniswapV2Trader),
				tokenIn: address(path[0]),
				tokenOut: address(path[1])
			})
		);
		swapPath.push(
			Swap({
				trader: address(uniswapV3Trader),
				tokenIn: address(path[1]),
				tokenOut: address(path[2])
			})
		);
		swapPath.push(
			Swap({
				trader: address(curveTrader),
				tokenIn: address(path[2]),
				tokenOut: address(path[3])
			})
		);

		tokenIn = path[0];
		tokenOut = path[3];

		vm.startPrank(owner);
		{
			uniswapV2Trader.setUp(address(mockUniswapV2Router));
			uniswapV3Trader.setUp(
				address(mockUniswapV3Router),
				address(mockUniswapV3Quoter)
			);
			curveTrader.setUp();
			curveTrader.registerPool(
				address(curvePair[0]),
				address(curvePair[1]),
				0,
				1,
				address(mockCurveStableSwap)
			);

			underTest.setUp(101, 10010);
			underTest.setTradeParams(
				address(tokenIn),
				address(tokenOut),
				swapPath,
				defaultCorrectionRatio
			);
		}
		vm.stopPrank();
	}

	function test_setUp_asOwner_thenSetValuesCorrectly()
		public
		prankAs(owner)
	{
		underTest = new TradeManager();

		underTest.setUp(101, 10);
		assertEq(underTest.owner(), owner);
		uint256 multiplier = underTest.correctionRatioMultiplier();
		assertEq(multiplier, 101);
		uint256 tolerance = underTest.offsetTolerance();
		assertEq(tolerance, 10);
	}

	function test_setCorrectionRatioMultiplier_asUser_thenReverts()
		public
		prankAs(user)
	{
		vm.expectRevert(NOT_OWNER);
		underTest.setCorrectionRatioMultiplier(101);
	}

	function test_setCorrectionRatioMultiplier_asOwner_thenSetCorrectly()
		public
		prankAs(owner)
	{
		underTest.setCorrectionRatioMultiplier(101);
		uint256 multiplier = underTest.correctionRatioMultiplier();
		assertEq(multiplier, 101);
	}

	function test_setOffsetTolerance_asUser_thenReverts()
		public
		prankAs(user)
	{
		vm.expectRevert(NOT_OWNER);
		underTest.setOffsetTolerance(10);
	}

	function test_setOffsetTolerance_asOwner_thenSetCorrectly()
		public
		prankAs(owner)
	{
		underTest.setOffsetTolerance(10);
		uint256 tolerance = underTest.offsetTolerance();
		assertEq(tolerance, 10);
	}

	function test_setCorrectionRatio_asUser_thenReverts()
		public
		prankAs(user)
	{
		vm.expectRevert(NOT_OWNER);
		underTest.setCorrectionRatio(
			address(tokenIn),
			address(tokenOut),
			defaultCorrectionRatio
		);
	}

	function test_setCorrectionRatio_asOwner_thenSetCorrectly()
		public
		prankAs(owner)
	{
		underTest.setCorrectionRatio(
			address(tokenIn),
			address(tokenOut),
			defaultCorrectionRatio
		);
		uint256 correctionRatio = underTest
			.getTradeParams(address(tokenIn), address(tokenOut))
			.correctionRatio;
		assertEq(correctionRatio, defaultCorrectionRatio);
	}

	function test_setTradeParams_asUser_thenReverts() public prankAs(user) {
		vm.expectRevert(NOT_OWNER);
		underTest.setTradeParams(
			address(tokenIn),
			address(tokenOut),
			swapPath,
			defaultCorrectionRatio
		);
	}

	function test_setTradeParams_asOwner_givenMismatchingPath_thenReverts()
		public
		prankAs(owner)
	{
		vm.expectRevert(REVERT_PATH_MISMATCH);
		underTest.setTradeParams(
			swapPath[1].tokenIn,
			address(tokenOut),
			swapPath,
			defaultCorrectionRatio
		);
	}

	function test_setTradeParams_asOwner_givenZeroCorrectionRatio_thenReverts()
		public
		prankAs(owner)
	{
		vm.expectRevert(REVERT_ZERO_AMOUNT);
		underTest.setTradeParams(
			address(tokenIn),
			address(tokenOut),
			swapPath,
			0
		);
	}

	function test_setTradeParams_asOwner_givenZeroAddress_thenReverts()
		public
		prankAs(owner)
	{
		vm.expectRevert(REVERT_ZERO_ADDRESS);
		underTest.setTradeParams(
			address(0),
			address(tokenOut),
			swapPath,
			defaultCorrectionRatio
		);
		vm.expectRevert(REVERT_ZERO_ADDRESS);
		underTest.setTradeParams(
			address(tokenIn),
			address(0),
			swapPath,
			defaultCorrectionRatio
		);
	}

	function test_setTradeParams_asOwner_givenZeroPathLength_thenReverts()
		public
		prankAs(owner)
	{
		Swap[] memory zeroPath = new Swap[](0);
		vm.expectRevert(REVERT_ZERO_PATH_LENGTH);
		underTest.setTradeParams(
			address(tokenIn),
			address(tokenOut),
			zeroPath,
			defaultCorrectionRatio
		);
	}

	function test_setTradeParams_asOwner_thenSetCorrectly()
		public
		prankAs(owner)
	{
		underTest.setTradeParams(
			address(tokenIn),
			address(tokenOut),
			swapPath,
			defaultCorrectionRatio
		);
		TradeParams memory params = underTest.getTradeParams(
			address(tokenIn),
			address(tokenOut)
		);

		assertEq(params.correctionRatio, defaultCorrectionRatio);

		assertEq(params.path.length, swapPath.length);

		for (uint256 i = 0; i < swapPath.length; i++) {
			assertEq(params.path[i].trader, swapPath[i].trader);
			assertEq(params.path[i].tokenIn, swapPath[i].tokenIn);
			assertEq(params.path[i].tokenOut, swapPath[i].tokenOut);
		}
	}

	function test_tradeExactInput_asUser_givenUnregisterdPair_thenReverts()
		public
		prankAs(user)
	{
		uint256 amountIn = 10 ether;

		address unregisteredTokenIn = swapPath[1].tokenIn;
		vm.expectRevert(
			abi.encodeWithSignature(
				REVERT_TRADE_PATH_NOT_FOUND,
				unregisteredTokenIn,
				tokenOut
			)
		);
		underTest.tradeExactInput(
			unregisteredTokenIn,
			address(tokenOut),
			amountIn,
			0
		);
	}

	function test_tradeExactInput_asUser_givenZeroAmount_thenReverts()
		public
		prankAs(user)
	{
		uint256 zeroAmountIn = 0;

		vm.expectRevert(REVERT_ZERO_AMOUNT);
		underTest.tradeExactInput(
			address(tokenIn),
			address(tokenOut),
			zeroAmountIn,
			0
		);
	}

	function test_tradeExactInput_asUser_givenZeroAddress_thenReverts()
		public
		prankAs(user)
	{
		uint256 amountIn = 10 ether;
		vm.expectRevert(REVERT_ZERO_ADDRESS);
		underTest.tradeExactInput(address(0), address(tokenOut), amountIn, 0);
		vm.expectRevert(REVERT_ZERO_ADDRESS);
		underTest.tradeExactInput(address(tokenIn), address(0), amountIn, 0);
	}

	function test_tradeExactInput_asUser_givenTooBigMinOutput_thenReverts()
		public
		prankAs(user)
	{
		uint256 amountIn = 10 ether;
		tokenIn.approve(address(underTest), amountIn);

		vm.expectRevert(REVERT_INSUFFICIENT_TRADE_OUTPUT);
		underTest.tradeExactInput(
			address(tokenIn),
			address(tokenOut),
			amountIn,
			type(uint256).max
		);
	}

	function test_tradeExactInput_asUser_givenValidParams_thenReturnedValueIsCorrect()
		public
		prankAs(user)
	{
		uint256 amountIn = 10 ether;
		tokenIn.approve(address(underTest), amountIn);

		uint256 amountOut = underTest.tradeExactInput(
			address(tokenIn),
			address(tokenOut),
			amountIn,
			0
		);

		assertEq(amountOut, amountIn * 3 * 3);
	}

	function test_tradeExactInput_asUser_givenValidAmount_thenTradeProperly()
		public
		prankAs(user)
	{
		uint256 amountIn = 10 ether;
		tokenIn.approve(address(underTest), amountIn);

		uint256 balanceTokenInBefore = tokenIn.balanceOf(user);
		uint256 balanceTokenOutBefore = tokenOut.balanceOf(user);

		uint256 amountOut = underTest.tradeExactInput(
			address(tokenIn),
			address(tokenOut),
			amountIn,
			0
		);

		uint256 balanceTokenInAfter = tokenIn.balanceOf(user);
		uint256 balanceTokenOutAfter = tokenOut.balanceOf(user);

		assertEq(balanceTokenInBefore - amountIn, balanceTokenInAfter);
		assertEq(balanceTokenOutBefore + amountOut, balanceTokenOutAfter);
	}

	function test_tradeExactOutput_asUser_givenUnregisterdPair_thenReverts()
		public
		prankAs(user)
	{
		uint256 amountOut = 10 ether;
		tokenIn.approve(address(underTest), type(uint256).max);

		address unregisteredTokenIn = swapPath[1].tokenIn;
		vm.expectRevert(
			abi.encodeWithSignature(
				REVERT_TRADE_PATH_NOT_FOUND,
				unregisteredTokenIn,
				tokenOut
			)
		);
		underTest.tradeExactOutput(
			unregisteredTokenIn,
			address(tokenOut),
			amountOut,
			type(uint256).max
		);
	}

	function test_tradeExactOutput_asUser_givenZeroAmount_thenReverts()
		public
		prankAs(user)
	{
		uint256 amountOut = 10 ether;

		vm.expectRevert(REVERT_ZERO_AMOUNT);
		underTest.tradeExactOutput(
			address(tokenIn),
			address(tokenOut),
			0,
			type(uint256).max
		);

		vm.expectRevert(REVERT_ZERO_AMOUNT);
		underTest.tradeExactOutput(
			address(tokenIn),
			address(tokenOut),
			amountOut,
			0
		);
	}

	function test_tradeExactOutput_asUser_givenZeroAddress_thenReverts()
		public
		prankAs(user)
	{
		uint256 amountOut = 10 ether;

		vm.expectRevert(REVERT_ZERO_ADDRESS);
		underTest.tradeExactOutput(
			address(0),
			address(tokenOut),
			amountOut,
			type(uint256).max
		);
		vm.expectRevert(REVERT_ZERO_ADDRESS);
		underTest.tradeExactOutput(
			address(tokenIn),
			address(0),
			amountOut,
			type(uint256).max
		);
	}

	function test_tradeExactOutput_asUser_givenTooSmallMaxInput_thenReverts()
		public
		prankAs(user)
	{
		uint256 amountOut = 10 ether;
		tokenIn.approve(address(underTest), type(uint256).max);

		vm.expectRevert(REVERT_INSUFFICIENT_TRADE_INPUT);
		underTest.tradeExactOutput(
			address(tokenIn),
			address(tokenOut),
			amountOut,
			1
		);
	}

	function test_tradeExactOutput_asUser_givenValidParams_thenReturnedValueIsCorrect()
		public
	{
		vm.prank(owner);
		underTest.setCorrectionRatio(
			address(tokenIn),
			address(tokenOut),
			1.01 ether // Enough correction ratio, 101%
		);

		vm.startPrank(user);
		{
			uint256 amountOut = 10 ether;
			tokenIn.approve(address(underTest), type(uint256).max);

			uint256 amountIn = underTest.tradeExactOutput(
				address(tokenIn),
				address(tokenOut),
				amountOut,
				type(uint256).max
			);

			assertEq(amountIn, ((amountOut / 3 / 3) * 101) / 100);
		}
		vm.stopPrank();
	}

	function test_tradeExactOutput_asUser_givenValidAmount_andEnoughCorretionRatio_thenTradeProperly()
		public
	{
		vm.prank(owner);
		underTest.setCorrectionRatio(
			address(tokenIn),
			address(tokenOut),
			1.01 ether // Enough correction ratio, 101%
		);

		vm.startPrank(user);
		{
			uint256 amountOut = 10 ether;
			tokenIn.approve(address(underTest), type(uint256).max);

			uint256 balanceTokenInBefore = tokenIn.balanceOf(user);
			uint256 balanceTokenOutBefore = tokenOut.balanceOf(user);

			uint256 amountIn = underTest.tradeExactOutput(
				address(tokenIn),
				address(tokenOut),
				amountOut,
				type(uint256).max
			);

			uint256 balanceTokenInAfter = tokenIn.balanceOf(user);
			uint256 balanceTokenOutAfter = tokenOut.balanceOf(user);

			assertEq(balanceTokenInBefore - amountIn, balanceTokenInAfter);

			uint256 realAmountOut = balanceTokenOutAfter - balanceTokenOutBefore;
			assertEq(realAmountOut, (((amountOut / 3 / 3) * 101) / 100) * 3 * 3);
		}
		vm.stopPrank();
	}

	function test_expectInputForExactOutput_asUser_givenExactOuput_thenGetExpectedInput()
		public
		prankAs(user)
	{
		vm.mockCall(
			address(mockCurveStableSwap),
			abi.encodeWithSignature(
				"get_dy(int128,int128,uint256)",
				0,
				1,
				10 ether
			),
			abi.encode(10 ether)
		);

		vm.mockCall(
			address(mockUniswapV3Quoter),
			abi.encodeWithSignature(
				"estimateMinSwapUniswapV3(address,address,uint256,uint24)",
				address(swapPath[1].tokenIn),
				address(swapPath[1].tokenOut),
				10 ether,
				3000
			),
			abi.encode(3.3333 ether)
		);

		address[] memory paths = new address[](2);
		paths[0] = address(swapPath[0].tokenIn);
		paths[1] = address(swapPath[0].tokenOut);

		uint256[] memory expectedAmounts = new uint256[](2);
		expectedAmounts[0] = 1.1111 ether;
		expectedAmounts[1] = 3.3333 ether;

		vm.mockCall(
			address(mockUniswapV2Router),
			abi.encodeWithSignature(
				"getAmountsIn(uint256,address[])",
				3.3333 ether,
				paths
			),
			abi.encode(expectedAmounts)
		);

		uint256 returnedAmount = underTest.expectInputForExactOutput(
			address(tokenIn),
			address(tokenOut),
			10 ether
		);

		assertEq(returnedAmount, 1.1111 ether);
	}

	function test_expectOutputForExactInput_asUser_givenExactInput_thenGetExpectedOutput()
		public
		prankAs(user)
	{
		address[] memory paths = new address[](2);
		paths[0] = address(swapPath[0].tokenIn);
		paths[1] = address(swapPath[0].tokenOut);

		uint256[] memory expectedAmounts = new uint256[](2);
		expectedAmounts[0] = 1 ether;
		expectedAmounts[1] = 3 ether;

		vm.mockCall(
			address(mockUniswapV2Router),
			abi.encodeWithSignature(
				"getAmountsOut(uint256,address[])",
				1 ether,
				paths
			),
			abi.encode(expectedAmounts)
		);

		vm.mockCall(
			address(mockUniswapV3Quoter),
			abi.encodeWithSignature(
				"estimateMaxSwapUniswapV3(address,address,uint256,uint24)",
				address(swapPath[1].tokenIn),
				address(swapPath[1].tokenOut),
				3 ether,
				3000
			),
			abi.encode(9 ether)
		);

		vm.mockCall(
			address(mockCurveStableSwap),
			abi.encodeWithSignature(
				"get_dy(int128,int128,uint256)",
				0,
				1,
				9 ether
			),
			abi.encode(9 ether)
		);

		uint256 returnedAmount = underTest.expectOutputForExactInput(
			address(tokenIn),
			address(tokenOut),
			1 ether
		);

		assertEq(returnedAmount, 9 ether);
	}
}
