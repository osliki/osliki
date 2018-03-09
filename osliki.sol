pragma solidity ^0.4.20;

contract Osliki {

    Order[] public orders;
    Offer[] public offers;
    Invoice[] public invoices;

    function Osliki() public {
        /*invoices[0] = Invoice({
            carrier: 0x0,
            orderId: 0,
            prepayment: 0,
            deposit: 0,
            depositHash: '',
            status: EnumInvoiceStatus.New
        });*/
    }

    /*struct Location {
        string lat;
        string lon;
        address addr;
    }

    struct CargoParams {
        uint weight;
        uint height;
        uint width;
        uint long;
        uint count;
    }*/

    struct Offer {
        address carrier;
        uint orderId;
        string message;
    }

    enum EnumOrderStatus { New, Process, Fulfilled }

    struct Order {
       address customer;

        string from;
        string to;
        uint[4] params;
        string message;

        uint[] offerIds;

        //Invoice[] invoices;
        address carrier;
        uint invoiceId;

        EnumOrderStatus status;
        uint256 createdAt;
        uint256 updatedAt;
    }

    enum EnumInvoiceStatus { New, Prepaid, Paid }

    struct Invoice {
        address carrier;
        uint orderId;
        uint prepayment;
        uint deposit;
        bytes32 depositHash;
        EnumInvoiceStatus status;
    }

    event NewOrder(uint);

    /*  params[0] - weight (kg)
        params[1] - lenght (m)
        params[2] - width (m)
        params[3] - height (m)    */
    function addOrder(
        string from,
        string to,
        uint[4] params,
        string message
    ) public returns (uint orderId) {
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

        orderId = orders.length - 1;

        emit NewOrder(orderId);
    }

    event NewOffer(uint, uint);

    function addOffer(
        uint orderId,
        string message
    ) public returns (uint offerId) {
        offers.push(Offer({
            carrier: msg.sender,
            orderId: orderId,
            message: message
        }));

        offerId = offers.length - 1;

        orders[orderId].offerIds.push(offerId);
        orders[orderId].updatedAt = block.number;

        emit NewOffer(orderId, offerId);
    }

    function getOrderOffers(uint orderId) public view returns (uint[]) {
        return orders[orderId].offerIds;
    }

}
