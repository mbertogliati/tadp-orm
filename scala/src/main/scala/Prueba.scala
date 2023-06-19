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

  //cuando dos parsers se componen, se aplica uno detras del otro. El resultado final es el que dicta la funcionResultado
  def componer[V,U](funcionResultado: (T,U) => V)(p: String => Try[ResultadoParser[U]]) : Parser[V] ={
    val parserRecibido = new Parser[U](p)
    new Parser[V](
      { s =>
        this(s).flatMap(r => parserRecibido.map(v => funcionResultado(r.parseado,v))(r.resto))
      }
    )
  }


  def <|>[U](p: String => Try[ResultadoParser[U]]) : Parser[Either[U,T]] = {
    val parserRecibido = new Parser[U](p)
    new Parser[Either[U,T]](
      {s =>
        this.map[Either[U,T]](Right(_))(s).orElse(parserRecibido.map[Either[U,T]](Left(_))(s))
      }
    )
  }

  def <>[U](p: String => Try[ResultadoParser[U]]) : Parser[(T,U)] = {
    this.componer((t: T, u: U) => (t, u))(p)
  }

  def ~>[U](p: String => Try[ResultadoParser[U]]) : Parser[U] =
      this.componer((t:T,u:U) => u)(p)

  def <~[U](p: String => Try[ResultadoParser[U]]) : Parser[T] =
    this.componer((t:T,u:U) => t)(p)

  def satisfies(condicion: T => Boolean) : Parser[T] =
    new Parser[T](
      {s =>
        this(s).filter(r => condicion(r.parseado))
      }
    )
  def opt : Parser[Option[T]] =
    new Parser[Option[T]](
      (this <|> ({s : String => Success(ResultadoParser(None, s))})).map(_.toOption)
    )
  def `*`: Parser[List[T]] =
    new Parser[List[T]](
      this.componer((t:T,ts:List[T]) => t :: ts)(s => this.*(s)).orDefault(List())
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

        this.+.componer((t:List[T],ts:List[List[T]]) => t :: ts)(
          s => (separador ~> this.sepBy(separador)).orDefault(List())(s)
        )

  def const[U](valor : U): Parser[U] =
    new Parser[U](
        this.map(_ => valor)
    )
  def map[U](f: T => U): Parser[U] =
    new Parser[U](
      {s =>
        this(s).map(_.map(f))
      }
    )
  //Este lo agregue yo porque me servia
  def orDefault(valor: T): Parser[T] =
    new Parser[T](
    s =>
      this(s).orElse(Success(ResultadoParser(valor, s)))
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




