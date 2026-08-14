import 'package:flutter/material.dart';
import 'package:jimiker/features/auth/terms/terms_document_screen.dart';
import 'package:jimiker/features/auth/terms/terms_documents.dart';

/// 동의 결과. 선택 항목(마케팅)까지 같이 돌려준다.
class TermsAgreement {
  const TermsAgreement({required this.marketing});

  /// 마케팅 정보 수신 동의 여부. users 문서의 advertisement로 저장된다.
  final bool marketing;
}

/// 처음 로그인한 사람에게 동의를 받는 화면.
///
/// 필수 항목을 모두 체크해야 가입이 진행된다. 뒤로 나가면 계정을 만들지
/// 않고 로그아웃되므로, 다음에 다시 로그인하면 이 화면이 또 나온다.
class TermsAgreementScreen extends StatefulWidget {
  const TermsAgreementScreen({super.key});

  @override
  State<TermsAgreementScreen> createState() =>
      _TermsAgreementScreenState();
}

class _TermsAgreementScreenState extends State<TermsAgreementScreen> {
  static const Color _primary = Color(0xFF6B7AF5);

  final Map<String, bool> _checked = {
    for (final document in legalDocuments) document.id: false,
  };

  bool get _allChecked => _checked.values.every((value) => value);

  bool get _requiredChecked =>
      requiredDocuments.every((doc) => _checked[doc.id] == true);

  void _toggleAll(bool value) {
    setState(() {
      for (final key in _checked.keys) {
        _checked[key] = value;
      }
    });
  }

  void _submit() {
    if (!_requiredChecked) return;

    Navigator.of(context).pop(
      TermsAgreement(marketing: _checked['marketing'] == true),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            size: 20,
            color: Colors.black,
          ),
          // 그냥 pop하면 null이 돌아가고, 부르는 쪽이 "동의 안 함"으로 본다.
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                children: [
                  const Text(
                    '지미커 이용을 위해\n약관에 동의해주세요',
                    style: TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.bold,
                      height: 1.4,
                      color: Color(0xFF222222),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '동의하셔야 회원가입이 완료됩니다.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 28),
                  _buildAllTile(),
                  const SizedBox(height: 6),
                  const Divider(height: 24),
                  for (final document in legalDocuments)
                    _buildDocumentTile(document),
                ],
              ),
            ),
            _buildSubmitBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildAllTile() {
    return InkWell(
      onTap: () => _toggleAll(!_allChecked),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            _CheckMark(checked: _allChecked, big: true),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                '전체 동의',
                style: TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF222222),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentTile(LegalDocument document) {
    final checked = _checked[document.id] == true;

    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: () => setState(
              () => _checked[document.id] = !checked,
            ),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 11),
              child: Row(
                children: [
                  _CheckMark(checked: checked),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      '${document.required ? '[필수] ' : '[선택] '}'
                      '${document.title}',
                      style: TextStyle(
                        fontSize: 14.5,
                        color: checked
                            ? const Color(0xFF222222)
                            : Colors.grey[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  TermsDocumentScreen(document: document),
            ),
          ),
          style: TextButton.styleFrom(
            minimumSize: const Size(48, 40),
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
          child: Text(
            '보기',
            style: TextStyle(
              fontSize: 13,
              decoration: TextDecoration.underline,
              color: Colors.grey[600],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton(
          onPressed: _requiredChecked ? _submit : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: _primary,
            disabledBackgroundColor: const Color(0xFFD6DAF6),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: const Text(
            '동의하고 시작하기',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _CheckMark extends StatelessWidget {
  const _CheckMark({required this.checked, this.big = false});

  final bool checked;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final size = big ? 26.0 : 23.0;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: checked
            ? _TermsAgreementScreenState._primary
            : const Color(0xFFE4E5EC),
      ),
      child: Icon(
        Icons.check,
        size: big ? 17 : 15,
        color: Colors.white,
      ),
    );
  }
}
