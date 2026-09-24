import 'package:flutter_test/flutter_test.dart';
import 'package:wifi_subscriber_sync/models/subscriber_model.dart';
import 'package:wifi_subscriber_sync/models/sync_diff_report.dart';

void main() {
  group('اختبارات خوارزمية تحليل الفروقات والدمج', () {
    test('تصنيف المشتركين الجدد والمعدلين بدقة دون تكرار المعرفات', () {
      final local = [
        Subscriber(deviceId: 'dev_1', fullName: 'علي', isPaid: true, expiryDate: '2026-10-01'),
        Subscriber(deviceId: 'dev_2', fullName: 'سالم', isPaid: false, expiryDate: '2026-09-01'),
      ];

      final incoming = [
        // تعديل على dev_2 ليصبح مسدداً
        Subscriber(deviceId: 'dev_2', fullName: 'سالم', isPaid: true, expiryDate: '2026-11-01'),
        // مشترك جديد
        Subscriber(deviceId: 'dev_3', fullName: 'فهد', isPaid: true, expiryDate: '2026-12-01'),
      ];

      final report = SyncDiffReport.compute(localList: local, incomingList: incoming);

      expect(report.newSubscribers.length, equals(1));
      expect(report.newSubscribers.first.deviceId, equals('dev_3'));

      expect(report.updatedSubscribers.length, equals(1));
      expect(report.updatedSubscribers.first.deviceId, equals('dev_2'));
      expect(report.updatedSubscribers.first.isPaid, isTrue);

      expect(report.finalMergedList.length, equals(3));
    });
  });
}

