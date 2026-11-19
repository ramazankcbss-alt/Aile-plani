import 'package:flutter/material.dart';

import '../bicim.dart';
import '../modeller.dart';
import '../servis/veri.dart';
import '../tema.dart';
import 'formlar.dart';
import 'ortak.dart';

class ButceSayfasi extends StatefulWidget {
  const ButceSayfasi({super.key, required this.durum});
  final Durum durum;

  @override
  State<ButceSayfasi> createState() => _ButceSayfasiState();
}

class _ButceSayfasiState extends State<ButceSayfasi> {
  DateTime _ay = ayBasi(DateTime.now());

  Future<void> _butceDegistir(Aile a) async {
    final v = await tutarSor(context, 'Aylık aile bütçesi',
        aciklama: 'Etkinlik, gezi, hediye, dışarıda yemek gibi aile ve keyif harcamaları için her ay ayırdığın tutar.',
        varsayilan: a.aylikButce);
    if (v == null) return;
    try {
      await Veri.butceKaydet(a.id, v);
    } catch (e) {
      if (mounted) bildir(context, hataYazisi(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.durum;
    return Scaffold(
      appBar: AppBar(title: const Text('Bütçe')),
      body: ListenableBuilder(
        listenable: d,
        builder: (context, _) {
          final aile = d.aile!;
          final bas = _ay.millisecondsSinceEpoch;
          final son = DateTime(_ay.year, _ay.month + 1).millisecondsSinceEpoch;
          final l = d.harcamalar.where((h) => h.tarih >= bas && h.tarih < son).toList();
          final toplam = l.fold(0.0, (a, h) => a + h.tutar);
          final butce = aile.aylikButce;
          final kalan = butce - toplam;

          final kategori = <String, double>{};
          for (final h in l) {
            kategori[h.kategori] = (kategori[h.kategori] ?? 0) + h.tutar;
          }
          final kategoriSira = kategori.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

          final kisi = <String, double>{for (final k in aile.kisiler) k.id: 0};
          var ortak = 0.0;
          for (final h in l) {
            if (h.kisiler.isEmpty) {
              ortak += h.tutar;
            } else {
              for (final id in h.kisiler) {
                if (kisi.containsKey(id)) kisi[id] = kisi[id]! + h.tutar / h.kisiler.length;
              }
            }
          }
          final enCok = kisi.values.fold(ortak, (a, b) => a > b ? a : b);

          final hedefler = d.planlar.where((p) => p.uzun && !p.tamam && p.butce > 0).toList();
          final planli = d.planlar
              .where((p) => !p.uzun && !p.tamam && p.tarih >= bas && p.tarih < son)
              .fold(0.0, (a, p) => a + p.butce);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              Row(
                children: [
                  IconButton(
                      onPressed: () => setState(() => _ay = DateTime(_ay.year, _ay.month - 1)),
                      icon: const Icon(Icons.chevron_left)),
                  Expanded(
                    child: Text(ayYaz(_ay),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                  ),
                  IconButton(
                      onPressed: () => setState(() => _ay = DateTime(_ay.year, _ay.month + 1)),
                      icon: const Icon(Icons.chevron_right)),
                ],
              ),
              Panel(
                baslik: 'Aile bütçesi',
                sag: TextButton(
                    onPressed: () => _butceDegistir(aile),
                    child: Text(butce > 0 ? 'Değiştir' : 'Belirle')),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        _Rakam('Harcanan', tl(toplam), Renk.yazi),
                        _Rakam('Bütçe', butce > 0 ? tl(butce) : '—', Renk.soluk),
                        _Rakam('Kalan', butce > 0 ? tl(kalan) : '—',
                            kalan < 0 ? Renk.kirmizi : Renk.yesil),
                      ],
                    ),
                    if (butce > 0) ...[
                      const SizedBox(height: 12),
                      Cubuk(
                        oran: toplam / butce,
                        renk: toplam > butce
                            ? Renk.kirmizi
                            : (toplam > butce * 0.8 ? Renk.vurgu : Renk.ana),
                      ),
                    ],
                    if (planli > 0) ...[
                      const SizedBox(height: 10),
                      Text('Bu ay için planlanan etkinliklerin tahmini bütçesi: ${tl(planli)}',
                          style: const TextStyle(color: Renk.soluk, fontSize: 13)),
                    ],
                    if (butce == 0) ...[
                      const SizedBox(height: 8),
                      const Text('Aile ve keyif harcamaları için aylık bir tutar belirle; koç aşımda seni uyarsın.',
                          style: TextStyle(color: Renk.soluk, fontSize: 13)),
                    ],
                  ],
                ),
              ),
              if (l.isNotEmpty)
                Panel(
                  baslik: 'Kime ne kadar?',
                  child: Column(
                    children: [
                      for (final k in aile.kisiler)
                        _Bar(etiket: '${k.emoji} ${k.ad}', tutar: kisi[k.id] ?? 0, enCok: enCok),
                      if (ortak > 0) _Bar(etiket: '🏠 Ortak', tutar: ortak, enCok: enCok),
                    ],
                  ),
                ),
              if (kategoriSira.isNotEmpty)
                Panel(
                  baslik: 'Kategoriler',
                  child: Column(
                    children: [
                      for (final e in kategoriSira)
                        _Bar(
                            etiket: Harcama.kategoriler[e.key] ?? e.key,
                            tutar: e.value,
                            enCok: kategoriSira.first.value,
                            renk: Renk.vurgu),
                    ],
                  ),
                ),
              if (hedefler.isNotEmpty)
                Panel(
                  baslik: 'Uzun vadeli birikimler',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final p in hedefler) ...[
                        Text(p.baslik, style: const TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Cubuk(oran: p.oran, renk: Renk.mor, yukseklik: 8),
                        const SizedBox(height: 2),
                        Text('${tl(p.biriken)} / ${tl(p.butce)}',
                            style: const TextStyle(color: Renk.soluk, fontSize: 12.5)),
                        const SizedBox(height: 10),
                      ],
                    ],
                  ),
                ),
              Panel(
                baslik: 'Harcamalar',
                sag: TextButton.icon(
                  onPressed: () => ac(context, HarcamaFormu(durum: d)),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Ekle'),
                ),
                child: l.isEmpty
                    ? const BosDurum(
                        ikon: Icons.receipt_long, yazi: 'Bu ay için harcama girilmemiş.')
                    : Column(
                        children: [
                          for (final h in l)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              title: Text(h.aciklama.isEmpty
                                  ? (Harcama.kategoriler[h.kategori] ?? '')
                                  : h.aciklama),
                              subtitle: Text(
                                  '${tarihKisa(h.tarihD)} · ${Harcama.kategoriler[h.kategori]} · ${h.kisiler.isEmpty ? 'Ortak' : aile.adlar(h.kisiler)}'),
                              trailing: Text(tl(h.tutar),
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                              onTap: () => ac(context, HarcamaFormu(durum: d, harcama: h)),
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

class _Rakam extends StatelessWidget {
  const _Rakam(this.baslik, this.deger, this.renk);
  final String baslik;
  final String deger;
  final Color renk;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          children: [
            Text(baslik, style: const TextStyle(color: Renk.soluk, fontSize: 12.5)),
            const SizedBox(height: 2),
            FittedBox(
              child: Text(deger,
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: renk)),
            ),
          ],
        ),
      );
}

class _Bar extends StatelessWidget {
  const _Bar({required this.etiket, required this.tutar, required this.enCok, this.renk = Renk.ana});
  final String etiket;
  final double tutar;
  final double enCok;
  final Color renk;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            SizedBox(width: 110, child: Text(etiket, overflow: TextOverflow.ellipsis)),
            Expanded(child: Cubuk(oran: enCok <= 0 ? 0 : tutar / enCok, renk: renk, yukseklik: 8)),
            const SizedBox(width: 8),
            SizedBox(
              width: 78,
              child: Text(tl(tutar),
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            ),
          ],
        ),
      );
}
