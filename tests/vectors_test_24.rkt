; Test: vector with mixed types (Integer, Boolean, Vector)
; This exercises the pointer mask: element 2 is a pointer, elements 0 and 1 are not.
; Pointer mask should be: bit 9 (= 7+2) = 1, bits 7 and 8 = 0.
(let ([t (vector 40 #t (vector 2))])
  (if (vector-ref t 1)
      (+ (vector-ref t 0) (vector-ref (vector-ref t 2) 0))
      44))
