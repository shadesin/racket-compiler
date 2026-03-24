;; explicate control test
;; let inside initializer
(let ([x (let ([y 3])
           (+ y 1))])
  (+ x 2))
;; expected conceptual CVar:
;; y = 3;
;; x = (+ y 1);
;; return (+ x 2);