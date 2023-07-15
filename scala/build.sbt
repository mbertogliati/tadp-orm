name := "scala"

version := "1"

organization := "edu.ar.utn.tadp"

scalaVersion := "2.13.10"

libraryDependencies ++= Seq(
  "org.scalatest" %% "scalatest" % "3.2.9" % "test",
  "org.scalactic" %% "scalactic" % "3.2.9"
)

lazy val modeloMusica = ProjectRef(uri("https://github.com/tadp-utn-frba/tadparser-musica-modelo.git#main"),"tadparser-musica-modelo")

lazy val root = (project in file("."))
  .dependsOn(modeloMusica)