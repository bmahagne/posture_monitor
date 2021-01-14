import 'dart:async';
import 'package:volume/volume.dart';

// Contains the logic to process the speed of the runner
class SpeedRegulator {
  double targetRunningSpeed;
  int steps = 0;

  AudioManager audioManager;
  int maxVol, currentVol;

  SpeedRegulator(double targetRunningSpeed) {
    this.targetRunningSpeed = targetRunningSpeed;
    calculateTargetstepsPerSecond();
    audioManager = AudioManager.STREAM_SYSTEM;
    initAudioStreamType();
    setDefaultVolume();
    updateVolumes();
  }

  Future<void> initAudioStreamType() async {
    await Volume.controlVolume(AudioManager.STREAM_MUSIC);
  }

  updateVolumes() async {
    // get Max Volume
    maxVol = await Volume.getMaxVol;
    // get Current Volume
    currentVol = await Volume.getVol;
  }

  setVol(int i) async {
    await Volume.setVol(i);
    updateVolumes();
  }

  volUp() async {
    setVol(currentVol + 3);
    updateVolumes();
  }

  volDown() async {
    setVol(currentVol - 3);
    updateVolumes();
  }

  bool abovePart = false;
  void countSteps(int zAcc) {
    if (zAcc > 6000) {
      if (!abovePart) {
        steps++;
      }
      abovePart = true;
    } else if (zAcc < 4500) {
      abovePart = false;
    }
  }

  Timer t;
  bool timerStarted = false;
  Duration d = Duration(seconds: 10);

  void startTimer() {
    steps = 0;
    setDefaultVolume();
    t = Timer.periodic(d, (Timer timer) => handleTimeOut());
    print("started timer");
  }

  void stopTimer() {
    setDefaultVolume();
    t.cancel();
    steps = 0;
    print("stopped timer");
  }

  void handleSpeedCheckTimer() async {
    if (!timerStarted) {
      startTimer();
    } else {
      stopTimer();
    }
    timerStarted = !timerStarted;
  }

  double stepsPerTime;
  double stepsPerSecond = 2; // 10 percent

  double targetStepsPerSecond;

  void calculateTargetstepsPerSecond() {
    // 1 step per second on lowest speed, 4 on highest.
    targetStepsPerSecond = 1 + (targetRunningSpeed * 3) / 100;
  }

  void setDefaultVolume() {
    setVol(15);
  }
  void handleTimeOut() {
    print("timer firing");
    stepsPerTime = steps / 10;
    double buffer = stepsPerSecond / 10;
    if (stepsPerTime > targetStepsPerSecond + buffer) {
      volDown();
    } else if (stepsPerTime < targetStepsPerSecond - buffer) {
      volUp();
    } else {
      setDefaultVolume();
    }
    // reset amount of steps
    steps = 0;
  }
}
