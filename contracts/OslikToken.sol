pragma solidity ^0.4.24;

import '../node_modules/zeppelin-solidity/contracts/token/ERC20/StandardBurnableToken.sol';

/**
 * @title OslikToken
 * @dev ERC20 Token, where all tokens are pre-assigned to the creator.
 * Note they can later distribute these tokens as they wish using `transfer` and other
 * `StandardToken` functions.
 */
contract OslikToken is StandardBurnableToken {

  string public constant name = 'Osliki Token'; // solium-disable-line uppercase
  string public constant symbol = 'OSLIK'; // solium-disable-line uppercase
  uint8 public constant decimals = 18; // solium-disable-line uppercase

  uint public constant INITIAL_SUPPLY = 10**8 * (10 ** uint(decimals));

  address public founder;

  /**
   * @dev Constructor that gives msg.sender all of existing tokens.
   */
  constructor(address _oslikiFoundation) public {
    require(_oslikiFoundation != address(0), "_oslikiFoundation is not assigned.");

    totalSupply_ = INITIAL_SUPPLY;
    founder = _oslikiFoundation;
    balances[founder] = INITIAL_SUPPLY;
    emit Transfer(0x0, founder, INITIAL_SUPPLY);
  }

}
