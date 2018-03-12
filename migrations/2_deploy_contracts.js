const Osliki = artifacts.require('Osliki')
const OslikToken = artifacts.require('OslikToken')
const fs = require('fs')

module.exports = async (deployer, network, accounts) => {
  await deployer.deploy(OslikToken)

  await deployer.deploy(Osliki, OslikToken.address, accounts[8])

  // https://github.com/trufflesuite/truffle/issues/573
  const metaDataFile = `${__dirname}/../build/contracts/Osliki.json`
  const metaData = require(metaDataFile)
  metaData.networks[deployer.network_id] = {}
  metaData.networks[deployer.network_id].address = Osliki.address
  fs.writeFileSync(metaDataFile, JSON.stringify(metaData, null, 4))
}
