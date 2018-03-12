//const BigNumber = require('bignumber.js');

const Osliki = artifacts.require('./Osliki.sol')

const allBigNumberToNumber = (arr) => {
  return arr.map(el => (el.toNumber ? el.toNumber() : el))
}

const EnumCurrency = {
  ETH: 0,
  OSLIK: 1,
}

const mockOrders = [
  ['frommm', 'tooo', '1,2,3,4', 1520707441279, 'My message'],
  ['frommm1', 'tooo1', '5,6,7,8', 1520707441299, 'My message1'],
]

const mockOffers = [
  [1, 'My offer message'],
  [1, 'My offer message 1'],
]

const mockInvoices = [
  [1, web3.toWei(1, 'ether'), web3.toWei(1, 'ether'), EnumCurrency.ETH],
  [1, web3.toWei(1, 'ether'), web3.toWei(1, 'ether'), EnumCurrency.OSLIK],
]


/*
Osliki.deployed().then((res) => {
  //res.oslikToken().then((res) =>{ console.log('dsdsd'); console.dir(res)}).catch((err)=>console.dir(err))
  res.oslikiFoundation().then((res) => { console.log('dsdsd'); console.dir(res)}).catch((err)=>console.dir(err))
//console.dir(res)
//console.log(res.oslikToken())
});
*/
contract('Osliki', accounts => {
  let instance;

  it("should add a new order", async () => {
    instance = await Osliki.deployed()

    const res0 = await instance.addOrder(...mockOrders[0], {from: accounts[0]})
    const res1 = await instance.addOrder(...mockOrders[1], {from: accounts[1]})

    assert.equal(res0.logs[0].args.orderId.toNumber(), 0, "orderId0 wasn't 0")
    assert.equal(res1.logs[0].args.orderId.toNumber(), 1, "orderId1 wasn't 1")
  })

  it("should add a new offer", async () => {
    const res0 = await instance.addOffer(...mockOffers[0], {from: accounts[3]})
    const res1 = await instance.addOffer(...mockOffers[1], {from: accounts[4]})

    assert.equal(res0.logs[0].args.offerId.toNumber(), 0, "offerId wasn't 0")
    assert.equal(res0.logs[0].args.orderId.toNumber(), 1, "orderId wasn't 0")

    assert.equal(res1.logs[0].args.offerId.toNumber(), 1, "offerId wasn't 1")
    assert.equal(res1.logs[0].args.orderId.toNumber(), 1, "orderId wasn't 1")
  })

  it("should add a new invoice", async () => {
    const res0 = await instance.addInvoice(...mockInvoices[0], {from: accounts[3]})
    const res1 = await instance.addInvoice(...mockInvoices[1], {from: accounts[4]})

    assert.equal(res0.logs[0].args.invoiceId.toNumber(), 1, "invoiceId wasn't 0")
    assert.equal(res0.logs[0].args.orderId.toNumber(), 1, "orderId wasn't 0")

    assert.equal(res1.logs[0].args.invoiceId.toNumber(), 2, "invoiceId wasn't 1")
    assert.equal(res1.logs[0].args.orderId.toNumber(), 1, "orderId wasn't 1")
  })

  it("should get invoice by id", async () => {
    let invoice = await instance.invoices(2)

    invoice = allBigNumberToNumber(invoice)
    invoice[2] = invoice[2].toString()
    invoice[3] = invoice[3].toString()
    invoice.splice(7) // remove createdAt and updatedAt

    assert.deepEqual(invoice, [
        accounts[4],
        ...mockInvoices[1],
        '0x0000000000000000000000000000000000000000000000000000000000000000',
        0
    ], "got wrong invoice")
  })

  it("should get order by id", async () => {
    let order = await instance.orders(1)

    order = allBigNumberToNumber(order)
    order.splice(9) // remove createdAt and updatedAt

    assert.deepEqual(order, [
      accounts[1],
      ...mockOrders[1],
      '0x0000000000000000000000000000000000000000',
      0,
      0,
    ], "got wrong order")
  })

  it("should get offer by id", async () => {
    let offer = await instance.offers(1)

    offer = allBigNumberToNumber(offer)

    assert.deepEqual(offer, [accounts[4], ...mockOffers[1]], "got wrong offer")
  })

  it("should get count of orders", async () => {
    const count = await instance.getOrdersCount()
    assert.equal(count.toNumber(), 2, "count of orders wasn't 2")
  })

  it("should get count of offers", async () => {
    const count = await instance.getOffersCount()
    assert.equal(count.toNumber(), 2, "count of offers wasn't 2")
  })

  it("should get count of offers by orderId", async () => {
    const count = await instance.getOrderOffersCount(1)
    assert.equal(count.toNumber(), 2, "count of offers by orderId=1 wasn't 2")
  })

  it("should get count of invoices", async () => {
    const count = await instance.getInvoicesCount()
    assert.equal(count.toNumber(), 3, "count of invoices wasn't 1")
  })
})
