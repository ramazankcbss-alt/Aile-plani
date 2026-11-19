import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../bicim.dart';
import '../modeller.dart';
import '../servis/bildirim.dart';
import '../servis/guncelleme.dart';
import '../servis/veri.dart';
import '../tema.dart';
import 'aile.dart';
import 'butce.dart';
import 'formlar.dart';
import 'ortak.dart';
import 'planlar.dart';
import 'program.dart';

class AnaKabuk extends StatefulWidget {
  const AnaKabuk({super.key, required this.durum});
  final Durum durum;

  @override
  State<AnaKabuk> createState() => _AnaKabukState();
}

class _AnaKabukState extends State<AnaKabuk> {
  int _sekme = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      Guncelleme.kontrolEt(context);
      try {
        final p = await SharedPreferences.getInstance();
        if (p.getBool('izin_soruldu') != true) {
          await p.setBool('izin_soruldu', true);
          await Bildirim.izinIste();
        }
      } catch (_) {}
      Hatirlatmalar.zamaniGelenleriGoster(aid: widget.durum.aid, uid: widget.durum.uid);
    });
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.durum;
    final sayfalar = [
      BugunSayfasi(durum: d, sekmeyeGit: (i) => setState(() => _sekme = i)),
      ProgramSayfasi(durum: d),
      PlanlarSayfasi(durum: d),
      ButceSayfasi(durum: d),
      AileSayfasi(durum: d),
    ];
    return Scaffold(
      body: IndexedStack(index: _sekme, children: sayfalar),
      floatingActionButton: _sekme == 4
          ? null
          : FloatingActionButton(
              onPressed: () => hizliEkle(context, d),
              child: const Icon(Icons.add),
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _sekme,
        onDestinationSelected: (i) => setState(() => _sekme = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.wb_sunny_outlined), selectedIcon: Icon(Icons.wb_sunny), label: 'Bugün'),
          NavigationDestination(icon: Icon(Icons.calendar_view_week_outlined), selectedIcon: Icon(Icons.calendar_view_week), label: 'Program'),
          NavigationDestination(icon: Icon(Icons.flag_outlined), selectedIcon: Icon(Icons.flag), label: 'Planlar'),
          NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet), label: 'Bütçe'),
          NavigationDestination(icon: Icon(Icons.family_restroom_outlined), selectedIcon: Icon(Icons.family_restroom), label: 'Aile'),
        ],
      ),
    );
  }
}

class BugunSayfasi extends StatelessWidget {
  const BugunSayfasi({super.key, required this.durum, required this.sekmeyeGit});
  final Durum durum;
  final ValueChanged<int> sekmeyeGit;

