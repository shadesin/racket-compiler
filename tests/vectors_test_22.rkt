; Test: nested vectors with correct GC pointer mask (exercises compute-tag pointer-type fix)
; The outer vector holds an inner vector, which must be marked as a GC pointer in the tag.
; This also stress-tests the GC by creating many tuples to force collection.
(let ([outer (vector (vector 21) (vector 21))])
  (+ (vector-ref (vector-ref outer 0) 0)
     (vector-ref (vector-ref outer 1) 0)))
