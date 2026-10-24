// JMH harness for scalus-cek and scalus-jit (images/scalus/Dockerfile).
//
// Scalus core: SCALUS_VERSION, built from source at SCALUS_SHA by the Dockerfile and published to
// the local Maven repository, so it resolves from there.
// Scalus JIT: scalus-uplc-jit-compiler is not published, so its sources at the same commit
// (SCALUS_SRC, cloned by the Dockerfile) are compiled here, against that core.
val scalusVersion = sys.env.getOrElse("SCALUS_VERSION", "1.4.1-SNAPSHOT")

ThisBuild / resolvers += Resolver.mavenLocal
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
