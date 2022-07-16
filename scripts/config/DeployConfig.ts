interface ITokenList {
  renBTC: string
  wBTC: string
  wETH: string
  FRAX: string
}

export interface IDeployConfig {
  outputFile: string
  TX_CONFIRMATIONS: number

  tokens: ITokenList

  uniswapV3Quoter: string
  curvePool_renBTC_wBTC: string
}
