import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'Posture.dart';
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

  AppLogic appLogic = AppLogic();

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
    print('sampling: \t$sampling');
    // array mit 3 werten
    if (!sampling) {
      subscription = ESenseManager.sensorEvents.listen((event) {
        List<int> acc = event.accel;
        appLogic.postureCorrect = appLogic.checkIfPostureCorrect(acc);
        bool posture = appLogic.getPostureCorrect();
        print('posture correct: \t$posture');

        print('SENSOR event: $event');
        setState(() {
          _event = event.toString();
        });
      });
      sampling = true;
    }
  }

  void _pauseListenToSensorEvents() {
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

  // need to be an instance variable to be able to change when widget get rebuild
  String connectedText = "Connected";
  String disconnectedText = "Connect to bluetooth";

  static const String startListeningToSensorEventsText = "Start working";

  Widget build(BuildContext context) {
    const String title = "MyTitle";
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
            title: const Text(title),
            // set color
            backgroundColor: Colors.greenAccent),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(appLogic.getPostureText()),
              Image(image: AssetImage('assets/posture_good.png')),
              Text(''),
              Text('eSense Device Status: \t$_deviceStatus'),
              Text('eSense Device Name: \t$_deviceName'),
              Text('posture correct: \t$appLogic.postureCorrect'),
              RaisedButton(
                onPressed: () => ListeningToSensorEventsButtonEffect(),
                textColor: Colors.white,
                padding: const EdgeInsets.all(0.0),
                child: Container(
                  padding: const EdgeInsets.all(10.0),
                  child:
                  const Text(startListeningToSensorEventsText, style: TextStyle(fontSize: 20)),
                ),
              ),
              RaisedButton(
                onPressed: () => connectToBLEButtonEffect(context),
                textColor: Colors.white,
                padding: const EdgeInsets.all(0.0),
                child: Container(
                  padding: const EdgeInsets.all(10.0),
                  child:
                  Text(
                    // vary text according to the connection status
                      (ESenseManager.connected)
                          ? connectedText
                          : disconnectedText,
                      style: TextStyle(color: Colors.blue)),
                ),
              ),
              // Text(''),
              // Text('$_event'),
            ],
          ),
        ),
      ),
    );
  }
}
