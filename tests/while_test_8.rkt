;; GCD via subtraction-based Euclidean algorithm.
;; gcd(48, 18): 48-18=30, 30-18=12, 18-12=6, 12-6=6 -> equal -> done
;; Expected: 6
(let ([a 48])
  (let ([b 18])
    (begin
      (while (not (eq? a b))
        (if (> a b)
            (set! a (- a b))
            (set! b (- b a))))
      a)))
