import 'package:flutter_test/flutter_test.dart';
import 'package:lapak8new/features/facilities/models/facility.dart';

void main() {
  test('uses aggregated available stock separately from physical capacity', () {
    final facility = Facility.fromMap({
      'id': 'facility-id',
      'nama': 'Proyektor',
      'total_unit': 2,
      'unit_tersedia': 1,
      'unit_dipakai': 1,
      'status': 'tersedia',
      'aktif': true,
    });

    expect(facility.totalUnit, 2);
    expect(facility.unitTersedia, 1);
    expect(facility.unitDipakai, 1);
    expect(facility.isAvailable, isTrue);
  });

  test('does not treat physical capacity as available stock when absent', () {
    final facility = Facility.fromMap({
      'id': 'facility-id',
      'nama': 'Proyektor',
      'total_unit': 2,
      'status': 'tersedia',
      'aktif': true,
    });

    expect(facility.totalUnit, 2);
    expect(facility.unitTersedia, 0);
    expect(facility.isAvailable, isFalse);
  });
}
