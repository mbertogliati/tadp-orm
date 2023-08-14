import scala.util.Try


object Parser{

  val void : Parser[Unit] = new Parser[Unit]({ s =>
    if (s.isEmpty) {
      throw new Exception("Cadena vacía")
    }
    ((),s)
  })

  val anyChar = new Parser(s => (s.head, s.tail))
  val char: Char => Parser[Char] = (c: Char) => anyChar.satisfies(_ == c)

  val letter: Parser[Char] = anyChar.satisfies(_.isLetter)
  val digit: Parser[Char] = anyChar.satisfies(_.isDigit)
  val alphaNum: Parser[Char] = digit <|> letter
  val string: String => Parser[String] = (str: String) => Parser({
    s =>
      if (!s.startsWith(str)) throw new Exception("La cadena no empieza con '" + str + "'")
      (str, s.substring(str.length))
  })

  def apply[T](parsear: String => (T, String)): Parser[T] = {
    new Parser[T](parsear)
  }
}

class Parser[+T](parsear: String => (T, String)){

  def apply(s: String): Try[(T, String)] =
    Try(parsear(s))

  def <|>[U >: T](p: Parser[U]) : Parser[U] = {
    new Parser[U](
      {s =>
        this(s).recoverWith(e => p(s)).get
      }
    )
  }
  def <>[U](p: Parser[U]) : Parser[(T,U)] =
    for(
      parseado1 <- this;
      parseado2 <- p
    ) yield (parseado1, parseado2)

  def ~>[U](p: Parser[U]) : Parser[U] =
    (this <> p).map({case (_,x) => x})

  def <~[U](p: Parser[U]) : Parser[T] =
    (this <> p).map({case (x,_) => x})

  def satisfies(condicion: T => Boolean) : Parser[T] =
    this.map({r =>
      if(!condicion(r)) throw new Exception("No se cumple la condicion")
      r
    })

  def opt : Parser[Option[T]] = {
    this.map(r => Some(r)) <|> Parser((None, _)) // void
  }

  def `*`: Parser[List[T]] =
    this.+ orDefault List()

  def + : Parser[List[T]] =
    for (
      parseado1 <- for (parseado <- this) yield List(parseado);
      parseado2 <- this.+ orDefault List()
    ) yield parseado1 ++ parseado2

  def sepBy(p: Parser[_]) : Parser[List[T]] =
    (this <> (p ~> this).*).map({case (cabeza,cola) => cabeza::cola})

  def const[U](valor : U): Parser[U] =
    this.map(_ => valor)

  def map[U](f: T => U): Parser[U] = {
    flatMap(r => new Parser((f(r), _)))
  }

  def flatMap[U](f: T => Parser[U]): Parser[U] =
    new Parser[U](
      {s =>
        this(s).flatMap({case (parseado,resto) => f(parseado)(resto)}).get
      }
    )

  def orDefault[U >: T](valor: U): Parser[U] =
    this <|> Parser.void.const(valor)
}