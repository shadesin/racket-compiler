# Racket Compiler: Lint → x86-64

A nanopass compiler that translates a subset of the Racket programming language through multiple intermediate languages down to x86-64 assembly. Currently supports the full `Lwhile` milestone with variables, conditionals, loops, and mutation.

## Overview

This compiler demonstrates a complete pipeline from high-level expressions to executable x86 code:

```
Source (Racket) → Lwhile → Lvar → Lint → C-lang → x86-64 Assembly
```

**Status:** Complete through the `Lwhile` milestone with comprehensive test coverage and optimized register allocation.

## Quick Start

### Prerequisites

- Racket (any recent version)
- GCC (for compiling the C runtime)

### Setup & Testing

```bash
# 1. Compile the C runtime support
gcc -c -g -std=c99 runtime.c

# Apple Silicon users targeting x86-64:
gcc -c -g -std=c99 -arch x86_64 runtime.c

# 2. Run all tests (interpreter + code generation)
racket run-tests.rkt

# Or use the Makefile
make test
```

## Supported Language Features

### Lwhile Language

The compiler supports programs with the following features:

- **Integers & arithmetic:** `+`, `-` operators
- **Variables:** lexical scoping with mutation (`set!`)
- **Conditionals:** `if` expressions
- **Loops:** `while` loops with `set!`-based mutation tracking
- **I/O:** `(read)` for integer input
- **Control flow:** `begin` for sequencing, `(void)` for unit type

**Example:**

```scheme
; Factorial with while loop
(let ([n (read)])
  (let ([result 1])
    (begin
      (while (> n 0)
        (begin
          (set! result (* result n))
          (set! n (- n 1))))
      result)))
```

## Compiler Pipeline

The compiler applies the following passes in sequence:

| Pass | Purpose |
|------|---------|
| `shrink` | Partial evaluation and constant folding |
| `uniquify` | Rename variables to ensure uniqueness |
| `uncover-get!` | Track mutation and generate `get!` for mutable reads |
| `remove-complex-opera*` | Push atomic values to top level |
| `explicate-control` | Convert to explicit control flow |
| `select-instructions` | Translate to pseudo-x86 instructions |
| `uncover-live` | Liveness analysis with iterative dataflow |
| `build-interference` | Construct register interference graph |
| `allocate-registers` | DSatur-based register allocation |
| `patch-instructions` | Fix immediate ranges and special cases |
| `prelude-and-conclusion` | Insert function prologue/epilogue |

**Output:** x86-64 assembly linked against `runtime.o`

## Key Implementation Details

### Mutation Handling

Variables modified with `set!` are tracked via the `uncover-get!` pass, which:
- Identifies mutable variables
- Generates `GetBang` operations for reads of mutable state
- Ensures correct variable semantics across assignments

### Control Flow

Explicit control flow graphs are built to handle:
- Conditional branches
- Loop targets and exits
- Effect positions (statements vs. expressions)

### Register Allocation

The `allocate-registers` pass uses:
- **Priority-based DSatur** heuristic for optimal coloring
- **Interference graph** construction from liveness info
- Handles cyclic CFGs with iterative worklist algorithm

## File Organization

### Core Compiler

- [compiler.rkt](compiler.rkt) — Main compiler driver and pass pipeline
- [utilities.rkt](utilities.rkt) — Helper functions and utilities

### Interpreters (Validation Layer)

Each intermediate language has an interpreter for testing:

- Language interpreters: `interp-Lint.rkt`, `interp-Lvar.rkt`, `interp-Lif.rkt`, `interp-Lwhile.rkt`
- C-lang interpreters: `interp-Cvar.rkt`, `interp-Cif.rkt`, `interp-Cwhile.rkt`
- Shared: [interp.rkt](interp.rkt) — Base interpreter framework

### Type Checking

- Language checkers: `type-check-Lvar.rkt`, `type-check-Lif.rkt`, `type-check-Lwhile.rkt`
- C-lang checkers: `type-check-Cvar.rkt`, `type-check-Cif.rkt`, `type-check-Cwhile.rkt`

### Graph & Data Structures

- [priority_queue.rkt](priority_queue.rkt) — Priority queue for DSatur allocation
- [multigraph.rkt](multigraph.rkt) — Multigraph utilities
- [graph-printing.rkt](graph-printing.rkt) — Visualization helpers

### Runtime

- [runtime.c](runtime.c) / [runtime.h](runtime.h) — C runtime for `(read)` and I/O
- [heap.rkt](heap.rkt) — Heap management (future expansion)

### Testing

- [run-tests.rkt](run-tests.rkt) — Main test runner
- `tests/` — Test programs with expected output (`.rkt`, `.res`, `.in` files)
- `debug/` — Debug test cases for specific compiler passes

## Testing

The test suite validates:

1. **Interpreter tests** — Each intermediate language's interpreter produces correct results
2. **Compiler tests** — Generated x86 code executes and produces correct output

**Test families:**
- `int` — Integer arithmetic
- `var` — Variables and assignment
- `cond` — Conditionals
- `while` — Loops and mutation

Run tests:

```bash
make test                    # Run all tests
racket run-tests.rkt         # Same
```

## Future Milestones

Potential extensions (currently not implemented):

- Function definitions and calls (`Lfun`, `Cfun`)
- Lambda expressions and closures
- Vector/array operations
- Polymorphic functions
- Gradual typing and dynamic types
- Any-language constructs

## Architecture Notes

### Intermediate Languages

The compiler chains these intermediate languages:

1. **Lwhile** — High-level with `while`, `set!`, begin, void
2. **Lvar** — Variables and conditionals
3. **Lint** — Integer expressions with `read()`
4. **Cvar/Cif/Cwhile** — C-like intermediate with explicit control flow

Each language has:
- An AST definition
- An interpreter (reference semantics)
- Type checker (validation)
- Compiler passes (translation to next language)

### Design Patterns

- **Mixin-based OO:** Type checkers and interpreters use Racket class mixins for composition
- **Pattern matching:** AST traversal via Racket's `match` syntax
- **Dataflow analysis:** Iterative fixed-point computation for liveness

## License

See [LICENSE](LICENSE) file.

---

**Questions or issues?** Refer to test cases under `tests/` for working examples, or explore the interpreter implementations (`interp-*.rkt`) for language semantics.

### 3) Assemble and link a generated file

```bash
gcc -g runtime.o foo.s
```

## Project Structure (High-Level)

- `compiler.rkt`: main pass implementations and pipeline configuration
- `run-tests.rkt`: test harness invocation
- `interp-*.rkt`: interpreters for intermediate languages
- `type-check-*.rkt`: language-specific type checkers
- `runtime.c`, `runtime.h`: runtime support linked with generated assembly
- `tests/`: test inputs and expected outputs