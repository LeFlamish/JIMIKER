import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:jimiker/core/widgets/cached_image.dart';

class PhotoButton extends StatelessWidget {
  final VoidCallback onTap;
  final int pickedCount;

  const PhotoButton({required this.onTap, required this.pickedCount});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.only(top: 5),
        height: 60,
        width: 60,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.camera_alt_outlined, size: 28),
            const SizedBox(height: 4),
            Text(
              '$pickedCount/10',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class PhotoList extends StatelessWidget {
  final List<XFile>? pickedImages;
  final void Function(int)? delete;

  const PhotoList({
    super.key,
    required this.pickedImages,
    required this.delete,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children:
            pickedImages?.asMap().entries.map((entry) {
              final index = entry.key;
              final image = entry.value;
              return Stack(
                children: [
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    height: 60,
                    width: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      image: DecorationImage(
                        image: FileImage(File(image.path)),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 2,
                    right: 2,
                    child: GestureDetector(
                      onTap: () => delete?.call(index),
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }).toList() ??
            [],
      ),
    );
  }
}

class StoragePhotoList extends StatelessWidget {
  final List<String> existingImages;
  final List<XFile> newImages;
  final void Function(int)? onDeleteExisting;
  final void Function(int)? onDeleteNew;

  const StoragePhotoList({
    super.key,
    required this.existingImages,
    required this.newImages,
    required this.onDeleteExisting,
    required this.onDeleteNew,
  });

  @override
  Widget build(BuildContext context) {
    final totalCount = existingImages.length + newImages.length;
    if (totalCount == 0) {
      return const SizedBox.shrink();
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ...existingImages.asMap().entries.map((entry) {
            final index = entry.key;
            final url = entry.value;
            return _PhotoThumbnail(
              // 이미 올라간 사진은 캐시에서 꺼내 쓴다.
              imageProvider: cachedImageProvider(url),
              onDelete: () => onDeleteExisting?.call(index),
            );
          }),
          ...newImages.asMap().entries.map((entry) {
            final index = entry.key;
            final image = entry.value;
            return _PhotoThumbnail(
              imageProvider: FileImage(File(image.path)),
              onDelete: () => onDeleteNew?.call(index),
            );
          }),
        ],
      ),
    );
  }
}

class _PhotoThumbnail extends StatelessWidget {
  final ImageProvider? imageProvider;
  final VoidCallback? onDelete;

  const _PhotoThumbnail({
    required this.imageProvider,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final provider = imageProvider;

    return Stack(
      children: [
        Container(
          margin: const EdgeInsets.only(left: 8),
          height: 60,
          width: 60,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: const Color(0xFFF0F0F0),
            image: provider == null
                ? null
                : DecorationImage(
                    image: provider,
                    fit: BoxFit.cover,
                  ),
          ),
        ),
        Positioned(
          top: 2,
          right: 2,
          child: GestureDetector(
            onTap: onDelete,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close,
                size: 14,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}