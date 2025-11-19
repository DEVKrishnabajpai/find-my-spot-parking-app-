import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:parking_app/screens/nearbyparkings.dart';

class ParkingTimeScreen extends StatefulWidget {
  const ParkingTimeScreen({super.key});

  @override
  State<ParkingTimeScreen> createState() => _ParkingTimeScreenState();
}

class _ParkingTimeScreenState extends State<ParkingTimeScreen> {
  DateTime? selectedDate;
  TimeOfDay? fromTime;
  TimeOfDay? toTime;

  String formatDate(DateTime date) =>
      DateFormat('EEE, dd MMM yyyy').format(date);

  String formatTime(TimeOfDay time) {
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    return DateFormat.jm().format(dt);
  }

  // --- Pickers ---
  Future<void> pickDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
    );
    if (date != null) setState(() => selectedDate = date);
  }

  Future<void> pickTime({required bool isFrom}) async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time != null) {
      setState(() {
        if (isFrom) {
          fromTime = time;
        } else {
          toTime = time;
        }
      });
    }
  }

  // --- Validate + Navigate ---
  void searchAvailability() {
    if (selectedDate == null || fromTime == null || toTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select all fields!')),
      );
      return;
    }

    final fromMinutes = fromTime!.hour * 60 + fromTime!.minute;
    final toMinutes = toTime!.hour * 60 + toTime!.minute;
    if (toMinutes <= fromMinutes) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End time must be after start time!')),
      );
      return;
    }

    // 
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => NearbyParkingScreen(
          selectedDate: selectedDate!,
          fromTime: fromTime!,
          toTime: toTime!,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff5f7fa),
      body: Column(
        children: [
         
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(
              top: 60,
              bottom: 30,
              left: 16,
              right: 16,
            ),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xff0072ff), Color(0xff00c6ff)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                
                IconButton(
                  icon: const Icon(
                    Icons.arrow_back,
                    color: Colors.white,
                    size: 26,
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                ),
                const SizedBox(width: 10),

                // 🏷 Title
                const Expanded(
                  child: Center(
                    child: Text(
                      'Select Parking Date & Time',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 48), // To balance layout
              ],
            ),
          ),

          const SizedBox(height: 30),

          // --- Main body ---
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  // Date Card
                  _buildInputCard(
                    title: "Select Date",
                    icon: Icons.calendar_today,
                    value: selectedDate == null
                        ? "No date selected"
                        : formatDate(selectedDate!),
                    onTap: pickDate,
                  ),

                  const SizedBox(height: 20),

                  // From Time Card
                  _buildInputCard(
                    title: "From Time",
                    icon: Icons.access_time,
                    value: fromTime == null
                        ? "No start time"
                        : formatTime(fromTime!),
                    onTap: () => pickTime(isFrom: true),
                  ),

                  const SizedBox(height: 20),

                  // To Time Card
                  _buildInputCard(
                    title: "To Time",
                    icon: Icons.access_time_filled,
                    value:
                        toTime == null ? "No end time" : formatTime(toTime!),
                    onTap: () => pickTime(isFrom: false),
                  ),

                  const SizedBox(height: 40),

                  // Search Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: searchAvailability,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xff0072ff),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        elevation: 3,
                      ),
                      child: const Text(
                        'Search Availability',
                        style: TextStyle(fontSize: 18, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Reusable UI card widget ---
  Widget _buildInputCard({
    required String title,
    required IconData icon,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.blueAccent, size: 26),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 18, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
