import 'bicim.dart';

double _d(Object? v) => v is num ? v.toDouble() : 0;
int _i(Object? v) => v is num ? v.toInt() : 0;
String _s(Object? v) => v is String ? v : '';
List<String> _ls(Object? v) =>
    v is List ? v.whereType<String>().toList() : <String>[];

/// Ailedeki bir kişi. Telefonu olmayan küçük çocuklar da kişi olarak eklenir.
class Kisi {
  const Kisi({required this.id, required this.ad, required this.rol});

  final String id;
  final String ad;

  /// ben | es | cocuk | diger
  final String rol;

  static const roller = {
    'ben': 'Ben',
    'es': 'Eşim',
    'cocuk': 'Çocuk',
    'diger': 'Diğer',
  };

  String get emoji => switch (rol) {
        'ben' => '🙂',
        'es' => '💞',
        'cocuk' => '🧒',
        _ => '👤',
      };

  factory Kisi.fromMap(Map m) =>
      Kisi(id: _s(m['id']), ad: _s(m['ad']), rol: _s(m['rol']).isEmpty ? 'diger' : _s(m['rol']));

  Map<String, dynamic> toMap() => {'id': id, 'ad': ad, 'rol': rol};
}

class Aile {
  const Aile({
    required this.id,
    required this.ad,
    required this.sahip,
    required this.uyeler,
    required this.kod,
    required this.kisiler,
    required this.aylikButce,
  });

  final String id;
  final String ad;
  final String sahip;
  final List<String> uyeler;
  final String kod;
  final List<Kisi> kisiler;
  final double aylikButce;

  factory Aile.fromMap(String id, Map<String, dynamic> m) => Aile(
        id: id,
        ad: _s(m['ad']),
        sahip: _s(m['sahip']),
        uyeler: _ls(m['uyeler']),
        kod: _s(m['kod']),
        kisiler: (m['kisiler'] is List ? m['kisiler'] as List : const [])
            .whereType<Map>()
            .map(Kisi.fromMap)
            .where((k) => k.id.isNotEmpty)
            .toList(),
        aylikButce: _d(m['aylikButce']),
      );

  Kisi? kisi(String id) {
    for (final k in kisiler) {
      if (k.id == id) return k;
    }
    return null;
  }

  String adlar(List<String> idler) {
    final l = idler.map(kisi).whereType<Kisi>().map((k) => k.ad).toList();
    return l.isEmpty ? 'Herkes' : l.join(', ');
  }
}

/// Haftalık programdaki tekrar eden bir zaman dilimi.
class ProgramOgesi {
  const ProgramOgesi({
    required this.id,
    required this.gun,
    required this.saat,
    required this.sure,
    required this.baslik,
    required this.tur,
    required this.kisiler,
  });

  final String id;

  /// 1 = Pazartesi ... 7 = Pazar
  final int gun;

  /// Günün dakikası (ör. 08:30 → 510)
  final int saat;

  /// Dakika
  final int sure;
  final String baslik;
  final String tur;
  final List<String> kisiler;

  static const turler = {
    'is': 'İş',
    'tarla': 'Tarla',
    'aile': 'Aile',
    'cocuklar': 'Çocuklar',
    'es': 'Eşimle',
    'kendim': 'Kendime',
    'diger': 'Diğer',
  };

  static bool calisma(String tur) => tur == 'is' || tur == 'tarla';

  factory ProgramOgesi.fromMap(String id, Map<String, dynamic> m) => ProgramOgesi(
        id: id,
        gun: _i(m['gun']).clamp(1, 7).toInt(),
        saat: _i(m['saat']),
        sure: _i(m['sure']),
        baslik: _s(m['baslik']),
        tur: turler.containsKey(m['tur']) ? m['tur'] as String : 'diger',
        kisiler: _ls(m['kisiler']),
      );

  Map<String, dynamic> toMap() => {
        'gun': gun,
        'saat': saat,
        'sure': sure,
        'baslik': baslik,
        'tur': tur,
        'kisiler': kisiler,
      };
}

/// Kısa vadeli plan (etkinlik, gezi, yapılacak) ya da uzun vadeli hedef.
class Plan {
  const Plan({
    required this.id,
    required this.baslik,
    required this.aciklama,
    required this.vade,
    required this.tarih,
    required this.kisiler,
    required this.butce,
    required this.biriken,
    required this.ilerleme,
    required this.tamam,
    required this.tamamTarih,
    required this.harcanan,
    required this.sure,
    required this.olusturma,
  });

  final String id;
  final String baslik;
  final String aciklama;

