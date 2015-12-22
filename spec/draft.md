# JSON Transformation Language (Core)

This document will describe the JSON Transformation Language, hereafter JTL.

## Introduction

JSON is a widely used data interchange format. It is easily parsed and maps naturally into data structures native to a variety of programming languages. Although JSON does not carry inherent semantic value, any given JSON document in its context may have semantic value as defined by its author and as interpreted by its recipient (often by agreement through a documented API).

However, the processing of JSON data is typically bespoke and/or opaque. There is a growing need to be able to perform operations on JSON in a language-independent manner, particularly with the growth of web and native apps, to write equivalent functions in servers, client web page code and in native client apps. One extreme is to write the code three times. Another extreme is to enforce the use of ECMAScript in all three contexts to avoid duplication. There are many circumstances in which neither is sensible.

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

## Components of JTL

This document describes the Core JTL. Once this document is complete, a processor which fulfils the requirements of a processor as described in this document implements JTL.

Further documents will describe extensions to JTL which processors should implement.

- Math
- String
- Regex
- ArbitraryIntegers
- ArbitraryFloats
- Alien
- HTTP

## Core Concepts

### Processor and Documents

A JTL document is a JSON document whose root node is a JSON Object and whose structure is defined in this specification. It is read by a JTL Processor, and when applied to a JSON document called a Source Document, the Processor produces one or more JSON documents called the Result Documents. Source and Result Documents may have any sort of JSON node as their root and may contain any legal JSON content.

### JTL Documents and Instructions

JTL Documents consist of Instructions and Instruction Arrays.

An Instruction is a JSON Object which as a key 'JTL', whose value is a string. Instructions may have other keys, and their values shall always be Instruction Arrays, except in the case of the `literal` Instruction, which has a `value` key whose value can be any JSON object.

An Instruction Array is a JSON Array containing zero or more Instructions.

### Nodes

The JSON value types Object, Array, String, Number, True, False and Null are considered to be nodes in the context of the document to which they belong. A node has a path, a value, and a document.

The path is an expression of the absolute position at which the node can be found from the context of the document, expressed as a series of strings (where the parent is an object property) or non-negative integers (where the parent is an array).

A node may also be said to have a name (if its parent node is a JSON Object), or an index (if its parent node is a JSON Array); in either case, this is simply the last item in the path.

For example, in the following JSON document, the node with the value `"Whittlesford"` has the path `[ "results", 0, "location" ]` and the name `"location"`. Its parent node is the JSON Object which has the path `[ "results", 0 ]`, and the index `0`. It has no name. The JSON Array is the only child of the document node, and its name is "results".

    {
      "results": [
        { "id" : 3,  "location": "Horningsea"   },
        { "id" : 27, "location": "Whittlesford" }
      ]
    }

Nodes which are document nodes always have an empty path, no name, and no index. A node may not be a member of more than one document, nor may it have multiple paths.

### Node lists

A node list is an ordered collection of zero or more nodes. The key features of a node list are:

- **Node lists cannot be 'nested'**. Placing one node list within another will result in one node list with the contents of both. Nodes may be repeated within a node list. They are unlike unlike node arrays and JSON Arrays in this regard.
- **Nodes are not changed by their membership in a node list**: the node list is aware its elements, but they are not aware of the node list. They are like node arrays but unlike JSON Arrays in this regard.

Most instructions return node lists.

### Node arrays

A node array is a structure containing an ordered collection of zero or more nodes. The key features of a node array are:

- **Node arrays can be 'nested'**. Placing one node array within another (or within a node list) will result in a node array one of whose children is a node array. They are like JSON Arrays but unlike node lists in this regard.
- **Nodes are not changed by their membership in a node array**: the node array is aware of its elements, but they are not aware of the node array. They are like node lists but unlike JSON Arrays in this regard.

Node arrays are useful for creating complex temporary structures.

### Instructions

An instruction is represented as a JSON Hash with a key JTL whose value is the name of the instruction. Other keys and values may be present, depending on the instruction.

An instruction, when executed, MUST produce one of the following results:

- A node list, which may contain zero or more nodes. This may be used in another calculation.
- A void result, indicating that no result was expected. This is distinct from an empty node list.

### Templates

A template is created by the `template` instruction. A template is typically:

- created in the `templates` attribute in the `transformation` instruction
- passed into the `select` attribute of the `declareTemplates` instruction
- created in the `templates` attribute of the `choose` instruction

When `applyTemplates` is called, templates are compared against the current node using the template's `match` attribute (if it exists), which must return a single boolean value.

When a matching template is found, the `produce` attribute of the template is evaluated and returned.

