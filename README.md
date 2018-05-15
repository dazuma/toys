# Toys

[![Travis-CI Build Status](https://travis-ci.org/dazuma/toys.svg)](https://travis-ci.org/dazuma/toys/)

Toys is a command line binary that lets you build your own suite of command
line tools (with commands and subcommands) using a Ruby DSL. Commands can be
defined globally or scoped to directories.

This repository includes the source for the **toys** gem, which provides the
`toys` binary itself, and the **toys-core** gem, which includes the underlying
command line framework.

## Contributing

While we appreciate contributions, please note that this software is currently
highly experimental, and the code is evolving very rapidly. Please contact the
author before embarking on a major pull request. More detailed contribution
guidelines will be provided when the software stabilizes further.

The source can be found on Github at
[https://github.com/dazuma/toys](https://github.com/dazuma/toys)

### TODO items

* I still don't like the name "execute". Maybe "script"? or "action"?
* I'm tempted to go back from "group" to "collection" or even "namespace" so that "group" is free for flags.
* We should drop the block syntax for adding flags/args at the Tool level and provide it at the ConfigDSL level instead. So that we can say `f.long_desc "blah blah"`

* Improve test coverage
* Write user's guide

* Investigate required flags and flag groups. Three types: at_most_one, exactly_one, at_least_one
* Investigate something to generate output formats
* Investigate system paths tool
* Investigate group clearing/locking

## License

Copyright 2018 Daniel Azuma

This software is licensed under the 3-clause BSD license.

See the LICENSE.md file for more information.
