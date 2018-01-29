# Changelog
All notable changes to `Rack::Params` will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
* started a Changelog
* [Feature]! can pass a block to `HashContext#param` and `ArrayContext#every` when `type`
  is `nil` to manually coerce the parameter

### Changed
* clarified that if a parameter is missing, it's not in the result _at all_,
  rather than simply nil.
* clarified what errors get raised on code-fail; `ArgumentError` is raised for
  parameter failures, `RuntimeError` on bad call (missing block, block in the wrong place,
  etc.)

### Removed
* Array and Hash parameters are now assumed to be already parsed, via
  `Rack::QueryParser`, so the `sep:` options are gone.
* `Context#_recurse`; it's inlined under `Context#_coerce` now, to handle more
  complex block semantics

### [0.0.1.pre5]
- all basic functionality
