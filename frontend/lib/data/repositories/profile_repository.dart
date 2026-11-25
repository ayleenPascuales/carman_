import '../../core/errors/app_exception.dart';
import '../mock/mock_data.dart';
import '../models/user_profile.dart';
import '../models/vehicle.dart';

class ProfileUpdate {
  const ProfileUpdate({
    required this.firstName,
    required this.lastName,
    required this.phone,
    required this.city,
  });

  final String firstName;
  final String lastName;
  final String phone;
  final String city;
}

class LicenseSubmission {
  const LicenseSubmission({
    required this.number,
    required this.expiry,
    required this.type,
    required this.frontImageReference,
    this.backImageReference,
  });

  final String number;
  final DateTime expiry;
  final String type;
  final String frontImageReference;
  final String? backImageReference;
}

abstract interface class ProfileRepository {
  Future<UserProfile> updateProfile(UserProfile current, ProfileUpdate update);

  Future<UserProfile> submitLicense(
    UserProfile current,
    LicenseSubmission submission,
  );

  Future<UserProfile> addRole(UserProfile current, UserRole role);

  Future<List<Vehicle>> fetchFavorites(Set<String> ids);
}

class DemoProfileRepository implements ProfileRepository {
  @override
  Future<UserProfile> updateProfile(
    UserProfile current,
    ProfileUpdate update,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (update.firstName.trim().isEmpty || update.lastName.trim().isEmpty) {
      throw const ValidationException(
        'El nombre y el apellido son obligatorios.',
      );
    }
    return current.copyWith(
      firstName: update.firstName.trim(),
      lastName: update.lastName.trim(),
      phone: update.phone.trim(),
      city: update.city,
    );
  }

  @override
  Future<UserProfile> submitLicense(
    UserProfile current,
    LicenseSubmission submission,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    if (submission.expiry.isBefore(DateTime.now())) {
      throw const ValidationException('Tu licencia está vencida.');
    }
    return current.copyWith(licenseStatus: LicenseStatus.pendingReview);
  }

  @override
  Future<UserProfile> addRole(UserProfile current, UserRole role) async {
    await Future<void>.delayed(const Duration(milliseconds: 700));
    return current.copyWith(roles: {...current.roles, role});
  }

  @override
  Future<List<Vehicle>> fetchFavorites(Set<String> ids) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    return MockData.byIds(ids);
  }
}
