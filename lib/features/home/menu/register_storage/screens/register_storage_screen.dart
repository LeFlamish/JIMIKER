import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:jimiker/data/models/storage.dart';
import 'package:jimiker/data/models/zone.dart';
import 'package:jimiker/data/models/zone_form_data.dart';
import 'package:jimiker/features/home/menu/chat/services/chat_service.dart';
import 'package:jimiker/features/home/menu/my_storages/services/my_storages_provider.dart';
import 'package:jimiker/features/home/menu/my_storages/services/storage_edit_config.dart';
import 'package:jimiker/core/utils/space_units.dart';
import 'package:jimiker/features/draw/draw_screen.dart';
import 'package:jimiker/features/draw/draw_provider.dart';
import 'package:jimiker/features/home/menu/register_storage/services/register_provider.dart';
import 'package:jimiker/features/home/menu/register_storage/services/register_storage_validator.dart';
import 'package:jimiker/features/draw/zone_provider.dart';
import 'package:jimiker/features/home/menu/register_storage/widgets/photo.dart';
import 'package:jimiker/features/home/menu/register_storage/widgets/zone_form_dialog.dart';

import '../../../../../services/auth_providers.dart';

class RegisterStorageScreen extends ConsumerStatefulWidget {
  const RegisterStorageScreen({super.key, this.editConfig});

  final StorageEditConfig? editConfig;

  @override
  ConsumerState<RegisterStorageScreen> createState() =>
      _RegisterStorageScreenState();
}

