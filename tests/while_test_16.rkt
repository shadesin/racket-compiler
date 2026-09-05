;; while_test_16: Three-variable loop — integer square root via repeated subtraction.
;; Uses the identity: n^2 = 1+3+5+...+(2n-1) (sum of first n odd numbers).
;; Find largest k such that k^2 <= n by summing odd numbers until we exceed n.
;; Tests complex liveness: three mutable vars (n, k, odd) all live at loop back-edge,
;; with the while condition comparing a derived variable.
;;
;; n = 49: odd numbers 1,3,5,7,9,11,13 sum to 49 exactly => k=7
;; Expected: 7
(let ([n 49])
  (let ([k 0])
    (let ([odd 1])
      (let ([sum 0])
        (begin
          (while (<= (+ sum odd) n)
            (begin
              (set! sum (+ sum odd))
              (set! odd (+ odd 2))
              (set! k (+ k 1))))
          k)))))
