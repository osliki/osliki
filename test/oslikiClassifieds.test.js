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

  it("should add new comments", async () => {
    await verifyThrows(async () => {
      await oslikiClassifieds.newComment(999, 'comment text', {from: accounts[2]}) // id not exist
    }, /revert/)

    await verifyThrows(async () => {
      await oslikiClassifieds.newComment(1, '', {from: accounts[2]}) // text empty
    }, /revert/)

    await oslikiClassifieds.newComment(1, 'comment text', {from: accounts[2]})
    await oslikiClassifieds.newComment(0, 'comment text1', {from: accounts[3]})
    let res = await oslikiClassifieds.newComment(1, 'comment text2', {from: accounts[3]})

    let args = findEvent('EventNewComment', res.logs).args

    assert.deepEqual([args.from, args.catId.toNumber(), args.adId.toNumber(), args.cmntId.toNumber()],
      [accounts[3], 0, 1, 2], "EventNewComment log incorrect"
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

    await verifyThrows(async () => {
      await oslikiClassifieds._changeOslikiFoundation('0x0', {from: oslikiFoundation});
    }, /revert/);

    await oslikiClassifieds._changeOslikiFoundation('0x02', {from: oslikiFoundation});

    const res = await oslikiClassifieds.oslikiFoundation();

    assert.equal(res, 0x0000000000000000000000000000000000000002, "OslikiFoundation isn't correct");
  })

  it("should get count of categories", async () => {
    const count = await oslikiClassifieds.getCatsCount()
    assert.equal(count.toNumber(), 2, "count of categories wasn't correct")
  })


  /* GETTERS */
  it("should get count of comments", async () => {
    const count = await oslikiClassifieds.getCommentsCount()
    assert.equal(count.toNumber(), 3, "count of comments wasn't correct")
  })

  it("should get count of comments by adId", async () => {
    const count0 = await oslikiClassifieds.getCommentsCountByAd(0)
    const count1 = await oslikiClassifieds.getCommentsCountByAd(1)
    const count3 = await oslikiClassifieds.getCommentsCountByAd(3)

    assert.equal(count0.toNumber(), 1, "count of comments for adId=0 wasn't correct")
    assert.equal(count1.toNumber(), 2, "count of comments for adId=1 wasn't correct")
    assert.equal(count3.toNumber(), 0, "count of comments for adId=3 wasn't correct")
  })

  it("should get all comment ids by ad", async () => {
    const cmntIds = await oslikiClassifieds.getAllCommentIdsByAd(1)
    assert.deepEqual(allBigNumberToNumber(cmntIds), [0, 2], "comments id wasn't correct")
  })

  it("should get comment id by adId and index", async () => {
    const cmntId = await oslikiClassifieds.getCommentIdByAd(1, 1)
    assert.deepEqual(cmntId.toNumber(), 2, "comment id wasn't correct")
  })

  it("should get count of ads", async () => {
    const count = await oslikiClassifieds.getAdsCount()
    assert.equal(count.toNumber(), 4, "count of ads wasn't correct")
  })

  it("should get count of ads", async () => {
    const [count0, count1, count5, count7] = await Promise.all([
      oslikiClassifieds.getAdsCountByUser(accounts[0]),
      oslikiClassifieds.getAdsCountByUser(accounts[1]),
      oslikiClassifieds.getAdsCountByUser(accounts[5]),
      oslikiClassifieds.getAdsCountByUser(accounts[7]),
    ])

    assert.equal(count0.toNumber(), 0, "count of ads0 wasn't correct")
    assert.equal(count1.toNumber(), 1, "count of ads1 wasn't correct")
    assert.equal(count5.toNumber(), 1, "count of ads5 wasn't correct")
    assert.equal(count7.toNumber(), 2, "count of ads7 wasn't correct")
  })

  it("should get ad id by user", async () => {
    const adId = await oslikiClassifieds.getAdIdByUser(accounts[7], 1)

    assert.equal(adId.toNumber(), 3, "adId wasn't correct")
  })

  it("should get all ad ids by user", async () => {
    const adIds = await oslikiClassifieds.getAllAdIdsByUser(accounts[7])

    assert.deepEqual(allBigNumberToNumber(adIds), [2, 3], "adIds wasn't correct")
  })

  it("should get count of ads by catId", async () => {
    const count = await oslikiClassifieds.getAdsCountByCat(1)
    assert.equal(count.toNumber(), 2, "count of ads wasn't correct")
  })

  it("should get ad id by user", async () => {
    const adId = await oslikiClassifieds.getAdIdByCat(1, 1)

    assert.equal(adId.toNumber(), 3, "adId wasn't correct")
  })

  it("should get all ad ids by cat", async () => {
    const adIds = await oslikiClassifieds.getAllAdIdsByCat(1)

    assert.deepEqual(allBigNumberToNumber(adIds), [2, 3], "adIds wasn't correct")
  })

  it("should get cat name by id", async () => {
    const catName = await oslikiClassifieds.catsRegister(1)

    assert.equal(catName, 'Second category', "Cat name wasn't correct")
  })

  it("should get ad by id", async () => {
    const ad = await oslikiClassifieds.ads(1)

    ad.splice(3)
    assert.deepEqual(allBigNumberToNumber(ad), [accounts[5], 0, "edited text"], "Ad wasn't correct")
  })

  it("should get comment by id", async () => {
    const cmnt = await oslikiClassifieds.comments(1)

    cmnt.splice(3)
    assert.deepEqual(allBigNumberToNumber(cmnt), [accounts[3], 0, "comment text1"], "Cmnt wasn't correct")
  })

})
