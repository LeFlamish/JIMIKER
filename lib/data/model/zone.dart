import 'package:cloud_firestore/cloud_firestore.dart';

class Zone {
  final String index;
  final double x, y, angle, width, height;
  final int price;

  Zone({
    required this.index,
    required this.x,
    required this.y,
    required this.angle,
    required this.width,
    required this.height,
    required this.price,
  });

  Zone copyWith({
    String? index,
    double? x,
    double? y,
    double? angle,
    double? width,
    double? height,
    int? price,
  }) {
    return Zone(
      index: index ?? this.index,
      x: x ?? this.x,
      y: y ?? this.y,
      angle: angle ?? this.angle,
      width: width ?? this.width,
      height: height ?? this.height,
      price: price ?? this.price,
    );
  }

  factory Zone.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return Zone(
      index: doc.id,
      x: data['x'],
      y: data['y'],
      angle: data['angle'],
      width: data['width'],
      height: data['height'],
      price: data['price'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'x': x,
      'y': y,
      'angle': angle,
      'width': width,
      'height': height,
      'price': price,
    };
  }
}
