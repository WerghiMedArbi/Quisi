import 'package:flutter/material.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:go_router/go_router.dart';
import 'dart:typed_data';
import '../utils/app_background.dart';

class ScanQRScreen extends StatefulWidget {
  @override
  _ScanQRScreenState createState() => _ScanQRScreenState();
}

class _ScanQRScreenState extends State<ScanQRScreen> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? controller;
  bool _isProcessing = false;

  void _onQRViewCreated(QRViewController controller) {
    this.controller = controller;
    controller.scannedDataStream.listen((scanData) {
      if (!_isProcessing && scanData.code != null) {
        _isProcessing = true;
        context.go('/nickname-entry/${scanData.code}');
      }
    });
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBackground.buildAppBar(title: "Scan QR Code"),
      body: AppBackground.buildBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  "Position the QR code within the frame to join the session",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16.0,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ),
              Expanded(
                flex: 5,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16.0),
                    child: QRView(
                      key: qrKey,
                      onQRViewCreated: _onQRViewCreated,
                      overlay: QrScannerOverlayShape(
                        borderColor: Colors.white,
                        borderRadius: 16.0,
                        borderLength: 30.0,
                        borderWidth: 10.0,
                        cutOutSize: MediaQuery.of(context).size.width * 0.7,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 1,
                child: Center(
                  child: ElevatedButton(
                    onPressed: () => context.go('/manual-code'),
                    style: AppBackground.primaryButtonStyle(width: 200),
                    child: Text(
                      "Enter Code Manually",
                      style: TextStyle(fontSize: 16.0),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Add this method to handle image loading with fallback
  ImageProvider _buildBackgroundImage() {
    try {
      return AssetImage('assets/images/bg.png');
    } catch (e) {
      print('Failed to load background image: $e');
      // Return a transparent image as fallback
      return MemoryImage(Uint8List.fromList([0, 0, 0, 0]));
    }
  }
}