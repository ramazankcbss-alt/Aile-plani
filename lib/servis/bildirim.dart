import 'dart:convert';
import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../bicim.dart';
import '../firebase_options.dart';
import '../modeller.dart';
import 'veri.dart';

/// Telefon bildirimleri.
class Bildirim {
  Bildirim._();

  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static bool _hazir = false;

  static const _kanal = AndroidNotificationDetails(
    'aile_plani',
    'Aile Planı',
    channelDescription: 'Hatırlatmalar, günün planı ve yeni dilekler',
    importance: Importance.high,
    priority: Priority.high,
    color: Color(0xFF2A9D8F),
  );

  static Future<void> init() async {
    if (_hazir) return;
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );
      _hazir = true;
    } catch (e) {
      debugPrint('Bildirim başlatılamadı: $e');
    }
  }

  static AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  static Future<bool> izinIste() async {
    if (!_hazir) return false;
    try {
      return await _android?.requestNotificationsPermission() ?? false;
    } catch (e) {
      debugPrint('Bildirim izni istenemedi: $e');
      return false;
    }
  }

  static Future<void> goster(int id, String baslik, String metin) async {
    if (!_hazir) return;
    try {
      await _plugin.show(
        id: id,
        title: baslik,
        body: metin,
        notificationDetails: const NotificationDetails(android: _kanal),
      );
    } catch (e) {
      debugPrint('Bildirim gösterilemedi: $e');
    }
  }

  static int kimlik(String anahtar) {
    var h = 0x811c9dc5;
    for (final c in anahtar.codeUnits) {
      h ^= c;
      h = (h * 0x01000193) & 0xffffffff;
    }
    return h & 0x7fffffff;
  }

  /// Uygulama açıkken görülen en yeni dileğin zamanı (arka planda tekrar bildirilmesin).
  static Future<void> dilekGoruldu(String aid, int zaman) async {
    try {
      final p = await SharedPreferences.getInstance();
      final eski = p.getInt('dilek_son_$aid') ?? 0;
      final yeni = zaman > eski ? zaman : eski;
      await p.setInt('dilek_son_$aid', yeni == 0 ? DateTime.now().millisecondsSinceEpoch : yeni);
    } catch (_) {}
  }
}

/// Günlük hatırlatma (telefonda saklanır, her telefonun kendine ait).
class Hatirlatma {
  Hatirlatma({
    required this.id,
    required this.saat,
    required this.metin,
    required this.gunler,
    this.acik = true,
  });

  final String id;

  /// Günün dakikası
  int saat;
  String metin;

  /// 1..7, boşsa her gün
  List<int> gunler;
  bool acik;

  bool bugunMu(DateTime d) => gunler.isEmpty || gunler.contains(d.weekday);

  Map<String, dynamic> toMap() =>
      {'id': id, 'saat': saat, 'metin': metin, 'gunler': gunler, 'acik': acik};

  factory Hatirlatma.fromMap(Map m) => Hatirlatma(
        id: '${m['id']}',
        saat: (m['saat'] as num?)?.toInt() ?? 20 * 60,
        metin: '${m['metin'] ?? ''}',
        gunler: ((m['gunler'] as List?) ?? const []).whereType<num>().map((e) => e.toInt()).toList(),
        acik: m['acik'] != false,
      );
}

class Hatirlatmalar {
  Hatirlatmalar._();

  static const _anahtar = 'hatirlatmalar';

  static Future<SharedPreferences> _p() async {
    final p = await SharedPreferences.getInstance();
    await p.reload();
    return p;
  }

  static List<Hatirlatma> get varsayilan => [
        Hatirlatma(id: 'cocuk', saat: 20 * 60, metin: 'Çocuklarla 20 dakika telefonsuz vakit 🧒', gunler: []),
        Hatirlatma(id: 'kendim', saat: 21 * 60 + 30, metin: 'Bugün kendin için ne yaptın? 10 dakika nefes al 🌿', gunler: []),
      ];

  static Future<List<Hatirlatma>> oku() async {
    final p = await _p();
    final s = p.getString(_anahtar);
    if (s == null) return varsayilan;
    try {
      final l = jsonDecode(s);
      if (l is List) return l.whereType<Map>().map(Hatirlatma.fromMap).toList();
    } catch (_) {}
    return varsayilan;
  }

  static Future<void> kaydet(List<Hatirlatma> l) async {
    final p = await _p();
    await p.setString(_anahtar, jsonEncode(l.map((h) => h.toMap()).toList()));
  }

  /// Sabah "günün planı" bildirimi saati (dakika); null: kapalı.
  static Future<int?> sabahOzeti() async {
    final p = await _p();
    final v = p.getInt('sabah_ozeti');
    if (v == null) return 8 * 60;
    return v < 0 ? null : v;
  }

  static Future<void> sabahOzetiKaydet(int? dakika) async {
    final p = await _p();
    await p.setInt('sabah_ozeti', dakika ?? -1);
  }

  static Future<bool> dilekBildirimi() async => (await _p()).getBool('dilek_bildirim') ?? true;

