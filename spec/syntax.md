# JSON Transformation Language Syntax

This document will describe JSON Transformation Language Syntax, an extension to the JSON Transformation Language.

## Introduction

JSON Transformation Language (hereafter JTL) is a domain-specific language for transforming JSON documents (and related tasks). JTL documents are written in JSON, which is designed to be simple and unambigouous for computers to parse, human-readable, and highly flexible. Although it is possible for humans to write JSON, it is cumbersome to do so reliably (this has contributed to the emergence of various configuration file formats, most notably YAML). Furthermore, many common patterns within JTL can be much more tersely and meaningfully written and represented with a syntax that is not strict JSON.

The JSON Transformation Language Syntax (Hereafter JTLS) is an extension to JTL. It provides a syntax that is more intuitive, more compact and more pleasant to write JTL. The relationship between JTLS and the JTL it produces should be transparent and it should be possible to represent all JTL documents using JTLS.

There is more than one way to represent a JTL document as JTLS. There is one way to represent a JTLS document as JTL (ignoring insignificant whitespace).

A JTLS parser will transform any valid JTLS document into an equivalent JTL document.

## Core Concepts

JTLS permits three different types of data to be represented:

- JTL Instruction Expression, such as `child { name: 'foo' } `
- Contextual Expressions, such as `./foo/0`
- JSON Literals, such as `{ "foo": [ 123 ] }`

JTL Instructions may contain JTL Instructions, Contextual Expressions or JSON Literals.

Contextual Expressions may contain JTL Instructions, Contextual Expressions or JSON Literals. Contextual Expressions can always be represented as JTL Instructions.

JSON Literals may not contain JTL Instructions or Contextual Expressions.

### JTL Instruction Expressions

A JTL Instruction Expression consists of the name of the instruction, followed by either an explicit argument list or an implicit argument list; optionally, it may be preceded by a selection.

An explicit argument list consists of comma-separated key-value pairs: argument names and argument values, for example:

    {
      select: children(),
      produce: name()
    }

An argument name is a single- or double-quoted string, or a bare string containing only uppercase and lowercase letters, and is followed by a colon.

Argument values may be either:

a) a single argument expression: an Instruction Expression, Contextual Expression, or Literal, or
b) an argument list, containing zero or more argument expressions, comma separated and enclosed in parentheses

The following are examples of argument values:

    (1, 2, 3, 4)
    [1, 2, 3, 4]
    children()
    1->range(4)
    $numbers
    ./*[ name()->eq('label')->not() ]
    ( undef, 1->range(4), current(), ./values/* )


An implicit argument list is an argument list (zero or more argument expressions, comma separated and enclosed in parentheses). It may be used to represent a JTL instruction with up to two attributes (`select` being one of them).

NB: Which other attribute is selected is currently specified by the `instructionSpec.json` file.

A selection is an argument value followed by the arrow infix `->`.

#### Examples

A JTL instruction with no attributes:

    current()

    { "JTL": "current" }

A JTL instruction with one explicit argument:

    eq { compare: 2 }
    eq { compare: ( 2 ) }

The above two examples are equivalent and represent the following JTL:

    { "JTL": "eq", "compare" : [ { "JTL": "literal", "value": 2 } ] }

This can also be written with one implicit argument:

    eq(2)

A JTL instruction with a selection (which is also a JTL instruction):

    name()->eq('depth')

    {
      "JTL"     : "eq",
      "select"  : [ { "JTL": "name" } ],
      "compare" : [ { "JTL": "literal", "value": "depth" } ]
    }

A JTL instruction with a selection of multiple nodes:

    (1,2)->reverse()

    {
      "JTL"     : "reverse",
      "select"  : [
        { "JTL": "literal", "value": 1 },
        { "JTL": "literal", "value": 2 }
      ]
    }


### Contextual Expressions

Contextual Expressions are shorthands for common operations navigating around documents, in particular, the instructions

- `child` and `children`
- `parent`
- `filter`

Contextual expresssions are always anchored. Allowed anchors are:

- the current node anchor, in expresssions beginning `./`
- the parent node anchor, in expresssions beginning `../`
- the root node anchor, in expresssions beginning `/`

Each anchor is followed by a filter and/or one or more steps.

A step may be a child step, preceded by a slash (`/`), or a descendant step, preceded by two (`//`).

A step may indicate nodes by name, using either a JSON string or a name token; or nodes may be selected by number (the number must be a non-negative integer).

For example:

- `./0` selects the first child of the current node (the current node is expected to be an array or node array).
- `./foo` selects the child of the current node whose name is `foo` (the current node is expected to be an object).
- `./*` selects the all children of the current node (the current node is expected to be an object, array, or node array).

The examples above are equivalent to, and will produce, the JTL expressions:

    { "JTL": "child", "index": [ { "JTL": "literal", "value":    0  } ] }
    { "JTL": "child", "name":  [ { "JTL": "literal", "value": "foo" } ] }
    { "JTL": "children" }

Steps may be filtered; filters are expressed with square brackets: `[ ]`. For example:

  `./*[ ./label->eq('foo') ]` selects all children of the current node which are objects with a key `label` whose value is the string `"foo"`.
  `./1[ ./0 ]` selects the second child of the current node provided that it is an array whose first child is `true`.

The examples above are equivalent to, and will produce, the JTL expressions:

    {
      "JTL"    : "filter",
      "select" : [ { "JTL": "children" } ]
      "test"   : [
        {
          "JTL": "eq",
          "select: [
            { "JTL": "child", "name": [ { "JTL": "literal", "value": "label" } ] }
          ],
          "compare": [
            { "JTL": "literal", "value": "foo" }
          ]
      ]
    }

    {
      "JTL"    : "filter",
      "select" : [ { "JTL": "child", "index": [ { "JTL": "literal", "value": 1 } ] } ]
      "test"   : [ { "JTL": "child", "index": [ { "JTL": "literal", "value": 0 } ] } ]
    }

Note: In XSLT, a set of child elements may be selected by name with no anchor, e.g. `li` selects all `li` elements that are the child of the current node. In JTLS, selecting a child of the current node must be anchored: `./li`. Unquoted string tokens are not permitted as values.

### JSON Literals

All literal JSON values are valid as arguments and will be transformed into `literal` instructions.

In addition, strings delimited by single quotes are valid and function identically to double-quoted strings (except that within hte strings, single quotes may be escaped, but double quotes may not be).

Note that being syntactically valid as described above does not imply that the values at runtime are valid, i.e. the following will be successfully parsed and converted to JTL but will cause an error:

    [1,2,3]->children()->filter('foo')

This is because the `test` attribute in `filter` expects a boolean value, not a string.

### White space

Use of white space to improve readability is encouraged. Insignificant white space is permitted anywhere in JTLS except within tokens and strings.

For example, the following expression:

    variable("last")->eq{compare:0.2}

... may also be expressed as follows:

    variable( "last" )
      ->
        eq {
          compare : 0.2
        }

But not as follows:

    variable(" last ")- > e q {compare:0 . 2}

White space before and after a JTLS document is also insignificant.
