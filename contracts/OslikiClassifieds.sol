pragma solidity ^0.4.23;

import "../node_modules/zeppelin-solidity/contracts/math/SafeMath.sol";
import "../node_modules/zeppelin-solidity/contracts/token/ERC20/ERC20.sol";
import "../node_modules/zeppelin-solidity/contracts/token/ERC20/SafeERC20.sol";

/**
 * @title Smart contract Osliki Classifieds
 *
 * @dev This is part of the Decentralized Osliki Platform (DOP).
 */
contract OslikiClassifieds {
  using SafeMath for uint;
  using SafeERC20 for ERC20;

  ERC20 public oslikToken; // OSLIK Token (OT) address (ERC20 compatible token)
  address public oslikiFoundation; // Osliki Foundation (OF) address

  uint public upPrice = 1 ether; // same decimals for OSLIK tokens
  uint public reward = 1 ether; // same decimals for OSLIK tokens

  string[] public catsRegister;
  Ad[] public ads;
  Comment[] public comments;

  mapping (address => uint[]) internal adsByUser;
  mapping (string => uint[]) internal adsByCat;

  event EventNewCategory(uint catId, string catName);
  event EventNewAd(address indexed from, uint indexed catId, uint adId);
  event EventEditAd(address indexed from, uint indexed catId, uint indexed adId);
  event EventNewComment(address indexed from, uint indexed catId, uint indexed adId, uint cmntId);
  event EventUpAd(address indexed from, uint indexed catId, uint indexed adId);
  event EventReward(address indexed to, uint reward);

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

  function _newAd(
    uint catId,
    string text // format 'ipfs hash,ipfs hash...'
  ) private returns (bool) {
    require(bytes(text).length != 0, "Text is empty");

    ads.push(Ad({
      user: msg.sender,
      catId: catId,
      text: text,
      comments: new uint[](0),
      createdAt: now,
      updatedAt: now
    }));

    uint adId = ads.length - 1;

    adsByCat[catsRegister[catId]].push(adId);
    adsByUser[msg.sender].push(adId);

    if (reward > 0 && oslikToken.allowance(oslikiFoundation, address(this)) >= reward) {
      uint balanceOfBefore = oslikToken.balanceOf(oslikiFoundation);

      oslikToken.safeTransferFrom(oslikiFoundation, msg.sender, reward);

      uint balanceOfAfter = oslikToken.balanceOf(oslikiFoundation);
      assert(balanceOfAfter == balanceOfBefore.sub(reward));

      emit EventReward(msg.sender, reward);
    }

    emit EventNewAd(msg.sender, catId, adId);

    return true;
  }

  function newAd(
    uint catId,
    string text // format 'ipfs hash,ipfs hash...'
  ) public {
    require(catId < catsRegister.length, "Category not found");

    assert(_newAd(catId, text));
  }

  function newCatWithAd(
    string catName,
    string text // format 'ipfs hash,ipfs hash...'
  ) public {
    require(bytes(catName).length != 0, "Category is empty");
    require(adsByCat[catName].length == 0, "Category already exists");

    catsRegister.push(catName);
    uint catId = catsRegister.length - 1;

    emit EventNewCategory(catId, catName);

    assert(_newAd(catId, text));
  }

  function editAd(
    uint adId,
    string text // format 'ipfs hash,ipfs hash...'
  ) public {
    require(adId < ads.length, "Ad id not found");
    require(bytes(text).length != 0, "Text is empty");

    Ad storage ad = ads[adId];

    require(msg.sender == ad.user, "Sender not authorized.");
    require(!_stringsEqual(ad.text, text), "New text is the same");

    ad.text = text;
    ad.updatedAt = now;

    emit EventEditAd(msg.sender, ad.catId, adId);
  }

  function newComment(
    uint adId,
    string text
  ) public {
    require(adId < ads.length, "Ad id not found");
    require(bytes(text).length != 0, "Text is empty");

    Ad storage ad = ads[adId];

    comments.push(Comment({
      user: msg.sender,
      adId: adId,
      text: text,
      createdAt: now,
      updatedAt: now
    }));

    uint cmntId = comments.length - 1;

    ad.comments.push(cmntId);

    emit EventNewComment(msg.sender, ad.catId, adId, cmntId);
  }

  function upAd(
    uint adId
  ) public {
    require(adId < ads.length, "Ad id not found");

    Ad memory ad = ads[adId];

    adsByCat[catsRegister[ad.catId]].push(adId);

    uint balanceOfBefore = oslikToken.balanceOf(oslikiFoundation);

    oslikToken.transferFrom(msg.sender, oslikiFoundation, upPrice);

    uint balanceOfAfter = oslikToken.balanceOf(oslikiFoundation);
    assert(balanceOfAfter == balanceOfBefore.add(upPrice));

    emit EventUpAd(msg.sender, ad.catId, adId);
  }

  modifier onlyFoundation {
    require(msg.sender == oslikiFoundation, "Sender not authorized.");
    _;
  }

  function _changeUpPrice(uint newUpPrice) public onlyFoundation {
    upPrice = newUpPrice;
  }

  function _changeReward(uint newReward) public onlyFoundation {
    reward = newReward;
  }

  function _changeOslikiFoundation(address newAddress) public onlyFoundation {
    oslikiFoundation = newAddress;
  }

  function _stringsEqual(string a, string b) private pure returns (bool) {
   return keccak256(a) == keccak256(b);
  }


  function getCatsCount() public view returns (uint) {
    return catsRegister.length;
  }

  function getCommentsCount() public view returns (uint) {
    return comments.length;
  }

  function getCommentsCountByAd(uint adId) public view returns (uint) {
    return ads[adId].comments.length;
  }

  function getAllCommentsByAd(uint adId) public view returns (uint[]) {
    return ads[adId].comments;
  }

  function getCommentByAd(uint adId, uint index) public view returns (uint) {
    return ads[adId].comments[index];
  }
  

  function getAdsCount() public view returns (uint) {
    return ads.length;
  }


  function getAdsCountByUser(address user) public view returns (uint) {
    return adsByUser[user].length;
  }

  function getAdByUser(address user, uint index) public view returns (uint) {
    return adsByUser[user][index];
  }

  function getAllAdsByUser(address user) public view returns (uint[]) {
    return adsByUser[user];
  }


  function getAdsCountByCat(string catName) public view returns (uint) {
    return adsByCat[catName].length;
  }

  function getAdByCat(string catName, uint index) public view returns (uint) {
    return adsByCat[catName][index];
  }

  function getAllAdsByCat(string catName) public view returns (uint[]) {
    return adsByCat[catName];
  }

}

// проверить returns struc в логах
