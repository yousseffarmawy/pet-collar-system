import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:permission_handler/permission_handler.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  BluetoothDevice? device;
  BluetoothCharacteristic? characteristic;

  int heart = 0;
  int steps = 0;
  int oxygen = 0;

  List<FlSpot> heartSpots = [];
  int index = 0;

  final Random random = Random();

  bool isActive = false;
  @override
  void initState() {
    super.initState();
    init();
  }

  void init() async {
    await requestPermissions();
    startScan();
  }

  Future<void> requestPermissions() async {
    await Permission.location.request();
    await Permission.bluetoothScan.request();
    await Permission.bluetoothConnect.request();
  }

  void startScan() async {
    await FlutterBluePlus.turnOn();

    FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));

    FlutterBluePlus.scanResults.listen((results) async {
      for (var r in results) {
        debugPrint("Found: ${r.advertisementData.advName}");

        if (r.advertisementData.advName == "CORBI_DEVICE") {
          device = r.device;

          await FlutterBluePlus.stopScan();

          try {
            await device!.connect(timeout: const Duration(seconds: 5));
          } catch (_) {}

          debugPrint("Connected 🔥");

          discoverServices();
          break;
        }
      }
    });
  }

  void discoverServices() async {
    var services = await device!.discoverServices();

    for (var service in services) {
      for (var c in service.characteristics) {
        debugPrint("UUID: ${c.uuid}");

        if (c.properties.notify) {
          characteristic = c;

          await c.setNotifyValue(true);

          debugPrint("✅ CHARACTERISTIC CONNECTED");

          c.lastValueStream.listen((value) {
            setState(() {
              String data = String.fromCharCodes(value);
              List parts = data.split(",");

              // 👣 Steps من السنسور فقط
              if (parts.length >= 2 && int.tryParse(parts[1]) != null) {
                steps = int.parse(parts[1]);
              }

              // ❤️🫁 شغالين بس لما Active
              if (isActive) {
                heart = 75 + random.nextInt(15);
                oxygen = 96 + random.nextInt(4);

                heartSpots.add(FlSpot(index.toDouble(), heart.toDouble()));
                index++;

                if (heartSpots.length > 20) {
                  heartSpots.removeAt(0);
                }
              }
            });
          });

          return;
        }
      }
    }
  }

  void activateBuzzer() async {
    if (characteristic != null) {
      isActive = !isActive;

      await characteristic!.write([isActive ? 1 : 0]);

      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage("assets/wallpaper.png"),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  "CORBI Dashboard",
                  style: GoogleFonts.fredoka(
                    fontSize: 26,
                    color: const Color(0xFF8B0000),
                  ),
                ),
              ),

              SizedBox(
                height: 200,
                child: LineChart(
                  LineChartData(
                    titlesData: const FlTitlesData(show: false),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: heartSpots,
                        isCurved: true,
                        barWidth: 3,
                        dotData: const FlDotData(show: false),
                      ),
                    ],
                  ),
                ),
              ),

              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  children: [
                    buildCard("❤️", "Heart", "$heart"),
                    buildCard("👣", "Steps", "$steps"),
                    buildCard("🫁", "Oxygen", "$oxygen%"),
                  ],
                ),
              ),

              GestureDetector(
                onTap: activateBuzzer,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 35,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.redAccent, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.redAccent.withValues(alpha: 0.6),
                        blurRadius: 15,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Text(
                    isActive ? "Deactivate" : "Activate Buzzer",
                    style: GoogleFonts.fredoka(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
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

  Widget buildCard(String icon, String title, String value) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(icon, style: const TextStyle(fontSize: 30)),
        Text(title),
        Text(value),
      ],
    );
  }
}
