import scala.util.{Try, Success, Failure}


case class ResultadoParser[T](parseado: T, resto: String){
  def map[U](f: T => U): ResultadoParser[U] =
    ResultadoParser[U](f(parseado), resto)
}


//Un parser ES una funcion que toma un string y devuelve un resultado parseado
//con la diferencia de que tiene más operaciones que una simple funcion
class Parser[T](parsear: (String => Try[ResultadoParser[T]])) extends (String => Try[ResultadoParser[T]]){
  override def apply(s: String) =
    parsear(s)
  def <|>[U](p: String => Try[ResultadoParser[U]]) : Parser[Either[T,U]] =
    new Parser[Either[T,U]](
      {s =>
        this(s).map(
          _.map[Either[T,U]](
            Left(_)))
          .orElse(p(s).map(
            _.map(Right(_))))
      }
    )
  def <>[U](p: String => Try[ResultadoParser[U]]) : Parser[(T,U)] =

    new Parser[(T,U)](
      {s =>
        this(s).flatMap(
          r1 => p(r1.resto).map(_.map((r1.parseado, _))))
      }
    )
  def ~>[U](p: String => Try[ResultadoParser[U]]) : Parser[U] =
    new Parser[U](
      {s =>
        this(s).flatMap(resultado => p(resultado.resto))
      }
    )

  def <~[U](p: String => Try[ResultadoParser[U]]) : Parser[T] =
    new Parser[T](
      {s =>
        this(s).flatMap(
          r1 => p(r1.resto).map(_.map(_ => r1.parseado)))
      }
    )
  def satisfies(condicion: T => Boolean) : Parser[T] =
    new Parser[T](
      {s =>
        this(s).filter(r => condicion(r.parseado)) match {
          case Success(resultado) if (condicion(resultado.parseado)) =>  Success(resultado)
          case Success(_) => Failure(new Exception("El resultado no cumple la condición"))
          case Failure(e) => Failure(e)
        }
      }
    )
  def opt : Parser[Option[T]] =
    new Parser[Option[T]](
      {s =>
        this(s) match {
          case Success(resultado) => Success(ResultadoParser[Option[T]](Some(resultado.parseado), resultado.resto))
          case Failure(_) => Success(ResultadoParser[Option[T]](None, s))
        }
      }
    )
  def `*`: Parser[List[T]] =
    new Parser[List[T]](
      {s =>
        this(s) match {
          case Success(resultado) => this.*(resultado.resto).map(resultado2 => ResultadoParser[List[T]](resultado.parseado::resultado2.parseado,resultado2.resto))
          case Failure(_) => Success(ResultadoParser(List(),s))
        }
      }
    )
  def + : Parser[List[T]] =
    new Parser[List[T]](
      {s =>
        this.*(s) match {
          case Success(ResultadoParser(List(),_)) => Failure(new Exception("No se pudo parsear al menos un elemento"))
          case Success(resultado) => Success(resultado)
        }
      }
    )
  def sepBy(separador: Parser[_]) : Parser[List[List[T]]] =
    new Parser[List[List[T]]](
      {s =>
        this.+(s).flatMap(
          resultado =>
            (separador ~> this.sepBy(separador)).opt(resultado.resto).map(
              _.map(
                option => resultado.parseado :: option.getOrElse(List())
              )))
      })
  def const[U](valor : U): Parser[U] =
    new Parser[U](
      {s =>
        this(s).map(_.map(_ => valor))
      }
    )
  def map[U](f: T => U): Parser[U] =
    new Parser[U](
      {s =>
        this(s).map(_.map(f))
      }
    )
}

class ParserFactory[T](condicion : (String => Boolean), resultado : (String => ResultadoParser[T]),mensaje : String){
  def crear() : Parser[T] =
    new Parser[T]({ s =>
      Try{
      if (condicion(s)) {
        resultado(s)

      } else {
        throw new Exception(mensaje)
      }}
    })
}
class CharParserFactory(condicion : (String => Boolean), mensaje: String) extends ParserFactory[Char](condicion, (s:String) => ResultadoParser(s.head, s.tail), mensaje)


object Main{

    val anyChar = new CharParserFactory((s:String) => s.nonEmpty, "Cadena vacía").crear()
    val char = (c: Char) => new CharParserFactory((s: String) => s.head == c, "El caracter a parsear no coincide con '" + c + "'").crear()
    val void = new ParserFactory[Unit](
      (s: String) => s.nonEmpty,
      (s: String) => ResultadoParser((), s),
      "Cadena vacía").crear()
    val letter = new CharParserFactory((s: String) => s.head.isLetter, "El caracter a parsear no es una letra").crear()
    val digit = new CharParserFactory((s: String) => s.head.isDigit, "El caracter a parsear no es un dígito").crear()
    val alphaNum = new CharParserFactory((s: String) => s.head.isLetterOrDigit, "El caracter a parsear no es alfanumérico").crear()
    val string = (s: String) => new ParserFactory[String](
      (str: String) => str.startsWith(s),
      (str: String) => ResultadoParser(str.substring(0, s.length), str.substring(s.length)),
      "La cadena a parsear no comienza con '" + s + "'").crear()

}




