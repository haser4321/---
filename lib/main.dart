import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProDaftarApp());
}

const sections = <Section>[
  Section('clients', 'العملاء', Icons.people_alt,
      'اسم العميل', 'الهاتف والعنوان'),
  Section('appointments', 'المواعيد', Icons.calendar_month,
      'اسم الموعد أو العميل', 'التاريخ والوقت والتفاصيل'),
  Section('debts', 'الديون', Icons.account_balance_wallet,
      'اسم العميل', 'تفاصيل الدين', amount: true),
  Section('transactions', 'الحسابات المالية', Icons.payments,
      'وصف العملية', 'تفاصيل العملية', amount: true),
  Section('services', 'الخدمات والأسعار', Icons.home_repair_service,
      'اسم الخدمة', 'وصف الخدمة', amount: true),
  Section('inventory', 'المخزون', Icons.inventory_2,
      'اسم المنتج', 'الكمية وتفاصيل المنتج', amount: true),
  Section('suppliers', 'الموردون', Icons.local_shipping,
      'اسم المورد', 'رقم الهاتف والعنوان'),
  Section('tasks', 'المهام والتذكيرات', Icons.task_alt,
      'اسم المهمة', 'موعد التنفيذ والتفاصيل'),
  Section('notes', 'الملاحظات', Icons.sticky_note_2,
      'عنوان الملاحظة', 'محتوى الملاحظة'),
];

class Section {
  final String id;
  final String title;
  final IconData icon;
  final String nameLabel;
  final String detailLabel;
  final bool amount;

  const Section(
    this.id,
    this.title,
    this.icon,
    this.nameLabel,
    this.detailLabel, {
    this.amount = false,
  });
}

String pinHash(String pin) =>
    sha256.convert(utf8.encode('ProDaftar_v1_$pin')).toString();

class ProDaftarApp extends StatefulWidget {
  const ProDaftarApp({super.key});

  @override
  State<ProDaftarApp> createState() => _ProDaftarAppState();
}

class _ProDaftarAppState extends State<ProDaftarApp> {
  bool dark = true;
  String businessName = 'دفتر المحترف';

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: businessName,
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF287D73),
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F7F8),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF58B8A7),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF101614),
      ),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: BusinessHome(
          dark: dark,
          businessName: businessName,
          onTheme: (v) => setState(() => dark = v),
          onBusinessName: (v) => setState(() => businessName = v),
        ),
      ),
    );
  }
}

class BusinessHome extends StatefulWidget {
  final bool dark;
  final String businessName;
  final ValueChanged<bool> onTheme;
  final ValueChanged<String> onBusinessName;

  const BusinessHome({
    super.key,
    required this.dark,
    required this.businessName,
    required this.onTheme,
    required this.onBusinessName,
  });

  @override
  State<BusinessHome> createState() => _BusinessHomeState();
}

class _BusinessHomeState extends State<BusinessHome> {
  SharedPreferences? prefs;

  final Map<String, List<Map<String, dynamic>>> data = {
    for (final s in sections) s.id: <Map<String, dynamic>>[],
  };

  int selected = -1;
  bool loading = true;
  bool unlocked = false;
  bool hasPin = false;
  String savedPinHash = '';
  String search = '';

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    prefs = await SharedPreferences.getInstance();

    for (final s in sections) {
      try {
        final raw = prefs!.getString('pro_${s.id}');
        if (raw != null) {
          final decoded = jsonDecode(raw) as List;
          data[s.id] = decoded
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        }
      } catch (_) {
        data[s.id] = [];
      }
    }

    final storedName = prefs!.getString('pro_business_name');
    final storedDark = prefs!.getBool('pro_dark_mode');
    savedPinHash = prefs!.getString('pro_pin_hash') ?? '';
    hasPin = savedPinHash.isNotEmpty;

    if (storedName != null && storedName.isNotEmpty) {
      widget.onBusinessName(storedName);
    }
    if (storedDark != null) widget.onTheme(storedDark);

