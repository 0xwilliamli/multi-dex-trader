export const Colors = {
	gray: 90,
	green: 92,
	red: 91,
	yellow: 93,
	blue: 36,
	white: 0,
}

export function colorLog(colorCode: number, msg: string) {
	console.log("\u001b[" + colorCode + "m" + msg + "\u001b[0m")
}
export function addColor(colorCode: number, msg: string) {
	return "\u001b[" + colorCode + "m" + msg + "\u001b[0m"
}
