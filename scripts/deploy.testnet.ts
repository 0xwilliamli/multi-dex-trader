import { IDeployConfig } from "./config/DeployConfig"
import { Deployer } from "./Deployer"
import { DeploymentHelper } from "./utils/DeploymentHelper"

const config: IDeployConfig = {
	outputFile: "./testnet_deployments.json",
	TX_CONFIRMATIONS: 1,
	uniswapV3Quoter: "0xa0a9Fa2324dB39e676AFDd7831D6b74a9a29A865",
	curvePool_renBTC_wBTC: "",
	tokens: {
		renBTC: "",
		wBTC: "",
		wETH: "",
		FRAX: "",
	}
}

async function main() {
	const helper = new DeploymentHelper(config)

	const renBTC = await helper.deployContractByName("MockERC20", "renBTC", "renBTC", "RENBTC");
	const wBTC = await helper.deployContractByName("MockERC20", "wBTC", "Wrapped Bitcoin", "WBTC");
	const wETH = await helper.deployContractByName("MockERC20", "wETH", "Wrapped Ethereum", "WETH");
	const frax = await helper.deployContractByName("MockERC20", "FRAX", "FRAX", "FRAX");

	const curvePool_renBTC_wBTC = await 
		helper.deployContractByName(
			"MockCurveStableSwap", 
			"CurveSwap(renBTC-WBTC)", 
			[renBTC.address, wBTC.address]
		)

	config.tokens.renBTC = renBTC.address;
	config.tokens.wBTC = wBTC.address;
	config.tokens.wETH = wETH.address;
	config.tokens.FRAX = frax.address;

	config.curvePool_renBTC_wBTC = curvePool_renBTC_wBTC.address;

	await new Deployer(config).run()
}

main().catch(error => {
	console.error(error)
	process.exitCode = 1
})
