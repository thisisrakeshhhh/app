import 'package:flutter/material.dart';
import '../../data/local/app_database.dart';
import '../../l10n/app_strings.dart';
import '../../services/api_service.dart';

class SyncStatusView extends StatefulWidget {
  final ApiService api;

  const SyncStatusView({super.key, required this.api});

  @override
  State<SyncStatusView> createState() => _SyncStatusViewState();
}

class _SyncStatusViewState extends State<SyncStatusView> {
  bool _isLoading = true;
  List<OutboxMutationEntry> _pendingMutations = [];

  @override
  void initState() {
    super.initState();
    _loadMutations();
  }

  Future<void> _loadMutations() async {
    setState(() => _isLoading = true);
    final list = await widget.api.db.outboxDao.getPendingQueue();
    if (mounted) {
      setState(() {
        _pendingMutations = list;
        _isLoading = false;
      });
    }
  }

  void _showTimelineModal(String orderId) async {
    final timeline = await widget.api.getOrderAuditTimeline(orderId);
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppStrings.auditTimeline,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                'Order ID: $orderId',
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
              const Divider(height: 24),
              for (int i = 0; i < timeline.length; i++) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      children: [
                        Icon(
                          timeline[i].isCompleted
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          color: timeline[i].isCompleted
                              ? Colors.green[700]
                              : Colors.amber[800],
                          size: 22,
                        ),
                        if (i < timeline.length - 1)
                          Container(
                            width: 2,
                            height: 28,
                            color: Colors.grey[300],
                          ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            timeline[i].title,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            timeline[i].subtitle,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (i < timeline.length - 1) const SizedBox(height: 4),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(AppStrings.close),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.syncStatusTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMutations,
            tooltip: AppStrings.retry,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadMutations,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Main honest status card
                  Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.blueGrey.shade200),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.offline_pin, color: Colors.blue[800], size: 28),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  AppStrings.savedOnPhoneOutbox,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue[900],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            AppStrings.pendingMutationsCount(_pendingMutations.length),
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.amber.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline, size: 18, color: Colors.amber[900]),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    AppStrings.syncWorkerNote,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.amber[900],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                  Text(
                    'Local Outbox Queue (Ordered FIFO)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 8),

                  if (_pendingMutations.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Center(
                          child: Text(
                            'No pending mutations. Outbox queue is clear.',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ),
                      ),
                    )
                  else
                    ..._pendingMutations.map((m) {
                      final dt = DateTime.fromMillisecondsSinceEpoch(m.createdAtEpochMs);
                      final timeStr =
                          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
                      final honestLabel = widget.api.getHonestSyncStatusLabel(m.syncStatus);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          leading: CircleAvatar(
                            backgroundColor: Colors.blueGrey.shade100,
                            child: Text(
                              '#${m.sequenceOrder}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.blueGrey.shade900,
                              ),
                            ),
                          ),
                          title: Row(
                            children: [
                              Text(
                                m.mutationType,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade100,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  m.syncStatus,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.amber.shade900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                'Provisional: ${m.provisionalBusinessId}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              Text(
                                '$honestLabel • $timeStr',
                                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                              ),
                            ],
                          ),
                          trailing: (m.provisionalBusinessId?.startsWith('LOCAL-ORD-') ?? false) ||
                                  (m.provisionalBusinessId?.startsWith('ord_') ?? false)
                              ? IconButton(
                                  icon: const Icon(Icons.timeline, color: Colors.blue),
                                  tooltip: AppStrings.auditTimeline,
                                  onPressed: () => _showTimelineModal(
                                    m.provisionalBusinessId!,
                                  ),
                                )
                              : null,
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}
