import 'package:flutter/material.dart';

Widget renderWebImage({
  required String url,
  required BoxFit fit,
  required Widget Function(BuildContext) errorBuilder,
}) {
  return Image.network(
    url,
    fit: fit,
    errorBuilder: (ctx, err, stack) => errorBuilder(ctx),
  );
}
