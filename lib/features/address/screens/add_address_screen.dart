import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:iconsax/iconsax.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../core/theme/theme.dart';
import '../../../core/services/address_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/models/address_model.dart';
import 'map_picker_screen.dart';

const String _googleApiKey = 'AIzaSyDtPU6YFH19qOs4IVdJIgEkyTOgRrNmgCE';

class AddAddressScreen extends StatefulWidget {
  final Address? addressToEdit;
  /// When true, navigating back returns to checkout flow
  final bool fromCheckout;
  const AddAddressScreen({super.key, this.addressToEdit, this.fromCheckout = false});

  @override
  State<AddAddressScreen> createState() => _AddAddressScreenState();
}

class _AddAddressScreenState extends State<AddAddressScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _routeNameController;
  late final TextEditingController _buildingNameController;
  late final TextEditingController _floorNumberController;
  
  // State
  String _countryCode = '+961'; // Default
  Country? _selectedCountry;
  City? _selectedCity;
  LatLng? _selectedLocation;
  bool _isDefault = false;
  bool _isSubmitting = false;
  bool _isAutoFilling = false;

  @override
  void initState() {
    super.initState();
    
    final address = widget.addressToEdit;
    
    // Auto-fill from user profile if adding new address (not editing)
    String initialFirstName = address?.firstName ?? '';
    String initialLastName = address?.lastName ?? '';
    String initialPhone = address?.phoneNumber ?? '';
    String initialCountryCode = address?.countryCode ?? '+961';
    
    if (address == null) {
      // New address - auto-fill from user profile
      final authService = AuthService();
      final user = authService.currentUser;
      if (user != null) {
        initialFirstName = user.firstName;
        initialLastName = user.lastName;
        initialPhone = user.phoneNumber;
        if (user.countryCode.isNotEmpty) {
          initialCountryCode = user.countryCode.startsWith('+') 
              ? user.countryCode 
              : '+${user.countryCode}';
        }
      }
    }
    
    _firstNameController = TextEditingController(text: initialFirstName);
    _lastNameController = TextEditingController(text: initialLastName);
    _phoneController = TextEditingController(text: initialPhone);
    _routeNameController = TextEditingController(text: address?.routeName ?? '');
    _buildingNameController = TextEditingController(text: address?.buildingName ?? '');
    _floorNumberController = TextEditingController(text: address?.floorNumber.toString() ?? '');
    
    if (address != null) {
      _countryCode = address.countryCode;
      _isDefault = address.isDefault;
      _selectedCountry = address.country;
      _selectedCity = address.city;
      if (address.latitude != null && address.longitude != null) {
        _selectedLocation = LatLng(address.latitude!, address.longitude!);
      }
    } else {
      _countryCode = initialCountryCode;
      // Auto-select "Set as Default" when adding new address from checkout
      if (widget.fromCheckout) {
        _isDefault = true;
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AddressService>().fetchCountries();
      if (address != null && address.country != null) {
        context.read<AddressService>().fetchCities(address.country!.id);
      }
    });
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _routeNameController.dispose();
    _buildingNameController.dispose();
    _floorNumberController.dispose();
    super.dispose();
  }

  Future<void> _autoFillFromLocation(LatLng location) async {
    setState(() => _isAutoFilling = true);
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json?latlng=${location.latitude},${location.longitude}&key=$_googleApiKey&language=en&result_type=street_address|premise|subpremise|route'
      );
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['status'] == 'OK' && data['results'] != null && data['results'].isNotEmpty) {
          // Get the most detailed result (first one is usually the most specific)
          final result = data['results'][0];
          final addressComponents = result['address_components'] as List;
          
          String? countryName;
          String? cityName;
          String? districtName;
          String? neighborhoodName;
          String? streetName;
          String? streetNumber;
          String? buildingName;
          String? premise;
          
          for (var component in addressComponents) {
            final types = component['types'] as List;
            final longName = component['long_name'] as String?;
            
            if (types.contains('country')) {
              countryName = longName;
            } else if (types.contains('administrative_area_level_1')) {
              // State/Province/Region
              districtName ??= longName;
            } else if (types.contains('administrative_area_level_2')) {
              // County/District
              districtName ??= longName;
            } else if (types.contains('locality')) {
              // City
              cityName = longName;
            } else if (types.contains('sublocality_level_1') || types.contains('sublocality')) {
              // Neighborhood/Area
              neighborhoodName = longName;
            } else if (types.contains('route')) {
              // Street name
              streetName = longName;
            } else if (types.contains('street_number')) {
              // Street number
              streetNumber = longName;
            } else if (types.contains('premise')) {
              // Building name
              premise = longName;
            } else if (types.contains('establishment') || types.contains('point_of_interest')) {
              // Named place/building
              buildingName ??= longName;
            }
          }
          
          // Use neighborhood or district as city fallback
          cityName ??= neighborhoodName ?? districtName;
          
          // 1. Match Country
          if (countryName != null) {
            final countries = context.read<AddressService>().countries;
            Country? matchedCountry;
            try {
              matchedCountry = countries.firstWhere(
                (c) => c.name.toLowerCase().contains(countryName!.toLowerCase()) || countryName!.toLowerCase().contains(c.name.toLowerCase()),
              );
            } catch (_) {}
            
            if (matchedCountry != null) {
               setState(() => _selectedCountry = matchedCountry);
               
               // 2. Fetch Cities for this country
               await context.read<AddressService>().fetchCities(matchedCountry.id);
               
               // 3. Match City - try multiple fields
               final citiesToTry = [cityName, neighborhoodName, districtName].whereType<String>();
               final cities = context.read<AddressService>().cities;
               
               for (final cityToMatch in citiesToTry) {
                 try {
                   final matchedCity = cities.firstWhere(
                     (c) => c.name.toLowerCase().contains(cityToMatch.toLowerCase()) || 
                            cityToMatch.toLowerCase().contains(c.name.toLowerCase()),
                   );
                   setState(() => _selectedCity = matchedCity);
                   break; // Found a match, stop searching
                 } catch (_) {}
               }
            }
          }
          
          // Build the route/street name with neighborhood if available
          String fullStreetName = '';
          if (streetName != null) {
            fullStreetName = streetName;
            if (neighborhoodName != null && neighborhoodName != cityName) {
              fullStreetName = '$streetName, $neighborhoodName';
            }
          } else if (neighborhoodName != null) {
            fullStreetName = neighborhoodName;
          }
          
          // Auto-fill street/route name
          if (fullStreetName.isNotEmpty) {
            _routeNameController.text = fullStreetName;
          }
          
          // Auto-fill building name - prioritize premise, then establishment, then street number
          if (premise != null && premise.isNotEmpty) {
            _buildingNameController.text = premise;
          } else if (buildingName != null && buildingName.isNotEmpty) {
            _buildingNameController.text = buildingName;
          } else if (streetNumber != null && streetNumber.isNotEmpty) {
            _buildingNameController.text = streetNumber;
          }
        }
      }
    } catch (e) {
      debugPrint('Autofill error: $e');
    } finally {
      setState(() => _isAutoFilling = false);
    }
  }

  Future<void> _pickLocation() async {
    final result = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(
        builder: (_) => MapPickerScreen(initialLocation: _selectedLocation),
      ),
    );

    if (result != null) {
      setState(() {
        _selectedLocation = result;
      });
      _autoFillFromLocation(result);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCountry == null || _selectedCity == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select country and city')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final fullAddress = '${_buildingNameController.text}, Floor ${_floorNumberController.text}, ${_routeNameController.text}, ${_selectedCity!.name}, ${_selectedCountry!.name}';

    final data = {
      'first_name': _firstNameController.text,
      'last_name': _lastNameController.text,
      'country_code': _countryCode,
      'phone_number': _phoneController.text,
      'address': fullAddress,
      'r_country_id': _selectedCountry!.id,
      'r_city_id': _selectedCity!.id,
      'route_name': _routeNameController.text,
      'building_name': _buildingNameController.text,
      'floor_number': int.tryParse(_floorNumberController.text) ?? 0,
      'is_default': _isDefault,
      'longitude': _selectedLocation?.longitude,
      'latitude': _selectedLocation?.latitude,
    };

    Address? createdAddress;
    bool success = false;
    
    if (widget.addressToEdit != null) {
      success = await context.read<AddressService>().updateAddress(widget.addressToEdit!.id, data);
    } else {
      createdAddress = await context.read<AddressService>().createAddress(data);
      success = createdAddress != null;
    }

    // If updating and set as default is checked, call setDefaultAddress explicitly
    // because the backend update endpoint doesn't handle is_default
    if (success && widget.addressToEdit != null && _isDefault) {
      await context.read<AddressService>().setDefaultAddress(widget.addressToEdit!.id);
    }

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        if (widget.fromCheckout) {
          // Return the newly created address to checkout
          Navigator.pop(context, createdAddress);
        } else {
          Navigator.pop(context);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.read<AddressService>().error ?? 'Failed to ${widget.addressToEdit != null ? 'update' : 'create'} address')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final addressService = context.watch<AddressService>();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          widget.addressToEdit != null ? 'Edit Address' : 'Add New Address',
          style: AppTypography.headingSmall(
            color: theme.textTheme.titleLarge?.color,
          ),
        ),
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: theme.iconTheme.color),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Map Preview Section
              GestureDetector(
                onTap: _pickLocation,
                child: Container(
                  height: 180,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: theme.cardTheme.color,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: theme.dividerColor,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(
                      children: [
                        if (_selectedLocation != null)
                          GoogleMap(
                            initialCameraPosition: CameraPosition(
                              target: _selectedLocation!,
                              zoom: 15.0,
                            ),
                            scrollGesturesEnabled: false,
                            zoomGesturesEnabled: false,
                            rotateGesturesEnabled: false,
                            tiltGesturesEnabled: false,
                            zoomControlsEnabled: false,
                            myLocationButtonEnabled: false,
                            markers: {
                              Marker(
                                markerId: const MarkerId('selected_location'),
                                position: _selectedLocation!,
                                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                              ),
                            },
                          )
                        else
                          Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Iconsax.map, size: 48, color: Colors.grey[400]),
                                const SizedBox(height: 8),
                                Text(
                                  'Tap to set location on map',
                                  style: AppTypography.bodyMedium(color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          ),
                        
                        // Overlay Button
                        Positioned(
                          bottom: 12,
                          right: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _selectedLocation != null ? Icons.edit : Icons.add_location_alt,
                                  size: 16,
                                  color: AppColors.primary500,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _selectedLocation != null ? 'Change Location' : 'Set Location',
                                  style: AppTypography.labelMedium(color: AppColors.primary500),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Personal Info
              Text('Contact Information', style: AppTypography.headingSmall(color: theme.textTheme.titleLarge?.color)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _firstNameController,
                      label: 'First Name',
                      icon: Iconsax.user,
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTextField(
                      controller: _lastNameController,
                      label: 'Last Name',
                      icon: Iconsax.user,
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 100,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.cardTheme.color,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: theme.dividerColor),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _countryCode,
                        isExpanded: true,
                        dropdownColor: theme.cardTheme.color,
                        items: ['+961', '+971', '+966', '+1', '+44'].map((code) {
                          return DropdownMenuItem(
                            value: code,
                            child: Text(code, style: TextStyle(color: theme.textTheme.bodyLarge?.color)),
                          );
                        }).toList(),
                        onChanged: (val) => setState(() => _countryCode = val!),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTextField(
                      controller: _phoneController,
                      label: 'Phone Number',
                      icon: Iconsax.call,
                      keyboardType: TextInputType.phone,
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Region Selection
              Text('Region', style: AppTypography.headingSmall(color: theme.textTheme.titleLarge?.color)),
              const SizedBox(height: 16),
              if (_isAutoFilling)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    children: [
                      const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                      const SizedBox(width: 8),
                      Text('Detecting region from map...', style: TextStyle(color: AppColors.primary500, fontSize: 12)),
                    ],
                  ),
                ),
              _buildSelectionField<Country>(
                context: context,
                value: _selectedCountry,
                items: addressService.countries,
                label: 'Select Country',
                isDark: isDark,
                itemLabel: (c) => c.name,
                onChanged: (val) {
                  setState(() {
                    _selectedCountry = val;
                    _selectedCity = null; // Reset city
                  });
                  if (val != null) {
                    context.read<AddressService>().fetchCities(val.id);
                  }
                },
              ),
              const SizedBox(height: 16),
              _buildSelectionField<City>(
                context: context,
                value: _selectedCity,
                items: addressService.cities,
                label: 'Select City',
                isDark: isDark,
                itemLabel: (c) => c.name,
                onChanged: (val) => setState(() => _selectedCity = val),
                enabled: _selectedCountry != null,
              ),
              const SizedBox(height: 24),

              // Address Details
              Text('Building Details', style: AppTypography.headingSmall(color: theme.textTheme.titleLarge?.color)),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _routeNameController,
                label: 'Street Name / Route',
                icon: Iconsax.map_1,
                isDark: isDark,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _buildingNameController,
                      label: 'Building Name/No',
                      icon: Iconsax.building,
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTextField(
                      controller: _floorNumberController,
                      label: 'Floor No',
                      icon: Iconsax.layer,
                      keyboardType: TextInputType.number,
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Default Toggle
              if (widget.addressToEdit == null || !widget.addressToEdit!.isDefault)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.cardTheme.color,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.dividerColor),
                  ),
                  child: Row(
                    children: [
                      Icon(Iconsax.tick_circle, color: _isDefault ? AppColors.primary500 : Colors.grey),
                      const SizedBox(width: 12),
                      Text(
                        'Set as Default Address',
                        style: AppTypography.bodyMedium(color: theme.textTheme.bodyLarge?.color),
                      ),
                      const Spacer(),
                      Switch(
                        value: _isDefault,
                        onChanged: (val) => setState(() => _isDefault = val),
                        activeColor: AppColors.primary500,
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 32),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary500,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSubmitting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Save Address',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isDark,
    TextInputType? keyboardType,
  }) {
    final theme = Theme.of(context);
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(color: theme.textTheme.bodyLarge?.color),
      validator: (val) => val == null || val.isEmpty ? 'Required' : null,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: theme.textTheme.bodyMedium?.color),
        prefixIcon: Icon(icon, color: theme.iconTheme.color, size: 20),
        filled: true,
        fillColor: theme.inputDecorationTheme.fillColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.dividerColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.dividerColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primary500),
        ),
      ),
    );
  }

  Widget _buildSelectionField<T>({
    required BuildContext context,
    required T? value,
    required List<T> items,
    required String label,
    required bool isDark,
    required String Function(T) itemLabel,
    required ValueChanged<T?> onChanged,
    bool enabled = true,
  }) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: enabled
          ? () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => _SelectionSheet<T>(
                  items: items,
                  label: label,
                  itemLabel: itemLabel,
                  onSelected: onChanged,
                ),
              );
            }
          : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value != null ? itemLabel(value) : label,
                style: TextStyle(
                  color: value != null
                      ? theme.textTheme.bodyLarge?.color
                      : theme.textTheme.bodyMedium?.color,
                  fontSize: 16,
                ),
              ),
            ),
            Icon(Icons.arrow_drop_down, color: theme.iconTheme.color),
          ],
        ),
      ),
    );
  }
}

