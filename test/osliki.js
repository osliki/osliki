const BigNumber = require('bignumber.js');

const Osliki = artifacts.require('./Osliki.sol')
const OslikToken = artifacts.require('./OslikToken.sol')

const allBigNumberToNumber = (arr) => {
  return arr.map(el => (el.toNumber ? el.toNumber() : el))
}

async function verifyThrows(pred, message) {
  let e;
  try {
    await pred();
  } catch (ex) {
    e = ex;
  }
  assert.throws(() => {
    if (e) { throw e; }
  }, message);
}

function findEvent(eventName, logs) {
  return logs.find((log) => log.event === eventName)
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
  ['My offer message'],
  ['My offer message 1'],
]

const mockInvoices = [ // prepayment, deposit, valid, currency
  [web3.toWei(0.7, 'ether'), web3.toWei(7, 'ether'), 500, EnumCurrency.OSLIK],
  [web3.toWei(0.3, 'ether'), web3.toWei(3, 'ether'), 500, EnumCurrency.ETH],
]

contract('Osliki', accounts => {
  let osliki;
  let oslikToken;
  let oslikTokenFounder;

  it("should set contract's instances", async () => {
    osliki = await Osliki.deployed()
    const oslikTokenAddr = await osliki.oslikToken()
    oslikToken = await OslikToken.at(oslikTokenAddr)
    oslikTokenFounder = await oslikToken.founder()
  })

  it("should add new orders", async () => {
    const res0 = await osliki.addOrder(...mockOrders[0], {from: accounts[0]})
    const res1 = await osliki.addOrder(...mockOrders[1], {from: accounts[1]})

    assert.equal(res0.logs[0].args.orderId.toNumber(), 0, "orderId0 wasn't 0")
    assert.equal(res1.logs[0].args.orderId.toNumber(), 1, "orderId1 wasn't 1")
  })

  it("should add new offers", async () => {
    const res0 = await osliki.addOffer(0, ...mockOffers[0], {from: accounts[3]})
    const res1 = await osliki.addOffer(1, ...mockOffers[1], {from: accounts[4]})

    assert.equal(res0.logs[0].args.offerId.toNumber(), 0, "offerId wasn't 0")
    assert.equal(res0.logs[0].args.orderId.toNumber(), 0, "orderId wasn't 0")

    assert.equal(res1.logs[0].args.offerId.toNumber(), 1, "offerId wasn't 1")
    assert.equal(res1.logs[0].args.orderId.toNumber(), 1, "orderId wasn't 1")
  })

  it("should add new invoices", async () => {
    const res0 = await osliki.addInvoice(0, ...mockInvoices[0], {from: accounts[3]})
    const res1 = await osliki.addInvoice(1, ...mockInvoices[1], {from: accounts[4]})

    assert.equal(res0.logs[0].args.invoiceId.toNumber(), 1, "wasn't 1 for invoiceId") // invoices[0] is always preassigned as empty
    assert.equal(res0.logs[0].args.orderId.toNumber(), 0, "wasn't 0 for orderId")

    assert.equal(res1.logs[0].args.invoiceId.toNumber(), 2, "wasn't 2 for invoiceId")
    assert.equal(res1.logs[0].args.orderId.toNumber(), 1, "wasn't 1 for orderId")
  })


  /*** PAYMENTS IN OSLIK ***/
  it("should fail OSLIK payment with not enough allowance", async () => {
    const invoiceId = 1 // mockInvoices[0] = [web3.toWei(0.7, 'ether'), web3.toWei(7, 'ether'), EnumCurrency.OSLIK],

    await verifyThrows(async () => {
      const res = await osliki.pay(invoiceId, '', {from: accounts[0]})
    }, /revert/);

  })

  it("should process OSLIK payment", async () => {
    const balanceContractBefore = await oslikToken.balanceOf(osliki.address) // balance before payment
    const balanceCarrierBefore = await oslikToken.balanceOf(accounts[3]) // balance before payment

    const invoiceId = 1 // mockInvoices[0] = [web3.toWei(0.7, 'ether'), web3.toWei(7, 'ether'), EnumCurrency.OSLIK],

    await oslikToken.approve(oslikTokenFounder, web3.toWei(5000, 'ether'), {from: oslikTokenFounder})
    await oslikToken.transferFrom(oslikTokenFounder, accounts[0], web3.toWei(5000, 'ether'), {from: oslikTokenFounder})

    await oslikToken.approve(osliki.address, web3.toWei(7.7, 'ether'), {from: accounts[0]})

    const res = await osliki.pay(invoiceId, '', {from: accounts[0]})

    const balanceContractAfter = await oslikToken.balanceOf(osliki.address)
    const balanceCarrierAfter = await oslikToken.balanceOf(accounts[3])

    assert.equal(findEvent('EventPayment', res.logs).args.invoiceId.toNumber(),
      invoiceId,
      "EventPayment invoiceId wasn't " + invoiceId)

    assert.equal(balanceContractAfter.minus(balanceContractBefore).toString(), web3.toWei(7, 'ether').toString(), "contract balance was wrong")
    assert.equal(balanceCarrierAfter.minus(balanceCarrierBefore).toString(), web3.toWei(0.7, 'ether').toString(), "carrier balance was wrong")
  })


  /*** PAYMENTS IN  ETH ***/
  it("should fail ETH payment from another customer", async () => {
    const invoiceId = 2 //2 = mockInvoices[1]

    await verifyThrows(async () => {
      await osliki.pay(invoiceId, '', {from: accounts[2], value: web3.toWei(3.3, 'ether')})
    }, /revert/);

  })

  it("should fail ETH payment with not enough value", async () => {
    const invoiceId = 2 //2 = mockInvoices[1]

    await verifyThrows(async () => {
      await osliki.pay(invoiceId, '', {from: accounts[1], value: web3.toWei(3.29999, 'ether')})
    }, /revert/);
  })

  it("should transfer ETH prepayment to the carrier", async () => {
    const balanceContractBefore = await web3.eth.getBalance(osliki.address) // balance before payment
    const balanceCarrierBefore = await web3.eth.getBalance(accounts[4])

    const invoiceId = 2 //2 = mockInvoices[1]
    const res = await osliki.pay(invoiceId, '', {from: accounts[1], value: web3.toWei(3.3, 'ether')})

    const fees = await osliki.fees()
    const fee = web3.toWei(new BigNumber('0.003'), 'ether')

    const balanceContractAfter = await web3.eth.getBalance(osliki.address)
    const balanceCarrierAfter = await web3.eth.getBalance(accounts[4])

    assert.equal(res.logs[0].event + res.logs[0].args.invoiceId.toNumber(),
      'EventPayment' + invoiceId,
      "EventPayment invoiceId wasn't " + invoiceId)

    assert.equal(fees.toString(), fee.toString(), "wrong amount of fee")

    assert.equal(balanceContractAfter.minus(balanceContractBefore).toString(), new BigNumber(mockInvoices[1][1]).plus(fee).toString(), "wrong balance after adding fee")
    assert.equal(balanceCarrierAfter.minus(balanceCarrierBefore).toString(), new BigNumber(mockInvoices[1][0]).minus(fee).toString(), "carrier balance was wrong")
  })

  it("should fail duplicate payment", async () => {
    const invoiceId = 2 //2 = mockInvoices[1]

    await verifyThrows(async () => {
      await osliki.pay(invoiceId, '', {from: accounts[1], value: web3.toWei(3.3, 'ether')})
    }, /revert/)
  })


  /*** GETTERS ***/
  it("should get order by id", async () => {
    let order = await osliki.orders(1)

    order = allBigNumberToNumber(order)
    order.splice(9) // remove createdAt and updatedAt

    assert.deepEqual(order, [
      accounts[1],
      ...mockOrders[1],
      //'0x0000000000000000000000000000000000000000',
      accounts[4],
      2, // invoiceId
      1,
    ], "got wrong order")
  })

  it("should get offer by id", async () => {
    let offer = await osliki.offers(1)

    offer = allBigNumberToNumber(offer)

    assert.deepEqual(offer, [accounts[4], 1, ...mockOffers[1]], "got wrong offer")
  })

  it("should get invoice by id", async () => {
    let invoice = await osliki.invoices(2)

    invoice = allBigNumberToNumber(invoice)
    invoice[2] = invoice[2].toString()
    invoice[3] = invoice[3].toString()
    invoice.splice(8) // remove createdAt and updatedAt

    assert.deepEqual(invoice, [
        accounts[4],
        1,
        ...mockInvoices[1],
        '0x0000000000000000000000000000000000000000000000000000000000000000',
        1
    ], "got wrong invoice")
  })

  it("should get count of orders", async () => {
    const count = await osliki.getOrdersCount()
    assert.equal(count.toNumber(), 2, "count of orders wasn't 2")
  })

  it("should get count of offers", async () => {
    const count = await osliki.getOffersCount()
    assert.equal(count.toNumber(), 2, "count of offers wasn't 2")
  })

  it("should get count of offers by orderId", async () => {
    const count = await osliki.getOrderOffersCount(1)
    assert.equal(count.toNumber(), 1, "count of offers by orderId=1 wasn't 1")
  })

  it("should get count of invoices", async () => {
    const count = await osliki.getInvoicesCount()
    assert.equal(count.toNumber(), 3, "count of invoices wasn't 1")
  })
})
