; Test: and/or inside function argument position (exercises the shrink-exp Apply fix)
; (and #t #f) should desugar to (if #t #f #f) = #f -> f gets 0
(define (boolToInt [b : Boolean]) : Integer (if b 1 0))
(boolToInt (and #t #f))
