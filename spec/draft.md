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

### Production

A production is an instruction which will return a single value, or a list of values. A production is represented as a JSON array, and consists of a series of instructions, which are executed in order.

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

The following instructions return a value

### object
### pair
### array
### scalar
### string
### number
### true
### false
### undefined
### copy-of

## Instructions for flow control and calculation
### template
### apply-templates
### apply-template / call-template
### variable
### for-each
### if
### choose
### when
### otherwise

## Other instructions
### message

## XSLT Elements not represented as instructions
### sort
### param, with-param


### JPath functions

select()
context()
current()
source()
union()
unique()
empty(), nonempty()
zero(), nonzero()
or(), and(), not()
equal()
greater-than(), less-than()
type()

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
