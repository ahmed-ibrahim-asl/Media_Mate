//----------------------------- dart_core ------------------------------
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
//----------------------------------------------------------------------

//-------------------------- flutter_packages --------------------------
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:permission_handler/permission_handler.dart';
//----------------------------------------------------------------------

class BluetoothService {
  static final BluetoothService _instance = BluetoothService._internal();
  factory BluetoothService() => _instance;
  BluetoothService._internal();

  final FlutterBluetoothSerial _bluetooth = FlutterBluetoothSerial.instance;
  BluetoothConnection? _connection;
  final StreamController<String> _incomingData = StreamController.broadcast();

  Stream<String> get onDataReceived => _incomingData.stream;
  bool get isConnected => _connection?.isConnected == true;

  Future<void> init() async {
    if (await Permission.bluetoothConnect.request().isGranted &&
        await Permission.bluetoothScan.request().isGranted &&
        await Permission.locationWhenInUse.request().isGranted) {
      await _bluetooth.requestEnable();
    } else {
      throw Exception("Bluetooth permissions not granted.");
    }
  }

  Future<List<BluetoothDevice>> getBondedDevices() async {
    return await _bluetooth.getBondedDevices();
  }

  Stream<BluetoothDiscoveryResult> startDiscovery() {
    return _bluetooth.startDiscovery();
  }

  Future<void> connect(String address) async {
    if (isConnected) return;
    _connection = await BluetoothConnection.toAddress(address);
    _connection!.input?.listen(
      (Uint8List data) {
        _incomingData.add(utf8.decode(data, allowMalformed: true));
      },
      onDone: () {
        _connection = null;
      },
    );
  }

  Future<void> disconnect() async {
    await _connection?.close();
    _connection = null;
  }

  Future<void> send(String message) async {
    if (!isConnected) throw Exception("Bluetooth not connected");
    _connection!.output.add(Uint8List.fromList(utf8.encode(message)));
    await _connection!.output.allSent;
  }

  /// Send a list of booleans as a compact string like '101' via Bluetooth
  Future<void> sendBoolArray(List<bool> boolArray) async {
    if (!isConnected) throw Exception("Bluetooth not connected");
    String message = boolArray.map((b) => b ? '1' : '0').join();
    await send(message);
  }
}
