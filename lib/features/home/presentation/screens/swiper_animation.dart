import 'package:flutter/material.dart';
import 'package:get/get.dart';

enum AppinioSwiperState { idle, swipe, unswipe }

enum AppinioSwiperDirection { left, right }

class AppinioSwiperController extends GetxController {
  var state = AppinioSwiperState.idle.obs;
  var currentIndex = 0.obs;

  void swipe(AppinioSwiperDirection direction) {
    state.value = AppinioSwiperState.swipe;
    // Handle swipe logic and increment index
    if (direction == AppinioSwiperDirection.right) {
      currentIndex.value++;
    } else if (direction == AppinioSwiperDirection.left) {
      currentIndex.value--;
    }
  }

  void unswipe() {
    state.value = AppinioSwiperState.unswipe;
    // Handle unswiping logic and adjust currentIndex
    currentIndex.value--;
  }

  void reset() {
    state.value = AppinioSwiperState.idle;
    currentIndex.value = 0;
  }
}

class AppinioSwiper extends StatelessWidget {
  final List<Widget> cards;
  final AppinioSwiperController controller;
  final double cardHeight;
  final double cardWidth;
  final Function? onSwipe;
  final Function? onEnd;
  final bool allowUnswipe;

  AppinioSwiper({
    required this.cards,
    required this.controller,
    this.cardHeight = 400,
    this.cardWidth = 300,
    this.onSwipe,
    this.onEnd,
    this.allowUnswipe = true,
  });

  @override
  Widget build(BuildContext context) {
    return GetBuilder<AppinioSwiperController>(
      builder: (_) {
        return Stack(
          children: List.generate(cards.length, (index) {
            final double offset =
                (controller.currentIndex.value - index) * 20.0;
            final double angle = (controller.currentIndex.value - index) * 5.0;

            return Positioned(
              top: 50 + offset,
              left: (MediaQuery.of(context).size.width - cardWidth) / 2,
              child: Transform.rotate(
                angle: angle * 3.14159 / 180,
                child: GestureDetector(
                  onPanUpdate: (details) {
                    if (details.localPosition.dx > cardWidth / 2) {
                      controller.swipe(AppinioSwiperDirection.right);
                    } else {
                      controller.swipe(AppinioSwiperDirection.left);
                    }
                    if (onSwipe != null) {
                      onSwipe!(controller.currentIndex.value);
                    }
                  },
                  onPanEnd: (details) {
                    if (controller.state.value == AppinioSwiperState.swipe) {
                      if (onEnd != null) {
                        onEnd!(controller.currentIndex.value);
                      }
                    }
                  },
                  child: AnimatedContainer(
                    duration: Duration(milliseconds: 300),
                    height: cardHeight,
                    width: cardWidth,
                    child: cards[index],
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 10,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  final AppinioSwiperController swiperController =
      Get.put(AppinioSwiperController());

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: Text('Appinio Swiper'),
        ),
        body: Center(
          child: AppinioSwiper(
            cards: [
              _buildCard('Card 1'),
              _buildCard('Card 2'),
              _buildCard('Card 3'),
            ],
            controller: swiperController,
            onSwipe: (index) {
              print('Swiped on card $index');
            },
            onEnd: (index) {
              print('Swipe ended for card $index');
            },
          ),
        ),
      ),
    );
  }

  Widget _buildCard(String title) {
    return Card(
      color: Colors.blue,
      child: Center(
        child: Text(
          title,
          style: TextStyle(color: Colors.white, fontSize: 24),
        ),
      ),
    );
  }
}
