import scala.util.{Try, Success, Failure}

case class ResultadoParser[T](parseado: T, resto: String)

object anyChar {
  def apply(s: String): Try[ResultadoParser[Char]] = {
    Try[ResultadoParser[Char]] {
      new ResultadoParser[Char](s.head, s.tail)
    }
  }
}
