import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jimiker/data/models/zone.dart';
import 'package:jimiker/data/models/zone_form_data.dart';
import 'package:jimiker/features/home/menu/chat/services/chat_service.dart';
import 'package:jimiker/features/home/menu/register_storage/screens/draw_screen.dart';
import 'package:jimiker/features/home/menu/register_storage/services/draw/draw_provider.dart';
import 'package:jimiker/features/home/menu/register_storage/services/register_provider.dart';
import 'package:jimiker/features/home/menu/register_storage/services/register_storage_validator.dart';
import 'package:jimiker/features/home/menu/register_storage/services/zone_provider.dart';
import 'package:jimiker/features/home/menu/register_storage/widgets/photo.dart';
import 'package:jimiker/features/home/menu/register_storage/widgets/zone_form_dialog.dart';

import '../../../../../services/auth_providers.dart';

class RegisterStorageScreen extends ConsumerStatefulWidget {
  const RegisterStorageScreen({super.key});

  @override
  ConsumerState<RegisterStorageScreen> createState() =>
      _RegisterStorageScreenState();
}

class _RegisterStorageScreenState
    extends ConsumerState<RegisterStorageScreen> {
  static const double _gridSize = 30.0;
  static const double _editorCanvasSize = 1000.0;

  late final TextEditingController _addressController;
  late final TextEditingController _detailAddressController;
  late final FocusNode _detailAddressFocusNode;

  // ✅ 편집 화면 진입 직전 provider를 1000 캔버스 기준으로 shift할 때,
  // 프리뷰(작은 레이아웃)가 clamp로 zone을 다시 “잘라서” 옮기지 않게 막는 플래그
  bool _suspendPreviewZoneClamp = false;

  @override
  void initState() {
    super.initState();
    _addressController = TextEditingController();
    _detailAddressController = TextEditingController();
    _detailAddressFocusNode = FocusNode(canRequestFocus: false);

    _addressController.text =
        ref.read(registerProvider).address ?? '';
    _detailAddressController.text =
        ref.read(registerProvider).detailAddress ?? '';
  }

  @override
  void dispose() {
    _addressController.dispose();
    _detailAddressController.dispose();
    _detailAddressFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final drawState = ref.watch(drawProvider);
    final zones = ref.watch(zoneProvider);
    final isStructureDrawn = drawState.lines.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: _clearDetailAddressFocus,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1) 사진
                      _buildSectionTitle("사진"),
                      const SizedBox(height: 10),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            const SizedBox(height: 10),
                            PhotoButton(
                              onTap: () {
                                ref
                                    .read(registerProvider.notifier)
                                    .pickImage();
                              },
                              pickedCount: ref
                                  .watch(registerProvider)
                                  .images
                                  .length,
                            ),
                            const SizedBox(width: 30),
                            PhotoList(
                              delete: (index) {
                                ref
                                    .read(registerProvider.notifier)
                                    .deletePhoto(index);
                              },
                              pickedImages: ref
                                  .watch(registerProvider)
                                  .images,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),

                      // 2) 주소
                      _buildSectionTitle("위치 정보"),
                      const SizedBox(height: 10),
                      _buildTextField(
                        onTap: () {
                          ref
                              .read(registerProvider.notifier)
                              .addressTap(
                                context,
                                _addressController,
                              );
                        },
                        controller: _addressController,
                        hint: "주소를 검색해주세요",
                        icon: Icons.search,
                        isReadOnly: true,
                      ),
                      const SizedBox(height: 10),
                      _buildTextField(
                        controller: _detailAddressController,
                        hint: "상세 주소를 입력해주세요",
                        icon: Icons.edit_location_alt_outlined,
                        focusNode: _detailAddressFocusNode,
                        onTap: _enableDetailAddressFocus,
                        onChanged: (value) {
                          ref
                              .read(registerProvider.notifier)
                              .updateDetailAddress(value);
                        },
                      ),
                      const SizedBox(height: 30),

                      // 3) 구조/구역
                      _buildSectionTitle("창고 배치 구성"),
                      const SizedBox(height: 10),
                      _buildStructureEditorArea(drawState),
                      const SizedBox(height: 20),

                      if (isStructureDrawn) ...[
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "등록된 구역 목록",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                              ),
                            ),
                            TextButton.icon(
                              onPressed: _showAddZoneDialog,
                              icon: const Icon(
                                Icons.add_box_outlined,
                                size: 18,
                              ),
                              label: const Text("구역 추가"),
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(
                                  0xFF6B66FF,
                                ),
                              ),
                            ),
                          ],
                        ),
                        _buildZoneList(zones),
                        const SizedBox(height: 20),
                      ],
                    ],
                  ),
                ),
              ),
              _buildBottomRegisterButton(),
            ],
          ),
        ),
      ),
    );
  }

  // =========================
  // UI builders
  // =========================

  Widget _buildStructureEditorArea(DrawProviderData drawState) {
    final zones = ref.watch(zoneProvider);

    final double layoutW = drawState.width.toDouble();
    final double layoutH = drawState.height.toDouble();

    return Container(
      width: double.infinity,
      height: layoutH + 100.0,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: drawState.lines.isNotEmpty
          ? Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: double.infinity,
                    height: double.infinity,
                    color: Colors.blueGrey[50],
                    child: Center(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: layoutW,
                          height: layoutH,
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: CustomPaint(
                                  painter: GridPainter(
                                    gridSize: _gridSize,
                                    width: layoutW,
                                    height: layoutH,
                                    lines: drawState.lines,
                                    doors: drawState.doors,
                                  ),
                                ),
                              ),
                              ..._buildZoneOverlays(
                                drawState: drawState,
                                zones: zones,
                                enableDrag: false,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: IconButton(
                    onPressed: _navigateToEditor,
                    icon: const CircleAvatar(
                      backgroundColor: Colors.white,
                      child: Icon(
                        Icons.edit,
                        color: Colors.black,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            )
          : Center(
              child: ElevatedButton.icon(
                onPressed: _navigateToEditor,
                icon: const Icon(Icons.draw_outlined),
                label: const Text("건물 부 구조 그리기"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6B66FF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildZoneList(List<Zone> zones) {
    if (zones.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        alignment: Alignment.center,
        child: Text(
          "상단 버튼을 눌러 구역을 추가해주세요.",
          style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: zones.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final zone = zones[index];
        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showZoneDialog(zone: zone),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFEFFF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.dashboard_customize,
                    color: Color(0xFF6B66FF),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "구역 ${zone.index}",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "크기 ${zone.width}m × ${zone.height}m · ${zone.price}원",
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.redAccent,
                    size: 20,
                  ),
                  onPressed: () {
                    ref
                        .read(zoneProvider.notifier)
                        .removeZone(zone.index);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildZoneOverlays({
    required DrawProviderData drawState,
    required List<Zone> zones,
    required bool enableDrag,
  }) {
    if (zones.isEmpty) return [];

    final layoutSize = Size(
      drawState.width.toDouble(),
      drawState.height.toDouble(),
    );

    return zones.map((zone) {
      final zoneWidth = zone.width.toDouble() * _gridSize;
      final zoneHeight = zone.height.toDouble() * _gridSize;

      // ✅ 편집 진입 직전에는 provider 좌표가 1000 기준으로 shift되므로
      // 프리뷰에서 clamp+update가 돌면 zone이 “잘려서” 한 곳에 모임.
      // 그래서 그 순간만 clamp/update를 잠깐 멈춤.
      final Offset position = _suspendPreviewZoneClamp
          ? Offset(zone.x.toDouble(), zone.y.toDouble())
          : _clampZoneOffset(
              Offset(zone.x.toDouble(), zone.y.toDouble()),
              Size(zoneWidth, zoneHeight),
              layoutSize,
            );

      if (!_suspendPreviewZoneClamp &&
          (position.dx != zone.x || position.dy != zone.y)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref
              .read(zoneProvider.notifier)
              .updateZone(
                zone.copyWith(x: position.dx, y: position.dy),
              );
        });
      }

      final content = Container(
        width: zoneWidth,
        height: zoneHeight,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0x336B66FF),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFF6B66FF)),
        ),
        child: Text(
          zone.index,
          style: const TextStyle(
            color: Color(0xFF6B66FF),
            fontWeight: FontWeight.bold,
          ),
        ),
      );

      return Positioned(
        left: position.dx,
        top: position.dy,
        child: enableDrag
            ? GestureDetector(
                onPanUpdate: (details) {
                  final updated = _clampZoneOffset(
                    Offset(
                      zone.x.toDouble() + details.delta.dx,
                      zone.y.toDouble() + details.delta.dy,
                    ),
                    Size(zoneWidth, zoneHeight),
                    layoutSize,
                  );

                  ref
                      .read(zoneProvider.notifier)
                      .updateZone(
                        zone.copyWith(x: updated.dx, y: updated.dy),
                      );
                },
                child: content,
              )
            : IgnorePointer(child: content),
      );
    }).toList();
  }

  Offset _clampZoneOffset(
    Offset offset,
    Size zoneSize,
    Size layoutSize,
  ) {
    final snapped = Offset(
      _snapToGrid(offset.dx),
      _snapToGrid(offset.dy),
    );

    final double maxX = (layoutSize.width - zoneSize.width)
        .clamp(0.0, layoutSize.width)
        .toDouble();
    final double maxY = (layoutSize.height - zoneSize.height)
        .clamp(0.0, layoutSize.height)
        .toDouble();

    return Offset(
      snapped.dx.clamp(0.0, maxX).toDouble(),
      snapped.dy.clamp(0.0, maxY).toDouble(),
    );
  }

  double _snapToGrid(double value) {
    return (value / _gridSize).round() * _gridSize;
  }

  // =========================
  // Actions
  // =========================

  void _navigateToEditor() async {
    _clearDetailAddressFocus();

    setState(() => _suspendPreviewZoneClamp = true);
    _prepareForEditorCanvas(); // ✅ B안 핵심: 편집 진입 직전에 1000 캔버스 기준으로 이동

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const DrawScreen()),
    );

    if (mounted) {
      setState(() => _suspendPreviewZoneClamp = false);
    }
    _clearDetailAddressFocus();
  }

  Future<void> _showAddZoneDialog() async {
    final nextIndex = ref.read(zoneProvider.notifier).nextIndex();
    await _showZoneDialog(index: nextIndex);
  }

  Future<void> _showZoneDialog({Zone? zone, String? index}) async {
    final zoneIndex = index ?? zone?.index ?? '';

    final result = await showDialog<ZoneFormData>(
      context: context,
      builder: (context) => ZoneFormDialog(
        index: zoneIndex,
        zone: zone == null
            ? null
            : ZoneFormData(
                width: zone.width,
                height: zone.height,
                price: zone.price,
              ),
      ),
    );

    if (result == null) return;

    final notifier = ref.read(zoneProvider.notifier);

    if (zone == null) {
      final drawState = ref.read(drawProvider);
      final zoneSize = Size(
        result.width * _gridSize,
        result.height * _gridSize,
      );
      final layoutSize = Size(
        drawState.width.toDouble(),
        drawState.height.toDouble(),
      );
      final position = _findAvailableZonePosition(
        zoneSize: zoneSize,
        layoutSize: layoutSize,
        zones: ref.read(zoneProvider),
      );

      notifier.addZone(
        Zone(
          index: zoneIndex,
          width: result.width,
          height: result.height,
          price: result.price,
          x: position.dx,
          y: position.dy,
          angle: 0,
        ),
      );
    } else {
      notifier.updateZone(
        zone.copyWith(
          width: result.width,
          height: result.height,
          price: result.price,
        ),
      );
    }
  }

  // =========================
  // B안 핵심: 편집(1000x1000) 진입 직전 좌표계 변환
  // =========================

  void _prepareForEditorCanvas() {
    final drawState = ref.read(drawProvider);
    final zones = ref.read(zoneProvider);

    final points = <Offset>[
      ...drawState.lines.expand((l) => [l.start, l.end]),
      ...drawState.doors,
      ...zones.expand(
        (z) => [
          Offset(z.x.toDouble(), z.y.toDouble()),
          Offset(
            z.x.toDouble() + (z.width.toDouble() * _gridSize),
            z.y.toDouble() + (z.height.toDouble() * _gridSize),
          ),
        ],
      ),
    ];

    if (points.isEmpty) return;

    final minX = points.map((p) => p.dx).reduce(min);
    final minY = points.map((p) => p.dy).reduce(min);
    final maxX = points.map((p) => p.dx).reduce(max);
    final maxY = points.map((p) => p.dy).reduce(max);

    final contentCenter = Offset(
      (minX + maxX) / 2,
      (minY + maxY) / 2,
    );
    const canvasCenter = Offset(
      _editorCanvasSize / 2,
      _editorCanvasSize / 2,
    );

    final rawTranslation = canvasCenter - contentCenter;

    // 격자 단위로 스냅 (선/문/구역이 동일 delta로 움직여야 함)
    final translation = Offset(
      _snapToGrid(rawTranslation.dx),
      _snapToGrid(rawTranslation.dy),
    );

    ref.read(drawProvider.notifier).shiftDrawing(translation);
    ref.read(zoneProvider.notifier).shiftZones(translation);
  }

  // =========================
  // Small UI helpers
  // =========================

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController? controller,
    required String hint,
    required IconData icon,
    void Function()? onTap,
    bool isReadOnly = false,
    void Function(String value)? onChanged,
    FocusNode? focusNode,
  }) {
    return TextField(
      onTap: onTap,
      controller: controller,
      focusNode: focusNode,
      readOnly: isReadOnly,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: const Color(0xFF6B66FF)),
        filled: true,
        fillColor: Colors.white,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF6B66FF)),
        ),
      ),
    );
  }

  Widget _buildBottomRegisterButton() {
    final registerRef = ref.watch(registerProvider);
    final drawState = ref.watch(drawProvider);
    final zones = ref.watch(zoneProvider);

    return Container(
      padding: const EdgeInsets.all(20),
      color: Colors.white,
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: registerRef.isSubmitting
              ? null
              : () async {
                  final detailAddress = _detailAddressController.text
                      .trim();

                  final validationResult =
                      RegisterStorageValidator.validate(
                        registerData: registerRef,
                        drawState: drawState,
                        zones: zones,
                        detailAddress: detailAddress,
                      );

                  if (!validationResult.isValid) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(validationResult.message),
                      ),
                    );
                    return;
                  }

                  try {
                    await ref
                        .read(registerProvider.notifier)
                        .registerStorage(
                          drawState: drawState,
                          zones: zones,
                          detailAddress: detailAddress,
                        );

                    if (!mounted) return;

                    final user = ref
                        .read(firebaseAuthProvider)
                        .currentUser;
                    if (user != null) {
                      final chatService = ChatService(
                        ref.read(firestoreProvider),
                      );
                      await chatService.sendSystemMessageToUser(
                        user: user,
                        message: '창고 등록 신청이 완료되었습니다.',
                      );
                    }

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("등록 요청이 완료되었습니다."),
                      ),
                    );

                    ref.read(registerProvider.notifier).reset();
                    ref.read(zoneProvider.notifier).reset();
                    ref.read(drawProvider.notifier).reset();
                    _addressController.clear();
                    _detailAddressController.clear();

                    if (mounted) {
                      Navigator.of(context).pop();
                    }
                  } catch (error) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("등록 중 오류가 발생했습니다: $error"),
                      ),
                    );
                  }
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            padding: EdgeInsets.zero,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: Ink(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6B66FF), Color(0xFF8FD3F4)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: registerRef.isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.white,
                        ),
                      ),
                    )
                  : const Text(
                      "등록하기",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  // =========================
  // Focus helpers
  // =========================

  void _enableDetailAddressFocus() {
    _detailAddressFocusNode.canRequestFocus = true;
    _detailAddressFocusNode.requestFocus();
  }

  void _clearDetailAddressFocus() {
    _detailAddressFocusNode.unfocus();
    _detailAddressFocusNode.canRequestFocus = false;
  }

  // =========================
  // Zone placement helper
  // =========================

  Offset _findAvailableZonePosition({
    required Size zoneSize,
    required Size layoutSize,
    required List<Zone> zones,
  }) {
    final maxX = (layoutSize.width - zoneSize.width)
        .clamp(0.0, layoutSize.width)
        .toDouble();
    final maxY = (layoutSize.height - zoneSize.height)
        .clamp(0.0, layoutSize.height)
        .toDouble();

    for (double y = _gridSize; y <= maxY; y += _gridSize) {
      for (double x = _gridSize; x <= maxX; x += _gridSize) {
        final rect = Rect.fromLTWH(
          x,
          y,
          zoneSize.width,
          zoneSize.height,
        );

        final overlaps = zones.any((zone) {
          final otherRect = Rect.fromLTWH(
            zone.x.toDouble(),
            zone.y.toDouble(),
            zone.width.toDouble() * _gridSize,
            zone.height.toDouble() * _gridSize,
          );
          return rect.overlaps(otherRect);
        });

        if (!overlaps) {
          return Offset(x, y);
        }
      }
    }

    return Offset(_gridSize, _gridSize);
  }
}
