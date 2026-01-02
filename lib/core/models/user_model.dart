import 'package:equatable/equatable.dart';
import 'package:chihelo_frontend/core/utils/image_helper.dart';

/// User Model
class User extends Equatable {
  final int id;
  final String firstName;
  final String lastName;
  final String? email;
  final String countryCode;
  final String phoneNumber;
  final String? gender;
  final String? mainImage;
  final int? languageId;
  final bool isProvider;

  const User({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.email,
    required this.countryCode,
    required this.phoneNumber,
    this.gender,
    this.mainImage,
    this.languageId,
    this.isProvider = false,
  });

  String get fullName => '$firstName $lastName';
  String get phone => '+$countryCode $phoneNumber';

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int,
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String? ?? '',
      email: json['email'] as String?,
      countryCode: json['country_code']?.toString() ?? '',
      phoneNumber: json['phone_number']?.toString() ?? '',
      gender: json['gender'] as String?,
      mainImage: ImageHelper.parse(json['main_image']),
      languageId: json['language_id'] as int?,
      isProvider: (json['is_provider'] ?? 0) == 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      'country_code': countryCode,
      'phone_number': phoneNumber,
      'gender': gender,
      'main_image': mainImage,
      'language_id': languageId,
      'is_provider': isProvider ? 1 : 0,
    };
  }

  User copyWith({
    int? id,
    String? firstName,
    String? lastName,
    String? email,
    String? countryCode,
    String? phoneNumber,
    String? gender,
    String? mainImage,
    int? languageId,
    bool? isProvider,
  }) {
    return User(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      countryCode: countryCode ?? this.countryCode,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      gender: gender ?? this.gender,
      mainImage: mainImage ?? this.mainImage,
      languageId: languageId ?? this.languageId,
      isProvider: isProvider ?? this.isProvider,
    );
  }

  @override
  List<Object?> get props => [
    id, firstName, lastName, email, countryCode, phoneNumber, 
    gender, mainImage, languageId, isProvider
  ];
}

