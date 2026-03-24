;; remove complex operands test
;; deeply nested complex exprressions
(+ (+ 1 2)
   (+ 3 (+ 4 5)))
;; expected conceptual output:
;; (let ([t1 (+ 1 2)])
;;  (let ([t2 (+ 4 5)])
;;    (let ([t3 (+ 3 t2)])
;;      (+ t1 t3))))