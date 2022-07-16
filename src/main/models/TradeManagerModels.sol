// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

struct Swap {
	address trader;
	address tokenIn;
	address tokenOut;
}

struct TradeParams {
	Swap[] path;
	uint256 correctionRatio; // correction ratio decimals 18
}
