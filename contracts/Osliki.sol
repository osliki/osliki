pragma solidity ^0.4.21;

import '../node_modules/zeppelin-solidity/contracts/math/SafeMath.sol';
import '../node_modules/zeppelin-solidity/contracts/token/ERC20/ERC20.sol';
import '../node_modules/zeppelin-solidity/contracts/token/ERC20/SafeERC20.sol';

/**
 * @title Smart contract Osliki
 *
 * @dev Osliki Protocol (OP) is implemented by this smart contract.
 * @dev This is the core of the Decentralized Osliki Platform (DOP).
 */
contract Osliki {
  using SafeMath for uint;
  using SafeERC20 for ERC20;

  ERC20 public oslikToken;
  address public oslikiFoundation;
  uint public constant OSLIKI_FEE = 1; // Only for transactions in ETH
  uint public fees = 0; // To know how much can be withdrawn in favor of the Osliki Foundation

  Order[] public orders;
  Offer[] public offers;
  Invoice[] public invoices;
  mapping (address => Stat) internal stats;

  enum EnumOrderStatus { New, Process, Fulfilled }
  enum EnumInvoiceStatus { New, Settled, Closed, Refund }
  enum EnumCurrency { ETH, OSLIK }

  event EventOrder(uint orderId);
  event EventOffer(uint offerId, uint indexed orderId);
  event EventInvoice(uint invoiceId, uint indexed orderId);
  event EventPayment(uint indexed invoiceId);
  event EventFulfill(uint indexed orderId);
  event EventRefund(uint indexed invoiceId);
  event EventReview(uint indexed orderId, address from);
  event EventWithdrawFees(uint fees);

  struct Order {
    address customer;
    string from; // Geo coords in the format 'lat,lon' or Ethereum address '0x...'
    string to; // Geo coords in the format 'lat,lon' or Ethereum address '0x...'
    string params; // Format 'weight(kg),length(m),width(m),height(m)'
    uint expires; // Expiration date in seconds since Unix Epoch
    string message;

    uint[] offerIds; // Array of carrier offers

    address carrier; // Chosen carrier
    uint invoiceId;

    EnumOrderStatus status;
    uint createdAt;
    uint updatedAt;
  }

  struct Offer {
    address carrier;
    uint orderId;
    string message;
    uint createdAt;
  }

  struct Invoice {
    address sender;
    uint orderId;
    uint prepayment;
    uint deposit;
    uint expires; // Expiration date in seconds since Unix Epoch
    EnumCurrency currency;
    bytes32 depositHash; // Ethereum-SHA-3 (Keccak-256) hash of the deposit key string provided by the customer
    EnumInvoiceStatus status;
    uint createdAt;
    uint updatedAt;
  }

  struct Stat {
    uint[] orders;
    uint rateSum;
    uint rateCount;
    mapping (uint => Review) reviews; // orderId => Stat
  }

  struct Review {
    bool lock; // Can rate only once
    uint8 rate; // Range between 1-5
    string text;
    uint createdAt;
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
      expires: 0,
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
      string from,
      string to,
      string params,
      uint expires,
      string message
  ) public {

    orders.push(Order({
      customer: msg.sender,
      from: from,
      to: to,
      params: params,
      expires: expires,
      message: message,

      offerIds: new uint[](0),

      carrier: 0x0,
      invoiceId: 0,

      status: EnumOrderStatus.New,
      createdAt: now,
      updatedAt: now
    }));

    uint orderId = orders.length - 1;

    /* stats */
    stats[msg.sender].orders.push(orderId);

    emit EventOrder(orderId);
  }

  function addOffer(
      uint orderId,
      string message
  ) public {

    Order storage order = orders[orderId];

    require(now <= order.expires); // expired order

    offers.push(Offer({
      carrier: msg.sender,
      orderId: orderId,
      message: message,
      createdAt: now
    }));

    uint offerId = offers.length - 1;

    order.offerIds.push(offerId);
    order.updatedAt = now;

    emit EventOffer(offerId, orderId);
  }

  function addInvoice(
    uint orderId,
    uint prepayment,
    uint deposit,
    uint expires,
    EnumCurrency currency
  ) public {
    Order memory order = orders[orderId];

    require(
      order.customer != msg.sender && // the customer can't be a carrier at the same time (for stats and reviews)
      now <= order.expires // expired order
    );

    invoices.push(Invoice({
      sender: msg.sender,
      orderId: orderId,
      prepayment: prepayment,
      deposit: deposit,
      expires: expires,
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
      now <= invoice.expires  && // can't pay invoices in a few years and change the statuses

      order.carrier == 0 && // carrier haven't been assigned yet
      order.invoiceId == 0 && // double check, so impossible to change carriers in the middle of the process
      order.customer == msg.sender && // can't pay for someone else's orders
      order.status == EnumOrderStatus.New && // can't pay already processed orders

      invoice.sender != msg.sender && // ??? double check, the customer can't be a carrier at the same time (for stats and reviews)
      invoice.status == EnumInvoiceStatus.New // can't pay already paid invoices
    );

    // in case of any throws the contract's state will be reverted
    // prevent re-entrancy
    order.status = EnumOrderStatus.Process;
    order.carrier = invoice.sender; // if the customer paid the invoice, it means that he chose a carrier
    order.invoiceId = invoiceId;
    order.updatedAt = now;

    /* stats */
    stats[order.carrier].orders.push(invoice.orderId);

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

    // if (invoice.status == EnumInvoiceStatus.Settled)
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

  function addReview(
    uint orderId,
    uint8 rate,
    string text
  ) public {

    Order storage order = orders[orderId];

    Stat storage stat = stats[msg.sender == order.customer ? order.carrier : order.customer];
    Review storage review = stat.reviews[orderId];

    require(
      (msg.sender == order.customer || msg.sender == order.carrier) &&
      (order.status == EnumOrderStatus.Process || order.status == EnumOrderStatus.Fulfilled) &&
      !review.lock &&
      (rate > 0 && rate <= 5)
    );

    review.lock = true;
    review.rate = rate;
    review.text = text;
    review.createdAt = now;

    stat.rateSum = stat.rateSum.add(rate);
    stat.rateCount++;

    emit EventReview(orderId, msg.sender);
  }

  function withdrawFees() public {
    require(msg.sender == oslikiFoundation && fees != 0);

    uint feesToWithdraw = fees;

    fees = 0;

    oslikiFoundation.transfer(feesToWithdraw);

    emit EventWithdrawFees(feesToWithdraw);
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

  function getStat(address user) public view returns(uint ordersCount, uint rateSum, uint rateCount) {
      Stat memory stat = stats[user];

      ordersCount = stat.orders.length;
      rateSum = stat.rateSum;
      rateCount = stat.rateCount;
  }

  function getUserOrders(address user, uint index) public view returns(uint orderId) {
      Stat memory stat = stats[user];

      orderId = stat.orders[index];
  }

  function getReview(address user, uint orderId) public view returns(uint8 rate, string text, uint createdAt) {
      Review memory review = stats[user].reviews[orderId];

      rate = review.rate;
      text = review.text;
      createdAt = review.createdAt;
  }

}
