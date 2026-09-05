# Racket Compiler Portfolio Refresh Plan

## Status

Portfolio modernization is implemented locally on `portfolio-refresh` and is
awaiting review before commit/push. Completed work includes the full source
import, rewritten documentation, CLI and examples, portable build targets,
Linux CI, targeted regression tests, removal of the obsolete stack-only
allocation path, and extraction of ABI, dataflow, heap-layout, and label policy
into focused modules. The added tests also exposed two correctness bugs, both
now fixed. The final local suite passes 7,187 intermediate checks and 170
native tests.

## Objective

Turn `shadesin/racket-compiler` into a polished, accurate, and reproducible
portfolio repository for the compiler developed during the IIIT compilers
course, while leaving the original GitHub Classroom repository and its Git
history completely untouched.

The public repository will describe the work as an educational compiler based
on *Essentials of Compilation*. It will clearly distinguish the compiler passes
and project-specific tests written by Souradeep Das from the course-provided
AST definitions, interpreters, type checkers, test harness, and C runtime.

## Repository Safety and Replacement Strategy

- Treat the GitHub Classroom checkout as read-only source material.
- Perform every portfolio change in a separate clone of
  `https://github.com/shadesin/racket-compiler`.
- Preserve the public repository's existing Git history, replacing its working
  tree in one clearly named import commit instead of force-pushing rewritten
  history.
- Do not push until the refreshed tree, documentation, attribution, and test
  results have been reviewed.
- Before importing, record both repositories' commit IDs and create a backup
  tag or branch for the current public-repository state.
- Exclude generated binaries and assembly, editor files, personal notes, and
  the book PDF from the public repository.

## Verified Baseline

The coursework implementation currently has an active 14-pass pipeline:

1. `shrink`
2. `uniquify`
3. `reveal-functions`
4. `limit-functions`
5. `expose-allocation`
6. `uncover-get!`
7. `remove-complex-opera*`
8. `explicate control`
9. `instruction selection`
10. `liveness analysis`
11. `build interference`
12. `allocate registers`
13. `patch instructions`
14. `prelude-and-conclusion`

The current suite has been run successfully with `make test`:

- 6,929 intermediate-pass assertions passed.
- 164 native x86 end-to-end tests passed.
- 0 failures and 0 errors.

The implementation supports integers, Booleans, lexical variables,
conditionals, mutation, loops, sequencing, typed vectors, heap allocation,
garbage-collector integration, typed top-level functions, recursion,
first-class function references, indirect calls, calls with more than six
source arguments, and tail calls.

General lambda expressions and closure conversion are not part of the active
pipeline and must not be advertised as supported.

## Phase 1: Import the Complete Working Baseline

- Replace the incomplete public snapshot with the tested coursework snapshot.
- Retain the public repository's `.git` directory and remote configuration.
- Import only source, test, build, and documentation files needed by the
  project.
- Confirm that no generated `.o`, `.s`, `.out`, `.dSYM`, Racket bytecode, PDF,
  or private note files are tracked.
- Review the license and course policy before publishing course-provided
  infrastructure.
- Run the complete suite in the new clone and record platform, Racket version,
  compiler version, and results.

Acceptance criteria:

- The Classroom repository remains byte-for-byte and Git-status unchanged.
- The portfolio clone contains the complete tested implementation.
- `make test` passes from a clean checkout.
- The import can be reviewed before any push.

## Phase 2: Replace the README

Write a concise project README containing:

- A one-paragraph description and an explicit educational-project disclaimer.
- A precise supported-language table and a separate limitations section.
- A compiler-pipeline diagram showing the major intermediate representations.
- A small source example and a shortened generated-x86 excerpt.
- Architecture highlights: explicit control flow, liveness, interference
  graphs, DSATUR allocation, spilling, tail calls, and precise GC roots.
- Tested platforms and prerequisites.
- One-command build/test instructions.
- The verified test totals, with wording that does not imply all harness code
  or test cases were independently authored.
