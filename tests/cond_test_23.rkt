;; cond_test_23: if in both assignment and tail position with shared continuation.
;; Tests create-block sharing: both branches of the if assign to x before
;; returning; the continuation (+ x 10) is shared without duplication.
;;
;; Input: 7
;;   n=7: (if (> 7 5) 100 -100) => 100
;;   result: (let ([x 100]) (+ x 10)) = 110
;; Expected: 110
(let ([n (read)])
  (let ([x (if (> n 5) 100 -100)])
    (+ x 10)))
