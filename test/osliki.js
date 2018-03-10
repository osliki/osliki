var BigNumber = require('bignumber.js');

var Osliki = artifacts.require("./Osliki.sol")

contract('Osliki', accounts => {
  let instance;

  const mockOrders = [
    ['frommm', 'tooo', '1,2,3,4', 1520707441279, 'My message'],
    ['frommm1', 'tooo1', '5,6,7,8', 1520707441299, 'My message1']
  ]

  const mockOffers = [
    [1, 'My offer message'],
    [1, 'My offer message 1']
  ]

  it("should add an order", async () => {
    instance = await Osliki.deployed()

    const res0 = await instance.addOrder(...mockOrders[0], {from: accounts[0]})
    const res1 = await instance.addOrder(...mockOrders[1], {from: accounts[1]})

    assert.equal(res0.logs[0].args.orderId.toNumber(), 0, "orderId0 wasn't 0")
    assert.equal(res1.logs[0].args.orderId.toNumber(), 1, "orderId1 wasn't 1")
  });

  it("should add an offer", async () => {
    const res0 = await instance.addOffer(...mockOffers[0], {from: accounts[3]})
    const res1 = await instance.addOffer(...mockOffers[1], {from: accounts[4]})

    assert.equal(res0.logs[0].args.offerId.toNumber(), 0, "offerId wasn't 0")
    assert.equal(res1.logs[0].args.orderId.toNumber(), 1, "orderId wasn't 1")
  });

  it("should get count of orders", async () => {
    const count = await instance.getOrdersCount()
    assert.equal(count.toNumber(), 2, "count of orders wasn't 2")
  });

  it("should get count of offers", async () => {
    const count = await instance.getOffersCount()
    assert.equal(count.toNumber(), 2, "count of offers wasn't 2")
  });

  it("should get count of offers by orderId", async () => {
    const count = await instance.getOrderOffersCount(1)
    assert.equal(count.toNumber(), 2, "count of offers by orderId=1 wasn't 2")
  });

  it("should get count of invoices", async () => {
    const count = await instance.getInvoicesCount()
    assert.equal(count.toNumber(), 0, "count of orders wasn't 0")
  });

  it("should get offer by id", async () => {
    let order = await instance.offers(1);
    order[1] = order[1].toNumber()
    assert.deepEqual(order, [accounts[4], ...mockOffers[1]], "got wrong order")
  });
});
