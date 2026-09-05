# Racket to x86-64 Compiler

[![CI](https://github.com/shadesin/racket-compiler/actions/workflows/ci.yml/badge.svg)](https://github.com/shadesin/racket-compiler/actions/workflows/ci.yml)

A multi-pass compiler for a statically typed subset of Racket. It
lowers expression-oriented source programs through explicit intermediate
representations to native x86-64 assembly, including graph-coloring register
allocation, tail calls, and garbage-collected vectors.

The project was developed for the IIIT compilers course,
following Jeremy Siek's *Essentials of Compilation*. Compiler passes and
project-specific regression tests are student work; the language framework,
reference interpreters, type checkers, harness, and C runtime began as
course-provided infrastructure.

## Highlights

- Fourteen explicit compiler passes, each operating on a structured AST.
- Backward liveness analysis over a control-flow graph.
- Interference-graph construction with move biasing.
- Priority-queue DSATUR register allocation across 11 registers.
- Ordinary stack spilling plus a precise GC root stack for heap pointers.
- Typed heterogeneous vectors and Cheney copying-collector integration.
- Direct, indirect, recursive, and properly lowered tail calls.
- System V x86-64 calls, including source functions with more than six
  arguments through typed tuple packing.
- Differential validation through intermediate-language interpreters and
  native executable tests.

## Supported source language

| Area | Supported forms |
| --- | --- |
| Values | 64-bit integers, Booleans, `void`, function references |
| Expressions | `let`, `if`, `and`, `or`, `not`, `+`, unary/binary `-` |
| Comparisons | `eq?`, `<`, `<=`, `>`, `>=` |
| Effects | `read`, `begin`, `set!`, `while` |
| Heap data | Typed `vector`, `vector-ref`, `vector-set!`, `vector-length` |
| Functions | Typed top-level definitions, recursion, higher-order references, indirect calls, tail calls |

This is deliberately not a full Racket implementation. General lambdas and
closure conversion, multiplication/division, strings, floating point, modules,
macros, and exceptions are outside the active compiler pipeline.

## Pipeline

```text
source
  -> shrink
  -> uniquify
  -> reveal functions
  -> limit functions
  -> expose allocation
  -> uncover get!
  -> remove complex operands
  -> explicate control
  -> select instructions
  -> liveness analysis
  -> build interference
  -> allocate registers
  -> patch instructions
  -> add preludes/conclusions
  -> x86-64 assembly
```

See [ARCHITECTURE.md](ARCHITECTURE.md) for representations, calling convention,
allocation layout, garbage-collector roots, and register allocation details.

## Quick start

Requirements:

- Racket 8.x or newer
- GCC or Clang with an x86-64 target
- GNU Make
- On Apple Silicon, Rosetta 2 to execute generated x86-64 binaries

Run the complete test suite:

```bash
make test
```

## Command-line compiler

`compile.rkt` is the command-line entry point for compiling one source program
outside the test harness. It reads the program, type-checks it, runs the active
pipeline from `compiler.rkt`, and writes x86-64 assembly. It does not link an
executable by itself.

Compile a source program to assembly:

```bash
racket compile.rkt examples/fibonacci.rkt
```

This writes `examples/fibonacci.s`. Build it with the runtime using:

```bash
make build PROGRAM=examples/fibonacci.rkt
```

The source language returns its result from `main`, so the executable's exit
status is the program result:

```bash
./examples/fibonacci.out
echo $?  # 55
```

Choose paths explicitly when needed:

```bash
racket compile.rkt --output /tmp/program.s path/to/program.rkt
make build PROGRAM=path/to/program.rkt ASM=/tmp/program.s BINARY=/tmp/program.out
```

Pass `--verbose` to the CLI to print pass names as they run.

To compile, link, and run the second example in one workflow:

```bash
make build PROGRAM=examples/functions-and-vectors.rkt
./examples/functions-and-vectors.out
echo $?  # 42
```

## Example

```racket
(define (increment [n : Integer]) : Integer
  (+ n 1))

(define (apply-twice [f : (Integer -> Integer)] [n : Integer]) : Integer
  (f (f n)))

(let ([values (vector 10 40)])
  (apply-twice increment (vector-ref values 1)))
```

The compiler emits ordinary AT&T-syntax x86-64, including indirect calls for
the higher-order application and runtime-managed allocation for the vector.
The resulting executable returns `42`.

## Tests

`run-tests.rkt` discovers source programs under `tests/` and checks:

1. Source type checking, including expected type errors.
2. Semantic equivalence after every pass that has a reference interpreter.
3. Assembly generation and linking with `runtime.c`.
4. Native program output or exit status against the expected result.

The expanded suite passes 7,187 intermediate-pass checks and 170 native
x86-64 tests: 7,357 checks in total, with zero failures and zero errors. CI
runs this suite and an independent CLI compile/link/execute smoke test on
Linux.

## Repository map

| Path | Purpose |
| --- | --- |
| `compiler.rkt` | Compiler passes and active pass registry |
| `compiler/` | ABI, dataflow, heap-layout, and label-mangling support |
| `compile.rkt` | User-facing command-line driver |
| `runtime.c`, `runtime.h` | Runtime and copying garbage collector |
| `interp-*.rkt` | Reference interpreters for source/intermediate languages |
| `type-check-*.rkt` | Type checkers for language stages |
| `utilities.rkt` | AST definitions, assembly printer, and course test harness |
| `tests/` | Source programs, input fixtures, expected results/type errors |
| `examples/` | Small programs intended for manual compilation |
| `debug/` | Focused liveness and interference inspection programs |

## Development notes

- Generated `.s`, `.o`, and `.out` files are ignored.

## License

The course support code is distributed under the MIT license retained in
[LICENSE](LICENSE).
