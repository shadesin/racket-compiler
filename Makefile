CC     = gcc
RACKET = racket
RM     = rm
CFLAGS ?= -g -std=c99
LDFLAGS ?=
TARGET_ARCH_FLAGS =

PROGRAM ?= examples/fibonacci.rkt
ASM     ?= $(patsubst %.rkt,%.s,$(PROGRAM))
BINARY  ?= $(patsubst %.rkt,%.out,$(PROGRAM))

# The compiler emits x86-64 assembly. On Apple Silicon, build the runtime for
# the same target so the linker can combine it with generated code.
ifeq ($(shell uname -s),Darwin)
ifeq ($(shell uname -m),arm64)
TARGET_ARCH_FLAGS = -arch x86_64
endif
endif

ifeq ($(shell uname -s),Linux)
LDFLAGS += -z noexecstack
endif

runtime.o: runtime.c runtime.h
	$(CC) -c $(CFLAGS) $(TARGET_ARCH_FLAGS) runtime.c

test: runtime.o
	$(RACKET) run-tests.rkt

compile:
	$(RACKET) compile.rkt --output $(ASM) $(PROGRAM)

build: runtime.o compile
	$(CC) $(CFLAGS) $(LDFLAGS) $(TARGET_ARCH_FLAGS) runtime.o $(ASM) -o $(BINARY)

example: build

smoke:
	$(MAKE) build PROGRAM=examples/functions-and-vectors.rkt
	@./examples/functions-and-vectors.out; status=$$?; \
	  test $$status -eq 42 || { echo "expected exit status 42, got $$status"; exit 1; }

clean: test-clean
	$(RM) -f *.o *.out *.exe *.s *~ examples/*.out examples/*.s
	$(RM) -rf *.dSYM examples/*.dSYM

test-clean:
	$(RM) -f tests/*.o tests/*.out tests/*.exe tests/*.s tests/*~
	$(RM) -rf tests/*.dSYM

.PHONY: test compile build example smoke clean test-clean
