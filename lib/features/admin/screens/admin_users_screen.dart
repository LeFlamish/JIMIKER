import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jimiker/core/widgets/cached_image.dart';
import 'package:jimiker/core/widgets/detail_section.dart';
import 'package:jimiker/data/models/user.dart';
import 'package:jimiker/features/admin/services/admin_providers.dart';

/// 가입자 목록. 닉네임·이메일로 검색하고 상세로 들어간다.
class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  ConsumerState<AdminUsersScreen> createState() =>
      _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen> {
  final TextEditingController _searchController =
      TextEditingController();
  String _keyword = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<AppUser> _filter(List<AppUser> users) {
    final keyword = _keyword.trim().toLowerCase();
    if (keyword.isEmpty) return users;
    return users
        .where(
          (user) =>
              user.nickName.toLowerCase().contains(keyword) ||
              user.email.toLowerCase().contains(keyword),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(adminUsersProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text('사용자 관리'),
        centerTitle: true,
        backgroundColor: const Color(0xFFF5F6FA),
        elevation: 0,
        titleTextStyle: const TextStyle(
          color: Color(0xFF222222),
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            size: 20,
            color: Colors.black,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _keyword = value),
                decoration: InputDecoration(
                  hintText: '닉네임 또는 이메일로 검색',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 4,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Expanded(
              child: usersAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      '사용자 목록을 불러오지 못했어요.\n관리자 권한이 있는지 확인해주세요.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey[600],
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
                data: (users) {
                  final filtered = _filter(users);
                  if (filtered.isEmpty) {
                    return Center(
                      child: Text(
                        _keyword.isEmpty ? '가입자가 없어요.' : '검색 결과가 없어요.',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) =>
                        _UserRow(user: filtered[index]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserRow extends StatelessWidget {
  const _UserRow({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListTile(
        leading: CachedAvatar(photoUrl: user.photoURL),
        title: Row(
          children: [
            Flexible(
              child: Text(
                user.nickName.isEmpty ? '(닉네임 없음)' : user.nickName,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (user.isManager) ...[
              const SizedBox(width: 6),
              const _Badge(text: '관리자', color: Color(0xFF6B7AF5)),
            ],
            if (user.suspended) ...[
              const SizedBox(width: 6),
              const _Badge(text: '정지', color: Color(0xFFD32F2F)),
            ],
          ],
        ),
        subtitle: Text(
          user.email.isEmpty ? '(이메일 없음)' : user.email,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12.5, color: Colors.grey[600]),
        ),
        trailing: const Icon(
          Icons.chevron_right,
          size: 20,
          color: Colors.grey,
        ),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => AdminUserDetailScreen(user: user),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}

/// 사용자 한 명의 활동과 정지 처리
class AdminUserDetailScreen extends ConsumerStatefulWidget {
  const AdminUserDetailScreen({super.key, required this.user});

  final AppUser user;

  @override
  ConsumerState<AdminUserDetailScreen> createState() =>
      _AdminUserDetailScreenState();
}

class _AdminUserDetailScreenState
    extends ConsumerState<AdminUserDetailScreen> {
  bool _isWorking = false;

  AppUser get _user => widget.user;

  String _formatDate(DateTime date) =>
      '${date.year}.${date.month.toString().padLeft(2, '0')}'
      '.${date.day.toString().padLeft(2, '0')}';

  Future<void> _toggleSuspend() async {
    final suspending = !_user.suspended;
    String reason = '';

    if (suspending) {
      final input = await _askReason();
      if (input == null || input.isEmpty) return;
      reason = input;
    } else {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('정지를 해제할까요?'),
          content: const Text('다시 예약과 창고 등록을 할 수 있게 됩니다.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(
                '닫기',
                style: TextStyle(color: Colors.grey[700]),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text(
                '해제',
                style: TextStyle(
                  color: Color(0xFF2E7D32),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    if (!mounted) return;
    setState(() => _isWorking = true);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      await ref
          .read(adminActionsProvider)
          .setUserSuspended(
            uid: _user.uid,
            suspended: suspending,
            reason: reason,
          );
      ref.invalidate(adminSummaryProvider);
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(content: Text(suspending ? '이용을 정지했어요.' : '정지를 해제했어요.')),
      );
    } catch (error) {
      if (mounted) setState(() => _isWorking = false);
      messenger.showSnackBar(
        SnackBar(content: Text('처리하지 못했어요: $error')),
      );
    }
  }

  Future<String?> _askReason() {
    final controller = TextEditingController();

    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('이용 정지'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '정지하면 새 예약과 창고 등록이 막힙니다.\n'
              '진행 중인 거래를 정리할 수 있도록 채팅은 그대로 열어둡니다.\n'
              '사유는 본인에게 전달됩니다.',
              style: TextStyle(fontSize: 13.5, height: 1.5),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              autofocus: true,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: '예) 허위 매물을 반복해서 등록했습니다.',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              '닫기',
              style: TextStyle(color: Colors.grey[700]),
            ),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text(
              '정지',
              style: TextStyle(
                color: Color(0xFFD32F2F),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activityAsync = ref.watch(
      userActivityProvider(_user.uid),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text('사용자 정보'),
        centerTitle: true,
        backgroundColor: const Color(0xFFF5F6FA),
        elevation: 0,
        titleTextStyle: const TextStyle(
          color: Color(0xFF222222),
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            size: 20,
            color: Colors.black,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            if (_user.suspended)
              DetailStatusBanner(
                icon: Icons.block,
                label: '이용 정지됨',
                description: _user.suspendReason.isEmpty
                    ? '사유가 기록되지 않았습니다.'
                    : _user.suspendReason,
                color: const Color(0xFFD32F2F),
                background: const Color(0xFFFFEBEE),
              )
            else if (_user.isManager)
              const DetailStatusBanner(
                icon: Icons.shield_outlined,
                label: '관리자 계정',
                description: '창고 승인과 사용자 관리를 할 수 있습니다.',
                color: Color(0xFF6B7AF5),
                background: Color(0xFFF0F1FF),
              )
            else
              const DetailStatusBanner(
                icon: Icons.check_circle_outline,
                label: '정상 이용 중',
                description: '제한 없이 이용하고 있습니다.',
                color: Color(0xFF2E7D32),
                background: Color(0xFFE8F5E9),
              ),
            const SizedBox(height: 16),
            DetailCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const DetailSectionTitle('계정'),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      CachedAvatar(photoUrl: _user.photoURL, radius: 26),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          _user.nickName.isEmpty
                              ? '(닉네임 없음)'
                              : _user.nickName,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  DetailInfoRow(
                    label: '이메일',
                    value: _user.email.isEmpty ? '(없음)' : _user.email,
                  ),
                  if (_user.createdAt != null)
                    DetailInfoRow(
                      label: '가입일',
                      value: _formatDate(_user.createdAt!),
                    ),
                  if (_user.lastLoginAt != null)
                    DetailInfoRow(
                      label: '최근 로그인',
                      value: _formatDate(_user.lastLoginAt!),
                    ),
                  DetailInfoRow(
                    label: '알림 수신',
                    value: _user.fcmToken.isEmpty ? '꺼짐' : '켜짐',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            DetailCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const DetailSectionTitle('활동'),
                  const SizedBox(height: 14),
                  activityAsync.when(
                    loading: () => const SizedBox(
                      height: 40,
                      child: Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        ),
                      ),
                    ),
                    error: (_, __) => Text(
                      '활동 정보를 불러오지 못했어요.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                    data: (activity) => Column(
                      children: [
                        DetailInfoRow(
                          label: '등록 창고',
                          value: '${activity.storageCount}개',
                        ),
                        DetailInfoRow(
                          label: '진행 중 예약',
                          value: '${activity.reservationCount}건',
                        ),
                        DetailInfoRow(
                          label: '이용 중',
                          value: '${activity.usageCount}건',
                        ),
                        DetailInfoRow(
                          label: '이용 완료',
                          value: '${activity.endedCount}건',
                        ),
                        if (activity.hasOngoing)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '진행 중인 거래가 있습니다. 정지하면 상대방도 영향을 받습니다.',
                              style: TextStyle(
                                fontSize: 12.5,
                                height: 1.4,
                                color: Colors.orange[800],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildBottomBar() {
    // 관리자 계정은 앱에서 손대지 않는다. 등급 변경은 콘솔에서만.
    if (_user.isManager) {
      return SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          color: Colors.white,
          child: Text(
            '관리자 계정은 앱에서 변경할 수 없습니다.\n등급 조정은 Firebase 콘솔에서 해주세요.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: Colors.grey[600],
            ),
          ),
        ),
      );
    }

    final suspended = _user.suspended;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFF0F0F0))),
        ),
        child: SizedBox(
          height: 52,
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isWorking ? null : _toggleSuspend,
            style: ElevatedButton.styleFrom(
              backgroundColor: suspended
                  ? const Color(0xFF2E7D32)
                  : const Color(0xFFD32F2F),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isWorking
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : Text(
                    suspended ? '정지 해제' : '이용 정지',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
