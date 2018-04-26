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
  let oslikiClassifieds;
  let oslikToken;
  let oslikTokenFounder;
  let oslikiFoundation;// = accounts[1]

  it("should set contract's instances", async () => {
    oslikiClassifieds = await OslikiClassifieds.deployed()
    oslikiFoundation = await oslikiClassifieds.oslikiFoundation()
    const oslikTokenAddr = await oslikiClassifieds.oslikToken()
    oslikToken = await OslikToken.at(oslikTokenAddr)
    oslikTokenFounder = await oslikToken.founder()
  })

  it("should add a new ads in a new cat", async () => {
    const res = await oslikiClassifieds.newCatWithAd('First category', 'text', {from: accounts[1]})
    const res2 = await oslikiClassifieds.newAd(0, 'text2', {from: accounts[5]})

    let args = findEvent('EventNewAd', res.logs).args
    let args1 = findEvent('EventNewCategory', res.logs).args
    let args2 = findEvent('EventNewAd', res2.logs).args
    let rewardEvent = findEvent('EventReward', res2.logs)

    assert.deepEqual([args.from, args.catId.toNumber(), args.adId.toNumber()],
      [accounts[1], 0, 0], "EventNewAd log incorrect"
    )

    assert.deepEqual([args1.catName, args1.catId.toNumber()],
      ['First category', 0], "EventNewCategory log incorrect"
    )

    assert.deepEqual([args2.from, args2.catId.toNumber(), args2.adId.toNumber()],
      [accounts[5], 0, 1], "EventNewAd2 log incorrect"
    )

    assert.equal(rewardEvent, undefined, "rewardEvent log incorrect")
  })

  it("should reward correctly", async () => {
    const [balanceBefore, balanceUserBefore, reward] = await Promise.all([
      oslikToken.balanceOf(oslikiFoundation), // balance before payment
      oslikToken.balanceOf(accounts[7]), // balance before payment
      oslikiClassifieds.reward(),
      oslikToken.approve(oslikiClassifieds.address, web3.toWei(80, 'ether'), {from: oslikTokenFounder})
    ])

    const res = await oslikiClassifieds.newCatWithAd('Second category', 'text reward1', {from: accounts[7]})

    const [balanceAfter, balanceUserAfter] = await Promise.all([
      oslikToken.balanceOf(oslikiFoundation), // balance before payment
      oslikToken.balanceOf(accounts[7]), // balance before payment
    ])

    const args = findEvent('EventReward', res.logs).args

    assert.deepEqual([args.to, args.reward],
      [accounts[7], reward], "EventReward log incorrect"
    )

    assert.equal(balanceBefore.minus(balanceAfter).toString(), reward.toString(), "Foundation balance is wrong")
    assert.equal(balanceUserAfter.minus(balanceUserBefore).toString(), reward.toString(), "User balance is wrong")

    await oslikiClassifieds._changeReward(0, {from: oslikiFoundation})

    const res2 = await oslikiClassifieds.newAd(1, 'text reward2', {from: accounts[7]})
    const eventReward = findEvent('EventReward', res2.logs)
    assert.equal(eventReward, undefined, "EventReward wasn't undefined")
  })

  it("shouldn't add a new ads", async () => {
    await verifyThrows(async () => {
      await oslikiClassifieds.newCatWithAd('First category', 'text', {from: accounts[1]}) // already existed
    }, /revert/)

    await verifyThrows(async () => {
      await oslikiClassifieds.newCatWithAd('', 'text', {from: accounts[1]}) // empty name
    }, /revert/)

    await verifyThrows(async () => {
      await oslikiClassifieds.newAd(9999, 'text', {from: accounts[1]}) // catId not exist
    }, /revert/)
  })

  it("should edit the ad", async () => {
    await verifyThrows(async () => {
      await oslikiClassifieds.editAd(1, 'edited text', {from: accounts[1]}) // not auth user
    }, /revert/)

    await verifyThrows(async () => {
      await oslikiClassifieds.editAd(1, '', {from: accounts[5]}) // empty text
    }, /revert/)

    await verifyThrows(async () => {
      await oslikiClassifieds.editAd(999, '', {from: accounts[5]}) // id not exist
    }, /revert/)

    let res = await oslikiClassifieds.editAd(1, 'edited text', {from: accounts[5]}) // not auth user

    let args = findEvent('EventEditAd', res.logs).args

    assert.deepEqual([args.from, args.catId.toNumber(), args.adId.toNumber()],
      [accounts[5], 0, 1], "EventEditAd log incorrect"
    )
  })

  it("should add new comment", async () => {
    await verifyThrows(async () => {
      await oslikiClassifieds.newComment(999, 'comment text', {from: accounts[2]}) // id not exist
    }, /revert/)

    await verifyThrows(async () => {
      await oslikiClassifieds.newComment(1, '', {from: accounts[2]}) // text empty
    }, /revert/)

    await oslikiClassifieds.newComment(1, 'comment text', {from: accounts[2]}) // not auth user
    let res = await oslikiClassifieds.newComment(1, 'comment text2', {from: accounts[3]}) // not auth user

    let args = findEvent('EventNewComment', res.logs).args

    assert.deepEqual([args.from, args.catId.toNumber(), args.adId.toNumber(), args.cmntId.toNumber()],
      [accounts[3], 0, 1, 1], "EventNewComment log incorrect"
    )
  })

  it("should upAd", async () => {
    //oslikTokenFounder === oslikiFoundation
    await oslikToken.transfer(accounts[1], web3.toWei(50, 'ether'), {from: oslikTokenFounder})

    const [balanceBefore, balanceUserBefore, upPrice] = await Promise.all([
      oslikToken.balanceOf(oslikiFoundation), // balance before payment
      oslikToken.balanceOf(accounts[1]), // balance before payment
      oslikiClassifieds.upPrice()
    ])

    await oslikToken.approve(oslikiClassifieds.address, web3.toWei(10, 'ether'), {from: accounts[1]})

    await verifyThrows(async () => {await oslikiClassifieds.upAd(999, {from: accounts[1]})}, /revert/)

    let res = await oslikiClassifieds.upAd(0, {from: accounts[1]})

    const [balanceAfter, balanceUserAfter] = await Promise.all([
      oslikToken.balanceOf(oslikiFoundation), // balance before payment
      oslikToken.balanceOf(accounts[1]), // balance before payment
    ])

    const args = findEvent('EventUpAd', res.logs).args

    assert.deepEqual([args.from, args.catId.toNumber(), args.adId.toNumber()],
      [accounts[1], 0, 0], "EventUpAd log incorrect"
    )

    assert.equal(balanceAfter.minus(balanceBefore).toString(), upPrice.toString(), "Foundation balance is wrong")
    assert.equal(balanceUserBefore.minus(balanceUserAfter).toString(), upPrice.toString(), "User balance is wrong")
  })



  it("should change upPrice", async () => {
    const newPrice = web3.toWei('2', 'ether');

    await verifyThrows(async () => {
      await oslikiClassifieds._changeUpPrice(newPrice, {from: accounts[1]});
    }, /revert/);

    await oslikiClassifieds._changeUpPrice(newPrice, {from: oslikiFoundation});

    const res = await oslikiClassifieds.upPrice();

    assert.equal(res, newPrice, "Price isn't correct");
  })

  it("should change Reward", async () => {
    const newReward = web3.toWei('8', 'ether');

    await verifyThrows(async () => {
      await oslikiClassifieds._changeReward(newReward, {from: accounts[1]});
    }, /revert/);

    await oslikiClassifieds._changeReward(newReward, {from: oslikiFoundation});

    const res = await oslikiClassifieds.reward();

    assert.equal(res, newReward, "Reward isn't correct");
  })

  it("should change OslikiFoundation address", async () => {

    await verifyThrows(async () => {
      await oslikiClassifieds._changeOslikiFoundation('0x02', {from: accounts[1]});
    }, /revert/);

    await oslikiClassifieds._changeOslikiFoundation('0x02', {from: oslikiFoundation});

    const res = await oslikiClassifieds.oslikiFoundation();

    assert.equal(res, 0x0000000000000000000000000000000000000002, "OslikiFoundation isn't correct");
  })

})

/*
assert.equal(findEvent('EventRefund', res.logs).args.invoiceId.toNumber(),
      invoiceId,
      "EventRefund invoiceId wasn't " + invoiceId)
*/
