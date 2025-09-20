import 'package:flutter/material.dart';

class HomeModel {
  // State field(s) for TabBar widget.
  TabController? tabBarController;
  int get tabBarCurrentIndex =>
      tabBarController != null ? tabBarController!.index : 0;
  int get tabBarPreviousIndex =>
      tabBarController != null ? tabBarController!.previousIndex : 0;

  // State field(s) for RatingBar widget.
  double? ratingBarValue;

  void initState(TickerProvider vsync) {
    tabBarController = TabController(length: 2, vsync: vsync);
  }

  void dispose() {
    tabBarController?.dispose();
  }
}