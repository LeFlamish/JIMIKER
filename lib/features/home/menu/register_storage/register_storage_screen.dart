import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:jimiker/features/home/menu/register_storage/draw/draw_provider.dart';
import 'package:jimiker/features/home/menu/register_storage/draw/draw_screen.dart';
import 'package:jimiker/features/home/menu/register_storage/register_provider.dart';
import 'package:jimiker/features/home/menu/register_storage/widgets/photo.dart';

// 구역 데이터 모델
class ZoneData {
  final String name;
  final String width;
  final String height;
  final String price;

  ZoneData({
    required this.name,
    required this.width,
    required this.height,
    required this.price,
  });
}

class RegisterStorageScreen extends ConsumerStatefulWidget {
  const RegisterStorageScreen({super.key});

  @override
  ConsumerState<RegisterStorageScreen> createState() =>
      _RegisterStorageScreenState();
}

class _RegisterStorageScreenState
    extends ConsumerState<RegisterStorageScreen> {
  late TextEditingController _addressController;
  late TextEditingController _detailAddressController;
  // 상태 변수: 도면이 그려졌는지 여부
  bool _isStructureDrawn = false;
  // 상태 변수: 등록된 구역 리스트
  List<ZoneData> _zones = [];
  // 스크롤 여부
  bool scroll = true;
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _addressController = TextEditingController();
    _detailAddressController = TextEditingController();
    _addressController.text =
        ref.read(registerProvider).address ?? '';
    _detailAddressController.text =
        ref.read(registerProvider).detailAddress ?? '';
  }

  @override
  void dispose() {
    super.dispose();
    _addressController.dispose();
    _detailAddressController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final registerRef = ref.watch(registerProvider);
    final drawState = ref.watch(drawProvider);
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. 사진 등록 (기존 유지)
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
                                .read(registerProvider)
                                .images
                                .length,
                          ),
                          const SizedBox(height: 30),
                          PhotoList(
                            delete: (index) {
                              ref
                                  .read(registerProvider.notifier)
                                  .deletePhoto(index);
                            },
                            pickedImages: ref
                                .read(registerProvider)
                                .images,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                    // 2. 주소 입력 (기존 유지)
                    _buildSectionTitle("위치 정보"),
                    const SizedBox(height: 10),
                    _buildTextField(
                      onTap: () {
                        ref
                            .read(registerProvider.notifier)
                            .addressTap(context, _addressController);
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
                    ),
                    const SizedBox(height: 30),

                    // 3. 창고 배치 구성 (수정된 부분)
                    _buildSectionTitle("창고 배치 구성"),

                    const SizedBox(height: 10),

                    // 3-1. 구조 그리기 버튼 또는 결과 화면
                    _buildStructureEditorArea(),

                    const SizedBox(height: 20),

                    // 3-2. 구역 추가 및 리스트 (도면이 있을 때만 활성화)
                    if (_isStructureDrawn) ...[
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
                      _buildZoneList(),
                    ],
                  ],
                ),
              ),
            ),
            _buildBottomRegisterButton(),
          ],
        ),
      ),
    );
  }

  // --- 위젯 빌더 메서드 ---

  // 내부 구조 그리기 영역 (핵심 수정 부분)
  Widget _buildStructureEditorArea() {
    final drawState = ref.read(drawProvider);
    return Container(
      width: double.infinity,
      height: drawState.height + 100,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: _isStructureDrawn
          ? Stack(
              children: [
                // 도면 이미지 (예시)
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: double.infinity,
                    height: double.infinity,
                    color: Colors.blueGrey[50],
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Icon(
                          //   Icons.map_outlined,
                          //   size: 48,
                          //   color: Colors.blueGrey,
                          // ),
                          // SizedBox(height: 8),
                          SingleChildScrollView(
                            physics: scroll
                                ? null
                                : const NeverScrollableScrollPhysics(),
                            scrollDirection: Axis.horizontal,
                            child: Container(
                              width: drawState.width,
                              height: drawState.height,
                              child: Stack(
                                children: [
                                  CustomPaint(
                                    painter: GridPainter(
                                      gridSize: 30,
                                      width: drawState.width ?? 0.0,
                                      height: drawState.height ?? 0.0,
                                      lines: drawState.lines ?? [],
                                      doors: drawState.doors ?? {},
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // 수정 버튼
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

  // 구역 리스트 보여주기
  Widget _buildZoneList() {
    if (_zones.isEmpty) {
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
      itemCount: _zones.length,
      separatorBuilder: (context, index) =>
          const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final zone = _zones[index];
        return Container(
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
                      zone.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${zone.width}m x ${zone.height}m  |  ₩${zone.price}",
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
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
                  setState(() {
                    _zones.removeAt(index);
                  });
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // 화면 이동 시뮬레이션 (구조 그리기 화면)
  void _navigateToEditor() async {
    // 실제로는 Navigator.push를 통해 에디터 화면으로 이동
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const DrawScreen()),
    );

    if (ref.read(drawProvider).lines.isNotEmpty) {
      setState(() {
        _isStructureDrawn = true;
      });
    }
  }

  // 구역 추가 다이얼로그
  void _showAddZoneDialog() {
    String width = "";
    String height = "";
    String price = "";

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text("구역 설정"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(
                  labelText: "가로 길이 (m)",
                  suffixText: "m",
                ),
                keyboardType: TextInputType.number,
                onChanged: (val) => width = val,
              ),
              TextField(
                decoration: const InputDecoration(
                  labelText: "세로 길이 (m)",
                  suffixText: "m",
                ),
                keyboardType: TextInputType.number,
                onChanged: (val) => height = val,
              ),
              TextField(
                decoration: const InputDecoration(
                  labelText: "구역 임대료",
                  suffixText: "원",
                ),
                keyboardType: TextInputType.number,
                onChanged: (val) => price = val,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                "취소",
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                if (width.isNotEmpty &&
                    height.isNotEmpty &&
                    price.isNotEmpty) {
                  setState(() {
                    _zones.add(
                      ZoneData(
                        name:
                            "구역 ${String.fromCharCode(65 + _zones.length)}", // A, B, C...
                        width: width,
                        height: height,
                        price: price,
                      ),
                    );
                  });
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6B66FF),
              ),
              child: const Text("추가"),
            ),
          ],
        );
      },
    );
  }

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
  }) {
    return TextField(
      onTap: onTap,
      controller: controller,
      readOnly: isReadOnly,
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
    return Container(
      padding: const EdgeInsets.all(20),
      color: Colors.white,
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: () {},
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
            child: const Center(
              child: Text(
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
}

// --- 임시: 구조 그리기 화면 (별도 파일로 분리될 내용) ---
class StructureEditorScreen extends StatelessWidget {
  const StructureEditorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("내부 구조 그리기")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("여기서 캔버스에 그림을 그립니다."),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // 저장하고 돌아가는 동작 시뮬레이션
                Navigator.pop(
                  context,
                  true,
                ); // true를 반환하여 그림이 그려졌음을 알림
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6B66FF),
              ),
              child: const Text("저장 후 복귀"),
            ),
          ],
        ),
      ),
    );
  }
}
