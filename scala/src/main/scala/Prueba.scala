import scala.util.{Try, Success, Failure}

case class ResultadoParser[T](parseado: T, resto: String)

abstract class Parser[T]{
  def parseado(s:String) : T
  def resto(s:String) : String
  def condicion(s : String) : Boolean
  var mensaje : String

  def apply(s: String): Try[ResultadoParser[T]] =
    Try[ResultadoParser[T]] {
      if(condicion(s)) {
        new ResultadoParser[T](parseado(s), resto(s))
      } else {
        throw new Exception(mensaje)
      }
    }
}

abstract class charParser extends Parser[Char]{
  override def parseado(s:String) : Char = s.head
  override def resto(s:String) : String = s.tail
}

object anyChar extends charParser {
  def condicion(s : String) : Boolean = s.nonEmpty
  var mensaje : String = "Cadena vacía"
}

case class char(c : Char) extends Parser[Char] {
  def parseado(s:String) : Char = c
  def resto(s:String) : String = s.tail
  def condicion(s: String) : Boolean = s.head == c
  var mensaje : String = "El primer caracter no coincide con '" + c + "'"
}

object void extends Parser[Unit]{
  def parseado(s: String): Unit = ()
  def resto(s: String): String = s
  def condicion(s: String): Boolean = s.nonEmpty
  var mensaje : String = "Cadena vacía"
}

object letter extends charParser{
  def condicion(s: String) : Boolean = s.head.isLetter
  var mensaje : String = "El caracter a parsear no es una letra"
}

object digit extends charParser{
  def condicion(s: String) : Boolean = s.head.isDigit
  var mensaje : String = "El primer caracter no es un dígito"
}

// Luego se puede implementar como letter(s) <|> digit(s)
object alphaNum extends charParser{
  def condicion(s: String): Boolean = s.head.isLetterOrDigit
  var mensaje: String = "El caracter a parsear no es alfanumérico"
}

case class string(stringBase : String) extends Parser[String]{
  def parseado(s: String): String = s.substring(0, this.stringBase.length)
  def resto(s: String): String = s.substring(this.stringBase.length)
  def condicion(s : String) : Boolean = s.startsWith(this.stringBase)
  var mensaje: String = "La cadena a parsear no comienza con '" + this.stringBase + "'"
}