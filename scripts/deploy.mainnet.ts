import { IDeployConfig } from "./config/DeployConfig"
import { Deployer } from "./Deployer"
import { colorLog, Colors, addColor } from "./utils/ColorConsole"
import * as readline from "readline-sync"

const config: IDeployConfig = {
  outputFile: "./mainnet_deployments.json",
  TX_CONFIRMATIONS: 3,
}

async function main() {
	var userinput: string = "0"

	userinput = readline.question(
		addColor(
			Colors.yellow,
			`\nYou are about to deploy on the mainnet, is it fine? [y/N]\n`
		)
	)

	if (userinput.toLowerCase() !== "y") {
		colorLog(Colors.blue, `User cancelled the deployment!\n`)
		return
	}

	colorLog(Colors.green, `User approved the deployment\n`)

	await new Deployer(config).run()
}

main().catch(error => {
	console.error(error)
	process.exitCode = 1
})
