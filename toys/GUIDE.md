# Toys User Guide

Toys is a command line binary that lets you build your own personal suite of
command line tools (with commands and subcommands) using a Ruby DSL. Toys
handles argument parsing, error reporting, logging, help text, and many other
details for you. It is designed for software developers, IT specialists, and
other power users who want to write and organize scripts to automate their
workflows.

This user's guide covers everything you need to know to use Toys effectively.

## Conceptual overview

Toys is a command line *framework*. It provides a binary called `toys` along
with basic functions such as argument parsing and online help. You provide the
actual behavior of the toys binary by writing *configuration files*.

Toys is a multi-command binary. You may define a collection of commands, called
*tools*, which can be invoked by passing the tool name as an argument to the
`toys` binary. Tools are arranged in a hierarchy; a tool may be a *namespace*
that has *subtools*.

Each tool defines the command line arguments, in the form of *flags* and
*positional arguments*, that it recognizes. Flags can optionally take *values*,
and positional arguments may be *required* or *optional*.

The configuration of a tool may define *descriptions*, for the tool itself, and
for each command line argument. These descriptions are displayed in the tool's
*online help* screen. Descriptions come in *long* and *short* forms, which
appear in different styles of help.

Toys searches for configuration in specifically-named *configuration files* and
*configuration directories*. It searches for these in the current directory,
and in a *configuration search path*.

Toys provides various features to help you write tools. This includes providing
a *logger* for each tool, *helper modules* that provide common functions a tool
can call, and *templates* which are prefabricated tools you can add to your
configuration.

Finally, Toys provides certain *built-in behavior*, including automatically
providing flags to display help screens and set verbosity. It also includes a
built-in namespace of *system tools* that let you inspect and configure the
Toys system.

## The Toys Command Line

## Config Syntax

## Config Search Path

## Defining Helpers

## Defining Templates

## Built-in Flags and Behavior

## Embedding Toys
