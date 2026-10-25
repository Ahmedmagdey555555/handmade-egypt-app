#!/bin/bash
set -e

mkdir -p apps/merchant/lib/screens

# ============ screens/terms_screen.dart ============
cat > apps/merchant/lib/screens/terms_screen.dart << 'FILE_END'
import 'package:flutter/material.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  // النص المبدئي - سيتم تغييره من لوحة التحكم لاحقاً
  static const String _termsText = '''
شروط وأحكام استخدام منصة Handmade للتجار

مرحباً بك في منصة Handmade. باستخدامك لهذا التطبيق، فإنك توافق على الشروط والأحكام التالية:

1. التسجيل:
- يجب تقديم بيانات صحيحة ومحدثة.
- التاجر مسؤول عن سرية حسابه.

2. المنتجات:
- يجب أن تكون المنتجات مطابقة للوصف والصور.
- يُمنع بيع منتجات مقلدة أو مخالفة للقوانين.

3. العمولات والمدفوعات:
- يتم خصم عمولة المنصة من كل طلب حسب الباقة المتفق عليها.
- يتم تحويل الأرباح للمحفظة بعد تأكيد العميل للاستلام.

4. جودة الخدمة:
- الالتزام بمواعيد الشحن.
- التعامل باحترام مع خدمة العملاء.

5. إلغاء الحساب:
- يحق للمنصة إيقاف أو إلغاء الحساب في حال مخالفة الشروط.

شكراً لتعاونك معنا.
''';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F2),
      appBar: AppBar(
        title: const Text('الشروط والأحكام'),
        backgroundColor: const Color(0xFFB07D62),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Text(
                _termsText,
                style: const TextStyle(fontSize: 15, height: 1.8),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(color: Colors.white),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFB07D62),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('أوافق على الشروط', style: TextStyle(fontSize: 16)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
FILE_END

# ============ تحديث screens/store_setup_screen.dart ============
cat > apps/merchant/lib/screens/store_setup_screen.dart << 'FILE_END'
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dashboard_screen.dart';
import 'terms_screen.dart';

class StoreSetupScreen extends StatefulWidget {
  const StoreSetupScreen({super.key});

  @override
  State<StoreSetupScreen> createState() => _StoreSetupScreenState();
}

class _StoreSetupScreenState extends State<StoreSetupScreen> {
  final _name = TextEditingController();
  final _desc = TextEditingController();
  final _phone = TextEditingController();
  bool _loading = false;
  bool _termsAccepted = false;

  Future<void> _createStore() async {
    if (_name.text.isEmpty || _phone.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('من فضلك أكمل البيانات الأساسية')));
      return;
    }
    if (!_termsAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يجب الموافقة على الشروط والأحكام أولاً')));
      return;
    }

    setState(() => _loading = true);
    try {
      final uid = Supabase.instance.client.auth.currentUser!.id;
      
      await Supabase.instance.client.from('stores').insert({
        'owner_id': uid,
        'name': _name.text.trim(),
        'description': _desc.text.trim(),
        'phone': _phone.text.trim(),
        'status': 'active',
        'terms_accepted': true,
      });

      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const DashboardScreen()));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openTerms() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const TermsScreen()),
    );
    if (result == true) {
      setState(() => _termsAccepted = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F2),
      appBar: AppBar(title: const Text('إنشاء متجر')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('أهلاً بيك في Handmade!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('عشان تبدأ تبيع، محتاجين نعرف بيانات متجرك الأول.', style: TextStyle(fontSize: 15, color: Colors.grey)),
          const SizedBox(height: 30),
          TextField(
            controller: _name,
            decoration: InputDecoration(labelText: 'اسم المتجر', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), prefixIcon: const Icon(Icons.store)),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(labelText: 'رقم الهاتف', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), prefixIcon: const Icon(Icons.phone)),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _desc,
            maxLines: 4,
            decoration: InputDecoration(labelText: 'نبذة عن المتجر (اختياري)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), prefixIcon: const Icon(Icons.description)),
          ),
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
            child: CheckboxListTile(
              title: const Text('أوافق على الشروط والأحكام', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              value: _termsAccepted,
              activeColor: const Color(0xFFB07D62),
              onChanged: (v) {
                if (v == true && !_termsAccepted) {
                  _openTerms();
                } else {
                  setState(() => _termsAccepted = v ?? false);
                }
              },
            ),
          ),
          const SizedBox(height: 30),
          FilledButton(
            onPressed: _loading ? null : _createStore,
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFB07D62), padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            child: _loading ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('بدء البيع الآن', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }
}
FILE_END

# ============ screens/wallet_screen.dart ============
cat > apps/merchant/lib/screens/wallet_screen.dart << 'FILE_END'
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  double _balance = 0;
  List<Map<String, dynamic>> _transactions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final uid = Supabase.instance.client.auth.currentUser!.id;
      final store = await Supabase.instance.client.from('stores').select('id, wallet_balance').eq('owner_id', uid).single();
      
      if (!mounted) return;
      setState(() => _balance = (store['wallet_balance'] as num?)?.toDouble() ?? 0);

      final txns = await Supabase.instance.client
          .from('wallet_transactions')
          .select()
          .eq('store_id', store['id'])
          .order('created_at', ascending: false);

      if (!mounted) return;
      setState(() {
        _transactions = txns.cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F2),
      appBar: AppBar(title: const Text('المحفظة'), backgroundColor: const Color(0xFFB07D62), foregroundColor: Colors.white),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFB07D62), Color(0xFF8B5A3C)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  const Text('الرصيد المتاح', style: TextStyle(color: Colors.white70, fontSize: 16)),
                  const SizedBox(height: 10),
                  Text('${_balance.toStringAsFixed(0)} ج.م', style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('سيتم إضافة طلبات السحب قريباً')));
                      },
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
                      child: const Text('طلب سحب'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text('سجل الحركات', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (_transactions.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                child: const Center(child: Text('مفيش حركات لسه', style: TextStyle(color: Colors.grey))),
              )
            else
              ..._transactions.map((t) {
                final isCredit = t['type'] == 'credit';
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                  child: Row(
                    children: [
                      Icon(isCredit ? Icons.arrow_downward : Icons.arrow_upward, color: isCredit ? Colors.green : Colors.red),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t['description'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                            Text(t['created_at'].toString().split('T').first, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                          ],
                        ),
                      ),
                      Text('${isCredit ? '+' : '-'} ${t['amount']} ج.م', style: TextStyle(fontWeight: FontWeight.bold, color: isCredit ? Colors.green : Colors.red)),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
FILE_END

# ============ screens/store_settings_screen.dart ============
cat > apps/merchant/lib/screens/store_settings_screen.dart << 'FILE_END'
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StoreSettingsScreen extends StatefulWidget {
  const StoreSettingsScreen({super.key});

  @override
  State<StoreSettingsScreen> createState() => _StoreSettingsScreenState();
}

class _StoreSettingsScreenState extends State<StoreSettingsScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _desc = TextEditingController();
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final uid = Supabase.instance.client.auth.currentUser!.id;
      final data = await Supabase.instance.client.from('stores').select().eq('owner_id', uid).single();
      if (!mounted) return;
      _name.text = data['name'] ?? '';
      _phone.text = data['phone'] ?? '';
      _desc.text = data['description'] ?? '';
      setState(() => _loading = false);
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final uid = Supabase.instance.client.auth.currentUser!.id;
      await Supabase.instance.client.from('stores').update({
        'name': _name.text.trim(),
        'phone': _phone.text.trim(),
        'description': _desc.text.trim(),
      }).eq('owner_id', uid);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم الحفظ')));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F2),
      appBar: AppBar(title: const Text('إعدادات المتجر'), backgroundColor: const Color(0xFFB07D62), foregroundColor: Colors.white),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                TextField(controller: _name, decoration: const InputDecoration(labelText: 'اسم المتجر', border: OutlineInputBorder())),
                const SizedBox(height: 16),
                TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'رقم الهاتف', border: OutlineInputBorder())),
                const SizedBox(height: 16),
                TextField(controller: _desc, maxLines: 4, decoration: const InputDecoration(labelText: 'نبذة عن المتجر', border: OutlineInputBorder())),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFFB07D62), padding: const EdgeInsets.symmetric(vertical: 16)),
                  child: _saving ? const CircularProgressIndicator(color: Colors.white) : const Text('حفظ التعديلات'),
                ),
              ],
            ),
    );
  }
}
FILE_END

echo "setup-merchant-2a done"
