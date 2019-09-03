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

It is a long established fact that a reader will be distracted by the readable content of a page when looking at its layout. The point of using Lorem Ipsum is that it has a more-or-less normal distribution of letters, as opposed to using 'Content here, content here', making it look like readable English.

## First cut

It is a long established fact that a reader will be distracted by the readable content of a page when looking at its layout. The point of using Lorem Ipsum is that it has a more-or-less normal distribution of letters, as opposed to using 'Content here, content here', making it look like readable English.

## Factoring out the Conversion

It is a long established fact that a reader will be distracted by the readable content of a page when looking at its layout. The point of using Lorem Ipsum is that it has a more-or-less normal distribution of letters, as opposed to using 'Content here, content here', making it look like readable English.

## Moving to Reader monad

It is a long established fact that a reader will be distracted by the readable content of a page when looking at its layout. The point of using Lorem Ipsum is that it has a more-or-less normal distribution of letters, as opposed to using 'Content here, content here', making it look like readable English.

# Looking back

It is a long established fact that a reader will be distracted by the readable content of a page when looking at its layout. The point of using Lorem Ipsum is that it has a more-or-less normal distribution of letters, as opposed to using 'Content here, content here', making it look like readable English. Many desktop publishing packages and web page editors now use Lorem Ipsum as their default model text, and a search for 'lorem ipsum' will uncover many web sites still in their infancy. Various versions have evolved over the years, sometimes by accident, sometimes on purpose (injected humour and the like).
