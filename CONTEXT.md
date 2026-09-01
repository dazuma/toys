# Toys

Toys is a configurable command line tool framework for Ruby, developed as a
monorepo of related gems (`toys-core`, `toys`, `toys-ci`, `toys-release`). This
file records the vocabulary the project uses for its own concepts, so that code,
documentation, and discussion stay consistent.

## Language

**Source**:
A location from which tools are loaded. Every source has an origin, saying
where its content came from, and a type, saying what the thing is: a file, a
directory, a block of DSL code, or a subclass of Toys::Tool. A source may be
added to a source list, declared from within a toys file, or found by a loader
as it walks a directory.
_Avoid_: Config, config file, config path, tool path

**Origin**:
Where a source's content came from: the local file system, a git repository, a
Ruby gem, or a block of code. A source's origin is fixed when its source spec
is resolved, and every source descending from it shares it. Distinct from a
source's type, which says what the thing is rather than where it came from, and
which varies from one source to the next down the tree.
_Avoid_: Provenance, location, source kind

**Source spec**:
An unresolved description of a source: its kind, and the information needed to
locate it. Source specs cover the sources added to a source list and the
sources declared from within a toys file. A source that a loader finds by
walking a directory has no source spec.
_Avoid_: Source request, source descriptor

**Source list**:
The ordered collection of root sources that a loader reads tools from.
_Avoid_: Config list, search path, load path

**Priority**:
A source's rank within a source list. When more than one source defines the same
tool name, the definition from the highest priority source wins.
_Avoid_: Precedence, order, rank

**Context directory**:
The directory that tools treat as their project root, normally the directory
_containing_ the toplevel toys file or directory, so that a tool behaves the
same whichever subdirectory it was invoked from. It is often set by the source
of a tool, but can be overridden by the tool definition, and may be left unset
(nil). The version of the context directory that a tool sees *at runtime*
through the `CONTEXT_DIRECTORY` context key, is the tool's context directory,
but if unset it falls back to the current working directory. So unlike a
tool's context directory, the effective context directory at runtime is never
nil.
_Avoid_: Base directory, project directory, source directory
