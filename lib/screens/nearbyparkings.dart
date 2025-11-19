import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:parking_app/screens/parkingdetails.dart';

class NearbyParkingScreen extends StatefulWidget {
  final DateTime selectedDate;
  final TimeOfDay fromTime;
  final TimeOfDay toTime;

  const NearbyParkingScreen({
    super.key,
    required this.selectedDate,
    required this.fromTime,
    required this.toTime,
  });

  @override
  State<NearbyParkingScreen> createState() => _NearbyParkingScreenState();
}

class _NearbyParkingScreenState extends State<NearbyParkingScreen> {
  GoogleMapController? _mapController;
  LatLng? _userLocation;
  bool _isLoading = true;
  List<Map<String, dynamic>> nearby = [];

  @override
  void initState() {
    super.initState();
    _loadNearbyParkings();
  }

  Future<void> _loadNearbyParkings() async {
    try {
      // Get user’s last parking need (current location)
      final user = FirebaseFirestore.instance;
      final userSnapshot =
          await user
              .collection('parking_needs')
              .orderBy('timestamp', descending: true)
              .where(
                'ownerId',
                isEqualTo: FirebaseAuth.instance.currentUser!.uid,
              )
              .limit(1)
              .get();

      if (userSnapshot.docs.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No user location found')));
        setState(() => _isLoading = false);
        return;
      }

      final userData = userSnapshot.docs.first.data();
      final double userLat = userData['latitude'];
      final double userLng = userData['longitude'];
      final String userCity = userData['city'];
      _userLocation = LatLng(userLat, userLng);

      // Combine user’s selected date + time
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

      // Fetch available parking spaces
      final parkingSnapshot =
          await FirebaseFirestore.instance
              .collection('parking_spaces')
              .where('availstatus', isEqualTo: 'available')
              .get();

      List<Map<String, dynamic>> tempList = [];

      // Check each parking spot
      for (var doc in parkingSnapshot.docs) {
        final data = doc.data();

        if (data['latitude'] == null || data['longitude'] == null) continue;

        final spotId = doc.id;

        // Get bookings for this date
        final bookingsSnapshot =
            await FirebaseFirestore.instance
                .collection('parking_spaces')
                .doc(spotId)
                .collection('bookings')
                .where(
                  'date',
                  isEqualTo: Timestamp.fromDate(
                    DateTime(
                      widget.selectedDate.year,
                      widget.selectedDate.month,
                      widget.selectedDate.day,
                    ),
                  ),
                )
                .get();

        bool isAvailable = true;

        for (var booking in bookingsSnapshot.docs) {
          final bookingData = booking.data();
          final bookedFrom = (bookingData['from'] as Timestamp).toDate();
          final bookedTo = (bookingData['to'] as Timestamp).toDate();

          // Overlap condition
          final overlaps =
              fromDateTime.isBefore(bookedTo) && toDateTime.isAfter(bookedFrom);

          if (overlaps) {
            isAvailable = false;
            break;
          }
        }

        // Add only if in same city and available
        if (isAvailable && data['city'] == userCity) {
          final double dist = Geolocator.distanceBetween(
            userLat,
            userLng,
            data['latitude'],
            data['longitude'],
          );
          data['distance'] = dist;
          data['id'] = spotId;
          tempList.add(data);
        }
      }

      // Sort by distance
      tempList.sort((a, b) => a['distance'].compareTo(b['distance']));
      nearby = tempList.take(10).toList();

      setState(() => _isLoading = false);
    } catch (e) {
      print('Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading nearby parkings: $e')),
      );
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Nearby Parking Spots"),
        backgroundColor: const Color(0xff0072ff),
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _userLocation == null
              ? const Center(child: Text("User location not found"))
              : Column(
                children: [
                  // Map Section
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.4,
                    child: GoogleMap(
                      onMapCreated: (controller) {
                        _mapController = controller;
                      },
                      initialCameraPosition: CameraPosition(
                        target: _userLocation!,
                        zoom: 14,
                      ),
                      markers: {
                        Marker(
                          markerId: const MarkerId('user'),
                          position: _userLocation!,
                          infoWindow: const InfoWindow(title: 'You'),
                          icon: BitmapDescriptor.defaultMarkerWithHue(
                            BitmapDescriptor.hueAzure,
                          ),
                        ),
                        ...nearby.map((spot) {
                          return Marker(
                            markerId: MarkerId(spot['id']),
                            position: LatLng(
                              spot['latitude'],
                              spot['longitude'],
                            ),
                            infoWindow: InfoWindow(
                              title: spot['street'] ?? 'Unknown Street',
                              snippet:
                                  '₹${spot['rate']}/hr • ${(spot['distance'] / 1000).toStringAsFixed(2)} km away',
                            ),
                          );
                        }).toSet(),
                      },
                    ),
                  ),

                  const SizedBox(height: 10),

                  // List Section
                  Expanded(
                    child: ListView.builder(
                      itemCount: nearby.length,
                      itemBuilder: (ctx, index) {
                        final spot = nearby[index];
                        return InkWell(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder:
                                    (context) => ParkingSpotDetailsPage(
                                      spot: spot,
                                      selectedDate: widget.selectedDate,
                                      fromTime: widget.fromTime,
                                      toTime: widget.toTime,
                                    
                                    ),
                              ),
                            );
                          },
                          child: Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              leading: const Icon(
                                Icons.local_parking_rounded,
                                color: Colors.deepPurple,
                                size: 32,
                              ),
                              title: Text(
                                spot['street'] ?? 'Unnamed Street',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                '${(spot['distance'] / 1000).toStringAsFixed(2)} km away • ₹${spot['rate']}/hr',
                              ),
                              trailing: const Icon(Icons.arrow_forward_ios),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
    );
  }
}
