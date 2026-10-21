// JMH harness for scalus-cek and scalus-jit (images/scalus/Dockerfile).
//
// Scalus core: the released artifact from Maven Central (SCALUS_VERSION).
// Scalus JIT: scalus-uplc-jit-compiler is not published, so its sources at the same tag
// (SCALUS_SRC, cloned by the Dockerfile) are compiled here, against the Maven core.
val scalusVersion = sys.env.getOrElse("SCALUS_VERSION", "1.4.0")
val scalusSrc = file(sys.env.getOrElse("SCALUS_SRC", "/bench/scalus-src"))

// The Scala version Scalus 1.4.0 is built with. The staging compiler of the JIT reads the TASTy of
// the Scalus classes, so it must not be older.
ThisBuild / scalaVersion := "3.3.8"

lazy val root = project
    .in(file("."))
    .enablePlugins(JmhPlugin)
    .settings(
      name := "pvb-scalus",
      Compile / unmanagedSourceDirectories +=
          scalusSrc / "scalus-uplc-jit-compiler" / "src" / "main" / "scala",
      libraryDependencies ++= Seq(
        "org.scalus" %% "scalus" % scalusVersion,
        "org.scala-lang" %% "scala3-staging" % scalaVersion.value,
        "org.scala-lang" %% "scala3-compiler" % scalaVersion.value
      )
    )
