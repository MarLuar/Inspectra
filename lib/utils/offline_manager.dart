import 'package:flutter/material.dart';

class OfflineManager extends ChangeNotifier {
  bool _isOffline = false;
  
  bool get isOffline => _isOffline;
  
  void checkConnectivity() async {
    // In a real implementation, we would use connectivity_plus package
    // For now, we'll assume the app is always in offline mode for this demo
    _isOffline = true;
    notifyListeners();
  }
  
  void refreshConnectivity() {
    checkConnectivity();
  }
}

class OfflineAwareWidget extends StatelessWidget {
  final Widget child;
  
  const OfflineAwareWidget({Key? key, required this.child}) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Ensure all data is saved before navigating away
        return true;
      },
      child: child,
    );
  }
}