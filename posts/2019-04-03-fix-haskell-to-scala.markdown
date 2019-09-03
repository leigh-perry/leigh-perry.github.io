---
title: Converting fix function to Fix data structure
---

Configuration is via a configuration library that inductively derives the configuration for known
types. It is able to decode nested classes of arbitrary complexity from key-value pairs, typically
environment variables or system properties.

For example, if your app has the following configuration:

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
