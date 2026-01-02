class Address {
  final int id;
  final String firstName;
  final String lastName;
  final String countryCode;
  final String phoneNumber;
  final String address;
  final String? state;
  final String routeName;
  final String buildingName;
  final int floorNumber;
  final bool isDefault;
  final double? longitude;
  final double? latitude;
  final Country? country;
  final City? city;

  Address({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.countryCode,
    required this.phoneNumber,
    required this.address,
    this.state,
    required this.routeName,
    required this.buildingName,
    required this.floorNumber,
    required this.isDefault,
    this.longitude,
    this.latitude,
    this.country,
    this.city,
  });

  factory Address.fromJson(Map<String, dynamic> json) {
    return Address(
      id: json['id'],
      firstName: json['first_name'],
      lastName: json['last_name'],
      countryCode: json['country_code'],
      phoneNumber: json['phone_number'],
      address: json['address'],
      state: json['state'],
      routeName: json['route_name'],
      buildingName: json['building_name'],
      floorNumber: json['floor_number'],
      isDefault: json['is_default'] == true || json['is_default'] == 1,
      longitude: json['longitude'] != null ? double.tryParse(json['longitude'].toString()) : null,
      latitude: json['latitude'] != null ? double.tryParse(json['latitude'].toString()) : null,
      country: json['country'] != null ? Country.fromJson(json['country']) : null,
      city: json['city'] != null ? City.fromJson(json['city']) : null,
    );
  }
}

class Country {
  final int id;
  final String code;
  final String name;
  final String? phoneCode;

  Country({
    required this.id,
    required this.code,
    required this.name,
    this.phoneCode,
  });

  factory Country.fromJson(Map<String, dynamic> json) {
    return Country(
      id: json['id'],
      code: json['code'],
      name: json['name'],
      phoneCode: json['phone_code'],
    );
  }
}

class City {
  final int id;
  final String name;

  City({
    required this.id,
    required this.name,
  });

  factory City.fromJson(Map<String, dynamic> json) {
    return City(
      id: json['id'],
      name: json['name'],
    );
  }
}
