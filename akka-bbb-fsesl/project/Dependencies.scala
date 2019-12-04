package org.bigbluebutton.build

import sbt._
import Keys._

object Dependencies {

  object Versions {
    // Scala
    val scala = "2.12.10"
    val junit = "5.6.0-M1"
    val scalactic = "3.1.0"

    // Libraries
    val akkaVersion = "2.6.0"
    val logback = "1.2.3"

    // Apache Commons
    val lang = "3.9"
    val codec = "1.13"

    // BigBlueButton
    val bbbCommons = "0.0.20-SNAPSHOT"
    val bbbFsesl = "0.0.7-SNAPSHOT"

    // Test
    val scalaTest = "3.1.0"
    val akkaTestKit = "2.6.0"
  }

  object Compile {
    val scalaLibrary = "org.scala-lang" % "scala-library" % Versions.scala
    val scalaCompiler = "org.scala-lang" % "scala-compiler" % Versions.scala

    val akkaActor = "com.typesafe.akka" % "akka-actor_2.12" % Versions.akkaVersion
    val akkaSl4fj = "com.typesafe.akka" % "akka-slf4j_2.12" % Versions.akkaVersion

    val logback = "ch.qos.logback" % "logback-classic" % Versions.logback
    val commonsCodec = "commons-codec" % "commons-codec" % Versions.codec

    val apacheLang = "org.apache.commons" % "commons-lang3" % Versions.lang

    val bbbCommons = "org.bigbluebutton" % "bbb-common-message_2.12" % Versions.bbbCommons excludeAll (
      ExclusionRule(organization = "org.red5"))
    val bbbFseslClient = "org.bigbluebutton" % "bbb-fsesl-client" % Versions.bbbFsesl
  }

  object Test {
    val scalaTest = "org.scalatest" %% "scalatest" % Versions.scalaTest % "test"
    val junit = "org.junit.jupiter" % "junit-jupiter-api" % Versions.junit % "test"
    val scalactic = "org.scalactic" % "scalactic_2.12" % Versions.scalactic % "test"
    val akkaTestKit = "com.typesafe.akka" %% "akka-testkit" % Versions.akkaTestKit % "test"
  }

  val testing = Seq(
    Test.scalaTest,
    Test.junit,
    Test.scalactic,
    Test.akkaTestKit)

  val runtime = Seq(
    Compile.scalaLibrary,
    Compile.scalaCompiler,
    Compile.akkaActor,
    Compile.akkaSl4fj,
    Compile.logback,
    Compile.commonsCodec,
    Compile.apacheLang,
    Compile.bbbCommons,
    Compile.bbbFseslClient) ++ testing
}
