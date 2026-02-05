import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:jimiker/services/auth_providers.dart';

class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  ConsumerState<ProfileEditScreen> createState() =>
      _ProfileEditScreenState();
}

class _ProfileEditScreenState
    extends ConsumerState<ProfileEditScreen> {
  final TextEditingController _nicknameController =
      TextEditingController();

  XFile? _selectedImage;
  String _photoUrl = '';
  String _initialNickname = ''; // 변경 여부 확인을 위한 초기 닉네임 저장 변수
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final me = ref.read(authControllerProvider);

    // 초기값 저장
    _initialNickname = me?.nickName ?? '';
    _nicknameController.text = _initialNickname;
    _photoUrl = me?.photoURL ?? '';

    // 텍스트가 변경될 때마다 화면을 갱신하여 버튼 상태 업데이트
    _nicknameController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  // 변경 사항이 있는지 확인하는 Getter
  bool get _hasChanges {
    final currentNickname = _nicknameController.text.trim();
    // 이미지를 새로 선택했거나 OR 닉네임이 초기값과 다를 경우 true
    return (_selectedImage != null) ||
        (currentNickname != _initialNickname);
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    setState(() {
      _selectedImage = image;
    });
  }

  Future<String?> _uploadProfileImage(String uid) async {
    if (_selectedImage == null) return null;

    final file = File(_selectedImage!.path);
    if (!file.existsSync()) {
      throw Exception('이미지 파일을 찾을 수 없습니다.');
    }

    final storage = ref.read(firebaseStorageProvider);

    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final path =
        'users/$uid/profile_${timestamp}_${_selectedImage!.name}';

    final reference = storage.ref(path);
    final metadata = SettableMetadata(customMetadata: {'uid': uid});

    await reference.putFile(file, metadata);
    return reference.getDownloadURL();
  }

  Future<void> _saveProfile() async {
    if (_isSaving) return;

    final auth = ref.read(firebaseAuthProvider);
    final user = auth.currentUser;

    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('로그인이 필요합니다.')));
      return;
    }

    final nickname = _nicknameController.text.trim();
    if (nickname.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('닉네임을 입력해주세요.')));
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final uploadedUrl = await _uploadProfileImage(user.uid);

      await ref
          .read(authControllerProvider.notifier)
          .updateProfile(
            nickName: nickname,
            photoURL: uploadedUrl ?? _photoUrl,
          );

      // 저장 성공 시 초기값 업데이트 (버튼 다시 비활성화되도록)
      _initialNickname = nickname;
      if (uploadedUrl != null) {
        _photoUrl = uploadedUrl;
        _selectedImage = null; // 선택된 이미지 초기화
      }

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('프로필이 저장되었습니다.')));

      // Navigator.of(context).pop(); // 필요시 주석 해제
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('저장에 실패했습니다: $error')));
    } finally {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
      });
    }
  }

  ImageProvider? _resolveProfileImage() {
    if (_selectedImage != null) {
      return FileImage(File(_selectedImage!.path));
    }
    if (_photoUrl.isNotEmpty) {
      return NetworkImage(_photoUrl);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final profileImage = _resolveProfileImage();

    // 저장 가능 상태: 변경사항이 있고 && 저장 중이 아님
    final bool canSave = _hasChanges && !_isSaving;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      appBar: AppBar(
        title: const Text('프로필 수정'),
        centerTitle: true,
        backgroundColor: const Color(0xFFF5F6F8),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            size: 20,
            color: Colors.black,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        titleTextStyle: const TextStyle(
          color: Colors.black,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 20,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 섹션 1: 프로필 사진
                    const Text(
                      "프로필 사진",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF6A85FF),
                                  Color(0xFF8F94FB),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              border: Border.all(
                                color: Colors.white,
                                width: 2,
                              ),
                            ),
                            child: ClipOval(
                              child: profileImage == null
                                  ? const Icon(
                                      Icons.person,
                                      color: Colors.white,
                                      size: 35,
                                    )
                                  : Image(
                                      image: profileImage,
                                      fit: BoxFit.cover,
                                      width: 60,
                                      height: 60,
                                    ),
                            ),
                          ),
                          const Spacer(),
                          OutlinedButton(
                            onPressed: _pickImage,
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                color: Color(0xFF7C8DFF),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  8,
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                            ),
                            child: const Text(
                              "사진 변경",
                              style: TextStyle(
                                color: Color(0xFF5D6DBE),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // 섹션 2: 닉네임
                    const Text(
                      "닉네임",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _nicknameController,
                      decoration: InputDecoration(
                        hintText: "닉네임을 입력해주세요",
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        suffixIcon: const Icon(
                          Icons.edit,
                          color: Color(0xFF7C8DFF),
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 하단 저장 버튼
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  // 변경사항이 있을 때만 _saveProfile 연결, 아니면 null (비활성화)
                  onPressed: canSave ? _saveProfile : null,
                  style: ElevatedButton.styleFrom(
                    // 활성화(파란색)
                    backgroundColor: const Color(0xFF6A85FF),
                    // 비활성화(회색) - 변경사항 없을 때
                    disabledBackgroundColor: Colors.grey[400],
                    // 비활성화 상태의 글자/아이콘 색상
                    disabledForegroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text(
                          "저장",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
