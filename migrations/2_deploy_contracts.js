const OslikToken = artifacts.require('OslikToken')
const Osliki = artifacts.require('Osliki')
const OslikiClassifieds = artifacts.require('OslikiClassifieds')
const fs = require('fs')

module.exports = async (deployer, network, accounts) => {
  const oslikiFoundation = accounts[0]

  await deployer.deploy(OslikToken)
  await deployer.deploy(Osliki, OslikToken.address, oslikiFoundation)
  await deployer.deploy(OslikiClassifieds, OslikToken.address, oslikiFoundation)


  // https://github.com/trufflesuite/truffle/issues/573
  const metaDataFile = `${__dirname}/../build/contracts/Osliki.json`
  const metaData = require(metaDataFile)
  metaData.networks[deployer.network_id] = {}
  metaData.networks[deployer.network_id].address = Osliki.address
  fs.writeFileSync(metaDataFile, JSON.stringify(metaData, null, 4))


  const metaDataFile2 = `${__dirname}/../build/contracts/OslikiClassifieds.json`
  const metaData2 = require(metaDataFile2)
  metaData2.networks[deployer.network_id] = {}
  metaData2.networks[deployer.network_id].address = OslikiClassifieds.address
  fs.writeFileSync(metaDataFile2, JSON.stringify(metaData2, null, 4))
}
