import 'package:flutter/material.dart';

import '../bicim.dart';
import '../modeller.dart';
import '../tema.dart';

/// Ailedeki kişilerden birkaçını seçtirir. Hiçbiri seçilmezse "Herkes".
class KisiSecici extends StatelessWidget {
  const KisiSecici({
    super.key,
    required this.aile,
    required this.secili,
    required this.degisti,
    this.tek = false,
    this.herkesYazisi = 'Herkes',
  });

  final Aile aile;
  final List<String> secili;
  final ValueChanged<List<String>> degisti;
  final bool tek;
  final String herkesYazisi;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (!tek)
          ChoiceChip(
            label: Text(herkesYazisi),
            selected: secili.isEmpty,
            onSelected: (_) => degisti(const []),
          ),
        for (final k in aile.kisiler)
          FilterChip(
            avatar: Text(k.emoji),
            label: Text(k.ad),
            selected: secili.contains(k.id),
            onSelected: (v) {
              if (tek) {
                degisti([k.id]);
                return;
              }
              final l = [...secili];
              if (v) {
                l.add(k.id);
              } else {
                l.remove(k.id);
              }
              degisti(l);
            },
          ),
      ],
    );
  }
}

/// Haftanın günlerini seçtirir. Boş: her gün.
class GunSecici extends StatelessWidget {
  const GunSecici({super.key, required this.secili, required this.degisti, this.hepsiYazisi = 'Her gün'});
  final List<int> secili;
  final ValueChanged<List<int>> degisti;
  final String hepsiYazisi;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        ChoiceChip(
          label: Text(hepsiYazisi),
          selected: secili.isEmpty,
          onSelected: (_) => degisti(const []),
        ),
        for (var g = 1; g <= 7; g++)
          FilterChip(
            label: Text(gunKisa[g - 1]),
            selected: secili.contains(g),
            onSelected: (v) {
              final l = [...secili];
              if (v) {
                l.add(g);
              } else {
                l.remove(g);
              }
              l.sort();
              degisti(l.length == 7 ? const [] : l);
            },
          ),
      ],
    );
  }
}

Color turRenk(String tur) => switch (tur) {
      'is' => Renk.mavi,
      'tarla' => const Color(0xFF65A30D),
      'aile' => Renk.ana,
      'cocuklar' => Renk.vurgu,
      'es' => const Color(0xFFDB2777),
      'kendim' => Renk.mor,
      _ => Renk.gri,
    };

IconData turIkon(String tur) => switch (tur) {
      'is' => Icons.work_outline,
      'tarla' => Icons.agriculture,
      'aile' => Icons.family_restroom,
      'cocuklar' => Icons.child_care,
      'es' => Icons.favorite_border,
      'kendim' => Icons.self_improvement,
      _ => Icons.event_note,
    };

/// Bir form sayfasının iskeleti: başlık, kaydet düğmesi, kaydırılabilir içerik.
class FormSayfa extends StatefulWidget {
  const FormSayfa({
    super.key,
    required this.baslik,
    required this.children,
    required this.kaydet,
    this.sil,
  });

  final String baslik;
  final List<Widget> children;

  /// Hata varsa açıklamasını döndürür ya da atar.
  final Future<String?> Function() kaydet;
  final Future<void> Function()? sil;

  @override
  State<FormSayfa> createState() => _FormSayfaState();
}

class _FormSayfaState extends State<FormSayfa> {
  bool _mesgul = false;

  Future<void> _kaydet() async {
    setState(() => _mesgul = true);
    try {
      final hata = await widget.kaydet();
      if (!mounted) return;
      if (hata != null) {
        bildir(context, hata);
      } else {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) bildir(context, hataYazisi(e));
    } finally {
      if (mounted) setState(() => _mesgul = false);
    }
  }

  Future<void> _sil() async {
    if (!await onayla(context, 'Silinsin mi?', 'Bu kayıt herkes için silinecek.')) return;
    setState(() => _mesgul = true);
    try {
      await widget.sil!();
      if (mounted) Navigator.of(context).pop(true);
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
        title: Text(widget.baslik),
        actions: [
          if (widget.sil != null)
            IconButton(
                tooltip: 'Sil',
                onPressed: _mesgul ? null : _sil,
                icon: const Icon(Icons.delete_outline)),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            ...widget.children,
            const SizedBox(height: 8),
            Buton(yazi: 'Kaydet', ikon: Icons.check, mesgul: _mesgul, onTap: _kaydet),
          ],
        ),
      ),
    );
  }
}

/// Form içindeki küçük başlık.
class Alan extends StatelessWidget {
  const Alan(this.baslik, this.child, {super.key});
  final String baslik;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(baslik,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, color: Renk.soluk, fontSize: 13.5)),
            const SizedBox(height: 8),
            child,
          ],
        ),
      );
}

Future<T?> ac<T>(BuildContext context, Widget sayfa) =>
    Navigator.of(context).push<T>(MaterialPageRoute(builder: (_) => sayfa));

/// Tutar sorar (ör. plan yapıldı → ne kadar harcandı).
Future<double?> tutarSor(BuildContext context, String baslik,
    {String aciklama = '', double? varsayilan, bool bosOlur = true}) async {
  final c = TextEditingController(
      text: varsayilan == null || varsayilan == 0 ? '' : sayi(varsayilan));
  final r = await showDialog<double>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(baslik),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (aciklama.isNotEmpty) ...[
            Text(aciklama, style: const TextStyle(color: Renk.soluk)),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: c,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(suffixText: '₺', hintText: '0'),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Vazgeç')),
        FilledButton(
          onPressed: () {
            final v = sayiOku(c.text);
            if (v == null && !bosOlur) return;
            Navigator.pop(ctx, v ?? 0);
          },
          child: const Text('Tamam'),
        ),
      ],
    ),
  );
  return r;
}
