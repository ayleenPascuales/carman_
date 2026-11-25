import 'package:carman_app/data/mock/mock_data.dart';
import 'package:carman_app/data/models/booking.dart';
import 'package:carman_app/data/models/vehicle.dart';
import 'package:carman_app/data/models/vehicle_query.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PricingService', () {
    test('reproduces the 3-day premium checkout total', () {
      final vehicle = MockData.vehicles.first;
      final start = DateTime(2026, 11, 15, 10);
      final end = DateTime(2026, 11, 18, 10);

      final pricing = PricingService.calculate(
        vehicle: vehicle,
        mode: RentalMode.daily,
        startAt: start,
        endAt: end,
        insurance: InsurancePlan.premium,
      );

      expect(pricing.units, 3);
      expect(pricing.rentalSubtotal, 225);
      expect(pricing.insuranceSubtotal, 54);
      expect(pricing.serviceFee, 24);
      expect(pricing.taxes, closeTo(63.63, 0.01));
      expect(pricing.total, closeTo(366.63, 0.01));
      expect(pricing.deposit, 150);
    });

    test('hourly rentals respect the two-hour minimum', () {
      final vehicle = MockData.vehicles.first;
      final start = DateTime(2026, 11, 15, 10);
      final end = start.add(const Duration(hours: 1));

      final pricing = PricingService.calculate(
        vehicle: vehicle,
        mode: RentalMode.hourly,
        startAt: start,
        endAt: end,
        insurance: InsurancePlan.basic,
      );

      expect(pricing.units, 2);
      expect(pricing.rentalSubtotal, vehicle.pricePerHour * 2);
    });

    test('weekly rentals receive a ten percent discount', () {
      final vehicle = MockData.vehicles.first;
      final start = DateTime(2026, 11, 15, 10);
      final end = start.add(const Duration(days: 7));

      final pricing = PricingService.calculate(
        vehicle: vehicle,
        mode: RentalMode.daily,
        startAt: start,
        endAt: end,
        insurance: InsurancePlan.premium,
      );

      expect(pricing.discount, closeTo(pricing.rentalSubtotal * 0.10, 0.01));
      expect(
        pricing.total,
        closeTo(
          pricing.rentalSubtotal -
              pricing.discount +
              pricing.insuranceSubtotal +
              pricing.serviceFee +
              pricing.taxes,
          0.01,
        ),
      );
    });
  });

  group('VehicleQuery', () {
    test('filters by city and category', () {
      final query = VehicleQuery(
        city: 'Cartagena',
        category: VehicleCategory.electric,
      );

      final matches = MockData.vehicles.where(query.matches).toList();

      expect(matches, hasLength(2));
      expect(matches.every((v) => v.city == 'Cartagena'), isTrue);
      expect(
        matches.every((v) => v.category == VehicleCategory.electric),
        isTrue,
      );
    });

    test('sorts by price ascending', () {
      final query = const VehicleQuery(sort: SortOption.priceAsc);
      final sorted = query.sortVehicles(MockData.vehicles);

      for (var i = 1; i < sorted.length; i++) {
        expect(sorted[i - 1].pricePerDay <= sorted[i].pricePerDay, isTrue);
      }
    });

    test('counts active filters for the results header', () {
      final query = const VehicleQuery(
        category: VehicleCategory.suv,
        transmission: TransmissionType.automatic,
        minSeats: 5,
        instantBookOnly: true,
      );

      expect(query.activeFilterCount, 4);
    });
  });
}
