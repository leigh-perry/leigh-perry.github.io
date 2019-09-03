---
title: Design of a Configuration Library
---

As a rule of thumb, there is a configuration library for every five developers (and a logging library for every two). 
This blog is about my configuration library, called [Conduction](https://github.com/leigh-perry/conduction). 

# Justification

Why write another configuration library?
Well, in the age of containerised cloud deployments, programs usually need to read their configuration from environment variables.
But they need to read that configuration into rich data structures, such as:
```scala
  final case class AppConfig(
    appName: String,
    endpoint: Endpoint,
    role: Option[AppRole],
    intermediates: List[TwoEndpoints],
  )

  final case class Endpoint(host: String, port: Int)
  final case class TwoEndpoints(ep1: Endpoint, ep2: Endpoint)

  // A String newtype
  final case class AppRole(value: String) extends AnyVal
```

I wanted to be able to, in one step, read the configuration from a set of environment variables like:
```bash
export MYAPP_APP_NAME=someAppName
export MYAPP_ENDPOINT_HOST=12.23.34.45
export MYAPP_ENDPOINT_PORT=6789
export MYAPP_ROLE_OPT=somerole
export MYAPP_INTERMEDIATE_COUNT=2
export MYAPP_INTERMEDIATE_0_EP1_HOST=11.11.11.11
export MYAPP_INTERMEDIATE_0_EP1_PORT=6790
export MYAPP_INTERMEDIATE_0_EP2_HOST=22.22.22.22
export MYAPP_INTERMEDIATE_0_EP2_PORT=6791
export MYAPP_INTERMEDIATE_1_EP1_HOST=33.33.33.33
export MYAPP_INTERMEDIATE_1_EP1_PORT=6792
export MYAPP_INTERMEDIATE_1_EP2_HOST=44.44.44.44
export MYAPP_INTERMEDIATE_1_EP2_PORT=6793
```

into an instance of `AppConfig`.

Conduction is the library that lets me do that, via:
```scala
      Configured[IO, AppConfig]
        .value("MYAPP")
        .run(Environment.fromEnvVars)
```

You can read more over at the Conduction [documentation page](https://github.com/leigh-perry/conduction/blob/master/README.md).

# Aims

In writing the library, I had some ambitions.

- I wanted it to be pure-functional.
- Extensibility. Allow the user to
  - add new primitive types,
  - add new complex types,
  - add other _effects_ beyond `Option`, `List`, `Either`, etc.
  - add new ways of providing the configuration, beyond just environment variables or JVM system properties.
- Provide complete validation. If there are multiple configuration errors, report them all rather than bailing at the first.

# Implementation

A standard approach for extensibility in functional programming is the combination of typeclasses and inductive derivation.

## First cut

I started by defining the typeclass:
```scala
trait Configured[A] {
  def value(env: Environment, name: String): ValidatedNec[ConfiguredError, A]
}
```

This trait covers most of the aims of the library.
- It provides the basic mechanism of reading a value of type `A`.
- It defines a family of configuration errors in the ADT `ConfiguredError`.
- It accumulates multiple errors via the `ValidatedNec[ConfiguredError, A]` return value.
- It allows the value to be read from a generalised input `Environment`.

I provided a set of standard instances for out-of-the-box supported primitive types:
```scala
object Configured {
  implicit val configuredInt: Configured[Int] =
    new Configured[Int] {
      override def value(env: Environment, name: String): ValidatedNec[ConfiguredError, Int] =
        // implementation elided
    }

  // ...
```

I then added some inductively derived types, meaning types that can be built out of data types that already had a `Configured` instance:
```scala
object Configured {
  // ...

  implicit def `Configured for Option`[A: Configured]: Configured[Option[A]] =
    new Configured[Option[A]] {
      override def value(env: Environment, name: String): ValidatedNec[ConfiguredError, Option[A]] =
        Configured[A]
          .value(env, s"${name}_OPT")
          .fold(
            c => if (c.forall(_.isInstanceOf[ConfiguredError.MissingValue])) None.validNec else c.invalid,
            a => a.some.valid
          )
    }

  // ...
```

Finally, to read a case class of your own definition, such as for `Endpoint`:


you need to define how to read its component parts:
```scala
object Endpoint {
  implicit def configuredf[F[_]](implicit F: Applicative[F]): Configured[F, Endpoint] = (
    Configured[F, String].withSuffix("HOST"),
    Configured[F, Int].withSuffix("PORT")
  ).mapN(Endpoint.apply)
}
```

This took care of:
- environment variable naming, via `.withSuffix()`,
- accumulation of multiple errors, via the applicative combinator `mapN`.

## Factoring out the Conversion

Although the implementations are elided in the type class instances above, I found that there was an amount of code duplication between them.
My first approach to this was to factor the code out as a function that supported conversion from `String` to any type `A`:
```scala
  private def eval[A](env: Environment, name: String, f: String => A): ValidatedNec[ConfiguredError, A] =
    env.get(name)
      .map {
        s =>
          Either.catchNonFatal(f(s))
            .fold(
              _ => ConfiguredError.InvalidValue(name, s).invalidNec[A],
              _.validNec[ConfiguredError]
            )
      }.getOrElse(ConfiguredError.MissingValue(name).invalidNec[A])
```

I decided then this this itself should be represented by its own typeclass called `Conversion`. 
`Configured` would then build upon `Conversion`. 
So I did.
```scala
trait Conversion[A] {
  def of(s: String): Either[String, A]
}
```

That way, to add support for a new primitive type, the user only had to add a new instance of `Conversion`. 
Even better, they could repurpose an existing type for their new type via `Functor.map`:
```scala
  final case class Latitude(value: Double) extends AnyVal

  object Latitude {
    implicit def conversion: Conversion[Latitude] =
      Conversion[Double].map(Latitude.apply)
  }
```

## Moving to Reader monad

It is a long established fact that a reader will be distracted by the readable content of a page when looking at its layout. The point of using Lorem Ipsum is that it has a more-or-less normal distribution of letters, as opposed to using 'Content here, content here', making it look like readable English.

# Looking back

It is a long established fact that a reader will be distracted by the readable content of a page when looking at its layout. The point of using Lorem Ipsum is that it has a more-or-less normal distribution of letters, as opposed to using 'Content here, content here', making it look like readable English. Many desktop publishing packages and web page editors now use Lorem Ipsum as their default model text, and a search for 'lorem ipsum' will uncover many web sites still in their infancy. Various versions have evolved over the years, sometimes by accident, sometimes on purpose (injected humour and the like).
