import 'package:jimiker/data/model/zone.dart';
import 'package:jimiker/features/home/menu/register_storage/services/draw/draw_provider.dart';
import 'package:jimiker/features/home/menu/register_storage/services/register_provider.dart';

class RegisterStorageValidationResult {
  final List<String> errors;

  const RegisterStorageValidationResult(this.errors);

  bool get isValid => errors.isEmpty;

  String get message => errors.join('\n');
}

class RegisterStorageValidator {
  static RegisterStorageValidationResult validate({
    required RegisterData registerData,
    required DrawProviderData drawState,
    required List<Zone> zones,
    required String detailAddress,
  }) {
    final errors = <String>[];

    if (registerData.images.isEmpty) {
      errors.add('사진을 최소 1장 등록해주세요.');
    }

    if ((registerData.address ?? '').isEmpty) {
      errors.add('주소를 입력해주세요.');
    }

    if (detailAddress.trim().isEmpty) {
      errors.add('상세 주소를 입력해주세요.');
    }

    if (drawState.lines.isEmpty) {
      errors.add('창고 배치 구성을 완료해주세요.');
    }

    if (zones.isEmpty) {
      errors.add('구역을 최소 1개 등록해주세요.');
    }

    final invalidZone = zones.firstWhere(
          (zone) =>
      zone.width <= 0 ||
          zone.height <= 0 ||
          zone.price <= 0,
      orElse: () => Zone(
        index: '',
        x: 0,
        y: 0,
        angle: 0,
        width: 0,
        height: 0,
        price: 0,
      ),
    );

    if (invalidZone.index.isNotEmpty) {
      errors.add('모든 구역의 크기와 임대료를 확인해주세요.');
    }

    return RegisterStorageValidationResult(errors);
  }
}