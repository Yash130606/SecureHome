import 'dart:async';
import 'package:flutter/material.dart';
import '../services/pi_service.dart';

class PiThumbnail extends StatefulWidget {
  final double width;
  final double height;
  final BorderRadius? borderRadius;
  final bool enabled;
  final Widget? placeholder;

  const PiThumbnail({
    super.key,
    this.width = double.infinity,
    this.height = 110,
    this.borderRadius,
    this.enabled = true,
    this.placeholder,
  });

  @override
  State<PiThumbnail> createState() => _PiThumbnailState();
}

class _PiThumbnailState extends State<PiThumbnail> {
  Timer? _timer;
  String _url = '';

  @override
  void initState() {
    super.initState();
    if (widget.enabled) {
      _refresh();
      _timer = Timer.periodic(const Duration(seconds: 3), (_) => _refresh());
    }
  }

  void _refresh() {
    if (!mounted) return;
    setState(() {
      // Cache-bust so Flutter re-fetches the image
      _url =
          '${PiService.thumbnailUrl}?t=${DateTime.now().millisecondsSinceEpoch}';
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final radius = widget.borderRadius ?? BorderRadius.circular(0);

    if (!widget.enabled || _url.isEmpty) {
      return _placeholder(radius);
    }

    return ClipRRect(
      borderRadius: radius,
      child: Image.network(
        _url,
        width: widget.width,
        height: widget.height,
        fit: BoxFit.cover,
        gaplessPlayback: true, // no flicker on refresh
        loadingBuilder: (_, child, progress) {
          if (progress == null) return child;
          return _placeholder(radius);
        },
        errorBuilder: (_, __, ___) => _placeholder(radius),
      ),
    );
  }

  Widget _placeholder(BorderRadius radius) {
    if (widget.placeholder != null) {
      return ClipRRect(
        borderRadius: radius,
        child: SizedBox(
          width: widget.width,
          height: widget.height,
          child: widget.placeholder,
        ),
      );
    }

    return ClipRRect(
      borderRadius: radius,
      child: Container(
        width: widget.width,
        height: widget.height,
        color: const Color(0xFF0A0A1A),
        child: const Center(
          child: Icon(Icons.videocam_outlined, color: Colors.white24, size: 28),
        ),
      ),
    );
  }
}
