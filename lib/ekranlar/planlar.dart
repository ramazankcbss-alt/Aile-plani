import 'package:flutter/material.dart';

import '../bicim.dart';
import '../modeller.dart';
import '../servis/veri.dart';
import '../tema.dart';
import 'formlar.dart';
import 'ortak.dart';

class PlanlarSayfasi extends StatelessWidget {
  const PlanlarSayfasi({super.key, required this.durum});
  final Durum durum;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Planlar ve hedefler'),
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [Tab(text: 'Kısa vadeli'), Tab(text: 'Uzun vadeli'), Tab(text: 'Yapılanlar')],
          ),
        ),
        body: ListenableBuilder(
          listenable: durum,
          builder: (context, _) {
            final kisa = durum.planlar.where((p) => !p.uzun && !p.tamam).toList();
            final uzun = durum.planlar.where((p) => p.uzun && !p.tamam).toList();
            final tamam = durum.planlar.where((p) => p.tamam).toList()
              ..sort((a, b) => b.tamamTarih.compareTo(a.tamamTarih));
            return TabBarView(
              children: [
                _Liste(
                  durum: durum,
                  planlar: kisa,
                  bos: 'Bu hafta ya da bu ay ailece yapmak istediklerinizi ekleyin: piknik, sinema, akraba ziyareti…',
                  ekle: () => ac(context, PlanFormu(durum: durum, vade: 'kisa')),
                  ust: _KisaOzet(planlar: kisa),
                ),
                _Liste(
                  durum: durum,
                  planlar: uzun,
                  bos: 'Ailece büyük hedefler: yaz tatili, ev düzenlemesi, çocukların eğitimi, ortak birikim…',
                  ekle: () => ac(context, PlanFormu(durum: durum, vade: 'uzun')),
                ),
                _Liste(
                  durum: durum,
                  planlar: tamam,
                  bos: 'Tamamladığınız planlar burada birikir. Güzel anıların listesi!',
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _KisaOzet extends StatelessWidget {
  const _KisaOzet({required this.planlar});
  final List<Plan> planlar;

  @override
  Widget build(BuildContext context) {
    if (planlar.isEmpty) return const SizedBox.shrink();
    final simdi = DateTime.now();
    final ay = DateTime(simdi.year, simdi.month + 1).millisecondsSinceEpoch;
    final buAy = planlar.where((p) => p.tarih > 0 && p.tarih < ay);
    final butce = buAy.fold(0.0, (a, p) => a + p.butce);
    return Panel(
      renk: Renk.anaAcik,
      child: Text(
        'Bu ay ${buAy.length} plan var${butce > 0 ? ', tahmini ${tl(butce)}' : ''}. '
        'Tarihsiz ${planlar.where((p) => p.tarih == 0).length} plan bekliyor.',
        style: const TextStyle(color: Renk.anaKoyu, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _Liste extends StatelessWidget {
  const _Liste({
    required this.durum,
    required this.planlar,
    required this.bos,
    this.ekle,
    this.ust,
  });

  final Durum durum;
  final List<Plan> planlar;
  final String bos;
  final VoidCallback? ekle;
  final Widget? ust;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        if (ust != null) ust!,
        if (planlar.isEmpty)
          Panel(
            child: Column(
              children: [
                BosDurum(ikon: Icons.flag_outlined, yazi: bos),
                if (ekle != null) Buton(yazi: 'Ekle', ikon: Icons.add, onTap: ekle),
              ],
            ),
          ),
        for (final p in planlar) PlanKarti(durum: durum, plan: p),
      ],
    );
  }
}

Future<void> planTamamla(BuildContext context, Durum durum, Plan p) async {
  final t = await tutarSor(context, '“${p.baslik}” yapıldı 🎉',
      aciklama: 'Ne kadar harcandı? Bütçeye işlenir. Harcama yoksa boş bırakın.',
      varsayilan: p.butce);
  if (t == null) return;
  try {
    await Veri.planTamamla(durum.aid, p, t, durum.uid);
  } catch (e) {
    if (context.mounted) bildir(context, hataYazisi(e));
  }
}

/// Bugün ekranındaki kısa plan satırı.
class PlanSatiri extends StatelessWidget {
  const PlanSatiri({super.key, required this.durum, required this.plan});
  final Durum durum;
  final Plan plan;

  @override
  Widget build(BuildContext context) {
    final p = plan;
    final t = p.tarihD;
    final gecti = t != null && t.isBefore(gunBasi(DateTime.now()));
    return InkWell(
      onTap: () => ac(context, PlanFormu(durum: durum, plan: p)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            SizedBox(
              width: 52,
              child: Text(t == null ? '' : tarihKisa(t),
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: gecti ? Renk.kirmizi : Renk.yazi)),
            ),
            const Icon(Icons.event, color: Renk.vurgu, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.baslik, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  Text(
                    '${durum.aile!.adlar(p.kisiler)}${p.butce > 0 ? ' · ${tl(p.butce)}' : ''}${gecti ? ' · tarihi geçti' : ''}',
                    style: const TextStyle(color: Renk.soluk, fontSize: 13),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Yapıldı',
              onPressed: () => planTamamla(context, durum, p),
              icon: const Icon(Icons.check_circle_outline, color: Renk.yesil),
            ),
          ],
        ),
      ),
    );
  }
}

class PlanKarti extends StatelessWidget {
  const PlanKarti({super.key, required this.durum, required this.plan});
  final Durum durum;
  final Plan plan;

  @override
  Widget build(BuildContext context) {
    final p = plan;
    final aile = durum.aile!;
    final t = p.tarihD;
    final bilgi = <String>[
      if (t != null) (p.uzun ? 'Hedef: ${tarihYaz(t)}' : tarihYaz(t)),
      aile.adlar(p.kisiler),
      if (!p.uzun && p.butce > 0 && !p.tamam) 'Bütçe ${tl(p.butce)}',
      if (p.tamam && p.harcanan > 0) 'Harcanan ${tl(p.harcanan)}',
    ];
    return Panel(
      child: InkWell(
        onTap: () => ac(context, PlanFormu(durum: durum, plan: p)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(p.tamam ? Icons.check_circle : (p.uzun ? Icons.flag : Icons.event),
                    color: p.tamam ? Renk.yesil : (p.uzun ? Renk.mor : Renk.vurgu)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(p.baslik,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(bilgi.join(' · '), style: const TextStyle(color: Renk.soluk, fontSize: 13)),
            if (p.aciklama.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(p.aciklama),
            ],
            if (p.uzun && !p.tamam) ...[
              const SizedBox(height: 12),
              Cubuk(oran: p.oran, renk: Renk.mor),
              const SizedBox(height: 6),
              Text(
                p.butce > 0
                    ? '${tl(p.biriken)} / ${tl(p.butce)} biriktirildi (%${(p.oran * 100).round()})'
                        '${_aylik(p)}'
                    : '%${p.ilerleme} tamamlandı',
                style: const TextStyle(fontSize: 13, color: Renk.soluk),
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                if (!p.tamam && p.uzun && p.butce > 0)
                  TextButton.icon(
                    onPressed: () async {
                      final v = await tutarSor(context, 'Birikim ekle',
                          aciklama: '“${p.baslik}” için ayırdığın tutar.', bosOlur: false);
                      if (v == null || v <= 0) return;
                      try {
                        await Veri.birikimEkle(durum.aid, p, v, durum.uid);
                      } catch (e) {
                        if (context.mounted) bildir(context, hataYazisi(e));
                      }
                    },
                    icon: const Icon(Icons.savings_outlined),
                    label: const Text('Birikim ekle'),
                  ),
                if (!p.tamam)
                  TextButton.icon(
                    onPressed: () => planTamamla(context, durum, p),
                    icon: const Icon(Icons.check),
                    label: Text(p.uzun ? 'Hedefe ulaşıldı' : 'Yapıldı'),
                  )
                else
                  TextButton.icon(
                    onPressed: () => Veri.planGeriAl(durum.aid, p),
                    icon: const Icon(Icons.undo),
                    label: const Text('Geri al'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Hedef tarihe göre ayda ne kadar ayrılmalı.
  String _aylik(Plan p) {
    final t = p.tarihD;
    final kalan = p.butce - p.biriken;
    if (t == null || kalan <= 0) return '';
    final simdi = DateTime.now();
    final ay = (t.year - simdi.year) * 12 + t.month - simdi.month;
    if (ay <= 0) return '\nHedef tarih geldi, kalan ${tl(kalan)}';
    return '\nHedefe yetişmek için ayda ~${tl(kalan / ay)}';
  }
}
