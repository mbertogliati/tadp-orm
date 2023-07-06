import scala.util.{Success, Try}

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
  def sepBy(p: String => Try[ResultadoParser[_]]) : Parser[List[T]] =
    (this <> (new Parser(p) ~> this).*).map({case (cabeza,cola) => cabeza::cola})


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