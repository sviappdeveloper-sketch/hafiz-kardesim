import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import '../l10n/l10n.dart';
import 'format.dart';

/// Reklam görseli en fazla bu boyutta saklanır (Firestore belge sınırı 1 MB).
const maxAdImageBytes = 700 * 1024;

/// Galeriden resim ya da GIF seçtirir; ham baytları ve GIF olup olmadığını döner.
/// GIF hareketli kalsın diye kırpılmaz, 700 KB'ı geçemez. Seçilmezse null.
Future<(Uint8List, bool)?> pickAdImageRaw() async {
  final x = await ImagePicker().pickImage(source: ImageSource.gallery, requestFullMetadata: false);
  if (x == null) return null;
  final bytes = await x.readAsBytes();
  final isGif = bytes.length > 3 && bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46;
  if (isGif && bytes.length > maxAdImageBytes) {
    throw HatimException(lt('GIF en fazla 700 KB olabilir. Daha küçük bir GIF seçin.'));
  }
  return (bytes, isGif);
}

/// Seçilen alanı (görselin piksel koordinatlarında) kesip JPEG'e çevirir.
Future<Uint8List> cropAdImage(Uint8List bytes, Rect area) async {
  final out = await compute(_crop, (bytes, area.left, area.top, area.width, area.height));
  if (out == null) throw HatimException(lt('Bu görsel açılamadı. Başka bir resim seçin.'));
  return out;
}

Uint8List? _crop((Uint8List, double, double, double, double) a) {
  final decoded = img.decodeImage(a.$1);
  if (decoded == null) return null;
  final src = img.bakeOrientation(decoded);
  final x = a.$2.round().clamp(0, src.width - 1);
  final y = a.$3.round().clamp(0, src.height - 1);
  final w = a.$4.round().clamp(1, src.width - x);
  final h = a.$5.round().clamp(1, src.height - y);
  var im = img.copyCrop(src, x: x, y: y, width: w, height: h);
  if (im.width > 1280) im = img.copyResize(im, width: 1280);
  var q = 85;
  var out = img.encodeJpg(im, quality: q);
  while (out.length > maxAdImageBytes && q > 45) {
    q -= 10;
    out = img.encodeJpg(im, quality: q);
  }
  while (out.length > maxAdImageBytes && im.width > 480) {
    im = img.copyResize(im, width: (im.width * 0.75).round());
    out = img.encodeJpg(im, quality: 70);
  }
  return out.length > maxAdImageBytes ? null : Uint8List.fromList(out);
}
