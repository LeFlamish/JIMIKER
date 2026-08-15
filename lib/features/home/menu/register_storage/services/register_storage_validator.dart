import 'package:jimiker/data/models/zone.dart';
import 'package:jimiker/features/draw/draw_provider.dart';
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

    final totalImages =
        registerData.images.length +
        registerData.existingImageUrls.length;
    if (totalImages == 0) {
      errors.add('사진을 최소 1장 등록해주세요.');
    }

    if ((registerData.address ?? '').isEmpty) {
      errors.add('주소를 입력해주세요.');
    }

    if (detailAddress.trim().isEmpty) {
      errors.add('상세 주소를 입력해주세요.');
    }

    if (drawState.lines.isEmpty ||
        drawState.width <= 0 ||
        drawState.height <= 0) {
      errors.add('창고 배치 구성을 완료해주세요.');
    }

    if (zones.isEmpty) {
      errors.add('구역을 최소 1개 등록해주세요.');
    }

    final hasInvalidZone = zones.any(
      (zone) =>
          zone.width <= 0 || zone.height <= 0 || zone.price <= 0,
    );
    if (hasInvalidZone) {
      errors.add('모든 구역의 크기와 임대료를 확인해주세요.');
    }

    // 구역 크기는 주인이 직접 잰 실측값이라, 도면(건물 크기)과 어긋나면
    // 둘 중 하나가 틀렸다는 신호다. 저장 전에 잡는다.
    if (drawState.width > 0 && drawState.height > 0) {
      final buildingArea = drawState.width * drawState.height;

      final tooBigZone = zones.any(
        (zone) =>
            zone.width > drawState.width ||
            zone.height > drawState.height,
      );
      if (tooBigZone) {
        errors.add('건물보다 큰 구역이 있어요. 건물 크기나 구역 크기를 확인해주세요.');
      }

      final zoneAreaSum = zones.fold<double>(
        0,
        (sum, zone) => sum + zone.width * zone.height,
      );
      if (zoneAreaSum > buildingArea) {
        errors.add(
          '구역 면적 합(${zoneAreaSum.toStringAsFixed(1)}㎡)이 '
          '건물 면적(${buildingArea.toStringAsFixed(1)}㎡)을 넘어요. '
          '크기를 다시 확인해주세요.',
        );
      }
    }

    return RegisterStorageValidationResult(errors);
  }
}
