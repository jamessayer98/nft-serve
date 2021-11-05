const Gift = artifacts.require("Gift");

module.exports = function (deployer) {
  deployer.deploy(Gift);
};
