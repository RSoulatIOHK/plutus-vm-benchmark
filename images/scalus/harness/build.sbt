// JMH harness for scalus-cek and scalus-jit (images/scalus/Dockerfile).
//
// Scalus core and the Scalus JIT: the released artifacts from Maven Central (SCALUS_VERSION),
// org.scalus::scalus and org.scalus::scalus-uplc-jit-compiler.
val scalusVersion = sys.env.getOrElse("SCALUS_VERSION", "1.4.1")

// The Scala version Scalus 1.4.1 is built with. The staging compiler of the JIT reads the TASTy of
// the Scalus classes, so it must not be older.
ThisBuild / scalaVersion := "3.3.8"

lazy val root = project
    .in(file("."))
    .enablePlugins(JmhPlugin)
    .settings(
      name := "pvb-scalus",
      libraryDependencies ++= Seq(
        "org.scalus" %% "scalus" % scalusVersion,
        "org.scalus" %% "scalus-uplc-jit-compiler" % scalusVersion
      )
    )
