#!/usr/bin/env racket
#lang racket

(require racket/cmdline
         racket/path
         "compiler.rkt"
         "type-check-Lfun.rkt"
         (only-in "utilities.rkt"
                  print-x86
                  read-program))

(provide compile-source-file)

(define compiler-verbose? (make-parameter #f))

(define (run-pipeline program)
  (for/fold ([current (type-check-Lfun program)])
            ([pass-info (in-list compiler-passes)])
    (define pass-name (list-ref pass-info 0))
    (define pass (list-ref pass-info 1))
    (define next (pass current))
    (when (compiler-verbose?)
      (eprintf "[compiler] ~a\n" pass-name))
    (if (>= (length pass-info) 4)
        ((list-ref pass-info 3) next)
        next)))

(define (default-output-path source)
  (path-replace-extension source #".s"))

(define (compile-source-file source [output #f])
  (define source-path (path->complete-path source))
  (unless (file-exists? source-path)
    (raise-user-error 'racket-compiler "source file does not exist: ~a" source))
  (define output-path
    (path->complete-path (or output (default-output-path source-path))))
  (when (equal? source-path output-path)
    (raise-user-error 'racket-compiler "input and output paths must differ"))
  (define assembly
    (print-x86 (run-pipeline (read-program source-path))))
  (call-with-output-file output-path
    #:exists 'replace
    (lambda (port)
      (display assembly port)
      (newline port)))
  output-path)

(module+ main
  (define requested-output #f)
  (define verbose? #f)
  (command-line
   #:program "compile.rkt"
   #:once-each
   [["-o" "--output"] path
    "Write assembly to PATH instead of replacing .rkt with .s"
    (set! requested-output path)]
   [["-v" "--verbose"]
    "Print each compiler pass as it runs"
    (set! verbose? #t)]
   #:args (source)
   (compiler-verbose? verbose?)
   (with-handlers ([exn:fail?
                    (lambda (error)
                      (eprintf "racket-compiler: ~a\n" (exn-message error))
                      (exit 1))])
     (define output (compile-source-file source requested-output))
     (printf "Wrote ~a\n" output))))
