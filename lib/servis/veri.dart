import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../modeller.dart';
import 'bildirim.dart';

/// Firestore yolları ve yazma işlemleri.
///
/// ap_kullanicilar/{uid}             : {ad, aileId, kisiId}
/// ap_kodlar/{kod}                   : {aileId}   (davet kodu → aile)
/// ap_aileler/{aid}                  : {ad, sahip, uyeler, kod, kisiler, aylikButce}
/// ap_aileler/{aid}/katilim/{uid}    : {kod}
/// ap_aileler/{aid}/program|planlar|dilekler|aliskanliklar|harcamalar/{id}
class Veri {
  Veri._();

  static final _db = FirebaseFirestore.instance;
  static CollectionReference<Map<String, dynamic>> get kullanicilar =>
      _db.collection('ap_kullanicilar');
  static CollectionReference<Map<String, dynamic>> get kodlar => _db.collection('ap_kodlar');
  static CollectionReference<Map<String, dynamic>> get aileler => _db.collection('ap_aileler');

  static CollectionReference<Map<String, dynamic>> alt(String aid, String ad) =>
      aileler.doc(aid).collection(ad);

  static int get simdi => DateTime.now().millisecondsSinceEpoch;

  static String yeniKod() {
    const harf = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final r = Random.secure();
    return List.generate(8, (_) => harf[r.nextInt(harf.length)]).join();
  }

  static String yeniId() {
    const harf = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final r = Random.secure();
    return List.generate(10, (_) => harf[r.nextInt(harf.length)]).join();
  }

  /// Yeni aile kurar. Kuran kişi "ben" olur; eş ve çocuklar kişi olarak eklenir.
  static Future<void> aileKur(String uid, String ad, String aileAdi,
      {String esAdi = '', List<String> cocuklar = const []}) async {
    final a = aileler.doc();
    final kod = yeniKod();
    final benId = yeniId();
    final kisiler = <Map<String, dynamic>>[
      Kisi(id: benId, ad: ad.trim(), rol: 'ben').toMap(),
      if (esAdi.trim().isNotEmpty) Kisi(id: yeniId(), ad: esAdi.trim(), rol: 'es').toMap(),
      for (final c in cocuklar)
        if (c.trim().isNotEmpty) Kisi(id: yeniId(), ad: c.trim(), rol: 'cocuk').toMap(),
    ];
    final b = _db.batch();
    b.set(a, {
      'ad': aileAdi.trim(),
      'sahip': uid,
      'uyeler': [uid],
      'kod': kod,
      'kisiler': kisiler,
      'aylikButce': 0,
    });
    b.set(kodlar.doc(kod), {'aileId': a.id});
    b.set(kullanicilar.doc(uid), {'ad': ad.trim(), 'aileId': a.id, 'kisiId': benId},
        SetOptions(merge: true));
    await b.commit();
    await _ornekleriEkle(a.id, kisiler);
  }

  /// Yeni aileye başlangıç için birkaç örnek alışkanlık ve program.
  static Future<void> _ornekleriEkle(String aid, List<Map<String, dynamic>> kisiler) async {
    try {
      final cocuklar = kisiler.where((k) => k['rol'] == 'cocuk').map((k) => k['id'] as String).toList();
      final esler = kisiler.where((k) => k['rol'] == 'es').map((k) => k['id'] as String).toList();
      final benler = kisiler.where((k) => k['rol'] == 'ben').map((k) => k['id'] as String).toList();
      final b = _db.batch();
      if (cocuklar.isNotEmpty) {
        b.set(alt(aid, 'aliskanliklar').doc(), {
          'baslik': 'Çocuklarla 20 dakika telefonsuz vakit',
          'kisiler': cocuklar,
          'gunler': <int>[],
          'yapilan': <String>[],
          'olusturma': simdi,
        });
      }
      b.set(alt(aid, 'aliskanliklar').doc(), {
        'baslik': 'Akşam yemeğini birlikte ye',
        'kisiler': <String>[],
        'gunler': <int>[],
        'yapilan': <String>[],
        'olusturma': simdi,
      });
      b.set(alt(aid, 'program').doc(), {
        'gun': 7,
        'saat': 10 * 60,
        'sure': 180,
        'baslik': 'Ailece kahvaltı ve gezinti',
        'tur': 'aile',
        'kisiler': <String>[],
      });
      b.set(alt(aid, 'program').doc(), {
        'gun': 6,
        'saat': 18 * 60,
        'sure': 60,
        'baslik': 'Kendime bir saat',
        'tur': 'kendim',
        'kisiler': benler,
      });
      if (esler.isNotEmpty) {
        b.set(alt(aid, 'program').doc(), {
          'gun': 3,
          'saat': 21 * 60,
          'sure': 45,
          'baslik': 'Eşimle çay ve sohbet',
          'tur': 'es',
          'kisiler': [...benler, ...esler],
        });
      }
      await b.commit();
    } catch (e) {
      debugPrint('Örnekler eklenemedi: $e');
    }
  }