    if (mounted) {
      setState(() {
        loading = false;
        unlocked = !hasPin;
      });
    }
  }

  Future<void> saveSection(String id) async {
    await prefs!.setString('pro_$id', jsonEncode(data[id]));
  }

  void notify(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  double amountOf(Map<String, dynamic> r) =>
      (r['amount'] as num?)?.toDouble() ?? 0;

  double get income => data['transactions']!
      .where((r) => r['type'] == 'income')
      .fold<double>(0, (s, r) => s + amountOf(r));

  double get expenses => data['transactions']!
      .where((r) => r['type'] == 'expense')
      .fold<double>(0, (s, r) => s + amountOf(r));

  double get debts => data['debts']!
      .fold<double>(0, (s, r) => s + amountOf(r));

  Future<void> verifyPin(String pin) async {
    if (pinHash(pin) == savedPinHash) {
      setState(() => unlocked = true);
    } else {
      notify('رمز الأمان غير صحيح');
    }
  }

  Future<void> configurePin() async {
    final first = TextEditingController();
    final second = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(hasPin ? 'تغيير رمز الأمان' : 'تفعيل رمز الأمان'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'اختر رمزًا رقميًا من 4 إلى 8 أرقام. '
              'لا تنسَ الرمز، فلا توجد آلية لاستعادته.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: first,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 8,
              decoration: const InputDecoration(
                labelText: 'رمز الأمان الجديد',
                border: OutlineInputBorder(),
              ),
            ),
            TextField(
              controller: second,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 8,
              decoration: const InputDecoration(
                labelText: 'تأكيد الرمز',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              final a = first.text.trim();
              final b = second.text.trim();
              if (!RegExp(r'^\d{4,8}$').hasMatch(a)) {
                notify('يجب أن يتكون الرمز من 4 إلى 8 أرقام');
                return;
              }
              if (a != b) {
                notify('الرمزان غير متطابقين');
                return;
              }
              Navigator.pop(ctx, a);
            },
            child: const Text('حفظ الرمز'),
          ),
        ],
      ),
    );

    first.dispose();
    second.dispose();

    if (result != null) {
      savedPinHash = pinHash(result);
      hasPin = true;
      await prefs!.setString('pro_pin_hash', savedPinHash);
      if (mounted) {
        setState(() {});
        notify('تم تفعيل رمز الأمان');
      }
    }
  }

  Future<void> removePin() async {
    final controller = TextEditingController();

    final pin = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إزالة رمز الأمان'),
        content: TextField(
          controller: controller,
          obscureText: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'أدخل الرمز الحالي',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('تحقق وإزالة'),
          ),
        ],
      ),
    );

    controller.dispose();

    if (pin == null) return;
    if (pinHash(pin) != savedPinHash) {
      notify('رمز الأمان غير صحيح');
      return;
    }

    await prefs!.remove('pro_pin_hash');
    if (mounted) {
      setState(() {
        hasPin = false;
        savedPinHash = '';
      });
      notify('تمت إزالة رمز الأمان');
    }
  }

  Future<void> addRecord(Section section, {Map<String, dynamic>? existing}) async {
    final name = TextEditingController(
      text: existing?['name']?.toString() ?? '',
    );
    final details = TextEditingController(
      text: existing?['details']?.toString() ?? '',
    );
    final amount = TextEditingController(
      text: existing == null ? '' : '${existing['amount'] ?? 0}',
    );
    String type = existing?['type']?.toString() ?? 'income';

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'إضافة سجل' : 'تعديل السجل'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: section.nameLabel,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: details,
                  minLines: 2,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: section.detailLabel,
                    border: const OutlineInputBorder(),
                  ),
                ),
                if (section.amount) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: amount,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'المبلغ أو السعر أو القيمة',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
                if (section.id == 'transactions') ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: type,
                    decoration: const InputDecoration(
                      labelText: 'نوع العملية',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'income',
                        child: Text('إيراد'),
                      ),
                      DropdownMenuItem(
                        value: 'expense',
                        child: Text('مصروف'),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) setDialogState(() => type = v);
                    },
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () {
                if (name.text.trim().isEmpty) {
                  notify('أدخل الاسم أولاً');
                  return;
                }
                Navigator.pop(ctx, true);
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      final record = existing ?? <String, dynamic>{
        'id': DateTime.now().microsecondsSinceEpoch.toString(),
        'created': DateTime.now().toIso8601String(),
        'done': false,
      };

      record['name'] = name.text.trim();
      record['details'] = details.text.trim();
      record['amount'] = double.tryParse(
            amount.text.trim().replaceAll(',', '.'),
          ) ??
          0.0;

      if (section.id == 'transactions') record['type'] = type;

      setState(() {
        if (existing == null) {
          data[section.id]!.insert(0, record);
        }
      });

      await saveSection(section.id);
      if (mounted) notify('تم حفظ السجل');
    }

    name.dispose();
    details.dispose();
    amount.dispose();
  }

  Future<void> deleteRecord(
    Section section,
    Map<String, dynamic> record,
  ) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text('هل تريد حذف "${record['name']}"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (yes == true) {
      setState(() => data[section.id]!.remove(record));
      await saveSection(section.id);
    }
  }

  Future<void> toggleTask(Map<String, dynamic> record) async {
    setState(() => record['done'] = !(record['done'] == true));
    await saveSection('tasks');
  }

  Widget stat(String title, String value, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 10),
            Text(title, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 5),
            Text(
              value,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget dashboard() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'مرحبًا بك في ${widget.businessName}',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        const Text('ملخص سريع لنشاطك التجاري'),
        const SizedBox(height: 18),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.25,
          children: [
            stat('العملاء', '${data['clients']!.length}', Icons.people),
            stat('المواعيد', '${data['appointments']!.length}',
                Icons.calendar_month),
            stat('الديون المسجلة', debts.toStringAsFixed(2),
                Icons.account_balance_wallet),
            stat('المهام المتبقية',
                '${data['tasks']!.where((r) => r['done'] != true).length}',
                Icons.task_alt),
            stat('إجمالي الإيرادات', income.toStringAsFixed(2),
                Icons.trending_up),
            stat('إجمالي المصروفات', expenses.toStringAsFixed(2),
                Icons.trending_down),
            stat('صافي العمليات', (income - expenses).toStringAsFixed(2),
                Icons.account_balance),
            stat('منتجات المخزون', '${data['inventory']!.length}',
                Icons.inventory_2),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('معلومات مالية'),
            subtitle: const Text(
              'الأرقام تمثل السجلات المدخلة فقط. '
              'الديون لا تُخصم تلقائيًا من الإيرادات، '
              'ولا يُعد صافي العمليات رصيدًا نقديًا فعليًا.',
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text('الأقسام', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        ...sections.asMap().entries.map((entry) {
          final i = entry.key;
          final s = entry.value;
          return Card(
            child: ListTile(
              leading: CircleAvatar(child: Icon(s.icon)),
              title: Text(s.title),
              subtitle: Text('${data[s.id]!.length} سجل'),
              trailing: const Icon(Icons.chevron_left),
              onTap: () => setState(() => selected = i),
            ),
          );
        }),
      ],
    );
  }

  Widget sectionPage(Section section) {
    final records = data[section.id]!.where((r) {
      if (search.trim().isEmpty) return true;
      final q = search.trim().toLowerCase();
      return (r['name'] ?? '').toString().toLowerCase().contains(q) ||
          (r['details'] ?? '').toString().toLowerCase().contains(q);
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            onChanged: (v) => setState(() => search = v),
            decoration: InputDecoration(
              hintText: 'بحث في ${section.title}',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
        Expanded(
          child: records.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(section.icon, size: 50, color: Colors.grey),
                      const SizedBox(height: 12),
                      Text(search.isEmpty
                          ? 'لا توجد سجلات بعد'
                          : 'لا توجد نتائج مطابقة'),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 90),
                  itemCount: records.length,
                  itemBuilder: (context, i) {
                    final r = records[i];
                    final done = r['done'] == true;
                    final value = amountOf(r);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 9),
                      child: ListTile(
                        leading: section.id == 'tasks'
                            ? Checkbox(
                                value: done,
                                onChanged: (_) => toggleTask(r),
                              )
                            : CircleAvatar(child: Icon(section.icon)),
                        title: Text(
                          r['name']?.toString() ?? '',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            decoration:
                                done ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 5),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if ((r['details'] ?? '')
                                  .toString()
                                  .isNotEmpty)
                                Text(r['details'].toString()),
                              if (section.amount)
                                Text(
                                  section.id == 'transactions'
                                      ? '${r['type'] == 'expense' ? 'مصروف' : 'إيراد'}: ${value.toStringAsFixed(2)}'
                                      : 'القيمة: ${value.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (v) {
                            if (v == 'edit') {
                              addRecord(section, existing: r);
                            }
                            if (v == 'delete') deleteRecord(section, r);
                            if (v == 'done') toggleTask(r);
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Text('تعديل'),
                            ),
                            if (section.id == 'tasks')
                              PopupMenuItem(
                                value: 'done',
                                child: Text(done ? 'إلغاء الإنجاز' : 'إنجاز'),
                              ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text('حذف'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> settings() async {
    final name = TextEditingController(text: widget.businessName);
    bool dark = widget.dark;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('إعدادات التطبيق'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(
                    labelText: 'اسم النشاط التجاري',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('الوضع الليلي'),
                  value: dark,
                  onChanged: (v) => setDialogState(() => dark = v),
                ),
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    hasPin ? Icons.lock : Icons.lock_open,
                  ),
                  title: Text(
                    hasPin ? 'تغيير رمز الأمان' : 'تفعيل رمز الأمان',
                  ),
                  subtitle: Text(
                    hasPin ? 'الرمز مفعّل' : 'حماية عند فتح التطبيق',
                  ),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await configurePin();
                  },
                ),
                if (hasPin)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.lock_open),
                    title: const Text('إزالة رمز الأمان'),
                    onTap: () async {
                      Navigator.pop(ctx);
                      await removePin();
                    },
                  ),
                const SizedBox(height: 8),
                const Text(
                  'تُحفظ البيانات محليًا على الجهاز. '
                  'هذه النسخة لا تتضمن مزامنة سحابية أو نسخًا احتياطيًا تلقائيًا.',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () async {
                final value =
                    name.text.trim().isEmpty ? 'دفتر المحترف' : name.text.trim();

                await prefs!.setString('pro_business_name', value);
                await prefs!.setBool('pro_dark_mode', dark);

                widget.onBusinessName(value);
                widget.onTheme(dark);

                if (mounted) setState(() {});
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );

    name.dispose();
  }

  Widget lockScreen() {
    final controller = TextEditingController();

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircleAvatar(
                  radius: 38,
                  child: Icon(Icons.lock_outline, size: 38),
                ),
                const SizedBox(height: 22),
                Text(
                  widget.businessName,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                const Text('أدخل رمز الأمان لفتح التطبيق'),
                const SizedBox(height: 24),
                TextField(
                  controller: controller,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: 8,
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                    labelText: 'رمز الأمان',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (v) => verifyPin(v.trim()),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => verifyPin(controller.text.trim()),
                    child: const Text('فتح التطبيق'),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'إذا نسيت الرمز، لا توجد استعادة تلقائية له. '
                  'لا تحذف بيانات التطبيق قبل حفظ نسخة خارجية من بياناتك.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!unlocked) return lockScreen();

    final home = selected == -1;
    final section = home ? null : sections[selected];

    return Scaffold(
      appBar: AppBar(
        title: Text(section?.title ?? widget.businessName),
        actions: [
          IconButton(
            tooltip: 'الإعدادات',
            onPressed: settings,
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const CircleAvatar(
                      radius: 28,
                      child: Icon(Icons.business_center, size: 30),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.businessName,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    const Text('إدارة أعمالك من مكان واحد'),
                  ],
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.dashboard),
                title: const Text('لوحة التحكم'),
                selected: home,
                onTap: () {
                  setState(() => selected = -1);
                  Navigator.pop(context);
                },
              ),
              Expanded(
                child: ListView(
                  children: [
                    for (int i = 0; i < sections.length; i++)
                      ListTile(
                        leading: Icon(sections[i].icon),
                        title: Text(sections[i].title),
                        selected: selected == i,
                        onTap: () {
                          setState(() {
                            selected = i;
                            search = '';
                          });
                          Navigator.pop(context);
                        },
                      ),
                  ],
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.settings),
                title: const Text('الإعدادات'),
                onTap: () {
                  Navigator.pop(context);
                  settings();
                },
              ),
            ],
          ),
        ),
      ),
      body: home ? dashboard() : sectionPage(section!),
      floatingActionButton: !home
          ? FloatingActionButton.extended(
              onPressed: () => addRecord(section!),
              icon: const Icon(Icons.add),
              label: const Text('إضافة سجل'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: home ? 0 : selected == 0 ? 1 : 2,
        onDestinationSelected: (i) {
          if (i == 0) {
            setState(() => selected = -1);
          } else if (i == 1) {
            setState(() {
              selected = 0;
              search = '';
            });
          } else {
            settings();
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'الرئيسية',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'العملاء',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'الإعدادات',
          ),
        ],
      ),
    );
  }
}