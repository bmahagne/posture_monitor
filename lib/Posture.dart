// Contains the logic of the application
class AppLogic {
  bool postureCorrect = true;
  bool getPostureCorrect() {
    return postureCorrect;
  }

  String postureGoodText = "Posture Good :)";
  String postureBadText = "Posture Bad :(";
  String getPostureText(){
    if(postureCorrect){
      return postureGoodText;
    } else {
      return postureBadText;
    }
  }
  bool checkIfPostureCorrect(List<int> acc) {
    int Yacc = acc[1];
    int threshold = -2200;

    if(Yacc > threshold) {
      // posture was bad
      return false;
    } else {
      // posture was fine
      return true;
    }
  }
}
