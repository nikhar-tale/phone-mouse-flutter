// lib/main.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/status.dart' as status;

void main() {
  runApp(MousePadApp());
}

class MousePadApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Phone Mouse WS',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: StartupScreen(),
    );
  }
}

class StartupScreen extends StatefulWidget {
  @override
  _StartupScreenState createState() => _StartupScreenState();
}

class _StartupScreenState extends State<StartupScreen> {
  final TextEditingController _ipController = TextEditingController();
  final TextEditingController _portController =
      TextEditingController(text: '8000');
  bool _connecting = false;

  void _connect() {
    final ip = _ipController.text.trim();
    final port = _portController.text.trim();
    if (ip.isEmpty || port.isEmpty) return;

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
      body: Center(
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: 24),
          padding: EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(blurRadius: 12, color: Colors.black12)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Connect to PC',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 24),
              TextField(
                controller: _ipController,
                decoration: InputDecoration(
                  labelText: 'Windows IP (e.g. 192.168.43.29)',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: _portController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Port',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _connecting ? null : _connect,
                  child: Text('Connect'),
                  style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8))),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TouchpadScreen extends StatefulWidget {
  final String ip;
  final String port;
  TouchpadScreen({required this.ip, required this.port});

  @override
  _TouchpadScreenState createState() => _TouchpadScreenState();
}

class _TouchpadScreenState extends State<TouchpadScreen> {
  IOWebSocketChannel? _channel;
  bool _connected = false;

  double sensitivity = 1.2;
  double _accDx = 0;
  double _accDy = 0;
  Timer? _sendTimer;

  @override
  void initState() {
    super.initState();
    _connect();
  }

  @override
  void dispose() {
    _disconnect();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blueGrey[50],
      appBar: AppBar(
        elevation: 0,
        title: Row(
          children: [
            Icon(
              _connected ? Icons.wifi : Icons.wifi_off,
              color: _connected ? Colors.greenAccent : Colors.redAccent,
            ),
            SizedBox(width: 8),
            Text(_connected ? 'Connected' : 'Connecting...'),
          ],
        ),
        backgroundColor: Colors.blueAccent,
        actions: [
          IconButton(icon: Icon(Icons.refresh), onPressed: _connect),
          IconButton(
            icon: Icon(Icons.power_settings_new, color: Colors.redAccent),
            onPressed: _disconnect,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              margin: EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.white, Colors.blueGrey[100]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
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
                onTap: () => _tapClick('left'),
                onDoubleTap: () => _tapClick('left'),
                onLongPressStart: (_) => _sendClick('left', true),
                onLongPressEnd: (_) => _sendClick('left', false),
                child: Center(
                  child: AnimatedOpacity(
                    duration: Duration(milliseconds: 300),
                    opacity: _connected ? 1 : 0.5,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.touch_app, size: 60, color: Colors.blueGrey),
                        SizedBox(height: 12),
                        Text(
                          _connected
                              ? 'Move one finger to control cursor\nUse two fingers to scroll'
                              : 'Connecting to server...',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 16, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Buttons row
          Padding(
            padding: const EdgeInsets.only(bottom: 24.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildCircleButton(Icons.mouse, "Left", 'left'),
                _buildCircleButton(Icons.mouse, "Right", 'right'),
              ],
            ),
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.blueAccent,
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            builder: (context) {
              return StatefulBuilder(
                builder: (context, setModalState) {
                  return Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "Pointer Sensitivity",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Slider(
                          value: sensitivity,
                          min: 0.5,
                          max: 3,
                          divisions: 5,
                          label: sensitivity.toStringAsFixed(1),
                          onChanged: (val) {
                            // update BOTH parent + modal state
                            setState(() => sensitivity = val);
                            setModalState(() {}); // refresh bottom sheet
                          },
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },

        child: Text(
          sensitivity.toStringAsFixed(1),
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
    );
  }

  void _tapClick(String button) {
    _sendClick(button, true);
    Future.delayed(Duration(milliseconds: 40), () => _sendClick(button, false));
  }

  Widget _buildCircleButton(IconData icon, String label, String button) {
    return ElevatedButton(
      onPressed: () => _tapClick(button),
      style: ElevatedButton.styleFrom(
        shape: CircleBorder(),
        padding: EdgeInsets.all(24),
        elevation: 6,
        backgroundColor: Colors.white,
        shadowColor: Colors.black26,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.blueAccent, size: 28),
          SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.blueGrey,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
