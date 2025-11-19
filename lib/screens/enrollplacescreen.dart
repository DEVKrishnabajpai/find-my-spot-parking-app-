import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

class EnrollPlaceScreen extends StatefulWidget {
  const EnrollPlaceScreen({super.key});

  @override
  State<EnrollPlaceScreen> createState() => _EnrollPlaceScreenState();
}

class _EnrollPlaceScreenState extends State<EnrollPlaceScreen> {
  var locationMarked = false;
  late GoogleMapController _mapController;
  LatLng? _currentLocation;
  var issubmitting = false;

  //  A key to identify and control the form
  final _formKey = GlobalKey<FormState>();

  //  Variables to store the form data
  var _enteredStreet = '';
  var _enteredHouseNo = '';
  String? _selectedCity;
  var _enteredRate = '';
  String _enteredPhone = "";
  double lt = 0.0;
  double ln = 0.0;

  // Function to get permission + current location
  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location services are disabled.')),
      );
      return;
    }

    // Check and request permissions
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

    // Get current position
    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    setState(() {
      _currentLocation = LatLng(position.latitude, position.longitude);
    });

    // Move map to current location
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
      issubmitting = true;
    });
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Either select on map or manually input parking spot',
            style: TextStyle(color: Colors.black),
          ),
          backgroundColor: Colors.red[100],
        ),
      );
      setState(() {
        issubmitting = false;
      });
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

          // Fill in the missing address variables
          _enteredStreet = p.street ?? '';
          _enteredHouseNo =
              p.subThoroughfare ??
              p.name ??
              ''; // subThoroughfare is best for house number
          _selectedCity = p.locality ?? '';
        }
      } catch (e) {
        // Handle any geocoding errors (e.g., no internet)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error finding location data: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          issubmitting = false;
        });
        return; // Stop
      }
    } else {
     
      final fulladdress = '$_enteredHouseNo,$_enteredStreet,$_selectedCity';

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
            issubmitting = false;
          });
          return; // Stop if address is bad
        }

        lt = locations.first.latitude;
        ln = locations.first.longitude;
      } catch (e) {
        // Handle geocoding errors (e.g., no internet)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error finding address: $e'),
            backgroundColor: Colors.red,
          ),
        );

        setState(() {
          issubmitting = false;
        });
        return; // Stop
      }
    }

    final user = FirebaseAuth.instance.currentUser;
    final parkingData = {
      'ownerId': user!.uid,
      'street': _enteredStreet,
      'houseNo': _enteredHouseNo,
      'city': _selectedCity,
      'phone': _enteredPhone,
      'rate': double.parse(_enteredRate),
      'latitude': lt,
      'longitude': ln,
      'timestamp': FieldValue.serverTimestamp(),
      'availstatus': "available",
    };

    try {
      await FirebaseFirestore.instance
          .collection('parking_spaces')
          .add(parkingData);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Parking added successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error adding parking: $e')));
    }
    setState(() {
      issubmitting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Add a new parking spot"),
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
              // MODIFIED: Wrapped the Column in a Form widget
              child: Form(
                key: _formKey, // Assign the key
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

                    // MODIFIED: Changed TextField to TextFormField
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

                    // MODIFIED: Changed TextField to TextFormField
                    TextFormField(
                      enabled: (locationMarked) ? false : true,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.home_outlined),
                        labelText: 'House No.',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (value) {
                        if (!locationMarked &&
                            (value == null || value.trim().isEmpty)) {
                          return 'Please enter a house number.';
                        }
                        return null;
                      },
                      onSaved: (value) {
                        _enteredHouseNo = value!;
                      },
                    ),
                    const SizedBox(height: 16),

                    // MODIFIED: Added validator and onSaved to DropdownButtonFormField
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
                          value: 'Kanpur',
                          child: Text('Kanpur'),
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

                    // MODIFIED: Changed TextField to TextFormField
                    TextFormField(
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.currency_rupee),
                        labelText: 'Per Hour Rate',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a rate.';
                        }
                        if (double.tryParse(value) == null) {
                          return 'Please enter a valid number.';
                        }
                        if (double.parse(value) <= 0) {
                          return 'Rate must be greater than zero.';
                        }
                        return null;
                      },
                      onSaved: (value) {
                        _enteredRate = value!;
                      },
                    ),
                    const SizedBox(height: 30),

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

                    // 📍 Get Current Location Button
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

                    // MODIFIED: Enroll button now calls _submitForm
                    SizedBox(
                      width: double.infinity,
                      child:
                          issubmitting
                              ? CircularProgressIndicator()
                              : ElevatedButton(
                                onPressed:
                                    _submitForm, // Calls the new submit function
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
                                  'Enroll the Place',
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
