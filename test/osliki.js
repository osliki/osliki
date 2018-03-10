var Osliki = artifacts.require("./Osliki.sol")

const mockOrders = [
  ["frommm", "tooo", [1, 1, 3, 5], "My message"],
  ["frommm1", "tooo1", [0, 1, 6, 2], "My message1"]
]


contract('Osliki', accounts => {
  let instance;

  it("should add an order", async () => {
    instance = await Osliki.deployed()

    const res0 = await instance.addOrder(...mockOrders[0], {from: accounts[0]})
    const res1 = await instance.addOrder(...mockOrders[1], {from: accounts[1]})

    assert.equal(res0.logs[0].args.orderId.toNumber(), 0, "orderId0 wasn't 0")
    assert.equal(res1.logs[0].args.orderId.toNumber(), 1, "orderId1 wasn't 1")
  });

  it("should add an offer", async () => {
    const res0 = await instance.addOffer(1, "My offer message", {from: accounts[3]})
    const res1 = await instance.addOffer(1, "My offer message 1", {from: accounts[4]})

    assert.equal(res0.logs[0].args.offerId.toNumber(), 0, "offerId wasn't 0")
    assert.equal(res0.logs[0].args.orderId.toNumber(), 1, "orderId wasn't 1")
  });

  it("should get all offers by orderId", async () => {
    const orderOffers = await instance.getOrderOffers(1)

  });
});
