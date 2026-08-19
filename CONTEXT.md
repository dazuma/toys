# Toys

Toys is a configurable command line tool framework for Ruby, developed as a
monorepo of related gems (`toys-core`, `toys`, `toys-ci`, `toys-release`). This
file records the vocabulary the project uses for its own concepts, so that code,
documentation, and discussion stay consistent.

## Language

**Source**:
A root location from which tools are loaded: a filesystem path, a git
repository, a Ruby gem, or a block of DSL code.
_Avoid_: Config, config file, config path, tool path

**Source list**:
The ordered collection of sources that a loader reads tools from.
_Avoid_: Config list, search path, load path

**Priority**:
A source's rank within a source list. When more than one source defines the same
tool name, the definition from the highest priority source wins.
_Avoid_: Precedence, order, rank