  /// Davet koduyla aileye katılır.
  static Future<void> kodlaKatil(String uid, String ad, String kodYazi) async {
    final kod = kodYazi.trim().toUpperCase().replaceAll(' ', '');
    final k = await kodlar.doc(kod).get();
    final aid = k.data()?['aileId'] as String?;
    if (!k.exists || aid == null) {
      throw 'Bu davet kodu bulunamadı. Kodu aileyi kuran kişiden tekrar isteyin.';
    }
    final b = _db.batch();
    b.set(aileler.doc(aid).collection('katilim').doc(uid), {'kod': kod});
    b.update(aileler.doc(aid), {
      'uyeler': FieldValue.arrayUnion([uid])
    });
    b.set(kullanicilar.doc(uid), {'ad': ad.trim(), 'aileId': aid, 'kisiId': ''},
        SetOptions(merge: true));
    try {
      await b.commit();
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw 'Katılamadınız: kod değişmiş olabilir. Güncel kodu isteyin.';
      }
      rethrow;
    }
  }

  static Future<void> kisiSec(String uid, String kisiId) =>
      kullanicilar.doc(uid).set({'kisiId': kisiId}, SetOptions(merge: true));

  static Future<void> ailedenAyril(String uid) =>
      kullanicilar.doc(uid).set({'aileId': '', 'kisiId': ''}, SetOptions(merge: true));

  // --- Aile ayarları --------------------------------------------------------

  static Future<void> kisileriKaydet(String aid, List<Kisi> kisiler) =>
      aileler.doc(aid).update({'kisiler': kisiler.map((k) => k.toMap()).toList()});

  static Future<String> kisiEkle(Aile a, String ad, String rol) async {
    final id = yeniId();
    await kisileriKaydet(a.id, [...a.kisiler, Kisi(id: id, ad: ad.trim(), rol: rol)]);
    return id;
  }

  static Future<void> butceKaydet(String aid, double tutar) =>
      aileler.doc(aid).update({'aylikButce': tutar});

  static Future<void> aileAdiKaydet(String aid, String ad) =>
      aileler.doc(aid).update({'ad': ad.trim()});

  /// Davet kodunu yeniler (eski kod çalışmaz olur).
  static Future<void> koduYenile(Aile a) async {
    final yeni = yeniKod();
    final b = _db.batch();
    b.update(aileler.doc(a.id), {'kod': yeni});
    b.set(kodlar.doc(yeni), {'aileId': a.id});
    if (a.kod.isNotEmpty) b.delete(kodlar.doc(a.kod));
    await b.commit();
  }

  static Future<void> uyeCikar(String aid, String uid) => aileler.doc(aid).update({
        'uyeler': FieldValue.arrayRemove([uid])
      });

  // --- Kayıtlar -------------------------------------------------------------

  static Future<void> kaydet(String aid, String koleksiyon, String? id,
      Map<String, dynamic> veri) {
    final c = alt(aid, koleksiyon);
    return id == null ? c.add(veri) : c.doc(id).set(veri, SetOptions(merge: true));
  }

  static Future<void> sil(String aid, String koleksiyon, String id) =>
      alt(aid, koleksiyon).doc(id).delete();

  static Future<void> aliskanlikIsaretle(String aid, Aliskanlik a, DateTime gun, bool yapildi) {
    final k = '${gun.year.toString().padLeft(4, '0')}-${gun.month.toString().padLeft(2, '0')}-${gun.day.toString().padLeft(2, '0')}';
    return alt(aid, 'aliskanliklar').doc(a.id).update({
      'yapilan': yapildi ? FieldValue.arrayUnion([k]) : FieldValue.arrayRemove([k]),
    });
  }

  /// Plan tamamlandı: harcanan tutar girildiyse bütçeye harcama olarak işlenir.
  static Future<void> planTamamla(String aid, Plan p, double harcanan, String uid) async {
    final b = _db.batch();
    b.update(alt(aid, 'planlar').doc(p.id), {
      'tamam': true,
      'tamamTarih': simdi,
      'ilerleme': 100,
      'harcanan': harcanan,
    });
    if (harcanan > 0) {
      b.set(alt(aid, 'harcamalar').doc(), {
        'tutar': harcanan,
        'aciklama': p.baslik,
        'kategori': 'etkinlik',
        'kisiler': p.kisiler,
        'tarih': simdi,
        'planId': p.id,
        'olusturan': uid,
      });
    }
    await b.commit();
  }

  static Future<void> planGeriAl(String aid, Plan p) =>
      alt(aid, 'planlar').doc(p.id).update({'tamam': false, 'tamamTarih': 0});

  /// Uzun vadeli hedefe para ekler; aynı zamanda "birikim" harcaması yazılır.
  static Future<void> birikimEkle(String aid, Plan p, double tutar, String uid) async {
    final b = _db.batch();
    b.update(alt(aid, 'planlar').doc(p.id), {'biriken': FieldValue.increment(tutar)});
    b.set(alt(aid, 'harcamalar').doc(), {
      'tutar': tutar,
      'aciklama': 'Birikim: ${p.baslik}',
      'kategori': 'birikim',
      'kisiler': p.kisiler,
      'tarih': simdi,
      'planId': p.id,
      'olusturan': uid,
    });
    await b.commit();
  }

  /// Dileği kısa vadeli plana dönüştürür.
  static Future<void> dilektenPlan(String aid, Dilek d, String uid, int tarih) async {
    final b = _db.batch();
    final p = alt(aid, 'planlar').doc();
    b.set(p, {
      'baslik': d.baslik,
      'aciklama': 'Dilek kutusundan',
      'vade': 'kisa',
      'tarih': tarih,
      'kisiler': [d.kimden],
      'butce': d.maliyet,
      'biriken': 0,
      'ilerleme': 0,
      'tamam': false,
      'tamamTarih': 0,
      'harcanan': 0,
      'sure': 0,
      'olusturma': simdi,
      'olusturan': uid,
      'dilekId': d.id,
    });
    b.update(alt(aid, 'dilekler').doc(d.id), {'durum': 'planlandi', 'planId': p.id});
    await b.commit();
  }
}

