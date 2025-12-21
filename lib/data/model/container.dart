import 'package:cloud_firestore/cloud_firestore.dart';

class Container {
  final String index;
  final double x, y, angle, width, height;
  final int price;

  Container({
    required this.index,
    required this.x,
    required this.y,
    required this.angle,
    required this.width,
    required this.height,
    required this.price,
  });

  factory Container.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return Container(
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
