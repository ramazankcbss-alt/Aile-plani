import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../bicim.dart';
import '../modeller.dart';
import '../servis/bildirim.dart';
import '../servis/guncelleme.dart';
import '../servis/veri.dart';
import '../tema.dart';
import 'formlar.dart';
import 'ortak.dart';

/// "Aile" sekmesi: dilek kutusu, alışkanlıklar, denge, hatırlatmalar, ayarlar.
class AileSayfasi extends StatelessWidget {
  const AileSayfasi({super.key, required this.durum});
  final Durum durum;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: durum,
      builder: (context, _) {
        final aile = durum.aile!;
        final bekleyen = durum.dilekler.where((d) => d.durum == 'bekliyor').length;
        Widget satir(IconData ikon, Color renk, String baslik, String alt, Widget sayfa) => Panel(
              padding: EdgeInsets.zero,
              child: ListTile(
                leading: CircleAvatar(
                    backgroundColor: renk.withValues(alpha: 0.12), child: Icon(ikon, color: renk)),
                title: Text(baslik, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(alt),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => ac(context, sayfa),
              ),
            );
        return Scaffold(
          appBar: AppBar(title: Text(aile.ad)),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Panel(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final k in aile.kisiler)
                      Chip(avatar: Text(k.emoji), label: Text(k.ad)),
                  ],
                ),
              ),
              satir(Icons.card_giftcard, Renk.vurgu, 'Dilek kutusu',
                  bekleyen == 0 ? 'Eşin ve çocukların istekleri' : '$bekleyen dilek bekliyor',
                  DilekSayfasi(durum: durum)),
              satir(Icons.repeat, Renk.ana, 'Alışkanlıklar',
                  '${durum.aliskanliklar.length} alışkanlık · günlük ritüeller',
                  AliskanlikSayfasi(durum: durum)),
              satir(Icons.balance, Renk.mor, 'Denge raporu',
                  'Kime ne kadar vakit ve bütçe ayrıldı', DengeSayfasi(durum: durum)),
              satir(Icons.notifications_active_outlined, Renk.mavi, 'Hatırlatmalar',
                  'Günlük hatırlatma ve sabah özeti', const HatirlatmaSayfasi()),
              satir(Icons.settings_outlined, Renk.soluk, 'Aile ayarları',
                  'Kişiler, davet kodu, üyeler', AyarlarSayfasi(durum: durum)),
            ],
          ),
        );
      },
    );
  }
}

// --- Dilek kutusu -----------------------------------------------------------

class DilekSayfasi extends StatelessWidget {
  const DilekSayfasi({super.key, required this.durum});
  final Durum durum;

