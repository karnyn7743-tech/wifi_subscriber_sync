import 'subscriber_model.dart';

class SyncDiffReport {
  final List<Subscriber> newSubscribers;
  final List<Subscriber> updatedSubscribers;
  final List<Subscriber> unchangedSubscribers;
  final List<Subscriber> finalMergedList;

  SyncDiffReport({
    required this.newSubscribers,
    required this.updatedSubscribers,
    required this.unchangedSubscribers,
    required this.finalMergedList,
  });

  factory SyncDiffReport.compute({
    required List<Subscriber> localList,
    required List<Subscriber> incomingList,
  }) {
    final localMap = {for (var s in localList) s.deviceId: s};
    final List<Subscriber> added = [];
    final List<Subscriber> updated = [];
    final List<Subscriber> unchanged = [];
    final Map<String, Subscriber> mergedMap = Map.from(localMap);

    for (final incoming in incomingList) {
      final existing = localMap[incoming.deviceId];

      if (existing == null) {
        added.add(incoming);
        mergedMap[incoming.deviceId] = incoming;
      } else {
        final hasChanges = existing.fullName != incoming.fullName ||
            existing.isPaid != incoming.isPaid ||
            existing.expiryDate != incoming.expiryDate ||
            existing.notes != incoming.notes;

        if (hasChanges) {
          updated.add(incoming);
          mergedMap[incoming.deviceId] = incoming;
        } else {
          unchanged.add(existing);
        }
      }
    }

    return SyncDiffReport(
      newSubscribers: added,
      updatedSubscribers: updated,
      unchangedSubscribers: unchanged,
      finalMergedList: mergedMap.values.toList(),
    );
  }

  bool get hasAnyChanges => newSubscribers.isNotEmpty || updatedSubscribers.isNotEmpty;
}