/// Açık olan ailenin bütün verisini canlı dinler.
class Durum extends ChangeNotifier {
  Durum({required this.aid, required this.uid}) {
    _dinle();
  }

  final String aid;
  final String uid;

  Aile? aile;
  bool aileYok = false;
  Object? hata;
  String kisiId = '';
  String ad = '';

  List<ProgramOgesi> program = [];
  List<Plan> planlar = [];
  List<Dilek> dilekler = [];
  List<Aliskanlik> aliskanliklar = [];
  List<Harcama> harcamalar = [];

  final List<StreamSubscription> _abonelikler = [];
  bool _dilekIlk = true;

  Kisi? get ben => aile?.kisi(kisiId);
  bool get sahip => aile?.sahip == uid;

  void _dinle() {
    _abonelikler.add(Veri.kullanicilar.doc(uid).snapshots().listen((s) {
      kisiId = (s.data()?['kisiId'] as String?) ?? '';
      ad = (s.data()?['ad'] as String?) ?? '';
      notifyListeners();
    }, onError: _hata));
    _abonelikler.add(Veri.aileler.doc(aid).snapshots().listen((s) {
      final d = s.data();
      if (!s.exists || d == null) {
        aileYok = true;
        aile = null;
      } else {
        aile = Aile.fromMap(s.id, d);
        aileYok = !aile!.uyeler.contains(uid);
      }
      notifyListeners();
    }, onError: _hata));

    _abonelikler.add(Veri.alt(aid, 'program').snapshots().listen((q) {
      program = q.docs.map((d) => ProgramOgesi.fromMap(d.id, d.data())).toList()
        ..sort((a, b) => a.gun != b.gun ? a.gun.compareTo(b.gun) : a.saat.compareTo(b.saat));
      notifyListeners();
    }, onError: _altHata));
    _abonelikler.add(Veri.alt(aid, 'planlar').snapshots().listen((q) {
      planlar = q.docs.map((d) => Plan.fromMap(d.id, d.data())).toList()
        ..sort(_planSira);
      notifyListeners();
    }, onError: _altHata));
    _abonelikler.add(Veri.alt(aid, 'dilekler').snapshots().listen((q) {
      dilekler = q.docs.map((d) => Dilek.fromMap(d.id, d.data())).toList()
        ..sort((a, b) => b.olusturma.compareTo(a.olusturma));
      if (!_dilekIlk) {
        for (final c in q.docChanges) {
          if (c.type != DocumentChangeType.added) continue;
          final d = Dilek.fromMap(c.doc.id, c.doc.data() ?? {});
          if (d.olusturan == uid) continue;
          final kim = aile?.kisi(d.kimden)?.ad ?? 'Biri';
          Bildirim.goster(Bildirim.kimlik('dilek-${d.id}'), 'Yeni dilek: ${d.baslik}',
              '$kim dilek kutusuna ekledi.');
        }
      }
      _dilekIlk = false;
      Bildirim.dilekGoruldu(aid, dilekler.isEmpty ? 0 : dilekler.first.olusturma);
      notifyListeners();
    }, onError: _altHata));
    _abonelikler.add(Veri.alt(aid, 'aliskanliklar').snapshots().listen((q) {
      aliskanliklar = q.docs.map((d) => Aliskanlik.fromMap(d.id, d.data())).toList()
        ..sort((a, b) => a.baslik.compareTo(b.baslik));
      notifyListeners();
    }, onError: _altHata));
    final eski = DateTime.now().subtract(const Duration(days: 400)).millisecondsSinceEpoch;
    _abonelikler.add(Veri.alt(aid, 'harcamalar')
        .where('tarih', isGreaterThan: eski)
        .orderBy('tarih', descending: true)
        .limit(1000)
        .snapshots()
        .listen((q) {
      harcamalar = q.docs.map((d) => Harcama.fromMap(d.id, d.data())).toList();
      notifyListeners();
    }, onError: _altHata));
  }

