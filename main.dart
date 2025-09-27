// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:intl/intl.dart';

// --- MODELS & DB helper (embedded for brevity) ---

class DBHelper {
  static final DBHelper _instance = DBHelper._internal();
  factory DBHelper() => _instance;
  DBHelper._internal();

  Database? _db;

  Future<Database> get db async {
    if (_db != null) return _db!;
    _db = await _init();
    return _db!;
  }

  Future<Database> _init() async {
    final path = join(await getDatabasesPath(), 'traveleks.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE operators(
            id TEXT PRIMARY KEY,
            code TEXT,
            name TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE bookings(
            id TEXT PRIMARY KEY,
            client_name TEXT,
            phone TEXT,
            operator_id TEXT,
            total_rub REAL,
            currency TEXT,
            operator_rate REAL,
            due_date TEXT,
            created_at TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE payments(
            id TEXT PRIMARY KEY,
            booking_id TEXT,
            amount_rub REAL,
            amount_currency REAL,
            currency TEXT,
            paid_at TEXT
          )
        ''');
        // insert default operators
        final opList = [
          ['anextour','AnexTour'],
          ['pegas','Pegas'],
          ['fstravel','FStravel'],
          ['coral','Coral'],
          ['sunmar','Sunmar'],
          ['paks','Paks'],
          ['russian_express','Russian Express'],
          ['intourist','Intourist']
        ];
        for (var o in opList) {
          await db.insert('operators', {
            'id': Uuid().v4(),
            'code': o[0],
            'name': o[1]
          });
        }
      },
    );
  }

  // CRUD bookings
  Future<List<Map<String, dynamic>>> getBookings() async {
    final database = await db;
    return database.query('bookings', orderBy: 'due_date ASC');
  }

  Future<void> insertBooking(Map<String, dynamic> b) async {
    final database = await db;
    await database.insert('bookings', b);
  }

  Future<void> insertPayment(Map<String, dynamic> p) async {
    final database = await db;
    await database.insert('payments', p);
  }

  Future<List<Map<String, dynamic>>> getPayments(String bookingId) async {
    final database = await db;
    return database.query('payments', where: 'booking_id = ?', whereArgs: [bookingId], orderBy: 'paid_at DESC');
  }

  Future<List<Map<String, dynamic>>> getOperators() async {
    final database = await db;
    return database.query('operators', orderBy: 'name ASC');
  }
}

class Booking {
  String id;
  String clientName;
  String phone;
  String operatorId;
  double totalRub;
  String currency; // 'RUB' / 'USD' / 'EUR'
  double operatorRate; // руб за 1 валюта (если currency != RUB)
  DateTime dueDate;
  Booking({
    required this.id,
    required this.clientName,
    required this.phone,
    required this.operatorId,
    required this.totalRub,
    required this.currency,
    required this.operatorRate,
    required this.dueDate,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'client_name': clientName,
    'phone': phone,
    'operator_id': operatorId,
    'total_rub': totalRub,
    'currency': currency,
    'operator_rate': operatorRate,
    'due_date': dueDate.toIso8601String(),
    'created_at': DateTime.now().toIso8601String(),
  };

  static Booking fromMap(Map<String, dynamic> m) {
    return Booking(
      id: m['id'],
      clientName: m['client_name'],
      phone: m['phone'],
      operatorId: m['operator_id'],
      totalRub: (m['total_rub'] as num).toDouble(),
      currency: m['currency'] ?? 'RUB',
      operatorRate: (m['operator_rate'] ?? 1.0).toDouble(),
      dueDate: DateTime.parse(m['due_date']),
    );
  }
}

// --- PROVIDER for state ---
class AppState extends ChangeNotifier {
  final DBHelper dbh = DBHelper();
  List<Booking> bookings = [];
  List<Map<String, dynamic>> operators = [];
  bool loading = false;

  Future<void> loadAll() async {
    loading = true; notifyListeners();
    final bList = await dbh.getBookings();
    bookings = bList.map((e) => Booking.fromMap(e)).toList();
    operators = await dbh.getOperators();
    loading = false; notifyListeners();
  }

  Future<void> addBooking(Booking b) async {
    await dbh.insertBooking(b.toMap());
    await loadAll();
  }

  Future<void> addPayment(String bookingId, double amountRub, {double? amountCurrency, String? currency}) async {
    await dbh.insertPayment({
      'id': Uuid().v4(),
      'booking_id': bookingId,
      'amount_rub': amountRub,
      'amount_currency': amountCurrency ?? 0.0,
      'currency': currency ?? 'RUB',
      'paid_at': DateTime.now().toIso8601String(),
    });
    await loadAll();
  }

  Future<double> getPaidForBooking(String bookingId) async {
    final pays = await dbh.getPayments(bookingId);
    double total = 0;
    for (var p in pays) total += (p['amount_rub'] as num).toDouble();
    return total;
  }

  Map<String, dynamic>? getOperatorById(String id) {
    try {
      return operators.firstWhere((o) => o['id'] == id);
    } catch (_) {
      return null;
    }
  }
}

// --- UI ---

void main() {
  runApp(ChangeNotifierProvider(
    create: (_) => AppState()..loadAll(),
    child: MyApp(),
  ));
}

class MyApp extends StatelessWidget {
  final primary = Colors.indigo;
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Traveleks (offline)',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: DashboardPage(),
    );
  }
}

class DashboardPage extends StatelessWidget {
  final currencyFmt = NumberFormat.currency(locale: 'ru_RU', symbol: '₽');

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('Traveleks — заявки'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () => state.loadAll(),
          ),
        ],
      ),
      body: state.loading
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: EdgeInsets.all(12),
                  child: Row(
                    children: [
                      ElevatedButton.icon(
                        icon: Icon(Icons.add),
                        label: Text('Новая заявка'),
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CreateBookingPage())),
                      ),
                      SizedBox(width: 12),
                      Text('Всего: ${state.bookings.length}'),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: state.bookings.length,
                    itemBuilder: (ctx, i) {
                      final b = state.bookings[i];
                      return FutureBuilder<double>(
                        future: state.getPaidForBooking(b.id),
                        builder: (ctx2, snap) {
                          final paid = snap.data ?? 0.0;
                          final remain = (b.totalRub - paid).clamp(0.0, double.infinity);
                          final due = DateFormat('yyyy-MM-dd').format(b.dueDate);
                          final op = state.getOperatorById(b.operatorId);
                          return Card(
                            margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            child: ListTile(
                              title: Text('${b.clientName} — ${op?['name'] ?? ''}'),
                              subtitle: Text('Сумма: ${currencyFmt.format(b.totalRub)} • Осталось: ${currencyFmt.format(remain)}\nК оплате до: $due'),
                              trailing: Icon(Icons.chevron_right),
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BookingDetailsPage(booking: b))),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

class CreateBookingPage extends StatefulWidget {
  @override
  _CreateBookingPageState createState() => _CreateBookingPageState();
}

class _CreateBookingPageState extends State<CreateBookingPage> {
  final _form = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _totalCtrl = TextEditingController();
  String _currency = 'RUB';
  double _operatorRate = 1.0;
  String? _selectedOperatorId;
  DateTime _dueDate = DateTime.now().add(Duration(days: 7));

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    final ops = state.operators;
    return Scaffold(
      appBar: AppBar(title: Text('Новая заявка')),
      body: Padding(
        padding: EdgeInsets.all(12),
        child: Form(
          key: _form,
          child: ListView(
            children: [
              TextFormField(controller: _nameCtrl, decoration: InputDecoration(labelText: 'ФИО туриста'), validator: (v)=> v==null||v.isEmpty? 'Введите имя':null),
              SizedBox(height:8),
              TextFormField(controller: _phoneCtrl, decoration: InputDecoration(labelText: 'Телефон')),
              SizedBox(height:8),
              DropdownButtonFormField<String>(
                value: _selectedOperatorId,
                hint: Text('Выберите оператора'),
                items: ops.map((o) => DropdownMenuItem(value: o['id'], child: Text(o['name']))).toList(),
                onChanged: (v) => setState(()=> _selectedOperatorId = v),
                validator: (v)=> v==null? 'Выберите оператора':null,
              ),
              SizedBox(height:8),
              Row(children: [
                Expanded(child: TextFormField(controller: _totalCtrl, decoration: InputDecoration(labelText: 'Сумма (в рублях)'), keyboardType: TextInputType.numberWithOptions(decimal: true), validator: (v)=> v==null||v.isEmpty? 'Введите сумму':null)),
                SizedBox(width:8),
                DropdownButton<String>(
                  value: _currency,
                  items: ['RUB','USD','EUR'].map((c)=> DropdownMenuItem(value:c, child: Text(c))).toList(),
                  onChanged: (v) => setState(()=> _currency = v!),
                )
              ]),
              SizedBox(height:8),
              TextFormField(
                initialValue: _operatorRate.toStringAsFixed(2),
                decoration: InputDecoration(labelText: 'Курс оператора (руб за 1 ${_currency})'),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                onChanged: (v) => setState(()=> _operatorRate = double.tryParse(v.replaceAll(',', '.')) ?? 1.0),
              ),
              SizedBox(height:8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Крайний срок оплаты: ${DateFormat('yyyy-MM-dd').format(_dueDate)}'),
                trailing: Icon(Icons.calendar_today),
                onTap: () async {
                  final dt = await showDatePicker(context: context, initialDate: _dueDate, firstDate: DateTime.now().subtract(Duration(days:365)), lastDate: DateTime.now().add(Duration(days:365*3)));
                  if (dt != null) setState(()=> _dueDate = dt);
                },
              ),
              SizedBox(height:12),
              ElevatedButton(
                child: Text('Сохранить'),
                onPressed: () async {
                  if (!_form.currentState!.validate()) return;
                  final id = Uuid().v4();
                  final totalRub = double.tryParse(_totalCtrl.text.replaceAll(',', '.')) ?? 0.0;
                  final b = Booking(
                    id: id,
                    clientName: _nameCtrl.text,
                    phone: _phoneCtrl.text,
                    operatorId: _selectedOperatorId!,
                    totalRub: totalRub,
                    currency: _currency,
                    operatorRate: _operatorRate,
                    dueDate: _dueDate,
                  );
                  await state.addBooking(b);
                  Navigator.pop(context);
                },
              )
            ],
          ),
        ),
      ),
    );
  }
}

class BookingDetailsPage extends StatefulWidget {
  final Booking booking;
  BookingDetailsPage({required this.booking});
  @override
  _BookingDetailsPageState createState() => _BookingDetailsPageState();
}

class _BookingDetailsPageState extends State<BookingDetailsPage> {
  final _payCtrl = TextEditingController();
  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    return Scaffold(
      appBar: AppBar(title: Text('Заявка — ${widget.booking.clientName}')),
      body: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          children: [
            Card(
              child: ListTile(
                title: Text(widget.booking.clientName),
                subtitle: Text('Тел: ${widget.booking.phone}\nСумма: ${widget.booking.totalRub.toStringAsFixed(2)} ₽'),
              ),
            ),
            SizedBox(height:8),
            FutureBuilder<double>(
              future: state.getPaidForBooking(widget.booking.id),
              builder: (ctx, snap) {
                final paid = snap.data ?? 0.0;
                final remain = (widget.booking.totalRub - paid).clamp(0.0, double.infinity);
                return Column(
                  children: [
                    Text('Внесено: ${paid.toStringAsFixed(2)} ₽', style: TextStyle(fontSize:16)),
                    SizedBox(height:6),
                    Text('Осталось: ${remain.toStringAsFixed(2)} ₽', style: TextStyle(fontSize:18, fontWeight: FontWeight.bold)),
                  ],
                );
              },
            ),
            SizedBox(height:12),
            TextField(controller: _payCtrl, keyboardType: TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: 'Добавить платёж (₽)')),
            SizedBox(height:8),
            ElevatedButton(
              child: Text('Добавить платёж'),
              onPressed: () async {
                final val = double.tryParse(_payCtrl.text.replaceAll(',', '.')) ?? 0.0;
                if (val <= 0) return;
                await state.addPayment(widget.booking.id, val);
                _payCtrl.clear();
                setState((){});
              },
            ),
            SizedBox(height:12),
            Expanded(
              child: FutureBuilder<List<Map<String,dynamic>>>(
                future: DBHelper().getPayments(widget.booking.id),
                builder: (ctx, snap) {
                  final list = snap.data ?? [];
                  if (list.isEmpty) return Text('Платежи отсутствуют');
                  return ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (i,_) {
                      final p = list[i];
                      return ListTile(
                        title: Text('${(p['amount_rub'] as num).toDouble().toStringAsFixed(2)} ₽'),
                        subtitle: Text('Дата: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.parse(p['paid_at']))}'),
                      );
                    }
                  );
                },
              ),
            )
          ],
        ),
      ),
    );
  }
}
