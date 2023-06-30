import scala.math.log10
import scala.util.{Failure, Success, Try}


case class ResultadoParser[+T](parseado: T, resto: String){
  def map[U](f: T => U): ResultadoParser[U] = {
    flatMap(r => ResultadoParser(f(r), resto))
  }
  def flatMap[U](f: T => ResultadoParser[U]): ResultadoParser[U] =
    f(parseado)
}


//Un parser ES una funcion que toma un string y devuelve un resultado parseado
//con la diferencia de que tiene más operaciones que una simple funcion
class Parser[+T](parsear: String => Try[ResultadoParser[T]]) extends (String => Try[ResultadoParser[T]]){
  override def apply(s: String): Try[ResultadoParser[T]] =
    parsear(s)


  def <|>[U >: T](p: String => Try[ResultadoParser[U]]) : Parser[U] = {
    new Parser[U](
      {s =>
          this(s).recoverWith(e => p(s))
      }
    )
  }

  def <>[U](p: String => Try[ResultadoParser[U]]) : Parser[(T,U)] =
      for(
        parseado1 <- this;
        parseado2 <- new Parser(p)
      ) yield (parseado1, parseado2)

  def ~>[U](p: String => Try[ResultadoParser[U]]) : Parser[U] =
      (this <> p).map(_._2)

  def <~[U](p: String => Try[ResultadoParser[U]]) : Parser[T] =
    (this <> p).map(_._1)

  def satisfies(condicion: T => Boolean) : Parser[T] =
    this.flatMap(parseado =>
      new Parser(s =>
        Try(ResultadoParser(parseado, s))
          .filter(r => condicion(r.parseado))))

  def opt : Parser[Option[T]] = {
    this.map(r => Some(r)) <|> {s : String => Success(ResultadoParser(None, s))}
  }

  def `*`: Parser[List[T]] =
    this.+ orDefault List()


  def + : Parser[List[T]] =
    for (
      parseado1 <- for (parseado <- this) yield List(parseado);
      parseado2 <- this.+ orDefault List()
    ) yield parseado1 ++ parseado2
  def sepBy(p: String => Try[ResultadoParser[_]]) : Parser[List[List[T]]] = {
    //TODO: elegir una solcion, la comentada usa cosas antes definidas mientras que la de ahora no.
    for(
      parseado1 <- for(resultado <- this.+ <~ new Parser(p).opt) yield List(resultado);
      parseado2 <- this.sepBy(p).orDefault(List())
    ) yield parseado1 ++ parseado2
  }

  /*
  new Parser[List[List[T]]](
    s =>
      ((this.+ <~ (new Parser(p).opt)).map(List(_)) <> this.sepBy(p).orDefault(List())).map(r => r._1 ++ r._2)(s)
  )*/

  def const[U](valor : U): Parser[U] =
    this.map(_ => valor)

  def map[U](f: T => U): Parser[U] = {
    flatMap(r => new Parser({s => Try(ResultadoParser(f(r), s))}))
  }

  def flatMap[U](f: T => Parser[U]): Parser[U] =
    new Parser[U](
      {s =>
        this(s).flatMap(r => f(r.parseado)(r.resto))
      }
    )

  def orDefault[U >: T](valor: U): Parser[U] =
    this <|> {s => Success(ResultadoParser(valor, s))}
}

object Main{
  val anyChar = new Parser({s => Try(ResultadoParser(s.head, s.tail))})
  val char: Char => Parser[Char] = (c: Char) => anyChar.satisfies(_ == c)
  val void = new Parser({s =>
    if(s.isEmpty){
      Failure(new RuntimeException("La cadena esta vacía"))
    }
    else{
      Try(ResultadoParser((), s))
    }
  })
  val letter: Parser[Char] = anyChar.satisfies(_.isLetter)
  val digit: Parser[Char] = anyChar.satisfies(_.isDigit)
  val alphaNum: Parser[Char] = digit <|> letter
  val string: String => Parser[String] = (str: String) => new Parser({
    s =>
        if (s.startsWith(str)){
          Try(ResultadoParser(str, s.substring(str.length)))
        } else {
          Failure(new Exception("La cadena no empieza con '" + str+"'"))
        }
  })

}
object Musiquita{
  /*val silencio: Parser[Char] = Main.char('_') <|> Main.char('-') <|> Main.char('~')
  val nombreNota: Parser[Char] = Main.anyChar.satisfies(c => c >= 'A' && c <= 'G')
  val nota = nombreNota <> (Main.char('#') <|> Main.char('b')).opt
  val tono = Main.digit <> nota
  val fraccion = (Main.digit <~ Main.char('/')) <> Main.digit
  val figura = fraccion.satisfies(tupla => tupla._1 == 1 && tupla._2 <= 16 && (log10(tupla._2)/log10(2.0) % 1 == 0))
  val sonido = tono <> figura
  val acordeExplicito = sonido.sepBy(Main.char('+'))*/
}