  static int _planSira(Plan a, Plan b) {
    if (a.tamam != b.tamam) return a.tamam ? 1 : -1;
    final at = a.tarih == 0 ? 1 << 62 : a.tarih, bt = b.tarih == 0 ? 1 << 62 : b.tarih;
    if (at != bt) return at.compareTo(bt);
    return b.olusturma.compareTo(a.olusturma);
  }

  void _hata(Object e) {
    hata = e;
    notifyListeners();
  }

  void _altHata(Object e) => debugPrint('Dinleme hatası: $e');

  Denge denge([DateTime? an]) => Denge.hesapla(
        aile: aile!,
        program: program,
        planlar: planlar,
        dilekler: dilekler,
        harcamalar: harcamalar,
        simdi: an ?? DateTime.now(),
      );

  double ayHarcama(DateTime an) {
    final ay = DateTime(an.year, an.month).millisecondsSinceEpoch;
    final sonraki = DateTime(an.year, an.month + 1).millisecondsSinceEpoch;
    return harcamalar
        .where((h) => h.tarih >= ay && h.tarih < sonraki)
        .fold(0.0, (a, h) => a + h.tutar);
  }

  @override
  void dispose() {
    for (final a in _abonelikler) {
      a.cancel();
    }
    super.dispose();
  }
}
