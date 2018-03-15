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

const gasPrice = web3.toWei(2, 'gwei')

const EnumCurrency = {
  ETH: 0,
  OSLIK: 1,
}

const mockOrders = [
  ['frommm', 'tooo', '1,2,3,4', 2530707441, 'My message'],
  ['frommm1', 'tooo1', '5,6,7,8', 2530707441, 'My message1'],
]

const mockOffers = [
  ['My offer message'],
  ['My offer message 1'],
]

const mockInvoices = [ // prepayment, deposit, valid, currency
  [web3.toWei(0.7, 'ether'), web3.toWei(7, 'ether'), 2530707441, EnumCurrency.OSLIK],
  [web3.toWei(0.3, 'ether'), web3.toWei(3, 'ether'), 2530707441, EnumCurrency.ETH],
]

const depositHashes = [
  ['1234', web3.sha3('1234')]
]

contract('Osliki', accounts => {
  let osliki;
  let oslikToken;
  let oslikTokenFounder;
  let oslikiFoundation;

  it("should set contract's instances", async () => {
    osliki = await Osliki.deployed()
    const oslikTokenAddr = await osliki.oslikToken()
    oslikToken = await OslikToken.at(oslikTokenAddr)
    oslikTokenFounder = await oslikToken.founder()
    oslikiFoundation = await osliki.oslikiFoundation()
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

  it("should fail fulfill order (in OSLIK) from another carrier", async () => {
    const invoiceId = 1 // mockInvoices[0] = [web3.toWei(0.7, 'ether'), web3.toWei(7, 'ether'), EnumCurrency.OSLIK],

    await verifyThrows(async () => {
      const res = await osliki.fulfill(invoiceId, '', {from: accounts[4]})
    }, /revert/);
  })

  it("should fulfill order (in OSLIK)", async () => {
    const balanceContractBefore = await oslikToken.balanceOf(osliki.address) // balance before payment
    const balanceCarrierBefore = await oslikToken.balanceOf(accounts[3]) // balance before payment

    const invoiceId = 1 // mockInvoices[0] = [web3.toWei(0.7, 'ether'), web3.toWei(7, 'ether'), EnumCurrency.OSLIK],

    const res = await osliki.fulfill(0, '', {from: accounts[3]})

    const balanceContractAfter = await oslikToken.balanceOf(osliki.address)
    const balanceCarrierAfter = await oslikToken.balanceOf(accounts[3])

    assert.equal(findEvent('EventFulfill', res.logs).args.orderId.toNumber(),
      0,
      "EventFulfill orderId wasn't 0")

    assert.equal(balanceContractBefore.minus(balanceContractAfter).toString(), web3.toWei(7, 'ether').toString(), "contract balance was wrong")
    assert.equal(balanceCarrierAfter.minus(balanceCarrierBefore).toString(), web3.toWei(7, 'ether').toString(), "carrier balance was wrong")
  })

  it("should refund order (in OSLIK)", async () => {
    const invoiceId = 1 // mockInvoices[0] = [web3.toWei(0.7, 'ether'), web3.toWei(7, 'ether'), EnumCurrency.OSLIK],
    const amount = web3.toWei(7.7, 'ether')

    const [balanceContractBefore, balanceCarrierBefore] = await Promise.all([
      oslikToken.balanceOf(osliki.address), // balance before payment
      oslikToken.balanceOf(accounts[3]), // balance before payment
      oslikToken.approve(osliki.address, amount, {from: accounts[3]}) // he has enough OSLIK
    ])

    const res = await osliki.refund(invoiceId, {from: accounts[3]})

    const [balanceContractAfter, balanceCarrierAfter] = await Promise.all([
      oslikToken.balanceOf(osliki.address), // balance before payment
      oslikToken.balanceOf(accounts[3]) // balance before payment
    ])

    assert.equal(findEvent('EventRefund', res.logs).args.invoiceId.toNumber(),
      invoiceId,
      "EventRefund invoiceId wasn't " + invoiceId)

    assert.equal(balanceContractAfter.toString(), balanceContractBefore.toString(), "contract balance was wrong")
    assert.equal(balanceCarrierBefore.minus(amount).toString(), balanceCarrierAfter.toString(), "carrier balance was wrong")
  })


  /*** PAYMENTS IN  ETH ***/
  it("should fail ETH payment from another customer", async () => {
    const invoiceId = 2 //2 = mockInvoices[1]

    await verifyThrows(async () => {
      await osliki.pay(invoiceId, '', {from: accounts[2], value: web3.toWei(3.3, 'ether')})
    }, /revert/)
  })

  it("should fail ETH payment with not enough value", async () => {
    const invoiceId = 2 //2 = mockInvoices[1]

    await verifyThrows(async () => {
      await osliki.pay(invoiceId, '', {from: accounts[1], value: web3.toWei(3.29999, 'ether')})
    }, /revert/)
  })

  it("should process ETH payment", async () => {
    const invoiceId = 2 //2 = mockInvoices[1]

    const [balanceContractBefore, balanceCarrierBefore] = await Promise.all([
      web3.eth.getBalance(osliki.address),
      web3.eth.getBalance(accounts[4]),
    ])

    const res = await osliki.pay(invoiceId, depositHashes[0][1], {from: accounts[1], value: web3.toWei(3.3, 'ether')})

    const [balanceContractAfter, balanceCarrierAfter, fees] = await Promise.all([
      web3.eth.getBalance(osliki.address),
      web3.eth.getBalance(accounts[4]),
      osliki.fees()
    ])

    const fee = web3.toWei(new BigNumber('0.003'), 'ether')

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

  it("should fail fulfill with wrong depositKey", async () => {
    await verifyThrows(async () => {
      await osliki.fulfill(1, '1235'/*key*/, {from: accounts[4]})
    }, /revert/)
  })

  it("should fulfill order (in ETH)", async () => {
    const invoiceId = 2 //2 = mockInvoices[1]

    const [balanceContractBefore, balanceCarrierBefore, feesBefore] = await Promise.all([
      web3.eth.getBalance(osliki.address),
      web3.eth.getBalance(accounts[4]),
      osliki.fees()
    ])

    const res = await osliki.fulfill(1, depositHashes[0][0]/*key*/, {from: accounts[4]})

    const [balanceContractAfter, balanceCarrierAfter, feesAfter] = await Promise.all([
      web3.eth.getBalance(osliki.address),
      web3.eth.getBalance(accounts[4]),
      osliki.fees()
    ])

    const fee = web3.toWei(new BigNumber('0.03'), 'ether')

    assert.equal(findEvent('EventFulfill', res.logs).args.orderId.toNumber(),
      1,
      "EventFulfill orderId wasn't 1")

    assert.equal(feesAfter.minus(feesBefore).toString(), fee.toString(), "wrong amount of fee")
    // balanceCarrierAfter will be less by the gasUsed, so dunno how to calc
    assert.equal(balanceContractBefore.minus(balanceContractAfter).toString(), new BigNumber(mockInvoices[1][1]).minus(fee).toString(), "contract balance was wrong")
  })

  it("should refund order (in ETH)", async () => {
    const invoiceId = 2 //2 = mockInvoices[1]

    const [balanceContractBefore, balanceCarrierBefore] = await Promise.all([
      web3.eth.getBalance(osliki.address),
      web3.eth.getBalance(accounts[4])
    ])

    const res = await osliki.refund(invoiceId, {from: accounts[4], value: web3.toWei(3.3, 'ether')})

    const [balanceContractAfter, balanceCarrierAfter] = await Promise.all([
      web3.eth.getBalance(osliki.address),
      web3.eth.getBalance(accounts[4])
    ])

    assert.equal(findEvent('EventRefund', res.logs).args.invoiceId.toNumber(),
      invoiceId,
      "EventRefund invoiceId wasn't " + invoiceId)

    assert.equal(balanceContractBefore.toString(), balanceContractAfter.toString(), "contract balance was wrong")
  })


  /*** REVIEWS
    accounts[0](customer OSLIKI) <=> accounts[3](carrier) | orderId = 0, invoiceId = 1
    accounts[1](customer ETH) <=> accounts[4](carrier) | orderId = 1, invoiceId = 2
  ***/

  it("should add reviews", async () => {
    const orderId = 0;
    const orderId1 = 1;

    await Promise.all([
      verifyThrows(async () => await osliki.addReview(orderId, 5, 'Excellent!', {from: accounts[1]}), /revert/), // wrong address
      verifyThrows(async () => await osliki.addReview(orderId, 10, 'Excellent!', {from: accounts[0]}), /revert/), // wrong star
      verifyThrows(async () => await osliki.addReview(orderId, 0, 'Excellent!', {from: accounts[0]}), /revert/), // wrong star
    ]);

    const res = await osliki.addReview(orderId, 5, 'Excellent!', {from: accounts[0]})
    const args = findEvent('EventReview', res.logs).args

    await Promise.all([
      verifyThrows(async () => await osliki.addReview(orderId, 1, 'Bad', {from: accounts[0]}), /revert/), // attempt to rate again
      await osliki.addReview(orderId1, 5, 'OK!', {from: accounts[1]}),
      await osliki.addReview(orderId, 4, 'Very good!', {from: accounts[3]}),
    ]);

    assert.equal(args.orderId.toNumber(), orderId, "EventReview orderId wasn't " + orderId)
    assert.equal(args.from, accounts[0], "EventReview from wasn't " + accounts[0])
  })

  it("should withdrw fee", async () => {
    const fees = await osliki.fees()
    const res = await osliki.withdrawFees({from: oslikiFoundation})

    assert.equal(findEvent('EventWithdrawFees', res.logs).args.fees.toNumber(),
      fees,
      "EventWithdrawFees fees wasn't " + fees)
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
      2,
    ], "got wrong order")
  })

  it("should get offer by id", async () => {
    let offer = await osliki.offers(1)

    offer = allBigNumberToNumber(offer)
    offer.splice(3)
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
        depositHashes[0][1],
        3
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

  it("should get stat of user", async () => {
    const stats = await osliki.getStat(accounts[0])

    assert.equal(stats[0].toNumber(), 1, "ordersCount count wasn't 1")
    assert.equal(stats[1].toNumber(), 4, "rateSum count wasn't 5")
    assert.equal(stats[2].toNumber(), 1, "rateCount count wasn't 1")

    const stats3 = await osliki.getStat(accounts[1])

    assert.equal(stats3[0].toNumber(), 1, "ordersCount count wasn't 1")
    assert.equal(stats3[1].toNumber(), 0, "rateSum count wasn't 0")
    assert.equal(stats3[2].toNumber(), 0, "rateCount count wasn't 0")
  })

  it("should get user's orderId by index", async () => {
    const stats = await osliki.getStat(accounts[4])

    ordersCount = stats[0]

    const orderId = await osliki.getUserOrders(accounts[4], ordersCount-1)

    assert.equal(orderId.toNumber(), 1, "orderId 1")
  })

  it("should get review", async () => {
    const stats = await osliki.getStat(accounts[3])
    ordersCount = stats[0]
    const orderId = await osliki.getUserOrders(accounts[3], ordersCount-1)
    const review = await osliki.getReview(accounts[3], orderId)

    assert.equal(review[0].toNumber(), 5, "rate wasn't 5")
    assert.equal(review[1], 'Excellent!', "text wasn't Excellent!")
  })

})
