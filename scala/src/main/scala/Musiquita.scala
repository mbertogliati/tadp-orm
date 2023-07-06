object Musiquita{
  import Musica._
  import EjemplosParser._

  val figuraSinPuntillo : Parser[Figura] = string("1/1").const(Redonda) <|> string("1/2").const(Blanca) <|> string("1/4").const(Negra) <|> string("1/8").const(Corchea) <|> string("1/16").const(SemiCorchea)
  val puntillo : Parser[Figura => ConPuntillo]  = char('.').const(ConPuntillo(_))
  val figura: Parser[Figura] = (figuraSinPuntillo <> puntillo.opt).map({
    case (figura,puntillo) => puntillo.getOrElse({figura: Figura => figura})(figura)})

  val notaSinModificador: Parser[Nota] = char('A').const(A) <|> char('B').const(B) <|> char('C').const(C) <|> char('D').const(D) <|> char('E').const(E) <|> char('F').const(F) <|> char('G').const(G)
  val modificador: Parser[Nota => Nota] = char('#').const({nota: Nota => nota.sostenido}) <|> char('b').const({nota: Nota => nota.bemol})

  val nota : Parser[Nota] = (notaSinModificador <> modificador.opt).map({
    case (nota,modificador) => modificador.getOrElse({nota: Nota => nota})(nota)})

  val tono: Parser[Tono] = (digit <> nota).map({
    case (octava,nota) => Tono(octava.asDigit,nota)})

  val sonido: Parser[Sonido] = (tono <> figura).map({
    case (tono,figura) => Sonido(tono,figura)})

  val silencio: Parser[Silencio] = char('_').const(Silencio(Blanca)) <|> char('-').const(Silencio(Negra)) <|> char('~').const(Silencio(Corchea))

  val acordeExplicito: Parser[Acorde] = (tono.sepBy(char('+')) <> figura).map({
    case (tonos: List[Tono],figura) => Acorde(tonos,figura)})

  val mayor : Parser[Tono => Figura => Acorde] = char('M').const({tono: Tono => figura => tono.nota.acordeMayor(tono.octava,figura)})
  val menor : Parser[Tono => Figura => Acorde] = char('m').const({tono: Tono => figura => tono.nota.acordeMenor(tono.octava,figura)})


  val acordeImplicito: Parser[Acorde] = (tono <> (mayor <|> menor) <> figura).map({
    case ((tono,mayorOMenor),figura) => mayorOMenor(tono)(figura)})

  val acorde: Parser[Acorde] = acordeExplicito <|> acordeImplicito

  val tocable: Parser[Tocable] = sonido <|> silencio <|> acorde

  val melodia: Parser[Melodia] = tocable.sepBy(char(' '))

}
