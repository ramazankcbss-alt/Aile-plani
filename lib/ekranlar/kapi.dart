import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../modeller.dart';
import '../servis/bildirim.dart';
import '../servis/guncelleme.dart';
import '../servis/veri.dart';
import '../tema.dart';
import 'ana.dart';
import 'giris.dart';

/// Oturum → profil → aile → "sen kimsin" sırasıyla doğru ekranı gösterir.
class Kapi extends StatelessWidget {
  const Kapi({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, s) {
        if (s.connectionState == ConnectionState.waiting) return const Yukleniyor();
        final u = s.data;
        if (u == null) return const GirisEkrani();
        return _ProfilKapi(key: ValueKey(u.uid), uid: u.uid);
      },
    );
  }
}

class Yukleniyor extends StatelessWidget {
  const Yukleniyor({super.key});
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}

class _ProfilKapi extends StatefulWidget {
  const _ProfilKapi({super.key, required this.uid});
  final String uid;

  @override
  State<_ProfilKapi> createState() => _ProfilKapiState();
}

class _ProfilKapiState extends State<_ProfilKapi> {
  late final _akis = Veri.kullanicilar.doc(widget.uid).snapshots();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: _akis,
      builder: (context, s) {
        if (s.hasError) return HataEkrani(yazi: hataYazisi(s.error!));
        if (!s.hasData) return const Yukleniyor();
        final d = s.data!.data() ?? {};
        final ad = (d['ad'] as String?) ?? '';
        final aid = (d['aileId'] as String?) ?? '';
        if (aid.isEmpty) return KurulumEkrani(uid: widget.uid, ad: ad);
        return _AileKapi(key: ValueKey(aid), uid: widget.uid, aid: aid);
      },
    );
  }
}

class _AileKapi extends StatefulWidget {
  const _AileKapi({super.key, required this.uid, required this.aid});
  final String uid;
  final String aid;

  @override
  State<_AileKapi> createState() => _AileKapiState();
}

class _AileKapiState extends State<_AileKapi> {
  late Durum _durum = Durum(aid: widget.aid, uid: widget.uid);

  @override
  void initState() {
    super.initState();
    Hatirlatmalar.oturum(widget.aid, widget.uid);
  }

  void _yenidenDene() {
    final eski = _durum;
    setState(() => _durum = Durum(aid: widget.aid, uid: widget.uid));
    eski.dispose();
  }

  @override
  void dispose() {
    _durum.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _durum,
      builder: (context, _) {
        final d = _durum;
        if (d.hata != null || d.aileYok) {
          return Scaffold(
            body: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Panel(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Icon(Icons.lock_outline, size: 48, color: Renk.soluk),
                        const SizedBox(height: 8),
                        Text(
                          d.hata != null
                              ? hataYazisi(d.hata!)
                              : 'Bu aileye erişiminiz yok. Aileden çıkarılmış olabilirsiniz.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 15, color: Renk.yazi),
                        ),
                        const SizedBox(height: 18),
                        Buton(yazi: 'Tekrar dene', ikon: Icons.refresh, onTap: _yenidenDene),
                        const SizedBox(height: 10),
                        Buton(
                          yazi: 'Başka aileye katıl / yeni kur',
                          ikincil: true,
                          onTap: () => Veri.ailedenAyril(widget.uid),
                        ),
                        TextButton(
                            onPressed: () => FirebaseAuth.instance.signOut(),
                            child: const Text('Çıkış yap')),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }
        final aile = d.aile;
        if (aile == null) return const Yukleniyor();
        if (d.ben == null) return KisiSecimEkrani(durum: d, aile: aile);
        return AnaKabuk(durum: d);
      },
    );
  }
}

class HataEkrani extends StatelessWidget {
  const HataEkrani({super.key, required this.yazi});
  final String yazi;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Renk.kirmizi),
                  const SizedBox(height: 10),
                  Text(yazi, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  TextButton(
                      onPressed: () => FirebaseAuth.instance.signOut(),
                      child: const Text('Çıkış yap')),
                ],
              ),
            ),
          ),
        ),
      );
}

/// İlk açılış: aileyi kur ya da davet koduyla katıl.
class KurulumEkrani extends StatefulWidget {
  const KurulumEkrani({super.key, required this.uid, required this.ad});
  final String uid;
  final String ad;

  @override
  State<KurulumEkrani> createState() => _KurulumEkraniState();
}

