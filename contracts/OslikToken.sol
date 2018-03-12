pragma solidity ^0.4.21;

import '../node_modules/zeppelin-solidity/contracts/token/ERC20/StandardToken.sol';

/**
 * @title OslikToken
 * @dev ERC20 Token, where all tokens are pre-assigned to the creator.
 * Note they can later distribute these tokens as they wish using `transfer` and other
 * `StandardToken` functions.
 */
contract OslikToken is StandardToken {

  string public constant name = 'Osliki Token'; // solium-disable-line uppercase
  string public constant symbol = 'OSLIK'; // solium-disable-line uppercase
  uint8 public constant decimals = 18; // solium-disable-line uppercase

  uint public constant INITIAL_SUPPLY = 10000 * (10 ** uint(decimals));

  /**
   * @dev Constructor that gives msg.sender all of existing tokens.
   */
  function OslikToken() public {
    totalSupply_ = INITIAL_SUPPLY;
    balances[msg.sender] = INITIAL_SUPPLY;
    emit Transfer(0x0, msg.sender, INITIAL_SUPPLY);
  }

}
