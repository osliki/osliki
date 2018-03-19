pragma solidity ^0.4.21;

import "../node_modules/zeppelin-solidity/contracts/math/SafeMath.sol";
import "../node_modules/zeppelin-solidity/contracts/token/ERC20/ERC20.sol";
import "../node_modules/zeppelin-solidity/contracts/token/ERC20/SafeERC20.sol";

/**
 * @title Smart contract Osliki
 *
 * @dev Osliki Protocol (OP) is implemented by this smart contract.
 * @dev This is the core of the Decentralized Platform Osliki (DPO).
 */
contract Osliki {
  using SafeMath for uint;
  using SafeERC20 for ERC20;

  ERC20 public oslikToken; // OSLIK Token (OT) address (ERC20 compatible token)
  address public oslikiFoundation; // Osliki Foundation (OF) address
  uint8 public constant OSLIKI_FEE = 1; // Only for transactions in ETH (1%)
  uint public fees = 0; // To know how much can be withdrawn in favor of the Osliki Foundation

  Order[] public orders;
  Offer[] public offers;
  Invoice[] public invoices;
  mapping (address => Stat) internal stats; // Statistics for each user who ever used the platform

  enum EnumOrderStatus { New, Process, Fulfilled }
  enum EnumInvoiceStatus { New, Settled, Closed, Refund }
  enum EnumCurrency { ETH, OSLIK }

  event EventOrder(uint orderId); // customer
  event EventOffer(uint offerId, uint indexed orderId); // carrier
  event EventRespond(uint indexed offerId); // customer
  event EventInvoice(uint invoiceId, uint indexed orderId); // carrier
  event EventPayment(uint indexed invoiceId); // customer
  event EventFulfill(uint indexed orderId); // carrier
  event EventRefund(uint indexed invoiceId); // carrier
  event EventReview(uint indexed orderId, address from); // customer || carrier
  event EventWithdrawFees(uint fees); // oslikiFoundation

  struct Order {
    address customer;
    string from; // Geographic coordinate in 'lat,lon' format or Ethereum address '0x...'
    string to; // Geographic coordinate in 'lat,lon' format or Ethereum address '0x...'
    string params; // Package params in 'weight(kg),length(m),width(m),height(m)' format
    uint expires; // Expiration date in SECONDS since Unix Epoch
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
    string respond; // Client respond
    uint createdAt;
    uint updatedAt;
  }

  struct Invoice {
    address sender; // Carrier
    uint orderId;
    uint prepayment; // Amount for the prepayment
    uint deposit; // Amount for the deposit
    EnumCurrency currency; // ETH or OSLIK (no fee)
    uint expires; // Expiration date in SECONDS since Unix Epoch
    bytes32 depositHash; // Ethereum-SHA-3 (Keccak-256) hash of the deposit key string provided by the customer
    EnumInvoiceStatus status;
    uint createdAt;
    uint updatedAt;
  }

  struct Stat {
    uint[] orders;
    uint rateSum;
    uint rateCount; // averageRate = rateSum / rateCount
    mapping (uint => Review) reviews; // mapping orderId => Stat
  }

  struct Review {
    uint8 rate; // Range between 1-5
    string text;
    uint createdAt;
  }

  /**
   * @dev Constructor.
   * @param _oslikToken OSLIK Token (OT) address (ERC20 compatible token).
   * @param _oslikiFoundation Address of the Osliki Foundation.
   */
  function Osliki(
    ERC20 _oslikToken,
    address _oslikiFoundation
  ) public {

    require(address(_oslikToken) != address(0));
    require(_oslikiFoundation != address(0));

    oslikToken = _oslikToken;
    oslikiFoundation = _oslikiFoundation;

    // because default value of the invoiceId in all orders == 0
    invoices.push(Invoice({
      sender: 0x0,
      orderId: 0,
      prepayment: 0,
      deposit: 0,
      currency: EnumCurrency.ETH,
      expires: 0,
      depositHash: 0x0,
      status: EnumInvoiceStatus.New,
      createdAt: now,
      updatedAt: now
    }));
  }

  /**
   * @dev Pure function that calculates the fee of OSLIKI_FEE for transactions in ETH.
   * @param amount Amount of transaction.
   * @return Returns the amount of fee.
   */
  function getFee(uint amount) public pure returns (uint) {
    return amount.div(100).mul(OSLIKI_FEE);
  }

  /**
   * @dev A customer adds a new package delivery order.
   * @param from Geographic coordinate in 'lat,lon' format or Ethereum address '0x...'.
   * @param to Geographic coordinate in 'lat,lon' format or Ethereum address '0x...'.
   * @param params Package params in 'weight(kg),length(m),width(m),height(m)' format.
   * @param expires Expiration date of the order in SECONDS since Unix Epoch.
   * @param message Free form message text.
   */
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

  /**
   * @dev A carrier adds a new offer. (optional)
   * @param orderId Id of the order.
   * @param message Free form message text.
   */
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
      respond: "",
      createdAt: now,
      updatedAt: now
    }));

    uint offerId = offers.length - 1;

    order.offerIds.push(offerId);
    order.updatedAt = now;

    emit EventOffer(offerId, orderId);
  }

  /**
   * @dev The customer respond to the offer. (optional)
   * @param offerId Id of the offer.
   * @param message Free form message text.
   */
  function respond(
      uint offerId,
      string message
  ) public {

    Offer storage offer = offers[offerId];
    Order memory order = orders[offer.orderId];

    require(msg.sender == order.customer);
    require(bytes(offer.respond).length == 0); // can respond only once
    require(bytes(message).length != 0);

    offer.respond = message;
    offer.updatedAt = now;

    emit EventRespond(offerId);
  }

  /**
   * @dev The carrier adds a new invoice.
   * @param orderId Id of the order.
   * @param prepayment Amount for the prepayment.
   * @param deposit Amount for the deposit.
   * @param expires Expiration date of the invoice in SECONDS since Unix Epoch.
   * @param currency Invoice currency can be either 0 (ETH) or 1 (OSLIK Token).
   */
  function addInvoice(
    uint orderId,
    uint prepayment,
    uint deposit,
    EnumCurrency currency,
    uint expires
  ) public {

    Order memory order = orders[orderId];

    require(order.customer != msg.sender); // the customer can't be a carrier at the same time (for stats and reviews)
    require(now <= order.expires); // expired order

    invoices.push(Invoice({
      sender: msg.sender,
      orderId: orderId,
      prepayment: prepayment,
      deposit: deposit,
      currency: currency,
      expires: expires,
      depositHash: 0x0,
      status: EnumInvoiceStatus.New,
      createdAt: now,
      updatedAt: now
    }));

    uint invoiceId = invoices.length - 1;

    emit EventInvoice(invoiceId, orderId);
  }

  /**
   * @dev The customer pays the invoice.
   * @param invoiceId Id of the invoice.
   * @param depositHash Ethereum-SHA-3 (Keccak-256) hash of the deposit key string provided by the customer.
   */
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

    require(now <= invoice.expires); // can't pay invoices in a few years and change the statuses

    require(order.carrier == 0); // carrier haven't been assigned yet
    require(order.invoiceId == 0); // double check, so impossible to change carriers in the middle of the process
    require(order.customer == msg.sender); // can't pay for someone else's orders
    require(order.status == EnumOrderStatus.New); // can't pay already processed orders

    require(invoice.sender != msg.sender); // ??? double check, the customer can't be a carrier at the same time (for stats and reviews)
    require(invoice.status == EnumInvoiceStatus.New); // can't pay already paid invoices

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

    } else if (invoice.currency == EnumCurrency.OSLIK) { // no fee

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

  /**
   * @dev The carrier fulfills the order and withdraws deposit (if any).
   * @param orderId Id of the invoice.
   * @param depositKey Deposit key string provided by the customer.
   */
  function fulfill(
    uint orderId,
    string depositKey
  ) public {

    Order storage order = orders[orderId];
    Invoice storage invoice = invoices[order.invoiceId];

    require(order.carrier == msg.sender); // only carrier
    require(invoice.sender == msg.sender); // just in case
    require(order.status == EnumOrderStatus.Process);
    require(invoice.status == EnumInvoiceStatus.Settled); // double check
    require(invoice.depositHash == 0x0 || invoice.depositHash == keccak256(depositKey)); // depositHash can be empty

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

      } else if (invoice.currency == EnumCurrency.OSLIK) { // no fee

        uint balanceOfBefore = oslikToken.balanceOf(addressThis);

        oslikToken.safeTransfer(invoice.sender, deposit);

        uint balanceOfAfter = oslikToken.balanceOf(addressThis);
        assert(balanceOfAfter == balanceOfBefore.sub(deposit));
      }
    }

    emit EventFulfill(orderId);
  }

  /**
   * @dev The carrier refunds the amount paid by the customer for the order.
   * @param invoiceId Id of the invoice.
   */
  function refund(
    uint invoiceId
  ) public payable {

    Invoice storage invoice = invoices[invoiceId];
    Order storage order = orders[invoice.orderId];

    require(invoice.sender == msg.sender);
    require(invoice.status == EnumInvoiceStatus.Settled || invoice.status == EnumInvoiceStatus.Closed);

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

    } else if (invoice.currency == EnumCurrency.OSLIK) {

      require(msg.value == 0); // prevent loss of ETH

      uint balanceOfBefore = oslikToken.balanceOf(addressThis);

      if (amountFromCarrier != 0) {
        oslikToken.safeTransferFrom(msg.sender, order.customer, amountFromCarrier);
      }

      if (amountFromContract != 0) {
        oslikToken.safeTransfer(order.customer, amountFromContract);
      }

      uint balanceOfAfter = oslikToken.balanceOf(addressThis);
      assert(balanceOfAfter == balanceOfBefore.sub(amountFromContract));
    }

    emit EventRefund(invoiceId);
  }

  /**
   * @dev The parties leave comments and ratings about their experience.
   * @param orderId Id of the order.
   * @param rate Rating form 1-5.
   * @param text Free form text.
   */
  function addReview(
    uint orderId,
    uint8 rate,
    string text
  ) public {

    Order memory order = orders[orderId];

    Stat storage stat = stats[msg.sender == order.customer ? order.carrier : order.customer];
    Review storage review = stat.reviews[orderId];

    require(msg.sender == order.customer || msg.sender == order.carrier);
    require(order.status == EnumOrderStatus.Process || order.status == EnumOrderStatus.Fulfilled);
    require(review.rate == 0); // can rate only once
    require(1 <= rate && rate <= 5);

    review.rate = rate;
    review.text = text;
    review.createdAt = now;

    stat.rateSum = stat.rateSum.add(rate);
    stat.rateCount++;

    emit EventReview(orderId, msg.sender);
  }

  /**
   * @dev Allows to withdraw the collected fees in favor of Osliki Foundation.
   */
  function withdrawFees() public {
    require(msg.sender == oslikiFoundation && fees != 0);

    uint feesToWithdraw = fees;

    fees = 0;

    oslikiFoundation.transfer(feesToWithdraw);

    emit EventWithdrawFees(feesToWithdraw);
  }

  /**GETTERS*/

  /**
   * @dev Retrieves the count of all orders.
   * @return Count of orders.
   */
  function getOrdersCount() public view returns (uint) {
    return orders.length;
  }

  /**
   * @dev Retrieves the count of all offers.
   * @return Count of offers.
   */
  function getOffersCount() public view returns (uint) {
    return offers.length;
  }

  /**
   * @dev Retrieves the count of offers for an order.
   * @param orderId Id of an order.
   * @return Count of offers.
   */
  function getOrderOffersCount(uint orderId) public view returns (uint) {
    return orders[orderId].offerIds.length;
  }

  /**
   * @dev Retrieves the offer id of an order by index.
   * @param orderId Id of the order.
   * @param index Index of the order.
   * @return Id of the offer.
   */
  function getOrderOffer(uint orderId, uint index) public view returns (uint) {
    return orders[orderId].offerIds[index];
  }

  /**
   * @dev Retrieves the count of all invoices.
   * @return Count of offers.
   */
  function getInvoicesCount() public view returns (uint) {
    return invoices.length;
  }

  /**
   * @dev Retrieves the stats of an user.
   * @param user Address of the user.
   * @return ordersCount Count of all orders the user has ever participated.
   * @return rateSum Sum of all ratings.
   * @return rateCount Count of all ratings.
   */
  function getStat(address user) public view returns(uint ordersCount, uint rateSum, uint rateCount) {
      Stat memory stat = stats[user];

      ordersCount = stat.orders.length;
      rateSum = stat.rateSum;
      rateCount = stat.rateCount;
  }

  /**
   * @dev Retrieves the id of an order by user and index.
   * @param user Address of the user.
   * @param index Index of the order.
   * @return Id of the order.
   */
  function getUserOrders(address user, uint index) public view returns(uint) {
      return stats[user].orders[index];
  }

  /**
   * @dev Retrieves the review of an user given for the order.
   * @param user Address of the user.
   * @param orderId Id of the order.
   * @return rate Given rate.
   * @return text Review text.
   * @return createdAt Creation timestamp (seconds).
   */
  function getReview(address user, uint orderId) public view returns(uint8 rate, string text, uint createdAt) {
      Review memory review = stats[user].reviews[orderId];

      rate = review.rate;
      text = review.text;
      createdAt = review.createdAt;
  }
}
