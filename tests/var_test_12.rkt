;; explicate control test
;; simple let -> return
(let ([x 10])
  (+ x 32))
;; expected:
;; x = 10;
;; return (+ x 32);