Templates do not, however, need to be declared immediately. A template can be created, stored in a variable, passed into another template as a parameter, etc. before being declared, or perhaps flow control will determine that it is never declared at all.

### Scope

All JTL instructions are evaluated in a scope, an environment which can be used as an interface to accessible variables and templates.

A new subscope is created for each instruction, and for each evaluation within the instruction.

Unless otherwise specified, a scope has access to variables in a parent (or ancestor) scope. It has access to templates defined in a caller scope (or its caller, etc.).

The caller and parent are often the same, but can be different, e.g. after an `applyTemplates` instruction.

Unless otherwise specified, the current node of a scope is the current node of the caller.

In practice, this means that for variables:

- **Variables** declared inside any given instruction **can** be accessed by **child** instructions.
- **Variables** declared inside any given instruction **cannot** be accessed by **sibling** instructions.
- **Variables** declared inside any given instruction **cannot** be accessed by **parent** instructions.
- **Variables** declared inside any given instruction **cannot** be accessed by **templates called** within that instruction, unless explicitly passed as parameters.

Whereas for templates:

- **Templates** declared inside any given instruction **can** be accessed by **child** instructions.
- **Templates** declared inside any given instruction **cannot** be accessed by **sibling** instructions.
- **Templates** declared inside any given instruction **cannot** be accessed by **parent** instructions.
- **Templates** declared inside any given instruction **can** be accessed by **templates called** within that instruction.

