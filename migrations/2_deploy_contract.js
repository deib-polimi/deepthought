var DeepThought = artifacts.require("DeepThought");
var ASTRAEA = artifacts.require("ASTRAEA")

module.exports = function(deployer) {
    deployer.deploy(DeepThought);
    deployer.deploy(ASTRAEA)
};