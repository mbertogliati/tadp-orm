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
