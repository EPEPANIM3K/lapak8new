import 'package:flutter/material.dart';

final ValueNotifier<String> adminActiveLocation = ValueNotifier<String>(
  '/admin/dashboard',
);

mixin AdminRouteRefresh<T extends StatefulWidget> on State<T> {
  String get adminRouteLocation;

  Future<void> refreshAdminData();

  @override
  void initState() {
    super.initState();
    adminActiveLocation.addListener(_handleAdminLocationChanged);
  }

  void _handleAdminLocationChanged() {
    if (adminActiveLocation.value == adminRouteLocation) {
      refreshAdminData();
    }
  }

  @override
  void dispose() {
    adminActiveLocation.removeListener(_handleAdminLocationChanged);
    super.dispose();
  }
}
