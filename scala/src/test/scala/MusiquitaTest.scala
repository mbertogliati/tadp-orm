import Musiquita._
import org.scalatest.freespec.AnyFreeSpec
import org.scalatest.matchers.should.Matchers.{a, convertToAnyShouldWrapper}
import scala.util.Success

class MusiquitaTest extends AnyFreeSpec{
  "Feliz cumpleaños" - {
    val felizCumple = "4C1/8 4C1/8 4D1/4 4C1/4 4F1/4 4E1/2 4C1/8 4C1/8 4D1/4 4C1/4 4G1/4 4F1/2"
    val miMelodia = melodia(felizCumple).get._1
    AudioPlayer.reproducir(miMelodia)
  }
  "Cancion Bonus" - {
    val cancionBonus = "4AM1/8 5C1/8 5C#1/8 5C#1/8 5D#1/8 5C1/8 4A#1/8 4G#1/2 - 4A#1/8 4A#1/8 5C1/4 5C#1/8 4A#1/4 4G#1/2 5G#1/4 5G#1/4 5D#1/2"
    val miMelodia = melodia(cancionBonus).get._1
    AudioPlayer.reproducir(miMelodia)
  }
  "Imagine" - {
    val imagine = "4E+4G1/4 4C1/4 4E+4G1/4 4C1/4 4E+4G1/4 4C1/4 4E+4B1/4 4C1/4 4F+4A1/4 4C1/4 4F+4A1/2 4C1/4 4F+4A1/4 4C1/4 4A1/4 4A#1/8 4B1/4 4E+4G1/4 4C1/4 4E+4G1/4 4C1/4 4E+4G1/8"
    val miMelodia = melodia(imagine).get._1
    AudioPlayer.reproducir(miMelodia)
  }
  "Take on Me" - {
    val takeOnMe = "4A1/8 4A1/8 4F1/8 4D1/4 4D1/4 4G1/8 4G1/4 4G1/4 4B1/8 5C1/8 5D1/8 5C1/8 5C1/8 5C1/8 4G1/8 4F1/8 4A1/8 4A1/8 4A1/8 4G1/8 4G1/8 4A1/8 4G1/8"
    val miMelodia = melodia(takeOnMe).get._1
    AudioPlayer.reproducir(miMelodia)
  }
}