class _RegisterStorageScreenState
    extends ConsumerState<RegisterStorageScreen> {
  /// 도면 좌표(m)를 미리보기에 그릴 때 쓰는 배율
  static const double _ppm = kPixelsPerMeter;
  static const double _cellM = kGridCellMeters;

  late final TextEditingController _addressController;
  late final TextEditingController _detailAddressController;
  late final FocusNode _detailAddressFocusNode;

  bool _isLoadingEditData = false;

  @override
  void initState() {
    super.initState();
    _addressController = TextEditingController();
    _detailAddressController = TextEditingController();
    _detailAddressFocusNode = FocusNode(canRequestFocus: false);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final editConfig = widget.editConfig;
      if (editConfig != null) {
        _hydrateEditData(editConfig);
      } else {
        // 새 등록에는 잠긴 구역이 없다. 이전 수정에서 남았을 수 있어 비운다.
        ref.read(lockedZonesProvider.notifier).state = {};
        final registerState = ref.read(registerProvider);
        _addressController.text = registerState.address ?? '';
        _detailAddressController.text =
            registerState.detailAddress ?? '';
      }
    });
  }

  @override
  void dispose() {
    if (widget.editConfig != null) {
      Future.microtask(() {
        ref.read(registerProvider.notifier).reset();
        ref.read(zoneProvider.notifier).reset();
        ref.read(drawProvider.notifier).reset();
        ref.read(lockedZonesProvider.notifier).state = {};
      });
    }
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
    final isEditMode = widget.editConfig != null;

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
                              pickedCount:
                                  ref
                                      .watch(registerProvider)
                                      .images
                                      .length +
                                  ref
                                      .watch(registerProvider)
                                      .existingImageUrls
                                      .length,
                            ),
                            const SizedBox(width: 30),
                            StoragePhotoList(
                              existingImages: ref
                                  .watch(registerProvider)
                                  .existingImageUrls,
                              newImages: ref
                                  .watch(registerProvider)
                                  .images,
                              onDeleteExisting: (index) {
                                ref
                                    .read(registerProvider.notifier)
                                    .removeExistingImage(index);
                              },
                              onDeleteNew: (index) {
                                ref
                                    .read(registerProvider.notifier)
                                    .deletePhoto(index);
                              },
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
                                  0xFF6B7AF5,
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
              _buildBottomRegisterButton(isEditMode: isEditMode),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _isLoadingEditData
          ? const LinearProgressIndicator(minHeight: 2)
          : null,
    );
  }

  // =========================
  // UI builders
  // =========================

  Widget _buildStructureEditorArea(DrawProviderData drawState) {
    final zones = ref.watch(zoneProvider);

    final double layoutW = drawState.width * _ppm;
    final double layoutH = drawState.height * _ppm;

    return Container(
      width: double.infinity,
      height: 300,
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
                    padding: const EdgeInsets.all(12),
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: SizedBox(
                        width: layoutW,
                        height: layoutH,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: CustomPaint(
                                painter: GridPainter(
                                  widthM: drawState.width,
                                  heightM: drawState.height,
                                  lines: drawState.lines,
                                  doors: drawState.doors,
                                  showLengths: true,
                                ),
                              ),
                            ),
                            ..._buildZoneOverlays(zones: zones),
                          ],
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
                label: const Text("건물 내부 구조 그리기"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6B7AF5),
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
    final lockedZones = ref.watch(lockedZonesProvider);
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
        final isLocked = lockedZones.containsKey(zone.index);
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
                    color: Color(0xFF6B7AF5),
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
                        '${formatZoneSize(zone.width, zone.height)} · '
                        '${formatArea(zone.width * zone.height)}',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '월 ${formatWon(zone.price)} · '
                        '${formatPricePerSqm(zone.price, zone.width * zone.height)}',
                        style: const TextStyle(
                          color: Color(0xFF6B7AF5),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isLocked)
                  Tooltip(
                    message: '예약·이용이 걸려 있어 삭제할 수 없어요',
                    triggerMode: TooltipTriggerMode.tap,
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(
                        Icons.lock_outline,
                        color: Color(0xFFFF9800),
                        size: 20,
                      ),
                    ),
                  )
                else
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

  List<Widget> _buildZoneOverlays({required List<Zone> zones}) {
    // 보기 전용 미리보기. 좌표는 에디터가 이미 건물 안으로 가둬서 저장하므로
    // 여기서 다시 보정하지 않는다.
    return zones.map((zone) {
      final zoneW = zone.width * _ppm;
      final zoneH = zone.height * _ppm;

      return Positioned(
        left: zone.x * _ppm,
        top: zone.y * _ppm,
        child: IgnorePointer(
          child: Container(
            width: zoneW,
            height: zoneH,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0x336B7AF5),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFF6B7AF5)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  zone.index,
                  style: const TextStyle(
                    color: Color(0xFF6B7AF5),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (zoneW >= 56 && zoneH >= 44)
                  Text(
                    formatZoneSize(zone.width, zone.height),
                    style: const TextStyle(
                      color: Color(0xFF6B7AF5),
                      fontSize: 10,
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }).toList();
  }

  // =========================
  // Actions
  // =========================

  void _hydrateEditData(StorageEditConfig editConfig) {
    final storage = editConfig.storage;
    ref
        .read(registerProvider.notifier)
        .setInitialData(
          address: storage.address,
          detailAddress: storage.detailAddress,
          latLng: LatLng(storage.lat, storage.lng),
          existingImageUrls: storage.images,
        );

    _addressController.text = storage.address;
    _detailAddressController.text = storage.detailAddress;

    final layoutLines = storage.layout['lines'];
    final layoutDoors = storage.layout['doors'];
    final lines = layoutLines is List<Line> ? layoutLines : <Line>[];
    final doors = layoutDoors is Set<Offset>
        ? layoutDoors
        : <Offset>{};

    ref
        .read(drawProvider.notifier)
        .setDrawing(
          lines: lines,
          doors: doors,
          width: storage.width,
          height: storage.height,
        );

    _loadEditZones(editConfig.storageId);
  }

  Future<void> _loadEditZones(String storageId) async {
    setState(() => _isLoadingEditData = true);

    try {
      final firestore = ref.read(firestoreProvider);
      final zonesSnapshot = await firestore
          .collection('storages')
          .doc(storageId)
          .collection('zones')
          .get();
      final zones = zonesSnapshot.docs.map(Zone.fromDoc).toList();
      ref.read(zoneProvider.notifier).setZones(zones);

      // 예약·이용이 걸린 구역은 잠근다. 상대의 계약이 참조하는 구역을
      // 주인이 지우거나 크기를 바꾸면 그 계약이 공중에 뜬다.
      final results = await Future.wait([
        firestore
            .collection('reservations')
            .where('storageId', isEqualTo: storageId)
            .get(),
        firestore
            .collection('usages')
            .where('storageId', isEqualTo: storageId)
            .get(),
      ]);

      final busyIndexes = <String>{
        // 거절된 예약은 이미 끝난 얘기라 잠그지 않는다.
        for (final doc in results[0].docs)
          if (doc.data()['status'] != 'rejected')
            doc.data()['containerIndex']?.toString() ?? '',
        for (final doc in results[1].docs)
          doc.data()['containerIndex']?.toString() ?? '',
      }..remove('');

      ref.read(lockedZonesProvider.notifier).state = {
        for (final zone in zones)
          if (busyIndexes.contains(zone.index)) zone.index: zone,
      };
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('구역 정보를 불러오지 못했어요: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoadingEditData = false);
      }
    }
  }

  Future<void> _submitRegister({
    required String detailAddress,
    required DrawProviderData drawState,
    required List<Zone> zones,
  }) async {
    try {
      await ref
          .read(registerProvider.notifier)
          .registerStorage(
            drawState: drawState,
            zones: zones,
            detailAddress: detailAddress,
          );

      if (!mounted) return;

      final user = ref.read(firebaseAuthProvider).currentUser;
      if (user != null) {
        final chatService = ChatService(ref.read(firestoreProvider));
        await chatService.sendSystemMessageToUser(
          user: user,
          message: '창고 등록 신청이 완료되었습니다.',
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("등록 요청이 완료되었습니다.")),
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
        SnackBar(content: Text("등록 중 오류가 발생했습니다: $error")),
      );
    }
  }

  Future<void> _submitEdit({
    required String detailAddress,
    required DrawProviderData drawState,
    required List<Zone> zones,
  }) async {
    final editConfig = widget.editConfig;
    if (editConfig == null) return;

    try {
      final registerState = ref.read(registerProvider);
      await ref
          .read(myStoragesProvider.notifier)
          .updateStorage(
            storageId: editConfig.storageId,
            currentStorage: editConfig.storage,
            address:
                registerState.address ?? editConfig.storage.address,
            detailAddress: detailAddress,
            latLng: registerState.latLng,
            drawState: drawState,
            zones: zones,
            existingImageUrls: registerState.existingImageUrls,
            newImages: registerState.images,
          );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('창고 정보가 수정되었습니다.')),
      );
      ref.read(registerProvider.notifier).reset();
      ref.read(zoneProvider.notifier).reset();
      ref.read(drawProvider.notifier).reset();
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('수정 중 오류가 발생했습니다: $error')),
      );
    }
  }

  /// 승인돼 있던 창고를 수정하면 재심사를 받는다는 사실을 알리고 동의받는다.
  ///
  /// 수정 즉시 지도에서 내려가기 때문에, 모르고 눌렀다가 매물이 사라졌다고
  /// 놀라지 않게 저장 전에 한 번 짚어준다.
  Future<bool> _confirmResubmitIfApproved() async {
    final status = widget.editConfig?.storage.reviewStatus;
    if (status != ReviewStatus.approved) return true;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('수정하면 재심사를 받아요'),
        content: const Text(
          '수정 내용은 관리자 심사를 다시 거칩니다.\n\n'
          '· 승인될 때까지 지도와 목록에서 내려갑니다\n'
          '· 그동안 새 예약을 받거나 대기 중 예약을 확정할 수 없어요\n'
          '· 이미 이용 중인 건과 확정된 예약은 그대로 유지됩니다',
          style: TextStyle(fontSize: 13.5, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              '취소',
              style: TextStyle(color: Colors.grey[700]),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6B7AF5),
              foregroundColor: Colors.white,
            ),
            child: const Text('수정하고 재심사 받기'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  void _navigateToEditor() async {
    _clearDetailAddressFocus();

    // 건물 실측 크기가 있어야 도면에 축척이 생긴다. 처음 한 번만 묻는다.
    if (!await _ensureBuildingSize()) return;
    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const DrawScreen()),
    );

    _clearDetailAddressFocus();
  }

  /// 건물 크기가 없으면 입력받는다. 입력하면 외곽 네 벽이 자동으로 생긴다.
  Future<bool> _ensureBuildingSize() async {
    final drawState = ref.read(drawProvider);
    if (drawState.width > 0 && drawState.height > 0) return true;

    final size = await showDialog<Size>(
      context: context,
      builder: (dialogContext) => const _BuildingSizeDialog(),
    );
    if (size == null) return false;

    ref
        .read(drawProvider.notifier)
        .setBuildingSize(size.width, size.height);
    return true;
  }

  Future<void> _showAddZoneDialog() async {
    final nextIndex = ref.read(zoneProvider.notifier).nextIndex();
    await _showZoneDialog(index: nextIndex);
  }

  Future<void> _showZoneDialog({Zone? zone, String? index}) async {
    final zoneIndex = index ?? zone?.index ?? '';

    final isLocked =
        zone != null &&
        ref.read(lockedZonesProvider).containsKey(zone.index);

    final result = await showDialog<ZoneFormData>(
      context: context,
      builder: (context) => ZoneFormDialog(
        index: zoneIndex,
        lockSize: isLocked,
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
      final position = _findAvailableZonePosition(
        zoneSizeM: Size(result.width, result.height),
        layoutSizeM: Size(drawState.width, drawState.height),
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
        prefixIcon: Icon(icon, color: const Color(0xFF6B7AF5)),
        filled: true,
        fillColor: Colors.white,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF6B7AF5)),
        ),
      ),
    );
  }

  Widget _buildBottomRegisterButton({required bool isEditMode}) {
    final registerRef = ref.watch(registerProvider);
    final drawState = ref.watch(drawProvider);
    final zones = ref.watch(zoneProvider);
    final isBusy = isEditMode
        ? ref.watch(myStoragesProvider).isUpdating
        : registerRef.isSubmitting;

    return Container(
      padding: const EdgeInsets.all(20),
      color: Colors.white,
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: isBusy
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
                        lockedZones: ref.read(lockedZonesProvider),
                      );

                  if (!validationResult.isValid) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(validationResult.message),
                      ),
                    );
                    return;
                  }

                  if (isEditMode) {
                    if (!await _confirmResubmitIfApproved()) return;
                    await _submitEdit(
                      detailAddress: detailAddress,
                      drawState: drawState,
                      zones: zones,
                    );
                  } else {
                    await _submitRegister(
                      detailAddress: detailAddress,
                      drawState: drawState,
                      zones: zones,
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
                colors: [Color(0xFF6B7AF5), Color(0xFF8FD3F4)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: isBusy
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
                  : Text(
                      isEditMode ? "수정하기" : "등록하기",
                      style: const TextStyle(
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
    required Size zoneSizeM,
    required Size layoutSizeM,
    required List<Zone> zones,
  }) {
    final maxX = (layoutSizeM.width - zoneSizeM.width).clamp(
      0.0,
      layoutSizeM.width,
    );
    final maxY = (layoutSizeM.height - zoneSizeM.height).clamp(
      0.0,
      layoutSizeM.height,
    );

    for (double y = 0; y <= maxY; y += _cellM) {
      for (double x = 0; x <= maxX; x += _cellM) {
        final rect = Rect.fromLTWH(
          x,
          y,
          zoneSizeM.width,
          zoneSizeM.height,
        );

        final overlaps = zones.any((zone) {
          final otherRect = Rect.fromLTWH(
            zone.x,
            zone.y,
            zone.width,
            zone.height,
          );
          return rect.overlaps(otherRect);
        });

        if (!overlaps) {
          return Offset(x, y);
        }
      }
    }

    return Offset.zero;
  }
}

/// 건물 실측 크기를 묻는 다이얼로그. 여기 넣은 값이 도면의 축척이 된다.
class _BuildingSizeDialog extends StatefulWidget {
  const _BuildingSizeDialog();

  @override
  State<_BuildingSizeDialog> createState() =>
      _BuildingSizeDialogState();
}

class _BuildingSizeDialogState extends State<_BuildingSizeDialog> {
  final _formKey = GlobalKey<FormState>();
  final _widthController = TextEditingController();
  final _heightController = TextEditingController();

  @override
  void dispose() {
    _widthController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  String? _validate(String? value) {
    final parsed = double.tryParse(value?.trim() ?? '');
    if (parsed == null) return '숫자를 입력해주세요.';
    if (parsed < 1 || parsed > 60) return '1~60m 사이로 입력해주세요.';
    return null;
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    Navigator.pop(
      context,
      Size(
        double.parse(_widthController.text.trim()),
        double.parse(_heightController.text.trim()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: const Text('창고 실제 크기'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '줄자로 잰 실제 크기를 넣어주세요.\n'
              '이 크기대로 도면 외곽이 그려지고, 안에서 칸막이와\n'
              '구역을 배치하게 됩니다.',
              style: TextStyle(fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _widthController,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: '가로 (m)',
              ),
              validator: _validate,
            ),
            TextFormField(
              controller: _heightController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: '세로 (m)',
              ),
              validator: _validate,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('취소', style: TextStyle(color: Colors.grey[700])),
        ),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6B7AF5),
            foregroundColor: Colors.white,
          ),
          child: const Text('도면 그리기'),
        ),
      ],
    );
  }
}
