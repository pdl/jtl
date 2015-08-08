# JSON Transformation Language (Core)

This document will describe the JSON Transformation Language, hereafter JTL.

## Introduction

JSON is a widely used data interchange format. It is easily parsed and maps naturally into data structures native to a variety of programming languages. Although JSON does not carry inherent semantic value, any given JSON document in its context may have semantic value as defined by its author and as interpreted by its recipient (often by agreement through a documented API).

However, the processing of JSON data is typically opaque. There is a growing need to be able to perform operations on JSON in a language-independent manner, particularly with the growth of web and native apps, to write equivalent functions in servers, client web page code and in native client apps. One extreme is to write the code three times. Another extreme is to enforce the use of ECMAScript in all three contexts to avoid duplication. There are many circumstances in which neither is sensible.

The purpose of JTL is to create machine-readable instructions for transforming one JSON document into another. Those instructions will be in JSON.

- Inference of missing values, coercion, etc. as a prerequisite for further processing
- Transformation of underlying canonical data into presentational forms, e.g. a human-readable summary
- Mediation between APIs and versions of APIs
- Validation of JSON data or data which can be faithfully expressed in JSON

Extensions to JTL may provide further mechanisms by which JSON processing can trigger other events - 'side-effects'. Use of such extensions will be by the common agreement of the transformation and the implementation (for example, a transformation may be denied HTTP access if it is not sufficiently trusted).

### XML, XSLT, JSON and JTL

JTL takes its inspiration from XSLT, and will attempt to follow its conventions and principles except insofar as:

- The differences between JSON and XML and the contexts in which they are used would render the precedent meaningless, cumbersome, or substantially more difficult to implement.
- A precedent in XSLT may be achievable in another, simpler or more powerful way and there is no compelling case for replicating the feature twice.
- The feature is one which XSLT processors are not required to implement.
- The feature appears to have been poorly understood by implementors or by users.

Notwithstanding the above, a minimal usable version of JTL does not depend on complete feature-parity (or feature-equivalence) with XSLT, especially where it is not strictly necessary for XSLT features to be in the JTL core.

Using XSLT as an inspiration provides several benefits:

- Familiar concepts and naming conventions should make for a smooth learning curve for users, core developers and implementers
- Maintaining a similar approach gives confidence in the generality of application
- XSLT itself provides a reference for what features a transformation language is likely to need, and subsequent versions and community extensions point to directions for new innovation
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

- A nodelist, which may contain zero or more nodes. This may be used in another calculation.
- A void sesult, indicating that no result was expected. This is distinct from an empty nodelist.

### Evaluation

An evaluation returns a list of results. It is represented as a JSON array, and consists of a series of instructions, which are executed in order.

An instruction may trigger multiple evaluatins, foe example: a `select` to determine the nodes to perform the instruction on, followed by a `produce` on each of the nodes.

In some cases, it is significant if there are empty nodelists, for example in the case of `eq`.

### Production

A production is an evaluation which will return a nodelist containing a single value, or a list of values.

The results of a production may not always be acceptable to the context in which they are placed, for example:

- In an array any results are permitted, including an empty list
- In a hash only a list of pairs is acceptable. The list may be empty.
- In a pair, a list of two items is required. The first, the key, must be a scalar, and the second item, the value, may be undefined.
- The templates attribute takes a production in which no values may be returned.
- In the `test` attribute of an instruction, only a single true or false value is permitted.

Instructions may specify further restrictions on allowable values in productions.

## Productive Instructions

The following instructions create a nodelist of one item

### object

 - select

Returns an object node populated with the contents of `select`, which must evaluate to an even-sized list of property names and corresponding values.

### pair

### array

 - select

Returns an array node populated with the contents of `select`.

### scalar

 - select

### string

 - value

Returns a node whose value is a string given in the `value` attribute.

### number

 - value

Returns a node whose value is a number given in the `value` attribute.

### boolean

 - value

Returns either true or false depending on the `value`.

### true

Returns a node whose value is boolean true.

### false

Returns a node whose value is boolean false.

### null

Returns a node whose value is `null`.

## Instructions for flow control and calculation

### apply-templates

 - select
 - name

Iterates through each node in the nodelist produced by `select`; on each iteration that node becomes the current node.

