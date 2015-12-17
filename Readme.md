# JSON Transformation Language

This is a repository for draft specifications for the JSON Transformation Language (JTL).

JTL can be used to transform one JSON document into one or more JSON documents. It can also be used for JSON-like native data structures. You might use JTL for:

- Inference of missing values, coercion, etc. as a prerequisite for further processing
- Transformation of underlying canonical data into presentational forms, e.g. a human-readable summary
- Mediation between APIs and versions of APIs
- Validation of JSON data or data which can be faithfully expressed in JSON

## What it looks like

JTL's 'native' format is JSON, and a transformation looks like this:

    {
      "JTL" : "transformation",
      "templates": [
        {
          "JTL": "template",
          "match": ... ,
          "produce": ... ,
        },
        ...
      ]
    }

A compact syntax optimised for ease of reading and writing which maps to this native format is also in development. It looks like this:

    template {
      match: type()->eq('array'),
      produce:
        ./*[ type()->eq('object') ]
        ->applyTemplates()
        ->array()
    }

## How it works

JTL applies **templates** to elements within input documents. These templates can be thought of as 'rules'. The template in the example above means: "When you find an array, return an array containing all the children of the original array that are objects". Because applyTemplates is called, arrays within those objects will also be processed.

If you've ever used XSLT, this and many other patterns will will be familiar. However, because of the differences between JSON and XML (and some specification differences), JTL offers more flexibility, more simplicity, and a shallower learning curve.

## Specifications

The **JTL Core** specification is currently in development. It can be found at `spec/draft.md`. A test suite can be found at `poc/share/instructionTests.js`.

The **JTL Syntax** specification is currently in development. Its grammar can currently be found at `poc/share/jtls.pgx`.

Further extensions, such as regular expressions, file IO, and HTTP are awaiting specification.

## Implementations

JTL is intended to have few requirements for implementation, to facilitate adoption.

- The core specification concentrates on the minimum required to execute a transformation language. Any language which can read JSON into native data structures should be capable of implementing JTL.
- Most features of the language will be made available as modular extensions.
- Some extensions will have higher requirements - for example, **JTL Syntax** requires a regular expression engine to implement (but JTL produced with JTL Syntax can be turned into 'raw' JTL for use in other environments).
- In some cases it may be possible to provide 'polyfill' implementations for syntactic sugar and efficiency features, requiring no additional native code writing for extensions.

Alongside a specification, proof-of-concept implementations are being built:

- an implementation in Perl5 is being built under `poc/`; this implements both JTL and the JTL Syntax
- a Javascript implementation is being built under `poc-js/`; this implements JTL Core only
