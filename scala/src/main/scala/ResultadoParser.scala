import scala.util.Try

case class ResultadoParser[+T](parseado: T, resto: String){

  def map[U](f: T => U): ResultadoParser[U] = {
    flatMap(r => ResultadoParser(f(r), resto))
  }
  def flatMap[U](f: T => ResultadoParser[U]): ResultadoParser[U] =
    f(parseado)
}