// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

abstract contract DexTraderBase is OwnableUpgradeable {
	error ZeroAmountPassed();
	error ZeroAddressPassed();

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
}