  /// kisa | uzun
  final String vade;

  /// Kısa vadede yapılacağı gün, uzun vadede hedef tarih (ms). 0: yok
  final int tarih;
  final List<String> kisiler;

  /// Tahmini/ayrılan bütçe (uzun vadede hedef tutar)
  final double butce;

  /// Uzun vadeli hedef için şimdiye kadar biriktirilen
  final double biriken;

  /// 0..100
  final int ilerleme;
  final bool tamam;
  final int tamamTarih;

  /// Plan yapıldığında harcanan gerçek tutar
  final double harcanan;

  /// Tahmini süre (dakika)
  final int sure;
  final int olusturma;

  bool get uzun => vade == 'uzun';
  DateTime? get tarihD => tarih > 0 ? DateTime.fromMillisecondsSinceEpoch(tarih) : null;

  /// Uzun vadeli hedefte para hedefi varsa ona, yoksa ilerleme yüzdesine göre oran.
  double get oran {
    if (tamam) return 1;
    if (uzun && butce > 0) return (biriken / butce).clamp(0.0, 1.0).toDouble();
    return ilerleme / 100;
  }

  factory Plan.fromMap(String id, Map<String, dynamic> m) => Plan(
        id: id,
        baslik: _s(m['baslik']),
        aciklama: _s(m['aciklama']),
        vade: m['vade'] == 'uzun' ? 'uzun' : 'kisa',
        tarih: _i(m['tarih']),
        kisiler: _ls(m['kisiler']),
        butce: _d(m['butce']),
        biriken: _d(m['biriken']),
        ilerleme: _i(m['ilerleme']).clamp(0, 100).toInt(),
        tamam: m['tamam'] == true,
        tamamTarih: _i(m['tamamTarih']),
        harcanan: _d(m['harcanan']),
        sure: _i(m['sure']),
        olusturma: _i(m['olusturma']),
      );
}

/// Dilek kutusu: eş ya da çocukların istekleri.
class Dilek {
  const Dilek({
    required this.id,
    required this.baslik,
    required this.kimden,
    required this.maliyet,
    required this.oncelik,
    required this.durum,
    required this.olusturan,
    required this.olusturma,
  });

  final String id;
  final String baslik;

  /// İsteyen kişinin kimliği
  final String kimden;
  final double maliyet;

  /// 1 düşük, 2 orta, 3 çok istiyor
  final int oncelik;

  /// bekliyor | planlandi | yapildi
  final String durum;
  final String olusturan;
  final int olusturma;

  static const oncelikler = {1: 'Olsa güzel', 2: 'İstiyorum', 3: 'Çok istiyorum'};

  factory Dilek.fromMap(String id, Map<String, dynamic> m) => Dilek(
        id: id,
        baslik: _s(m['baslik']),
        kimden: _s(m['kimden']),
        maliyet: _d(m['maliyet']),
        oncelik: _i(m['oncelik']).clamp(1, 3).toInt(),
        durum: _s(m['durum']).isEmpty ? 'bekliyor' : _s(m['durum']),
        olusturan: _s(m['olusturan']),
        olusturma: _i(m['olusturma']),
      );
}

/// Günlük alışkanlık / ritüel (ör. çocuklarla 20 dk telefonsuz vakit).
class Aliskanlik {
  const Aliskanlik({
    required this.id,
    required this.baslik,
    required this.kisiler,
    required this.gunler,
    required this.yapilan,
  });

  final String id;
  final String baslik;
  final List<String> kisiler;

  /// Hangi günler (1..7). Boşsa her gün.
  final List<int> gunler;

  /// Yapıldığı günler: "2026-11-18"
  final List<String> yapilan;

  bool bugunMu(DateTime d) => gunler.isEmpty || gunler.contains(d.weekday);
  bool yapildi(DateTime d) => yapilan.contains(gunAnahtari(d));

  /// Bugünden geriye, yapılması gereken günlerde kesintisiz yapılan gün sayısı.
  /// Bugün henüz yapılmadıysa seri bozulmuş sayılmaz.
  int seri(DateTime bugun) {
    final set = yapilan.toSet();
    var n = 0;
    var d = gunBasi(bugun);
    for (var i = 0; i < 400; i++) {
      if (bugunMu(d)) {
        if (set.contains(gunAnahtari(d))) {
          n++;
        } else if (i > 0) {
          break;
        }
      }
      d = d.subtract(const Duration(days: 1));
    }
    return n;
  }

