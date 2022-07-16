// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@uniswap/v3-core/contracts/interfaces/pool/IUniswapV3PoolImmutables.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "./interfaces/IQuoter.sol";
import "./interfaces/IUniswapV3Quoter.sol";
import "./libraries/FullMath.sol";
import "./libraries/TickMath.sol";
import "./libraries/SafeCast.sol";
import "./libraries/TickBitmap.sol";
import "./libraries/SqrtPriceMath.sol";
import './UniswapV3Quoter.sol';
import "hardhat/console.sol";

contract Quoter is IQuoter, UniswapV3Quoter {
    using SafeERC20 for IERC20;
    using SafeCast for uint256;

    IUniswapV3Factory internal uniV3Factory; // TODO should it be immutable?

    constructor(address _uniV3Factory) {
        uniV3Factory = IUniswapV3Factory(_uniV3Factory);
    }

    function estimateMaxSwapUniswapV3(
        address _fromToken,
        address _toToken,
        uint256 _amount,
        uint24 _poolFee
    ) public view override returns (uint256) {
        address pool = uniV3Factory.getPool(_fromToken, _toToken, _poolFee);

        return _estimateOutputSingle(_toToken, _fromToken, _amount, pool);
    }

    function estimateMinSwapUniswapV3(
        address _fromToken,
        address _toToken,
        uint256 _amount,
        uint24 _poolFee
    ) public view override returns (uint256) {
        address pool = uniV3Factory.getPool(_fromToken, _toToken, _poolFee);

        return _estimateInputSingle(_toToken, _fromToken, _amount, pool);
    }

    function _estimateOutputSingle(
        address _fromToken,
        address _toToken,
        uint256 _amount,
        address _pool
    ) internal view returns (uint256 amountOut) {
        bool zeroForOne = _fromToken > _toToken;
        // todo: price limit?
        (int256 amount0, int256 amount1) = quoteSwapExactAmount(_pool, int256(_amount), zeroForOne ? (TickMath.MIN_SQRT_RATIO + 1) : (TickMath.MAX_SQRT_RATIO - 1), zeroForOne);
        if (zeroForOne)
            amountOut = amount1 > 0 ? uint256(amount1) : uint256(-amount1);
        else amountOut = amount0 > 0 ? uint256(amount0) : uint256(-amount0);
    }

    function _estimateInputSingle(
        address _fromToken,
        address _toToken,
        uint256 _amount,
        address _pool
    ) internal view returns (uint256 amountOut) {
        bool zeroForOne = _fromToken < _toToken;
        // todo: price limit?
        (int256 amount0, int256 amount1) = quoteSwap(_pool, -int256(_amount), zeroForOne ? (TickMath.MIN_SQRT_RATIO + 1) : (TickMath.MAX_SQRT_RATIO - 1), zeroForOne);
        if (zeroForOne)
            amountOut = amount0 > 0 ? uint256(amount0) : uint256(-amount0);
        else amountOut = amount1 > 0 ? uint256(amount1) : uint256(-amount1);
    }    


    function doesPoolExist(address _token0, address _token1)
        external
        view
        returns (bool)
    {
        // try 0.05%
        address pool = uniV3Factory.getPool(_token0, _token1, 500);
        if (pool != address(0)) return true;

        // try 0.3%
        pool = uniV3Factory.getPool(_token0, _token1, 3000);
        if (pool != address(0)) return true;

        // try 1%
        pool = uniV3Factory.getPool(_token0, _token1, 10000);
        if (pool != address(0)) return true;
        else return false;
    }
}
