import 'package:flutter/material.dart';

import '../bicim.dart';
import '../modeller.dart';
import '../servis/veri.dart';
import '../tema.dart';
import 'ana.dart';
import 'formlar.dart';
import 'ortak.dart';

/// Tekrar eden haftalık program: her gün için zaman dilimleri.
class ProgramSayfasi extends StatelessWidget {
  const ProgramSayfasi({super.key, required this.durum});
  final Durum durum;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 7,
      initialIndex: DateTime.now().weekday - 1,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Haftalık program'),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [for (final g in gunKisa) Tab(text: g)],
          ),
        ),
        body: ListenableBuilder(
          listenable: durum,
          builder: (context, _) => TabBarView(
            children: [
              for (var g = 1; g <= 7; g++) _GunListesi(durum: durum, gun: g),
            ],
          ),
        ),
      ),
    );
  }
}

class _GunListesi extends StatelessWidget {
  const _GunListesi({required this.durum, required this.gun});
  final Durum durum;
  final int gun;

  @override
  Widget build(BuildContext context) {
    final l = durum.program.where((o) => o.gun == gun).toList();
    final tur = <String, int>{};
    for (final o in l) {
      tur[o.tur] = (tur[o.tur] ?? 0) + o.sure;
    }
    final toplam = tur.values.fold(0, (a, b) => a + b);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        if (l.isNotEmpty)
          Panel(
            baslik: '${gunAdlari[gun - 1]} · ${sureYaz(toplam)} planlı',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    height: 14,
                    child: Row(
                      children: [
                        for (final e in tur.entries.where((x) => x.value > 0))
                          Expanded(flex: e.value, child: Container(color: turRenk(e.key))),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    for (final e in tur.entries)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(width: 10, height: 10, color: turRenk(e.key)),
                          const SizedBox(width: 4),
                          Text('${ProgramOgesi.turler[e.key]} ${sureYaz(e.value)}',
                              style: const TextStyle(fontSize: 12.5, color: Renk.soluk)),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
        Panel(
          baslik: 'Akış',
          sag: TextButton.icon(
            onPressed: () => ac(context, ProgramFormu(durum: durum, gun: gun)),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Ekle'),
          ),
          child: l.isEmpty
              ? const BosDurum(
                  ikon: Icons.calendar_view_week,
                  yazi: 'Bu gün boş. İş, tarla, aile, eşinle ve kendine ayırdığın saatleri ekle; '
                      'koç dengeyi buna göre hesaplar.')
              : Column(children: [for (final o in l) ProgramSatiri(durum: durum, oge: o)]),
        ),
      ],
    );
  }
}