class _KurulumEkraniState extends State<KurulumEkrani> {
  late final _ad = TextEditingController(text: widget.ad);
  final _kod = TextEditingController();
  final _aile = TextEditingController();
  final _es = TextEditingController();
  final _cocuklar = TextEditingController();
  bool _kur = true;
  bool _mesgul = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Guncelleme.kontrolEt(context);
    });
  }

  @override
  void dispose() {
    for (final c in [_ad, _kod, _aile, _es, _cocuklar]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _devam() async {
    final ad = _ad.text.trim();
    if (ad.length < 2) {
      bildir(context, 'Adınızı yazın.');
      return;
    }
    if (!_kur && _kod.text.trim().length < 6) {
      bildir(context, 'Size gönderilen davet kodunu yazın.');
      return;
    }
    setState(() => _mesgul = true);
    try {
      if (_kur) {
        final aileAdi = _aile.text.trim().isEmpty ? '$ad ailesi' : _aile.text.trim();
        await Veri.aileKur(widget.uid, ad, aileAdi,
            esAdi: _es.text,
            cocuklar: _cocuklar.text.split(RegExp(r'[,\n]')).map((e) => e.trim()).toList());
      } else {
        await Veri.kodlaKatil(widget.uid, ad, _kod.text);
      }
      await Bildirim.izinIste();
    } catch (e) {
      if (mounted) bildir(context, hataYazisi(e));
    } finally {
      if (mounted) setState(() => _mesgul = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hoş geldin'),
        actions: [
          TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              onPressed: () => FirebaseAuth.instance.signOut(),
              child: const Text('Çıkış')),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Panel(
              baslik: 'Adın',
              child: TextField(
                controller: _ad,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                    hintText: 'Örn. Ramazan', prefixIcon: Icon(Icons.person_outline)),
              ),
            ),
            Panel(
              baslik: 'Aile',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: true, label: Text('Aileyi kur'), icon: Icon(Icons.home)),
                      ButtonSegment(value: false, label: Text('Kodla katıl'), icon: Icon(Icons.group_add)),
                    ],
                    selected: {_kur},
                    onSelectionChanged: (s) => setState(() => _kur = s.first),
                  ),
                  const SizedBox(height: 14),
                  if (_kur) ...[
                    TextField(
                      controller: _aile,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                          labelText: 'Aile adı', hintText: 'Örn. Kocabaş ailesi'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _es,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                          labelText: 'Eşinin adı (isteğe bağlı)', prefixIcon: Icon(Icons.favorite_border)),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _cocuklar,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                          labelText: 'Çocukların adları',
                          hintText: 'Virgülle ayır: Ali, Zeynep',
                          prefixIcon: Icon(Icons.child_care)),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Aileyi kuran kişi, eşine ve büyük çocuklara Ayarlar bölümündeki davet kodunu gönderir. Onlar kendi telefonlarından katılır.',
                      style: TextStyle(color: Renk.soluk, fontSize: 13.5),
                    ),
                  ] else ...[
                    TextField(
                      controller: _kod,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                          labelText: 'Davet kodu', hintText: 'Örn. K7PX3MQA'),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Kodu aileyi kuran kişi Ayarlar → Aile üyeleri bölümünden gönderir.',
                      style: TextStyle(color: Renk.soluk, fontSize: 13.5),
                    ),
                  ],
                ],
              ),
            ),
            Buton(
              yazi: _kur ? 'Aileyi Kur' : 'Aileye Katıl',
              mesgul: _mesgul,
              onTap: _devam,
            ),
            const SizedBox(height: 16),
            Text(
              Guncelleme.buSurum > 0
                  ? 'Uygulama sürümü: ${Guncelleme.buSurum}'
                  : 'Uygulama sürümü: geliştirme',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Renk.soluk, fontSize: 12.5),
            ),
          ],
        ),
      ),
    );
  }
}

/// Koda katılan kişi ailedeki kişilerden hangisi olduğunu seçer.
class KisiSecimEkrani extends StatefulWidget {
  const KisiSecimEkrani({super.key, required this.durum, required this.aile});
  final Durum durum;
  final Aile aile;

  @override
  State<KisiSecimEkrani> createState() => _KisiSecimEkraniState();
}

class _KisiSecimEkraniState extends State<KisiSecimEkrani> {
  bool _mesgul = false;
  String _rol = 'es';

  Future<void> _sec(String kisiId) async {
    setState(() => _mesgul = true);
    try {
      await Veri.kisiSec(widget.durum.uid, kisiId);
    } catch (e) {
      if (mounted) bildir(context, hataYazisi(e));
    } finally {
      if (mounted) setState(() => _mesgul = false);
    }
  }

  Future<void> _yeni() async {
    final ad = widget.durum.ad.trim();
    if (ad.isEmpty) return;
    setState(() => _mesgul = true);
    try {
      final id = await Veri.kisiEkle(widget.aile, ad, _rol);
      await Veri.kisiSec(widget.durum.uid, id);
    } catch (e) {
      if (mounted) bildir(context, hataYazisi(e));
    } finally {
      if (mounted) setState(() => _mesgul = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.aile;
    return Scaffold(
      appBar: AppBar(title: Text(a.ad)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Panel(
              baslik: 'Ailede sen kimsin?',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final k in a.kisiler)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Text(k.emoji, style: const TextStyle(fontSize: 26)),
                      title: Text(k.ad),
                      subtitle: Text(Kisi.roller[k.rol] ?? ''),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _mesgul ? null : () => _sec(k.id),
                    ),
                ],
              ),
            ),
            Panel(
              baslik: 'Listede yoksan',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('"${widget.durum.ad}" adıyla yeni kişi olarak eklen:',
                      style: const TextStyle(color: Renk.soluk)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final r in const ['es', 'cocuk', 'diger'])
                        ChoiceChip(
                          label: Text(Kisi.roller[r]!),
                          selected: _rol == r,
                          onSelected: (_) => setState(() => _rol = r),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Buton(yazi: 'Ekle ve devam et', mesgul: _mesgul, onTap: _yeni),
                ],
              ),
            ),
            TextButton(
                onPressed: () => FirebaseAuth.instance.signOut(),
                child: const Text('Çıkış yap')),
          ],
        ),
      ),
    );
  }
}
