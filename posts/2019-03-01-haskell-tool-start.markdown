---
title: Getting started with Haskell tooling
---

## Environment options

Although configuration values are typically read from environment variables, they can be read from any
source that provides an instance of `Environment`:

```scala
trait Environment {
  def get(key: String): Option[String]
}
``` 

`Environment.fromEnvVars` provides normal access to environment variables. 
`Environment.fromMap(map: Map[String, String])` uses a prepopulated map of values, which is useful for unit testing.

## Error reporting

The library is invoked with the `Environment` instance injected via Reader Monad, and returns a `ValidatedNec[ConfiguredError, A]`.
Composition of `Configured` instances is done using applicative combination, eg

```scala
  implicit def configuredf[F[_]](implicit F: Applicative[F]): Configured[F, Endpoint] = (
    Configured[F, String].withSuffix("HOST"),
    Configured[F, Int].withSuffix("PORT")
  ).mapN(Endpoint.apply)
```

This means that if configuration errors are present, all errors are reported, rather than bailing at the first error discovered.
