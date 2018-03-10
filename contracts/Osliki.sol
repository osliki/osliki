pragma solidity ^0.4.21;
//pragma experimental ABIEncoderV2;

contract Osliki {
    function Osliki() public {

    }

    Order[] public orders;
    Offer[] public offers;
    Invoice[] public invoices;

    enum EnumOrderStatus { New, Process, Fulfilled }
    enum EnumInvoiceStatus { New, Prepaid, Paid }

    event NewOrder(uint orderId);
    event NewOffer(uint offerId, uint orderId);
    event NewInvoice(uint invoiceId);

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
        uint256 createdAt;
        uint256 updatedAt;
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
        bytes32 depositHash;
        EnumInvoiceStatus status;
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
