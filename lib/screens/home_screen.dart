import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/water_service.dart';
import '../services/notification_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final WaterService _waterService = WaterService();
  final NotificationService _notificationService = NotificationService();
  late AnimationController _progressAnimController;
  late Animation<double> _progressAnimation;
  double _animatedProgress = 0.0;
  Timer? _midnightTimer;

  // Quick-add presets in ml
  static const List<int> _quickAddOptions = [150, 200, 300, 500];

  @override
  void initState() {
    super.initState();
    _progressAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _progressAnimation = CurvedAnimation(
      parent: _progressAnimController,
      curve: Curves.easeInOut,
    );
    _waterService.addListener(_onWaterChanged);
    _initServices();
    _scheduleMidnightReset();
  }

  Future<void> _initServices() async {
    await _waterService.init();
    _animateProgress(_waterService.progressFraction);
  }

  void _onWaterChanged() {
    _animateProgress(_waterService.progressFraction);
  }

  void _animateProgress(double target) {
    _progressAnimation = Tween<double>(
      begin: _animatedProgress,
      end: target,
    ).animate(CurvedAnimation(
      parent: _progressAnimController,
      curve: Curves.easeInOut,
    ));
    _progressAnimController.forward(from: 0);
    _progressAnimation.addListener(() {
      setState(() {
        _animatedProgress = _progressAnimation.value;
      });
    });
  }

  void _scheduleMidnightReset() {
    final now = DateTime.now();
    final midnight =
        DateTime(now.year, now.month, now.day + 1, 0, 0, 5); // 5s past midnight
    final diff = midnight.difference(now);
    _midnightTimer = Timer(diff, () {
      _waterService.resetToday();
      _scheduleMidnightReset(); // reschedule for next day
    });
  }

  Future<void> _addWater(int amountMl) async {
    await _waterService.addWater(amountMl);
    if (_waterService.goalReached) {
      _showGoalReachedSnackbar();
    } else {
      _showAddedSnackbar(amountMl);
    }
  }

  void _showAddedSnackbar(int amountMl) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.water_drop, color: Colors.white),
            const SizedBox(width: 8),
            Text('+${amountMl}ml 추가됐어요!'),
          ],
        ),
        backgroundColor: const Color(0xFF2196F3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showGoalReachedSnackbar() {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.emoji_events, color: Colors.amber),
            SizedBox(width: 8),
            Text('오늘 목표 달성! 정말 잘했어요! 🎉'),
          ],
        ),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _showCustomAmountDialog() async {
    int? custom;
    await showDialog<int>(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('직접 입력'),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: '섭취량 (ml)',
              suffixText: 'ml',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () {
                final val = int.tryParse(controller.text.trim());
                if (val != null && val > 0) {
                  custom = val;
                  Navigator.pop(ctx);
                }
              },
              child: const Text('추가'),
            ),
          ],
        );
      },
    );
    if (custom != null) {
      await _addWater(custom!);
    }
  }

  Future<void> _toggleNotifications() async {
    if (_notificationService.remindersEnabled) {
      _notificationService.disableReminders();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('알림이 꺼졌어요'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } else {
      final enabled =
          await _notificationService.enableReminders(intervalMinutes: 30);
      if (mounted) {
        if (enabled) {
          _notificationService.sendTestNotification();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('30분마다 음수 알림이 켜졌어요'),
              backgroundColor: Colors.green.shade700,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  '알림을 켤 수 없어요. 브라우저에서 알림 권한을 허용해 주세요.'),
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    }
    setState(() {});
  }

  Future<void> _showResetConfirmDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('오늘 기록 초기화'),
        content: const Text(
            '오늘 섭취한 물 기록을 모두 초기화할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.red.shade400),
            onPressed: () => Navigator.pop(ctx, true),
            child:
                const Text('초기화', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _waterService.resetToday();
    }
  }

  Future<void> _showGoalDialog() async {
    double tempGoal = _waterService.dailyGoalMl / 1000.0;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('하루 목표량 설정'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('0.5L 단위로 조절하세요',
                  style: TextStyle(fontSize: 13, color: Colors.grey)),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: tempGoal > 0.5
                        ? () => setDialogState(() => tempGoal -= 0.5)
                        : null,
                    icon: const Icon(Icons.remove_circle_outline),
                    iconSize: 36,
                    color: Colors.blue,
                  ),
                  const SizedBox(width: 16),
                  Text(
                    '${tempGoal.toStringAsFixed(1)} L',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    onPressed: tempGoal < 10.0
                        ? () => setDialogState(() => tempGoal += 0.5)
                        : null,
                    icon: const Icon(Icons.add_circle_outline),
                    iconSize: 36,
                    color: Colors.blue,
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _waterService.setGoal((tempGoal * 1000).round());
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        '목표량이 ${tempGoal.toStringAsFixed(1)}L로 변경됐어요!'),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: Colors.purple.shade600,
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              child: const Text('저장'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _waterService.removeListener(_onWaterChanged);
    _waterService.dispose();
    _notificationService.dispose();
    _progressAnimController.dispose();
    _midnightTimer?.cancel();
    super.dispose();
  }

  // ─── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final notifSupported = _notificationService.isSupported;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F7FF),
      appBar: AppBar(
        backgroundColor: cs.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.water_drop, size: 24),
            SizedBox(width: 8),
            Text(
              '물 마시기',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.flag_outlined),
            tooltip: '목표량 변경',
            onPressed: _showGoalDialog,
          ),
          if (notifSupported)
            AnimatedBuilder(
              animation: _notificationService,
              builder: (_, __) => IconButton(
                icon: Icon(
                  _notificationService.remindersEnabled
                      ? Icons.notifications_active
                      : Icons.notifications_none,
                ),
                tooltip: _notificationService.remindersEnabled
                    ? '알림 끄기'
                    : '알림 켜기',
                onPressed: _toggleNotifications,
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '오늘 초기화',
            onPressed: _showResetConfirmDialog,
          ),
        ],
      ),
      body: !_waterService.initialized
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(cs, notifSupported),
    );
  }

  Widget _buildBody(ColorScheme cs, bool notifSupported) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildDateCard(),
              const SizedBox(height: 16),
              _buildProgressCard(cs),
              const SizedBox(height: 16),
              _buildQuickAddCard(cs),
              const SizedBox(height: 16),
              if (notifSupported) ...[
                _buildNotificationCard(cs),
                const SizedBox(height: 16),
              ],
              _buildHistoryCard(cs),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Date Card ──────────────────────────────────────────────────────────────

  Widget _buildDateCard() {
    final now = DateTime.now();
    final dayFormat = DateFormat('M월 d일 (E)', 'ko');
    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, size: 18, color: Color(0xFF2196F3)),
            const SizedBox(width: 10),
            Text(
              dayFormat.format(now),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Color(0xFF37474F),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Progress Card ──────────────────────────────────────────────────────────

  Widget _buildProgressCard(ColorScheme cs) {
    final total = _waterService.totalIntakeMl;
    final goal = _waterService.dailyGoalMl;
    final remaining = _waterService.remainingMl;
    final reached = _waterService.goalReached;

    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            GestureDetector(
              onTap: _showGoalDialog,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '오늘의 목표',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.edit, size: 16, color: cs.primary),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _buildCircularProgress(cs, total, goal, reached),
            const SizedBox(height: 24),
            _buildStatsRow(total, goal, remaining, reached),
            const SizedBox(height: 16),
            _buildLinearProgressBar(cs, reached),
          ],
        ),
      ),
    );
  }

  Widget _buildCircularProgress(
      ColorScheme cs, int total, int goal, bool reached) {
    final progressColor = reached ? Colors.green : cs.primary;

    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: 180,
          height: 180,
          child: CircularProgressIndicator(
            value: 1.0,
            strokeWidth: 14,
            color: const Color(0xFFE3F2FD),
          ),
        ),
        SizedBox(
          width: 180,
          height: 180,
          child: CircularProgressIndicator(
            value: _animatedProgress,
            strokeWidth: 14,
            color: progressColor,
            strokeCap: StrokeCap.round,
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (reached)
              const Icon(Icons.emoji_events, color: Colors.amber, size: 32)
            else
              Icon(Icons.water_drop, color: cs.primary, size: 32),
            const SizedBox(height: 4),
            Text(
              '${total}ml',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: progressColor,
              ),
            ),
            Text(
              '목표 ${goal}ml',
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatsRow(int total, int goal, int remaining, bool reached) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _statChip(
          icon: Icons.check_circle_outline,
          label: '섭취량',
          value: '${total}ml',
          color: Colors.blue,
        ),
        _statChip(
          icon: Icons.flag_outlined,
          label: '목표',
          value: '${goal}ml',
          color: Colors.purple,
        ),
        _statChip(
          icon: reached ? Icons.done_all : Icons.hourglass_bottom,
          label: reached ? '달성!' : '남은량',
          value: reached ? '🎉' : '${remaining}ml',
          color: reached ? Colors.green : Colors.orange,
        ),
      ],
    );
  }

  Widget _statChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.bold, color: color)),
        Text(label,
            style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }

  Widget _buildLinearProgressBar(ColorScheme cs, bool reached) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('0ml',
                style: TextStyle(fontSize: 11, color: Colors.grey)),
            Text(
              '${(_animatedProgress * 100).toStringAsFixed(0)}%',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: reached ? Colors.green : cs.primary,
              ),
            ),
            const Text('2000ml',
                style: TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: _animatedProgress,
            minHeight: 12,
            backgroundColor: const Color(0xFFE3F2FD),
            valueColor: AlwaysStoppedAnimation<Color>(
              reached ? Colors.green : cs.primary,
            ),
          ),
        ),
      ],
    );
  }

  // ─── Quick Add Card ─────────────────────────────────────────────────────────

  Widget _buildQuickAddCard(ColorScheme cs) {
    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '빠른 추가',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF37474F)),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                for (final ml in _quickAddOptions)
                  _quickAddButton(ml, cs),
                _customAddButton(cs),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickAddButton(int ml, ColorScheme cs) {
    return SizedBox(
      width: 90,
      child: ElevatedButton(
        onPressed: () => _addWater(ml),
        style: ElevatedButton.styleFrom(
          backgroundColor: cs.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.water_drop, size: 18),
            const SizedBox(height: 4),
            Text(
              '${ml}ml',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _customAddButton(ColorScheme cs) {
    return SizedBox(
      width: 90,
      child: OutlinedButton(
        onPressed: _showCustomAmountDialog,
        style: OutlinedButton.styleFrom(
          foregroundColor: cs.primary,
          side: BorderSide(color: cs.primary),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, size: 18),
            SizedBox(height: 4),
            Text('직접입력',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  // ─── Notification Card ──────────────────────────────────────────────────────

  Widget _buildNotificationCard(ColorScheme cs) {
    return AnimatedBuilder(
      animation: _notificationService,
      builder: (_, __) {
        final enabled = _notificationService.remindersEnabled;
        return Card(
          color: enabled
              ? const Color(0xFFE8F5E9)
              : Colors.white,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              children: [
                Icon(
                  enabled
                      ? Icons.notifications_active
                      : Icons.notifications_none,
                  color: enabled ? Colors.green.shade700 : Colors.grey,
                  size: 28,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '음수 알림',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: enabled
                              ? Colors.green.shade800
                              : const Color(0xFF37474F),
                        ),
                      ),
                      Text(
                        enabled
                            ? '${_notificationService.intervalMinutes}분마다 알림'
                            : '규칙적으로 물 마시도록 알림을 받아보세요',
                        style: const TextStyle(
                            fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: enabled,
                  activeColor: Colors.green.shade600,
                  onChanged: (_) => _toggleNotifications(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─── History Card ───────────────────────────────────────────────────────────

  Widget _buildHistoryCard(ColorScheme cs) {
    final entries = _waterService.entries.reversed.toList();

    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  '오늘 기록',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF37474F)),
                ),
                const Spacer(),
                if (entries.isNotEmpty)
                  Text(
                    '총 ${entries.length}건',
                    style:
                        const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (entries.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.water_drop_outlined,
                          size: 40, color: Colors.grey),
                      SizedBox(height: 8),
                      Text(
                        '아직 기록이 없어요.\n위 버튼을 눌러 물 섭취를 기록해보세요!',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: entries.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, thickness: 0.5),
                itemBuilder: (ctx, i) {
                  final entry = entries[i];
                  final realIndex =
                      _waterService.entries.length - 1 - i;
                  final timeStr =
                      DateFormat('HH:mm').format(entry.timestamp);
                  return ListTile(
                    dense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: cs.primary.withOpacity(0.12),
                      child: Icon(Icons.water_drop,
                          size: 16, color: cs.primary),
                    ),
                    title: Text(
                      '${entry.amountMl} ml',
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      timeStr,
                      style: const TextStyle(
                          fontSize: 12, color: Colors.grey),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline,
                          size: 18, color: Colors.redAccent),
                      tooltip: '삭제',
                      onPressed: () =>
                          _waterService.removeEntry(realIndex),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
