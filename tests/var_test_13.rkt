;; explicate control test
;; nested lets (sequencing correctness)
(let ([x 5])
  (let ([y 7])
    (+ x y)))
;; expected conceptual CVar:
;; x = 5;
;; y = 7;
;; return (+ x y);