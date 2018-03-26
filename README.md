# Automation/Smart Contract : for distributing Lendroid tokens from a csv file


Open truffle.js and replace its content with the following code:

	module.exports = {
		networks: {
		 development: {
				host: 'localhost',
				port: 8545,
				network_id: '*', // Match any network id
				gas: 3500000,
			}, 
		 ropsten: {
				host: 'localhost',
				port: 8545,
				network_id: '3', // Match any network id
				gas: 3500000,
				gasPrice: 50000000000
			},
		},
		solc: {
			optimizer: {
				enabled: true,
				runs: 200,
			},
		},
	};

The above will allow us to run truffle migrate --network ropsten to deploy the contracts to Ropsten testnet.









Reference : https://hackernoon.com/how-to-script-an-automatic-token-airdrop-for-40k-subscribers-e40c8b1a02c6

