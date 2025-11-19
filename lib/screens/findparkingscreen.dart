import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:parking_app/screens/datetimeselector.dart';

class Findparkingscreen extends StatefulWidget {
  const Findparkingscreen({super.key});

  @override
  State<Findparkingscreen> createState() => _FindparkingscreenState();
}

class _FindparkingscreenState extends State<Findparkingscreen> {
  var locationMarked = false;
  late GoogleMapController _mapController;
  LatLng? _currentLocation;
  bool _isSubmitting = false;

  final _formKey = GlobalKey<FormState>();

  var _enteredStreet = '';
  String? _selectedCity;
  String _enteredPhone = "";
  double lt = 0.0;
  double ln = 0.0;

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location services are disabled.')),
      );
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission denied')),
        );
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location permission permanently denied')),
      );
      return;
    }

    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    setState(() {
      _currentLocation = LatLng(position.latitude, position.longitude);
    });

    _mapController.animateCamera(
      CameraUpdate.newLatLngZoom(_currentLocation!, 16),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Location marked: (${position.latitude}, ${position.longitude})',
        ),
      ),
    );
    locationMarked = true;
  }

  void _submitForm() async {
    setState(() {
      _isSubmitting = true;
    });

    if (!_formKey.currentState!.validate()) {
      setState(() {
        _isSubmitting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please fill the entries properly!',
            style: TextStyle(color: Colors.black),
          ),
          backgroundColor: Colors.red[100],
        ),
      );
      return;
    }

    _formKey.currentState!.save();

    if (locationMarked == true) {
      lt = _currentLocation!.latitude;
      ln = _currentLocation!.longitude;
      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(lt, ln);
        if (placemarks.isNotEmpty) {
          Placemark p = placemarks.first;

          _enteredStreet = p.street ?? '';
          _selectedCity = p.locality ?? '';
        }
      } catch (e) {
        setState(() {
          _isSubmitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error finding location data: $e'),
            backgroundColor: Colors.red,
          ),
        );
        return; // Stop
      }
    } else {
      final fulladdress = '$_enteredStreet,$_selectedCity';
      print("Geocoding address: $fulladdress");

      try {
        List<Location> locations = await locationFromAddress(fulladdress);

        if (locations.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Address not found. Please check spelling.'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() {
            _isSubmitting = false;
          });
          return;
        }

        lt = locations.first.latitude;
        ln = locations.first.longitude;
      } catch (e) {
        setState(() {
          _isSubmitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error finding address: $e'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    final user = FirebaseAuth.instance.currentUser;
    final parkingData = {
      'ownerId': user!.uid,
      'street': _enteredStreet,
      'city': _selectedCity,
      'phone': _enteredPhone,
      'latitude': lt,
      'longitude': ln,
      'timestamp': FieldValue.serverTimestamp(),
      'findingstatus': "waiting",
    };

    try {
      await FirebaseFirestore.instance
          .collection('parking_needs')
          .add(parkingData);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fetchiing nearby parkings!')),
      );
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) {
            return ParkingTimeScreen();
          },
        ),
      );
      setState(() {
        _isSubmitting = false;
      });
    } catch (e) {
      setState(() {
        _isSubmitting = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error finding parkings: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Find nearby parking spots"),
        backgroundColor: const Color(0xff0072ff),
        actions: [
          IconButton(
            onPressed: () {
              FirebaseAuth.instance.signOut();
            },
            icon: Icon(Icons.logout_outlined),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/bg_image.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),

              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'Choose Your Location',
                      style: GoogleFonts.poppins(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF002B5B),
                      ),
                    ),
                    const SizedBox(height: 25),

                    TextFormField(
                      enabled: (locationMarked) ? false : true,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.location_on_outlined),
                        labelText: 'Street Address',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (value) {
                        if (!locationMarked &&
                            (value == null || value.trim().isEmpty)) {
                          return 'Please enter a street address.';
                        }
                        return null;
                      },
                      onSaved: (value) {
                        _enteredStreet = value!;
                      },
                    ),
                    const SizedBox(height: 16),

                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.location_city),
                        labelText: 'City',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Delhi', child: Text('Delhi')),
                        DropdownMenuItem(
                          value: 'Mumbai',
                          child: Text('Mumbai'),
                        ),
                        DropdownMenuItem(
                          value: 'Bangalore',
                          child: Text('Bangalore'),
                        ),
                        DropdownMenuItem(
                          value: 'Kolkata',
                          child: Text('Kolkata'),
                        ),
                        DropdownMenuItem(
                          value: 'Bhisi jargaon',
                          child: Text('Bhisi jargaon'),
                        ),
                        DropdownMenuItem(
                          value: 'Kanpur',
                          child: Text('Kanpur'),
                        ),
                      ],

                      onChanged:
                          (locationMarked)
                              ? null // If location IS marked, disable this dropdown
                              : (value) {
                                // Otherwise, enable it
                                setState(() {
                                  _selectedCity = value;
                                });
                              },
                      onSaved: (value) {
                        _selectedCity = value;
                      },
                      validator: (value) {
                        if (!locationMarked && value == null) {
                          return 'Please select a city.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.phone),
                        labelText: 'Mobile No.',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (value) {
                        if (value == null ||
                            value.trim().isEmpty ||
                            value.length != 10) {
                          return 'Please enter a valid phone number.';
                        }
                        return null;
                      },
                      onSaved: (value) {
                        _enteredPhone = value!;
                      },
                    ),

                    const SizedBox(height: 16),

                    // Google Map
                    Container(
                      height: 250,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.black26),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: GoogleMap(
                          initialCameraPosition: const CameraPosition(
                            target: LatLng(28.6139, 77.2090),
                            zoom: 14,
                          ),
                          myLocationEnabled: true,
                          myLocationButtonEnabled: true,
                          onMapCreated: (controller) {
                            _mapController = controller;
                          },
                          markers:
                              _currentLocation != null
                                  ? {
                                    Marker(
                                      markerId: const MarkerId('current'),
                                      position: _currentLocation!,
                                      infoWindow: const InfoWindow(
                                        title: 'Your Current Location',
                                      ),
                                    ),
                                  }
                                  : {},
                        ),
                      ),
                    ),
                    const SizedBox(height: 25),

                    //  Get Current Location Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _getCurrentLocation,
                        icon: const Icon(Icons.my_location),
                        label: const Text('Get Current Location'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orangeAccent,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Enroll button now calls _submitForm
                    SizedBox(
                      width: double.infinity,
                      child:
                          _isSubmitting
                              ? const CircularProgressIndicator()
                              : ElevatedButton(
                                onPressed: () {
                                  _submitForm();
                                  ParkingTimeScreen();
                                }, // Calls the new submit function
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0066CC),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text(
                                  'Fetch nearby parkings',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
