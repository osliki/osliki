pragma solidity ^0.4.23;

import "./SafeMath.sol";
import "./ERC20.sol";
import "./SafeERC20.sol";

/**
 * @title Smart contract Osliki Classifieds
 *
 * @dev This is part of the Decentralized Osliki Platform (DOP).
 */
contract Ads {
  using SafeMath for uint;
  using SafeERC20 for ERC20;

  ERC20 public oslikToken; // OSLIK Token (OT) address (ERC20 compatible token)
  address public oslikiFoundation; // Osliki Foundation (OF) address

  uint public upPrice = 1 ether; // same decimals for OSLIK tokens

  string[] public catsRegister;
  Ad[] public ads;
  Comment[] public comments;


  mapping (address => uint[]) internal byUsers;
  mapping (string => uint[]) internal byCats;
      // cat name => exist?
    // cat id = > ads[]
    // getCat [catName, catId]
  struct Category {
    string name;
    Ad[] ads;
  }

  struct Ad {
    address user;
    uint catId;
    string text;
    uint[] comments;
    uint createdAt;
    uint updatedAt;
  }

  struct Comment {
    address user;
    uint adId;
    string text;
    uint createdAt;
    uint updatedAt;
  }

  constructor(
    ERC20 _oslikToken,
    address _oslikiFoundation
  ) public {

    require(address(_oslikToken) != address(0), "_oslikToken is not assigned.");
    require(_oslikiFoundation != address(0), "_oslikiFoundation is not assigned.");

    oslikToken = _oslikToken;
    oslikiFoundation = _oslikiFoundation;
  }

  function setUpPrice(uint newUpPrice) public {
      require(msg.sender == oslikiFoundation);

      upPrice = newUpPrice;
  }

  function _addAd(
    uint catId,
    string text // format 'ipfs hash,ipfs hash...'
  ) private {
    ads.push(Ad({
      user: msg.sender,
      catId: catId,
      text: text,
      comments: new uint[](0),
      createdAt: now,
      updatedAt: now
    }));

    uint adId = ads.length - 1;

    byCats[catsRegister[catId]].push(adId);
    byUsers[msg.sender].push(adId);

    // emit EventAddAd(msg.sender, cat, adId);
  }

  function addAd(
    uint catId,
    string text // format 'ipfs hash,ipfs hash...'
  ) public {
    _addAd(catId, text);
  }

   function addAd(
    string newCat,
    string text // format 'ipfs hash,ipfs hash...'
  ) public {

    require(byCats[newCat].length == 0, "This category already exists.");

    catsRegister.push(newCat);
    uint catId = catsRegister.length - 1;
    _addAd(catId, text);
  }

  function editAd(
    uint adId,
    string text // format 'ipfs hash,ipfs hash...'
  ) public {
    Ad storage ad = ads[adId];

    require(msg.sender == ad.user, "Sender not authorized.");

    /*if (!compareStrings(ad.cat, cat)) {
        ad.cat = cat;
    }*/

    if (!compareStrings(ad.text, text)) {
        ad.text = text;
        ad.updatedAt = now;
    }

    // emit EventEditAd(msg.sender, cat, adId);
  }

  function addComment(
    uint adId,
    string text
  ) public {
    Ad storage ad = ads[adId];

    require(msg.sender == ad.user, "Sender not authorized.");

    /*if (!compareStrings(ad.cat, cat)) {
        ad.cat = cat;
    }*/

    if (!compareStrings(ad.text, text)) {
        ad.text = text;
        ad.updatedAt = now;
    }

    // emit EventEditAd(msg.sender, cat, adId);
  }

  function editComment(
    uint commentId,
    string text
  ) public {
    Comment storage comment = comments[commentId];

    require(msg.sender == comment.user, "Sender not authorized.");

    if (!compareStrings(comment.text, text)) {
        comment.text = text;
        comment.updatedAt = now;
    }

    // emit EventEditComment(commentId, msg.sender);
  }

  function upAd(
    uint adId
  ) public {
    Ad memory ad = ads[adId];

    require(msg.sender == ad.user, "Sender not authorized.");

    byCats[catsRegister[ad.catId]].push(adId);

    uint balanceOfBefore = oslikToken.balanceOf(oslikiFoundation);

    oslikToken.safeTransferFrom(msg.sender, oslikiFoundation, upPrice);

    uint balanceOfAfter = oslikToken.balanceOf(oslikiFoundation);
    assert(balanceOfAfter == balanceOfBefore.add(upPrice));
  }

  function compareStrings (string a, string b) public pure returns (bool) {
   return keccak256(a) == keccak256(b);
  }

}
