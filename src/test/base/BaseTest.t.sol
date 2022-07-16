// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import { DSTest } from "ds-test/test.sol";

import { VM } from "../utils/VM.sol";
import { console } from "../utils/console.sol";
import "../utils/Accounts.sol";

contract BaseTest is DSTest {
	VM internal constant vm = VM(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
	Accounts internal accountsDb = new Accounts(vm);

	bytes internal constant NOT_OWNER = "Ownable: caller is not the owner";
	bytes internal constant ERC20_INVALID_BALANCE =
		"ERC20: transfer amount exceeds balance";

	modifier prankAs(address caller) {
		vm.startPrank(caller);
		_;
		vm.stopPrank();
	}

	function assertEqTolerance(
		uint256 a,
		uint256 b,
		uint256 tolerancePercentage // two decimals
	) internal {
		uint256 diff = b > a ? b - a : a - b;
		uint256 maxForgivness = (b * tolerancePercentage) / 10000;

		if (maxForgivness < diff) {
			emit log("Error: a == b not satisfied [with forgivness]");
			emit log_named_uint("  A", a);
			emit log_named_uint("  B", b);
			emit log_named_uint("  Max forgivness", maxForgivness);
			emit log_named_uint("    Actual Difference", diff);
			fail();
		}
	}
}
