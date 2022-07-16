const { use, assert } = require("chai");
const { ethers } = require("hardhat");
const { solidity } = require("ethereum-waffle");
const {
  abi,
} = require("@uniswap/v3-periphery/artifacts/contracts/lens/Quoter.sol/Quoter.json");

const tokens = [
  {
    symbol: "WETH",
    address: "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"
  },
  {
    symbol: "DAI",
    address: "0x6B175474E89094C44Da98b954EedeAC495271d0F"
  },
  {
    symbol: "LINK",
    address: "0x514910771AF9Ca656af840dff83E8264EcF986CA"
  },
  {
    symbol: "UNI",
    address: "0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984"
  },
];

use(solidity);

describe("Quoter comparison test", function () {
  this.timeout(15000);

  const uniswapQuoterAddress = "0xb27308f9F90D607463bb33eA1BeBb41C27CE5AB6";

  tokens.map((fromToken) => {
    tokens.filter((token) => token.address != fromToken.address).map((toToken) => {

      it("Should return the same price of Uniswap offchain quoter for the pair " + fromToken.symbol + " -> " + toToken.symbol, async function () {
        const Quoter = await ethers.getContractFactory("Quoter");
        const quoter = await Quoter.deploy("0x1F98431c8aD98523631AE4a59f267346ea31F984");
        await quoter.deployed();

        const uniswap = await ethers.getContractAt(abi, uniswapQuoterAddress);
        const amount = ethers.utils.parseUnits("100.0", 18);

        const expectedAmountToReceive0 =
          await uniswap.callStatic.quoteExactInputSingle(
            fromToken.address,
            toToken.address,
            3000,
            amount,
            0
          );

          console.log("Lens result" + fromToken.symbol + " -> " + toToken.symbol, ethers.utils.formatUnits(expectedAmountToReceive0, 18));

          const expectedAmountToReceive1 = await quoter.estimateMaxSwapUniswapV3(
            fromToken.address,
            toToken.address,
            amount,
            3000
          );

          console.log("Quoter result" + fromToken.symbol + " -> " + toToken.symbol, ethers.utils.formatUnits(expectedAmountToReceive1, 18));
      
          const minimum = Math.min(
            expectedAmountToReceive0,
            expectedAmountToReceive1
          );
          const maximum = Math.max(
            expectedAmountToReceive0,
            expectedAmountToReceive1
          );
      
          assert((maximum - minimum) / minimum < 0.01, "Oracle price mismatch");
      });

    });
  });
});