  /// Son 7 günde (yapılması gereken günlerden) kaçı yapıldı.
  (int, int) haftalik(DateTime bugun) {
    var yapilmali = 0, yapilmis = 0;
    for (var i = 0; i < 7; i++) {
      final d = gunBasi(bugun).subtract(Duration(days: i));
      if (!bugunMu(d)) continue;
      yapilmali++;
      if (yapildi(d)) yapilmis++;
    }
    return (yapilmis, yapilmali);
  }

  factory Aliskanlik.fromMap(String id, Map<String, dynamic> m) => Aliskanlik(
        id: id,
        baslik: _s(m['baslik']),
        kisiler: _ls(m['kisiler']),
        gunler: (m['gunler'] is List ? m['gunler'] as List : const [])
            .whereType<num>()
            .map((e) => e.toInt())
            .toList(),
        yapilan: _ls(m['yapilan']),
      );
}

class Harcama {
  const Harcama({
    required this.id,
    required this.tutar,
    required this.aciklama,
    required this.kategori,
    required this.kisiler,
    required this.tarih,
    required this.planId,
  });

  final String id;
  final double tutar;
  final String aciklama;
  final String kategori;
  final List<String> kisiler;
  final int tarih;
  final String planId;

  static const kategoriler = {
    'etkinlik': 'Etkinlik / gezi',
    'yemek': 'Dışarıda yemek',
    'hediye': 'Hediye',
    'egitim': 'Eğitim / kurs',
    'oyuncak': 'Oyun / oyuncak',
    'kendim': 'Kendime',
    'birikim': 'Hedefe birikim',
    'diger': 'Diğer',
  };

  DateTime get tarihD => DateTime.fromMillisecondsSinceEpoch(tarih);

  factory Harcama.fromMap(String id, Map<String, dynamic> m) => Harcama(
        id: id,
        tutar: _d(m['tutar']),
        aciklama: _s(m['aciklama']),
        kategori: kategoriler.containsKey(m['kategori']) ? m['kategori'] as String : 'diger',
        kisiler: _ls(m['kisiler']),
        tarih: _i(m['tarih']),
        planId: _s(m['planId']),
      );
}

/// Bir kişi için denge raporu satırı.
class DengeSatiri {
  DengeSatiri(this.kisi);
  final Kisi kisi;

  /// Haftalık programda bu kişiyle planlanmış vakit (iş/tarla hariç)
  int programDakika = 0;

  /// Bu ay yapılan planlar
  int yapilanPlan = 0;

  /// Bu ay bu kişi için harcanan (ortak harcamalar paylaştırılır)
  double harcama = 0;

  /// Bekleyen ve gerçekleşen dilekleri
  int bekleyenDilek = 0;
  int gerceklesenDilek = 0;
}

class Denge {
  Denge({
    required this.satirlar,
    required this.turDakika,
    required this.ayHarcama,
    required this.aylikButce,
  });

  final List<DengeSatiri> satirlar;

  /// Haftalık programın türlere göre toplam dakikası
  final Map<String, int> turDakika;
  final double ayHarcama;
  final double aylikButce;

  int get toplamDakika => turDakika.values.fold(0, (a, b) => a + b);
  int get calismaDakika => (turDakika['is'] ?? 0) + (turDakika['tarla'] ?? 0);

  static Denge hesapla({
    required Aile aile,
    required List<ProgramOgesi> program,
    required List<Plan> planlar,
    required List<Dilek> dilekler,
    required List<Harcama> harcamalar,
    required DateTime simdi,
  }) {
    final satirlar = {for (final k in aile.kisiler) k.id: DengeSatiri(k)};
    final hepsi = aile.kisiler.map((k) => k.id).toList();
    List<String> kimler(List<String> l) => l.isEmpty ? hepsi : l;

    final tur = <String, int>{for (final t in ProgramOgesi.turler.keys) t: 0};
    for (final p in program) {
      tur[p.tur] = (tur[p.tur] ?? 0) + p.sure;
      if (ProgramOgesi.calisma(p.tur)) continue;
      // "Kendime" vakti, kişi seçilmediyse yalnızca "ben"e yazılır.
      final l = p.kisiler.isEmpty && p.tur == 'kendim'
          ? aile.kisiler.where((k) => k.rol == 'ben').map((k) => k.id).toList()
          : kimler(p.kisiler);
      for (final id in l) {
        satirlar[id]?.programDakika += p.sure;
      }
    }
    final ay = ayBasi(simdi).millisecondsSinceEpoch;
    for (final p in planlar) {
      if (!p.tamam || p.tamamTarih < ay) continue;
      for (final id in kimler(p.kisiler)) {
        satirlar[id]?.yapilanPlan++;
      }
    }
    var ayToplam = 0.0;
    for (final h in harcamalar) {
      if (h.tarih < ay) continue;
      ayToplam += h.tutar;
      final l = kimler(h.kisiler);
      if (l.isEmpty) continue;
      for (final id in l) {
        satirlar[id]?.harcama += h.tutar / l.length;
      }
    }
    for (final d in dilekler) {
      final s = satirlar[d.kimden];
      if (s == null) continue;
      if (d.durum == 'yapildi') {
        s.gerceklesenDilek++;
      } else {
        s.bekleyenDilek++;
      }
    }
    return Denge(
      satirlar: satirlar.values.toList(),
      turDakika: tur,
      ayHarcama: ayToplam,
      aylikButce: aile.aylikButce,
    );
  }