(Note that this refers to templates which have been declared and are being accessed through `applyTemplate`s, not templates which are contained in a variable and are accessed through `callVariable`, which follow the rules for variables above.

### Instruction Arrays

An instruction array is represented as a JSON Array, and consists of a series of instructions, which are executed in order and together return a node list.

An instruction may trigger multiple instruction arrays, for example: a `select` to determine the nodes to perform the instruction on, followed by a `produce` on each of the nodes.

Evaluation of the instruction array will return a node list containing a single value, or a list of values.

The evaluation of an instruction array may not always be acceptable to the context in which they are placed, for example:

- When the results are used to populate a JSON Array, any results are permitted, including an empty list
- When the results are used to populate a JSON Object, only an even-sized list is acceptable (the list may be empty). These will be taken as keys and values, alternately, and keys must be strings.
- The `templates` attribute expects only remplates to be returned.
- In the `test` attribute of an instruction, only a single true or false value is permitted.

Instructions may specify further restrictions on allowable values resulting from evaluation. In such cases an error will be thrown.

## Productive Instructions

The following instructions create a node list of at least one item:

### literal

 - value

Returns a JSON literal, taken as the contents of `value`. Note that `value` is taken verbatim not evaluated as attributes normally are, so the following produces a node list containing an array of two hashes, not a node list of two hashes:

    {
      "JTL"   : "literal",
      "value" : [ {}, {} ]
    }

### object

 - select

Returns an object node (which is also a document node) populated with the contents of `select`, which must evaluate to an even-sized list of property names and corresponding values.

The following JTL always produces `{ "items" : {} }`:

    {
      "JTL"    : "object",
      "select" : [
        { "JTL": "literal", "value": "items" },
        { "JTL": "object" }
      ]
    }

### array

 - select

Returns an array node (which is also a document node) populated with the contents of `select`.

The following JTL always produces `[ "items", [] ]`:

    {
      "JTL"   : "array",
      "select" : [
        { "JTL": "literal", "value": "items" },
        { "JTL": "array" }
      ]
    }

### true

Returns a node (which is also a document node) whose value is boolean true.

The following two instructions are therefore equivalent:

    { "JTL": "literal", "value": true }

    { "JTL": "true" }

### false

Returns a node (which is also a document node) whose value is boolean false.

The following two instructions are therefore equivalent:

    { "JTL": "literal", "value": false }

    { "JTL": "false" }

### null

Returns a node (which is also a document node) whose value is `null`.

The following two instructions are therefore equivalent:

    { "JTL": "literal", "value": null }

    { "JTL": "null" }

### template

 - match
 - produce
 - name

Returns a template (which can be used in `declareTemplates`). See the section **Templates**, above.

### range

- select
- end

Evaluates `select` and `end`, expecting both to be single integers. Returns a list of integers starting at `select` and ending at `end` (inclusively, e.g. `1, 2, 3`). If `select` and `end` are equal, a list of one item will be returned (e.g. `1`). If `select` is greater than `end`, the list of integers will count downwards instead.

## Instructions for flow control and calculation

### applyTemplates

 - select
 - name

Iterates through each node in the node list produced by `select`; on each iteration that node becomes the current node.

Searches through the in-scope templates in reverse order of declaration and from the current scope back up through its parents to the topmost scope. The first matching template is applied.

Note that unlike in XSLT, there is no priority ordering.

### callVariable

 - name

Returns the contents of the variable with the name given in `name`, which must produce a single string.

### forEach

 - select
 - produce

Iterates through each node in the node list produced by `select`; on each iteration that node becomes the current node, and `produce` is evaluated and returned.

### if

 - select
 - test
 - produce

The `test` attribute is evaluated. It must return boolean true or false. If true, `produce` is evaluated. If false, an empty node list is returned.

### while

 - select
 - test
 - produce

Iterates through each node in the node list produced by `select`; on each iteration that node becomes the current node;
the `test` attribute is evaluated. It must return boolean true or false. If true, `produce` is evaluated, and the results are prepended to the queue of nodes waiting to be processed. If false, the node is appended to the list of nodes to be returned.

The following `while` instruction causes all integers to be rounded down to the next multiple of 10.

  {
    "JTL": "while",
    "test": [
      {
        "JTL": "not",
        "select": [
          {
            "JTL": "eq",
            "select": [
              {
                "JTL": "modulo",
                "compare": { "JTL": "literal", "value": 10 }
              }
            ],
            "compare": [ { "JTL": "literal", "value": 0 } ]
          }
        ]
      }
    ],
    "produce": [
      {
        "JTL": "subtract",
        "compare": { "JTL": "literal", "value": 1 }
      }
    ]
  }

The following `while` instruction flattens nested arrays (no matter how deep!).

  {
    "JTL": "while",
    "test": [
      {
        "JTL": "eq",
        "select": [ { "JTL": "type" } ],
        "compare": [ { "JTL": "literal", "value": 'array' } ]
      }
    ],
    "produce": [ { "JTL": "children" } ]
  }

### choose

 - select
 - templates

Evaluates `select`; for each node in `select`, tries each of the templates returned by `templates` in turn; the first which matches is evaluated and the result appended to the result list of this instruction. If none of the templates match a given node, that node is not returned. Each node is matched separately.

The following JTL `choose` instruction returns all the children of the current node, replacing all strings with the string `"xxx"` - but leaving all other children untouched.

    {
      "JTL": "choose",
      "select": [ { "JTL": "children" } ],
      "templates": [
        {
          "JTL": "template",
          "match": [
            {
              "JTL": "eq",
              "select": [ { "JTL": "type" } ],
              "compare": [ { "JTL": "literal", "value": "string" } ]
            }
          ],
          "produce": [ { "JTL": "literal", "value": "xxx" } ]
        },
        {
          "JTL": "template",
          "produce": [ { "JTL": "current" } ]
        }
      ]
    }

### copyOf

 - select

For each node in `select`, returns a copy of that node, i.e. a node which has the same value, but is in a document of its own.

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

### union

 - select
 - test

Evaluates `select`, and filters them so that no node is returned more than once. Nodes are returned in the order in which they were first seen.

If `test` is present, a test for uniqueness other than identity is possible (e.g. an equality test).

### intersection

 - select
 - compare
 - test ??? (union of values vs union of nodes)

Evaluates `select` and `compare`, and filters them so that only nodes which appear in both node lists are returned.

If `test` is present, a test for uniqueness other than identity is possible (e.g. an equality test).

### symmetricDifference

 - select
 - compare
 - test

Evaluates `select` and `compare`, and filters them so that only nodes which appear in one of the two node lists - but not both - are returned.

If `test` is present, a test for uniqueness other than identity is possible (e.g. an equality test).

### filter

 - select
 - test

Evaluates `select`, and then evaluates `test` for each node. Only nodes for which `test` returns true will be returned. `test` must return boolean values only.

### reduce

- select
- produce

Evaluates `select`, and then, for each item in the result (apart from the first), evaluates `produce`, with the current node set to a node array consisting of the item and the result of the previous `produce` (which must be a single item), or in the case of the first evalueation, the first item in select.

Throws an error if `select` contains fewer than two items.

### zip

- select

Evaluates `select`, which shoud be a list of arrays or node arrays. Returns a list of arrays such that the first array contains the first element of each of the input arrays, the second array contains the second element, etc. If one array is exhausted, its values are recycled from the beginning until the end of the longest array. If any arrays are empty, they will not be used at all.

If select contains no non-empty arrays/node arrays, an empty node list is returned.

### unique

 - select
 - test

Evaluates `select`, and filters them so that no duplicate node is returned (not even the first instance of a duplicate is returned). By default, duplication is determined by deciding if two nodes are the same.

### sort

 - select
 - test

Returns the nodes in `select`, sorted in ascending order.

Note that this differs from `xsl:sort` in XSLT, which itself is empty but causes certain parents (e.g. `xsl:for-each`) to order the selection.

If `test` exists, it is evaluated for pairs of nodes. Return values must be `true`, `false`, or `undefined`. If `true`, the nodes are in the correct order. If false, they are in the wrong order. If `undefined`, either order is acceptable.

The default value of test sorts nodes:

- missing before present (e.g. `[]` sorts before `[ 0 ]` );
- by type in in the following order: undefined, false, true, array, object, number, string;
- arrays are compared by comparing each of their children;
- objects are compared by taking a unique sorted list of keys and looking at each of their values.
- numbers are sorted in ascending numerical order
- strings are sorted by codepoint

### reverse

 - select

Returns the nodes in `select`, but in reverse order, i.e. from last to first.

### first

 - select

Evaluates `select`, and returns only the first node.

### last

 - select

Evaluates `select`, and returns only the last node.

### nth

 - select
 - which

Evaluates `select`, and returns only the nodes with the indexes given in `nth`, which should be a list of 0-based integers. The current node when evaluating `nth` is a node array of nodes returned by `select`.

## Instructions which always return booleans

### empty, nonempty

  - select

### emptyList, nonemptyList

  - select

### zero, nonzero

  - select

### not

 - select

### or, and

 - select
 - compare

### sameNode

 - select
 - compare

Returns true if the nodes are the same node, i.e. they share a document and have the same path from the root of the document.

### equal

 - select
 - compare

Returns true if the nodes are the equal in value, i.e. they are of the same type, and:

- arrays have the same number of children and each corresponding child is equal
- objects have the same keys and each key has the same value
- numbers have the same mathematical value
- strings are identical

### greaterThan, lessThan

 - select

## Void instructions

### variable

 - select
 - name

Defines a variable in the current scope.

### declareTemplate

 - select

Adds this template to the current scope's templates. Returns void.

### message

### param, withParam

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
  - **TransformationNoMatchingTemplate** - thrown when applyTemplates is called on a node but no matching templates are found
  - **TransformationVariableDeclarationFailed** - thrown when a variable is set in the same scope as an existing variable of the same name
  - **TransformationUnknownVariable** - thrown when a variable is called but does not exist
- **ResultNodesUnexpected** - thrown when results were produced which were not consistent with the instruction or context
  - **ResultNodesUnexpectedNumber** - thrown when the more or fewer result nodes were produced than expected
    - **ResultNodesNotEvenNumber** - thrown when an even number of result nodes is expected, but an odd number of items was produced
    - **ResultNodesMultipleNodes** - thrown when a single result node was expected, but multiple nodes were produced
  - **ResultNodeUnexpectedType** - thrown when a node of an impermissible type was produced
    - **ResultNodeNotBoolean** - thrown when a boolean node was expected, but some other type of node was found
    - **ResultNodeNotString** - thrown when a string was expected, but some other type of node was found

## Security Considerations

- Transformations are in effect programs and should be treated with an appropriate degree of caution.
- There is no theoretical limit on the size or depth of the source document or the transformation, but implementations may need to provide a practical limit.
- There is no theoretical limit on the depth of recursion in the transformation, but implementations may need to provide a practical limit.
- In most cases it will be convenient for JTL implementations to be built by operating not only on raw JSON documents but on language-specific data types which are created by a JSON parser. Differences between these and JSON may give rise to security considerations. For example:
  - Many languages allow circular references. JSON does not provide for this and so no consideration for this possibility has been made in the specification.
  - There is no theoretical limit on the size of individual values in the source document or in the transformation, but this may be inconsistent with restrictions on native data types.
  - Modifying these data structures during a execution may produce unexpected results which may give rise to security considerations.
- Although at no point is an implementation required by **this** specification to retrieve or modify external resources, implementations may support extensions which do so, and security considerations apply to these.

Where an implementation detects a situation in which security considerations indicate processing would be unwise, it should stop, and throw an error.

Where an implementation's applicability is narrowed in one of the ways described above (e.g. a recursion limit), it must document this.

## See Also

- XSLT: Although it is theoretically possible to convert almost any JSON to an XML representation, by using XSLT to transform it to an XML representation of the target document, then convert back to JSON, this is likely to be unintuitive to write and requires an XSLT implementation.
- JSONT: This requires a javascript implementation, and so is not truly language-agnostic. Specification is minimal. (cf JSON::T)
- JOLT: Seems to be mostly Java.
- json2json: written in coffeescript, not sure of its completeness
- jq - A compelling terse syntax, but only implemented in C.
