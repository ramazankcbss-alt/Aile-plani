import 'package:aile_plani/bicim.dart';
import 'package:aile_plani/modeller.dart';
import 'package:flutter_test/flutter_test.dart';

Aile _aile() => Aile.fromMap('a', {
      'ad': 'Kocabaş ailesi',
      'sahip': 'u',
      'uyeler': ['u'],
      'kod': 'ABCDEFGH',
      'aylikButce': 1000,
      'kisiler': [
        {'id': 'ben', 'ad': 'Ramazan', 'rol': 'ben'},
        {'id': 'es', 'ad': 'Ayşe', 'rol': 'es'},
        {'id': 'c1', 'ad': 'Ali', 'rol': 'cocuk'},
      ],
    });

void main() {
  test('Sayı okuma (Türkçe yazım)', () {
    expect(sayiOku('1.250,5'), 1250.5);
    expect(sayiOku('1.250'), 1250);
    expect(sayiOku('12.5'), 12.5);
    expect(sayiOku(''), isNull);
  });

  test('Saat çevirme', () {
    expect(saatDakika('08:30'), 510);
    expect(saatYaz(510), '08:30');
    expect(sureYaz(90), '1 sa 30 dk');
  });

  test('Alışkanlık serisi', () {
    final bugun = DateTime(2026, 11, 18);
    final a = Aliskanlik.fromMap('x', {
      'baslik': 'Masal',
      'yapilan': ['2026-11-16', '2026-11-17'],
    });
    expect(a.seri(bugun), 2); // bugün henüz yapılmadı, seri bozulmaz
    final b = Aliskanlik.fromMap('y', {
      'baslik': 'Masal',
      'yapilan': ['2026-11-15', '2026-11-17', '2026-11-18'],
    });
    expect(b.seri(bugun), 2);
  });

  test('Denge: vakit ve harcama kişilere dağıtılır', () {
    final aile = _aile();
    final simdi = DateTime(2026, 11, 18);
    final d = Denge.hesapla(
      aile: aile,
      program: [
        ProgramOgesi.fromMap('1', {'gun': 1, 'saat': 480, 'sure': 600, 'baslik': 'İş', 'tur': 'is'}),
        ProgramOgesi.fromMap('2', {'gun': 7, 'saat': 600, 'sure': 120, 'baslik': 'Park', 'tur': 'cocuklar', 'kisiler': ['ben', 'c1']}),
        ProgramOgesi.fromMap('3', {'gun': 6, 'saat': 1080, 'sure': 60, 'baslik': 'Kitap', 'tur': 'kendim'}),
      ],
      planlar: const [],
      dilekler: [
        Dilek.fromMap('d', {'baslik': 'Bisiklet', 'kimden': 'c1', 'durum': 'bekliyor'}),
      ],
      harcamalar: [
        Harcama.fromMap('h', {'tutar': 300, 'tarih': DateTime(2026, 11, 2).millisecondsSinceEpoch}),
        Harcama.fromMap('h2', {'tutar': 200, 'kisiler': ['c1'], 'tarih': DateTime(2026, 11, 3).millisecondsSinceEpoch}),
        Harcama.fromMap('h3', {'tutar': 999, 'tarih': DateTime(2026, 10, 3).millisecondsSinceEpoch}),
      ],
      simdi: simdi,
    );
    DengeSatiri s(String id) => d.satirlar.firstWhere((x) => x.kisi.id == id);
    expect(s('ben').programDakika, 180);
    expect(s('c1').programDakika, 120);
    expect(s('es').programDakika, 0);
    expect(d.ayHarcama, 500);
    expect(s('c1').harcama, 300);
    expect(s('c1').bekleyenDilek, 1);
    final o = d.oneriler(aliskanliklar: const [], planlar: const [], simdi: simdi);
    expect(o.any((x) => x.contains('Ayşe')), isTrue);
    expect(o.any((x) => x.contains('Dilek kutusunda 1')), isTrue);
  });

  test('Uzun vadeli hedef oranı', () {
    final p = Plan.fromMap('p', {'baslik': 'Tatil', 'vade': 'uzun', 'butce': 20000, 'biriken': 5000});
    expect(p.oran, 0.25);
    expect(_aile().adlar(['es', 'c1']), 'Ayşe, Ali');
    expect(_aile().adlar([]), 'Herkes');
  });
}
