pragma solidity ^0.4.21;
pragma experimental ABIEncoderV2;

contract Osliki {

    Order[] public orders;
    Offer[] public offers;
    Invoice[] public invoices;

    enum EnumOrderStatus { New, Process, Fulfilled }
    enum EnumInvoiceStatus { New, Prepaid, Paid }

    event NewOrder(uint orderId);
    event NewOffer(uint offerId, uint orderId);
    event NewInvoice(uint invoiceId);

    function Osliki() public {

    }

    struct Offer {
        address carrier;
        uint orderId;
        string message;
    }

    struct Order {
       address customer;

        string from;
        string to;
        uint[4] params;
        string message;

        uint[] offerIds;

        address carrier;
        uint invoiceId;

        EnumOrderStatus status;
        uint256 createdAt;
        uint256 updatedAt;
    }

    struct Invoice {
        address carrier;
        uint orderId;
        uint prepayment;
        uint deposit;
        bytes32 depositHash;
        EnumInvoiceStatus status;
    }

    /*  params[0] - weight (kg)
        params[1] - lenght (m)
        params[2] - width (m)
        params[3] - height (m)    */
    function addOrder(
        string from,
        string to,
        uint[4] params,
        string message
    ) public {
        orders.push(Order({
            customer: msg.sender,

            from: from,
            to: to,
            params: params,
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

    function getOrderOffers(uint orderId) public view returns (uint) {
        //uint[] memory orderOfferIds = orders[orderId].offerIds;
/*Offer[] memory orderOffers;
        for (uint i = 0; i < orderOfferIds.length; ++i) {
            orderOffers[i] = offers[orderOfferIds[i]];
        }*/

        //return orderOffers[0];
        return orders[orderId].offerIds[1];
    }
    /*function getOrderOffers(uint orderId) public view returns (uint[]) {
        return orders[orderId].offerIds;
    }*/
}
