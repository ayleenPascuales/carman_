import 'package:carman_app/data/mock/admin_mock_data.dart';
import 'package:carman_app/data/models/admin_models.dart';
import 'package:carman_app/data/models/driver_models.dart';
import 'package:carman_app/data/repositories/admin_repository.dart';
import 'package:carman_app/data/repositories/driver_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DemoDriverRepository', () {
    test('loads services and changes availability', () async {
      final repository = DemoDriverRepository();
      final data = await repository.fetchDashboard();

      expect(data.trips, isNotEmpty);
      expect(data.availability, DriverAvailability.online);
      expect(
        data.trips.where((trip) => trip.status == DriverTripStatus.offered),
        isNotEmpty,
      );

      await repository.setAvailability(false);
      final offline = await repository.fetchDashboard();
      expect(offline.availability, DriverAvailability.offline);
    });

    test('accepts, starts and completes a service', () async {
      final repository = DemoDriverRepository();
      final initial = await repository.fetchDashboard();
      final offered = initial.trips.firstWhere(
        (trip) => trip.status == DriverTripStatus.offered,
      );

      await repository.acceptTrip(offered.id);
      var data = await repository.fetchDashboard();
      expect(
        data.trips.firstWhere((trip) => trip.id == offered.id).status,
        DriverTripStatus.accepted,
      );

      await repository.startTrip(offered.id);
      data = await repository.fetchDashboard();
      expect(data.availability, DriverAvailability.onTrip);
      expect(
        data.trips.firstWhere((trip) => trip.id == offered.id).status,
        DriverTripStatus.inProgress,
      );

      final earningsBefore = data.stats.earningsToday;
      await repository.completeTrip(offered.id);
      data = await repository.fetchDashboard();
      expect(
        data.trips.firstWhere((trip) => trip.id == offered.id).status,
        DriverTripStatus.completed,
      );
      expect(data.stats.earningsToday, greaterThan(earningsBefore));
      expect(data.availability, DriverAvailability.online);
    });
  });

  group('DemoAdminRepository', () {
    test('suspends and reactivates a user', () async {
      final repository = DemoAdminRepository();
      final data = await repository.fetchDashboard();
      final user = data.users.first;

      await repository.updateUserStatus(user.id, AdminUserStatus.suspended);
      var updated = await repository.fetchDashboard();
      expect(
        updated.users.firstWhere((item) => item.id == user.id).status,
        AdminUserStatus.suspended,
      );

      await repository.updateUserStatus(user.id, AdminUserStatus.active);
      updated = await repository.fetchDashboard();
      expect(
        updated.users.firstWhere((item) => item.id == user.id).status,
        AdminUserStatus.active,
      );
    });

    test('reviews a pending request and updates the counter', () async {
      final repository = DemoAdminRepository();
      final data = await repository.fetchDashboard();
      final approval = data.approvals.firstWhere(
        (item) => item.status == AdminApprovalStatus.pending,
      );

      await repository.reviewApproval(approval.id, true);
      final updated = await repository.fetchDashboard();

      expect(
        updated.approvals.firstWhere((item) => item.id == approval.id).status,
        AdminApprovalStatus.approved,
      );
      expect(
        updated.stats.pendingApprovals,
        lessThan(AdminMockData.stats.pendingApprovals),
      );
    });
  });
}