  static Future<void> dilekBildirimiKaydet(bool v) async =>
      (await _p()).setBool('dilek_bildirim', v);

  /// Hangi aile/kullanıcı için arka plan kontrolü yapılacağı.
  static Future<void> oturum(String aid, String uid) async {
    final p = await _p();
    await p.setString('oturum_aid', aid);
    await p.setString('oturum_uid', uid);
  }

  static Future<void> oturumKapat() async {
    final p = await _p();
    await p.remove('oturum_aid');
    await p.remove('oturum_uid');
  }

  /// Saati gelmiş ve bugün henüz gösterilmemiş hatırlatmaları gösterir.
  /// Saatinden 3 saatten fazla geçmişse (telefon kapalıydı vb.) atlanır.
  static Future<void> zamaniGelenleriGoster({String? aid, String? uid}) async {
    final p = await _p();
    final simdi = DateTime.now();
    final dk = simdi.hour * 60 + simdi.minute;
    final bugun = gunAnahtari(simdi);
    await Bildirim.init();

    for (final h in await oku()) {
      if (!h.acik || !h.bugunMu(simdi)) continue;
      if (dk < h.saat || dk - h.saat > 180) continue;
      final k = 'gosterildi_${h.id}';
      if (p.getString(k) == bugun) continue;
      await p.setString(k, bugun);
      await Bildirim.goster(Bildirim.kimlik('hatirlatma-${h.id}-$bugun'), 'Aile Planı', h.metin);
    }

    final sabah = await sabahOzeti();
    if (sabah != null && aid != null && dk >= sabah && dk - sabah <= 180 &&
        p.getString('gosterildi_sabah') != bugun) {
      await p.setString('gosterildi_sabah', bugun);
      try {
        final q = await Veri.alt(aid, 'program').where('gun', isEqualTo: simdi.weekday).get();
        final l = q.docs.map((d) => ProgramOgesi.fromMap(d.id, d.data())).toList()
          ..sort((a, b) => a.saat.compareTo(b.saat));
        final aile = l.where((o) => !ProgramOgesi.calisma(o.tur)).toList();
        final metin = aile.isEmpty
            ? 'Bugün programda aile ya da kendin için bir vakit yok. Küçük bir şey ekle!'
            : aile.take(4).map((o) => '${saatYaz(o.saat)} ${o.baslik}').join(' · ');
        await Bildirim.goster(Bildirim.kimlik('sabah-$bugun'),
            'Günaydın! Bugün ${gunAdlari[simdi.weekday - 1]}', metin);
      } catch (e) {
        debugPrint('Sabah özeti hazırlanamadı: $e');
      }
    }

    if (aid != null && uid != null && await dilekBildirimi()) {
      final son = p.getInt('dilek_son_$aid');
      if (son != null) {
        try {
          final q = await Veri.alt(aid, 'dilekler')
              .where('olusturma', isGreaterThan: son)
              .orderBy('olusturma')
              .limit(20)
              .get();
          var enYeni = son;
          for (final d in q.docs) {
            final x = Dilek.fromMap(d.id, d.data());
            if (x.olusturma > enYeni) enYeni = x.olusturma;
            if (x.olusturan == uid) continue;
            await Bildirim.goster(Bildirim.kimlik('dilek-${x.id}'), 'Yeni dilek: ${x.baslik}',
                'Dilek kutusuna yeni bir istek eklendi.');
          }
          await p.setInt('dilek_son_$aid', enYeni);
        } catch (e) {
          debugPrint('Dilekler kontrol edilemedi: $e');
        }
      }
    }
  }
}

const _gorevAdi = 'aile-plani-kontrol';

/// Uygulama kapalıyken ~15 dakikada bir çalışan kontrolü kurar.
Future<void> arkaPlanKontrolunuBaslat() async {
  try {
    await Workmanager().initialize(arkaPlanGorevi);
    await Workmanager().registerPeriodicTask(
      _gorevAdi,
      _gorevAdi,
      frequency: const Duration(minutes: 15),
    );
  } catch (e) {
    debugPrint('Arka plan kontrolü kurulamadı: $e');
  }
}

@pragma('vm:entry-point')
void arkaPlanGorevi() {
  Workmanager().executeTask((gorev, girdi) async {
    try {
      WidgetsFlutterBinding.ensureInitialized();
      DartPluginRegistrant.ensureInitialized();
      try {
        await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      } catch (_) {}
      final p = await SharedPreferences.getInstance();
      await p.reload();
      var aid = p.getString('oturum_aid');
      var uid = p.getString('oturum_uid');
      if (aid != null) {
        final k = FirebaseAuth.instance.currentUser ??
            await FirebaseAuth.instance
                .authStateChanges()
                .first
                .timeout(const Duration(seconds: 15), onTimeout: () => null);
        if (k == null || k.uid != uid) {
          aid = null;
          uid = null;
        }
      }
      await Hatirlatmalar.zamaniGelenleriGoster(aid: aid, uid: uid);
    } catch (e) {
      debugPrint('Arka plan kontrolü hatası: $e');
    }
    return true;
  });
}
