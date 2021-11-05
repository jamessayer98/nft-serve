const GameItem = artifacts.require("GameItem");

module.exports = async function (deployer,network,accounts) {
  await deployer.deploy(GameItem);
  const d = await GameItem.deployed()
  await d.awardItem(accounts[0],"https://game.example/item-id-8u5h2m.json")
  await d.awardItem(accounts[0],"https://game.example/item-id-8u5h2m.json")
  await d.awardItem(accounts[0],"https://game.example/item-id-8u5h2m.json")
  await d.awardItem(accounts[0],"https://game.example/item-id-8u5h2m.json")
  await d.awardItem(accounts[0],"https://game.example/item-id-8u5h2m.json")
  await d.awardItem(accounts[0],"https://game.example/item-id-8u5h2m.json")
  await d.awardItem(accounts[0],"https://game.example/item-id-8u5h2m.json")
  await d.awardItem(accounts[0],"https://game.example/item-id-8u5h2m.json")
  await d.awardItem(accounts[0],"https://game.example/item-id-8u5h2m.json")
  await d.awardItem(accounts[0],"https://game.example/item-id-8u5h2m.json")
};
