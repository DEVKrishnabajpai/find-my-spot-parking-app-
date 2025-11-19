import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

class PaymentConfirmationScreen extends StatefulWidget {
  final Map<String, dynamic> spot;
  final DateTime selectedDate;
  final TimeOfDay fromTime;
  final TimeOfDay toTime;

  const PaymentConfirmationScreen({
    super.key,
    required this.spot,
    required this.selectedDate,
    required this.fromTime,
    required this.toTime,
  });

  @override
  State<PaymentConfirmationScreen> createState() =>
      _PaymentConfirmationScreenState();
}

class _PaymentConfirmationScreenState extends State<PaymentConfirmationScreen> {
  String paymentMethod = 'Online';
  bool _isProcessing = false;

  late Razorpay razorpay;

  @override
  void initState() {
    super.initState();

    razorpay = Razorpay();

    razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccessResponse);
    razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentErrorResponse);
    razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWalletSelected);
  }

  @override
  void dispose() {
    razorpay.clear();
    super.dispose();
  }

  String formatDate(DateTime date) =>
      DateFormat('EEE, dd MMM yyyy').format(date);

  String formatTime(TimeOfDay time) {
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    return DateFormat.jm().format(dt);
  }

  void _openCheckout(double amount) {
    var options = {
      'key': 'rzp_test_Rh9FO6nQUyzXKP',
      'amount': (amount * 100).toInt(),
      'name': 'Parking App',
      'description': 'Parking Booking Payment',
      'prefill': {'contact': 9878906654, 'email': 'test@example.com'},
      'external': {
        'wallets': ['paytm'],
      },
    };

    razorpay.open(options);
  }

  Future<void> confirmBooking() async {
    if (paymentMethod == 'Online') {
      final hours =
          (widget.toTime.hour + widget.toTime.minute / 60.0) -
          (widget.fromTime.hour + widget.fromTime.minute / 60.0);
      final rate = (widget.spot['rate'] ?? 0).toDouble();
      final totalAmount = rate * hours;

      _openCheckout(totalAmount);
      return;
    }

    _createFirestoreBooking('pending');
  }

  Future<void> _createFirestoreBooking(String paymentStatus) async {
    setState(() => _isProcessing = true);

    try {
      final fromDateTime = DateTime(
        widget.selectedDate.year,
        widget.selectedDate.month,
        widget.selectedDate.day,
        widget.fromTime.hour,
        widget.fromTime.minute,
      );

      final toDateTime = DateTime(
        widget.selectedDate.year,
        widget.selectedDate.month,
        widget.selectedDate.day,
        widget.toTime.hour,
        widget.toTime.minute,
      );

      final hours =
          (widget.toTime.hour + widget.toTime.minute / 60.0) -
          (widget.fromTime.hour + widget.fromTime.minute / 60.0);
      final rate = (widget.spot['rate'] ?? 0).toDouble();
      final totalAmount = (rate * hours).toStringAsFixed(2);

      final userId = FirebaseAuth.instance.currentUser?.uid ?? 'unknown';

      await FirebaseFirestore.instance
          .collection('parking_spaces')
          .doc(widget.spot['id'])
          .collection('bookings')
          .add({
            'from': fromDateTime,
            'to': toDateTime,
            'date': widget.selectedDate,
            'userId': userId,
            'status': 'confirmed',
            'paymentMode': paymentMethod,
            'paymentStatus': paymentStatus,
            'totalAmount': totalAmount,
            'createdAt': Timestamp.now(),
          });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Booking confirmed successfully!')),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }

    setState(() => _isProcessing = false);
  }

  void _handlePaymentSuccessResponse(PaymentSuccessResponse response) {
    _createFirestoreBooking('paid');
  }

  void _handlePaymentErrorResponse(PaymentFailureResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Payment Failed: ${response.message}')),
    );
  }

  void _handleExternalWalletSelected(ExternalWalletResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('External Wallet: ${response.walletName}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hours =
        (widget.toTime.hour + widget.toTime.minute / 60.0) -
        (widget.fromTime.hour + widget.fromTime.minute / 60.0);
    final rate = (widget.spot['rate'] ?? 0).toDouble();
    final totalAmount = rate * hours;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Confirm Booking"),
        backgroundColor: const Color(0xff0072ff),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Booking Details",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),

            _buildInfoRow("Location", widget.spot['street'] ?? 'Unknown'),
            _buildInfoRow("Date", formatDate(widget.selectedDate)),
            _buildInfoRow(
              "Time",
              "${formatTime(widget.fromTime)} - ${formatTime(widget.toTime)}",
            ),
            _buildInfoRow("Rate", "₹${widget.spot['rate']}/hour"),

            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Total Amount",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    "₹${totalAmount.toStringAsFixed(2)}",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 30),

            const Text(
              "Select Payment Method",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),

            RadioListTile<String>(
              title: const Text("Online Payment"),
              value: "Online",
              groupValue: paymentMethod,
              onChanged: (value) => setState(() => paymentMethod = value!),
            ),

            RadioListTile<String>(
              title: const Text("Cash"),
              value: "COD",
              groupValue: paymentMethod,
              onChanged: (value) => setState(() => paymentMethod = value!),
            ),
            const SizedBox(height: 180),

            Padding(
              padding: EdgeInsets.only(bottom: 5),
              child: Text("*No money would be deducted from your account"),
            ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isProcessing ? null : confirmBooking,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xff0072ff),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child:
                    _isProcessing
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                          'Confirm Booking',
                          style: TextStyle(fontSize: 18, color: Colors.white),
                        ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