- A project-layout section distinguishing authored compiler code from supplied
  course infrastructure.
- References and attribution to *Essentials of Compilation*, the course, and
  upstream support code.

Remove the GitHub Classroom badge, stale milestone claims, duplicated README
sections, and unsupported examples such as multiplication-based factorial.

## Phase 3: Add a Usable Compiler Command

- Add a small command-line driver, tentatively `compile.rkt`.
- Accept an input `.rkt` program and optional output path.
- Type-check, run the active pass pipeline, and emit `.s` assembly.
- Provide useful errors for invalid source programs and unsupported constructs.
- Add `make compile PROGRAM=...` or an equally simple documented command.
- Add one or two examples under `examples/` that compile and run end to end.

Acceptance criteria:

- A new user can compile an example without editing `run-tests.rkt`.
- The output can be assembled and linked with the runtime using documented
  commands.

## Phase 4: Improve Structure Without Changing Semantics

Refactor in small, test-backed commits:

- Split the 2,700-line `compiler.rkt` into modules grouped by responsibility,
  such as front-end normalization, control-flow lowering, x86 selection,
  dataflow/register allocation, heap lowering, and functions.
- Remove or clearly isolate obsolete earlier-pass implementations that are no
  longer used by the active pipeline.
- Correct stale or contradictory comments, especially around CFG transposition
  and liveness.
- Centralize ABI constants such as argument, caller-saved, callee-saved, and
  reserved registers.
- Standardize metadata keys and pass names.
- Keep every refactor behavior-preserving and run the full test suite after
  each logical step.

## Phase 5: Strengthen Correctness Tests

- Add focused regression tests for:
  - register pressure and both ordinary/root-stack spills;
  - values live across direct, indirect, and collector calls;
  - argument-register move cycles;
  - functions with 0, 6, 7, and many arguments;
  - recursive and mutually recursive tail calls;
  - nested vectors and pointer masks;
  - repeated collections using a deliberately small heap;
  - mutation combined with calls and loop predicates;
  - assembler-safe function labels and possible label collisions;
  - source type errors and unsupported forms.
- Add a smoke test that starts from source and checks a native executable.
- Consider property-based or differential tests comparing source and
  intermediate interpreters with native output.

## Phase 6: Add Continuous Integration

- Add GitHub Actions for Linux with pinned or documented Racket and GCC setup.
- Compile `runtime.c`, run `make test`, and fail on any test failure.
- Cache dependencies only if it materially improves runtime.
- Add a visible CI badge after the workflow passes on GitHub.
- Optionally add formatting/lint checks after the code is modularized.

## Phase 7: Portfolio Polish

- Add `CONTRIBUTING.md` only if external contributions are genuinely welcome.
- Add a short `ARCHITECTURE.md` if the README would otherwise become too long.
- Add a changelog or release notes for a `v1.0.0` portfolio release.
- Add repository topics such as `compiler`, `racket`, `x86-64`,
  `register-allocation`, `garbage-collection`, and `programming-languages`.
- Add a concise repository description and social-preview image if desired.
- Prepare accurate résumé bullets using the verified features and test totals.

## Remaining publication decisions

1. Confirm course publication policy before pushing the supplied infrastructure
   and tests. Attribution and the upstream MIT license are now explicit.
2. Review the local replacement as a normal commit on the existing public
   history; the original public snapshot is preserved on a backup branch.
3. Decide whether closure conversion and lambdas should remain explicitly out
   of scope or become a future milestone.

## Recommended Execution Order

1. Confirm publication/attribution constraints.
2. Back up the current public branch and import the complete tested snapshot.
3. Replace the README and add architecture/attribution documentation.
4. Add the CLI and runnable examples.
5. Add CI and targeted regression tests.
6. Refactor the compiler into modules in isolated commits.
7. Review the final repository, then push and tag the first polished release.

This ordering produces a credible public project early while keeping the
larger structural refactor separately reviewable and easy to revert.
