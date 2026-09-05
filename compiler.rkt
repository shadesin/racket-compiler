#lang racket
(require racket/set racket/stream)
(require racket/fixnum)
(require data/queue)
(require graph)
(require "multigraph.rkt")
(require "priority_queue.rkt")
(require "compiler/abi.rkt")
(require "compiler/dataflow.rkt")
(require "compiler/heap-layout.rkt")
(require "compiler/labels.rkt")
(require "interp-Lint.rkt")
(require "interp-Lvar.rkt")
(require "interp-Lif.rkt")
(require "interp-Lwhile.rkt")
(require "interp-Lvec.rkt")
(require "interp-Lvec-prime.rkt")
(require "interp-Cvar.rkt")
(require "interp-Cif.rkt")
(require "interp-Cwhile.rkt")
(require "interp-Cvec.rkt")
(require "interp-Lfun.rkt")
(require "interp-Lfun-prime.rkt")
(require "interp-Cfun.rkt")
(require "interp.rkt")
(require "type-check-Lvar.rkt")
(require "type-check-Lif.rkt")
(require "type-check-Lwhile.rkt")
(require "type-check-Lvec.rkt")
(require "type-check-Cvar.rkt")
(require "type-check-Cif.rkt")
(require "type-check-Cwhile.rkt")
(require "type-check-Cvec.rkt")
(require "type-check-Lfun.rkt")
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
      ;; Chapter 6: HasType wraps vector creation after type-checking
      [(HasType e t)
       (HasType ((uniquify-exp env) e) t)]
      ;; GlobalValue, Allocate, Collect don't contain variable references
      [(GlobalValue name) (GlobalValue name)]
      [(Allocate n t) (Allocate n t)]
      [(Collect n) (Collect n)]
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

    ;; Chapter 6: HasType -- strip the wrapper, rco-exp the inner expression
    ;; (expose-allocation has already lowered vector creation, so HasType
    ;; should only appear on already-simple forms by now)
    [(HasType e t) (rco-exp e)]

    ;; Chapter 6: Collect, Allocate, GlobalValue are complex (not atomic);
    ;; rco-atom will bind them to a temp variable.
    ;; We leave them as-is here; rco-prim handles their args (none).
    [(Collect n) (Collect n)]
    [(Allocate n t) (Allocate n t)]
    [(GlobalValue name) (GlobalValue name)]

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
;; Chapter 5 Figure 5.6: (Void) is listed as an atm in Lmon_While.
;; Chapter 6: Collect, Allocate, GlobalValue are NOT atomic (complex).
(define (atomic? e)
  (match e
    [(Int _)  #t]
    [(Var _)  #t]
    [(Bool _) #t]
    [(Void)   #t]   ;; (void) is an atom per Fig 5.6
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
    ;; Let in effect position: process the binding for effects (rhs may itself
    ;; have side effects), then process the body for effects.
    ;; §5.6: "only begin may appear in predicate positions; the other two have
    ;; result type Void." Let in effect position is handled similarly.
    [(Let x rhs body)
     (explicate-assign rhs x (explicate-effect body k))]

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

    ;; Pure atoms (including GetBang) -- result discarded, no meaningful side effect
    ;; GetBang is just a read; reading and discarding a mutable variable has no effect.
    [(or (Int _) (Bool _) (Var _) (GetBang _)) k]

    ;; (read) has a side effect -- emit the call but discard the result
    [(Prim 'read '())
     (Seq (Prim 'read '()) k)]

    ;; Chapter 6: Collect is a pure effect (GC call) -- emit it as a statement
    [(Collect n)
     (Seq (Collect n) k)]

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
    ;; Chapter 6: Collect on rhs -- emit the collect, then assign Void to x
    [(Collect n)
     (Seq (Collect n) (Seq (Assign (Var x) (Void)) k))]
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
    ;; Use explicate-assign-fun so Apply on the rhs becomes a Call (not a raw expression).
    [(Let x rhs body)
     (explicate-assign-fun rhs x (explicate-pred body thn els))]
    ;; (not e): swap the then/else branches and recurse
    [(Prim 'not (list e))
     (explicate-pred e els thn)]
    ;; Comparison operator: emit IfStmt directly
    [(Prim op es) #:when (member op '(eq? < <= > >=))
     (IfStmt (Prim op es) (create-block thn) (create-block els))]
    ;; Boolean constant: partial evaluation -- discard one branch
    [(Bool b) (if b thn els)]
    ;; begin in predicate: effects (using explicate-effect-fun for Apply), then condition
    [(Begin es body)
     (foldr (lambda (sub acc) (explicate-effect-fun sub acc))
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
    ;; Function call used as a condition: evaluate it first, then test tmp.
    [(Apply fun args)
     (define tmp (gensym 'predtmp))
     (explicate-assign-fun cnd tmp (explicate-pred (Var tmp) thn els))]
    ;; Any other complex expression in predicate position (e.g., vector-ref returning Boolean,
    ;; GetBang of a mutable Boolean var, etc.): bind to a temp, then compare against #t.
    [_
     (define tmp (gensym 'predtmp))
     (explicate-assign cnd tmp
       (IfStmt (Prim 'eq? (list (Var tmp) (Bool #t)))
               (create-block thn)
               (create-block els)))]))

;; -- Expression lowering
;; explicate-exp : exp -> exp (CTup atomic/prim)
(define (explicate-exp e)
  (match e
    [(Int n) (Int n)]
    [(Bool b) (Bool b)]
    [(Var x) (Var x)]
    [(FunRef f n) (FunRef f n)]
    [(Void) (Void)]
    ;; GetBang lowers to a plain variable reference in C form
    [(GetBang x) (Var x)]
    [(Prim 'read '()) (Prim 'read '())]
    ;; Chapter 6: GlobalValue and Allocate become C expressions
    [(GlobalValue name) (GlobalValue name)]
    [(Allocate n t) (Allocate n t)]
    ;; vector-ref, vector-set!, vector-length pass through
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

    ;; Case: dst = function reference
    [(FunRef f n)
      (list (Instr 'leaq (list (Global (mangle-function-label f)) dst)))]

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
           (Instr 'movzbq (list (ByteReg 'al) dst)))]

    ;; ------------------------------------------------------------------
    ;; Chapter 6: Tuple / GC operations
    ;; ------------------------------------------------------------------

    ;; Case: dst = (global-value name)
    ;; Read a global variable via RIP-relative addressing
    [(GlobalValue name)
     (list (Instr 'movq (list (Global name) dst)))]

    ;; Case: dst = (allocate len type)
    ;; Inline allocation:
    ;;   movq free_ptr(%rip), %r11
    ;;   addq $8*(len+1), free_ptr(%rip)
    ;;   movq $tag, 0(%r11)
    ;;   movq %r11, dst
    ;; The tag encodes: bit0=1 (not-copied), bits 1-6=length, bits 7+=pointer-mask
    [(Allocate len type)
     (define tag (compute-tag len type))
     (list (Instr 'movq (list (Global 'free_ptr) (Reg 'r11)))
           (Instr 'addq (list (Imm (* 8 (+ len 1))) (Global 'free_ptr)))
           (Instr 'movq (list (Imm tag) (Deref 'r11 0)))
           (Instr 'movq (list (Reg 'r11) dst)))]

    ;; Case: dst = (vector a0 ... an)
    ;; Fallback lowering for residual vector literals.
    [(Prim 'vector args)
     (define len (length args))
     (define tag (compute-tag len `(Vector ,@(for/list ([_ args]) 'Integer))))
     (append
      (list (Instr 'movq (list (Global 'free_ptr) (Reg 'r11)))
            (Instr 'addq (list (Imm (* 8 (+ len 1))) (Global 'free_ptr)))
            (Instr 'movq (list (Imm tag) (Deref 'r11 0))))
      (for/list ([a args] [i (in-naturals)])
        (Instr 'movq (list (select-atm a) (Deref 'r11 (* 8 (+ i 1))))))
      (list (Instr 'movq (list (Reg 'r11) dst))))]

    ;; Case: dst = (vector-ref tup n)
    ;;   movq tup, %r11
    ;;   movq 8*(n+1)(%r11), dst
    [(Prim 'vector-ref (list tup (Int n)))
     (list (Instr 'movq (list (select-atm tup) (Reg 'r11)))
           (Instr 'movq (list (Deref 'r11 (* 8 (+ n 1))) dst)))]

    ;; Case: dst = (vector-set! tup n rhs)
    ;;   movq tup, %r11
    ;;   movq rhs', 8*(n+1)(%r11)
    ;;   movq $0, dst
    [(Prim 'vector-set! (list tup (Int n) rhs))
     (list (Instr 'movq (list (select-atm tup) (Reg 'r11)))
           (Instr 'movq (list (select-atm rhs) (Deref 'r11 (* 8 (+ n 1)))))
           (Instr 'movq (list (Imm 0) dst)))]

    ;; Case: dst = (vector-length tup)
    ;; Read tag word, extract bits 1-6 (length field)
    ;;   movq tup, %r11
    ;;   movq 0(%r11), dst
    ;;   andq $126, dst   (mask out everything except bits 1-6; 126 = 0b01111110)
    ;;   sarq $1, dst     (shift right by 1 to normalize)
    [(Prim 'vector-length (list tup))
     (list (Instr 'movq (list (select-atm tup) (Reg 'r11)))
           (Instr 'movq (list (Deref 'r11 0) dst))
           (Instr 'andq (list (Imm 126) dst))
           (Instr 'sarq (list (Imm 1) dst)))]

    ;; Fallback: unknown expression format
    [_ (error 'select-assign (format "unhandled expression (~a): ~a" (if (list? e) (car e) 'unknown) e))]))

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
     (list (Callq 'read_int 0))]
    ;; Chapter 6: (collect bytes) -> movq %r15, %rdi; movq $bytes, %rsi; callq collect
    [(Collect bytes)
     (list (Instr 'movq (list (Reg 'r15) (Reg 'rdi)))
           (Instr 'movq (list (Imm bytes) (Reg 'rsi)))
           (Callq 'collect 2))]))

;; Helper to translate atomic expressions (Int/Bool/Var/Global) to x86 arguments
;; Bool #t => 1, Bool #f => 0  (booleans are encoded as integers)
;; Chapter 6: GlobalValue -> Global (RIP-relative addressing)
(define (select-atm a)
  (match a
    [(Int n)          (Imm n)]
    [(Bool #t)        (Imm 1)]
    [(Bool #f)        (Imm 0)]
    [(Void)           (Imm 0)]   ;; void encodes as 0
    [(Var x)          (Var x)]
    [(GlobalValue n)  (Global n)]))
  
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

    ;; Case 3a: Large immediate with a memory (Deref) destination.
    ;; x86-64 arithmetic ops only accept 32-bit sign-extended immediates.
    ;; Move the large constant into %rax first, then operate on memory.
    [(Instr op (list (Imm n) (Deref r o)))
     #:when (or (> n 2147483647) (< n -2147483648))
     (list (Instr 'movq (list (Imm n) (Reg 'rax)))
           (Instr op (list (Reg 'rax) (Deref r o))))]

    ;; Case 3b: Large immediate with a register destination.
    ;; Same 32-bit immediate limit applies even when dst is a register.
    ;; Use %r10 as scratch if dst is %rax (to avoid clobbering it), else %rax.
    [(Instr op (list (Imm n) (Reg dst)))
     #:when (and (not (eq? op 'movq))   ;; movq supports full 64-bit immediates
                 (or (> n 2147483647) (< n -2147483648)))
     (define scratch (if (eq? dst 'rax) 'r10 'rax))
     (list (Instr 'movq (list (Imm n) (Reg scratch)))
           (Instr op   (list (Reg scratch) (Reg dst))))]

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
;; Chapter 6 version: sets up garbage collector, root stack, and r15.
(define (prelude-and-conclusion p)
  (match p
    [(X86Program info blocks)
     (define stack-size (dict-ref info 'stack-size))  ;; Space for spilled variables
     (define used-callee (dict-ref info 'used_callee (set)))  ;; Callee-saved regs used
     (define num-root-spills (dict-ref info 'num-root-spills 0))  ;; Chapter 6: root stack spills

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
     
     ;; Build prelude: push rbp, set rbp, push callee-saved regs, adjust rsp
     ;; Chapter 6: also call initialize, set r15, zero root stack slots, addq r15
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
        ;; Chapter 6: Initialize garbage collector
        (list (Instr 'movq (list (Imm 65536) (Reg 'rdi)))
              (Instr 'movq (list (Imm 65536) (Reg 'rsi)))
              (Callq 'initialize 2)
              ;; Load rootstack_begin into r15
              (Instr 'movq (list (Global 'rootstack_begin) (Reg 'r15))))
        ;; Chapter 6: Zero-initialize all root stack slots before use
        ;; (GC tests for null before dereferencing)
        (for/list ([i (in-range num-root-spills)])
          (Instr 'movq (list (Imm 0) (Deref 'r15 (* 8 i)))))
        ;; Chapter 6: Move r15 up by the size of the root-stack frame
        (if (> num-root-spills 0)
            (list (Instr 'addq (list (Imm (* 8 num-root-spills)) (Reg 'r15))))
            '())
        (list (Jmp 'start))))
     
     ;; Build conclusion: restore rsp, pop callee-saved regs (in reverse), pop rbp, return
     (define conclusion
       (append
        ;; Chapter 6: Move r15 back down past root stack frame
        (if (> num-root-spills 0)
            (list (Instr 'subq (list (Imm (* 8 num-root-spills)) (Reg 'r15))))
            '())
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
                 (cons (cons 'main (Block '() prelude))
                       (append blocks
                               (list (cons 'conclusion (Block '() conclusion))))))]))

;; -----------------------------------------------------------------------------


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; HW3 Passes
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; ------------------------------------------------------------------------------
;; uncover-live : x86var -> x86var
;; Liveness analysis via analyze-dataflow.
;;
;; Liveness is a BACKWARD analysis. analyze-dataflow joins successor states,
;; so the raw CFG is passed directly and the helper handles predecessor
;; re-enqueuing internally.
;; The transfer function receives (label, live-after) and returns live-before
;; by walking the block's instructions backwards using read-set / write-set.
;; Jump instructions are transparent (empty read/write sets), so liveness
;; passes through them unchanged; analyze-dataflow already unions the
;; live-before sets of all successor blocks to form live-after.
;;
;; After analyze-dataflow converges, a single final pass annotates each block
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
     ;; Pass cfg directly: analyze-dataflow joins successors' states to form
     ;; each node's input (= live-after for liveness) and re-enqueues predecessors
     ;; when live-before changes. No external transpose needed.
     (define mapping
       (analyze-dataflow cfg transfer (set) set-union))

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
    ;; Chapter 6: andq, sarq - reads destination (used for vector-length)
    [(Instr 'andq   (list s d)) (set-union (locations-arg s) (locations-arg d))]
    [(Instr 'sarq   (list s d)) (set-union (locations-arg s) (locations-arg d))]
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
    ;; Chapter 6: andq, sarq - writes destination
    [(Instr 'andq   (list s d)) (locations-arg d)]
    [(Instr 'sarq   (list s d)) (locations-arg d)]
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
;; Chapter 6: For Callq 'collect, vector-typed variables that are live must
;; also interfere with callee-saved registers (to force them to the root stack).
;; The type information is stored in 'locals-types in the program info.
(define (build-interference p)
  (match p
    [(X86Program info blocks)
     (define G (undirected-graph '()))
     ;; Get type info for variables (may be absent for non-vec programs)
     (define var-types (dict-ref info 'locals-types '()))
     
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
               ;; Standard: live vars interfere with caller-saved regs
               (for ([v live-after])
                 (for ([r caller-saved-regs])
                   (add-edge! G r v)))
               ;; Chapter 6: If this is a call to 'collect, vector-typed live
               ;; variables must ALSO interfere with callee-saved registers.
               ;; This forces them to spill (to root stack), making them
               ;; visible to the garbage collector.
               (when (equal? label 'collect)
                 (for ([v live-after])
                   (when (and (symbol? v)
                              (vector-type? (dict-ref var-types v #f)))
                     (for ([r callee-saved-regs])
                       (add-edge! G r v)))))]
              
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

;; vector-type? : type -> boolean
;; Returns #t if the type is a Vector type (i.e., a GC-visible heap pointer).
;; Raw function addresses are not managed by the collector.
(define (vector-type? t)
  (is-gc-pointer-type? t))

;; -----------------------------------------------------------------------------

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
;; Chapter 6: Variables of Vector type that spill go to the ROOT STACK
;; (r15-relative) rather than the regular stack (rbp-relative).
(define (allocate-registers p)
  (match p
    [(X86Program info blocks)
     (define G (dict-ref info 'conflicts))
     ;; Some temps may have no conflicts (isolated vertices). Add them so the
     ;; allocator still assigns a home.
     (for ([b blocks])
       (match b
         [(cons _ (Block _ instrs))
          (for ([i instrs])
            (match i
              [(Instr _ args)
               (for ([a args])
                 (match a
                   [(Var x) (add-vertex! G x)]
                   [_ (void)]))]
              [_ (void)]))]))
     ;; Type information for local variables (used to decide root vs regular spill)
     (define var-types (dict-ref info 'locals-types '()))
     
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
     ;; Chapter 6: Vector-typed variables that spill go to root stack (r15-relative)
     ;;   Root stack grows upward: slot i is at 8*i offset from where r15 started.
     ;;   We number root-stack slots separately, starting from 0.
     ;; Regular spilled variables go to rbp-relative locations as before.

     ;; First pass: figure out how many root-stack slots we need and
     ;; assign root-stack slot indices to vector-typed spilled variables.
     (define root-slot-map (make-hash))  ;; var -> root-stack slot index
     (define root-slot-counter 0)        ;; mutable counter

     (for ([(u c) (in-hash color-map)])
       (when (and (>= c num-alloc-regs)   ;; it's a spill
                  (vector-type? (dict-ref var-types u #f)))  ;; it's a vector
         (hash-set! root-slot-map u root-slot-counter)
         (set! root-slot-counter (+ root-slot-counter 1))))

     (define num-root-spills root-slot-counter)

     ;; Now count regular (non-vector) spills
     (define num-regular-spills
       (for/sum ([(u c) (in-hash color-map)])
         (if (and (>= c num-alloc-regs)
                  (not (hash-has-key? root-slot-map u)))
             1
             0)))

     ;; Build home-map: color -> home
     ;; For regular spills we number them 0... among the non-vector spills
     (define regular-spill-index (make-hash))  ;; var -> regular spill index
     (define regular-spill-counter 0)
     (for ([(u c) (in-hash color-map)])
       (when (and (>= c num-alloc-regs)
                  (not (hash-has-key? root-slot-map u)))
         (hash-set! regular-spill-index u regular-spill-counter)
         (set! regular-spill-counter (+ regular-spill-counter 1))))

     (define home-map
       (for/hash ([(u c) (in-hash color-map)])
         (cond
           [(< c num-alloc-regs)
            ;; Assigned to a register
            (values u (Reg (list-ref allocatable-regs c)))]
           [(hash-has-key? root-slot-map u)
            ;; Vector-typed spill: goes to root stack
            ;; Root stack slots are at (old-r15 + 8*slot), so we use
            ;; (Deref 'r15 (* -8 (- num-root-spills slot))) relative to the
            ;; post-increment r15. Actually the book uses 0(%r15), 8(%r15) etc
            ;; relative to the pre-increment r15 base. We use negative offsets
            ;; from the incremented r15: slot 0 = -8*(num-root-spills), slot 1 = ...
            ;; Simpler: relative to the TOP of root frame = r15 after increment.
            ;; slot i lives at (base + 8*i) = (r15_at_entry - 8*num_root_spills + 8*i)
            ;;                             = r15_after - 8*(num_root_spills - i)
            ;; BUT the book just uses 0-based from the base before increment.
            ;; We'll use offsets relative to the original r15 (before addq):
            ;;   slot 0 -> 0(%r15_base)
            ;;   slot 1 -> -8(%r15_base)  (since r15 was incremented by 8*n)
            ;; The easiest approach: spill to a special tag, then prelude-and-conclusion
            ;; handles the actual initialization. We simply use Deref 'r15 with the
            ;; NEGATIVE offset from the post-increment r15:
            ;;   after addq $8*n, %r15: slot i is at -8*(n-i)(%r15)
            (define slot (hash-ref root-slot-map u))
            (values u (Deref 'r15 (* -8 (- num-root-spills slot))))]
           [else
            ;; Regular spill: rbp-relative
            (define idx (hash-ref regular-spill-index u))
            (values u (Deref 'rbp (- (* 8 (+ used-callee-count idx 1)))))])))

     ;; Step F: Calculate Stack Space (regular spills only)
     (define stack-space (* 8 num-regular-spills))

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
                                 'used_callee used-callee
                                 'num-root-spills num-root-spills))
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
    [(HasType e t)     (collect-set! e)]
    [(Prim _ args)     (apply set-union (set) (map collect-set! args))]
    ;; Chapter 7: Apply -- recurse into function and all arguments
    [(Apply fun args)  (apply set-union (set) (collect-set! fun) (map collect-set! args))]
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
    [(HasType e t)     (HasType (recur e) t)]
    [(Prim op args)    (Prim op (map recur args))]
    ;; Chapter 7: Apply -- recurse into function and all arguments
    [(Apply fun args)  (Apply (recur fun) (map recur args))]
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

    ;; Chapter 6: vector forms (just pass through, shrink inner exprs)
    [(HasType e t)     (HasType (shrink-exp e) t)]
    [(GlobalValue name) (GlobalValue name)]
    [(Allocate n t)    (Allocate n t)]
    [(Collect n)       (Collect n)]

    ;; Chapter 7: Apply -- shrink fun and all args (so and/or inside args get desugared)
    [(Apply fun args)
     (Apply (shrink-exp fun) (map shrink-exp args))]

    ;; Fallback for any other expression types
    [else e]))

(define (shrink p)
  (match p
    [(Program info e) (Program info (shrink-exp e))]))

;; -----------------------------------------------------------------------------
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Chapter 6 New Passes
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; -----------------------------------------------------------------------------
;; expose-allocation : LTup -> LTup (lowered)
;;
;; Lowers (HasType (Prim 'vector (e0 ... en-1)) (Vector t0 ... tn-1)) into:
;;
;;   (Let x0 e0
;;     (Let x1 e1
;;       ...
;;         (Let _ (if (< (+ (global-value free_ptr) bytes)
;;                        (global-value fromspace_end))
;;                    (void)
;;                    (Collect bytes))
;;           (Let v (Allocate len type)
;;             (Let _ (vector-set! v 0 x0)
;;               (Let _ (vector-set! v 1 x1)
;;                 ...
;;                 v))))))
;;
;; where bytes = 8 * (len + 1)  (tag word + len data words)
;; -----------------------------------------------------------------------------

(define (expose-alloc-exp e)
  (match e
    ;; ---------- The main case: (HasType (vector e0 ... en-1) type) ----------
    [(HasType (Prim 'vector args) type)
     (define len (length args))
     (define bytes (* 8 (+ len 1)))   ;; 1 tag word + len data words
     ;; First, expose-allocate all sub-expressions recursively
     (define args^ (map expose-alloc-exp args))
     ;; Generate fresh temp names for each element
     (define tmps (for/list ([_ args^]) (gensym 'alloctmp)))
     ;; Generate a fresh name for the allocated tuple
     (define vtmp (gensym 'vec))
     ;; GC check: if free_ptr + bytes >= fromspace_end, collect
     (define gc-check
       (If (Prim '< (list
                     (Prim '+ (list (GlobalValue 'free_ptr) (Int bytes)))
                     (GlobalValue 'fromspace_end)))
           (Void)
           (Collect bytes)))
     ;; Chain of vector-set! calls to initialize fields
     (define setters
       (for/foldr ([acc (Var vtmp)])
                  ([tmp tmps] [idx (in-naturals)])
         (Let (gensym 'ignored)
              (Prim 'vector-set! (list (Var vtmp) (Int idx) (Var tmp)))
              acc)))
     ;; Wrap in Let for allocation
     (define alloc-let
       (Let vtmp (Allocate len type) setters))
     ;; Wrap in Let for GC check
     (define gc-let
       (Let (gensym 'ignored) gc-check alloc-let))
     ;; Wrap in Let for each element binding (innermost first, so use foldr)
     (foldr (lambda (tmp arg acc)
               (Let tmp arg acc))
            gc-let
            tmps
            args^)]

    ;; ---------- Strip HasType from non-vector expressions ----------
    [(HasType e t) (expose-alloc-exp e)]

    ;; ---------- Bare (Prim 'vector ...) without HasType ----------
    ;; This can happen in tests that bypass the type checker.
    ;; We recursively expose the args first, then infer element types:
    ;;   - If an arg is an (Allocate n type), its type IS the element type.
    ;;   - Otherwise, use Integer as a safe fallback.
    ;; This prevents incorrect all-Integer pointer masks for nested vectors.
    [(Prim 'vector args)
     (define args^ (map expose-alloc-exp args))
     (define elem-types
       (for/list ([a args^])
         (match a
           ;; Already-lowered allocation: the Allocate node carries the type
           [(Allocate _ t) t]
           ;; Nested vector creation wrapped in Let chains: check for Allocate in body
           ;; If we cannot determine the type statically, default to Integer.
           [_ 'Integer])))
     (define vec-ty `(Vector ,@elem-types))
     (expose-alloc-exp (HasType (Prim 'vector args) vec-ty))]

    ;; ---------- Recursive cases ----------
    [(Let x rhs body)
     (Let x (expose-alloc-exp rhs) (expose-alloc-exp body))]
    [(If c t f)
     (If (expose-alloc-exp c) (expose-alloc-exp t) (expose-alloc-exp f))]
    [(Prim op args)
     (Prim op (map expose-alloc-exp args))]
    [(SetBang x rhs)
     (SetBang x (expose-alloc-exp rhs))]
    [(Begin es body)
     (Begin (map expose-alloc-exp es) (expose-alloc-exp body))]
    [(WhileLoop c b)
     (WhileLoop (expose-alloc-exp c) (expose-alloc-exp b))]
    ;; Atoms and already-lowered forms pass through
    [_ e]))

(define (expose-allocation p)
  (match p
    [(Program info e)
     (Program info (expose-alloc-exp e))]))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Chapter 7 Passes: Functions
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; -----------------------------------------------------------------------------
;; shrink-fun : LFun -> LFun
;; In addition to the existing shrink work (and/or -> if), this pass
;; wraps the top-level expression into a `main` function definition and
;; converts ProgramDefsExp to ProgramDefs.
(define (shrink-fun p)
  (match p
    [(ProgramDefsExp info ds body)
     ;; Shrink each function definition's body
     (define ds^ (for/list ([d ds])
                   (match d
                     [(Def f params rty dinfo dbody)
                      (Def f params rty dinfo (shrink-exp dbody))])))
     ;; Shrink the top-level body and wrap into a main def
     (define body^ (shrink-exp body))
     (define main-def (Def 'main '() 'Integer '() body^))
     (ProgramDefs info (append ds^ (list main-def)))]
    ;; If already ProgramDefs (already shrunk), handle def bodies
    [(ProgramDefs info ds)
     (define ds^ (for/list ([d ds])
                   (match d
                     [(Def f params rty dinfo dbody)
                      (Def f params rty dinfo (shrink-exp dbody))])))
     (ProgramDefs info ds^)]
    ;; Non-function program: fall back to existing shrink
    [(Program info e)
     (shrink p)]))

;; -----------------------------------------------------------------------------
;; reveal-functions : LFun -> LFunRef
;; Replaces (Var f) references to top-level function names with (FunRef f n)
;; where n is the arity of the function.
(define (reveal-functions p)
  (match p
    [(ProgramDefs info ds)
     ;; Build a map from function name -> arity
     (define fun-arity
       (for/hash ([d ds])
         (values (Def-name d) (length (Def-param* d)))))
     ;; Recurse through each definition's body
     (define (reveal-exp e)
       (match e
         [(Var x)
          (if (hash-has-key? fun-arity x)
              (FunRef x (hash-ref fun-arity x))
              (Var x))]
         [(FunRef f n) (FunRef f n)]
         [(Int n) (Int n)]
         [(Bool b) (Bool b)]
         [(Void) (Void)]
         [(Let x rhs body)
          (Let x (reveal-exp rhs) (reveal-exp body))]
         [(If c t f)
          (If (reveal-exp c) (reveal-exp t) (reveal-exp f))]
         [(Apply fun args)
          (Apply (reveal-exp fun) (map reveal-exp args))]
         [(SetBang x rhs) (SetBang x (reveal-exp rhs))]
         [(Begin es body) (Begin (map reveal-exp es) (reveal-exp body))]
         [(WhileLoop c b) (WhileLoop (reveal-exp c) (reveal-exp b))]
         [(HasType e t) (HasType (reveal-exp e) t)]
         [(GlobalValue name) (GlobalValue name)]
         [(Allocate n t) (Allocate n t)]
         [(Collect n) (Collect n)]
         [(Prim op args) (Prim op (map reveal-exp args))]
         [_ e]))
     (define ds^
       (for/list ([d ds])
         (match d
           [(Def f params rty dinfo body)
            (Def f params rty dinfo (reveal-exp body))])))
     (ProgramDefs info ds^)]))

;; -----------------------------------------------------------------------------
;; limit-functions : LFunRef -> LFunRef
;; Packs extra parameters (beyond 6) into a tuple for functions with > 6 params.

;; Parse a parameter declaration of the form [x : T].
(define (limit-param-name p)
  (match p
    [`[,x : ,_] x]
    [else (error 'limit-functions "bad parameter ~a" p)]))

(define (limit-param-type p)
  (match p
    [`[,_ : ,t] t]
    [else (error 'limit-functions "bad parameter ~a" p)]))

;; Build an environment mapping each top-level function name to its function type.
(define (build-limit-fun-type-env ds)
  (for/hash ([d ds])
    (match d
      [(Def f (list `[,xs : ,ps] ...) rt _ _)
       (values f `(,@ps -> ,rt))]
      [else (error 'limit-functions "ill-formed function definition ~a" d)])))

;; Lightweight type inference used only to annotate packed argument tuples.
;; This keeps the tuple element types precise (especially for vector-typed args)
;; so expose-allocation can compute correct GC pointer masks.
(define (infer-limit-type env e)
  (match e
    [(Int _) 'Integer]
    [(Bool _) 'Boolean]
    [(Void) 'Void]
    [(Var x)
     (define t (dict-ref env x #f))
     (if t
         t
         (error 'limit-functions "unknown variable in type inference: ~a" x))]
    [(FunRef f _)
     (define t (dict-ref env f #f))
     (if t
         t
         (error 'limit-functions "unknown function in type inference: ~a" f))]
    [(HasType _ t) t]
    [(Let x rhs body)
     (define rhs-ty (infer-limit-type env rhs))
     (infer-limit-type (dict-set env x rhs-ty) body)]
    [(If _ thn _)
     (infer-limit-type env thn)]
    [(Begin _ body)
     (infer-limit-type env body)]
    [(WhileLoop _ _) 'Void]
    [(SetBang _ _) 'Void]
    [(Apply fun _)
     (match (infer-limit-type env fun)
       [`(,_ ... -> ,rt) rt]
       [other (error 'limit-functions "expected function type, not ~a" other)])]
    [(GlobalValue _) 'Integer]
    [(Allocate _ t) t]
    [(Collect _) 'Void]
    [(Prim 'read '()) 'Integer]
    [(Prim 'vector args)
     `(Vector ,@(map (lambda (a) (infer-limit-type env a)) args))]
    [(Prim 'vector-length (list _)) 'Integer]
    [(Prim 'vector-ref (list vec (Int i)))
     (match (infer-limit-type env vec)
       [`(Vector ,ts ...)
        (if (and (<= 0 i) (< i (length ts)))
            (list-ref ts i)
            (error 'limit-functions "vector-ref index ~a out of bounds in type inference" i))]
       [other (error 'limit-functions "expected vector type, not ~a" other)])]
    [(Prim 'vector-set! (list _ _ _)) 'Void]
    [(Prim op _)
     (match op
       [(or '+ '- '*) 'Integer]
       [(or 'eq? '< '<= '> '>= 'not 'and 'or) 'Boolean]
       [else (error 'limit-functions "cannot infer primitive type for ~a" op)])]
    [else (error 'limit-functions "cannot infer type for expression ~a" e)]))

(define (limit-functions p)
  (match p
    [(ProgramDefs info ds)
     (define fun-type-env (build-limit-fun-type-env ds))

     (define (limit-def d)
       (match d
         [(Def f params rty dinfo body)
          (define n (length params))
          (if (<= n 6)
              d
                  ;; Pack params 6..n-1 into a tuple, passed as the 6th argument.
                  ;; This keeps total args <= 6 (the register-only calling convention).
                  ;; params = ([x1 : T1] ... [xn : Tn])
                  (let* ([first5 (take params 5)]
                    [rest   (drop params 5)]
                     [rest-types (map limit-param-type rest)]
                     [tup-type `(Vector ,@rest-types)]
                     [tup-var (gensym 'tup)]
                     [tup-param `[,tup-var : ,tup-type]]
                    [new-params (append first5 (list tup-param))]
                    ;; Replace each extra param xi with (vector-ref tup (i-5))
                     [body^ (for/foldr ([b body])
                                       ([rp rest] [k (in-naturals)])
                              (let ([xk (limit-param-name rp)]
                                    [vref (Prim 'vector-ref
                                                (list (Var tup-var) (Int k)))])
                                ;; bind xk to the vector-ref in a let
                                (Let xk vref b)))])
                (Def f new-params rty dinfo body^)))]))

     (define (limit-exp env e)
       (match e
         [(Apply fun args)
          (define fun^ (limit-exp env fun))
          (define args^ (map (lambda (a) (limit-exp env a)) args))
          (if (<= (length args^) 6)
              (Apply fun^ args^)
               ;; Pack args 6+ into a tuple, passed as the 6th argument.
                (let* ([first5 (take args^ 5)]
                       [rest   (drop args^ 5)])
                (define rest-types
                  (for/list ([a rest])
                    (infer-limit-type env a)))
                (define vec-type `(Vector ,@rest-types))
                 (Apply fun^ (append first5 (list (HasType (Prim 'vector rest) vec-type))))))]
         [(Let x rhs body)
          (define rhs^ (limit-exp env rhs))
          (define rhs-ty (infer-limit-type env rhs^))
          (Let x rhs^ (limit-exp (dict-set env x rhs-ty) body))]
         [(If c t f) (If (limit-exp env c) (limit-exp env t) (limit-exp env f))]
         [(Begin es body)
          (Begin (map (lambda (a) (limit-exp env a)) es)
                 (limit-exp env body))]
         [(WhileLoop c b) (WhileLoop (limit-exp env c) (limit-exp env b))]
         [(SetBang x rhs) (SetBang x (limit-exp env rhs))]
         [(HasType e t) (HasType (limit-exp env e) t)]
         [(Prim op args) (Prim op (map (lambda (a) (limit-exp env a)) args))]
         [_ e]))

     (define ds^
       (for/list ([d ds])
         (match (limit-def d)
           [(Def f params rty dinfo body)
            (define env-with-params
              (for/fold ([env fun-type-env])
                        ([p params])
                (dict-set env (limit-param-name p) (limit-param-type p))))
            (Def f params rty dinfo (limit-exp env-with-params body))])))
     (ProgramDefs info ds^)]))

;; -----------------------------------------------------------------------------
;; uniquify-fun : LFun -> LFun (with unique variable names)
;; Extends uniquify to handle ProgramDefs / Def / Apply / FunRef.
(define (uniquify-fun p)
  (match p
    [(ProgramDefs info ds)
     ;; Function names stay the same (they are globally scoped)
     ;; Build env with all function names mapping to themselves
     (define fun-names (for/list ([d ds]) (cons (Def-name d) (Def-name d))))
     (define (uniquify-def d)
       (match d
         [(Def f params rty dinfo body)
          ;; Create fresh names for parameters
          (define param-env
            (for/list ([p params])
              (match p
                [`[,x : ,t]
                 (define x^ (gensym x))
                 (cons x x^)]
                [else (error 'uniquify-fun "bad param ~a" p)])))
          (define new-params
            (for/list ([p params] [pe param-env])
              (match p
                [`[,x : ,t] `[,(cdr pe) : ,t]]
                [else p])))
          (define env (append param-env fun-names))
          (Def f new-params rty dinfo ((uniquify-fun-exp env) body))]))
     (ProgramDefs info (for/list ([d ds]) (uniquify-def d)))]
    [(ProgramDefsExp info ds body)
     ;; Convert to ProgramDefs first for simplicity
     (uniquify-fun (ProgramDefs info
                                (append ds (list (Def 'main '() 'Integer '() body)))))]
    [else (uniquify p)]))

;; extend uniquify-exp to handle Apply and FunRef
;; (already handles Prim and most things, Apply needs explicit handling)
;; We override by extending the uniquify-exp to also handle Apply
(define (uniquify-fun-exp env)
  (lambda (e)
    (match e
      [(Var x)
       (Var (dict-ref env x))]
      [(Int n) (Int n)]
      [(Bool b) (Bool b)]
      [(Void) (Void)]
      [(Let x rhs body)
       (define x^ (gensym x))
       (Let x^ ((uniquify-fun-exp env) rhs)
            ((uniquify-fun-exp (dict-set env x x^)) body))]
      [(If cnd thn els)
       (If ((uniquify-fun-exp env) cnd)
           ((uniquify-fun-exp env) thn)
           ((uniquify-fun-exp env) els))]
      [(SetBang x rhs)
       (SetBang (dict-ref env x) ((uniquify-fun-exp env) rhs))]
      [(WhileLoop cnd body)
       (WhileLoop ((uniquify-fun-exp env) cnd)
                  ((uniquify-fun-exp env) body))]
      [(Begin es body)
       (Begin (map (uniquify-fun-exp env) es)
              ((uniquify-fun-exp env) body))]
      [(HasType e^ t)
       (HasType ((uniquify-fun-exp env) e^) t)]
      [(GlobalValue name) (GlobalValue name)]
      [(Allocate n t) (Allocate n t)]
      [(Collect n) (Collect n)]
      [(Prim op es)
       (Prim op (for/list ([a es]) ((uniquify-fun-exp env) a)))]
      [(Apply fun args)
       (Apply ((uniquify-fun-exp env) fun)
              (for/list ([a args]) ((uniquify-fun-exp env) a)))]
      [(FunRef f n) (FunRef f n)])))

;; -----------------------------------------------------------------------------
;; uncover-get!-fun : LFun -> LFun
;; Extends uncover-get! to handle Def / ProgramDefs.
(define (uncover-get!-fun p)
  (match p
    [(ProgramDefs info ds)
     (define ds^
       (for/list ([d ds])
         (match d
           [(Def f params rty dinfo body)
            (define mutable-vars (collect-set! body))
            (Def f params rty dinfo ((uncover-get!-exp mutable-vars) body))])))
     (ProgramDefs info ds^)]))

;; -----------------------------------------------------------------------------
;; expose-allocation-fun : LFun -> LFun (lowered allocation)
;; Extends expose-allocation to handle ProgramDefs.
(define (expose-allocation-fun p)
  (match p
    [(ProgramDefs info ds)
     (define ds^
       (for/list ([d ds])
         (match d
           [(Def f params rty dinfo body)
            (Def f params rty dinfo (expose-alloc-exp body))])))
     (ProgramDefs info ds^)]))

;; -----------------------------------------------------------------------------
;; remove-complex-opera*-fun : LFun^mon -> LFun^mon
;; Extends remove-complex-opera* to handle ProgramDefs, Apply, and FunRef.
;;
;; FunRef is classified as COMPLEX (needs leaq to convert label -> address).
;; Apply is classified as COMPLEX (translates to a call sequence).
(define (remove-complex-opera*-fun p)
  (match p
    [(ProgramDefs info ds)
     (define ds^
       (for/list ([d ds])
         (match d
           [(Def f params rty dinfo body)
            (Def f params rty dinfo (rco-exp-fun body))])))
     (ProgramDefs info ds^)]))

(define (rco-exp-fun e)
  (match e
    [(Int n) (Int n)]
    [(Var x) (Var x)]
    [(Bool b) (Bool b)]
    [(Void) (Void)]
    [(Prim 'read '()) (Prim 'read '())]
    [(If cnd thn els)
     (If (rco-exp-fun cnd) (rco-exp-fun thn) (rco-exp-fun els))]
    [(GetBang x) (GetBang x)]
    [(SetBang x rhs) (SetBang x (rco-exp-fun rhs))]
    [(Begin es body) (Begin (map rco-exp-fun es) (rco-exp-fun body))]
    [(WhileLoop cnd body) (WhileLoop (rco-exp-fun cnd) (rco-exp-fun body))]
    [(HasType e^ t) (rco-exp-fun e^)]
    [(Collect n) (Collect n)]
    [(Allocate n t) (Allocate n t)]
    [(GlobalValue name) (GlobalValue name)]
    [(Prim op args) (rco-prim-fun op args)]
    [(Let x rhs body)
     (Let x (rco-exp-fun rhs) (rco-exp-fun body))]
    [(FunRef f n) (FunRef f n)]
    [(Apply fun args)
     ;; fun and all args must be atomic
     (define-values (fun^ fun-lets) (rco-atom-fun fun))
     (define-values (args^ args-lets)
       (for/fold ([atoms '()] [lets '()])
                 ([a args])
         (define-values (a^ ls) (rco-atom-fun a))
         (values (append atoms (list a^)) (append lets ls))))
     (foldr (lambda (b acc) (Let (car b) (cdr b) acc))
            (Apply fun^ args^)
            (append fun-lets args-lets))]))

(define (rco-prim-fun op args)
  (define-values (rev-lets atoms)
    (for/fold ([lets '()] [atoms '()])
              ([a args])
      (let-values ([(a^ lets^) (rco-atom-fun a)])
        (values (append lets lets^) (append atoms (list a^))))))

  (foldr
   (lambda (b acc) (Let (car b) (cdr b) acc))
   (Prim op atoms)
   rev-lets))

(define (rco-atom-fun e)
  (cond
    ;; FunRef is NOT atomic -- it needs a leaq, so treat as complex
    [(or (atomic? e)) (values e '())]
    [else
     (define tmp (gensym 'tmp))
     (values (Var tmp)
             (list (cons tmp (rco-exp-fun e))))]))

;; -----------------------------------------------------------------------------
;; explicate-control-fun : LFun^mon -> CFun
;; Extends explicate-control to handle per-function basic block generation.
(define (explicate-control-fun p)
  (match p
    [(ProgramDefs info ds)
     ;; Process each function def into a CFun Def
     (define new-defs
       (for/list ([d ds])
         (match d
           [(Def f params rty dinfo body)
            ;; Reset basic-blocks for each function
            (set! basic-blocks '())
            ;; Compile the body in tail position
            (define start-tail (explicate-tail-fun body))
            ;; The start block gets name "f_start"
            (define start-label (symbol-append f '_start))
            ;; Build all blocks: start + accumulated basic-blocks
            (define all-blocks
              (cons (cons start-label start-tail) basic-blocks))
            (Def f params rty dinfo all-blocks)])))
     (ProgramDefs info new-defs)]))

;; Tail position for functions: Apply becomes TailCall
(define (explicate-tail-fun e)
  (match e
    [(Apply fun args)
     ;; In tail position: emit a TailCall
     (TailCall (explicate-exp fun) (map explicate-exp args))]
    [(Let x rhs body)
     (explicate-assign-fun rhs x (explicate-tail-fun body))]
    [(If cnd thn els)
     (define thn-tail (explicate-tail-fun thn))
     (define els-tail (explicate-tail-fun els))
     (explicate-pred cnd thn-tail els-tail)]
    [(Begin es body)
     (foldr (lambda (sub acc) (explicate-effect-fun sub acc))
            (explicate-tail-fun body)
            es)]
    [(SetBang x rhs)
     (explicate-assign-fun rhs x (Return (Void)))]
    [(WhileLoop cnd body)
     (define loop-label (gensym 'loop))
     (define body-tail
       (explicate-effect-fun body (Goto loop-label)))
     (define loop-tail
       (explicate-pred cnd body-tail (Return (Void))))
     (set! basic-blocks (cons (cons loop-label loop-tail) basic-blocks))
     (Goto loop-label)]
    [_ (explicate-tail e)]))

;; Assignment position for functions: Apply becomes Call
(define (explicate-assign-fun rhs x k)
  (match rhs
    [(Apply fun args)
     ;; In assignment position: emit Call
     (Seq (Assign (Var x) (Call (explicate-exp fun) (map explicate-exp args))) k)]
    [(Let y rhs2 body)
     (explicate-assign-fun rhs2 y (explicate-assign-fun body x k))]
    [(If cnd thn els)
     (define k-block (create-block k))
     (define thn-tail (explicate-assign-fun thn x k-block))
     (define els-tail (explicate-assign-fun els x k-block))
     (explicate-pred cnd thn-tail els-tail)]
    [(Begin es body)
     (foldr (lambda (sub acc) (explicate-effect-fun sub acc))
            (explicate-assign-fun body x k)
            es)]
    [(SetBang y rhs2)
     (explicate-assign-fun rhs2 y
                           (Seq (Assign (Var x) (Void)) k))]
    [(WhileLoop cnd body)
     (define k-after (Seq (Assign (Var x) (Void)) k))
     (define loop-label (gensym 'loop))
     (define body-tail
       (explicate-effect-fun body (Goto loop-label)))
     (define loop-tail (explicate-pred cnd body-tail k-after))
     (set! basic-blocks (cons (cons loop-label loop-tail) basic-blocks))
     (Goto loop-label)]
    [_ (explicate-assign rhs x k)]))

;; Effect position for functions
(define (explicate-effect-fun e k)
  (match e
    [(Apply fun args)
     ;; Effectful call: emit Call, discard result
     (define tmp (gensym 'effect))
     (Seq (Assign (Var tmp) (Call (explicate-exp fun) (map explicate-exp args))) k)]
    [(Let x rhs body)
     (explicate-assign-fun rhs x (explicate-effect-fun body k))]
    [(SetBang x rhs)
     (explicate-assign-fun rhs x k)]
    [(Begin es body)
     (foldr (lambda (sub acc) (explicate-effect-fun sub acc))
            (explicate-effect-fun body k)
            es)]
    [(WhileLoop cnd body)
     (define loop-label (gensym 'loop))
     (define body-tail
       (explicate-effect-fun body (Goto loop-label)))
     (define loop-tail (explicate-pred cnd body-tail k))
     (set! basic-blocks (cons (cons loop-label loop-tail) basic-blocks))
     (Goto loop-label)]
    [(If cnd thn els)
     (define k-block (create-block k))
     (explicate-pred cnd
                     (explicate-effect-fun thn k-block)
                     (explicate-effect-fun els k-block))]
    [_ (explicate-effect e k)]))

;; extend explicate-exp for FunRef (already handled in catch-all, but explicit)
;; FunRef passes through as-is (it's an atom in C form)
;; Actually the explicate-exp catch-all uses (Prim op args) which won't match FunRef.
;; We need to handle FunRef explicitly:
(define (explicate-exp-fun e)
  (match e
    [(FunRef f n) (FunRef f n)]
    [_ (explicate-exp e)]))

;; Override explicate-exp to support FunRef
;; (We'll patch explicate-exp calls within explicate-tail-fun/assign-fun above
;;  by using explicate-exp-fun)

;; Re-define the tail/assign/effect helpers above using explicate-exp-fun
;; rather than explicate-exp where FunRef might appear:
;; [Already done above via pattern matching]

;; -----------------------------------------------------------------------------
;; select-instructions-fun : CFun -> x86Var,Def_callq*
;; Extends select-instructions to handle per-function code generation.

(define (select-instructions-fun p)
  (match p
    [(ProgramDefs info defs)
     ;; Build x86 instructions for a single Def
     (define (select-def d)
       (match d
         [(Def f params rty dinfo blocks)
          (define f-label (mangle-function-label f))
          ;; Generate instructions to move arg-regs into parameter variables
          ;; at the start of the function
          (define param-moves
            (for/list ([p params] [reg arg-passing-regs])
              (match p
                [`[,x : ,t]
                 (Instr 'movq (list (Reg reg) (Var x)))]
                [else (error 'select-instructions-fun "bad param" p)])))
          ;; Process each basic block
          (define new-blocks
            (for/list ([b blocks])
              (match b
                [(cons label tail)
                 ;; Inject param moves at the start block
                 (define start-label (symbol-append f-label '_start))
                 (define instrs (select-tail-fun tail f-label))
                 (define final-instrs
                   (if (equal? label (symbol-append f '_start))
                       (append param-moves instrs)
                       instrs))
                 (cons (if (equal? label (symbol-append f '_start))
                           start-label
                           label)
                       (Block '() final-instrs))])))
          ;; Build info with num-params for the interpreter and param vars for RA
          (define param-vars
            (for/list ([p params])
              (match p
                [`[,x : ,t] x]
                [else (error 'select-instructions-fun "bad param" p)])))
          (define new-info
            (dict-set* dinfo
                       'num-params (length params)
                       'param-vars param-vars))
          (Def f-label '() rty new-info new-blocks)]))
     ;; Convert to X86ProgramDefs
     (X86ProgramDefs info (for/list ([d defs]) (select-def d)))]))

;; select-tail-fun: compile CFun tails, with function name for label prefixing
(define (select-tail-fun t fname)
  (define conclusion-label (symbol-append fname '_conclusion))
  (match t
    [(Return exp)
     (append (select-assign (Reg 'rax) exp)
             (list (Jmp conclusion-label)))]
    [(Seq stmt tail)
     (append (select-stmt-fun stmt)
             (select-tail-fun tail fname))]
    [(Goto label)
     (list (Jmp label))]
    [(IfStmt (Prim op (list a1 a2)) (Goto thn-label) (Goto els-label))
     (define cc (match op ['eq? 'e] ['< 'l] ['<= 'le] ['> 'g] ['>= 'ge]))
     (list (Instr 'cmpq (list (select-atm a2) (select-atm a1)))
           (JmpIf cc thn-label)
           (Jmp els-label))]
    ;; TailCall in tail position
    [(TailCall fun args)
     (define n (length args))
     ;; Save callee in r11 (a non-allocatable scratch register), then
     ;; save arguments to temporaries and load argument registers.
     ;; This avoids post-RA register-cycle clobbering.
     (define arg-tmps (for/list ([_ args]) (gensym 'argtmp)))
     (define save-fun
       (list (Instr 'movq (list (select-atm-fun fun) (Reg 'r11)))))
     (define save-args
       (for/list ([a args] [t arg-tmps])
         (Instr 'movq (list (select-atm-fun a) (Var t)))))
     (define load-args
       (for/list ([t arg-tmps] [r arg-passing-regs])
         (Instr 'movq (list (Var t) (Reg r)))))
     (append save-fun
             save-args
             load-args
             (list (Instr 'movq (list (Reg 'r11) (Reg 'rax))))
            (list (TailJmp (Reg 'rax) n)))]
    [else (error 'select-tail-fun "unhandled" t)]))

;; select-stmt-fun: compile statements in function context
(define (select-stmt-fun s)
  (match s
    [(Assign (Var v) (Call fun args))
     ;; Regular (non-tail) function call
     (define n (length args))
     ;; Save callee in r11, then save args to temporaries first to avoid
     ;; post-RA argument-register clobbering.
     (define arg-tmps (for/list ([_ args]) (gensym 'argtmp)))
     (define save-fun
       (list (Instr 'movq (list (select-atm-fun fun) (Reg 'r11)))))
     (define save-args
       (for/list ([a args] [t arg-tmps])
         (Instr 'movq (list (select-atm-fun a) (Var t)))))
     (define load-args
       (for/list ([t arg-tmps] [r arg-passing-regs])
         (Instr 'movq (list (Var t) (Reg r)))))
     (append save-fun
             save-args
             load-args
             (list (Instr 'movq (list (Reg 'r11) (Reg 'rax))))
             (list (IndirectCallq (Reg 'rax) n)
                   (Instr 'movq (list (Reg 'rax) (Var v)))))]
    [(Assign (Var v) (FunRef f n))
     ;; leaq f(%rip), dst
      (list (Instr 'leaq (list (Global (mangle-function-label f)) (Var v))))]
    [else (select-stmt s)]))

;; select-atm-fun: select atoms, handling FunRef as Global
(define (select-atm-fun a)
  (match a
    [(FunRef f n) (Global (mangle-function-label f))]
    [_ (select-atm a)]))

;; -----------------------------------------------------------------------------
;; uncover-live-fun : x86Var,Def -> x86Var,Def (annotated with live sets)
;; Extends uncover-live to work per-function.
(define (uncover-live-fun p)
  (match p
    [(X86ProgramDefs info defs)
     (define new-defs
       (for/list ([d defs])
         (match d
           [(Def f params rty dinfo blocks)
            ;; Run liveness per-function
            (define live-result (uncover-live (X86Program dinfo blocks)))
            (match live-result
              [(X86Program new-info new-blocks)
               (Def f params rty new-info new-blocks)])])))
     (X86ProgramDefs info new-defs)]))

;; Extend read-set and write-set to handle IndirectCallq, TailJmp, leaq
;; These are used by the existing uncover-live pass.
;; We need to patch read-set and write-set to handle these new instructions.
;; (The existing ones only handle Callq, not IndirectCallq/TailJmp/leaq)

;; We'll monkey-patch by redefining read-set and write-set below to extend them.
;; But since they're already defined, we use a wrapper approach:

;; Override read-set for Chapter 7 instructions:
(define (read-set-fun i)
  (match i
    ;; leaq src, dst: reads nothing (src is a label/global)
    [(Instr 'leaq (list s d)) (set)]
    ;; IndirectCallq target arity: reads target and arity argument regs
    [(IndirectCallq target arity)
     (set-union (locations-arg target)
                (list->set (take arg-passing-regs arity)))]
    ;; TailJmp target arity: reads target and arity argument regs
    [(TailJmp target arity)
     (set-union (locations-arg target)
                (list->set (take arg-passing-regs arity)))]
    [_ (read-set i)]))

;; Override write-set for Chapter 7 instructions:
(define (write-set-fun i)
  (match i
    ;; leaq src, dst: writes dst
    [(Instr 'leaq (list s d)) (locations-arg d)]
    ;; IndirectCallq: writes all caller-saved regs (same as Callq)
    [(IndirectCallq target arity) caller-saved-regs]
    ;; TailJmp: writes nothing relevant (pops frame and jumps)
    [(TailJmp target arity) (set)]
    [_ (write-set i)]))

;; -----------------------------------------------------------------------------
;; build-interference-fun : x86Var,Def -> x86Var,Def (with interference graph)
;; Extends build-interference to work per-function.
(define (build-interference-fun p)
  (match p
    [(X86ProgramDefs info defs)
     (define new-defs
       (for/list ([d defs])
         (match d
           [(Def f params rty dinfo blocks)
            ;; Run build-interference per-function
            (define result (build-interference-fun-single dinfo blocks))
            (match result
              [(X86Program new-info new-blocks)
               (Def f params rty new-info new-blocks)])])))
     (X86ProgramDefs info new-defs)]))

;; build-interference for a single function's blocks (using fun-aware read/write sets)
(define (build-interference-fun-single info blocks)
  (define G (undirected-graph '()))
  (define var-types (dict-ref info 'locals-types '()))
  (define param-vars (dict-ref info 'param-vars '()))

  ;; Prevent parameter variables from being assigned to argument registers.
  ;; This avoids clobbering during the sequential param-move prologue.
  (for ([p param-vars])
    (add-vertex! G p)
    (for ([r arg-passing-regs])
      (add-edge! G p r)))

  (for ([b blocks])
    (match b
      [(cons label (Block b-info instrs))
       (define live-after-sets (dict-ref b-info 'live-after '()))
       (for ([i instrs] [live-after live-after-sets])
         (match i
           [(Instr 'movq (list s d))
            (define s-sym (get-canonical s))
            (define d-sym (get-canonical d))
            (for ([v live-after])
              (unless (or (equal? v d-sym) (equal? v s-sym))
                (add-edge! G d-sym v)))]
           [(Instr 'movzbq (list s d))
            (define s-sym 'rax)
            (define d-sym (get-canonical d))
            (for ([v live-after])
              (unless (or (equal? v d-sym) (equal? v s-sym))
                (add-edge! G d-sym v)))]
           [(Instr 'leaq (list s d))
            ;; leaq: d gets a new value, no move biasing
            (define d-sym (get-canonical d))
            (for ([v live-after])
              (unless (equal? v d-sym)
                (add-edge! G d-sym v)))]
           [(or (IndirectCallq _ arity) (Callq _ arity))
            ;; Live vars interfere with caller-saved regs
            (for ([v live-after])
              (for ([r caller-saved-regs])
                (add-edge! G r v)))
            ;; Vector-typed vars live across ANY call -> also interfere with callee-saved
            (for ([v live-after])
              (when (and (symbol? v)
                         (vector-type? (dict-ref var-types v #f)))
                (for ([r callee-saved-regs])
                  (add-edge! G r v))))]
           [(TailJmp _ arity)
            ;; TailJmp: treat like IndirectCallq for interference purposes
            (for ([v live-after])
              (for ([r caller-saved-regs])
                (add-edge! G r v)))]
           [else
            (for ([d (write-set-fun i)])
              (for ([v live-after])
                (unless (equal? v d)
                  (add-edge! G d v))))]))]))
  (X86Program (dict-set info 'conflicts G) blocks))

;; -----------------------------------------------------------------------------
;; allocate-registers-fun : x86Var,Def -> x86Def
;; Extends allocate-registers to work per-function.
(define (allocate-registers-fun p)
  (match p
    [(X86ProgramDefs info defs)
     (define new-defs
       (for/list ([d defs])
         (match d
           [(Def f params rty dinfo blocks)
            ;; Run register allocation per-function
            (define result (allocate-registers (X86Program dinfo blocks)))
            (match result
              [(X86Program new-info new-blocks)
               (Def f params rty new-info new-blocks)])])))
     (X86ProgramDefs info new-defs)]))

;; -----------------------------------------------------------------------------
;; patch-instructions-fun : x86Def -> x86Def (patched)
;; Extends patch-instructions to handle leaq and TailJmp constraints.
(define (patch-instructions-fun p)
  (match p
    [(X86ProgramDefs info defs)
     (define new-defs
       (for/list ([d defs])
         (match d
           [(Def f params rty dinfo blocks)
            (define new-blocks
              (for/list ([b blocks])
                (match b
                  [(cons label (Block b-info instrs))
                   (cons label (Block b-info (append-map patch-instr-fun instrs)))])))
            (Def f params rty dinfo new-blocks)])))
     (X86ProgramDefs info new-defs)]))

;; patch-instr-fun: extends patch-instr with Chapter 7 cases
(define (patch-instr-fun i)
  (match i
    ;; leaq: destination must be a register (not memory)
    [(Instr 'leaq (list src (Deref r o)))
     (list (Instr 'leaq (list src (Reg 'rax)))
           (Instr 'movq (list (Reg 'rax) (Deref r o))))]
    ;; TailJmp: argument must be rax
    ;; If it's already rax, pass through
    [(TailJmp (Reg 'rax) n) (list i)]
    ;; Otherwise, move to rax first
    [(TailJmp arg n)
     (list (Instr 'movq (list arg (Reg 'rax)))
           (TailJmp (Reg 'rax) n))]
    ;; Delegate to the existing patch-instr
    [_ (patch-instr i)]))

;; -----------------------------------------------------------------------------
;; uncover-live-fun-v2: version of uncover-live that uses our fun-aware read/write sets
;; We need to hook the per-function liveness to use read-set-fun / write-set-fun.
;; The existing uncover-live calls read-set/write-set directly, so we override
;; via a wrapper that patches after the block annotation.

;; Actually, let's reimplement uncover-live-fun to use our extended read/write sets:
(define (uncover-live-fun-v2 p)
  (match p
    [(X86ProgramDefs info defs)
     (define new-defs
       (for/list ([d defs])
         (match d
           [(Def f params rty dinfo blocks)
            (define result (uncover-live-single-fun dinfo blocks))
            (match result
              [(X86Program new-info new-blocks)
               (Def f params rty new-info new-blocks)])])))
     (X86ProgramDefs info new-defs)]))

;; uncover-live for a single function using fun-aware read/write sets
(define (uncover-live-single-fun info blocks)
  ;; Step 1: Build directed CFG
  (define cfg (multigraph (make-hash)))
  (for ([b blocks])
    (add-vertex! cfg (car b)))
  ;; Add conclusion as a virtual sink
  (define f-name (let ([pair (assoc 'name info)])
                    (if pair (cdr pair) 'unknown)))
  (define all-labels (map car blocks))
  ;; Find the function name from block labels (start label = fname_start)
  (define conclusion-label
    (let* ([start-labels (filter (lambda (l) (string-suffix? (symbol->string l) "_start")) all-labels)]
           [fname (if (null? start-labels)
                      'main
                      (let ([sl (symbol->string (car start-labels))])
                        (string->symbol
                         (substring sl 0 (- (string-length sl) (string-length "_start"))))))])
      (symbol-append fname '_conclusion)))
  (add-vertex! cfg conclusion-label)
  (for ([b blocks])
    (match b
      [(cons label (Block _ instrs))
       (for ([instr instrs])
         (match instr
           [(Jmp target)     (add-directed-edge! cfg label target)]
           [(JmpIf _ target) (add-directed-edge! cfg label target)]
           [_ (void)]))]))

  ;; Table for fast block lookup
  (define blocks-table
    (make-hash (for/list ([b blocks]) (cons (car b) (cdr b)))))

  ;; Transfer function using fun-aware read/write sets
  (define (transfer node live-after)
    (cond
      [(equal? node conclusion-label)
       (set 'rax 'rsp)]
      [else
       (match (hash-ref blocks-table node #f)
         [#f (set)]
         [(Block _ instrs)
          (for/fold ([live live-after])
                    ([instr (reverse instrs)])
            (set-union (set-subtract live (write-set-fun instr))
                       (read-set-fun instr)))])]))

  ;; Run dataflow
  (define mapping (analyze-dataflow cfg transfer (set) set-union))

  ;; Annotate blocks
  (define new-blocks
    (for/list ([b blocks])
      (match b
        [(cons label (Block b-info instrs))
         (define-values (live-afters _lb)
           (compute-live-instrs-fun instrs mapping))
         (cons label (Block (dict-set b-info 'live-after live-afters) instrs))])))

  (X86Program info new-blocks))

;; compute-live-instrs-fun: like compute-live-instrs but uses read/write-set-fun
(define (compute-live-instrs-fun instrs label->live)
  (define-values (live-afters _live-before)
    (for/fold ([live-afters '()]
               [live-after  (set)])
              ([instr (reverse instrs)])
      (match instr
        [(Jmp lbl)
         (define new-live (hash-ref label->live lbl (set)))
         (values (cons new-live live-afters) new-live)]
        [(JmpIf cc lbl)
         (define new-live (set-union live-after (hash-ref label->live lbl (set))))
         (values (cons new-live live-afters) new-live)]
        [_
         (define rd (read-set-fun instr))
         (define wr (write-set-fun instr))
         (define live-before (set-union (set-subtract live-after wr) rd))
         (values (cons live-after live-afters) live-before)])))
  (values live-afters _live-before))

;; -----------------------------------------------------------------------------
;; prelude-and-conclusion-fun : x86Def -> x86callq*
;; Generates prelude and conclusion for each function definition.
(define (prelude-and-conclusion-fun p)
  (match p
    [(X86ProgramDefs global-info defs)
     ;; For each def, build prelude/start/conclusion blocks, then flatten.
     (define all-blocks
       (append-map
        (lambda (d)
          (match d
            [(Def f params rty dinfo blocks)
             (define stack-size (dict-ref dinfo 'stack-size 0))
             (define used-callee (dict-ref dinfo 'used_callee (set)))
             (define num-root-spills (dict-ref dinfo 'num-root-spills 0))

             (define used-callee-list (sort (set->list used-callee) symbol<?))
             (define num-callee (length used-callee-list))
             (define S (quotient stack-size 8))
             (define C num-callee)
             (define total-bytes (+ (* 8 S) (* 8 C)))
             (define aligned-size
               (if (zero? (modulo total-bytes 16))
                   total-bytes
                   (+ total-bytes (- 16 (modulo total-bytes 16)))))
             (define rsp-adjustment (- aligned-size (* 8 C)))

             (define start-label (symbol-append f '_start))
             (define conclusion-label (symbol-append f '_conclusion))
             (define is-main? (equal? f 'main))

             (define prelude
               (append
                (list (Instr 'pushq (list (Reg 'rbp)))
                      (Instr 'movq (list (Reg 'rsp) (Reg 'rbp))))
                (for/list ([reg used-callee-list])
                  (Instr 'pushq (list (Reg reg))))
                (if (> rsp-adjustment 0)
                    (list (Instr 'subq (list (Imm rsp-adjustment) (Reg 'rsp))))
                    '())
                (if is-main?
                    (list (Instr 'movq (list (Imm 65536) (Reg 'rdi)))
                          (Instr 'movq (list (Imm 65536) (Reg 'rsi)))
                          (Callq 'initialize 2)
                          (Instr 'movq (list (Global 'rootstack_begin) (Reg 'r15))))
                    '())
                (for/list ([i (in-range num-root-spills)])
                  (Instr 'movq (list (Imm 0) (Deref 'r15 (* 8 i)))))
                (if (> num-root-spills 0)
                    (list (Instr 'addq (list (Imm (* 8 num-root-spills)) (Reg 'r15))))
                    '())
                (list (Jmp start-label))))

             (define conclusion
               (append
                (if (> num-root-spills 0)
                    (list (Instr 'subq (list (Imm (* 8 num-root-spills)) (Reg 'r15))))
                    '())
                (if (> rsp-adjustment 0)
                    (list (Instr 'addq (list (Imm rsp-adjustment) (Reg 'rsp))))
                    '())
                (for/list ([reg (reverse used-callee-list)])
                  (Instr 'popq (list (Reg reg))))
                (list (Instr 'popq (list (Reg 'rbp)))
                      (Retq))))

             (define expanded-blocks
               (for/list ([b blocks])
                 (match b
                   [(cons label (Block b-info instrs))
                    (define expanded-instrs
                      (append-map
                       (lambda (instr)
                         (match instr
                           [(TailJmp (Reg 'rax) n)
                            (append
                             (if (> num-root-spills 0)
                                 (list (Instr 'subq (list (Imm (* 8 num-root-spills)) (Reg 'r15))))
                                 '())
                             (if (> rsp-adjustment 0)
                                 (list (Instr 'addq (list (Imm rsp-adjustment) (Reg 'rsp))))
                                 '())
                             (for/list ([reg (reverse used-callee-list)])
                               (Instr 'popq (list (Reg reg))))
                             (list (Instr 'popq (list (Reg 'rbp)))
                                   (IndirectJmp (Reg 'rax))))]
                           [_ (list instr)]))
                       instrs))
                    (cons label (Block b-info expanded-instrs))])))

             (append
              (list (cons f (Block '() prelude)))
              expanded-blocks
              (list (cons conclusion-label (Block '() conclusion))))]))
        defs))
     (X86Program global-info all-blocks)]))

(define compiler-passes
  `(("shrink"               ,shrink-fun           ,interp-Lfun      ,type-check-Lfun)
    ("uniquify"             ,uniquify-fun         ,interp-Lfun      ,type-check-Lfun)
    ("reveal-functions"     ,reveal-functions     ,interp-Lfun-prime ,type-check-Lfun)
    ("limit-functions"      ,limit-functions      ,interp-Lfun-prime ,type-check-Lfun-has-type)
    ("expose-allocation"    ,expose-allocation-fun ,interp-Lfun-prime ,type-check-Lfun-has-type)
    ("uncover-get!"         ,uncover-get!-fun     ,interp-Lfun-prime ,type-check-Lfun)
    ("remove complex opera*" ,remove-complex-opera*-fun ,interp-Lfun-prime ,type-check-Lfun)
    ("explicate control"    ,explicate-control-fun ,interp-Cfun)
    ("instruction selection" ,select-instructions-fun ,interp-pseudo-x86-3)
    ("liveness analysis"    ,uncover-live-fun-v2  ,interp-pseudo-x86-3)
    ("build interference"   ,build-interference-fun ,interp-pseudo-x86-3)
    ("allocate registers"   ,allocate-registers-fun ,interp-pseudo-x86-3)
    ("patch instructions"   ,patch-instructions-fun ,interp-pseudo-x86-3)
    ("prelude-and-conclusion" ,prelude-and-conclusion-fun #f)
  ))
