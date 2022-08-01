var NFT = artifacts.require("./NFT.sol");
var Marketplace = artifacts.require("./Marketplace.sol");
var Generator = artifacts.require("./NFTGenerator.sol");
var Migrations = artifacts.require("./Migrations.sol");

module.exports = function(deployer) {
  deployer.deploy(Marketplace);
  deployer.deploy(NFT_URIStorage, "NFT Marketplace", "NMP", Marketplace.address);
  deployer.deploy(NFTGenerator, Marketplace.address);
  deployer.deploy(Migrations);
};
