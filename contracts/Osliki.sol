pragma solidity ^0.4.21;

import '../node_modules/zeppelin-solidity/contracts/math/SafeMath.sol';
import '../node_modules/zeppelin-solidity/contracts/token/ERC20/ERC20.sol';
import '../node_modules/zeppelin-solidity/contracts/token/ERC20/SafeERC20.sol';

contract Osliki {
  using SafeMath for uint;
  using SafeERC20 for ERC20;

  ERC20 public oslikToken;
  address public oslikiFoundation;
  uint public constant OSLIKI_FEE = 1; // Only for ETH
  uint public fees = 0; // To know how much can be withdrawn in favor of the Foundation

  Order[] public orders;
  Offer[] public offers;
  Invoice[] public invoices;
  mapping (address => uint[]) public stats;

  enum EnumOrderStatus { New, Process, Fulfilled }
  enum EnumInvoiceStatus { New, Settled, Closed, Refund }
  enum EnumCurrency { ETH, OSLIK }
  enum EnumStars { _0, _1, _2, _3, _4, _5 }

  event EventOrder(uint orderId);
  event EventOffer(uint offerId, uint orderId);
  event EventInvoice(uint invoiceId, uint orderId);
  event EventPayment(uint invoiceId);
  event EventFulfill(uint orderId);
  event EventRefund(uint invoiceId);

  event EventLog(uint fist, uint sec, uint thrd, uint asa);

  struct Order {
    address customer;
    string from;
    string to;
    string params;
    uint date;
    string message;

    uint[] offerIds;

    address carrier;
    uint invoiceId;

    EnumOrderStatus status;
    uint createdAt;
    uint updatedAt;
  }

  struct Offer {
    address carrier;
    uint orderId;
    string message;
  }

  struct Invoice {
    address sender;
    uint orderId;
    uint prepayment;
    uint deposit;
    uint valid;
    EnumCurrency currency;
    bytes32 depositHash;
    EnumInvoiceStatus status;
    uint createdAt;
    uint updatedAt;
  }

  struct Stat {
    EnumStars stars;
    string comment;
  }

  function Osliki(
    ERC20 _oslikToken,
    address _oslikiFoundation
  ) public {

    require(address(_oslikToken) != address(0) && _oslikiFoundation != address(0));

    oslikToken = _oslikToken;
    oslikiFoundation = _oslikiFoundation;

    // plug for invoices[0] cos default invoiceId in all orders == 0
    invoices.push(Invoice({
      sender: 0x0,
      orderId: 0,
      prepayment: 0,
      deposit: 0,
      valid: 0,
      currency: EnumCurrency.ETH,
      depositHash: 0x0,
      status: EnumInvoiceStatus.New,
      createdAt: now,
      updatedAt: now
    }));
  }

  function getFee(uint value) public pure returns (uint) {
    return value.div(100).mul(OSLIKI_FEE);
  }

  function addOrder(
      string from, // geo coord 'lat,lon' or Ethereum address '0x...'
      string to,
      string params,  // format 'weight(kg),length(m),width(m),height(m)'
      uint date,
      string message
  ) public {

    orders.push(Order({
      customer: msg.sender,
      from: from,
      to: to,
      params: params,
      date: date,
      message: message,

      offerIds: new uint[](0),

      carrier: 0x0,
      invoiceId: 0,

      status: EnumOrderStatus.New,
      createdAt: now,
      updatedAt: now
    }));

    uint orderId = orders.length -1;

    emit EventOrder(orderId);
  }

  /*@ToDo: require order.date < now */
  function addOffer(
      uint orderId,
      string message
  ) public {
    Order storage order = orders[orderId];
    require(order.date >= now); // spoiled order

    offers.push(Offer({
      carrier: msg.sender,
      orderId: orderId,
      message: message
    }));

    uint offerId = offers.length - 1;

    order.offerIds.push(offerId);
    order.updatedAt = now;

    emit EventOffer(offerId, orderId);
  }

  /* @ToDo:
  check possible issues with invoices[0]
  add dateBefore
  */
  function addInvoice(
    uint orderId,
    uint prepayment,
    uint deposit,
    uint valid,
    EnumCurrency currency
  ) public {

    invoices.push(Invoice({
      sender: msg.sender,
      orderId: orderId,
      prepayment: prepayment,
      deposit: deposit,
      valid: valid,
      currency: currency,
      depositHash: '',
      status: EnumInvoiceStatus.New,
      createdAt: now,
      updatedAt: now
    }));

    uint invoiceId = invoices.length - 1;

    emit EventInvoice(invoiceId, orderId);
  }

  function pay(
    uint invoiceId,
    bytes32 depositHash
  ) public payable {

    Invoice storage invoice = invoices[invoiceId];
    Order storage order = orders[invoice.orderId];

    uint prepayment = invoice.prepayment;
    uint deposit = invoice.deposit;
    uint amount = prepayment.add(deposit);
    address addressThis = address(this);

    require(
      now <= invoice.createdAt.add(invoice.valid)  && // can't pay invoices in a few years and change the statuses
      order.carrier == 0 && // carrier haven't been assigned yet
      order.invoiceId == 0 && // double check, so impossible to change carriers in the middle of the process
      order.customer == msg.sender && // can't pay for someone else's orders
      order.status == EnumOrderStatus.New && // can't pay already processed orders
      invoice.status == EnumInvoiceStatus.New // can't pay already paid invoices
    );

    // in case of any throws the contract's state will be reverted
    // prevent re-entrancy
    order.status = EnumOrderStatus.Process;
    order.carrier = invoice.sender; // if the customer paid the invoice, it means that he chose the carrier
    order.invoiceId = invoiceId;
    order.updatedAt = now;

    //invoice.status = (deposit != 0 ? EnumInvoiceStatus.Deposit : EnumInvoiceStatus.Prepaid); // ?!?!?!?!?!?
    invoice.status = EnumInvoiceStatus.Settled;
    invoice.depositHash = depositHash; // even if deposit = 0, can be usefull for changing order state
    invoice.updatedAt = now;

    if (invoice.currency == EnumCurrency.ETH) {
      require(msg.value == amount); // not enough or too much funds

      uint balanceBefore = addressThis.balance; // for asserts
      uint fee = 0;

      if (prepayment != 0) {
        fee = getFee(prepayment);
        fees = fees.add(fee);

        invoice.sender.transfer(prepayment.sub(fee));
      }

      // deposit is already added to the contract balance

      uint balanceAfter = addressThis.balance;
      assert(balanceAfter == balanceBefore.sub(prepayment).add(fee)); // msg.value is added to balanceBefore
    }

    if (invoice.currency == EnumCurrency.OSLIK) { // no fee
      require(msg.value == 0); // prevent loss of ETH

      uint balanceOfBefore = oslikToken.balanceOf(addressThis);

      if (prepayment != 0) {
        oslikToken.safeTransferFrom(msg.sender, invoice.sender, prepayment);
      }

      if (deposit != 0) {
        oslikToken.safeTransferFrom(msg.sender, addressThis, deposit);
      }

      uint balanceOfAfter = oslikToken.balanceOf(addressThis);
      assert(balanceOfAfter == balanceOfBefore.add(deposit));
    }

    emit EventPayment(invoiceId);
  }

  function fulfill(
    uint orderId,
    string depositKey
  ) public {

    Order storage order = orders[orderId];
    Invoice storage invoice = invoices[order.invoiceId];

    bytes32 defaultHash;

    require(
      order.carrier == msg.sender && // only carrier
      invoice.sender == msg.sender && // just in case
      order.status == EnumOrderStatus.Process &&
      invoice.status == EnumInvoiceStatus.Settled && // double check
      (invoice.depositHash == defaultHash || invoice.depositHash == keccak256(depositKey))// depositHash can be empty
    );

    order.status = EnumOrderStatus.Fulfilled;
    order.updatedAt = now;

    invoice.status = EnumInvoiceStatus.Closed;
    invoice.updatedAt = now;

    uint deposit = invoice.deposit;

    if (deposit != 0) {
      address addressThis = address(this);

      if (invoice.currency == EnumCurrency.ETH) {
        uint balanceBefore = addressThis.balance;

        uint fee = getFee(deposit);
        fees = fees.add(fee);

        invoice.sender.transfer(deposit.sub(fee));

        uint balanceAfter = addressThis.balance;
        assert(balanceAfter == balanceBefore.sub(deposit).add(fee));
      }

      if (invoice.currency == EnumCurrency.OSLIK) { // no fee
        uint balanceOfBefore = oslikToken.balanceOf(addressThis);

        oslikToken.safeApprove(addressThis, deposit);
        oslikToken.safeTransferFrom(addressThis, invoice.sender, deposit);

        uint balanceOfAfter = oslikToken.balanceOf(addressThis);
        assert(balanceOfAfter == balanceOfBefore.sub(deposit));
      }
    }

    emit EventFulfill(orderId);
  }

  function refund(
    uint invoiceId
  ) public payable {

    Invoice storage invoice = invoices[invoiceId];
    Order storage order = orders[invoice.orderId];

    require(
      invoice.sender == msg.sender &&
      (invoice.status == EnumInvoiceStatus.Settled || invoice.status == EnumInvoiceStatus.Closed)
    );

    // !!! if invoice.status == EnumInvoiceStatus.Settled
    uint amountFromCarrier = invoice.prepayment;
    uint amountFromContract = invoice.deposit;

    if (invoice.status == EnumInvoiceStatus.Closed) {
      amountFromCarrier = amountFromCarrier.add(invoice.deposit);
      amountFromContract = amountFromContract.sub(invoice.deposit);
    }

    invoice.status = EnumInvoiceStatus.Refund;
    invoice.updatedAt = now;

    uint amount = amountFromCarrier.add(amountFromContract);
    address addressThis = address(this);

    if (invoice.currency == EnumCurrency.ETH) {
      require(msg.value == amountFromCarrier); // carrier's part of refund not 0

      if (amount != 0) {
        uint balanceBefore = addressThis.balance;

        order.customer.transfer(amount);

        uint balanceAfter = addressThis.balance;
        assert(balanceAfter == balanceBefore.sub(amount));
      }
    }

    if (invoice.currency == EnumCurrency.OSLIK) {
      require(msg.value == 0); // prevent loss of ETH

      uint balanceOfBefore = oslikToken.balanceOf(addressThis);

      if (amountFromCarrier != 0) {
        oslikToken.safeTransferFrom(msg.sender, order.customer, amountFromCarrier);
      }

      if (amountFromContract != 0) {
        oslikToken.safeApprove(addressThis, amountFromContract);

        oslikToken.safeTransferFrom(addressThis, order.customer, amountFromContract);
      }

      uint balanceOfAfter = oslikToken.balanceOf(addressThis);
      assert(balanceOfAfter == balanceOfBefore.sub(amountFromContract));
    }

    emit EventRefund(invoiceId);
  }

  function comment() public payable {

  }

  /**GETTERS*/
  function getOrdersCount() public view returns (uint) {
    return orders.length;
  }

  function getOffersCount() public view returns (uint) {
    return offers.length;
  }

  function getOrderOffersCount(uint orderId) public view returns (uint) {
    return orders[orderId].offerIds.length;
  }

  function getOrderOffer(uint orderId, uint index) public view returns (uint) {
    return orders[orderId].offerIds[index];
  }

  function getInvoicesCount() public view returns (uint) {
    return invoices.length;
  }

}
