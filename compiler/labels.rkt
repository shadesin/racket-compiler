#lang racket

(provide mangle-function-label)

;; Keep the synthetic entry point recognizable. Namespace every user function
;; away from runtime symbols and encode non-ASCII-alphanumeric characters by
;; code point. Encoding underscore too makes this mapping injective.
(define (mangle-function-label function-name)
  (if (equal? function-name 'main)
      'main
      (let ([encoded
             (for/list ([character
                         (in-string (symbol->string function-name))])
               (if (or (char<=? #\a character #\z)
                       (char<=? #\A character #\Z)
                       (char<=? #\0 character #\9))
                   (string character)
                   (format "_~x_" (char->integer character))))])
        (string->symbol
         (string-append "rkt_" (apply string-append encoded))))))
