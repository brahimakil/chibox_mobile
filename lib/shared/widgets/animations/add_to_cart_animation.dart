import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class AddToCartAnimation extends StatefulWidget {
  final GlobalKey cartKey;
  final Function(GlobalKey) createOverlayEntry;

  const AddToCartAnimation({
    super.key,
    required this.cartKey,
    required this.createOverlayEntry,
  });

  @override
  State<AddToCartAnimation> createState() => AddToCartAnimationState();
}

class AddToCartAnimationState extends State<AddToCartAnimation> {
  void runAnimation(GlobalKey widgetKey, String imageUrl) {
    RenderBox? renderBox = widgetKey.currentContext?.findRenderObject() as RenderBox?;
    RenderBox? cartBox = widget.cartKey.currentContext?.findRenderObject() as RenderBox?;

    if (renderBox == null || cartBox == null) return;

    Offset startPos = renderBox.localToGlobal(Offset.zero);
    Offset endPos = cartBox.localToGlobal(Offset.zero);
    Size startSize = renderBox.size;
    Size endSize = cartBox.size;

    // Adjust end position to center of cart icon
    endPos = Offset(
      endPos.dx + endSize.width / 2 - 20, // 20 is half of flying widget size
      endPos.dy + endSize.height / 2 - 20,
    );

    OverlayEntry? entry;
    entry = OverlayEntry(
      builder: (context) {
        return _FlyingWidget(
          startPos: startPos,
          endPos: endPos,
          startSize: startSize,
          imageUrl: imageUrl,
          onComplete: () {
            entry?.remove();
          },
        );
      },
    );

    Overlay.of(context).insert(entry);
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

class _FlyingWidget extends StatefulWidget {
  final Offset startPos;
  final Offset endPos;
  final Size startSize;
  final String imageUrl;
  final VoidCallback onComplete;

  const _FlyingWidget({
    required this.startPos,
    required this.endPos,
    required this.startSize,
    required this.imageUrl,
    required this.onComplete,
  });

  @override
  State<_FlyingWidget> createState() => _FlyingWidgetState();
}

class _FlyingWidgetState extends State<_FlyingWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _xAnimation;
  late Animation<double> _yAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _xAnimation = Tween<double>(
      begin: widget.startPos.dx,
      end: widget.endPos.dx,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic));

    _yAnimation = Tween<double>(
      begin: widget.startPos.dy,
      end: widget.endPos.dy,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic));

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

    _opacityAnimation = Tween<double>(
      begin: 1.0,
      end: 0.5,
    ).animate(CurvedAnimation(parent: _controller, curve: const Interval(0.8, 1.0)));

    _controller.forward().then((_) => widget.onComplete());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Positioned(
          left: _xAnimation.value,
          top: _yAnimation.value,
          child: Opacity(
            opacity: _opacityAnimation.value,
            child: Transform.scale(
              scale: _scaleAnimation.value,
              child: Container(
                width: widget.startSize.width,
                height: widget.startSize.height,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  image: DecorationImage(
                    image: widget.imageUrl.isNotEmpty
                        ? CachedNetworkImageProvider(widget.imageUrl)
                        : const AssetImage('assets/images/productfailbackorskeleton_loading.png') as ImageProvider,
                    fit: BoxFit.cover,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
