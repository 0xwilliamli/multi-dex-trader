import * as dotenv from "dotenv"

import { HardhatUserConfig, task, subtask } from "hardhat/config"
import { TASK_COMPILE_SOLIDITY_GET_SOURCE_PATHS } from "hardhat/builtin-tasks/task-names"

import "@nomiclabs/hardhat-etherscan"
import "@nomiclabs/hardhat-waffle"
import "@typechain/hardhat"
import "@openzeppelin/hardhat-upgrades"

dotenv.config()

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
	const accounts = await hre.ethers.getSigners()

	for (const account of accounts) {
		console.log(account.address)
	}
})

subtask(TASK_COMPILE_SOLIDITY_GET_SOURCE_PATHS).setAction(async (_, __, runSuper) => {
	const paths = await runSuper()
	return paths.filter((p: string) => !p.endsWith(".t.sol") || p.includes("/mock/"))
})

const config: HardhatUserConfig = {
	defaultNetwork: "localhost",
	networks: {
		localhost: {
			url: "http://localhost:8545",
		},
		rinkeby: {
			url: process.env.RINKEBY_URL || "",
			accounts:
				process.env.PRIVATE_KEY_TEST !== undefined
					? [process.env.PRIVATE_KEY_TEST]
					: [
							"0x60ddfe7f579ab6867cbe7a2dc03853dc141d7a4ab6dbefc0dae2d2b1bd4e487f",
					  ],
		},
		mainnet: {
			url: process.env.MAINNET_URL || "",
			accounts:
				process.env.PRIVATE_KEY !== undefined
					? [process.env.PRIVATE_KEY]
					: [
							"0x60ddfe7f579ab6867cbe7a2dc03853dc141d7a4ab6dbefc0dae2d2b1bd4e487f",
					  ],
		},
	},
	etherscan: {
		apiKey: process.env.ETHERSCAN_API_KEY,
	},
	solidity: {
		version: "0.8.13",
		settings: {
			optimizer: {
				enabled: true,
				runs: 200,
			},
		},
	},
	paths: {
		sources: "./src",
		tests: "./test",
		cache: "./hardhat/cache",
		artifacts: "./hardhat/artifacts",
	},
}

export default config
