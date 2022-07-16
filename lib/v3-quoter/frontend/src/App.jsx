import React, { useEffect, useState } from 'react';
import { ethers } from 'ethers';
import { useContractLoader, useUserProviderAndSigner } from "eth-hooks";
import useContractConfig from "./hooks/useContractConfig";
import './App.css';
import { TokenList } from "./tokens.js";

const {
  abi,
} = require("@uniswap/v3-periphery/artifacts/contracts/lens/Quoter.sol/Quoter.json");

function App() {
  const [ err, setErr ] = useState("");
  const [ buyFlag, setBuyFlag ] = useState(false);
  const [ amount, setAmount ] = useState(0.0);
  const [ quote, setQuote ] = useState("");
  const [ loading, setLoading ] = useState(false);
  const [ sourceToken, setSourceToken ] = useState();
  const [ destToken, setDestToken ] = useState();
  const [ fee, setFee ] = useState();

  const [ provider, setProvider ] = useState();
  const chainId = 42;
  const config = useContractConfig();
  const providerAndSigner = useUserProviderAndSigner(provider)
  const contracts = useContractLoader(providerAndSigner.signer, config, chainId);

  const tokens = TokenList.kovan;
  const poolFees = [ 500, 3000, 10000 ];

  useEffect( () => {
    const loadProvider = async() => {
      const provider = new ethers.providers.Web3Provider(window.ethereum);
      const userAccount = await window.ethereum.request({ method: 'eth_requestAccounts' });
      setProvider(provider);
    }
    loadProvider();
  }, []);

  const setErrorAlert = (text) => {
    setErr(text);
    setTimeout(() => {
      setErr("");
   }, 2000);
  }

  const setQuoteAlert = (text) => {
    setQuote(text);
    setTimeout(() => {
      setQuote("");
   }, 10000);
  }

  const getQuote = async () => {
    if(amount <= 0) {
      setErrorAlert("Amount cannot be 0 or negative");

      return;
    }

    setLoading(true);

    try {

      const exists = await contracts.Quoter.doesPoolExist(sourceToken, destToken);
      
      if(!exists) {
        setErrorAlert("Pool does not exist");
      } else {
        const formattedAmount = ethers.utils.parseEther(amount);
        const uniswap = new ethers.Contract("0xb27308f9F90D607463bb33eA1BeBb41C27CE5AB6", abi, provider);

        let expectedAmount = 0;
        let expectedAmountUniswap = 0;
        
        if(!buyFlag) {
          // Sell
          expectedAmount = await contracts.Quoter.estimateMaxSwapUniswapV3(sourceToken, destToken, formattedAmount, fee);
          expectedAmountUniswap = await uniswap.callStatic.quoteExactInputSingle(
            sourceToken,
            destToken,
            fee,
            formattedAmount,
            0
          );
        } else {
          // Buy
          expectedAmount = await contracts.Quoter.estimateMinSwapUniswapV3(destToken, sourceToken, formattedAmount, fee);
          expectedAmountUniswap = await uniswap.callStatic.quoteExactOutputSingle(
            sourceToken,
            destToken,
            fee,
            formattedAmount,
            0
          );
        }

        const text = `You would ${buyFlag ? "give" : "receive"} ${ethers.utils.formatUnits(expectedAmount, 18)} tokens. Uniswap lens quoter returned ${ethers.utils.formatUnits(expectedAmountUniswap, 18)} tokens.`;
        setQuoteAlert(text);
      }

    } catch(e) {
      console.error("Error occurred");
      console.error(e);
      setErrorAlert("Internal Error");
    }

    setLoading(false);
  };

  return (
    <main className="text-center form-signin">
      <form>
        <img className="mb-4" src="https://upload.wikimedia.org/wikipedia/commons/thumb/e/e7/Uniswap_Logo.svg/1026px-Uniswap_Logo.svg.png" alt="Uniswap logo" width="72" height="72" />
        <h1 className="mb-3 h3 fw-normal">Uniswap V3 Quoter</h1>

        <div className="mb-3 btn-group" role="group">
          <input type="radio" className="btn-check" name="btnradio" id="buy" onChange={()=>setBuyFlag(true)} autoComplete="off" checked={buyFlag} />
          <label className="btn btn-outline-primary" htmlFor="buy">BUY</label>
        
          <input type="radio" className="btn-check" name="btnradio" id="sell" onChange={()=>setBuyFlag(false)} autoComplete="off" checked={!buyFlag} />
          <label className="btn btn-outline-primary" htmlFor="sell">SELL</label>
        </div>
        <div className="form-floating">
          <select className="form-select" id="floatingSourceToken" value={sourceToken} onChange={(e) => setSourceToken(e.target.value)}>
            <option>Choose...</option>
            { tokens.filter((token) => token.address !== destToken).map((token, idx) => 
              <option value={token.address} key={idx}>{token.symbol}</option>
            )}
          </select>
          <label htmlFor="floatingSourceToken">Source Token</label>
        </div>
        <div className="form-floating">
          <select className="form-select" id="floatingDestToken" value={destToken} onChange={(e) => setDestToken(e.target.value)}>
            <option>Choose...</option>
            { tokens.filter((token) => token.address !== sourceToken).map((token, idx) => 
              <option value={token.address} key={idx}>{token.symbol}</option>
            )}
          </select>
          <label htmlFor="floatingDestToken">Destination Token</label>
        </div>
        <div className="form-floating">
          <input type="number" className="form-control" id="floatingAmount" value={amount} onChange={(e) => setAmount(e.target.value)} />
          <label htmlFor="floatingAmount">
            {!buyFlag &&
              <>
                Amount in source tokens
              </>
            }
            {buyFlag &&
              <>
                Amount in destination tokens
              </>
            }
          </label>
        </div>
        <div className="form-floating">
          <select className="form-select" id="floatingFee" onChange={(e) => setFee(e.target.value)}>
          <option>Choose...</option>
          { poolFees.map((fee, idx) => 
              <option value={fee} key={idx}>{(fee / 10000).toFixed(2) + '%'}</option>
            )}
          </select>
          <label htmlFor="floatingFee">Fee</label>
        </div>

        <br />

        {!loading &&
          <button className="w-100 btn btn-lg btn-primary" type="button" onClick={()=>getQuote()}>Quote</button>
        }
        {loading &&
          <button className="w-100 btn btn-lg btn-primary" type="button" disabled>
            <span className="spinner-border spinner-border-sm" role="status" aria-hidden="true"></span>&nbsp;Loading...
          </button>
        }
        { quote !== "" &&
          <div className="alert alert-primary text-wrap" role="alert">{quote}</div>
        }
        { err !== "" &&
          <div className="alert alert-danger text-wrap" role="alert">{err}</div>
        }
        <p className="mt-5 mb-3 text-muted">Made for Unicode Hack - v0.0.4</p>
      </form>
    </main>
  );
}

export default App;