  Future<void> _plana(BuildContext context, Dilek d) async {
    final simdi = DateTime.now();
    final t = await showDatePicker(
      context: context,
      helpText: 'Ne zaman yapalım?',
      initialDate: simdi.add(const Duration(days: 2)),
      firstDate: gunBasi(simdi),
      lastDate: DateTime(simdi.year + 3),
    );
    if (t == null) return;
    try {
      await Veri.dilektenPlan(
          durum.aid, d, durum.uid, DateTime(t.year, t.month, t.day, 12).millisecondsSinceEpoch);
      if (context.mounted) bildir(context, 'Plan oluşturuldu: ${d.baslik}');
    } catch (e) {
      if (context.mounted) bildir(context, hataYazisi(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dilek kutusu')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => ac(context, DilekFormu(durum: durum)),
        icon: const Icon(Icons.add),
        label: const Text('Dilek ekle'),
      ),
      body: ListenableBuilder(
        listenable: durum,
        builder: (context, _) {
          final aile = durum.aile!;
          final bekleyen = durum.dilekler.where((d) => d.durum == 'bekliyor').toList()
            ..sort((a, b) => b.oncelik != a.oncelik
                ? b.oncelik.compareTo(a.oncelik)
                : b.olusturma.compareTo(a.olusturma));
          final digerleri = durum.dilekler.where((d) => d.durum != 'bekliyor').toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              const Panel(
                renk: Renk.vurguAcik,
                child: Text(
                  'Ailede herkes istediğini buraya yazar. Sen de uygun olanları plana dönüştürürsün; '
                  'böylece kimse unutulmaz.',
                  style: TextStyle(height: 1.35),
                ),
              ),
              if (bekleyen.isEmpty)
                const Panel(
                    child: BosDurum(
                        ikon: Icons.card_giftcard, yazi: 'Bekleyen dilek yok. Çocuklarına ne istediklerini sor!')),
              for (final d in bekleyen)
                Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Text(aile.kisi(d.kimden)?.emoji ?? '👤', style: const TextStyle(fontSize: 24)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(d.baslik,
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                                Text(
                                  '${aile.kisi(d.kimden)?.ad ?? 'Biri'} · ${Dilek.oncelikler[d.oncelik]}'
                                  '${d.maliyet > 0 ? ' · ~${tl(d.maliyet)}' : ''}',
                                  style: const TextStyle(color: Renk.soluk, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => ac(context, DilekFormu(durum: durum, dilek: d)),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          FilledButton.tonalIcon(
                            onPressed: () => _plana(context, d),
                            icon: const Icon(Icons.event_available),
                            label: const Text('Plana dönüştür'),
                          ),
                          TextButton(
                            onPressed: () => Veri.kaydet(durum.aid, 'dilekler', d.id, {'durum': 'yapildi'}),
                            child: const Text('Gerçekleşti'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              if (digerleri.isNotEmpty)
                Panel(
                  baslik: 'Planlanan ve gerçekleşenler',
                  child: Column(
                    children: [
                      for (final d in digerleri)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                              d.durum == 'yapildi' ? Icons.check_circle : Icons.event_available,
                              color: d.durum == 'yapildi' ? Renk.yesil : Renk.ana),
                          title: Text(d.baslik),
                          subtitle: Text(
                              '${aile.kisi(d.kimden)?.ad ?? ''} · ${d.durum == 'yapildi' ? 'Gerçekleşti' : 'Planlandı'}'),
                          trailing: d.durum == 'planlandi'
                              ? TextButton(
                                  onPressed: () =>
                                      Veri.kaydet(durum.aid, 'dilekler', d.id, {'durum': 'yapildi'}),
                                  child: const Text('Gerçekleşti'))
                              : null,
                          onLongPress: () => ac(context, DilekFormu(durum: durum, dilek: d)),
                        ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

// --- Alışkanlıklar ----------------------------------------------------------

class AliskanlikSayfasi extends StatelessWidget {
  const AliskanlikSayfasi({super.key, required this.durum});
  final Durum durum;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Alışkanlıklar')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => ac(context, AliskanlikFormu(durum: durum)),
        child: const Icon(Icons.add),
      ),
      body: ListenableBuilder(
        listenable: durum,
        builder: (context, _) {
          final simdi = DateTime.now();
          final gunler = [for (var i = 6; i >= 0; i--) gunBasi(simdi).subtract(Duration(days: i))];
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              if (durum.aliskanliklar.isEmpty)
                const Panel(
                    child: BosDurum(
                        ikon: Icons.repeat,
                        yazi: 'Küçük ama her gün yapılan şeyler hayatı değiştirir. İlk alışkanlığını ekle.')),
              for (final a in durum.aliskanliklar)
                Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(a.baslik,
                                style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700)),
                          ),
                          if (a.seri(simdi) > 0)
                            Etiket('🔥 ${a.seri(simdi)} gün', renk: Renk.vurgu, zemin: Renk.vurguAcik),
                          IconButton(
                            onPressed: () => ac(context, AliskanlikFormu(durum: durum, aliskanlik: a)),
                            icon: const Icon(Icons.edit_outlined, size: 20),
                          ),
                        ],
                      ),
                      Text(
                        '${durum.aile!.adlar(a.kisiler)} · ${a.gunler.isEmpty ? 'Her gün' : a.gunler.map((g) => gunKisa[g - 1]).join(', ')}',
                        style: const TextStyle(color: Renk.soluk, fontSize: 13),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          for (final g in gunler)
                            _GunKutusu(
                              gun: g,
                              aktif: a.bugunMu(g),
                              yapildi: a.yapildi(g),
                              onTap: () => Veri.aliskanlikIsaretle(durum.aid, a, g, !a.yapildi(g)),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _GunKutusu extends StatelessWidget {
  const _GunKutusu({required this.gun, required this.aktif, required this.yapildi, required this.onTap});
  final DateTime gun;
  final bool aktif;
  final bool yapildi;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: aktif ? onTap : null,
        borderRadius: BorderRadius.circular(10),
        child: Column(
          children: [
            Text(gunKisa[gun.weekday - 1], style: const TextStyle(fontSize: 11.5, color: Renk.soluk)),
            const SizedBox(height: 4),
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: yapildi ? Renk.ana : (aktif ? Colors.white : Renk.zemin),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: yapildi ? Renk.ana : Renk.cizgi),
              ),
              child: yapildi
                  ? const Icon(Icons.check, color: Colors.white, size: 20)
                  : Text('${gun.day}',
                      style: TextStyle(color: aktif ? Renk.yazi : Renk.gri, fontSize: 13)),
            ),
          ],
        ),
      );
}

// --- Denge raporu -----------------------------------------------------------

class DengeSayfasi extends StatelessWidget {
  const DengeSayfasi({super.key, required this.durum});
  final Durum durum;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Denge raporu')),
      body: ListenableBuilder(
        listenable: durum,
        builder: (context, _) {
          final simdi = DateTime.now();
          final d = durum.denge(simdi);
          final oneriler =
              d.oneriler(aliskanliklar: durum.aliskanliklar, planlar: durum.planlar, simdi: simdi);
          final enCokDk = d.satirlar.fold(0, (a, s) => s.programDakika > a ? s.programDakika : a);
          final enCokTl = d.satirlar.fold(0.0, (a, s) => s.harcama > a ? s.harcama : a);
          final turler = d.turDakika.entries.where((e) => e.value > 0).toList()
            ..sort((a, b) => b.value.compareTo(a.value));
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Panel(
                renk: Renk.vurguAcik,
                baslik: '🧭 Koçun önerileri',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final o in oneriler)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text('• $o', style: const TextStyle(height: 1.35)),
                      ),
                  ],
                ),
              ),
              Panel(
                baslik: 'Haftam nereye gidiyor?',
                child: turler.isEmpty
                    ? const Text('Haftalık programa saat ekledikçe burada dağılım görünür.',
                        style: TextStyle(color: Renk.soluk))
                    : Column(
                        children: [
                          for (final e in turler)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 5),
                              child: Row(
                                children: [
                                  Icon(turIkon(e.key), size: 18, color: turRenk(e.key)),
                                  const SizedBox(width: 6),
                                  SizedBox(width: 74, child: Text(ProgramOgesi.turler[e.key] ?? '')),
                                  Expanded(
                                    child: Cubuk(
                                        oran: e.value / d.toplamDakika,
                                        renk: turRenk(e.key),
                                        yukseklik: 8),
                                  ),
                                  const SizedBox(width: 8),
                                  SizedBox(
                                    width: 92,
                                    child: Text(
                                        '${sureYaz(e.value)} %${(e.value / d.toplamDakika * 100).round()}',
                                        textAlign: TextAlign.right,
                                        style: const TextStyle(fontSize: 12.5)),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
              ),
              Panel(
                baslik: 'Kişi kişi',
                child: Column(
                  children: [
                    for (final s in d.satirlar)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text('${s.kisi.emoji} ${s.kisi.ad}',
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                            const SizedBox(height: 6),
                            _Olcu('Haftalık vakit', sureYaz(s.programDakika),
                                enCokDk == 0 ? 0 : s.programDakika / enCokDk, Renk.ana),
                            _Olcu('Bu ay bütçe', tl(s.harcama),
                                enCokTl == 0 ? 0 : s.harcama / enCokTl, Renk.vurgu),
                            const SizedBox(height: 4),
                            Text(
                              'Bu ay ${s.yapilanPlan} plan yapıldı · '
                              '${s.gerceklesenDilek} dilek gerçekleşti, ${s.bekleyenDilek} bekliyor',
                              style: const TextStyle(color: Renk.soluk, fontSize: 12.5),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const Text(
                'Vakit, haftalık programdaki iş ve tarla dışındaki saatlerden; bütçe bu ayki harcamalardan hesaplanır. '
                'Kişi seçilmeyen kayıtlar herkese sayılır.',
                style: TextStyle(color: Renk.soluk, fontSize: 12.5),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Olcu extends StatelessWidget {
  const _Olcu(this.ad, this.deger, this.oran, this.renk);
  final String ad;
  final String deger;
  final double oran;
  final Color renk;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            SizedBox(width: 100, child: Text(ad, style: const TextStyle(fontSize: 13, color: Renk.soluk))),
            Expanded(child: Cubuk(oran: oran, renk: renk, yukseklik: 8)),
            const SizedBox(width: 8),
            SizedBox(
                width: 80,
                child: Text(deger,
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
          ],
        ),
      );
}

// --- Hatırlatmalar ----------------------------------------------------------

class HatirlatmaSayfasi extends StatefulWidget {
  const HatirlatmaSayfasi({super.key});

  @override
  State<HatirlatmaSayfasi> createState() => _HatirlatmaSayfasiState();
}

class _HatirlatmaSayfasiState extends State<HatirlatmaSayfasi> {
  List<Hatirlatma>? _liste;
  int? _sabah;
  bool _dilek = true;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    final l = await Hatirlatmalar.oku();
    final s = await Hatirlatmalar.sabahOzeti();
    final d = await Hatirlatmalar.dilekBildirimi();
    if (mounted) {
      setState(() {
        _liste = l;
        _sabah = s;
        _dilek = d;
      });
    }
  }

  Future<void> _kaydet() async {
    await Hatirlatmalar.kaydet(_liste!);
    setState(() {});
  }

  Future<int?> _saatSor(int dakika) async {
    final t = await showTimePicker(
        context: context, initialTime: TimeOfDay(hour: dakika ~/ 60, minute: dakika % 60));
    return t == null ? null : t.hour * 60 + t.minute;
  }

  Future<void> _duzenle([Hatirlatma? h]) async {
    final metin = TextEditingController(text: h?.metin ?? '');
    var saat = h?.saat ?? 20 * 60;
    var gunler = [...?h?.gunler];
    final sonuc = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, yenile) => Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(h == null ? 'Yeni hatırlatma' : 'Hatırlatmayı düzenle',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              TextField(
                controller: metin,
                autofocus: h == null,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(hintText: 'Örn. Eşini ara, akşam planı yap'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  final v = await _saatSor(saat);
                  if (v != null) yenile(() => saat = v);
                },
                icon: const Icon(Icons.schedule),
                label: Text(saatYaz(saat)),
              ),
              const SizedBox(height: 12),
              GunSecici(secili: gunler, degisti: (l) => yenile(() => gunler = l)),
              const SizedBox(height: 16),
              Row(
                children: [
                  if (h != null)
                    TextButton(
                      onPressed: () {
                        _liste!.removeWhere((x) => x.id == h.id);
                        Navigator.pop(ctx, true);
                      },
                      child: const Text('Sil', style: TextStyle(color: Renk.kirmizi)),
                    ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () {
                      final m = metin.text.trim();
                      if (m.isEmpty) return;
                      if (h == null) {
                        _liste!.add(Hatirlatma(id: Veri.yeniId(), saat: saat, metin: m, gunler: gunler));
                      } else {
                        h
                          ..metin = m
                          ..saat = saat
                          ..gunler = gunler;
                      }
                      Navigator.pop(ctx, true);
                    },
                    child: const Text('Kaydet'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (sonuc == true) {
      _liste!.sort((a, b) => a.saat.compareTo(b.saat));
      await _kaydet();
      final izin = await Bildirim.izinIste();
      if (!izin && mounted) {
        bildir(context, 'Bildirim izni kapalı olabilir. Telefon ayarlarından Aile Planı bildirimlerini açın.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = _liste;
    return Scaffold(
      appBar: AppBar(title: const Text('Hatırlatmalar')),
      floatingActionButton: l == null
          ? null
          : FloatingActionButton(onPressed: () => _duzenle(), child: const Icon(Icons.add)),
      body: l == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                Panel(
                  baslik: 'Günlük hatırlatmalar',
                  child: Column(
                    children: [
                      if (l.isEmpty)
                        const Text('Hatırlatma yok.', style: TextStyle(color: Renk.soluk)),
                      for (final h in l)
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: h.acik,
                          onChanged: (v) {
                            h.acik = v;
                            _kaydet();
                          },
                          title: Text(h.metin),
                          subtitle: Text(
                              '${saatYaz(h.saat)} · ${h.gunler.isEmpty ? 'Her gün' : h.gunler.map((g) => gunKisa[g - 1]).join(', ')}'),
                          secondary: IconButton(
                              onPressed: () => _duzenle(h), icon: const Icon(Icons.edit_outlined)),
                        ),
                    ],
                  ),
                ),
                Panel(
                  baslik: 'Sabah özeti',
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _sabah != null,
                    title: const Text('Günün programını sabah bildir'),
                    subtitle: Text(_sabah == null ? 'Kapalı' : saatYaz(_sabah!)),
                    onChanged: (v) async {
                      int? yeni;
                      if (v) {
                        yeni = await _saatSor(_sabah ?? 8 * 60);
                        if (yeni == null) return;
                      }
                      await Hatirlatmalar.sabahOzetiKaydet(yeni);
                      setState(() => _sabah = yeni);
                    },
                  ),
                ),
                Panel(
                  baslik: 'Dilek kutusu',
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _dilek,
                    title: const Text('Yeni dilek eklenince bildir'),
                    onChanged: (v) async {
                      await Hatirlatmalar.dilekBildirimiKaydet(v);
                      setState(() => _dilek = v);
                    },
                  ),
                ),
                const Text(
                  'Hatırlatmalar bu telefona özeldir. Telefon pil tasarrufundayken birkaç dakika gecikebilir.',
                  style: TextStyle(color: Renk.soluk, fontSize: 12.5),
                ),
              ],
            ),
    );
  }
}

// --- Ayarlar ----------------------------------------------------------------

class AyarlarSayfasi extends StatelessWidget {
  const AyarlarSayfasi({super.key, required this.durum});
  final Durum durum;

  Future<void> _kisiDuzenle(BuildContext context, Aile a, [Kisi? k]) async {
    final ad = TextEditingController(text: k?.ad ?? '');
    var rol = k?.rol ?? 'cocuk';
    final sonuc = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, yenile) => AlertDialog(
          title: Text(k == null ? 'Kişi ekle' : 'Kişiyi düzenle'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: ad,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Adı'),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  for (final e in Kisi.roller.entries)
                    ChoiceChip(
                      label: Text(e.value),
                      selected: rol == e.key,
                      onSelected: (_) => yenile(() => rol = e.key),
                    ),
                ],
              ),
            ],
          ),
          actions: [
            if (k != null && k.id != durum.kisiId)
              TextButton(
                  onPressed: () => Navigator.pop(ctx, 'sil'),
                  child: const Text('Çıkar', style: TextStyle(color: Renk.kirmizi))),
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Vazgeç')),
            FilledButton(onPressed: () => Navigator.pop(ctx, 'kaydet'), child: const Text('Kaydet')),
          ],
        ),
      ),
    );
    if (sonuc == null) return;
    try {
      if (sonuc == 'sil') {
        await Veri.kisileriKaydet(a.id, a.kisiler.where((x) => x.id != k!.id).toList());
      } else if (ad.text.trim().isNotEmpty) {
        if (k == null) {
          await Veri.kisiEkle(a, ad.text, rol);
        } else {
          await Veri.kisileriKaydet(a.id, [
            for (final x in a.kisiler) x.id == k.id ? Kisi(id: k.id, ad: ad.text.trim(), rol: rol) : x
          ]);
        }
      }
    } catch (e) {
      if (context.mounted) bildir(context, hataYazisi(e));
    }
  }

  Future<void> _aileAdi(BuildContext context, Aile a) async {
    final c = TextEditingController(text: a.ad);
    final r = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Aile adı'),
        content: TextField(controller: c, autofocus: true, textCapitalization: TextCapitalization.words),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('Kaydet')),
        ],
      ),
    );
    if (r == null || r.trim().isEmpty) return;
    try {
      await Veri.aileAdiKaydet(a.id, r);
    } catch (e) {
      if (context.mounted) bildir(context, hataYazisi(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Aile ayarları')),
      body: ListenableBuilder(
        listenable: durum,
        builder: (context, _) {
          final a = durum.aile!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Panel(
                baslik: 'Aile',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.home_outlined),
                  title: Text(a.ad),
                  trailing: const Icon(Icons.edit_outlined),
                  onTap: () => _aileAdi(context, a),
                ),
              ),
              Panel(
                baslik: 'Kişiler',
                sag: TextButton.icon(
                  onPressed: () => _kisiDuzenle(context, a),
                  icon: const Icon(Icons.person_add_alt, size: 18),
                  label: const Text('Ekle'),
                ),
                child: Column(
                  children: [
                    for (final k in a.kisiler)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Text(k.emoji, style: const TextStyle(fontSize: 24)),
                        title: Text(k.ad + (k.id == durum.kisiId ? ' (sen)' : '')),
                        subtitle: Text(Kisi.roller[k.rol] ?? ''),
                        trailing: const Icon(Icons.edit_outlined, size: 20),
                        onTap: () => _kisiDuzenle(context, a, k),
                      ),
                    const Text(
                      'Telefonu olmayan çocukları da kişi olarak ekle; planlarda ve dileklerde seçilebilsinler.',
                      style: TextStyle(color: Renk.soluk, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              Panel(
                baslik: 'Davet kodu',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Eşin ve büyük çocukların uygulamayı kurup hesap açtıktan sonra "Kodla katıl" deyip bu kodu yazar.',
                      style: TextStyle(color: Renk.soluk),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: SelectableText(a.kod,
                              style: const TextStyle(
                                  fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: 3)),
                        ),
                        IconButton(
                          tooltip: 'Kopyala',
                          onPressed: () async {
                            await Clipboard.setData(ClipboardData(
                                text: 'Aile Planı uygulamasına katıl! Davet kodu: ${a.kod}\n'
                                    'Uygulama: https://github.com/ramazankcbss-alt/Aile-plani/releases/latest'));
                            if (context.mounted) bildir(context, 'Davet mesajı kopyalandı.');
                          },
                          icon: const Icon(Icons.copy),
                        ),
                      ],
                    ),
                    if (durum.sahip)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () async {
                            if (!await onayla(context, 'Kod yenilensin mi?',
                                'Eski kod artık çalışmaz. Aileye katılmış olanlar etkilenmez.',
                                evet: 'Yenile')) {
                              return;
                            }
                            try {
                              await Veri.koduYenile(a);
                            } catch (e) {
                              if (context.mounted) bildir(context, hataYazisi(e));
                            }
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('Kodu yenile'),
                        ),
                      ),
                  ],
                ),
              ),
              Panel(
                baslik: 'Uygulamayı kullananlar (${a.uyeler.length})',
                child: _Uyeler(durum: durum, aile: a),
              ),
              Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Buton(
                      yazi: 'Çıkış yap',
                      ikon: Icons.logout,
                      ikincil: true,
                      onTap: () async {
                        await Hatirlatmalar.oturumKapat();
                        await FirebaseAuth.instance.signOut();
                        if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
                      },
                    ),
                    const SizedBox(height: 10),
                    Text(
                      Guncelleme.buSurum > 0 ? 'Sürüm ${Guncelleme.buSurum}' : 'Geliştirme sürümü',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Renk.soluk, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Uyeler extends StatefulWidget {
  const _Uyeler({required this.durum, required this.aile});
  final Durum durum;
  final Aile aile;

  @override
  State<_Uyeler> createState() => _UyelerState();
}

class _UyelerState extends State<_Uyeler> {
  final Map<String, String> _adlar = {};

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  @override
  void didUpdateWidget(covariant _Uyeler eski) {
    super.didUpdateWidget(eski);
    if (eski.aile.uyeler.length != widget.aile.uyeler.length) _yukle();
  }

  Future<void> _yukle() async {
    for (final u in widget.aile.uyeler) {
      if (_adlar.containsKey(u)) continue;
      try {
        final d = await Veri.kullanicilar.doc(u).get();
        final kisiId = (d.data()?['kisiId'] as String?) ?? '';
        final ad = widget.aile.kisi(kisiId)?.ad ?? (d.data()?['ad'] as String?) ?? 'Kullanıcı';
        _adlar[u] = ad;
      } catch (_) {
        _adlar[u] = 'Kullanıcı';
      }
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.aile;
    return Column(
      children: [
        for (final u in a.uyeler)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.phone_android),
            title: Text((_adlar[u] ?? '…') + (u == widget.durum.uid ? ' (sen)' : '')),
            subtitle: Text(u == a.sahip ? 'Aileyi kuran' : 'Üye'),
            trailing: widget.durum.sahip && u != a.sahip
                ? IconButton(
                    tooltip: 'Aileden çıkar',
                    onPressed: () async {
                      if (!await onayla(context, 'Aileden çıkarılsın mı?',
                          '${_adlar[u] ?? 'Bu kişi'} artık aile verilerini göremez.',
                          evet: 'Çıkar')) {
                        return;
                      }
                      try {
                        await Veri.uyeCikar(a.id, u);
                      } catch (e) {
                        if (context.mounted) bildir(context, hataYazisi(e));
                      }
                    },
                    icon: const Icon(Icons.person_remove_outlined, color: Renk.kirmizi),
                  )
                : null,
          ),
      ],
    );
  }
}
