pragma solidity ^0.4.21;
//pragma experimental ABIEncoderV2;
import '../node_modules/zeppelin-solidity/contracts/math/SafeMath.sol';

contract Osliki {
  using SafeMath for uint;

  function Osliki() public {
    // plug for invoices[0] cos default invoiceId in all orders == 0
    invoices.push(Invoice({
      carrier: 0x0,
      orderId: 0,
      prepayment: 0,
      deposit: 0,
      currency: EnumCurrency.OSLIK,
      depositHash: 0x0,
      status: EnumInvoiceStatus.New,
      createdAt: block.number,
      updatedAt: block.number
    }));
  }

  address oslikToken = 0x0;

  Order[] public orders;
  Offer[] public offers;
  Invoice[] public invoices;

  enum EnumOrderStatus { New, Process, Fulfilled }
  enum EnumInvoiceStatus { New, Prepaid, Paid }
  enum EnumCurrency { ETH, OSLIK }

  event NewOrder(uint orderId);
  event NewOffer(uint offerId, uint orderId);
  event NewInvoice(uint invoiceId, uint orderId);
  event PrePayment(uint invoiceId);

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
    address carrier;
    uint orderId;
    uint prepayment;
    uint deposit;
    EnumCurrency currency;
    bytes32 depositHash;
    EnumInvoiceStatus status;
    uint createdAt;
    uint updatedAt;
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
      createdAt: block.number,
      updatedAt: block.number
    }));

    uint orderId = orders.length -1;

    emit NewOrder(orderId);
  }

  function addOffer(
      uint orderId,
      string message
  ) public {
    offers.push(Offer({
      carrier: msg.sender,
      orderId: orderId,
      message: message
    }));

    uint offerId = offers.length - 1;

    orders[orderId].offerIds.push(offerId);
    orders[orderId].updatedAt = block.number;

    emit NewOffer(offerId, orderId);
  }

  /* @ToDo: check possible issues with invoices[0] */
  function addInvoice(
    uint orderId,
    uint prepayment,
    uint deposit,
    EnumCurrency currency
  ) public {
    invoices.push(Invoice({
      carrier: msg.sender,
      orderId: orderId,
      prepayment: prepayment,
      deposit: deposit,
      currency: currency,
      depositHash: '',
      status: EnumInvoiceStatus.New,
      createdAt: block.number,
      updatedAt: block.number
    }));

    uint invoiceId = invoices.length - 1;

    emit NewInvoice(invoiceId, orderId);
  }

  function pay(
    uint invoiceId,
    uint prepayment,
    uint deposit,
    bytes32 depositHash
  ) public payable {
    Invoice memory invoice = invoices[invoiceId];
    Order memory order = orders[invoice.orderId];

    uint amount = prepayment.add(deposit);

    require(order.customer == msg.sender); // can't pay for someone else's orders
    require(order.status == EnumOrderStatus.New); // can't pay already processed orders
    require(invoice.status == EnumInvoiceStatus.New); // can't pay already paid invoices
    //require(!(invoice.currency == EnumCurrency.OSLIK && msg.value != 0)); // prevent loss of ETH
    //require(!(invoice.currency == EnumCurrency.ETH && msg.value != amount)); // not enough funds

    if (invoice.currency == EnumCurrency.ETH) {
      require(msg.value != amount); // not enough funds

      if (prepayment != 0) {
        invoice.carrier.transfer(prepayment);
        invoice.status = EnumInvoiceStatus.Prepaid;
        emit PrePayment(invoiceId);
      }
    }

    if (invoice.currency == EnumCurrency.OSLIK) {
      require(msg.value != 0); // prevent loss of ETH


    }
  }

//address.transfer(amountEther)

  function getOrdersCount() public view returns (uint) {
    return orders.length;
  }

  function getOffersCount() public view returns (uint) {
    return offers.length;
  }

  function getOrderOffersCount(uint orderId) public view returns (uint) {
    return orders[orderId].offerIds.length;
  }

  function getInvoicesCount() public view returns (uint) {
    return invoices.length;
  }
}
