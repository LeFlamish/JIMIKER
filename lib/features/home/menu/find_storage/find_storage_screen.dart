import 'package:flutter/material.dart';
import 'package:jimiker/features/home/menu/find_storage/widgets/current_location_map.dart';

class Research extends StatelessWidget {
  const Research({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: CurrentLocationMap(),
    );
  }
}