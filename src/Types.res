// types
type rec bigNumber = {
    add: (. bigNumber) => bigNumber,
    sub: (. bigNumber) => bigNumber,
    mul: (. bigNumber) => bigNumber,
    div: (. int) => bigNumber,
    mod: (. int) => bigNumber,
    pow: (. int) => bigNumber,
    abs: (. ()) => bigNumber,
    eq: (. bigNumber) => bool,
    lt: (. bigNumber) => bool,
    lte: (. bigNumber) => bool,
    gt: (. bigNumber) => bool,
    gte: (. bigNumber) => bool,
    isZero: (. ()) => bool,
    toNumber: (. ()) => float,
    toString: (. ()) => string,
    toHexString: (. ()) => string
}

type ethProvider
type abi

type transactionReceipt = string
type address = string
type privateKey = string


type addressLike = HexAddress(address) | TokenName(string)

type zrxRequestType = Price | Quote
type zrxSource = {
    name: string,
    proportion: string
}
type zrxResponse = {
    price: string,
    guaranteedPrice: string,
    to: string,
    data: string,
    value: string,
    gasPrice: string,
    gas: string,
    estimatedGas: string,
    protocolFee: string,
    minimumProtocolFee: string,
    buyAmount: string,
    sellAmount: string,
    sources: array<zrxSource>,
    buyTokenAddress: string,
    sellTokenAddress: string,
    allowanceTarget: string
}
exception InvalidResponse

type attemptState = 
    | First 
    | Ongoing({price_0: float, price_max: float, tokenBalance: string, buyReceipt: transactionReceipt}) 
    | Canceled 
    | Success(transactionReceipt, transactionReceipt)
type sellMethod = Threshold | Stoploss
