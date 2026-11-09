import 'dart:convert';
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

final Set<String> _registeredViews = {};

Widget renderWebImage({
  required String url,
  required BoxFit fit,
  required Widget Function(BuildContext) errorBuilder,
}) {
  final cleanUrl = url.trim();
  final fitKey = fit == BoxFit.cover ? 'cov' : (fit == BoxFit.contain ? 'con' : 'fill');
  final hash = base64Url.encode(utf8.encode('$cleanUrl-$fitKey')).replaceAll('=', '');
  final viewType = 'stone-img-$hash';

  if (!_registeredViews.contains(viewType)) {
    _registeredViews.add(viewType);
    ui_web.platformViewRegistry.registerViewFactory(
      viewType,
      (int viewId) {
        final img = web.document.createElement('img') as web.HTMLImageElement;
        img.src = cleanUrl;
        img.style.width = '100%';
        img.style.height = '100%';
        img.style.objectFit = fit == BoxFit.cover
            ? 'cover'
            : (fit == BoxFit.contain ? 'contain' : 'fill');
        img.style.display = 'block';
        img.style.pointerEvents = 'none';
        img.style.userSelect = 'none';
        img.loading = 'eager';
        // Suppress referer so external hosts (vitalygroup.co) do not block hotlinking from GitHub Pages
        img.referrerPolicy = 'no-referrer';
        return img;
      },
    );
  }

  return HtmlElementView(viewType: viewType);
}
