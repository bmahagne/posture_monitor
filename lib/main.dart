import 'package:flutter/material.dart';
import 'dart:async';
import 'SpeedRegulator.dart';
import 'package:esense_flutter/esense.dart';

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _deviceName = 'Unknown';
  String _deviceStatus = '';
  bool sampling = false;
  String _event = '';
  StreamSubscription subscription;

  // the name of the eSense device to connect to -- change this to your own device.
  // Only the right one is needed.
  String eSenseNameRight = 'eSense-0584';

  @override
  void initState() {
    super.initState();
    _connectToESense();
  }

  Future<void> _connectToESense() async {
    bool con = false;

    // if you want to get the connection events when connecting, set up the listener BEFORE connecting...
    ESenseManager.connectionEvents.listen((event) {
      print('CONNECTION event: $event');

      // when we're connected to the eSense device, we can start listening to events from it
      if (event.type == ConnectionType.connected) _listenToESenseEvents();

      setState(() {
        switch (event.type) {
          case ConnectionType.connected:
            _deviceStatus = 'connected';
            break;
          case ConnectionType.unknown:
            _deviceStatus = 'unknown';
            break;
          case ConnectionType.disconnected:
            _deviceStatus = 'disconnected';
            break;
          case ConnectionType.device_found:
            _deviceStatus = 'device_found';
            break;
          case ConnectionType.device_not_found:
            _deviceStatus = 'device_not_found';
            break;
        }
      });
    });

    con = await ESenseManager.connect(eSenseNameRight);

    setState(() {
      _deviceStatus = con ? 'connecting' : 'connection failed';
    });
  }

  void _listenToESenseEvents() {
    ESenseManager.eSenseEvents.listen((event) {
      print('ESENSE event: $event');

      setState(() {
        switch (event.runtimeType) {
          case DeviceNameRead:
            _deviceName = (event as DeviceNameRead).deviceName;
            break;
        }
      });
    });

    _getESenseProperties();
  }

  void _getESenseProperties() async {
    // get the battery level every 10 secs
    Timer.periodic(Duration(seconds: 10),
        (timer) async => await ESenseManager.getBatteryVoltage());

    // wait 2, 3, 4, 5, ... secs before getting the name, offset, etc.
    // it seems like the eSense BTLE interface does NOT like to get called
    // several times in a row -- hence, delays are added in the following calls
    Timer(
        Duration(seconds: 2), () async => await ESenseManager.getDeviceName());
    Timer(Duration(seconds: 3),
        () async => await ESenseManager.getAccelerometerOffset());
    Timer(
        Duration(seconds: 4),
        () async =>
            await ESenseManager.getAdvertisementAndConnectionInterval());
    Timer(Duration(seconds: 5),
        () async => await ESenseManager.getSensorConfig());
  }

  void _startListenToSensorEvents() async {
    print("entered startListeningToSensorEvents() fct()");
    // subscribe to sensor event from the eSense device
    if (!sampling) {
      subscription = ESenseManager.sensorEvents.listen((event) {
        List<int> acc = event.accel;

        // steps
        print("steps: ${speedRegulator.steps}");

        print('SENSOR event: $event');
        setState(() {
          _event = event.toString();
          speedRegulator.countSteps(acc[2]);
        });
      });
      sampling = true;
    }
  }

  void _pauseListenToSensorEvents() {
    speedRegulator.steps = 0;
    subscription.cancel();
    setState(() {
      sampling = false;
    });
  }

  void dispose() {
    _pauseListenToSensorEvents();
    ESenseManager.disconnect();
    super.dispose();
  }

  void ListeningToSensorEventsButtonEffect() {
    print("entered ListeningToSensorEventsButtonEffect() fct");
    if (ESenseManager.connected) {
      print("sampling: \t$sampling");
      if (!sampling) {
        _startListenToSensorEvents();
      } else {
        _pauseListenToSensorEvents();
      }
    }
  }

  void connectToBLEButtonEffect(BuildContext context) {
    // only try connection if not already connected
    if (!ESenseManager.connected) {
      _connectToESense();
    } else {
      print("already connected to eSense via bluetooth");
    }
  }

  // double targetRunningSpeed = 50.0;
  bool pacingSpeedGettingTracked = false;

  // need to be an instance variable to be able to change when widget get rebuild
  String connectedText = "Connected";
  String disconnectedText = "Connect to bluetooth";
  SpeedRegulator speedRegulator = new SpeedRegulator(50.0);

  Widget build(BuildContext context) {
    const String title = "Jogging Pacer";
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
            title: const Text(title),
            // Use same color as strava
            backgroundColor: Colors.deepOrange),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Padding(
                padding: EdgeInsets.only(bottom: 30),
                child: Text(
                  "RUNNING SPEED",
                  style: TextStyle(fontSize: 30.0, fontWeight: FontWeight.w900),
                  textAlign: TextAlign.center,
                ),
              ),
              Text(
                speedRegulator.targetRunningSpeed.toInt().toString(),
                style: TextStyle(fontSize: 40.0, fontWeight: FontWeight.w900),
              ),
              Slider(
                value: speedRegulator.targetRunningSpeed,
                min: 0,
                max: 100,
                divisions: 10,
                activeColor: Colors.pink,
                onChanged: (double value) {
                  setState(() {
                    speedRegulator.targetRunningSpeed = value;
                    speedRegulator.calculateTargetstepsPerSecond();
                  });
                },
              ),
              Padding(
                padding: EdgeInsets.only(bottom: 100),
                child: Text(
                  "Just slide the Slider to increase\nor decrease target running speed",
                  style: TextStyle(fontSize: 20.0, fontWeight: FontWeight.w900),
                ),
              ),
              Padding(
                padding: EdgeInsets.only(bottom: 30),
                child: Transform.scale(
                    scale: 5,
                    child: IconButton(
                        icon:
                            Icon(pacingSpeedGettingTracked ? Icons.pause : Icons.play_arrow),
                        tooltip: "start counting steps",
                        onPressed: () {
                          print("play button pressed");
                          setState(() {
                            pacingSpeedGettingTracked = !pacingSpeedGettingTracked;
                            ListeningToSensorEventsButtonEffect();
                            speedRegulator.handleSpeedCheckTimer();
                          });
                        })),
              ),
              Text("Start/Stop Running!"),
              Text(''),
              // Text('eSense Device Status: \t$_deviceStatus'),
              // Text('eSense Device Name: \t$_deviceName'),
              Text('steps: \t${speedRegulator.steps}'),
              Text('stepsPerTime: \t${speedRegulator.stepsPerTime}'),
              Text('targetStepsPerTime: \t${speedRegulator.targetStepsPerSecond}'),
              Text(''),
              // Text(''),
              // Text('$_event'),

              // start listening button
              FloatingActionButton(
                // a floating button that starts/stops listening to sensor events.
                // is disabled until we're connected to the device.
                onPressed: () => connectToBLEButtonEffect(context),
                tooltip: 'Listen to eSense sensors',
                child: (!ESenseManager.connected)
                    ? Icon(Icons.play_arrow)
                    : Icon(Icons.pause),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 10.0),
                child: Text(
                    // vary text according to the connection status
                    (ESenseManager.connected)
                        ? connectedText
                        : disconnectedText,
                    style: TextStyle(color: Colors.blue)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
