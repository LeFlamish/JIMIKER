import 'package:image_picker/image_picker.dart';

/// 사진을 고를 때 쓰는 공통 설정.
///
/// 요즘 휴대폰 사진은 한 장에 4~12MB다. 원본 그대로 올리면
///  - storage.rules가 10MB에서 막아 아예 업로드가 실패하는 사진이 생기고
///  - 성공해도 모바일 데이터를 많이 쓰고, 나중에 볼 때도 느리다
/// 창고 목록·채팅에 띄우는 크기에는 긴 변 1600px이면 충분하다.
const int _photoMaxSide = 1600;
const int _photoQuality = 85;

/// 프로필 사진은 작은 원으로만 보여서 더 줄여도 된다.
const int _avatarMaxSide = 512;
const int _avatarQuality = 85;

/// 사진 한 장을 고른다. (창고 사진, 채팅 사진)
Future<XFile?> pickPhoto({
  ImageSource source = ImageSource.gallery,
  ImagePicker? picker,
}) {
  return (picker ?? ImagePicker()).pickImage(
    source: source,
    maxWidth: _photoMaxSide.toDouble(),
    maxHeight: _photoMaxSide.toDouble(),
    imageQuality: _photoQuality,
  );
}

/// 사진 여러 장을 고른다. (창고 등록)
Future<List<XFile>> pickPhotos({ImagePicker? picker}) {
  return (picker ?? ImagePicker()).pickMultiImage(
    maxWidth: _photoMaxSide.toDouble(),
    maxHeight: _photoMaxSide.toDouble(),
    imageQuality: _photoQuality,
  );
}

/// 프로필 사진을 고른다.
Future<XFile?> pickAvatar({ImagePicker? picker}) {
  return (picker ?? ImagePicker()).pickImage(
    source: ImageSource.gallery,
    maxWidth: _avatarMaxSide.toDouble(),
    maxHeight: _avatarMaxSide.toDouble(),
    imageQuality: _avatarQuality,
  );
}
