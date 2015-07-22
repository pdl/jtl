# JSON Transformation Language (Core)

This document will describe the JSON Transformation Language, hereafter JTL.

## Introduction

JSON is a widely used data interchange format. It has a low overhead and is easily translated into data structures native to a variety of programming languages. Although JSON does not carry inherent semantic value, any given JSON document in its context may have semantic value as defined by its author and intended recipient (often by agreement through a documented API).

However, the processing of JSON data is typically opaque. There is a growing need to be able to perform operations on JSON in a language-independent manner, particularly with the growth of web and native apps, to wirte equivalent functions in servers, client web page code and in native client apps. One extreme is to write the code three times. Another extreme is to enforce the use of ECMAScript in all three contexts to avoid duplication. There are many circumstances in which neither is sensible.

The purpose of JTL is to create machine-readable instructions for transforming one JSON document into another. Those instructions will be in JSON.

- Inference of missing values, coercion, etc. as a prerequisite for further processing
- Transformation of underlying canonical data into presentational forms, e.g. a human-readable summary
- Mediation between APIs and versions of APIs
- Validation of JSON data or data which can be faithfully expressed in JSON

Extensions to JTL may provide further mechanisms by which JSON processing can trigger other events - 'side-effects'. Use of such extensions will be by the common agreement of the transformation and the implementation (for example, a transformation may be denied HTTP access if it is not sufficiently trusted).

### XML, XSLT, JSON and JTL

JTL takes its inspiration from XSLT, and will attempt to follow its conventions and principles except insofar as:

- The differences between JSON and XML would render the precedent meaningless, cumbersome, or substantially more difficult to implement.
- A precedent in XSLT may be achievable in another, simpler or more powerful way and there is no compelling case for replicating the feature twice.
- The feature is one which XSLT processors are not required to implement.
- There is substantial evidence that the feature was poorly designed.

Notwithstanding the above, a minimal usable version of JTL may be arrived at before feature-parity with XSLT is achieved, especially where it is not strictly necessary for XSLT features to be in the JTL core.

Using XSLT as an inspiration provides several benefits:

- Familiar concepts and naming conventions should make for a smooth learning curve for users, core developers and implementers
- Maintaining a similar approach gives confidence in the generality of application
- XSLT itself provides a reference for what features a transformation language is likely to need, and community extensions point to directions for new innovation
- By adapting an existing paradigm, innovation rests on a solid base

## Processor and Documents

A JTL document is a JSON document whose root node is a hash and whose structure is defined in this specification. It is read by a JTL Processor, and when applied to a JSON document called a Source Document, the Processor produces one or more JSON documents called the Result Documents. Source and Result Documents may have any sort of JSON node as their root and may contain any legal JSON content.

## Components of JTL

This document describes the Core JTL. Once this document is complete, a processor which fulfils the requirements of a processor as described in this document implements JTL.

Further documents will describe extensions to JTL which processors should implement.

- StrictNumbers
- StrictBooleans
- Math
- String
- Regex
- ArbitraryIntegers
- ArbitraryFloats
- Alien
- HTTP

## Core Concepts

## Nodes

The JSON value types Object, Array, String, Number, True, False and Null are considered to be nodes in the context of the document to which they belong. A node has a path, a value, and a document.

The path is an expression of the absolute position at which the node can be found from the context of the document.

### Instructions

An instruction is represented as a JSON hash with a key JTL whose value is the name of the instruction. Other keys and values may be present, depending on the instruction.

Instructions have attributes.

An instruction, when executed, MUST produce one of the following results:

- A nodelist, which may have zero or more nodes. This may be used in another calculation.
- A void sesult, indicating that no result was expected. This is distinct from an empty nodelist.

### Evaluation

An evaluation returns a list of results. It is represented as a JSON array, and consists of a series of instructions, which are executed in order.

An instruction may trigger multiple evaluatins, foe example: a `select` to determine the nodes to perform the instruction on, followed by a `produce` on each of the nodes.

In some cases, it is significant if there are empty nodelists, for example in the case of `eq`.

### Production

A production is an evaluation which will return a nodelist containing a single value, or a list of values.

The results of a production may not always be acceptable to the context in which they are placed:

- In an array any results are permitted, including an empty list
- In a hash only a list of pairs is acceptable. The list may be empty.
- In a pair, a list of two items is required. The first, the key, must be a scalar, and the second item, the value, may be undefined.
- The templates attribute takes a production in which no values may be returned.

## Truth

???

JTL makes a distinction between the JSON true value and truthiness.

A NodeList is always truthy if it has members, even if none of those members are truthy. If it has no members, it is falsy.

A Node is truthy if its value is truthy.

A Hash is truthy if it has properties, even if none of the values are truthy.

An Array is truthy if it has members, even if none of them are truthy.

A Number is truthy if it is not zero.

A string is truthy if it is not empty.

Undefined is never truthy.

### Literal values

If, instead of a production, you wish to create a literal value. Literal values are possible within strings, e.g. "\"foo\"", "[]", "{}".

## Productive Instructions

The following instructions create a nodelist of one item

### object
### pair
### array
### scalar
### string
 - value
### number
 - value
### boolean
 - value
### true
### false
### undefined

## Instructions for flow control and calculation

### template
 - match
 - produce
### apply-templates
 - select
 - name
### apply-template / call-template
 - select
 - name
### for-each
 - select
 - produce
### if
 - test
### choose
### when
 - test
 - produce
### otherwise
 - produce
### copy-of
### type
 - select
### context
### current
### source
(I have forgotten what I intended this to mean. PErhaps it will return.)
### union
 - select
 - test ??? (union of values vs union of nodes)
### intersection
 - select
 - compare
 - test ??? (union of values vs union of nodes)
#### filter
 - select
 - test
(isn't this just foreach?)

### unique
 - select
### sort
 - select
(note that this is different from sort in XSLT)

## Instructions which always return booleans

### empty, nonempty
  - select
### empty-list, nonempty-list
  - select
### zero, nonzero
  - select
### not
 - test
### or, and
 - select
 - compare
### equal
 - select
### greater-than, less-than
 - select

## Void instructions
### variable
 - select/produce
### message
### param, with-param

## XML vs JSON

- Namespaces
- Attributes
- Processing instructions
- Comments
- Whitespace
- CDATA sections
- Mixed content
- Concatenation of text nodes
- Handling of certain control characters
- DTDs and Stylesheets


### Prioritisation
node() | value()
scalar() | hash() | array()
number() | string()


### Security

At no point is an implementation required by this specification to retrieve external resources.

### See Also

- XSLT: Although it is theoretically possible to convert almost any JSON to an XML representation, use XSLT to transform it to an XML representation of the target document, then convert back to JSON, this is likely to be unintuitive to write and requires an XSLT implementation.
- JSONT: This requires a javascript implementation, and so is not truly language-agnostic. Specification is minimal. (cf JSON::T)
- JOLT: Seems to be mostly
- json2json: written in coffeescript, not sure of its completeness
