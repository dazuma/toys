# @title Toys-Core User Guide

# Toys-Core User Guide

Toys-Core is the command line framework underlying Toys. It implements most of
the core functionality of Toys, including the tool DSL, argument parsing,
loading Toys files, online help, subprocess control, and so forth. It can be
used to create custom command line executables using the same facilities. You
can generally write 

This user's guide covers everything you need to know to build your own command
line executables in Ruby using the Toys-Core framework.

This guide assumes you are already familiar with Toys itself, including how to
define tools by writing Toys files, parsing arguments and flags, and how tools
are executed. For background, please see the
[Toys User's Guide](https://www.rubydoc.info/gems/toys/file/docs/guide.md).

**(This user's guide is still under construction.)**

## Conceptual overview

Toys-Core is a command line *framework* in the traditional sense. It is
intended to be used to write custom command line executables in Ruby. It
provides libraries to handle basic functions such as argumet parsing and online
help, and you provide the actual behavior.

The entry point for Toys-Core is the **cli object**. Typically your executable
script instantiates a CLI, configures it with the desired tool implementations,
and runs it.

An executable defines its functionality using the **Toys DSL** which can be
written in **toys files** or in **blocks** passed to the CLI. It uses the same
DSL used by Toys itself, and supports tools, subtools, flags, arguments, help
text, and all the other features of Toys.

An executable may customize its own facilities for writing tools by providing
**built-in mixins** and **built-in templates**, and can implement default
behavior across all tools by providing **middleware**.

Most executables will provide a set of **static tools**, but it is possible to
support user-provided tools as Toys does. Executables can customize how tool
definitions are searched and loaded from the file system.

Finally, an executable may customize many aspects of its behavior, such as the
**logging output**, **error handling**, and even shell **tab completion**.

## Using the CLI object

## Writing tools

## Customizing the tool environment

## Customizing default behavior

## Packaging your executable
