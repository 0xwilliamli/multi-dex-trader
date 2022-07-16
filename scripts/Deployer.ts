import { IDeployConfig } from "./config/DeployConfig"
import { DeploymentHelper } from "./utils/DeploymentHelper"
import { ethers } from "hardhat"
import { Contract, Signer, utils } from "ethers"
import { ensureValidString } from "./utils/TradeHelper";
import { SwapStruct } from "../typechain-types/TradeManager";

export class Deployer {
	config: IDeployConfig
	helper: DeploymentHelper
	deployer?: Signer

	curveTrader?: Contract
	uniswapV2Trader?: Contract
	uniswapV3Trader?: Contract
	tradeManager?: Contract

	readonly UniswapV2RouterAddress = "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D";
	readonly UniswapV3RouterAddress = "0x1F98431c8aD98523631AE4a59f267346ea31F984";

	constructor(config: IDeployConfig) {
		this.config = config
		this.helper = new DeploymentHelper(config)
	}

	async run() {
		console.log("run()")
		this.deployer = (await ethers.getSigners())[0]

		this.curveTrader = await this.helper.deployUpgradeableContractWithName(
			"CurveTrader",
			"CurveTrader",
			"setUp"
		)

		this.uniswapV2Trader = await this.helper.deployUpgradeableContractWithName(
			"UniswapV2Trader",
			"UniswapV2Trader",
			"setUp",
			this.UniswapV2RouterAddress
		)

		this.uniswapV3Trader = await this.helper.deployUpgradeableContractWithName(
			"UniswapV3Trader",
			"UniswapV3Trader",
			"setUp",
			this.UniswapV3RouterAddress,
			this.config.uniswapV3Quoter
		)
		
		this.tradeManager = await this.helper.deployUpgradeableContractWithName(
			"TradeManager",
			"TradeManager",
			"setUp",
			101,	// Correction Ratio Multiplier: 1.01x
			10		// Offset Tolerance: 0.1%
		)

		await this.configCurveTrader()
		await this.configTradeManager()
	}

	async configCurveTrader() {
		console.log("configCurveTrader()")

		await this.helper.sendAndWaitForTransaction(
			this.curveTrader?.registerPool(
				this.config.tokens.renBTC, 
				this.config.tokens.wBTC, 
				0, 
				1, 
				this.config.curvePool_renBTC_wBTC
			)
		)
	}

	async configTradeManager() {
		console.log("configTradeManager()")

		const path: SwapStruct[] = new Array<SwapStruct>(
			{
				trader: ensureValidString(this.curveTrader?.address),
				tokenIn: this.config.tokens.renBTC,
				tokenOut: this.config.tokens.wBTC
			},
			{
				trader: ensureValidString(this.uniswapV3Trader?.address),
				tokenIn: this.config.tokens.wBTC,
				tokenOut: this.config.tokens.wETH
			},
			{
				trader: ensureValidString(this.uniswapV3Trader?.address),
				tokenIn: this.config.tokens.wETH,
				tokenOut: this.config.tokens.FRAX
			},
		)

		await this.helper.sendAndWaitForTransaction(
			this.tradeManager?.setTradeParams(
				this.config.tokens.renBTC, 
				this.config.tokens.FRAX, 
				path, 
				utils.parseEther('1')
			)
		)
	}
}
