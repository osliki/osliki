const BigNumber = require('bignumber.js');

const OslikiClassifieds = artifacts.require('OslikiClassifieds.sol')
const OslikToken = artifacts.require('OslikToken.sol')

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

contract('OslikiClassifieds', accounts => {
  let oslikiClassifieds
  let oslikToken
  let oslikTokenFounder
  let oslikiFoundation

  it("should set contract's instances", async () => {
    oslikToken = await OslikToken.deployed()
    oslikiClassifieds = await OslikiClassifieds.deployed()
    oslikiFoundation = await oslikiClassifieds.oslikiFoundation()
  })

  it("should change upPrice", async () => {
    const newPrice = web3.toWei('2', 'ether');

    await verifyThrows(async () => {
      await oslikiClassifieds._setUpPrice(newPrice, {from: accounts[1]});
    }, /revert/);

    await oslikiClassifieds._setUpPrice(newPrice, {from: oslikiFoundation});

    const res = await oslikiClassifieds.upPrice();

    assert.equal(res, newPrice, "Price isn't correct");
  })

return

  it("should add new ad", async () => {
    const res = await oslikiClassifieds.addAd(0, 'text', {from: oslikiFoundation})
console.dir(res)
    //assert.equal(res0.logs[0].args.orderId.toNumber(), 0, "orderId0 wasn't 0")
  })
})

/*
assert.equal(findEvent('EventRefund', res.logs).args.invoiceId.toNumber(),
      invoiceId,
      "EventRefund invoiceId wasn't " + invoiceId)
*/
