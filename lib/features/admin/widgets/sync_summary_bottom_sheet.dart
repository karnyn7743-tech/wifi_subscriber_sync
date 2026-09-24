import 'package:flutter/material.dart';
import '../../../models/subscriber_model.dart';
import '../../../models/sync_diff_report.dart';

class SyncSummaryBottomSheet extends StatelessWidget {
  final SyncDiffReport report;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const SyncSummaryBottomSheet({
    super.key,
    required this.report,
    required this.onConfirm,
    required this.onCancel,
  });

  static Future<bool?> show(
    BuildContext context, {
    required SyncDiffReport report,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: false,
      isDismissible: false,
      builder: (ctx) => SyncSummaryBottomSheet(
        report: report,
        onConfirm: () => Navigator.pop(ctx, true),
        onCancel: () => Navigator.pop(ctx, false),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 48,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 16),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.compare_arrows_rounded, color: Colors.teal, size: 28),
              SizedBox(width: 8),
              Text(
                'ملخص المزامنة والدمج',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'راجع التعديلات قبل اعتمادها وحفظها في قاعدة البيانات',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildStatBadge('مشتركين جدد', report.newSubscribers.length, Colors.green, Icons.person_add_alt_1),
                const SizedBox(width: 8),
                _buildStatBadge('تعديلات/تجديد', report.updatedSubscribers.length, Colors.orange.shade800, Icons.edit_note),
                const SizedBox(width: 8),
                _buildStatBadge('دون تغيير', report.unchangedSubscribers.length, Colors.grey.shade700, Icons.check_circle_outline),
              ],
            ),
          ),
          const Divider(height: 28),
          Expanded(
            child: report.hasAnyChanges
                ? ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      if (report.newSubscribers.isNotEmpty) ...[
                        _buildSectionHeader('المشتركون الجدد المُضافون', Colors.green),
                        ...report.newSubscribers.map((s) => _buildSubscriberTile(s, isNew: true)),
                      ],
                      if (report.updatedSubscribers.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _buildSectionHeader('المشتركون الذين تم تحديث بياناتهم', Colors.orange.shade800),
                        ...report.updatedSubscribers.map((s) => _buildSubscriberTile(s, isNew: false)),
                      ],
                    ],
                  )
                : const Center(
                    child: Text(
                      'جميع البيانات متطابقة تماماً. لا توجد تغييرات.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                )
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: Colors.grey.shade400),
                    ),
                    onPressed: onCancel,
                    child: const Text('إلغاء المزامنة', style: TextStyle(color: Colors.black87)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.save_alt),
                    label: Text(
                      'تأكيد وحفظ (${report.finalMergedList.length})',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: onConfirm,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatBadge(String label, int count, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text('$count', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            Text(label, style: TextStyle(fontSize: 11, color: color), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
    );
  }

  Widget _buildSubscriberTile(Subscriber sub, {required bool isNew}) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 0,
      color: isNew ? Colors.green.shade50 : Colors.orange.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: isNew ? Colors.green.shade200 : Colors.orange.shade200),
      ),
      child: ListTile(
        dense: true,
        leading: Icon(
          isNew ? Icons.add_circle : Icons.published_with_changes,
          color: isNew ? Colors.green : Colors.orange.shade800,
        ),
        title: Text(sub.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          'الجهاز: ${sub.deviceId.substring(0, sub.deviceId.length > 8 ? 8 : sub.deviceId.length)}... • ${sub.isPaid ? 'مسدد' : 'غير مسدد'}',
          style: const TextStyle(fontSize: 11),
        ),
        trailing: Text(sub.expiryDate.split('T').first, style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
      ),
    );
  }
}
