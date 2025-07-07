// Test script to verify the Stop Local Alerts functionality
// This file can be used to test the new button and functionality

import 'package:flutter_test/flutter_test.dart';
import 'package:emergency_alert/services/emergency_response_service.dart';

void main() {
  group('Stop Local Alerts Tests', () {
    late EmergencyResponseService emergencyService;

    setUp(() {
      emergencyService = EmergencyResponseService();
    });

    test(
      'hasActiveLocalServices should return false when no services are active',
      () {
        // Initially, no services should be active
        expect(emergencyService.hasActiveLocalServices, isFalse);
      },
    );

    test('isEmergencyActive should return false initially', () {
      expect(emergencyService.isEmergencyActive, isFalse);
    });

    test('stopLocalAlerts should complete without errors', () async {
      // This should not throw an error even when no alerts are active
      await expectLater(emergencyService.stopLocalAlerts(), completes);
    });

    test('Emergency state should be accessible', () {
      expect(emergencyService.emergencyActiveStream, isNotNull);
      expect(emergencyService.countdownStream, isNotNull);
      expect(emergencyService.currentAlertStream, isNotNull);
    });
  });
}