class _SelectionSheet<T> extends StatefulWidget {
  final List<T> items;
  final String label;
  final String Function(T) itemLabel;
  final ValueChanged<T?> onSelected;

  const _SelectionSheet({
    required this.items,
    required this.label,
    required this.itemLabel,
    required this.onSelected,
  });

  @override
  State<_SelectionSheet<T>> createState() => _SelectionSheetState<T>();
}

class _SelectionSheetState<T> extends State<_SelectionSheet<T>> {
  late List<T> _filteredItems;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filteredItems = widget.items;
  }

  void _filter(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredItems = widget.items;
      } else {
        _filteredItems = widget.items.where((item) {
          return widget.itemLabel(item).toLowerCase().contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          
          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              widget.label,
              style: AppTypography.headingSmall(color: theme.textTheme.titleLarge?.color),
            ),
          ),
          const SizedBox(height: 16),

          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              onChanged: _filter,
              style: TextStyle(color: theme.textTheme.bodyLarge?.color),
              decoration: InputDecoration(
                hintText: 'Search...',
                hintStyle: TextStyle(color: theme.textTheme.bodyMedium?.color),
                prefixIcon: Icon(Iconsax.search_normal, color: theme.iconTheme.color),
                filled: true,
                fillColor: theme.inputDecorationTheme.fillColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // List
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _filteredItems.length,
              separatorBuilder: (_, __) => Divider(color: theme.dividerColor),
              itemBuilder: (context, index) {
                final item = _filteredItems[index];
                return ListTile(
                  title: Text(
                    widget.itemLabel(item),
                    style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                  ),
                  onTap: () {
                    widget.onSelected(item);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
