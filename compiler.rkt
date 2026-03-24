#lang racket
(require racket/set racket/stream)
(require racket/fixnum)
(require data/queue)
(require graph)
(require "multigraph.rkt")
(require "priority_queue.rkt")
(require "interp-Lint.rkt")
(require "interp-Lvar.rkt")
(require "interp-Lif.rkt")
(require "interp-Lwhile.rkt")
(require "interp-Cvar.rkt")
(require "interp-Cif.rkt")
(require "interp-Cwhile.rkt")
(require "interp.rkt")
(require "type-check-Lvar.rkt")
(require "type-check-Lif.rkt")
(require "type-check-Lwhile.rkt")
(require "type-check-Cvar.rkt")
(require "type-check-Cif.rkt")
(require "type-check-Cwhile.rkt")
(require "utilities.rkt")
(provide (all-defined-out))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Lint examples
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; The following compiler pass is just a silly one that doesn't change
;; anything important, but is nevertheless an example of a pass. It
;; flips the arguments of +. -Jeremy
(define (flip-exp e)
  (match e
    [(Var x) e]
    [(Prim 'read '()) (Prim 'read '())]
    [(Prim '- (list e1)) (Prim '- (list (flip-exp e1)))]
    [(Prim '+ (list e1 e2)) (Prim '+ (list (flip-exp e2) (flip-exp e1)))]))

(define (flip-Lint e)
  (match e
    [(Program info e) (Program info (flip-exp e))]))


