# Multi Dex Trader

Smart contracts for managing trade paths across multiple DEXs to trade any 
collaterals into a targeted token

### Structure

- Dex Traders: Dedicated trader contract for each DEX used, including
  Uniswap v2, v3, Sushiswap, and Curve. Must be inherited from
  IVestaDexTrader interface.
- VestaTradeManager: Manages trading paths and actions for any collaterals
  supported in Vesta Protocol v1.

### Commands script

```
git clone https://github.com/IntelMin/multi-dex-trader.git
forge install
forge build
forge test
```