  /// Koç önerileri: en önemliden başlayarak.
  List<String> oneriler({required List<Aliskanlik> aliskanliklar, required List<Plan> planlar, required DateTime simdi}) {
    final l = <String>[];
    final kendim = turDakika['kendim'] ?? 0;
    if (kendim == 0) {
      l.add('Programında kendine ayrılmış bir vakit yok. Haftada en az 1 saat "Kendime" ekle: yürüyüş, kitap, bir hobi…');
    }
    final digerleri = satirlar.where((s) => s.kisi.rol != 'ben').toList()
      ..sort((a, b) => a.programDakika.compareTo(b.programDakika));
    if (digerleri.isNotEmpty) {
      final en = digerleri.first;
      if (en.programDakika < 120) {
        l.add(en.programDakika == 0
            ? '${en.kisi.ad} ile bu hafta programda ortak bir vakit yok. Birlikte küçük bir şey planla.'
            : '${en.kisi.ad} ile bu hafta programda sadece ${sureYaz(en.programDakika)} vakit var. Biraz daha ekleyebilir misin?');
      }
    }
    final esler = satirlar.where((s) => s.kisi.rol == 'es');
    for (final e in esler) {
      if ((turDakika['es'] ?? 0) == 0) {
        l.add('${e.kisi.ad} ile baş başa bir vakit yok. Haftada bir akşam çay ya da yürüyüş bile fark yaratır.');
      }
    }
    final bekleyen = satirlar.fold<int>(0, (a, s) => a + s.bekleyenDilek);
    if (bekleyen > 0) {
      l.add('Dilek kutusunda $bekleyen istek bekliyor. Birini bu haftanın planına dönüştür.');
    }
    if (aylikButce > 0 && ayHarcama > aylikButce * 0.9) {
      l.add(ayHarcama > aylikButce
          ? 'Bu ayın aile bütçesi ${tl(ayHarcama - aylikButce)} aşıldı. Ücretsiz etkinliklere yönel: park, piknik, oyun akşamı.'
          : 'Bu ayın bütçesinin %${(ayHarcama / aylikButce * 100).round()} kadarı kullanıldı.');
    }
    if (toplamDakika > 0 && calismaDakika / toplamDakika > 0.85) {
      l.add('Programının %${(calismaDakika / toplamDakika * 100).round()} kadarı iş ve tarla. Tarla işine çocukları da katarak vakti birleştirebilirsin.');
    }
    for (final a in aliskanliklar) {
      final (yapilmis, yapilmali) = a.haftalik(simdi);
      if (yapilmali >= 3 && yapilmis * 2 < yapilmali) {
        l.add('"${a.baslik}" son 7 günde $yapilmali günün $yapilmis gününde yapıldı. Hatırlatma kurmak işe yarayabilir.');
        break;
      }
    }
    final uzunlar = planlar.where((p) => p.uzun && !p.tamam).toList();
    if (uzunlar.isEmpty) {
      l.add('Uzun vadeli bir aile hedefiniz yok. Ailece hayal edin: bir tatil, ev düzenlemesi, ortak birikim…');
    }
    final seriler = aliskanliklar.map((a) => (a, a.seri(simdi))).where((x) => x.$2 >= 3).toList()
      ..sort((a, b) => b.$2.compareTo(a.$2));
    if (seriler.isNotEmpty) {
      l.add('Tebrikler! "${seriler.first.$1.baslik}" ${seriler.first.$2} gündür aksamadan devam ediyor. 👏');
    }
    if (l.isEmpty) {
      l.add('Her şey dengeli görünüyor. Bu hafta ailece yeni bir şey denemeye ne dersin?');
    }
    return l;
  }
}
