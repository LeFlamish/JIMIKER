import 'package:flutter/material.dart';
import 'package:jimiker/data/models/zone_form_data.dart';


class ZoneFormDialog extends StatefulWidget {
  final ZoneFormData? zone;
  final String index;

  const ZoneFormDialog({
    super.key,
    required this.index,
    this.zone,
  });

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
  }

  @override
  void dispose() {
    _widthController.dispose();
    _heightController.dispose();
    _priceController.dispose();
    super.dispose();
  }

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
                label: '구역 임대료 (원)',
                isInteger: true,
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
        final parsed = isInteger ? int.tryParse(value) : double.tryParse(value);
        if (parsed == null) {
          return '숫자를 입력해주세요.';
        }
        return null;
      },
    );
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final width = double.parse(_widthController.text);
    final height = double.parse(_heightController.text);
    final price = int.parse(_priceController.text);

    Navigator.pop(
      context,
      ZoneFormData(width: width, height: height, price: price),
    );
  }
}
