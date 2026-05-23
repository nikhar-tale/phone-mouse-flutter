// lib/main.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MousePadApp());
}

class MousePadApp extends StatelessWidget {
  const MousePadApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Phone Mouse WS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A), // Slate 900
        primaryColor: const Color(0xFF6366F1), // Indigo
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF6366F1),
          secondary: Color(0xFF06B6D4), // Teal
          surface: Color(0xFF1E293B), // Slate 800
        ),
      ),
      home: const StartupScreen(),
    );
  }
}

class StartupScreen extends StatefulWidget {
  const StartupScreen({super.key});

  @override
  State<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<StartupScreen> {
  final TextEditingController _ipController = TextEditingController();
  final TextEditingController _portController = TextEditingController(
    text: '8000',
  );
  bool _connecting = false;
  bool _isScanning = false;
  String _scanStatus = '';
  RawDatagramSocket? _udpSocket;

  @override
  void initState() {
    super.initState();
    _loadSavedSettings();
    _startAutoDiscovery();
  }

  @override
  void dispose() {
    _udpSocket?.close();
    _ipController.dispose();
    _portController.dispose();
    super.dispose();
  }

  void _loadSavedSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedIp = prefs.getString('saved_ip') ?? '';
      final savedPort = prefs.getString('saved_port') ?? '8000';
      if (mounted) {
        setState(() {
          if (savedIp.isNotEmpty) {
            _ipController.text = savedIp;
          }
          _portController.text = savedPort;
        });
      }
    } catch (e) {
      debugPrint("Error loading settings: $e");
    }
  }

  void _saveSettings(String ip, String port) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('saved_ip', ip);
      await prefs.setString('saved_port', port);
    } catch (e) {
      debugPrint("Error saving settings: $e");
    }
  }

  void _startAutoDiscovery() async {
    if (_isScanning) return;
    setState(() {
      _isScanning = true;
      _scanStatus = 'Searching for PC on local network...';
    });

    try {
      _udpSocket?.close();
      _udpSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      _udpSocket!.broadcastEnabled = true;

      // Send request
      _udpSocket!.send(
        utf8.encode("DISCOVER_PHONE_MOUSE_REQUEST"),
        InternetAddress("255.255.255.255"),
        8002,
      );

      // Listen for response
      _udpSocket!.listen((event) {
        if (event == RawSocketEvent.read) {
          final dg = _udpSocket!.receive();
          if (dg != null) {
            final message = utf8.decode(dg.data);
            if (message.startsWith("DISCOVER_PHONE_MOUSE_RESPONSE:")) {
              final parts = message.split(":");
              final serverPort = parts.length > 1 ? parts[1] : '8000';
              final serverIp = dg.address.address;

              if (mounted) {
                setState(() {
                  _ipController.text = serverIp;
                  _portController.text = serverPort;
                  _isScanning = false;
                  _scanStatus = 'PC found at $serverIp:$serverPort!';
                });

                _udpSocket?.close();
                _udpSocket = null;

                // Auto connect
                _connect();
              }
            }
          }
        }
      });

      // Timeout discovery after 3 seconds
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && _isScanning) {
          setState(() {
            _isScanning = false;
            _scanStatus = 'Auto-discovery timed out. Enter IP manually.';
          });
          _udpSocket?.close();
          _udpSocket = null;
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isScanning = false;
          _scanStatus = 'Scan error: $e';
        });
      }
    }
  }

  void _connect() {
    final ip = _ipController.text.trim();
    final port = _portController.text.trim();
    if (ip.isEmpty || port.isEmpty) return;

    _saveSettings(ip, port);

    setState(() => _connecting = true);

    // Navigate to touchpad screen with IP and Port
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => TouchpadScreen(ip: ip, port: port),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // App logo & name
                  Center(
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6366F1), Color(0xFF06B6D4)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0x4D6366F1),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.mouse_rounded,
                        color: Colors.white,
                        size: 36,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Center(
                    child: Text(
                      'Phone Mouse',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                  const Center(
                    child: Text(
                      'Wireless Touchpad Controller',
                      style: TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Connection card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: const Color(0xFF334155),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Connect to PC',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        if (_scanStatus.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _isScanning
                                  ? const Color(0x1A6366F1)
                                  : (_scanStatus.contains('found')
                                        ? const Color(0x1A10B981)
                                        : const Color(0x1AEF4444)),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _isScanning
                                    ? const Color(0x4D6366F1)
                                    : (_scanStatus.contains('found')
                                          ? const Color(0x4D10B981)
                                          : const Color(0x4DEF4444)),
                              ),
                            ),
                            child: Row(
                              children: [
                                if (_isScanning) ...[
                                  const RadarScanner(),
                                  const SizedBox(width: 12),
                                ] else ...[
                                  Icon(
                                    _scanStatus.contains('found')
                                        ? Icons.check_circle_rounded
                                        : Icons.warning_rounded,
                                    color: _scanStatus.contains('found')
                                        ? const Color(0xFF10B981)
                                        : const Color(0xFFF59E0B),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                ],
                                Expanded(
                                  child: Text(
                                    _scanStatus,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: _isScanning
                                          ? const Color(0xFFC7D2FE)
                                          : (_scanStatus.contains('found')
                                                ? const Color(0xFFA7F3D0)
                                                : const Color(0xFFFDE68A)),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        TextField(
                          controller: _ipController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          style: const TextStyle(
                            color: Colors.white,
                            fontFamily: 'monospace',
                            fontSize: 15,
                            letterSpacing: 1.1,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Windows IP Address',
                            labelStyle: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 13,
                            ),
                            prefixIcon: const Icon(
                              Icons.lan_outlined,
                              color: Color(0xFF94A3B8),
                            ),
                            filled: true,
                            fillColor: const Color(0xFF0F172A),
                            focusedBorder: OutlineInputBorder(
                              borderSide: const BorderSide(
                                color: Color(0xFF6366F1),
                                width: 1.5,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderSide: const BorderSide(
                                color: Color(0xFF334155),
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _portController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(
                            color: Colors.white,
                            fontFamily: 'monospace',
                            fontSize: 15,
                            letterSpacing: 1.1,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Port',
                            labelStyle: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 13,
                            ),
                            prefixIcon: const Icon(
                              Icons.settings_ethernet_rounded,
                              color: Color(0xFF94A3B8),
                            ),
                            filled: true,
                            fillColor: const Color(0xFF0F172A),
                            focusedBorder: OutlineInputBorder(
                              borderSide: const BorderSide(
                                color: Color(0xFF6366F1),
                                width: 1.5,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderSide: const BorderSide(
                                color: Color(0xFF334155),
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: OutlinedButton.icon(
                                onPressed: _isScanning || _connecting
                                    ? null
                                    : _startAutoDiscovery,
                                icon: _isScanning
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Color(0xFF6366F1),
                                              ),
                                        ),
                                      )
                                    : const Icon(
                                        Icons.refresh_rounded,
                                        size: 18,
                                      ),
                                label: Text(_isScanning ? 'Scanning' : 'Scan'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF6366F1),
                                  side: const BorderSide(
                                    color: Color(0xFF334155),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 3,
                              child: ElevatedButton(
                                onPressed: _connecting ? null : _connect,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF6366F1),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 0,
                                ),
                                child: _connecting
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
                                        ),
                                      )
                                    : const Text(
                                        'Connect',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
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

class RadarScanner extends StatefulWidget {
  final double size;
  const RadarScanner({super.key, this.size = 20});

  @override
  State<RadarScanner> createState() => _RadarScannerState();
}

class _RadarScannerState extends State<RadarScanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(painter: RadarPainter(_controller.value));
        },
      ),
    );
  }
}

class RadarPainter extends CustomPainter {
  final double progress;
  RadarPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    final paintCircle = Paint()
      ..color = const Color(0xFF6366F1).withValues(alpha: 1.0 - progress)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawCircle(center, maxRadius * progress, paintCircle);

    final paintCenter = Paint()
      ..color = const Color(0xFF6366F1)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, 4.0, paintCenter);

    if (progress > 0.5) {
      final paintCircle2 = Paint()
        ..color = const Color(
          0xFF6366F1,
        ).withValues(alpha: 1.0 - (progress - 0.5) * 2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawCircle(center, maxRadius * (progress - 0.5), paintCircle2);
    }
  }

  @override
  bool shouldRepaint(covariant RadarPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class TouchpadScreen extends StatefulWidget {
  final String ip;
  final String port;
  const TouchpadScreen({super.key, required this.ip, required this.port});

  @override
  State<TouchpadScreen> createState() => _TouchpadScreenState();
}

class _TouchpadScreenState extends State<TouchpadScreen> {
  IOWebSocketChannel? _channel;
  bool _connected = false;

  double sensitivity = 1.2;
  double _accDx = 0;
  double _accDy = 0;
  Timer? _sendTimer;

  final Set<int> _activePointers = {};
  Offset? _pointerDownPosition;
  DateTime? _pointerDownTime;
  bool _hasMovedPastThreshold = false;
  Timer? _longPressTimer;
  bool _isLongPressing = false;

  bool _showSensitivity = false;
  final ValueNotifier<Offset?> _touchPositionNotifier = ValueNotifier<Offset?>(
    null,
  );

  final TextEditingController _keyboardController = TextEditingController(
    text: " ",
  );
  final FocusNode _keyboardFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _connect();
    _keyboardFocusNode.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _longPressTimer?.cancel();
    _touchPositionNotifier.dispose();
    _keyboardController.dispose();
    _keyboardFocusNode.dispose();
    _disconnect();
    super.dispose();
  }

  void _sendKeyboardKey(String key) {
    if (_channel == null || !_connected) return;
    _channel!.sink.add(jsonEncode({'type': 'keyboard', 'key': key}));
  }

  void _toggleKeyboard() {
    HapticFeedback.lightImpact();
    if (_keyboardFocusNode.hasFocus) {
      _keyboardFocusNode.unfocus();
    } else {
      _keyboardFocusNode.requestFocus();
    }
  }

  void _connect() {
    final uri = 'ws://${widget.ip}:${widget.port}/ws';
    try {
      _channel = IOWebSocketChannel.connect(Uri.parse(uri));
      _channel!.stream.listen(
        (message) {},
        onDone: () {
          setState(() => _connected = false);
          _stopSender();
        },
        onError: (e) {
          setState(() => _connected = false);
          _stopSender();
        },
      );
      setState(() => _connected = true);
      _startSender();
    } catch (e) {
      setState(() => _connected = false);
    }
  }

  void _disconnect() {
    _channel?.sink.close(status.goingAway);
    _channel = null;
    _connected = false;
    _stopSender();
  }

  void _startSender() {
    _sendTimer?.cancel();
    _sendTimer = Timer.periodic(const Duration(milliseconds: 16), (t) {
      if (_accDx.abs() < 0.01 && _accDy.abs() < 0.01) return;
      _sendMove(_accDx, _accDy);
      _accDx = 0;
      _accDy = 0;
    });
  }

  void _stopSender() {
    _sendTimer?.cancel();
    _sendTimer = null;
  }

  void _queueDelta(double dx, double dy) {
    if (dx.abs() < 0.3 && dy.abs() < 0.3) return;
    _accDx += dx * sensitivity;
    _accDy += dy * sensitivity;
  }

  void _sendMove(double dx, double dy) {
    if (_channel == null || !_connected) return;
    _channel!.sink.add(jsonEncode({'type': 'move', 'dx': dx, 'dy': dy}));
  }

  void _sendClick(String button, bool down) {
    if (_channel == null || !_connected) return;
    _channel!.sink.add(
      jsonEncode({'type': 'click', 'button': button, 'down': down}),
    );
  }

  void _sendScroll(int amount) {
    if (_channel == null || !_connected) return;
    _channel!.sink.add(jsonEncode({'type': 'scroll', 'amount': amount}));
  }

  void _handlePointerDown(PointerDownEvent event) {
    _activePointers.add(event.pointer);
    _touchPositionNotifier.value = event.localPosition;
    if (_activePointers.length == 1) {
      _pointerDownPosition = event.position;
      _pointerDownTime = DateTime.now();
      _hasMovedPastThreshold = false;
      _longPressTimer?.cancel();
      _longPressTimer = Timer(const Duration(milliseconds: 500), () {
        if (!_hasMovedPastThreshold && !_isLongPressing) {
          HapticFeedback.mediumImpact();
          setState(() {
            _isLongPressing = true;
          });
          _sendClick('left', true);
        }
      });
    } else {
      _longPressTimer?.cancel();
      if (_isLongPressing) {
        setState(() {
          _isLongPressing = false;
        });
        _sendClick('left', false);
      }
    }
  }

  void _handlePointerMove(PointerMoveEvent event) {
    _touchPositionNotifier.value = event.localPosition;
    if (_pointerDownPosition != null) {
      final distance = (event.position - _pointerDownPosition!).distance;
      if (distance > 10.0) {
        _hasMovedPastThreshold = true;
        _longPressTimer?.cancel();
      }
    }
  }

  void _handlePointerUp(PointerUpEvent event) {
    _activePointers.remove(event.pointer);
    _touchPositionNotifier.value = null;
    _longPressTimer?.cancel();

    if (_activePointers.isEmpty) {
      if (_isLongPressing) {
        setState(() {
          _isLongPressing = false;
        });
        _sendClick('left', false);
      } else {
        if (_pointerDownTime != null && !_hasMovedPastThreshold) {
          final duration = DateTime.now().difference(_pointerDownTime!);
          if (duration.inMilliseconds < 300) {
            _tapClick('left');
          }
        }
      }
      _pointerDownPosition = null;
      _pointerDownTime = null;
    } else {
      if (_isLongPressing) {
        setState(() {
          _isLongPressing = false;
        });
        _sendClick('left', false);
      }
    }
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    _activePointers.remove(event.pointer);
    _touchPositionNotifier.value = null;
    _longPressTimer?.cancel();
    if (_isLongPressing) {
      setState(() {
        _isLongPressing = false;
      });
      _sendClick('left', false);
    }
  }

  void _tapClick(String button) {
    HapticFeedback.lightImpact();
    _sendClick(button, true);
    Future.delayed(
      const Duration(milliseconds: 40),
      () => _sendClick(button, false),
    );
  }

  Widget _buildHeaderPanel() {
    return Container(
      margin: const EdgeInsets.only(top: 16, left: 16, right: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155), width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _connected
                      ? const Color(0xFF10B981)
                      : const Color(0xFFF59E0B),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _connected ? 'Connected to ${widget.ip}' : 'Reconnecting...',
                style: const TextStyle(
                  color: Color(0xFFF8FAFC),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(
                  Icons.tune_rounded,
                  color: _showSensitivity
                      ? const Color(0xFF6366F1)
                      : const Color(0xFF94A3B8),
                  size: 20,
                ),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  setState(() {
                    _showSensitivity = !_showSensitivity;
                  });
                },
              ),
              IconButton(
                icon: const Icon(
                  Icons.power_settings_new_rounded,
                  color: Colors.redAccent,
                  size: 20,
                ),
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  _disconnect();
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const StartupScreen()),
                  );
                },
              ),
            ],
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: _showSensitivity
                ? Padding(
                    padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
                    child: Row(
                      children: [
                        const Text(
                          "Sensitivity",
                          style: TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 12,
                          ),
                        ),
                        Expanded(
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: const Color(0xFF6366F1),
                              inactiveTrackColor: const Color(0xFF334155),
                              thumbColor: const Color(0xFF6366F1),
                              overlayColor: const Color(0x336366F1),
                              valueIndicatorColor: const Color(0xFF6366F1),
                              valueIndicatorTextStyle: const TextStyle(
                                color: Colors.white,
                              ),
                            ),
                            child: Slider(
                              value: sensitivity,
                              min: 0.5,
                              max: 3.0,
                              divisions: 25,
                              label: sensitivity.toStringAsFixed(1),
                              onChanged: (val) {
                                setState(() {
                                  sensitivity = val;
                                });
                              },
                            ),
                          ),
                        ),
                        Text(
                          sensitivity.toStringAsFixed(1),
                          style: const TextStyle(
                            color: Color(0xFFF8FAFC),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildLandscapeHeaderPanel() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _connected
                      ? const Color(0xFF10B981)
                      : const Color(0xFFF59E0B),
                ),
              ),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Connected',
                  style: TextStyle(
                    color: Color(0xFFF8FAFC),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  _disconnect();
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const StartupScreen()),
                  );
                },
                child: const Icon(
                  Icons.power_settings_new_rounded,
                  color: Colors.redAccent,
                  size: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            widget.ip,
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10),
            overflow: TextOverflow.ellipsis,
          ),
          const Divider(color: Color(0xFF334155), height: 16),
          const Text(
            "SENSITIVITY",
            style: TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
          Row(
            children: [
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: const Color(0xFF6366F1),
                    inactiveTrackColor: const Color(0xFF334155),
                    thumbColor: const Color(0xFF6366F1),
                    trackHeight: 2,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 6,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 12,
                    ),
                  ),
                  child: Slider(
                    value: sensitivity,
                    min: 0.5,
                    max: 3.0,
                    divisions: 25,
                    onChanged: (val) {
                      setState(() {
                        sensitivity = val;
                      });
                    },
                  ),
                ),
              ),
              Text(
                sensitivity.toStringAsFixed(1),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKeyboardMiddleButton({required bool isLandscape}) {
    final bool isActive = _keyboardFocusNode.hasFocus;
    return GestureDetector(
      onTap: _toggleKeyboard,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 60),
        width: isLandscape ? double.infinity : 64,
        height: isLandscape ? 50 : 70,
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF334155) : const Color(0xFF1E293B),
          border: Border(
            top: const BorderSide(color: Color(0xFF334155), width: 1.5),
            left: !isLandscape
                ? const BorderSide(color: Color(0xFF334155), width: 0.75)
                : BorderSide.none,
            right: !isLandscape
                ? const BorderSide(color: Color(0xFF334155), width: 0.75)
                : BorderSide.none,
            bottom: isLandscape
                ? const BorderSide(color: Color(0xFF334155), width: 0.75)
                : BorderSide.none,
          ),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.keyboard_rounded,
              color: isActive
                  ? const Color(0xFF6366F1)
                  : const Color(0xFF94A3B8),
              size: 20,
            ),
            const SizedBox(height: 4),
            Text(
              'KEY',
              style: TextStyle(
                color: isActive
                    ? const Color(0xFFF8FAFC)
                    : const Color(0xFF94A3B8),
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTouchpadArea(BorderRadius borderRadius) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: borderRadius,
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: Stack(
          children: [
            Positioned.fill(
              child: Listener(
                onPointerDown: _handlePointerDown,
                onPointerMove: _handlePointerMove,
                onPointerUp: _handlePointerUp,
                onPointerCancel: _handlePointerCancel,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onScaleUpdate: (details) {
                    if (details.pointerCount == 1) {
                      final delta = details.focalPointDelta;
                      _queueDelta(delta.dx, delta.dy);
                    } else if (details.pointerCount == 2) {
                      final delta = details.focalPointDelta;
                      final scrollAmount = (-delta.dy * 0.1).round();
                      if (scrollAmount != 0) _sendScroll(scrollAmount);
                    }
                  },
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.fingerprint_rounded,
                          size: 48,
                          color: const Color(0x806366F1),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _isLongPressing
                              ? 'DRAG LOCK ACTIVE'
                              : 'Drag finger to move pointer\nUse two fingers to scroll',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: _isLongPressing
                                ? const Color(0xFFEF4444)
                                : const Color(0xFF94A3B8),
                            fontWeight: _isLongPressing
                                ? FontWeight.bold
                                : FontWeight.normal,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            ValueListenableBuilder<Offset?>(
              valueListenable: _touchPositionNotifier,
              builder: (context, pos, child) {
                if (pos == null) return const SizedBox.shrink();
                return Positioned(
                  left: pos.dx - 24,
                  top: pos.dy - 24,
                  child: IgnorePointer(
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xCC6366F1),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0x666366F1),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                        gradient: RadialGradient(
                          colors: [const Color(0x4D6366F1), Colors.transparent],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Stack(
          children: [
            OrientationBuilder(
              builder: (context, orientation) {
                if (orientation == Orientation.portrait) {
                  return Column(
                    children: [
                      _buildHeaderPanel(),
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(0xFF334155),
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            children: [
                              Expanded(
                                child: _buildTouchpadArea(
                                  const BorderRadius.vertical(
                                    top: Radius.circular(18),
                                  ),
                                ),
                              ),
                              SizedBox(
                                height: 70,
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    PressableTrackpadButton(
                                      label: 'LEFT CLICK',
                                      button: 'left',
                                      icon: Icons.mouse_outlined,
                                      borderRadius: const BorderRadius.only(
                                        bottomLeft: Radius.circular(18),
                                      ),
                                      border: const Border(
                                        top: BorderSide(
                                          color: Color(0xFF334155),
                                          width: 1.5,
                                        ),
                                        right: BorderSide(
                                          color: Color(0xFF334155),
                                          width: 0.75,
                                        ),
                                      ),
                                      onClickChange: _sendClick,
                                    ),
                                    _buildKeyboardMiddleButton(
                                      isLandscape: false,
                                    ),
                                    PressableTrackpadButton(
                                      label: 'RIGHT CLICK',
                                      button: 'right',
                                      icon: Icons.mouse,
                                      borderRadius: const BorderRadius.only(
                                        bottomRight: Radius.circular(18),
                                      ),
                                      border: const Border(
                                        top: BorderSide(
                                          color: Color(0xFF334155),
                                          width: 1.5,
                                        ),
                                        left: BorderSide(
                                          color: Color(0xFF334155),
                                          width: 0.75,
                                        ),
                                      ),
                                      onClickChange: _sendClick,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                } else {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: 3,
                        child: Container(
                          margin: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(0xFF334155),
                              width: 1.5,
                            ),
                          ),
                          child: _buildTouchpadArea(BorderRadius.circular(18)),
                        ),
                      ),
                      Container(
                        width: 180,
                        margin: const EdgeInsets.only(
                          top: 16,
                          bottom: 16,
                          right: 16,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildLandscapeHeaderPanel(),
                            const SizedBox(height: 12),
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E293B),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: const Color(0xFF334155),
                                    width: 1.5,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    PressableTrackpadButton(
                                      label: 'LEFT CLICK',
                                      button: 'left',
                                      icon: Icons.mouse_outlined,
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(18),
                                        topRight: Radius.circular(18),
                                      ),
                                      border: const Border(
                                        bottom: BorderSide(
                                          color: Color(0xFF334155),
                                          width: 0.75,
                                        ),
                                      ),
                                      onClickChange: _sendClick,
                                    ),
                                    _buildKeyboardMiddleButton(
                                      isLandscape: true,
                                    ),
                                    PressableTrackpadButton(
                                      label: 'RIGHT CLICK',
                                      button: 'right',
                                      icon: Icons.mouse,
                                      borderRadius: const BorderRadius.only(
                                        bottomLeft: Radius.circular(18),
                                        bottomRight: Radius.circular(18),
                                      ),
                                      border: const Border(
                                        top: BorderSide(
                                          color: Color(0xFF334155),
                                          width: 0.75,
                                        ),
                                      ),
                                      onClickChange: _sendClick,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }
              },
            ),
            Positioned(
              left: -100,
              top: -100,
              child: SizedBox(
                width: 1,
                height: 1,
                child: Opacity(
                  opacity: 0,
                  child: TextField(
                    controller: _keyboardController,
                    focusNode: _keyboardFocusNode,
                    keyboardType: TextInputType.text,
                    textInputAction: TextInputAction.send,
                    enableSuggestions: false,
                    autocorrect: false,
                    onChanged: (text) {
                      if (text.length > 1) {
                        final char = text[text.length - 1];
                        if (char == ' ') {
                          _sendKeyboardKey("space");
                        } else {
                          _sendKeyboardKey(char);
                        }
                        _keyboardController.text = " ";
                      } else if (text.isEmpty) {
                        _sendKeyboardKey("backspace");
                        _keyboardController.text = " ";
                      }
                    },
                    onSubmitted: (text) {
                      _sendKeyboardKey("enter");
                      _keyboardController.text = " ";
                      Future.delayed(const Duration(milliseconds: 50), () {
                        if (mounted) _keyboardFocusNode.requestFocus();
                      });
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PressableTrackpadButton extends StatefulWidget {
  final String label;
  final String button;
  final IconData icon;
  final BorderRadius borderRadius;
  final Border border;
  final Function(String, bool) onClickChange;

  const PressableTrackpadButton({
    super.key,
    required this.label,
    required this.button,
    required this.icon,
    required this.borderRadius,
    required this.border,
    required this.onClickChange,
  });

  @override
  State<PressableTrackpadButton> createState() =>
      _PressableTrackpadButtonState();
}

class _PressableTrackpadButtonState extends State<PressableTrackpadButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTapDown: (_) {
          HapticFeedback.mediumImpact();
          setState(() => _isPressed = true);
          widget.onClickChange(widget.button, true);
        },
        onTapUp: (_) {
          setState(() => _isPressed = false);
          widget.onClickChange(widget.button, false);
        },
        onTapCancel: () {
          setState(() => _isPressed = false);
          widget.onClickChange(widget.button, false);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 60),
          decoration: BoxDecoration(
            color: _isPressed
                ? const Color(0xFF334155)
                : const Color(0xFF1E293B),
            borderRadius: widget.borderRadius,
            border: widget.border,
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                widget.icon,
                color: _isPressed
                    ? const Color(0xFF6366F1)
                    : const Color(0xFF94A3B8),
                size: 20,
              ),
              const SizedBox(height: 4),
              Text(
                widget.label,
                style: TextStyle(
                  color: _isPressed
                      ? const Color(0xFFF8FAFC)
                      : const Color(0xFF94A3B8),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
