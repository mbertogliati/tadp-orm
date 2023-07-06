import scala.math.log10
import scala.util.{Failure, Success, Try}

object EjemplosParser {
  val anyChar = new Parser({ s => Try(ResultadoParser(s.head, s.tail)) })
  val char: Char => Parser[Char] = (c: Char) => anyChar.satisfies(_ == c)
  val void = new Parser({ s =>
    if (s.isEmpty) {
      Failure(new RuntimeException("La cadena esta vacía"))
    }
    else {
      Try(ResultadoParser((), s))
    }
  })
  val letter: Parser[Char] = anyChar.satisfies(_.isLetter)
  val digit: Parser[Char] = anyChar.satisfies(_.isDigit)
  val alphaNum: Parser[Char] = digit <|> letter
  val string: String => Parser[String] = (str: String) => new Parser({
    s =>
      if (s.startsWith(str)) {
        Try(ResultadoParser(str, s.substring(str.length)))
      } else {
        Failure(new Exception("La cadena no empieza con '" + str + "'"))
      }
  })

}