;; Next we have the partial evaluation pass described in the book.
(define (pe-neg r)
  (match r
    [(Int n) (Int (fx- 0 n))]
    [else (Prim '- (list r))]))

(define (pe-add r1 r2)
  (match* (r1 r2)
    [((Int n1) (Int n2)) (Int (fx+ n1 n2))]
    [(_ _) (Prim '+ (list r1 r2))]))

(define (pe-exp e)
  (match e
    [(Int n) (Int n)]
    [(Prim 'read '()) (Prim 'read '())]
    [(Prim '- (list e1)) (pe-neg (pe-exp e1))]
    [(Prim '+ (list e1 e2)) (pe-add (pe-exp e1) (pe-exp e2))]
    [(Prim '- (list e1 e2)) (pe-add (pe-exp e1) (pe-neg (pe-exp e2)))]
    ))

(define (pe-Lint p)
  (match p
    [(Program info e) (Program info (pe-exp e))]))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; HW1 Passes
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; -----------------------------------------------------------------------------

(define (uniquify-exp env)
  (lambda (e)
    (match e
      [(Var x)
       (Var (dict-ref env x))]
      [(Int n) (Int n)]
      [(Bool b) (Bool b)]
      [(Void) (Void)]
      [(Let x e body)
       (define x^ (gensym x))
       (Let x^ ((uniquify-exp env) e)
             ((uniquify-exp (dict-set env x x^)) body))]
      [(If cnd thn els)
       (If ((uniquify-exp env) cnd)
           ((uniquify-exp env) thn)
           ((uniquify-exp env) els))]
      ;; SetBang: the variable must already be in env (bound by a surrounding Let)
      [(SetBang x rhs)
       (SetBang (dict-ref env x) ((uniquify-exp env) rhs))]
      ;; WhileLoop: recursively uniquify condition and body
      [(WhileLoop cnd body)
       (WhileLoop ((uniquify-exp env) cnd) ((uniquify-exp env) body))]
      ;; Begin: recursively uniquify all subexpressions
      [(Begin es body)
       (Begin (map (uniquify-exp env) es) ((uniquify-exp env) body))]
      [(Prim op es)
       (Prim op (for/list ([e es]) ((uniquify-exp env) e)))])))

;; uniquify : Lvar -> Lvar
(define (uniquify p)
  (match p
    [(Program info e) (Program info ((uniquify-exp '()) e))]))

;; -----------------------------------------------------------------------------

;; remove-complex-opera* : Lvar -> Lvar^mon
(define (remove-complex-opera* p)
  (match p
    [(Program info e)
     (Program info (rco-exp e))]))

;; 4 Helper functions for remove-complex-opera*
;; rco-exp : exp -> exp(mon)
(define (rco-exp e)
  (match e
    [(Int n) (Int n)]
    [(Var x) (Var x)]
    [(Bool b) (Bool b)]
    [(Void) (Void)]
    [(Prim 'read '()) (Prim 'read '())]

    ;; if: all three subexpressions are processed as complex expressions.
    ;; Crucially, the condition is NOT atomized (doing so would interfere
    ;; with explicate_control's ability to emit efficient comparisons).
    [(If cnd thn els)
     (If (rco-exp cnd) (rco-exp thn) (rco-exp els))]

    ;; GetBang is a complex (effectful) read from a mutable variable.
    ;; It stays as-is here; rco-atom will introduce a tmp for it.
    [(GetBang x) (GetBang x)]

    ;; SetBang: RHS may be complex; the whole SetBang is itself complex.
    [(SetBang x rhs) (SetBang x (rco-exp rhs))]

    ;; Begin: each subexpression is processed for effects; body for value.
    [(Begin es body) (Begin (map rco-exp es) (rco-exp body))]

    ;; WhileLoop: condition and body are both complex.
    [(WhileLoop cnd body) (WhileLoop (rco-exp cnd) (rco-exp body))]

    [(Prim op args)
     (rco-prim op args)]

    [(Let x e body)
     (Let x (rco-exp e) (rco-exp body))]))

;; rco-prim : symbol (list exp) -> exp(mon)
(define (rco-prim op args)
  (define-values (rev-lets atoms)
    (for/fold ([lets '()] [atoms '()])
              ([a args])
      (let-values ([(a^ lets^) (rco-atom a)])
        (values (append lets lets^) (append atoms (list a^))))))

  (foldr
   (lambda (b acc) (Let (car b) (cdr b) acc))
   (Prim op atoms)
   rev-lets))

;; rco-atom : exp -> (values atom (list (cons var exp)))
(define (rco-atom e)
  (cond
    [(atomic? e)
     (values e '())]

    [else
     (define tmp (gensym 'tmp))
     (values (Var tmp)
             (list (cons tmp (rco-exp e))))]))

;; atomic? : exp -> boolean
;; Note: GetBang is intentionally NOT atomic - it is an effectful read
;; from a mutable variable and must be sequenced correctly.
(define (atomic? e)
  (match e
    [(Int _) #t]
    [(Var _) #t]
    [(Bool _) #t]
    [_ #f]))

;; -----------------------------------------------------------------------------

;; Global dictionary of basic blocks (list of (label . tail)), accumulated
;; during a single call to explicate-control and reset on each fresh call.
(define basic-blocks '())

;; create-block : tail -> Goto
;; If tail is already a Goto, return it unchanged (no need for a new block).
;; Otherwise generate a fresh label, store tail under that label in
;; basic-blocks, and return a Goto to the new label.
(define (create-block tail)
  (match tail
    [(Goto label) (Goto label)]
    [else
     (define label (gensym 'block))
     (set! basic-blocks (cons (cons label tail) basic-blocks))
     (Goto label)]))

;; explicate-control : Lif^mon -> Cif
(define (explicate-control p)
  (match p
    [(Program info e)
     (set! basic-blocks '())
     (define start-tail (explicate-tail e))
     (CProgram info (cons (cons 'start start-tail) basic-blocks))]))

;; -- Effect position ----------------------------------------------------------
;; explicate-effect : exp tail -> tail
;; Compiles an expression evaluated only for its side effects (result discarded).
;; k is the continuation tail (what happens after this expression).
(define (explicate-effect e k)
  (match e
    ;; set! -> assign rhs into x, then continue
    ;; Use explicate-assign so Let-wrapped GetBang nodes from RCO are handled.
    [(SetBang x rhs)
     (explicate-assign rhs x k)]

    ;; begin -> process each subexpression for effect, then the body
    [(Begin es body)
     (foldr (lambda (sub acc) (explicate-effect sub acc))
            (explicate-effect body k)
            es)]

    ;; while -> build a loop block
    ;;   goto loop
    ;;   loop: if cnd -> body; goto loop
    ;;              else -> k
    [(WhileLoop cnd body)
     (define loop-label (gensym 'loop))
     (define body-tail (explicate-effect body (Goto loop-label)))
     (define loop-tail (explicate-pred cnd body-tail k))
     (set! basic-blocks (cons (cons loop-label loop-tail) basic-blocks))
     (Goto loop-label)]

    ;; (void) is pure -- just the continuation
    [(Void) k]

    ;; Pure atoms -- no side effects, discard value, just k
    [(or (Int _) (Bool _) (Var _)) k]

    ;; (read) has a side effect -- emit the call but discard the result
    [(Prim 'read '())
     (Seq (Prim 'read '()) k)]

    ;; Any other expression: bind to a fresh tmp to preserve side effects
    [_
     (define tmp (gensym 'effect))
     (explicate-assign e tmp k)]))

;; -- Tail position ------------------------------------------------------------
;; explicate-tail : exp -> tail
(define (explicate-tail e)
  (match e
    [(Let x rhs body)
     (explicate-assign rhs x (explicate-tail body))]
    ;; Bool/Int/Void constant in tail position -> just return it
    [(Bool b) (Return (Bool b))]
    [(Int n)  (Return (Int n))]
    [(Void)   (Return (Void))]
    ;; GetBang: mutable variable read -> return the variable's current value
    [(GetBang x) (Return (Var x))]
    ;; set! in tail position -> assign rhs into x, then return void
    [(SetBang x rhs)
     (explicate-assign rhs x (Return (Void)))]
    ;; begin in tail position -> effects, then tail of body
    [(Begin es body)
     (foldr (lambda (sub acc) (explicate-effect sub acc))
            (explicate-tail body)
            es)]
    ;; while in tail position -> emit loop, return void
    [(WhileLoop cnd body)
     (define loop-label (gensym 'loop))
     (define body-tail (explicate-effect body (Goto loop-label)))
     (define loop-tail (explicate-pred cnd body-tail (Return (Void))))
     (set! basic-blocks (cons (cons loop-label loop-tail) basic-blocks))
     (Goto loop-label)]
    ;; if in tail position: compile both branches as tails, then delegate
    ;; the condition to explicate-pred
    [(If cnd thn els)
     (define thn-tail (explicate-tail thn))
     (define els-tail (explicate-tail els))
     (explicate-pred cnd thn-tail els-tail)]
    [_
     (Return (explicate-exp e))]))

;; -- Assignment position -------------------------------------------------------
;; explicate-assign : exp var tail -> tail
(define (explicate-assign rhs x k)
  (match rhs
    [(Let y rhs2 body)
     (explicate-assign rhs2 y (explicate-assign body x k))]
    ;; Bool/Int constant: emit a single assignment then continue
    [(Bool b) (Seq (Assign (Var x) (Bool b)) k)]
    [(Int n)  (Seq (Assign (Var x) (Int n))  k)]
    ;; (void) on rhs -> assign 0 (Void) to x then continue
    [(Void) (Seq (Assign (Var x) (Void)) k)]
    ;; GetBang: mutable variable read -- just copy the variable
    [(GetBang y) (Seq (Assign (Var x) (Var y)) k)]
    ;; set! on rhs: perform the set!-assignment, then assign Void to x
    ;; Use explicate-assign for rhs to handle Let-wrapped GetBang from RCO.
    [(SetBang y rhs2)
     (explicate-assign rhs2 y (Seq (Assign (Var x) (Void)) k))]
    ;; begin on rhs: effects, then assign body to x
    [(Begin es body)
     (foldr (lambda (sub acc) (explicate-effect sub acc))
            (explicate-assign body x k)
            es)]
    ;; while on rhs: emit the loop, then assign Void to x
    [(WhileLoop cnd body)
     (define k-after (Seq (Assign (Var x) (Void)) k))
     (define loop-label (gensym 'loop))
     (define body-tail (explicate-effect body (Goto loop-label)))
     (define loop-tail (explicate-pred cnd body-tail k-after))
     (set! basic-blocks (cons (cons loop-label loop-tail) basic-blocks))
     (Goto loop-label)]
    ;; if on the rhs of a let: both branches must share the continuation k.
    ;; Wrap k in a block so it is not duplicated.
    [(If cnd thn els)
     (define k-block (create-block k))
     (define thn-tail (explicate-assign thn x k-block))
     (define els-tail (explicate-assign els x k-block))
     (explicate-pred cnd thn-tail els-tail)]
    [_
     (Seq (Assign (Var x) (explicate-exp rhs)) k)]))

;; -- Predicate (condition) position
;; explicate-pred : exp tail tail -> tail
;; Compiles a Boolean-typed LIf expression as the condition of an if,
;; given already-compiled tails for the then and else branches.
(define (explicate-pred cnd thn els)
  (match cnd
    ;; Boolean variable: emit an eq? comparison against #t
    [(Var x)
     (IfStmt (Prim 'eq? (list (Var x) (Bool #t)))
             (create-block thn)
             (create-block els))]
    ;; Let expression in predicate: sequence the binding then recurse
    [(Let x rhs body)
     (explicate-assign rhs x (explicate-pred body thn els))]
    ;; (not e): swap the then/else branches and recurse
    [(Prim 'not (list e))
     (explicate-pred e els thn)]
    ;; Comparison operator: emit IfStmt directly
    [(Prim op es) #:when (member op '(eq? < <= > >=))
     (IfStmt (Prim op es) (create-block thn) (create-block els))]
    ;; Boolean constant: partial evaluation -- discard one branch
    [(Bool b) (if b thn els)]
    ;; begin in predicate: effects, then condition check on body
    [(Begin es body)
     (foldr (lambda (sub acc) (explicate-effect sub acc))
            (explicate-pred body thn els)
            es)]
    ;; Nested if in predicate: both branches are also in predicate context.
    ;; Wrap the outer thn/els in blocks to avoid code duplication.
    [(If cnd^ thn^ els^)
     (define thn-block (create-block thn))
     (define els-block (create-block els))
     (explicate-pred cnd^
                     (explicate-pred thn^ thn-block els-block)
                     (explicate-pred els^ thn-block els-block))]
    [else (error "explicate-pred unhandled case" cnd)]))

;; -- Expression lowering
;; explicate-exp : exp -> exp (Cwhile atomic/prim)
(define (explicate-exp e)
  (match e
    [(Int n) (Int n)]
    [(Bool b) (Bool b)]
    [(Var x) (Var x)]
    [(Void) (Void)]
    ;; GetBang lowers to a plain variable reference in C form
    [(GetBang x) (Var x)]
    [(Prim 'read '()) (Prim 'read '())]
    [(Prim op args) (Prim op args)]))

;; -----------------------------------------------------------------------------

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; HW2 Passes
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; -----------------------------------------------------------------------------
;; select-instructions : Cvar -> x86var
(define (select-instructions p)
  (match p
    [(CProgram info blocks)
     (define new-blocks
       (for/list ([b blocks])
         (match b
           [(cons label tail)
            (cons label (Block '() (select-tail tail)))])))
     (X86Program info new-blocks)]))

;; Helper to compile an expression 'e' into a destination 'dst'
(define (select-assign dst e)
  (match e
    ;; Case: dst = (void) -> encode as 0
    [(Void)
     (list (Instr 'movq (list (Imm 0) dst)))]

    ;; Case: dst = bool/int/var  (Bool is encoded as 0 or 1)
    [(or (Int _) (Var _) (Bool _))
     (list (Instr 'movq (list (select-atm e) dst)))]

    ;; Case: dst = (read)
    [(Prim 'read '())
     (list (Callq 'read_int 0)
           (Instr 'movq (list (Reg 'rax) dst)))]

    ;; Case: dst = (- atm)
    [(Prim '- (list a))
     (if (equal? a dst)
         (list (Instr 'negq (list dst)))
         (list (Instr 'movq (list (select-atm a) dst))
               (Instr 'negq (list dst))))]

    ;; Case: dst = (+ atm1 atm2)
    [(Prim '+ (list a1 a2))
     (cond
       [(equal? a1 dst)
        (list (Instr 'addq (list (select-atm a2) dst)))]
       [(equal? a2 dst)
        (list (Instr 'addq (list (select-atm a1) dst)))]
       [else
        (list (Instr 'movq (list (select-atm a1) dst))
              (Instr 'addq (list (select-atm a2) dst)))])]

    ;; Case: dst = (- atm1 atm2)  binary subtraction
    [(Prim '- (list a1 a2))
     (cond
       [(equal? a1 dst)
        (list (Instr 'subq (list (select-atm a2) dst)))]
       [else
        (list (Instr 'movq (list (select-atm a1) dst))
              (Instr 'subq (list (select-atm a2) dst)))])]

    ;; Case: dst = (not atm)
    ;; x86 has no boolean-not, so we use xorq $1.  If dst already holds atm
    ;; we save a movq.
    [(Prim 'not (list a))
     (define arg (select-atm a))
     (if (equal? arg dst)
         (list (Instr 'xorq (list (Imm 1) dst)))
         (list (Instr 'movq  (list arg dst))
               (Instr 'xorq  (list (Imm 1) dst))))]

    ;; Case: dst = (eq? atm1 atm2)
    ;; cmpq arg2, arg1  (sets flags for arg1 - arg2)
    ;; sete %al         (byte register: 1 if equal, 0 otherwise)
    ;; movzbq %al, dst  (zero-extend byte into full 64-bit destination)
    [(Prim 'eq? (list a1 a2))
     (list (Instr 'cmpq   (list (select-atm a2) (select-atm a1)))
           (Instr 'set    (list 'e (ByteReg 'al)))
           (Instr 'movzbq (list (ByteReg 'al) dst)))]

    ;; Case: dst = (< atm1 atm2)  - analogous to eq? but uses setl
    [(Prim '< (list a1 a2))
     (list (Instr 'cmpq   (list (select-atm a2) (select-atm a1)))
           (Instr 'set    (list 'l (ByteReg 'al)))
           (Instr 'movzbq (list (ByteReg 'al) dst)))]

    ;; Case: dst = (<= atm1 atm2)
    [(Prim '<= (list a1 a2))
     (list (Instr 'cmpq   (list (select-atm a2) (select-atm a1)))
           (Instr 'set    (list 'le (ByteReg 'al)))
           (Instr 'movzbq (list (ByteReg 'al) dst)))]

    ;; Case: dst = (> atm1 atm2)
    [(Prim '> (list a1 a2))
     (list (Instr 'cmpq   (list (select-atm a2) (select-atm a1)))
           (Instr 'set    (list 'g (ByteReg 'al)))
           (Instr 'movzbq (list (ByteReg 'al) dst)))]

    ;; Case: dst = (>= atm1 atm2)
    [(Prim '>= (list a1 a2))
     (list (Instr 'cmpq   (list (select-atm a2) (select-atm a1)))
           (Instr 'set    (list 'ge (ByteReg 'al)))
           (Instr 'movzbq (list (ByteReg 'al) dst)))]))

;; Helper to select instructions for a tail (sequence of statements)
(define (select-tail t)
  (match t
    ;; Treat 'Return e' as 'rax = e; jmp conclusion'
    [(Return exp)
     (append (select-assign (Reg 'rax) exp)
             (list (Jmp 'conclusion)))]

    [(Seq stmt tail)
     (append (select-stmt stmt)
             (select-tail tail))]

    ;; goto label  =>  jmp label
    [(Goto label)
     (list (Jmp label))]

    ;; if (cmp atm1 atm2) goto thn; else goto els
    ;; =>  cmpq arg2, arg1 ; jCC thn ; jmp els
    [(IfStmt (Prim op (list a1 a2)) (Goto thn-label) (Goto els-label))
     (define cc (match op ['eq? 'e] ['< 'l] ['<= 'le] ['> 'g] ['>= 'ge]))
     (list (Instr 'cmpq (list (select-atm a2) (select-atm a1)))
           (JmpIf cc thn-label)
           (Jmp els-label))]))

;; Helper to select instructions for a specific statement
(define (select-stmt s)
  (match s
    [(Assign (Var v) e)
     (select-assign (Var v) e)]
    ;; (read) as a standalone statement (Cwhile effect statement): call read_int,
    ;; discard the result in rax.
    [(Prim 'read '())
     (list (Callq 'read_int 0))]))

;; Helper to translate atomic expressions (Int/Bool/Var) to x86 arguments
;; Bool #t => 1, Bool #f => 0  (booleans are encoded as integers)
(define (select-atm a)
  (match a
    [(Int n)    (Imm n)]
    [(Bool #t)  (Imm 1)]
    [(Bool #f)  (Imm 0)]
    [(Var x)    (Var x)]))
  
;; -----------------------------------------------------------------------------

;; assign-homes : x86var -> x86var
(define (assign-homes p)
  (match p
    [(X86Program info blocks)
     (define vars (remove-duplicates (collect-vars blocks)))
     (define homes (make-homes vars))
     (define stack-size (* 8 (length vars)))
     (X86Program
      (dict-set info 'stack-size stack-size)
      (map (lambda (b) (assign-homes-block b homes)) blocks))]))

;; Helper functions for assign-homes:

;; collect-vars : ((label . block)*) -> (listof var)
(define (collect-vars blocks)
  (apply append
         (map (lambda (lb)
                (collect-vars-block (cdr lb)))
              blocks)))

(define (collect-vars-block b)
  (match b
    [(Block _ instrs)
     (apply append (map collect-vars-instr instrs))]))

(define (collect-vars-instr i)
  (match i
    [(Instr _ args)
     (apply append (map collect-vars-arg args))]
    [_ '()]))

(define (collect-vars-arg a)
  (match a
    [(Var x) (list x)]
    [_ '()]))

;; make-homes : (listof var) -> (dict var arg)
(define (make-homes vars)
  (for/hash ([x vars] [i (in-naturals 1)])
    (values x (Deref 'rbp (* -8 i)))))

(define (assign-homes-block lb homes)
  (match lb
    [(cons label b)
     (cons label (assign-homes-block* b homes))]))

(define (assign-homes-block* b homes)
  (match b
    [(Block info instrs)
     (Block info
            (map (lambda (i) (assign-homes-instr i homes))
                 instrs))]))

(define (assign-homes-instr i homes)
  (match i
    [(Instr op args)
     (Instr op (map (lambda (a) (assign-homes-arg a homes)) args))]
    [_ i]))

(define (assign-homes-arg a homes)
  (match a
    [(Var x) (dict-ref homes x)]
    [_ a]))


;; -----------------------------------------------------------------------------

;; patch-instructions : x86var -> x86int
(define (patch-instructions p)
  (match p
    [(X86Program info blocks)
     (X86Program info
                 (for/list ([b blocks])
                   (match b
                     [(cons label (Block b-info instrs))
                      (cons label (Block b-info (append-map patch-instr instrs)))])))]))

;; Helper to patch a single instruction
;; Returns a list of instructions (usually 1, sometimes 2 or 3)
(define (patch-instr i)
  (match i
    ;; Case 0: Trivial move (source == destination)
    ;; Delete the instruction
    [(Instr 'movq (list src dst))
     #:when (equal? src dst)
     '()]
    
    ;; Case 1: movq mem, mem
    ;; Move source to %rax, then %rax to destination
    [(Instr 'movq (list (Deref r1 o1) (Deref r2 o2)))
     (list (Instr 'movq (list (Deref r1 o1) (Reg 'rax)))
           (Instr 'movq (list (Reg 'rax) (Deref r2 o2))))]
    
    ;; Case 2: Arithmetic op mem, mem (e.g., addq, subq)
    ;; If we have `addq mem1, mem2`, we load mem1 to %rax, then `addq %rax, mem2`.
    [(Instr op (list (Deref r1 o1) (Deref r2 o2)))
     (list (Instr 'movq (list (Deref r1 o1) (Reg 'rax)))
           (Instr op (list (Reg 'rax) (Deref r2 o2))))]

    ;; Case 3: Immediate outside the 32-bit signed range can't be encoded
    ;; directly in most x86-64 instructions (only movq supports 64-bit imm).
    ;; Move it into %rax first, then emit the operation.
    [(Instr op (list (Imm n) (Deref r o)))
     #:when (or (> n 2147483647) (< n -2147483648))
     (list (Instr 'movq (list (Imm n) (Reg 'rax)))
           (Instr op (list (Reg 'rax) (Deref r o))))]

    ;; Case 4: cmpq _ (Imm n)  -- second arg of cmpq must not be an immediate.
    ;; Move the immediate into rax and compare against that.
    [(Instr 'cmpq (list arg (Imm n)))
     (list (Instr 'movq (list (Imm n) (Reg 'rax)))
           (Instr 'cmpq (list arg (Reg 'rax))))]

    ;; Case 5: cmpq mem, mem  -- at most one memory reference allowed.
    ;; Move the first operand into rax first.
    [(Instr 'cmpq (list (Deref r1 o1) (Deref r2 o2)))
     (list (Instr 'movq (list (Deref r1 o1) (Reg 'rax)))
           (Instr 'cmpq (list (Reg 'rax) (Deref r2 o2))))]

    ;; Case 6: movzbq _ mem  -- destination of movzbq must be a register.
    ;; Move into rax first, then store rax into memory.
    [(Instr 'movzbq (list src (Deref r o)))
     (list (Instr 'movzbq (list src (Reg 'rax)))
           (Instr 'movq   (list (Reg 'rax) (Deref r o))))]

    ;; Default: Return the instruction unchanged
    [_ (list i)]))

;; -----------------------------------------------------------------------------

;; prelude-and-conclusion : x86int -> x86int
(define (prelude-and-conclusion p)
  (match p
    [(X86Program info blocks)
     (define stack-size (dict-ref info 'stack-size))  ;; Space for spilled variables
     (define used-callee (dict-ref info 'used_callee (set)))  ;; Callee-saved regs used
     
     ;; Convert set to sorted list for consistent ordering
     (define used-callee-list (sort (set->list used-callee) symbol<?))
     (define num-callee (length used-callee-list))
     
     ;; Calculate stack adjustment using the formula: A = align(8S + 8C) - 8C
     ;; S = number of spilled variables (stack-size / 8)
     ;; C = number of callee-saved registers
     ;; align() rounds up to nearest multiple of 16 bytes
     (define S (quotient stack-size 8))
     (define C num-callee)
     (define total-bytes (+ (* 8 S) (* 8 C)))
     (define aligned-size 
       (if (zero? (modulo total-bytes 16))
           total-bytes
           (+ total-bytes (- 16 (modulo total-bytes 16)))))
     (define rsp-adjustment (- aligned-size (* 8 C)))
     
     (define label 'main)
     
     ;; Build prelude: push rbp, set rbp, push callee-saved regs, adjust rsp, jump to start
     (define prelude
       (append
        (list (Instr 'pushq (list (Reg 'rbp)))
              (Instr 'movq (list (Reg 'rsp) (Reg 'rbp))))
        ;; Push each callee-saved register
        (for/list ([reg used-callee-list])
          (Instr 'pushq (list (Reg reg))))
        ;; Adjust stack pointer for spilled variables
        (if (> rsp-adjustment 0)
            (list (Instr 'subq (list (Imm rsp-adjustment) (Reg 'rsp))))
            '())
        (list (Jmp 'start))))
     
     ;; Build conclusion: restore rsp, pop callee-saved regs (in reverse), pop rbp, return
     (define conclusion
       (append
        ;; Restore stack pointer
        (if (> rsp-adjustment 0)
            (list (Instr 'addq (list (Imm rsp-adjustment) (Reg 'rsp))))
            '())
        ;; Pop callee-saved registers in reverse order
        (for/list ([reg (reverse used-callee-list)])
          (Instr 'popq (list (Reg reg))))
        ;; Pop rbp and return
        (list (Instr 'popq (list (Reg 'rbp)))
              (Retq))))
     
     ;; Construct the new program with main at the front and conclusion at the back
     (X86Program info
                 (cons (cons label (Block '() prelude))
                       (append blocks
                               (list (cons 'conclusion (Block '() conclusion))))))]))

;; -----------------------------------------------------------------------------


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; HW3 Passes
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; ------------------------------------------------------------------------------
;; analyze_dataflow : multigraph * (label * set -> set) * set * (set * set -> set)
;;                    -> hash[label -> set]
;;
;; Generic work list algorithm for dataflow analysis (Figure 5.5, EoC sec.5.2).
;; Formulated as a FORWARD analysis: the input to each transfer call is the
;; join of the abstract states of the node's predecessors in G.
;; For a BACKWARD analysis (e.g. liveness), pass the TRANSPOSE of the CFG as G.
(define (analyze_dataflow G transfer bottom join)
  (define mapping (make-hash))
  (for ([v (in-vertices G)])
    (dict-set! mapping v bottom))
  (define worklist (make-queue))
  (for ([v (in-vertices G)])
    (enqueue! worklist v))
  (define trans-G (transpose G))
  (while (not (queue-empty? worklist))
    (define node (dequeue! worklist))
    (define input (for/fold ([state bottom])
                            ([pred (in-neighbors trans-G node)])
                   (join state (dict-ref mapping pred))))
    (define output (transfer node input))
    (cond [(not (equal? output (dict-ref mapping node)))
           (dict-set! mapping node output)
           (for ([v (in-neighbors G node)])
             (enqueue! worklist v))]))
  mapping)

;; ------------------------------------------------------------------------------
;; uncover-live : x86var -> x86var
;; Liveness analysis via analyze_dataflow.
;;
;; Liveness is a BACKWARD analysis, so we pass (transpose cfg) as G.
;; The transfer function receives (label, live-after) and returns live-before
;; by walking the block's instructions backwards using read-set / write-set.
;; Jump instructions are transparent (empty read/write sets), so liveness
;; passes through them unchanged; analyze_dataflow already unions the
;; live-before sets of all successor blocks to form live-after.
;;
;; After analyze_dataflow converges, a single final pass annotates each block
;; with per-instruction live-after sets using compute-live-instrs.
(define (uncover-live p)
  (match p
    [(X86Program info blocks)
     ;; Step 1: Build directed CFG.
     (define cfg (multigraph (make-hash)))
     (for ([b blocks])
       (add-vertex! cfg (car b)))
     (add-vertex! cfg 'conclusion)
     (for ([b blocks])
       (match b
         [(cons label (Block _ instrs))
          (for ([instr instrs])
            (match instr
              [(Jmp target)     (add-directed-edge! cfg label target)]
              [(JmpIf _ target) (add-directed-edge! cfg label target)]
              [_ (void)]))]))

     ;; Table for fast block lookup.
     (define blocks-table
       (make-hash (for/list ([b blocks]) (cons (car b) (cdr b)))))

     ;; Transfer function: (label * live-after-set -> live-before-set).
     ;; 'conclusion is a fixed sink whose live-before is always {rax, rsp}.
     ;; For all other blocks, walk instructions backward from live-after.
     (define (transfer node live-after)
       (cond
         [(equal? node 'conclusion)
          (set 'rax 'rsp)]
         [else
          (match (hash-ref blocks-table node #f)
            [#f (set)]
            [(Block _ instrs)
             (for/fold ([live live-after])
                       ([instr (reverse instrs)])
               (set-union (set-subtract live (write-set instr))
                          (read-set instr)))])]))

     ;; Steps 2-4: Run the generic dataflow algorithm.
     ;; Pass (transpose cfg) because liveness is a backward analysis.
     ;; bottom = empty set, join = set-union.
     (define mapping
       (analyze_dataflow (transpose cfg) transfer (set) set-union))

     ;; Step 5: Final pass -- annotate each block with per-instruction
     ;; live-after sets using the converged mapping.
     (define new-blocks
       (for/list ([b blocks])
         (match b
           [(cons label (Block b-info instrs))
            (define-values (live-afters _lb)
              (compute-live-instrs instrs mapping))
            (cons label (Block (dict-set b-info 'live-after live-afters) instrs))])))

     (X86Program info new-blocks)]))

;; compute-live-instrs: walk a block's instructions backwards.
;; Uses label->live to look up live-before sets of jump targets.
;; Returns: (values list-of-live-after-sets  live-before-of-first-instr)
(define (compute-live-instrs instrs label->live)
  (define-values (live-afters _live-before)
    (for/fold ([live-afters '()]
               [live-after  (set)])
              ([instr (reverse instrs)])
      (match instr
        ;; Unconditional jump: live-after of Jmp = live-before of target block.
        [(Jmp lbl)
         (define new-live (hash-ref label->live lbl (set)))
         (values (cons new-live live-afters) new-live)]

        ;; Conditional jump: might go to lbl or fall through.
        ;; live-after = (live-before of fall-through) U (live-before of lbl).
        ;; JmpIf reads/writes no general-purpose variables itself.
        [(JmpIf cc lbl)
         (define new-live (set-union live-after (hash-ref label->live lbl (set))))
         (values (cons new-live live-afters) new-live)]

        ;; Regular instruction: standard backward liveness.
        [_
         (define rd (read-set instr))
         (define wr (write-set instr))
         (define live-before (set-union (set-subtract live-after wr) rd))
         (values (cons live-after live-afters) live-before)])))
  (values live-afters _live-before))

;; Caller-saved registers that might be clobbered by a call
(define caller-saved-regs
  (set 'rax 'rcx 'rdx 'rsi 'rdi 'r8 'r9 'r10 'r11))

;; Argument passing registers (in order)
(define arg-passing-regs
  '(rdi rsi rdx rcx r8 r9))

;; Helper: Set of locations read by an instruction
(define (read-set i)
  (match i
    [(Instr 'movq   (list s d)) (locations-arg s)]
    [(Instr 'addq   (list s d)) (set-union (locations-arg s) (locations-arg d))]
    [(Instr 'subq   (list s d)) (set-union (locations-arg s) (locations-arg d))]
    [(Instr 'negq   (list d))   (locations-arg d)]
    ;; xorq s, d  - reads both operands (e.g. xorq $1, var for boolean not)
    [(Instr 'xorq   (list s d)) (set-union (locations-arg s) (locations-arg d))]
    ;; cmpq s, d  - reads both operands, only writes flags (no GP-reg reads here)
    [(Instr 'cmpq   (list s d)) (set-union (locations-arg s) (locations-arg d))]
    ;; movzbq s, d - reads the byte source
    [(Instr 'movzbq (list s d)) (locations-arg s)]
    ;; set cc, bytereg - only depends on flags, not GP regs
    [(Instr 'set    (list cc d)) (set)]
    [(Callq label arity)
     ;; Reads the first 'arity' argument registers
     (list->set (take arg-passing-regs arity))]
    [_ (set)]))

;; Helper: Set of locations written by an instruction
(define (write-set i)
  (match i
    [(Instr 'movq   (list s d)) (locations-arg d)]
    [(Instr 'addq   (list s d)) (locations-arg d)]
    [(Instr 'subq   (list s d)) (locations-arg d)]
    [(Instr 'negq   (list d))   (locations-arg d)]
    ;; xorq s, d  - writes d
    [(Instr 'xorq   (list s d)) (locations-arg d)]
    ;; cmpq only writes the flags register - no GP-reg destination
    [(Instr 'cmpq   (list s d)) (set)]
    ;; movzbq s, d - writes d
    [(Instr 'movzbq (list s d)) (locations-arg d)]
    ;; set cc, bytereg - writes the byte register (al -> rax)
    [(Instr 'set    (list cc d)) (locations-arg d)]
    [(Callq label arity)      caller-saved-regs]
    [_ (set)]))

;; Helper: Extract vars/regs from an argument.
;; ByteReg 'al is the low byte of rax, so we treat it as 'rax.
(define (locations-arg a)
  (match a
    [(Var x)     (set x)]
    [(Reg r)     (set r)]
    [(ByteReg r) (set 'rax)]   ;; ByteReg 'al is the low byte of rax; treat as rax
    [_ (set)]))

;; -----------------------------------------------------------------------------

;; Helper to extract the raw symbol from an argument
;; (Var 'x) -> 'x
;; (Reg 'rax) -> 'rax
;; (Imm 1) -> 1
(define (get-canonical arg)
  (match arg
    [(Var x) x]
    [(Reg r) r]
    [(Imm n) n]
    [_ arg]))

;; build-interference : x86var -> x86var
(define (build-interference p)
  (match p
    [(X86Program info blocks)
     (define G (undirected-graph '()))
     
     (for ([b blocks])
       (match b
         [(cons label (Block b-info instrs))
          (define live-after-sets (dict-ref b-info 'live-after))
          
          ;; Iterate instructions and live-after sets
          (for ([i instrs] [live-after live-after-sets])
            (match i
              ;; Case 1: movq s, d  (move biasing: no edge between d and s)
              [(Instr 'movq (list s d))
               (define s-sym (get-canonical s))
               (define d-sym (get-canonical d))
               (for ([v live-after])
                 ;; Don't add edge if v is the source (move biasing)
                 ;; or if v is the destination (self-loop)
                 (unless (or (equal? v d-sym) (equal? v s-sym))
                   (add-edge! G d-sym v)))]
              
              ;; Case 2: movzbq src, d  (also a move -- same biasing rule as movq)
              ;; src is always (ByteReg 'al) = low byte of rax.
              ;; Don't add an edge between d and rax, so the allocator may
              ;; assign d to rax and eliminate the move.
              [(Instr 'movzbq (list s d))
               (define s-sym 'rax)
               (define d-sym (get-canonical d))
               (for ([v live-after])
                 (unless (or (equal? v d-sym) (equal? v s-sym))
                   (add-edge! G d-sym v)))]
              
              ;; Case 3: Callq
              [(Callq label arity)
               (for ([v live-after])
                 (for ([r caller-saved-regs])
                   (add-edge! G r v)))]
              
              ;; Case 4: Arithmetic / General
              ;; cmpq  -> write-set {} -> no edges (only writes flags)
              ;; xorq  -> write-set {d} -> edges d<->v
              ;; set   -> write-set {rax} -> edges rax<->v
              [else
               (for ([d (write-set i)])
                 (for ([v live-after])
                   (unless (equal? v d)
                     (add-edge! G d v))))]))]))
     
     (X86Program (dict-set info 'conflicts G) blocks)]))

;; -----------------------------------------------------------------------------

;; 1. Define the registers available for allocation.
;;    Ordered exactly as in EoC sec.3.4 (k = 11):
;;      Colors 0-6  -> caller-saved  (preferred for non-call-live variables)
;;      Colors 7-10 -> callee-saved  (preferred for call-live variables)
;;    Registers excluded from allocation (given negative "special" colors):
;;      rax->-1  rsp->-2  rbp->-3  r11->-4  r15->-5
(define allocatable-regs
  '(rcx rdx rsi rdi r8 r9 r10   ;; caller-saved: colors 0-6
    rbx r12 r13 r14))           ;; callee-saved: colors 7-10

(define num-alloc-regs (length allocatable-regs))

;; Callee-saved registers that the allocator may assign to variables.
;; (r15 is excluded from allocation per the book, so not listed here.)
(define callee-saved-regs
  '(rbx r12 r13 r14))

;; Complete register -> color mapping as specified in EoC sec.3.4.
;; Allocatable registers get non-negative colors 0-10.
;; Non-allocatable ("special") registers get negative colors.
(define reg->color
  (make-hash
   (append
    ;; Allocatable: derive from allocatable-regs list order
    (for/list ([r allocatable-regs] [c (in-naturals)])
      (cons r c))
    ;; Non-allocatable: fixed negative colors from the book
    '((rax . -1) (rsp . -2) (rbp . -3) (r11 . -4) (r15 . -5)))))

;; 2. Helper to map a color index to a specific register or stack location.
;;    Colors 0 to (N-1) -> Registers
;;    Colors N+ -> Stack Spills
;;    Stack layout:  rbp+0 -> [saved rbp]
;;                   rbp-8 -> [callee-saved 1]
;;                   ...
;;                   rbp-8*(C) -> [callee-saved C]
;;                   rbp-8*(C+1) -> [spill 1]
;;                   rbp-8*(C+2) -> [spill 2]
(define (color->home c used-callee-count)
  (if (< c num-alloc-regs)
      (Reg (list-ref allocatable-regs c))             ;; Return the register
      ;; Spill to stack: offset = -8 * (used-callee-count + (c - num-alloc-regs) + 1)
      (Deref 'rbp (- (* 8 (+ used-callee-count (- c num-alloc-regs) 1))))));

;; 3. The main Register Allocation pass
(define (allocate-registers p)
  (match p
    [(X86Program info blocks)
     (define G (dict-ref info 'conflicts))
     
     ;; Step A: Setup for Graph Coloring
     
     ;; Identify all variables/registers in the graph
     (define vars (filter symbol? (get-vertices G)))
     
     ;; Store assignments: Variable -> Color (Int)
     (define color-map (make-hash)) 

     ;; Step B: Saturation sets -- one mutable set per variable tracking which
     ;; neighbor colors it has seen. Pre-seeded from ALL pre-colored register
     ;; neighbors using the complete reg->color mapping (includes negative colors
     ;; for non-allocatable registers rax/rsp/rbp/r11/r15 per EoC sec.3.4).
     (define sat-sets (make-hash))
     (for ([u vars])
       (define init-colors
         (apply mutable-set
                (filter number?
                        (map (lambda (v) (hash-ref reg->color v #f))
                             (get-neighbors G u)))))
       (hash-set! sat-sets u init-colors))

     (define (saturation u) (set-count (hash-ref sat-sets u)))

     ;; Step C: DSatur algorithm using a priority queue (EoC fig. 3.11).
     ;; The pqueue is a min-queue; we store key = (cons (- saturation) var) so
     ;; the most-saturated variable pops first (most-negative = highest priority).
     ;; This gives O((V + E) log V) instead of O(V^2 * E).
     (define pq (make-pqueue (lambda (a b) (<= (car a) (car b)))))

     ;; handles: var -> pqueue node, kept so we can call pqueue-decrease-key!
     ;; whenever a neighbor gets colored and this variable's saturation rises.
     (define handles (make-hash))
     (for ([u vars])
       (hash-set! handles u (pqueue-push! pq (cons (- (saturation u)) u))))

     ;; Main DSatur loop
     (let loop ()
       (when (> (pqueue-count pq) 0)
         ;; 1. Pop the variable with the highest current saturation
         (define u (cdr (pqueue-pop! pq)))

         ;; 2. Collect forbidden colors from all neighbors.
         ;; Already-colored variables use color-map; registers use the
         ;; complete reg->color mapping (covers all 16 registers).
         (define forbidden (mutable-set))
         (for ([v (get-neighbors G u)])
           (cond
             [(hash-has-key? color-map v)
              (set-add! forbidden (hash-ref color-map v))]
             [(hash-has-key? reg->color v)
              (set-add! forbidden (hash-ref reg->color v))]))

         ;; 3. Assign the lowest non-forbidden color
         (define c (let find ([i 0])
                     (if (set-member? forbidden i) (find (+ i 1)) i)))
         (hash-set! color-map u c)

         ;; 4. Update saturation of uncolored symbol neighbors and notify pqueue
         ;;    so it can maintain the max-saturation invariant (pqueue-decrease-key!
         ;;    re-heapifies after we mutate the node's key with set-node-key!).
         (for ([v (get-neighbors G u)])
           (when (and (symbol? v)
                      (hash-has-key? handles v)
                      (not (hash-has-key? color-map v)))
             (set-add! (hash-ref sat-sets v) c)
             (define h (hash-ref handles v))
             (set-node-key! h (cons (- (saturation v)) v))
             (pqueue-decrease-key! pq h)))

         (loop)))

     ;; Step D: Track Used Callee-Saved Registers (before converting to homes)
     
     ;; Determine which callee-saved registers were assigned to variables
     (define used-callee
       (list->set
        (filter (lambda (reg)
                  (member reg callee-saved-regs))
                (map (lambda (c) (list-ref allocatable-regs c))
                     (filter (lambda (c) (< c num-alloc-regs))
                             (hash-values color-map))))))
     
     (define used-callee-count (set-count used-callee))
     
     ;; Step E: Convert Colors to Homes (now with callee count known)
     
     (define home-map
       (for/hash ([(u c) (in-hash color-map)])
         (values u (color->home c used-callee-count))))

     ;; Step F: Calculate Stack Space
     
     ;; Find the highest color used
     (define max-color
       (if (empty? (hash-values color-map))
           0
           (apply max (hash-values color-map))))
     
     ;; Calculate how many spills occurred
     (define num-spills (max 0 (- (+ max-color 1) num-alloc-regs)))
     
     ;; Stack space is now stored separately (for spilled variables only)
     ;; The prelude_and_conclusion pass will handle alignment
     (define stack-space (* 8 num-spills))

     ;; Step G: Rewrite Instructions
     
     (define (resolve arg)
       (match arg
         [(Var x) (hash-ref home-map x)]
         [_ arg]))

     (define new-blocks
       (for/list ([b blocks])
         (match b
           [(cons label (Block b-info instrs))
            (define new-instrs
              (for/list ([i instrs])
                (match i
                  [(Instr op args) (Instr op (map resolve args))]
                  [(Callq func arity) (Callq func arity)]
                  [(Jmp label) (Jmp label)]
                  [_ i])))
            (cons label (Block b-info new-instrs))])))

     ;; Return the new program with updated instructions, stack info, and used callee-saved registers
     (define new-info (dict-set* info 
                                 'stack-size stack-space
                                 'used_callee used-callee))
     (X86Program new-info new-blocks)]))

;; -----------------------------------------------------------------------------

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; HW5 Passes
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; -----------------------------------------------------------------------------
;; uncover-get! : Lwhile -> Lwhile
;;
;; Identifies all variables that are mutated (appear as the LHS of a set!)
;; and replaces all their reads with (GetBang x) to mark them as effectful.
;; This prevents remove-complex-opera* from reordering them past side effects.
;; -----------------------------------------------------------------------------

;; collect-set! : exp -> (setof symbol)
;; Returns the set of all variable names that appear on the LHS of a SetBang.
(define (collect-set! e)
  (match e
    [(SetBang x rhs)   (set-union (set x) (collect-set! rhs))]
    [(Let x rhs body)  (set-union (collect-set! rhs) (collect-set! body))]
    [(WhileLoop c b)   (set-union (collect-set! c) (collect-set! b))]
    [(Begin es body)   (apply set-union (collect-set! body) (map collect-set! es))]
    [(If c t f)        (set-union (collect-set! c) (collect-set! t) (collect-set! f))]
    [(Prim _ args)     (apply set-union (set) (map collect-set! args))]
    [_ (set)]))

;; uncover-get!-exp : (setof symbol) -> (exp -> exp)
;; Replaces (Var x) with (GetBang x) for all x in mutable-vars.
(define ((uncover-get!-exp mutable-vars) e)
  (define recur (uncover-get!-exp mutable-vars))
  (match e
    [(Var x)
     (if (set-member? mutable-vars x) (GetBang x) (Var x))]
    [(SetBang x rhs)   (SetBang x (recur rhs))]
    [(WhileLoop c b)   (WhileLoop (recur c) (recur b))]
    [(Begin es body)   (Begin (map recur es) (recur body))]
    [(Let x rhs body)  (Let x (recur rhs) (recur body))]
    [(If c t f)        (If (recur c) (recur t) (recur f))]
    [(Prim op args)    (Prim op (map recur args))]
    [_ e]))

(define (uncover-get! p)
  (match p
    [(Program info e)
     (define mutable-vars (collect-set! e))
     (Program info ((uncover-get!-exp mutable-vars) e))]))

;; -----------------------------------------------------------------------------

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; HW4 Passes 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; -----------------------------------------------------------------------------
;; shrink : Lif -> Lif
;; Removes 'and' and 'or' operators by translating them to 'if' expressions
;; Translations:
;;   (and e1 e2) => (if e1 e2 #f)
;;   (or e1 e2)  => (if e1 #t e2)
;; -----------------------------------------------------------------------------

(define (shrink-exp e)
  (match e
    ;; Boolean constants
    [(Bool b) (Bool b)]
    
    ;; Integers
    [(Int n) (Int n)]
    
    ;; Variables
    [(Var x) (Var x)]
    
    ;; Let expressions - recursively shrink both RHS and body
    [(Let x rhs body)
     (Let x (shrink-exp rhs) (shrink-exp body))]
    
    ;; If expressions - recursively shrink all three subexpressions
    [(If cnd thn els)
     (If (shrink-exp cnd) (shrink-exp thn) (shrink-exp els))]
    
    ;; And operator: (and e1 e2) => (if e1 e2 #f)
    [(Prim 'and (list e1 e2))
     (If (shrink-exp e1) (shrink-exp e2) (Bool #f))]
    
    ;; Or operator: (or e1 e2) => (if e1 #t e2)
    [(Prim 'or (list e1 e2))
     (If (shrink-exp e1) (Bool #t) (shrink-exp e2))]
    
    ;; Other primitives - recursively shrink arguments
    [(Prim op args)
     (Prim op (map shrink-exp args))]

    ;; LWhile new forms
    [(SetBang x rhs)   (SetBang x (shrink-exp rhs))]
    [(WhileLoop c b)   (WhileLoop (shrink-exp c) (shrink-exp b))]
    [(Begin es body)   (Begin (map shrink-exp es) (shrink-exp body))]
    [(Void)            (Void)]

    ;; Fallback for any other expression types
    [else e]))

(define (shrink p)
  (match p
    [(Program info e) (Program info (shrink-exp e))]))

;; -----------------------------------------------------------------------------

;; Define the compiler passes to be used by interp-tests and the grader
;; Note that your compiler file (the file that defines the passes)
;; must be named "compiler.rkt"
(define compiler-passes
  `(
     ("shrink",shrink,interp-Lwhile ,type-check-Lwhile)
     ("uniquify",uniquify,interp-Lwhile ,type-check-Lwhile)
     ("uncover-get!",uncover-get!,interp-Lwhile ,type-check-Lwhile)
     ("remove complex opera*",remove-complex-opera* ,interp-Lwhile ,type-check-Lwhile)
     ("explicate control",explicate-control,interp-Cwhile ,type-check-Cwhile)
     ("instruction selection" ,select-instructions ,interp-pseudo-x86-1)
     ("liveness analysis" ,uncover-live,interp-pseudo-x86-1)
     ("build interference" ,build-interference,interp-pseudo-x86-1)
     ("allocate registers" ,allocate-registers,interp-pseudo-x86-1)
     ("patch instructions" ,patch-instructions,interp-pseudo-x86-1)
     ("prelude-and-conclusion" ,prelude-and-conclusion ,interp-x86-1)
     ))
