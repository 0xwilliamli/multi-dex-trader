// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

interface IStableSwap {
	function coins(uint256 index) external view returns (address);

	function get_dy(
		int128 i,
		int128 j,
		uint256 _dx
	) external view returns (uint256);

	function exchange(
		int128 i,
		int128 j,
		uint256 _dx,
		uint256 _min_dy
	) external returns (uint256);
}
