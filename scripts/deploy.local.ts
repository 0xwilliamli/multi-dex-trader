import { IDeployConfig } from "./config/DeployConfig"
import { Deployer } from "./Deployer"

const config: IDeployConfig = {
	outputFile: "local_deployments.json",
	TX_CONFIRMATIONS: 1,
}

async function main() {
	await new Deployer(config).run()
}

main().catch(error => {
	console.error(error)
	process.exitCode = 1
})
