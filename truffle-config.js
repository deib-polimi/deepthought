module.exports = {
  networks: {
    development: {
      // host and port should match the RPC Server address
      // as seen in Ganache
      host: "127.0.0.1",
      port: 7545,
      network_id: "*"
    }
  },
  compilers: {
    solc: {
      version: "^0.8.0",
      settings: {
        optimizer: {
        enabled: true, // Default: false
        runs: 1500 // Default: 200
        }
      }
    }
  }
};