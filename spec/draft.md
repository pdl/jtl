# JSON Transformation Language (Core)

This document will describe the JSON Transformation Language, hereafter JTL.

The purpose of JTL is to create machine-readable instructions for transforming one JSON document into another. Those instructions will be in JSON.

JTL takes its inspiation from XSLT, and will attempt to follow its conventions and principles except insofar as:

- The differences between JSON and XML would render the precedent meaningless, cumbersome, or substantially more difficult to implement.
- A precedent in XSLT may be achievable in another, simpler way and there is no compelling case for replicating the feature twice.
- The feature is one which XSLT processors are not required to implement.
- There is substantial evidence that the feature was poorly designed.

Notwithstanding the above, a minimal usable version of JTL may be arrived at before feature-parity with XSLT is achieved, especially where it is not strictly necessary for XSLT features to be in the JTL core.

## Processor and Documents

A JTL document is a JSON document whose root node is a hash and whose structure is defined in this specification. It is read by a JTL Processor, and when applied to a JSON document called a Source Document, the Processor produces a JSON document called the Result Document. Source and Result Documents may have any sort of JSON node as their root and may contain any legal JSON content.


## Components of JTL

This document describes the Core JTL. Once this document is complete, a processor which implements this document implements JTL.

- StrictNumbers
- StrictBooleans
- Math
- String
- Regex
- ArbitraryIntegers
- ArbitraryFloats
- Alien

## Nodes

The JSON value types Object, Array, String, Number, True, False and Null are considered to be nodes in the context of the document to which they belong. A node has a path, a value, and a document.

The path is an expression of the absolute position at which the node can be found from the context of the document.

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

## Concepts

### Instructions

An instruction is represented as a JSON hash with a key JTL whose value is the name of the instruction. Other keys and values are typically present depending on the instruction.

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

### Selection

A selection is a union of nodes.

### Literal values

If, instead of a production, you wish to create a literal value. Literal values are possible within strings, e.g. "\"foo\"", "[]", "{}".

## Productive Instructions

The following instructions create a nodelist of one item

### object
### pair
### array
### scalar
### string
### number
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
### otherwise
### copy-of

## Void instructions
### variable
 - select/produce
### message

## XSLT Elements not represented as instructions
### sort
### param, with-param


### JPath functions

### context
### current
### source
### union
 - select
### unique
 - select
### empty(), nonempty
### zero(), nonzero
### or, and, not
 - test
### equal
### greater-than(), less-than
### type

## XSLT vs JSON

Namespaces
Attributes
Processing instructions
Comments
whitespace
Mixed content
DTDs and Stylesheets


### Prioritisation
node() | value()
scalar() | hash() | array()
number() | string()



### Security

At no point is an implementation required to retrieve external resources.

### See Also

- XSLT. Although it is theoretically possible to convert almost any JSON to an XML representation, use XSLT to transform it to an XML representation of the target document, then convert back to JSON, this is likely to be unintuitive to write and requires an XSLT implementation.
- JSONT This requires a javascript implementation, and so is not truly language-agnostic.
-
