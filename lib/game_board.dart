import 'package:flutter/material.dart';
import 'models/game_state.dart';
import 'letter_fragments.dart';

class GameBoard extends StatelessWidget {
  final GameState state;
  final Function(int row, int col) onTap;

  const GameBoard({
    super.key,
    required this.state,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final size = state.level.gridSize;
    
    return Padding(
      padding: const EdgeInsets.all(12),
      child: AspectRatio(
        aspectRatio: 1,
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: size,
            crossAxisSpacing: 4,
            mainAxisSpacing: 4,
            childAspectRatio: 1,
          ),
          itemCount: size * size,
          itemBuilder: (context, index) {
            final row = index ~/ size;
            final col = index % size;
            final fragment = state.board[row][col];
            
            return _FragmentTile(
              fragment: fragment,
              onTap: () => onTap(row, col),
            );
          },
        ),
      ),
    );
  }
}

class _FragmentTile extends StatefulWidget {
  final CellFragment fragment;
  final VoidCallback onTap;

  const _FragmentTile({
    required this.fragment,
    required this.onTap,
  });

  @override
  State<_FragmentTile> createState() => _FragmentTileState();
}

class _FragmentTileState extends State<_FragmentTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.85).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(_FragmentTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.fragment.isMatched && !oldWidget.fragment.isMatched) {
      _controller.forward().then((_) => _controller.reverse());
    }
    if (widget.fragment.isAnimating && !oldWidget.fragment.isAnimating) {
      _controller.forward().then((_) => _controller.reverse());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fragment = widget.fragment;
    final baseColor = LetterFragments.getFragmentColor(fragment.symbol);
    
    Color tileColor;
    if (fragment.isMatched) {
      tileColor = Colors.transparent;
    } else if (fragment.isSelected) {
      tileColor = baseColor.withOpacity(0.9);
    } else if (fragment.isAnimating) {
      tileColor = const Color(0xFFFF6B6B).withOpacity(0.8);
    } else {
      tileColor = baseColor.withOpacity(0.6);
    }
    
    return GestureDetector(
      onTap: fragment.isMatched ? null : widget.onTap,
      onTapDown: (_) {
        if (!fragment.isMatched) {
          _controller.forward();
        }
      },
      onTapUp: (_) {
        _controller.reverse();
      },
      onTapCancel: () {
        _controller.reverse();
      },
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: fragment.scale * _scaleAnimation.value,
            child: child,
          );
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            gradient: fragment.isMatched
                ? null
                : LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      tileColor,
                      fragment.isSelected
                          ? baseColor.withOpacity(0.7)
                          : baseColor.withOpacity(0.4),
                    ],
                  ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: fragment.isSelected
                  ? Colors.white.withOpacity(0.8)
                  : fragment.isMatched
                      ? Colors.transparent
                      : Colors.white.withOpacity(0.2),
              width: fragment.isSelected ? 2 : 1,
            ),
            boxShadow: fragment.isSelected
                ? [
                    BoxShadow(
                      color: baseColor.withOpacity(0.5),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ]
                : fragment.isMatched
                    ? null
                    : [
                        BoxShadow(
                          color: baseColor.withOpacity(0.2),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
          ),
          child: fragment.isMatched
              ? const SizedBox.shrink()
              : Center(
                  child: Text(
                    fragment.symbol,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: fragment.isSelected
                          ? Colors.white
                          : Colors.white.withOpacity(0.9),
                      shadows: [
                        Shadow(
                          color: baseColor.withOpacity(0.5),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
