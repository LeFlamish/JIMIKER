import 'package:flutter/material.dart';
import 'package:jimiker/core/utils/space_units.dart';
import 'package:jimiker/data/models/zone_form_data.dart';

class ZoneFormDialog extends StatefulWidget {
  final ZoneFormData? zone;
  final String index;

  const ZoneFormDialog({super.key, required this.index, this.zone});

  @override
  State<ZoneFormDialog> createState() => _ZoneFormDialogState();
}

class _ZoneFormDialogState extends State<ZoneFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _widthController;
  late final TextEditingController _heightController;
  late final TextEditingController _priceController;

  @override
  void initState() {
    super.initState();
    final zone = widget.zone;
    _widthController = TextEditingController(
      text: zone?.width.toString() ?? '',
    );
    _heightController = TextEditingController(
      text: zone?.height.toString() ?? '',
    );
    _priceController = TextEditingController(
      text: zone?.price.toString() ?? '',
    );

    // 입력하는 동안 아래 면적·평·비유가 실시간으로 바뀐다.
    _widthController.addListener(_refresh);
    _heightController.addListener(_refresh);
    _priceController.addListener(_refresh);
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    _widthController.dispose();
    _heightController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  double? get _width => double.tryParse(_widthController.text.trim());
  double? get _height =>
      double.tryParse(_heightController.text.trim());
  int? get _price => int.tryParse(_priceController.text.trim());

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: Text('구역 ${widget.index} 설정'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildNumberField(
                controller: _widthController,
                label: '가로 길이 (m)',
              ),
              _buildNumberField(
                controller: _heightController,
                label: '세로 길이 (m)',
              ),
              _buildNumberField(
                controller: _priceController,
                label: '월 임대료 (원)',
                isInteger: true,
              ),
              const SizedBox(height: 14),
              _buildAreaPreview(),
              const SizedBox(height: 6),
              Text(
                '크기는 도면에서 구역 모서리를 끌어서도 바꿀 수 있어요.',
                style: TextStyle(
                  fontSize: 11.5,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            '취소',
            style: TextStyle(color: Colors.grey),
          ),
        ),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6B66FF),
          ),
          child: Text(widget.zone == null ? '추가' : '수정'),
        ),
      ],
    );
  }

  /// "6.0㎡ (약 1.8평)" + 뭐가 들어가는 크기인지 + ㎡당 가격.
  ///
  /// m 숫자만으로는 감이 안 오는 사람이 대부분이라, 입력과 동시에
  /// 소비자가 보게 될 것과 같은 정보를 주인에게도 보여준다.
  Widget _buildAreaPreview() {
    final width = _width;
    final height = _height;
    if (width == null || height == null || width <= 0 || height <= 0) {
      return Text(
        '크기를 입력하면 면적과 평수를 계산해드려요.',
        style: TextStyle(fontSize: 12.5, color: Colors.grey[500]),
      );
    }

    final area = width * height;
    final price = _price;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F1FF),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            formatArea(area),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF6B66FF),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            areaHint(area),
            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
          ),
          if (price != null && price > 0) ...[
            const SizedBox(height: 3),
            Text(
              formatPricePerSqm(price, area),
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNumberField({
    required TextEditingController controller,
    required String label,
    bool isInteger = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(
        decimal: !isInteger,
      ),
      decoration: InputDecoration(labelText: label),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return '필수 입력 항목입니다.';
        }
        final parsed = isInteger
            ? int.tryParse(value)
            : double.tryParse(value);
        if (parsed == null) {
          return '숫자를 입력해주세요.';
        }
        if (parsed <= 0) {
          return '0보다 커야 합니다.';
        }
        if (!isInteger && parsed.toDouble() > 60) {
          return '60m 이하로 입력해주세요.';
        }
        return null;
      },
    );
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    Navigator.pop(
      context,
      ZoneFormData(
        width: double.parse(_widthController.text),
        height: double.parse(_heightController.text),
        price: int.parse(_priceController.text),
      ),
    );
  }
}
