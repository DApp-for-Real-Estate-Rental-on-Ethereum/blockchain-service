pragma solidity ^0.8.24;

contract BookingPaymentContract {
    struct Booking {
        address guest;
        address host;
        uint256 rentAmount;
        uint256 depositAmount;
        bool completed;
        bool hasActiveReclamation;
        uint256 completedAt;
    }

    struct ReclamationRefund {
        uint256 bookingId;
        address recipient;
        uint256 refundAmount;
        uint256 penaltyAmount;
        bool processed;
    }

    address public constant PLATFORM_WALLET = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;
    uint256 public constant PLATFORM_FEE_PERCENT = 10;

    address public admin;
    mapping(uint256 => Booking) public bookings;
    mapping(uint256 => ReclamationRefund) public reclamationRefunds;

    bool private locked;

    event BookingPaymentCreated(
        uint256 indexed bookingId,
        address indexed guest,
        address indexed host,
        uint256 rentAmount,
        uint256 depositAmount
    );

    event BookingCompleted(
        uint256 indexed bookingId,
        address indexed host,
        address indexed guest,
        uint256 rentToHost,
        uint256 platformFee,
        uint256 depositToGuest
    );

    event BookingCancelled(
        uint256 indexed bookingId,
        address indexed guest,
        uint256 refundAmount
    );

    event AdminUpdated(address oldAdmin, address newAdmin);

    event ReclamationRefundProcessed(
        uint256 indexed bookingId,
        address indexed recipient,
        uint256 refundAmount,
        uint256 penaltyAmount
    );

    event PartialRefundProcessed(
        uint256 indexed bookingId,
        address indexed recipient,
        uint256 refundAmount,
        string reason
    );

    modifier onlyAdmin() {
        require(msg.sender == admin, "Not admin");
        _;
    }

    modifier bookingExists(uint256 bookingId) {
        require(bookings[bookingId].guest != address(0), "Booking not found");
        _;
    }

    modifier nonReentrant() {
        require(!locked, "Reentrant call");
        locked = true;
        _;
        locked = false;
    }

    constructor() {
        admin = msg.sender;
    }

    receive() external payable {}

    function createBookingPayment(
        uint256 bookingId,
        address host,
        address tenant,
        uint256 rentAmount,
        uint256 depositAmount
    ) external payable {
        require(bookings[bookingId].guest == address(0), "Booking already exists");
        require(host != address(0), "Invalid host address");
        require(tenant != address(0), "Invalid tenant address");
        require(rentAmount > 0, "Rent amount must be > 0");
        require(msg.value == rentAmount + depositAmount, "Incorrect ETH amount sent");
        require(host != tenant, "Host and tenant cannot be the same");
        require(msg.sender == tenant, "Caller must be tenant");

        bookings[bookingId] = Booking({
            guest: tenant,
            host: host,
            rentAmount: rentAmount,
            depositAmount: depositAmount,
            completed: false,
            hasActiveReclamation: false,
            completedAt: 0
        });

        emit BookingPaymentCreated(
            bookingId,
            tenant,
            host,
            rentAmount,
            depositAmount
        );
    }

    function completeBooking(uint256 bookingId)
        external
        bookingExists(bookingId)
        nonReentrant
    {
        Booking storage booking = bookings[bookingId];

        require(!booking.completed, "Booking already completed");
        require(
            msg.sender == booking.host || msg.sender == admin,
            "Only host or admin can complete"
        );
        require(
            !booking.hasActiveReclamation || msg.sender == admin,
            "Active reclamation"
        );

        uint256 rentAmount = booking.rentAmount;
        uint256 depositAmount = booking.depositAmount;
        uint256 totalAmount = rentAmount + depositAmount;

        require(totalAmount > 0, "No funds to distribute");
        require(address(this).balance >= totalAmount, "Insufficient contract balance");

        uint256 platformFee = 0;
        
        if (!booking.hasActiveReclamation) {
            platformFee = (rentAmount * PLATFORM_FEE_PERCENT) / 100;
            
            booking.rentAmount = rentAmount - platformFee;
            
            booking.completedAt = block.timestamp;
        } else {
            require(totalAmount > 0, "No funds to hold");
            booking.completedAt = block.timestamp;
        }
        
        booking.completed = true;

        if (!booking.hasActiveReclamation) {
            if (platformFee > 0) {
                (bool feeOk, ) = PLATFORM_WALLET.call{value: platformFee}("");
                require(feeOk, "Platform fee transfer failed");
            }
        }

        emit BookingCompleted(
            bookingId,
            booking.host,
            booking.guest,
            0,
            platformFee,
            0
        );
    }

    function cancelBooking(uint256 bookingId)
        external
        bookingExists(bookingId)
        nonReentrant
    {
        Booking storage booking = bookings[bookingId];

        require(!booking.completed, "Booking already completed");
        require(
            msg.sender == booking.guest || msg.sender == admin,
            "Only guest or admin can cancel"
        );

        uint256 refundAmount = booking.rentAmount + booking.depositAmount;
        require(refundAmount > 0, "Nothing to refund");

        booking.rentAmount = 0;
        booking.depositAmount = 0;
        booking.completed = true;
        booking.completedAt = 0;

        (bool ok, ) = booking.guest.call{value: refundAmount}("");
        require(ok, "Refund failed");

        emit BookingCancelled(bookingId, booking.guest, refundAmount);
    }

    function getBooking(uint256 bookingId)
        external
        view
        returns (
            address,
            address,
            uint256,
            uint256
        )
    {
        Booking storage booking = bookings[bookingId];
        require(booking.guest != address(0), "Booking not found");

        return (
            booking.guest,
            booking.host,
            booking.rentAmount,
            booking.depositAmount
        );
    }

    function bookingExistsCheck(uint256 bookingId)
        external
        view
        returns (bool)
    {
        return bookings[bookingId].guest != address(0);
    }

    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }

    function transferAdmin(address newAdmin) external onlyAdmin {
        require(newAdmin != address(0), "Invalid admin address");
        require(newAdmin != admin, "Same admin");
        address oldAdmin = admin;
        admin = newAdmin;
        emit AdminUpdated(oldAdmin, newAdmin);
    }

    function emergencyWithdraw() external onlyAdmin nonReentrant {
        uint256 balance = address(this).balance;
        require(balance > 0, "No balance");
        (bool success, ) = admin.call{value: balance}("");
        require(success, "Withdraw failed");
    }

    function processReclamationRefund(
        uint256 bookingId,
        address recipient,
        uint256 refundAmount,
        uint256 penaltyAmount,
        bool refundFromRent
    ) external onlyAdmin bookingExists(bookingId) nonReentrant {
        Booking storage booking = bookings[bookingId];
        require(booking.completed, "Booking not completed");
        require(booking.hasActiveReclamation, "No active reclamation");

        ReclamationRefund storage r = reclamationRefunds[bookingId];
        require(!r.processed, "Refund already processed");

        uint256 totalRequired = refundAmount + penaltyAmount;
        require(totalRequired > 0, "Nothing to process");
        require(address(this).balance >= totalRequired, "Insufficient contract balance");

        if (refundFromRent) {
            uint256 rentNeeded = refundAmount;
            uint256 depositNeeded = 0;
            
            if (booking.rentAmount < refundAmount) {
                rentNeeded = booking.rentAmount;
                depositNeeded = refundAmount - booking.rentAmount;
                require(booking.depositAmount >= depositNeeded, "Insufficient deposit for refund");
            } else {
                require(booking.rentAmount >= refundAmount, "Insufficient rent for refund");
            }
            
            if (rentNeeded > 0) {
                booking.rentAmount -= rentNeeded;
            }
            if (depositNeeded > 0) {
                booking.depositAmount -= depositNeeded;
            }
        } else {
            require(booking.rentAmount >= refundAmount, "Insufficient rent for host");
            require(booking.depositAmount >= penaltyAmount, "Insufficient deposit for penalty");
            
            booking.rentAmount -= refundAmount;
            booking.depositAmount -= penaltyAmount;
        }

        if (refundAmount > 0) {
            (bool refundOk, ) = recipient.call{value: refundAmount}("");
            require(refundOk, "Refund transfer failed");
        }

        if (penaltyAmount > 0) {
            (bool penaltyOk, ) = PLATFORM_WALLET.call{value: penaltyAmount}("");
            require(penaltyOk, "Penalty transfer failed");
        }

        r.bookingId = bookingId;
        r.recipient = recipient;
        r.refundAmount = refundAmount;
        r.penaltyAmount = penaltyAmount;
        r.processed = true;

        booking.hasActiveReclamation = false;

        emit ReclamationRefundProcessed(bookingId, recipient, refundAmount, penaltyAmount);
    }

    function processPartialRefund(
        uint256 bookingId,
        address recipient,
        uint256 refundAmount,
        bool refundFromRent
    ) external onlyAdmin bookingExists(bookingId) nonReentrant {
        Booking storage booking = bookings[bookingId];

        require(booking.hasActiveReclamation, "No active reclamation");
        require(refundAmount > 0, "Refund must be > 0");

        if (refundFromRent) {
            require(booking.rentAmount >= refundAmount, "Insufficient rent amount");
            booking.rentAmount -= refundAmount;
        } else {
            require(booking.depositAmount >= refundAmount, "Insufficient deposit amount");
            booking.depositAmount -= refundAmount;
        }

        require(address(this).balance >= refundAmount, "Insufficient contract balance");

        (bool ok, ) = recipient.call{value: refundAmount}("");
        require(ok, "Partial refund transfer failed");

        emit PartialRefundProcessed(bookingId, recipient, refundAmount, "Reclamation refund");
    }

    function setActiveReclamation(uint256 bookingId, bool active)
        external
        onlyAdmin
        bookingExists(bookingId)
    {
        bookings[bookingId].hasActiveReclamation = active;
    }

    function getReclamationRefund(uint256 bookingId)
        external
        view
        returns (
            address,
            uint256,
            uint256,
            bool
        )
    {
        ReclamationRefund storage refund = reclamationRefunds[bookingId];
        return (
            refund.recipient,
            refund.refundAmount,
            refund.penaltyAmount,
            refund.processed
        );
    }

    function getBookingWithReclamation(uint256 bookingId)
        external
        view
        returns (
            address,
            address,
            uint256,
            uint256,
            bool,
            bool
        )
    {
        Booking storage booking = bookings[bookingId];
        require(booking.guest != address(0), "Booking not found");
        return (
            booking.guest,
            booking.host,
            booking.rentAmount,
            booking.depositAmount,
            booking.completed,
            booking.hasActiveReclamation
        );
    }
}
