#lang racket
(require "../compiler.rkt")
(require "../utilities.rkt")
(require graph)
(require racket/set)

;; Reconstruct the Book Example (same as before)
(define p
  (X86Program '()
    (list (cons 'start
                (Block '()
                       (list 
                        (Instr 'movq (list (Imm 1) (Var 'v)))
                        (Instr 'movq (list (Imm 46) (Var 'w)))
                        (Instr 'movq (list (Var 'v) (Var 'x)))
                        (Instr 'addq (list (Imm 7) (Var 'x)))
                        (Instr 'movq (list (Var 'x) (Var 'y)))
                        (Instr 'movq (list (Var 'x) (Var 'z)))
                        (Instr 'addq (list (Var 'w) (Var 'z)))
                        (Instr 'movq (list (Var 'y) (Var 't)))
                        (Instr 'negq (list (Var 't)))
                        (Instr 'movq (list (Var 'z) (Reg 'rax)))
                        (Instr 'addq (list (Var 't) (Reg 'rax)))
                        (Jmp 'conclusion)))))))

;; 1. Run Liveness Analysis (Prerequisite)
(define p-live (uncover-live p))

;; 2. Run Build Interference
(define p-inter (build-interference p-live))

;; 3. Extract and Print Graph
(match p-inter
  [(X86Program info blocks)
   (define G (dict-ref info 'conflicts))
   
   (displayln "Interference Graph Edges:")
   (displayln "-------------------------")
   ;; Iterate over all vertices and print their neighbors
   ;; We sort them to make the output deterministic and easy to read
   (define sorted-vertices (sort (get-vertices G) 
                                 (lambda (x y) (string<? (~a x) (~a y)))))
   
   (for ([u sorted-vertices])
     (define neighbors (sort (get-neighbors G u) 
                             (lambda (x y) (string<? (~a x) (~a y)))))
     (printf "~a interferes with: ~a\n" (~a u #:width 5) neighbors))])