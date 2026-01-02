import 'package:flutter/foundation.dart';
import '../constants/api_constants.dart';
import '../models/address_model.dart';
import 'api_service.dart';

class AddressService extends ChangeNotifier {
  final ApiService _api = ApiService();
  
  List<Address> _addresses = [];
  List<Country> _countries = [];
  List<City> _cities = [];
  bool _isLoading = false;
  String? _error;

  List<Address> get addresses => _addresses;
  List<Country> get countries => _countries;
  List<City> get cities => _cities;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Fetch user addresses
  Future<void> fetchAddresses() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _api.get(ApiConstants.getAddresses);
      
      if (response.success && response.data != null) {
        final List<dynamic> data = response.data!['addresses'];
        _addresses = data.map((json) => Address.fromJson(json)).toList();
      } else {
        _error = response.message;
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Fetch countries
  Future<void> fetchCountries() async {
    try {
      final response = await _api.get(ApiConstants.getCountries);
      
      if (response.success && response.data != null) {
        final List<dynamic> data = response.data!['countries'];
        _countries = data.map((json) => Country.fromJson(json)).toList();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error fetching countries: $e');
    }
  }

  /// Fetch cities by country ID
  Future<void> fetchCities(int countryId) async {
    try {
      final response = await _api.get(
        ApiConstants.getCities,
        queryParams: {'country_id': countryId},
      );
      
      if (response.success && response.data != null) {
        final List<dynamic> data = response.data!['cities'];
        _cities = data.map((json) => City.fromJson(json)).toList();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error fetching cities: $e');
    }
  }

  /// Create new address
  Future<bool> createAddress(Map<String, dynamic> addressData) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _api.post(
        ApiConstants.createAddress,
        body: addressData,
      );
      
      if (response.success) {
        await fetchAddresses(); // Refresh list
        return true;
      } else {
        _error = response.message;
        return false;
      }
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Update existing address
  Future<bool> updateAddress(int id, Map<String, dynamic> addressData) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _api.put(
        ApiConstants.updateAddress,
        body: {'address_id': id, ...addressData},
      );
      
      if (response.success) {
        await fetchAddresses(); // Refresh list
        return true;
      } else {
        _error = response.message;
        return false;
      }
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Set default address
  Future<bool> setDefaultAddress(int addressId) async {
    try {
      final response = await _api.post(
        ApiConstants.setDefaultAddress,
        body: {'address_id': addressId},
      );
      
      if (response.success) {
        await fetchAddresses(); // Refresh list
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error setting default address: $e');
      return false;
    }
  }

  /// Delete address
  Future<bool> deleteAddress(int addressId) async {
    try {
      final response = await _api.delete(
        ApiConstants.deleteAddress,
        queryParams: {'address_id': addressId},
      );
      
      if (response.success) {
        _addresses.removeWhere((a) => a.id == addressId);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error deleting address: $e');
      return false;
    }
  }
}
