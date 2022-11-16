open Types
@module("ethers") external ethers: 'a = "ethers"

//let sell_amount = "1000000000000000000" // 1 ETH
let sell_amount = "100000000000000000" // 0.1 ETH
let min_eth_amount: bigNumber = ethers["BigNumber"]["from"](. "100000000000000000") // 0.1 ETH

let gas_multiple: bigNumber = ethers["BigNumber"]["from"](. "2") // 2
let profit_threshold = 2.0 // 200% return
let stoploss_threshold = 0.1

// let discord_token = ""
let discord_token = ""
let discord_guild = ""
let discord_channel = ""

// aws
let endpoint = ""
let credentials = {
  "accessKeyId": "", 
  "secretAccessKey": ""
};

//debug
//let discord_guild = ""
//let discord_channel = ""

let eth_wallet_address = ""
let eth_wallet_private_key = ""

let infura_project_id = ""
let infura_project_secret = ""
