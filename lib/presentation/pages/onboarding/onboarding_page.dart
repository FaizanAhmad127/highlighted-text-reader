import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:introduction_screen/introduction_screen.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/firebase/app_analytics.dart';
import '../../../core/utils/ui_helpers.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _introKey = GlobalKey<IntroductionScreenState>();

  List<PageViewModel> get _pages => [
        PageViewModel(
          title: "Highlight it",
          bodyWidget: const Text(
            "- Find text/phrases of which you don't know meaning in your book page.\n- Take any highlighter of any color.\n- Highlight the text of which you need to find meaning",
            textAlign: TextAlign.justify,
            style: UIHelpers.bodyTextStyle,
          ),
          image: Image.asset(
            AppConstants.onboard1Asset,
            fit: BoxFit.cover,
            width: double.infinity,
          ),
          decoration: PageDecoration(
            imageFlex: 3,
            pageColor: Colors.white,
            titleTextStyle: UIHelpers.titleTextStyle,
          ),
        ),
        PageViewModel(
          title: "Take/upload picture",
          bodyWidget: const Text(
            "- Open your phone camera or use pick image feature.\n- Take a picture or pick an image of a book page from phone gallery.\n- Finally, upload it.",
            textAlign: TextAlign.justify,
            style: UIHelpers.bodyTextStyle,
          ),
          image: Image.asset(
            AppConstants.onboard2Asset,
            fit: BoxFit.cover,
            width: double.infinity,
          ),
          decoration: const PageDecoration(
            bodyPadding: EdgeInsets.symmetric(horizontal: 5),
            imageFlex: 3,
            pageColor: Colors.white,
            titleTextStyle: UIHelpers.titleTextStyle,
          ),
        ),
        PageViewModel(
          title: "Now wait while we process the image",
          bodyWidget: const Text(
            "- Use a sharp, well-lit photo of the page.\n- You need an internet connection to find highlights and meanings.\n- If nothing is highlighted, you will not get a result.\n- For each phrase you will get a short literal meaning and how it is used in the sentence.",
            textAlign: TextAlign.justify,
            style: UIHelpers.bodyTextStyle,
          ),
          image: Image.asset(
            AppConstants.onboard3Asset,
            fit: BoxFit.fitHeight,
            width: double.infinity,
          ),
          decoration: const PageDecoration(
            imageFlex: 2,
            pageColor: Colors.white,
            titleTextStyle: UIHelpers.titleTextStyle,
          ),
        ),
      ];

  void _onDone() {
    unawaited(AppAnalytics.logOnboardingFinished(method: 'done'));
    context.go(AppConstants.homeRoute);
  }

  void _onSkip() {
    unawaited(AppAnalytics.logOnboardingFinished(method: 'skip'));
    context.go(AppConstants.homeRoute);
  }

  @override
  Widget build(BuildContext context) {
    return IntroductionScreen(
      globalBackgroundColor: Colors.grey[100],
      key: _introKey,
      pages: _pages,
      showBackButton: true,
      showNextButton: true,
      showSkipButton: true,
      back: const Icon(Icons.arrow_back),
      done: const Text("Done"),
      next: const Icon(Icons.arrow_forward),
      skip: const Text("Skip"),
      onDone: _onDone,
      onSkip: _onSkip,
    );
  }
}
