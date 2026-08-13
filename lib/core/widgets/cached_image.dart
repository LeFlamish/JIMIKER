import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// 앱 전역이 공유하는 네트워크 이미지 디스크 캐시.
///
/// 한 번 내려받은 이미지는 [_stalePeriod] 동안 파일로 남아 있어서
/// 앱을 껐다 켜도 다시 받지 않는다. (데이터/로딩시간 절약)
class AppImageCache {
  const AppImageCache._();

  static const String _cacheKey = 'jimikerImageCache';
  static const Duration _stalePeriod = Duration(days: 30);
  static const int _maxObjects = 500;

  static final CacheManager instance = CacheManager(
    Config(
      _cacheKey,
      stalePeriod: _stalePeriod,
      maxNrOfCacheObjects: _maxObjects,
    ),
  );

  /// 같은 URL인데 내용이 바뀐 경우(프로필 사진 교체 등) 캐시를 지운다.
  static Future<void> evict(String url) async {
    if (url.isEmpty) return;
    await instance.removeFile(url);
    await CachedNetworkImageProvider(
      url,
      cacheManager: instance,
    ).evict();
  }
}

/// 캐시를 사용하는 [ImageProvider]. `NetworkImage(url)` 자리에 넣으면 된다.
///
/// url이 비어 있으면 null을 돌려주므로 `backgroundImage` 같은 곳에 바로 쓸 수 있다.
ImageProvider? cachedImageProvider(String? url) {
  final trimmed = url?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return CachedNetworkImageProvider(
    trimmed,
    cacheManager: AppImageCache.instance,
  );
}

/// 캐시를 사용하는 [Image.network] 대체 위젯.
///
/// url이 비었거나 로딩에 실패하면 [errorWidget](기본: 회색 아이콘)을 보여준다.
class CachedImage extends StatelessWidget {
  const CachedImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
  });

  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim();
    final Widget child;

    if (url == null || url.isEmpty) {
      child = _fallback(isError: true);
    } else {
      child = CachedNetworkImage(
        imageUrl: url,
        cacheManager: AppImageCache.instance,
        width: width,
        height: height,
        fit: fit,
        fadeInDuration: const Duration(milliseconds: 150),
        // 표시 크기에 맞춰 디코딩해 메모리도 같이 아낀다.
        memCacheWidth: _decodeWidth(context),
        placeholder: (_, __) => _fallback(isError: false),
        errorWidget: (_, __, ___) => _fallback(isError: true),
      );
    }

    if (borderRadius == null) return child;
    return ClipRRect(borderRadius: borderRadius!, child: child);
  }

  Widget _fallback({required bool isError}) {
    final provided = isError ? errorWidget : placeholder;
    if (provided != null) return provided;

    return Container(
      width: width,
      height: height,
      color: const Color(0xFFF0F0F0),
      alignment: Alignment.center,
      child: isError
          ? const Icon(
              Icons.image_not_supported_outlined,
              color: Colors.grey,
            )
          : const SizedBox.shrink(),
    );
  }

  /// 위젯 크기가 정해져 있을 때만 디코딩 해상도를 제한한다.
  /// 가로/세로 중 큰 쪽을 기준으로 잡아 [BoxFit.cover]에서도 흐려지지 않게 한다.
  int? _decodeWidth(BuildContext context) {
    final candidates = [
      width,
      height,
    ].whereType<double>().where((v) => v.isFinite && v > 0);
    if (candidates.isEmpty) return null;

    final longestSide = candidates.reduce((a, b) => a > b ? a : b);
    final pixelRatio =
        MediaQuery.maybeDevicePixelRatioOf(context) ?? 1.0;
    return (longestSide * pixelRatio).round();
  }
}

/// 프로필 사진용 원형 아바타. 사진이 없으면 기본 아이콘을 보여준다.
class CachedAvatar extends StatelessWidget {
  const CachedAvatar({
    super.key,
    required this.photoUrl,
    this.radius = 20,
    this.icon = Icons.person,
  });

  final String? photoUrl;
  final double radius;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = cachedImageProvider(photoUrl);

    if (provider == null) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        child: Icon(icon, color: theme.colorScheme.onSurfaceVariant),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: theme.colorScheme.surfaceContainerHighest,
      backgroundImage: provider,
    );
  }
}
