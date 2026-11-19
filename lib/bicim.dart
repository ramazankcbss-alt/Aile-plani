import 'package:intl/intl.dart';

/// Para, sayı ve tarih biçimleri (Türkçe).
final _tl = NumberFormat.currency(locale: 'tr_TR', symbol: '₺', decimalDigits: 0);
final _sayi = NumberFormat.decimalPattern('tr_TR');

String tl(num v) => _tl.format(v);
String sayi(num v) => _sayi.format(v);

/// "1.250,5" / "1250.5" / "1 250" gibi yazımları sayıya çevirir.
double? sayiOku(String s) {
  var t = s.trim().replaceAll(' ', '').replaceAll('₺', '');
  if (t.isEmpty) return null;
  if (t.contains(',')) {
    t = t.replaceAll('.', '').replaceAll(',', '.');
  } else if (RegExp(r'^\d{1,3}(\.\d{3})+$').hasMatch(t)) {
    t = t.replaceAll('.', '');
  }
  return double.tryParse(t);
}

const gunAdlari = ['Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'];
const gunKisa = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];

/// 2026-11-18 biçiminde gün anahtarı.
String gunAnahtari(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime gunBasi(DateTime d) => DateTime(d.year, d.month, d.day);

/// Haftanın pazartesisi 00:00.
DateTime haftaBasi(DateTime d) => gunBasi(d).subtract(Duration(days: d.weekday - 1));

DateTime ayBasi(DateTime d) => DateTime(d.year, d.month);

String tarihYaz(DateTime d) => DateFormat('d MMMM y', 'tr_TR').format(d);
String tarihKisa(DateTime d) => DateFormat('d MMM', 'tr_TR').format(d);
String ayYaz(DateTime d) => DateFormat('MMMM y', 'tr_TR').format(d);

String sureYaz(int dakika) {
  if (dakika < 60) return '$dakika dk';
  final s = dakika ~/ 60, d = dakika % 60;
  return d == 0 ? '$s sa' : '$s sa $d dk';
}

/// "08:30" → dakika (510). Geçersizse null.
int? saatDakika(String s) {
  final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(s.trim());
  if (m == null) return null;
  final sa = int.parse(m.group(1)!), dk = int.parse(m.group(2)!);
  if (sa > 23 || dk > 59) return null;
  return sa * 60 + dk;
}

String saatYaz(int dakika) =>
    '${(dakika ~/ 60).toString().padLeft(2, '0')}:${(dakika % 60).toString().padLeft(2, '0')}';
