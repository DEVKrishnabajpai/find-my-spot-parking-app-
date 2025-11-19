import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:parking_app/screens/paymentsscreen.dart';

class ParkingSpotDetailsPage extends StatefulWidget {
  final Map<String, dynamic> spot;
  final DateTime selectedDate;
  final TimeOfDay fromTime;
  final TimeOfDay toTime;

  const ParkingSpotDetailsPage({
    required this.spot,
    required this.selectedDate,
    required this.fromTime,
    required this.toTime,
    super.key,
  });

  @override
  State<ParkingSpotDetailsPage> createState() =>
      _ParkingSpotDetailsPageState();
}

class _ParkingSpotDetailsPageState extends State<ParkingSpotDetailsPage> {
  LatLng? _userLocation;
  late LatLng _spotLocation;
  GoogleMapController? _mapController;
  bool _isFetchingLocation = true;
  double? _distanceKm;

  @override
  void initState() {
    super.initState();
    _spotLocation = LatLng(widget.spot['latitude'], widget.spot['longitude']);
    _getUserLocation();
  }

  // Get current user location
  Future<void> _getUserLocation() async {
    try {
      final permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission denied')),
        );
        setState(() => _isFetchingLocation = false);
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final userLoc = LatLng(pos.latitude, pos.longitude);
      final distMeters = Geolocator.distanceBetween(
        pos.latitude,
        pos.longitude,
        widget.spot['latitude'],
        widget.spot['longitude'],
      );
      setState(() {
        _userLocation = userLoc;
        _distanceKm = distMeters / 1000;
        _isFetchingLocation = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error getting location: $e')),
      );
      setState(() => _isFetchingLocation = false);
    }
  }

  void _openInGoogleMaps() async {
    final Uri googleMapsUrl = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${widget.spot['latitude']},${widget.spot['longitude']}&travelmode=driving',
    );
    await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        elevation: 0,
        title: const Text(
          "Parking Spot Details",
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            //  LOCATION CARD
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.location_on,
                        color: Colors.blueAccent, size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "${widget.spot['houseNo']}, ${widget.spot['street']}, ${widget.spot['city']}",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // RATE CARD
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 3,
              child: ListTile(
                leading: const Icon(Icons.currency_rupee, color: Colors.green),
                title: Text(
                  "₹${widget.spot['rate']}/hr",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: const Text("Hourly Rate"),
              ),
            ),

            const SizedBox(height: 12),

            //  CONTACT CARD
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 3,
              child: ListTile(
                leading: const Icon(Icons.phone, color: Colors.orange),
                title: Text(
                  "${widget.spot['phone']}",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: const Text("Contact Number"),
                trailing: IconButton(
                  icon: const Icon(Icons.call, color: Colors.green),
                  onPressed: () {
                    final Uri phoneUri = Uri(
                      scheme: 'tel',
                      path: widget.spot['phone'],
                    );
                    launchUrl(phoneUri);
                  },
                ),
              ),
            ),

            const SizedBox(height: 12),

            //  GOOGLE MAP PREVIEW
            if (_isFetchingLocation)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_userLocation != null)
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 3,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: GestureDetector(
                    onTap: _openInGoogleMaps,
                    child: SizedBox(
                      height: 220,
                      child: GoogleMap(
                        onMapCreated: (controller) => _mapController = controller,
                        initialCameraPosition: CameraPosition(
                          target: _spotLocation,
                          zoom: 13.5,
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
                          Marker(
                            markerId: const MarkerId('spot'),
                            position: _spotLocation,
                            infoWindow:
                                const InfoWindow(title: 'Parking Spot'),
                          ),
                        },
                        zoomControlsEnabled: false,
                        myLocationEnabled: true,
                        myLocationButtonEnabled: false,
                      ),
                    ),
                  ),
                ),
              ),

            if (_distanceKm != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Approx. ${_distanceKm!.toStringAsFixed(2)} km away',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                  ),
                ),
              ),



            const SizedBox(height: 20),

            //  BOOK BUTTON
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => PaymentConfirmationScreen(
                      spot: widget.spot,
                      selectedDate: widget.selectedDate,
                      fromTime: widget.fromTime,
                      toTime: widget.toTime,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.book_online),
              label: const Text(
                "Book Now",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                backgroundColor: Colors.blueAccent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