Searches through the templates in reverse order of declaration and from the current scope back up through its parents to the topmost scope. The first matching template is applied.

Note that unlike in XSLT, there is no priority ordering.

### apply-template / call-template

 - select
 - name

Iterates through each node in the nodelist produced by `select`; on each iteration that node becomes the current node.

Searches through the templates in reverse order of declaration and from the current scope back up through its parents to the topmost scope, searching for templates whose name is equal to the value of the name attribute. The first matching template is applied.

### call-variable

 - name

Returns the contents of the variable with the name given in `name`, which must produce a single string.

### call-param

 - name

Returns the contents a parameter with the name given in `name`, which must produce a single string.

### call-function

 - name
 - params

Evaluates the function with the name given in `name` (which must produce a single string). Within the function, only templates, functions and variables accessible when the function is created will be available, except that the current node will be available.

### for-each

 - select
 - produce

Iterates through each node in the nodelist produced by `select`; on each iteration that node becomes the current node, and `produce` is evaluated and returned.

### if

 - test
 - produce

The `test` attribute is evaluated. It must return boolean true or false. If true, `produce` is evaluated. If false, an empty nodelist is returned.

### choose

### when

 - test
 - produce

### otherwise

 - produce

### copy-of

### type

 - select

Evaluates `select`, which should return a single node. If absent, the current node is assumed.

Returns a string node whose value is the JSON type of the selected node.

### count

 - select

Evaluates `select` and returns the number of nodes in the list.

### current

Returns the current node.

### source

(I have forgotten what I intended this to mean. PErhaps it will return.)

### union

 - select
 - test ??? (union of values vs union of nodes)

Evaluates `select`, and filters them so that no node is returned more than once. Nodes are returned in the order in which they were first seen.

### intersection

 - select
 - compare
 - test ??? (union of values vs union of nodes)

Evaluates `select` and `compare`, and filters them so that only nodes which appear in both nodelists are returned.

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

Defines a variable in the current scope.

### function

 - name
 - params
 - produce

Defines a variable in the current scope.

When the function is executed, `params` is called with the current node of the caller scope (but the scope should have the scope in which it was declared as its parent).

A hash is then built with the parameters

### template

 - match
 - produce
 - name

Adds this template to the current scope's templates. Returns void.

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

## Errors

The following error types are defined:

- **InputNotWellFormed** - thrown when input document is not a JSON document
- **TransformationNotWellFormed** - thrown when the transformation is not a JSON document
- **TransformationInvalid** - thrown when the transformation is not a valid JTL transformation
  - **TransformationUnexpectedType** - thrown when a value was found which does not have a JSON type which is allowable at this point
  - **TransformationUnknownInstruction** - thrown when an instruction is not understood
  - **TransformationMissingRequiredAtrribute** - thrown when an attribute is required but is not present
  - **TransformationNoMatchingTemplate** - thrown when apply-templates is called on a node but no matching templates are found
  - **TransformationVariableDeclarationFailed** - thrown when a variable is set in the same scope as an existing variable of the same name
- **ResultNodesUnexpected** - thrown when results were produced which were not consistent with the instruction or context
  - **ResultNodesUnexpectedNumber** - thrown when the more or fewer result nodes were produced than expected
    - **ResultNodesNotEvenNumber** - thrown when an even number of result nodes is expected, but an odd number of items was produced
    - **ResultNodesMultipleNodes** - thrown when a single result node was expected, but multiple nodes were produced
  - **ResultNodeUnexpectedType** - thrown when a node of an impermissible type was produced
    - **ResultNodeNotBoolean** - thrown when a boolean node was expected, but some other type of node was found
    - **ResultNodeNotString** - thrown when a string was expected, but some other type of node was found

## Security

At no point is an implementation required by this specification to retrieve external resources.

## See Also

- XSLT: Although it is theoretically possible to convert almost any JSON to an XML representation, use XSLT to transform it to an XML representation of the target document, then convert back to JSON, this is likely to be unintuitive to write and requires an XSLT implementation.
- JSONT: This requires a javascript implementation, and so is not truly language-agnostic. Specification is minimal. (cf JSON::T)
- JOLT: Seems to be mostly
- json2json: written in coffeescript, not sure of its completeness
