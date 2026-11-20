import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme/app_theme.dart';
import '../utils/ad_image.dart';
import '../utils/format.dart';
import '../widgets/ornaments.dart';

/// Reklam görselini kırpma: görsel iki parmakla büyütülüp küçültülür, sürüklenir;
/// çerçevenin içinde kalan alan reklamda görünür. Kırpılan JPEG döner.
class AdCropScreen extends StatefulWidget {
  const AdCropScreen({super.key, required this.bytes});
  final Uint8List bytes;

  @override
  State<AdCropScreen> createState() => _AdCropScreenState();
}

class _AdCropScreenState extends State<AdCropScreen> {
  static const _ratio = 16 / 9;
  final _tc = TransformationController();
  ui.Image? _img;
  bool _busy = false;
  double _childW = 0, _childH = 0, _frameW = 0, _frameH = 0;
  bool _placed = false;

  @override
  void initState() {
    super.initState();
    decodeImageFromList(widget.bytes).then((im) {
      if (mounted) setState(() => _img = im);
    }).catchError((_) {
      if (mounted) {
        showSnack(context, lt('Bu görsel açılamadı. Başka bir resim seçin.'));
        Navigator.pop(context);
      }
    });
  }

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  Future<void> _use() async {
    final im = _img;
    if (im == null) return;
    setState(() => _busy = true);
    final m = _tc.value;
    final scale = m.getMaxScaleOnAxis();
    final t = m.getTranslation();
    final f = im.width / _childW; // ekran → piksel
    final area = Rect.fromLTWH((-t.x / scale) * f, (-t.y / scale) * f, (_frameW / scale) * f, (_frameH / scale) * f);
    try {
      final out = await cropAdImage(widget.bytes, area);
      if (mounted) Navigator.pop(context, out);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showSnack(context, errorText(e));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final im = _img;
    return Scaffold(
      appBar: AppBar(title: Text(lt('Görseli yerleştirin'))),
      body: PatternBackground(
        child: im == null
            ? const LoadingView()
            : LayoutBuilder(builder: (context, c) {
                _frameW = c.maxWidth - 32;
                _frameH = _frameW / _ratio;
                final r = [_frameW / im.width, _frameH / im.height].reduce((a, b) => a > b ? a : b);
                _childW = im.width * r;
                _childH = im.height * r;
                if (!_placed) {
                  _placed = true;
                  _tc.value = Matrix4.identity()
                    ..translate(-(_childW - _frameW) / 2, -(_childH - _frameH) / 2);
                }
                return ListView(padding: const EdgeInsets.all(16), children: [
                  Text(lt('İki parmakla büyütüp küçültün, sürükleyerek kaydırın. Çerçevenin içinde kalan kısım tanıtımda görünür.'),
                      style: AppText.body(14, color: AppColors.muted)),
                  const SizedBox(height: 14),
                  Container(
                    width: _frameW,
                    height: _frameH,
                    decoration: BoxDecoration(border: Border.all(color: AppColors.goldLight, width: 2)),
                    child: ClipRect(
                      child: InteractiveViewer(
                        transformationController: _tc,
                        constrained: false,
                        minScale: 1,
                        maxScale: 6,
                        boundaryMargin: EdgeInsets.zero,
                        child: SizedBox(
                          width: _childW,
                          height: _childH,
                          child: Image.memory(widget.bytes, fit: BoxFit.fill, gaplessPlayback: true),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  GoldButton(label: lt('Bu alanı kullan'), icon: Icons.crop, busy: _busy, onPressed: _use),
                ]);
              }),
      ),
    );
  }
}
