// SPDX-License-Identifier: SEE LICENSE IN LICENSE

pragma solidity ^0.8.13;

import { BaseTest, console } from "../base/BaseTest.t.sol";
import "../../main/traders/CurveTrader.sol";
import "../mocks/MockCurveStableSwap.sol";
import "../mocks/MockERC20.sol";
import "../../main/models/CurveModels.sol";

contract CurveTraderTest is BaseTest {
	bytes private constant REVERT_ZERO_AMOUNT =
		abi.encodeWithSignature("ZeroAmountPassed()");
	bytes private constant REVERT_ZERO_ADDRESS =
		abi.encodeWithSignature("ZeroAddressPassed()");
	bytes private constant REVERT_POOL_INFO_MISSING =
		abi.encodeWithSignature("PoolInfoMissing()");
	bytes private constant REVERT_INSUFFICIENT_OUTPUT_AMOUNT =
		"MockCurveStableSwap: insufficient output amount";

	uint256 constant swapRate = 1;

	CurveTrader private underTest;
	MockCurveStableSwap private mockCurveStableSwap;

	MockERC20 private tokenIn;
	MockERC20 private tokenOut;

	address private owner;
	address private user;
	address private randomAddr;

	function setUp() public {
		vm.warp(10000);

		underTest = new CurveTrader();

		owner = accountsDb.PUBLIC_KEYS(0);
		user = accountsDb.PUBLIC_KEYS(1);
		randomAddr = accountsDb.PUBLIC_KEYS(2);

		tokenIn = new MockERC20("TokenIn", "IN");
		tokenOut = new MockERC20("TokenOut", "OUT");

		address[] memory tokens = new address[](2);
		tokens[0] = address(tokenIn);
		tokens[1] = address(tokenOut);

		mockCurveStableSwap = new MockCurveStableSwap(tokens);

		tokenIn.mint(user, type(uint256).max);
		tokenOut.mint(address(mockCurveStableSwap), type(uint256).max);

		vm.startPrank(owner);
		{
			underTest.setUp();
			underTest.registerPool(
				address(tokenIn),
				address(tokenOut),
				0,
				1,
				address(mockCurveStableSwap)
			);
		}
		vm.stopPrank();
	}

	function test_setUp_CallerIsOwner() public prankAs(user) {
		underTest = new CurveTrader();

		underTest.setUp();
		assertEq(underTest.owner(), user);
	}

	function test_registerPool_asUser_thenReverts() public prankAs(user) {
		vm.expectRevert(NOT_OWNER);
		underTest.registerPool(
			address(tokenIn),
			address(tokenOut),
			0,
			1,
			address(mockCurveStableSwap)
		);
	}

	function test_registerPool_asOwner_givenZeroAddress_thenReverts()
		public
		prankAs(owner)
	{
		vm.expectRevert(REVERT_ZERO_ADDRESS);
		underTest.registerPool(
			address(0),
			address(tokenOut),
			0,
			1,
			address(mockCurveStableSwap)
		);
		vm.expectRevert(REVERT_ZERO_ADDRESS);
		underTest.registerPool(
			address(tokenIn),
			address(0),
			0,
			1,
			address(mockCurveStableSwap)
		);

		vm.expectRevert(REVERT_ZERO_ADDRESS);
		underTest.registerPool(
			address(tokenIn),
			address(tokenOut),
			0,
			1,
			address(0)
		);
	}

	function test_registerPool_asOwner_givenValidInfo_thenSetMaxAllowanceForPool()
		public
		prankAs(owner)
	{
		underTest.registerPool(
			address(tokenIn),
			address(tokenOut),
			0,
			1,
			address(mockCurveStableSwap)
		);

		uint256 allowanceA = tokenIn.allowance(
			address(underTest),
			address(mockCurveStableSwap)
		);
		uint256 allowanceB = tokenOut.allowance(
			address(underTest),
			address(mockCurveStableSwap)
		);
		assertEq(allowanceA, type(uint256).max);
		assertEq(allowanceB, type(uint256).max);
	}

	function test_registerPool_asOwner_givenValidInfo_thenRegisterPool()
		public
		prankAs(owner)
	{
		underTest.registerPool(
			address(tokenIn),
			address(tokenOut),
			0,
			1,
			address(mockCurveStableSwap)
		);

		PoolInfo memory poolInfoAB = underTest.getPoolInfo(
			address(tokenIn),
			address(tokenOut)
		);
		assertEq(poolInfoAB.pool, address(mockCurveStableSwap));
		assertEq(poolInfoAB.indexA, 0);
		assertEq(poolInfoAB.indexB, 1);

		PoolInfo memory poolInfoBA = underTest.getPoolInfo(
			address(tokenOut),
			address(tokenIn)
		);
		assertEq(poolInfoBA.pool, address(mockCurveStableSwap));
		assertEq(poolInfoBA.indexA, 1);
		assertEq(poolInfoBA.indexB, 0);
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

	function test_swapExactInputSinglePath_asUser_givenMissingPool_thenReverts()
		public
		prankAs(user)
	{
		uint256 amountIn = 10 ether;
		vm.expectRevert(REVERT_POOL_INFO_MISSING);
		underTest.swapExactInputSinglePath(
			address(tokenIn),
			randomAddr,
			amountIn,
			0
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
		vm.expectRevert(REVERT_ZERO_AMOUNT);
		underTest.swapExactOutputSinglePath(
			address(tokenIn),
			address(tokenOut),
			0,
			type(uint256).max
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

	function test_swapExactOutputSinglePath_asUser_givenMissingPool_thenReverts()
		public
		prankAs(user)
	{
		uint256 amountOut = 10 ether;
		vm.expectRevert(REVERT_POOL_INFO_MISSING);
		underTest.swapExactOutputSinglePath(
			address(tokenIn),
			randomAddr,
			amountOut,
			type(uint256).max
		);
	}

	function test_swapExactOutputSinglePath_asUser_givenSmallAmountInMax_thenReverts()
		public
		prankAs(user)
	{
		uint256 amountOut = 10 ether;
		tokenIn.approve(address(underTest), type(uint256).max);
		vm.expectRevert(REVERT_INSUFFICIENT_OUTPUT_AMOUNT);
		underTest.swapExactOutputSinglePath(
			address(tokenIn),
			address(tokenOut),
			amountOut,
			9 ether
		);
	}

	function test_swapExactOutputSinglePath_asUser_givenTooBigAmountInMax_thenReturnsRemainingToken()
		public
		prankAs(user)
	{
		uint256 amountOut = 10 ether;
		tokenIn.approve(address(underTest), 11 ether);

		uint256 tokenInBalanceBefore = tokenIn.balanceOf(user);
		underTest.swapExactOutputSinglePath(
			address(tokenIn),
			address(tokenOut),
			amountOut,
			11 ether
		);
		uint256 tokenInBalanceAfter = tokenIn.balanceOf(user);

		assertEq(tokenIn.allowance(user, address(underTest)), 0);
		assertEq(tokenInBalanceAfter, tokenInBalanceBefore - 10 ether);
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
		uint256 expectedAmount = 10 ether;

		vm.mockCall(
			address(mockCurveStableSwap),
			abi.encodeWithSignature(
				"get_dy(int128,int128,uint256)",
				0,
				1,
				10 ether
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
		uint256 expectedAmount = 10 ether;

		vm.mockCall(
			address(mockCurveStableSwap),
			abi.encodeWithSignature(
				"get_dy(int128,int128,uint256)",
				0,
				1,
				10 ether
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
