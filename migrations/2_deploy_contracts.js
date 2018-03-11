var OslikToken = artifacts.require('./OslikToken.sol');
var Osliki = artifacts.require('./Osliki.sol');

module.exports = async (deployer, network, accounts) => {
  await deployer.deploy(OslikToken);
  deployer.deploy(Osliki, OslikToken.address, accounts[8]);
};
