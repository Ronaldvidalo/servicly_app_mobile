import 'package:flutter/material.dart';

class RatingStars extends StatelessWidget {
  final double rating;
  final int ratingCount;
  final double starSize;

  const RatingStars({
    super.key,
    required this.rating,
    required this.ratingCount,
    this.starSize = 16.0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = Colors.amber.shade700;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(
          // Si no hay rating, la estrella aparece vacía
          rating > 0 ? Icons.star_rounded : Icons.star_border_rounded,
          color: color,
          size: starSize,
        ),
        const SizedBox(width: 4),
        Text(
          rating.toStringAsFixed(1),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
            fontSize: starSize * 0.9,
          ),
        ),
        const SizedBox(width: 6),
        // Solo mostramos el número de reseñas si es mayor que cero
        if (ratingCount > 0)
          Text(
            '($ratingCount)',
            style: TextStyle(
              fontSize: starSize * 0.75,
              color: theme.textTheme.bodySmall?.color,
            ),
          ),
      ],
    );
  }
}