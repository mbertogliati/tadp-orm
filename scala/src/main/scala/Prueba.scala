import scala.math.log10
import scala.util.{Failure, Success, Try}


case class ResultadoParser[+T](parseado: T, resto: String){
  def map[U](f: T => U): ResultadoParser[U] =
    ResultadoParser[U](f(parseado), resto)
}


//Un parser ES una funcion que toma un string y devuelve un resultado parseado
//con la diferencia de que tiene más operaciones que una simple funcion
class Parser[+T](parsear: (String => Try[ResultadoParser[T]])) extends (String => Try[ResultadoParser[T]]){
  override def apply(s: String) =
    parsear(s)

  //cuando dos parsers se componen, se aplica uno detras del otro. El resultado final es el que dicta la Transformacion
  def componer[V,U](transformacion: (T,U) => V)(p: String => Try[ResultadoParser[U]]) : Parser[V] ={
    new Parser[V](
      { s =>
        for(
          resultadoT <- this(s);
          resultadoU <- p(resultadoT.resto)
        ) yield ResultadoParser(transformacion(resultadoT.parseado,resultadoU.parseado),resultadoU.resto)
        //this(s).flatMap(r => parserRecibido.map(v => funcionResultado(r.parseado,v))(r.resto))
      }
    )
  }


  def <|>[U >: T](p: String => Try[ResultadoParser[U]]) : Parser[U] = {
    new Parser[U](
      {s =>
          this(s).recoverWith(e => p(s))
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
      for(
        resultado <- this(s) if condicion(resultado.parseado)
      ) yield resultado
        //this(s).filter(r => condicion(r.parseado))
      }
    )
  def opt : Parser[Option[T]] = {
    new Parser[Option[T]](
    { s =>
        this.map(r => Some(r))(s).recoverWith(e => Success(ResultadoParser(None, s)))
    })
  }

  //(this <|> ({s : String => Success(ResultadoParser(None, s))})).map(_.toOption)

  def `*`: Parser[List[T]] =
      this.componer((t:T,ts:List[T]) => t :: ts)(s => this.*(s)).orDefault(List())

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
    this.map(_ => valor)

  def map[U](f: T => U): Parser[U] =
    new Parser[U](
      {s =>
        this(s).map(_.map(f))
      }
    )
  //Este lo agregue yo porque me servia
  def orDefault[U >: T](valor: U): Parser[U] =
    new Parser[U](
    s =>
      this(s).orElse(Success(ResultadoParser[U](valor, s)))
    )
}

object Main{

  val anyChar = new Parser({s => Try(ResultadoParser(s.head, s.tail))})
  val char = (c: Char) => anyChar.satisfies(_ == c)
  val void = new Parser({s =>
    if(s.isEmpty){
      Failure(new RuntimeException("La cadena esta vacía"))
    }
    else{
      Try(ResultadoParser((), s))
    }
  })
  val letter = new Parser({s => anyChar.satisfies(_.isLetter)(s)})
  val digit = new Parser({s => anyChar.satisfies(_.isDigit)(s)})
  val alphaNum = digit <|> letter
  val string = (str: String) => new Parser({
    s =>
        if (s.startsWith(str)){
          Try(ResultadoParser(str, s.substring(str.length)))
        } else {
          Failure(new Exception("La cadena no empieza con '" + str+"'"))
        }
  })

}
object Musiquita{
  val silencio = Main.char('_') <|> Main.char('-') <|> Main.char('~')
  val nombreNota = Main.anyChar.satisfies(c => c >= 'A' && c <= 'G')
  val nota = nombreNota <> (Main.char('#') <|> Main.char('b')).opt
  val tono = Main.digit <> nota
  val fraccion = (Main.digit <~ Main.char('/')) <> Main.digit
  val figura = fraccion.satisfies(tupla => tupla._1 == 1 && tupla._2 <= 16 && ((log10(tupla._2)/(log10(2.0)) % 1 == 0)))
  val sonido = tono <> figura
  val acordeExplicito = sonido.sepBy(Main.char('+'))
}




