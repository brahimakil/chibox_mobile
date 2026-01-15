import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:iconsax/iconsax.dart';
import 'dart:io' show Platform;
import '../../../core/theme/theme.dart';

class MapPickerScreen extends StatefulWidget {
  final LatLng? initialLocation;

  const MapPickerScreen({super.key, this.initialLocation});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> with WidgetsBindingObserver {
  GoogleMapController? _mapController;
  LatLng _currentCenter = const LatLng(33.8938, 35.5018); // Default to Beirut, Lebanon
  bool _isLoading = true;
  bool _waitingForSettings = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.initialLocation != null) {
      _currentCenter = widget.initialLocation!;
      _isLoading = false;
    } else {
      _getCurrentLocation();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // When app resumes from settings, retry getting location
    if (state == AppLifecycleState.resumed && _waitingForSettings) {
      _waitingForSettings = false;
      _getCurrentLocation();
    }
  }

  Future<void> _showLocationServicesDialog() async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Iconsax.location_slash, color: AppColors.primary500),
              const SizedBox(width: 12),
              const Flexible(child: Text('Location Services')),
            ],
          ),
          content: const Text(
            'Location services are disabled. Please enable them to use the map and detect your current location.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                _waitingForSettings = true;
                await Geolocator.openLocationSettings();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary500,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Enable', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showPermissionDeniedDialog({bool permanent = false}) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Iconsax.shield_slash, color: AppColors.primary500),
              const SizedBox(width: 12),
              const Flexible(child: Text('Permission Required')),
            ],
          ),
          content: Text(
            permanent
                ? 'Location permission is permanently denied. Please enable it from app settings to use the map.'
                : 'Location permission is required to detect your current location. Please grant permission.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
            ),
            if (permanent)
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  _waitingForSettings = true;
                  await Geolocator.openAppSettings();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary500,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Open Settings', style: TextStyle(color: Colors.white)),
              )
            else
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _getCurrentLocation();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary500,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Try Again', style: TextStyle(color: Colors.white)),
              ),
          ],
        );
      },
    );
  }

  Future<void> _getCurrentLocation({int retryCount = 0}) async {
    setState(() => _isLoading = true);
    
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() => _isLoading = false);
      if (mounted) {
        _showLocationServicesDialog();
      }
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() => _isLoading = false);
        if (mounted) {
          _showPermissionDeniedDialog();
        }
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() => _isLoading = false);
      if (mounted) {
        _showPermissionDeniedDialog(permanent: true);
      }
      return;
    }

    try {
      // Platform-specific location settings for best accuracy
      late LocationSettings locationSettings;
      if (Platform.isAndroid) {
        locationSettings = AndroidSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 0,
          forceLocationManager: false,
          intervalDuration: const Duration(milliseconds: 500),
        );
      } else if (Platform.isIOS) {
        locationSettings = AppleSettings(
          accuracy: LocationAccuracy.best,
          activityType: ActivityType.other,
          distanceFilter: 0,
          pauseLocationUpdatesAutomatically: false,
        );
      } else {
        locationSettings = const LocationSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 0,
        );
      }

      // Get current position with best accuracy for device
      final position = await Geolocator.getCurrentPosition(
        locationSettings: locationSettings,
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () async {
          // If timeout, try to get last known position
          final lastPos = await Geolocator.getLastKnownPosition();
          if (lastPos != null) {
            return lastPos;
          }
          throw Exception('Location timeout');
        },
      );
      
      if (mounted) {
        setState(() {
          _currentCenter = LatLng(position.latitude, position.longitude);
          _isLoading = false;
        });
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(_currentCenter, 17),
        );
      }
    } catch (e) {
      // Try last known position as fallback
      try {
        final lastPosition = await Geolocator.getLastKnownPosition();
        if (lastPosition != null && mounted) {
          setState(() {
            _currentCenter = LatLng(lastPosition.latitude, lastPosition.longitude);
            _isLoading = false;
          });
          _mapController?.animateCamera(
            CameraUpdate.newLatLngZoom(_currentCenter, 17),
          );
          return;
        }
      } catch (_) {}
      
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Could not get location. You can manually move the map.'),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () => _getCurrentLocation(),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _currentCenter,
              zoom: 15.0,
            ),
            onMapCreated: (GoogleMapController controller) {
              _mapController = controller;
            },
            onCameraMove: (CameraPosition position) {
              setState(() {
                _currentCenter = position.target;
              });
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
          ),
          
          // Center Pin
          const Center(
            child: Padding(
              padding: EdgeInsets.only(bottom: 40), // Adjust for pin tip
              child: Icon(
                Iconsax.location5,
                size: 50,
                color: AppColors.primary500,
              ),
            ),
          ),

          // Back Button
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            child: CircleAvatar(
              backgroundColor: Colors.white,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),

          // Current Location Button
          Positioned(
            bottom: 100,
            right: 16,
            child: FloatingActionButton(
              backgroundColor: Colors.white,
              onPressed: _getCurrentLocation,
              child: const Icon(Icons.my_location, color: Colors.black),
            ),
          ),

          // Confirm Button
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context, _currentCenter);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary500,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Confirm Location',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
