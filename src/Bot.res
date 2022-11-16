open Types
open Constants
open Promise


// imports & init
@module external qs: 'a = "qs"

@new @module("discord.js-selfbot-v11") external client: unit => 'a = "Client"
let myClient: 'a = client()

@new @module("@aws/web3-ws-provider") external awsWebSocketProvider: (string, 'a) => 'b = "AWSWebsocketProvider"
let awsProvider = awsWebSocketProvider(
    endpoint,
    {
        "clientConfig": {
            "credentials": credentials
        }
    })

@module("ethers") external ethers: 'a = "ethers"
@new external createWallet: (privateKey, ethProvider) => 'a = "Ethers.ethers.Wallet"
@new external createContract: (address, abi, ethProvider) => 'a = "Ethers.ethers.Contract"
let myProvider: ethProvider = ethers["providers"]["WebSocketProvider"](. awsProvider)
let myWallet = createWallet(eth_wallet_private_key, myProvider)

@module("@uniswap/v2-core/build/IUniswapV2Pair.json") external abi_IUniswapV2Pair: abi = "abi"
@module("@uniswap/v2-core/build/IERC20.json") external abi_IERC20: abi = "abi"

// pure functions
let isEthPairLink: (string) => bool = (s) => {
    Js.String2.includes(s, "http") && Js.String2.includes(s, "eth")
}

let addressFromUrl: (string) => option<address> = (s) => {
    let regexResult = Js.Re.exec_(%re("/0x.{40}/"), s)
    switch regexResult{
        | None => None
        | Some(result) => {
            let pairAddress: option<address> = Js.Nullable.toOption(Js.Re.captures(result)[0])
            switch pairAddress {
                | None => None
                | Some(pairAddress) => Some(pairAddress)
            }
        }
    }
}

let addressFromMessage: (string) => option<address> = (msg: string) => {
    let splitMessage: array<string> = Js.String2.split(msg, " ")
    switch splitMessage {
        | [] => None
        | [_] => None
        | many if many[0] == "<@&882669674771406889>" => {
            let pairLinks = Js.Array2.filter(many, isEthPairLink)
            switch pairLinks {
                | [] => None
                | [one] => addressFromUrl(one)
                | many => addressFromUrl(many[0])
            }
        }
        | _ => None
    }
}

// async view functions
let tokenFromPair: (address) => Promise.t<address> = (pairAddress: address) => {
    let pairContract = createContract(pairAddress, abi_IUniswapV2Pair, myProvider)
    pairContract["token0"](.)
    ->then(token0 => {
        resolve(token0)
    })
}

let zrxQuery: (~buyToken: addressLike, ~sellToken: addressLike=?, ~sellAmount: string=?, ~requestType: zrxRequestType=?, unit) => Promise.t<zrxResponse> =
    (~buyToken, ~sellToken=TokenName("ETH"), ~sellAmount=sell_amount, ~requestType=Price, ()) => {
        let body = {
            "buyToken": switch buyToken {
                | TokenName(name) => name
                | HexAddress(address) => address
            },
            "sellToken": switch sellToken {
                | TokenName(name) => name
                | HexAddress(address) => address
            },
            "sellAmount": sellAmount,
        }
        let queryString = switch qs["stringify"](. body) {
            | None => ""
            | Some(body) => body
        } 
        let request = switch requestType {
            | Price => "https://api.0x.org/swap/v1/price?" ++ queryString
            | Quote => "https://api.0x.org/swap/v1/quote?" ++ queryString
        }
        Axios.get(request)
        ->then(response => {
            switch response["status"] {
                | 200 => {
                    let data: zrxResponse = response["data"]
                    resolve(data)
                }
                | _ => {
                    reject(raise(InvalidResponse))
                }
            }
        })->catch(error => {
            Js.log(error)
            reject(raise(InvalidResponse))
        })
    }

let getTokenBalance: (address) => Promise.t<bigNumber> = (tokenAddress: address) => {
    let tokenContract = createContract(tokenAddress, abi_IERC20, myProvider)
    tokenContract["balanceOf"](. eth_wallet_address)
    ->then((balance: bigNumber) => {
        Js.log("token balance of " ++ tokenAddress ++ ": " ++ balance.toString(.))
        resolve(balance)
    })
}

let getEthBalance: unit => Promise.t<bigNumber> = () => {
    myWallet["getBalance"](.)
    ->then((balance: bigNumber) => {
        Js.log("eth balance: " ++ balance.toString(.))
        resolve(balance)
    })
}

// async do functions
let approve: (~tokenAddress: address, ~quote: zrxResponse) => Promise.t<transactionReceipt> = (~tokenAddress: address, ~quote: zrxResponse) => {
    let allowanceTarget = quote.allowanceTarget
    let amount = quote.sellAmount

    let targetContract = createContract(tokenAddress, abi_IERC20, myProvider)
    let contractWithSigner = targetContract["connect"](. myWallet)
    contractWithSigner["approve"](. allowanceTarget, amount)
    ->then(tx => {
        tx["wait"](.)
        ->then(receipt => {
            Js.log("approve receipt: " ++ receipt)
            resolve(receipt)
        })
    })
}

let sendTransaction: (zrxResponse) => Promise.t<transactionReceipt> = (quote: zrxResponse) => {
    let gas = ethers["BigNumber"]["from"](. quote.gasPrice)
    let gas = gas.mul(. gas_multiple)
    let transaction = {
        "to": ethers["utils"]["getAddress"](. quote.to),
        "data": quote.data,
        "value": quote.value,
        // "gasLimit": quote.gas,
        "gasPrice": gas.toString(.)
    }
    myWallet["sendTransaction"](. transaction)
    ->then(tx => {
        tx["wait"](.)
        ->then(receipt => {
            Js.log("transaction receipt: " ++ receipt)
            resolve(receipt)
        })
    })
}

// loops
let rec mainLoop: (~tokenAddress: address, ~method: sellMethod, ~state: attemptState) => Promise.t<attemptState> = (~tokenAddress: address, ~method: sellMethod, ~state: attemptState) => {
    switch state {
        | First => {
            getEthBalance()
            ->then(ethBalance => {
                if ethBalance.lt(. min_eth_amount) {
                    resolve(Canceled)
                } else {
                    Js.log("buying " ++ tokenAddress)
                    zrxQuery(~buyToken=HexAddress(tokenAddress), ~sellToken=TokenName("ETH"), ~sellAmount=sell_amount, ~requestType=Quote, ())
                    ->then(quote_0 => {
                        let price_0 = 1.0/.Js.Float.fromString(quote_0.price)
                        sendTransaction(quote_0)
                        ->then(buyReceipt => {
                            getTokenBalance(tokenAddress)
                            ->then(tokenBalance => {
                                zrxQuery(~buyToken=TokenName("ETH"), ~sellToken=HexAddress(tokenAddress), ~sellAmount=tokenBalance.toString(.), ~requestType=Quote, ())
                                ->then(quote_approve => {
                                    Js.log("approving " ++ tokenBalance.toString(.) ++ " " ++ tokenAddress)
                                    approve(~tokenAddress=tokenAddress, ~quote=quote_approve)
                                    ->then(_ =>
                                        mainLoop(~tokenAddress=tokenAddress, ~method=method, ~state=Ongoing({price_0: price_0, price_max: price_0, tokenBalance: tokenBalance.toString(.), buyReceipt: buyReceipt}))
                                    )->catch(error => {
                                        Js.log(error)
                                        resolve(Canceled)
                                    })
                                })->catch(error => {
                                    Js.log(error)
                                    resolve(Canceled)
                                })
                            })->catch(error => {
                                Js.log(error)
                                resolve(Canceled)
                            })
                        })->catch(error => {
                            Js.log(error)
                            resolve(Canceled)
                        })
                    })->catch(error=> {
                        Js.log(error)
                        resolve(Canceled)
                    })
                }
            })->catch(error => {
                Js.log(error)
                resolve(Canceled)
            })
        }
        | Canceled => resolve(Canceled)
        | Success(buyReceipt, sellReceipt) => resolve(Success(buyReceipt, sellReceipt))
        | Ongoing({price_0, price_max, tokenBalance, buyReceipt}) => {
            zrxQuery(~buyToken=TokenName("ETH"), ~sellToken=HexAddress(tokenAddress), ~sellAmount=tokenBalance, ~requestType=Quote, ())
            ->then(quote_1 => {
                let price_1 = Js.Float.fromString(quote_1.price)
                let threshold = price_0 *. profit_threshold
                let price_max = price_max > price_1 ? price_max : price_1
                let sell = switch method {
                    | Threshold => price_1 > threshold
                    | Stoploss =>  price_1 < price_max *. (1.0 -. stoploss_threshold)
                }
                if sell {
                    Js.log("selling " ++ tokenAddress)
                    zrxQuery(~buyToken=TokenName("ETH"), ~sellToken=HexAddress(tokenAddress), ~sellAmount=tokenBalance, ~requestType=Quote, ())
                    ->then(quote_sell => {
                        sendTransaction(quote_sell)
                        ->then(sellReceipt => {
                            resolve(Success(buyReceipt, sellReceipt))
                        })->catch(error => {
                            Js.log(error)
                            resolve(Canceled)
                        })
                    })->catch(error => {
                        Js.log(error)
                        resolve(Canceled)
                    })
                } else {
                    mainLoop(~tokenAddress=tokenAddress, ~method=method, ~state=Ongoing({price_0: price_0, price_max: price_max, tokenBalance: tokenBalance, buyReceipt: buyReceipt}))
                }
            })->catch(error => {
                Js.log(error)
                resolve(Canceled)
            })
        }
    }
}

// runtime bindings
myClient["on"](. "ready", () => {
    Js.log("Logged in as " ++ myClient["user"]["tag"])
})

myClient["on"](. "message", (msg): Promise.t<attemptState> => {
    if msg["guild"]["id"] != discord_guild || msg["channel"]["id"] != discord_channel { resolve(Canceled) }
    else {
        Js.log(msg["content"])
        switch addressFromMessage(msg["content"]) {
            | None => resolve(Canceled)
            | Some(pairAddress) => {
                tokenFromPair(pairAddress)
                ->then(tokenAddress => {
                    mainLoop(~tokenAddress=tokenAddress, ~method=Threshold, ~state=First)
                })->catch(_ => {
                    resolve(Canceled)
                })
            }
        }
    }
})

myClient["login"](. discord_token)