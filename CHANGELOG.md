# Changelog

All notable portfolio releases will be recorded here.

## Unreleased

### Added

- Complete compiler implementation through typed functions and vectors.
- Command-line compiler driver and runnable examples.
- Architecture and attribution documentation.
- Linux continuous integration and an end-to-end CLI smoke test.
- Regression coverage for ABI boundaries, label collisions, GC pressure, root
  spills, and mutation across calls.
- Focused compiler support modules for ABI policy, dataflow, heap layout, and
  assembler label generation.

### Changed

- Apple Silicon builds now compile the runtime for the x86-64 target
  automatically.
- ABI register definitions are centralized in `compiler/abi.rkt`.
- Function labels use collision-resistant encoding and a runtime-safe namespace.
- Function-aware control lowering now handles calls nested in mutation, loops,
  branches, and effect contexts.
- Function values are classified as raw code addresses rather than GC-managed
  heap pointers.

## 0.1.0 - 2026-03-24

- Initial public snapshot through the mutable-variable/loop milestone.
