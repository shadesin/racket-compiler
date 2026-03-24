#lang racket
(require "../compiler.rkt")
(require "../utilities.rkt")
(require racket/set)

;; This test reconstructs the running example from Chapter 3.
;; It corresponds to the code in Figure 3.2 and the liveness analysis in Figure 3.5.
(define p
  (X86Program '()
    (list (cons 'start
                (Block '()
                       (list 
                        ;; v = 1
                        (Instr 'movq (list (Imm 1) (Var 'v)))
                        
                        ;; w = 46
                        (Instr 'movq (list (Imm 46) (Var 'w)))
                        
                        ;; x = v + 7
                        (Instr 'movq (list (Var 'v) (Var 'x)))
                        (Instr 'addq (list (Imm 7) (Var 'x)))
                        
                        ;; y = x
                        (Instr 'movq (list (Var 'x) (Var 'y)))
                        
                        ;; z = x + w
                        (Instr 'movq (list (Var 'x) (Var 'z)))
                        (Instr 'addq (list (Var 'w) (Var 'z)))
                        
                        ;; t = -y
                        (Instr 'movq (list (Var 'y) (Var 't)))
                        (Instr 'negq (list (Var 't)))
                        
                        ;; res = z + t
                        (Instr 'movq (list (Var 'z) (Reg 'rax)))
                        (Instr 'addq (list (Var 't) (Reg 'rax)))
                        
                        (Jmp 'conclusion)))))))

;; Run the pass
(define result (uncover-live p))

;; Print the Live-After sets for verification
(match result
  [(X86Program info blocks)
   (match (car blocks)
     [(cons label (Block b-info instrs))
      (displayln "Instruction                           Live-After Set")
      (displayln "----------------------------------------------------")
      
      (for ([i instrs] [s (dict-ref b-info 'live-after)])
        ;; Format the output to look like the book's diagram
        (define instr-str (~a i))
        (define set-str (~a (sort (set->list s) symbol<?)))
        (printf "~a ~a\n" (~a instr-str #:width 35) set-str))])])