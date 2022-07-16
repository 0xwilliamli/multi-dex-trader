// SPDX-License-Identifier: SEE LICENSE IN LICENSE

pragma solidity ^0.8.13;

import { BaseTest, console } from "../base/BaseTest.t.sol";
import "../../main/traders/UniswapV3Trader.sol";
import "../mocks/MockUniswapV3Router.sol";
import "../mocks/MockUniswapV3Quoter.sol";
import "../mocks/MockERC20.sol";

contract UniswapV3TraderTest is BaseTest {
	bytes private constant REVERT_ZERO_AMOUNT =
		abi.encodeWithSignature("ZeroAmountPassed()");
	bytes private constant REVERT_ZERO_ADDRESS =
		abi.encodeWithSignature("ZeroAddressPassed()");

	uint256 constant swapRate = 3;

	UniswapV3Trader private underTest;
	MockUniswapV3Quoter private mockUniswapV3Quoter;
	MockUniswapV3Router private mockUniswapV3Router;

	MockERC20 private tokenIn;
	MockERC20 private tokenOut;

	address private owner;
	address private user;

	function setUp() public {
		vm.warp(10000);

		underTest = new UniswapV3Trader();
		mockUniswapV3Router = new MockUniswapV3Router();
		mockUniswapV3Quoter = new MockUniswapV3Quoter(mockUniswapV3Router);

		owner = accountsDb.PUBLIC_KEYS(0);
		user = accountsDb.PUBLIC_KEYS(1);

		tokenIn = new MockERC20("TokenIn", "IN");
		tokenOut = new MockERC20("TokenOut", "OUT");

		tokenIn.mint(user, type(uint256).max);
		tokenOut.mint(address(mockUniswapV3Router), type(uint256).max);

		vm.startPrank(owner);
		{
			underTest.setUp(
				address(mockUniswapV3Router),
				address(mockUniswapV3Quoter)
			);
		}
		vm.stopPrank();
	}

	function test_setUp_CallerIsOwner() public prankAs(user) {
		underTest = new UniswapV3Trader();

		underTest.setUp(
			address(mockUniswapV3Router),
			address(mockUniswapV3Quoter)
		);
		assertEq(underTest.owner(), user);
	}

	function test_setUp_asOwner_givenZeroAddress_thenReverts()
		public
		prankAs(owner)
	{
		underTest = new UniswapV3Trader();

		vm.expectRevert(REVERT_ZERO_ADDRESS);
		underTest.setUp(address(0), address(mockUniswapV3Quoter));

		vm.expectRevert(REVERT_ZERO_ADDRESS);
		underTest.setUp(address(mockUniswapV3Router), address(0));
	}

	function test_setUp_asOwner_thenSetUpCorrectly() public prankAs(owner) {
		underTest = new UniswapV3Trader();

		underTest.setUp(
			address(mockUniswapV3Router),
			address(mockUniswapV3Quoter)
		);
		address _uniswapV3Router = address(underTest.uniswapV3Router());
		address _uniswapV3Quoter = address(underTest.v3Quoter());

		assertEq(_uniswapV3Router, address(mockUniswapV3Router));
		assertEq(_uniswapV3Quoter, address(mockUniswapV3Quoter));
	}

	function test_setMaxTxDuration_asUser_thenReverts()
		public
		prankAs(user)
	{
		vm.expectRevert(NOT_OWNER);
		underTest.setMaxTxDuration(15);
	}

	function test_setMaxTxDuration_asOwner_thenSetCorrectly()
		public
		prankAs(owner)
	{
		underTest.setMaxTxDuration(30);
		uint256 maxTxDuration = underTest.maxTxDuration();
		assertEq(maxTxDuration, 30);
	}

	function test_setPoolFee_asUser_thenReverts() public prankAs(user) {
		vm.expectRevert(NOT_OWNER);
		underTest.setPoolFee(3000);
	}

	function test_setPoolFee_asOwner_thenSetCorrectly()
		public
		prankAs(owner)
	{
		underTest.setPoolFee(5000);
		uint256 poolFee = underTest.poolFee();
		assertEq(poolFee, 5000);
	}

	function test_swapExactInputSinglePath_asUser_givenZeroAmount_thenReverts()
		public
		prankAs(user)
	{
		vm.expectRevert(REVERT_ZERO_AMOUNT);
		underTest.swapExactInputSinglePath(
			address(tokenIn),
			address(tokenOut),
			0,
			0
		);
	}

	function test_swapExactInputSinglePath_asUser_givenZeroAddress_thenReverts()
		public
		prankAs(user)
	{
		uint256 amountIn = 10 ether;
		vm.expectRevert(REVERT_ZERO_ADDRESS);
		underTest.swapExactInputSinglePath(
			address(0),
			address(tokenOut),
			amountIn,
			0
		);
		vm.expectRevert(REVERT_ZERO_ADDRESS);
		underTest.swapExactInputSinglePath(
			address(tokenIn),
			address(0),
			amountIn,
			0
		);
	}

	function test_swapExactInputSinglePath_asUser_givenValidParams_thenSetMaxAllowanceForRouter()
		public
		prankAs(user)
	{
		uint256 amountIn = 10 ether;
		tokenIn.approve(address(underTest), amountIn);

		underTest.swapExactInputSinglePath(
			address(tokenIn),
			address(tokenOut),
			amountIn,
			0
		);
		assertEq(
			tokenIn.allowance(address(underTest), address(mockUniswapV3Router)),
			type(uint256).max
		);
	}

	function test_swapExactInputSinglePath_asUser_givenValidParams_thenReturnedValueIsCorrect()
		public
		prankAs(user)
	{
		uint256 amountIn = 10 ether;
		tokenIn.approve(address(underTest), amountIn);

		uint256 amountOut = underTest.swapExactInputSinglePath(
			address(tokenIn),
			address(tokenOut),
			amountIn,
			0
		);

		assertEq(amountOut, amountIn * swapRate);
	}

	function test_swapExactInputSinglePath_asUser_givenValidParams_thenSwapExactly()
		public
		prankAs(user)
	{
		uint256 amountIn = 10 ether;
		tokenIn.approve(address(underTest), amountIn);

		uint256 balanceTokenInBefore = tokenIn.balanceOf(user);
		uint256 balanceTokenOutBefore = tokenOut.balanceOf(user);

		uint256 amountOut = underTest.swapExactInputSinglePath(
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

	function test_swapExactOutputSinglePath_asUser_givenZeroAmount_thenReverts()
		public
		prankAs(user)
	{
		uint256 amountOut = 10 ether;
		vm.expectRevert(REVERT_ZERO_AMOUNT);
		underTest.swapExactOutputSinglePath(
			address(tokenIn),
			address(tokenOut),
			0,
			type(uint256).max
		);
		vm.expectRevert(REVERT_ZERO_AMOUNT);
		underTest.swapExactOutputSinglePath(
			address(tokenIn),
			address(tokenOut),
			amountOut,
			0
		);
	}

	function test_swapExactOutputSinglePath_asUser_givenZeroAddress_thenReverts()
		public
		prankAs(user)
	{
		uint256 amountOut = 10 ether;
		vm.expectRevert(REVERT_ZERO_ADDRESS);
		underTest.swapExactOutputSinglePath(
			address(0),
			address(tokenOut),
			amountOut,
			type(uint256).max
		);
		vm.expectRevert(REVERT_ZERO_ADDRESS);
		underTest.swapExactOutputSinglePath(
			address(tokenIn),
			address(0),
			amountOut,
			type(uint256).max
		);
	}

	function test_swapExactOutputSinglePath_asUser_givenValidParams_thenSetMaxAllowanceForRouter()
		public
		prankAs(user)
	{
		uint256 amountOut = 10 ether;
		tokenIn.approve(address(underTest), type(uint256).max);

		underTest.swapExactOutputSinglePath(
			address(tokenIn),
			address(tokenOut),
			amountOut,
			type(uint256).max
		);
		assertEq(
			tokenIn.allowance(address(underTest), address(mockUniswapV3Router)),
			type(uint256).max
		);
	}

	function test_swapExactOutputSinglePath_asUser_givenValidParams_thenReturnedValueIsCorrect()
		public
		prankAs(user)
	{
		uint256 amountOut = 10 ether;
		tokenIn.approve(address(underTest), type(uint256).max);

		uint256 amountIn = underTest.swapExactOutputSinglePath(
			address(tokenIn),
			address(tokenOut),
			amountOut,
			type(uint256).max
		);

		assertEq(amountIn, amountOut / swapRate);
	}

	function test_swapExactOutputSinglePath_asUser_givenValidParams_thenSwapExactly()
		public
		prankAs(user)
	{
		uint256 amountOut = 10 ether;
		tokenIn.approve(address(underTest), type(uint256).max);

		uint256 balanceTokenInBefore = tokenIn.balanceOf(user);
		uint256 balanceTokenOutBefore = tokenOut.balanceOf(user);

		uint256 amountIn = underTest.swapExactOutputSinglePath(
			address(tokenIn),
			address(tokenOut),
			amountOut,
			type(uint256).max
		);

		uint256 balanceTokenInAfter = tokenIn.balanceOf(user);
		uint256 balanceTokenOutAfter = tokenOut.balanceOf(user);

		assertEq(balanceTokenInBefore - amountIn, balanceTokenInAfter);
		assertEq(balanceTokenOutBefore + amountOut, balanceTokenOutAfter);
	}

	function test_expectInputForExactOutput_asUser_givenExactOutput_thenGetExpectedInput()
		public
		prankAs(user)
	{
		uint256 expectedAmount = 3.3333 ether;

		vm.mockCall(
			address(mockUniswapV3Quoter),
			abi.encodeWithSignature(
				"estimateMinSwapUniswapV3(address,address,uint256,uint24)",
				address(tokenIn),
				address(tokenOut),
				10 ether,
				3000
			),
			abi.encode(expectedAmount)
		);

		uint256 returnedAmount = underTest.expectInputForExactOutput(
			address(tokenIn),
			address(tokenOut),
			10 ether
		);

		assertEq(returnedAmount, expectedAmount);
	}

	function test_expectOutputForExactInput_asUser_givenExactInput_thenGetExpectedOutput()
		public
		prankAs(user)
	{
		uint256 expectedAmount = 30 ether;

		vm.mockCall(
			address(mockUniswapV3Quoter),
			abi.encodeWithSignature(
				"estimateMaxSwapUniswapV3(address,address,uint256,uint24)",
				address(tokenIn),
				address(tokenOut),
				10 ether,
				3000
			),
			abi.encode(expectedAmount)
		);

		uint256 returnedAmount = underTest.expectOutputForExactInput(
			address(tokenIn),
			address(tokenOut),
			10 ether
		);

		assertEq(returnedAmount, expectedAmount);
	}
}