  String _selam(DateTime t) {
    if (t.hour < 6) return 'İyi geceler';
    if (t.hour < 12) return 'Günaydın';
    if (t.hour < 18) return 'İyi günler';
    return 'İyi akşamlar';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: durum,
      builder: (context, _) {
        final aile = durum.aile!;
        final simdi = DateTime.now();
        final bugun = gunBasi(simdi);
        final yarin = bugun.add(const Duration(days: 1));
        final denge = durum.denge(simdi);
        final oneriler = denge.oneriler(
            aliskanliklar: durum.aliskanliklar, planlar: durum.planlar, simdi: simdi);
        final program = durum.program.where((o) => o.gun == simdi.weekday).toList();
        final planlar = durum.planlar
            .where((p) =>
                !p.tamam &&
                !p.uzun &&
                p.tarih > 0 &&
                p.tarih < yarin.millisecondsSinceEpoch)
            .toList();
        final yakin = durum.planlar
            .where((p) =>
                !p.tamam &&
                !p.uzun &&
                p.tarih >= yarin.millisecondsSinceEpoch &&
                p.tarih < bugun.add(const Duration(days: 8)).millisecondsSinceEpoch)
            .toList();
        final aliskanliklar = durum.aliskanliklar.where((a) => a.bugunMu(simdi)).toList();
        final bekleyen = durum.dilekler.where((x) => x.durum == 'bekliyor').length;
        final harcanan = durum.ayHarcama(simdi);

        return Scaffold(
          appBar: AppBar(
            toolbarHeight: 76,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${_selam(simdi)}, ${durum.ben?.ad ?? ''}'),
                Text('${gunAdlari[simdi.weekday - 1]}, ${tarihYaz(simdi)}',
                    style: const TextStyle(fontSize: 13.5, color: Colors.white70)),
              ],
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              Panel(
                renk: Renk.vurguAcik,
                baslik: '🧭 Koçun önerisi',
                sag: TextButton(
                    onPressed: () => ac(context, DengeSayfasi(durum: durum)),
                    child: const Text('Denge raporu')),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final o in oneriler.take(2))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text('• $o', style: const TextStyle(fontSize: 14.5, height: 1.35)),
                      ),
                  ],
                ),
              ),
              Panel(
                baslik: 'Bugünün programı',
                sag: TextButton(onPressed: () => sekmeyeGit(1), child: const Text('Hafta')),
                child: program.isEmpty && planlar.isEmpty
                    ? const Text('Bugün için program yok. ＋ ile ekleyebilirsin.',
                        style: TextStyle(color: Renk.soluk))
                    : Column(
                        children: [
                          for (final o in program) ProgramSatiri(durum: durum, oge: o),
                          for (final p in planlar) PlanSatiri(durum: durum, plan: p),
                        ],
                      ),
              ),
              if (aliskanliklar.isNotEmpty)
                Panel(
                  baslik: 'Bugünün alışkanlıkları',
                  child: Column(
                    children: [
                      for (final a in aliskanliklar)
                        AliskanlikSatiri(durum: durum, aliskanlik: a, gun: simdi),
                    ],
                  ),
                ),
              if (yakin.isNotEmpty)
                Panel(
                  baslik: 'Önümüzdeki 7 gün',
                  sag: TextButton(onPressed: () => sekmeyeGit(2), child: const Text('Planlar')),
                  child: Column(
                    children: [for (final p in yakin) PlanSatiri(durum: durum, plan: p)],
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: _Kutu(
                      ikon: Icons.card_giftcard,
                      baslik: 'Dilek kutusu',
                      deger: bekleyen == 0 ? 'Boş' : '$bekleyen bekliyor',
                      onTap: () => ac(context, DilekSayfasi(durum: durum)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _Kutu(
                      ikon: Icons.account_balance_wallet_outlined,
                      baslik: 'Bu ay',
                      deger: aile.aylikButce > 0
                          ? '${tl(harcanan)} / ${tl(aile.aylikButce)}'
                          : tl(harcanan),
                      onTap: () => sekmeyeGit(3),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Kutu extends StatelessWidget {
  const _Kutu({required this.ikon, required this.baslik, required this.deger, required this.onTap});
  final IconData ikon;
  final String baslik;
  final String deger;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Renk.cizgi),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(ikon, color: Renk.ana),
                const SizedBox(height: 8),
                Text(baslik, style: const TextStyle(color: Renk.soluk, fontSize: 13)),
                const SizedBox(height: 2),
                Text(deger,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              ],
            ),
          ),
        ),
      );
}

/// Programdaki bir öğe (saat, başlık, kişiler).
class ProgramSatiri extends StatelessWidget {
  const ProgramSatiri({super.key, required this.durum, required this.oge});
  final Durum durum;
  final ProgramOgesi oge;

  @override
  Widget build(BuildContext context) {
    final renk = turRenk(oge.tur);
    return InkWell(
      onTap: () => ac(context, ProgramFormu(durum: durum, oge: oge)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            SizedBox(
              width: 52,
              child: Text(saatYaz(oge.saat),
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
            ),
            Container(
              width: 4,
              height: 38,
              decoration: BoxDecoration(color: renk, borderRadius: BorderRadius.circular(4)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(oge.baslik, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  Text(
                    '${ProgramOgesi.turler[oge.tur]} · ${sureYaz(oge.sure)}'
                    '${ProgramOgesi.calisma(oge.tur) ? '' : ' · ${durum.aile!.adlar(oge.kisiler)}'}',
                    style: const TextStyle(color: Renk.soluk, fontSize: 13),
                  ),
                ],
              ),
            ),
            Icon(turIkon(oge.tur), color: renk, size: 20),
          ],
        ),
      ),
    );
  }
}

/// Alışkanlık için işaret kutusu ve seri.
class AliskanlikSatiri extends StatelessWidget {
  const AliskanlikSatiri({super.key, required this.durum, required this.aliskanlik, required this.gun});
  final Durum durum;
  final Aliskanlik aliskanlik;
  final DateTime gun;

  @override
  Widget build(BuildContext context) {
    final a = aliskanlik;
    final yapildi = a.yapildi(gun);
    final seri = a.seri(gun);
    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      value: yapildi,
      onChanged: (v) async {
        try {
          await Veri.aliskanlikIsaretle(durum.aid, a, gun, v == true);
        } catch (e) {
          if (context.mounted) bildir(context, hataYazisi(e));
        }
      },
      title: Text(a.baslik,
          style: TextStyle(
              decoration: yapildi ? TextDecoration.lineThrough : null,
              color: yapildi ? Renk.soluk : Renk.yazi)),
      subtitle: Text(durum.aile!.adlar(a.kisiler), style: const TextStyle(fontSize: 12.5)),
      secondary: seri > 0 ? Etiket('🔥 $seri', renk: Renk.vurgu, zemin: Renk.vurguAcik) : null,
    );
  }
}
