#lang racket

(provide compute-tag is-gc-pointer-type?)

;; A type is a pointer only when its values live in the collector-managed heap.
;; Function values in this compiler are raw code addresses, not heap closures.
(define (is-gc-pointer-type? type)
  (match type
    [`(Vector ,_ ...) #t]
    [_ #f]))

;; Vector header layout, starting from the least-significant bit:
;;   bit 0     = 1 when the object has not been forwarded
;;   bits 1-6  = vector length
;;   bits 7+   = one pointer bit for each vector field
(define (compute-tag length type)
  (define pointer-mask
    (match type
      [`(Vector ,element-types ...)
       (for/fold ([mask 0])
                 ([element-type element-types]
                  [index (in-naturals)])
         (if (is-gc-pointer-type? element-type)
             (bitwise-ior mask (arithmetic-shift 1 (+ 7 index)))
             mask))]
      [_ 0]))
  (bitwise-ior 1
               (arithmetic-shift length 1)
               pointer-mask))
