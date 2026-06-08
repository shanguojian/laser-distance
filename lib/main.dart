import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const LaserDistanceApp());
}

class LaserDistanceApp extends StatelessWidget {
  const LaserDistanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '激光测距仪',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const LaserDistancePage(),
    );
  }
}

class LaserDistancePage extends StatefulWidget {
  const LaserDistancePage({super.key});

  @override
  State<LaserDistancePage> createState() => _LaserDistancePageState();
}

class _LaserDistancePageState extends State<LaserDistancePage> {
  String _distance = '---.-- m';
  final List<String> _logs = [];
  final List<String> _availablePorts = ['COM1', 'COM2', 'COM3', 'COM4'];
  String _selectedPort = 'COM1';
  String _selectedBaudrate = '115200';
  String _selectedStopbits = '1';
  String _selectedParity = '无';
  bool _isConnected = false;
  bool _isContinuousMode = false;
  Timer? _continuousTimer;
  final ScrollController _logScrollController = ScrollController();

  final List<String> _baudrates = ['9600', '19200', '38400', '57600', '115200'];
  final List<String> _stopbits = ['1', '1.5', '2'];
  final List<String> _parities = ['无', '奇校验', '偶校验'];

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _continuousTimer?.cancel();
    _logScrollController.dispose();
    super.dispose();
  }

  void _addLog(String message) {
    final timestamp = DateTime.now().toString().substring(11, 23);
    setState(() {
      _logs.add('[$timestamp] $message');
    });
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_logScrollController.hasClients) {
        _logScrollController.animateTo(
          _logScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _bytesToHex(Uint8List data) {
    return data.map((byte) => byte.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
  }

  void _toggleConnection() {
    setState(() {
      _isConnected = !_isConnected;
      if (_isConnected) {
        _addLog('已连接到 $_selectedPort @ $_selectedBaudrate');
      } else {
        if (_isContinuousMode) {
          _toggleContinuous();
        }
        _addLog('已断开连接');
      }
    });
  }

  void _sendSingleMeasure() {
    if (!_isConnected) return;
    final cmd = Uint8List.fromList([0x55, 0xAA, 0x88, 0xFF, 0xFF, 0xFF, 0xFF, 0x84]);
    _addLog('<发送> ${_bytesToHex(cmd)}');
    Future.delayed(const Duration(milliseconds: 300), () {
      _simulateResponse();
    });
  }

  void _toggleContinuous() {
    setState(() {
      _isContinuousMode = !_isContinuousMode;
      if (_isContinuousMode) {
        final cmd = Uint8List.fromList([0x55, 0xAA, 0x89, 0xFF, 0xFF, 0xFF, 0xFF, 0x85]);
        _addLog('<发送> ${_bytesToHex(cmd)}');
        _continuousTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
          _simulateResponse();
        });
      } else {
        _continuousTimer?.cancel();
        final cmd = Uint8List.fromList([0x55, 0xAA, 0x8E, 0xFF, 0xFF, 0xFF, 0xFF, 0x8A]);
        _addLog('<发送> ${_bytesToHex(cmd)}');
      }
    });
  }

  void _simulateResponse() {
    final randomDistance = (0.1 + (DateTime.now().millisecond % 4900) / 1000);
    final distanceInTenthsMm = (randomDistance * 10000).toInt();
    final highByte = (distanceInTenthsMm >> 8) & 0xFF;
    final lowByte = distanceInTenthsMm & 0xFF;
    final response = Uint8List.fromList([0x55, 0xAA, 0x88, 0x01, 0x00, highByte, lowByte, 0x84]);
    
    _addLog('<接收> ${_bytesToHex(response)}');
    
    if (response.length >= 8 && 
        response[0] == 0x55 && 
        response[1] == 0xAA && 
        response[2] == 0x88 && 
        response[3] == 0x01) {
      final high = response[5];
      final low = response[6];
      final distance = (high << 8) | low;
      final distanceM = distance / 10000.0;
      
      setState(() {
        _distance = '${distanceM.toStringAsFixed(3)} m';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('激光测距仪'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(8),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('串口设置', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const SizedBox(width: 60, child: Text('串口号:')),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _selectedPort,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 8),
                                ),
                                items: _availablePorts.map((port) {
                                  return DropdownMenuItem(value: port, child: Text(port));
                                }).toList(),
                                onChanged: _isConnected ? null : (value) {
                                  setState(() => _selectedPort = value!);
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const SizedBox(width: 60, child: Text('波特率:')),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _selectedBaudrate,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 8),
                                ),
                                items: _baudrates.map((baud) {
                                  return DropdownMenuItem(value: baud, child: Text(baud));
                                }).toList(),
                                onChanged: _isConnected ? null : (value) {
                                  setState(() => _selectedBaudrate = value!);
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const SizedBox(width: 60, child: Text('停止位:')),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _selectedStopbits,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 8),
                                ),
                                items: _stopbits.map((stop) {
                                  return DropdownMenuItem(value: stop, child: Text(stop));
                                }).toList(),
                                onChanged: _isConnected ? null : (value) {
                                  setState(() => _selectedStopbits = value!);
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const SizedBox(width: 60, child: Text('校验位:')),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _selectedParity,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 8),
                                ),
                                items: _parities.map((parity) {
                                  return DropdownMenuItem(value: parity, child: Text(parity));
                                }).toList(),
                                onChanged: _isConnected ? null : (value) {
                                  setState(() => _selectedParity = value!);
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _toggleConnection,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isConnected ? Colors.red[700] : Colors.blue[700],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: Text(_isConnected ? '关闭串口' : '打开串口'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('测量控制', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _isConnected ? _sendSingleMeasure : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFc5221f),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                ),
                                child: const Text('单次测量', style: TextStyle(fontSize: 16)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _isConnected ? _toggleContinuous : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _isContinuousMode ? Colors.orange[700] : const Color(0xFF137333),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                ),
                                child: const Text('连续测量', style: TextStyle(fontSize: 16)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('距离显示', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _distance,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 250,
            padding: const EdgeInsets.all(8),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('调试窗口 - 原始16进制数据', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        ElevatedButton(
                          onPressed: () => setState(() => _logs.clear()),
                          child: const Text('清空日志'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        padding: const EdgeInsets.all(4),
                        child: ListView.builder(
                          controller: _logScrollController,
                          itemCount: _logs.length,
                          itemBuilder: (context, index) {
                            return Text(
                              _logs[index],
                              style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}