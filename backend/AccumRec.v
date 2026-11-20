(** Accumulator recursion elimination for x86-64 RTL.

    The function body must be a pure integer fragment with an empty local
    stack. A direct recursive call followed by additions becomes a loop:
    save the pending addends in a fresh accumulator, assign the recursive
    arguments in parallel, then branch to the old entry point. Single-argument
    and single-addend calls are instances of the same transformation.

    Return-copy normalization and jump threading are local preparation and
    cleanup phases. Only [transf_program] is exposed as a compiler pass.
    Correctness, including separate compilation, is in AccumRecproof.v. *)

Require Import Coqlib Maps Errors AST Integers Registers Op RTL RTLtyping Parmov.

(** * Integer fragment and structural utilities *)

Definition int_add_operation : operation := Olea (Aindexed2 0).

(** A small, total, integer-only fragment.  No stack addresses, symbols,
    memory reads, divisions, floating arithmetic or builtins are accepted. *)
Definition supported_int_operation (op: operation) (args: list reg) : bool :=
  match op, args with
  | Omove, _ :: nil
  | Ointconst _, nil
  | Olea (Aindexed _), _ :: nil
  | Olea (Aindexed2 _), _ :: _ :: nil
  | Osub, _ :: _ :: nil
  | Omul, _ :: _ :: nil => true
  | _, _ => false
  end.

Definition supported_int_condition (cond: condition) (args: list reg) : bool :=
  match cond, args with
  | Ccomp _, _ :: _ :: nil
  | Ccompu _, _ :: _ :: nil
  | Ccompimm _ _, _ :: nil
  | Ccompuimm _ _, _ :: nil => true
  | _, _ => false
  end.

Definition unary_int_signature : signature :=
  mksignature (Xint :: nil) Xint cc_default.

Definition body_pc (pc: node) : node := xO pc.
Definition init_pc : node := 1%positive.
Definition exit_pc : node := 3%positive.
Definition accumulator (f: function) : reg := Pos.succ (max_reg_function f).

Definition relocate (i: instruction) : instruction :=
  match i with
  | Inop s => Inop (body_pc s)
  | Iop op args dst s => Iop op args dst (body_pc s)
  | Iload chunk addr args dst s => Iload chunk addr args dst (body_pc s)
  | Istore chunk addr args src s => Istore chunk addr args src (body_pc s)
  | Icall sg ros args res s => Icall sg ros args res (body_pc s)
  | Itailcall sg ros args => Itailcall sg ros args
  | Ibuiltin ef args res s => Ibuiltin ef args res (body_pc s)
  | Icond cond args yes no => Icond cond args (body_pc yes) (body_pc no)
  | Ijumptable arg tbl => Ijumptable arg (List.map body_pc tbl)
  | Ireturn r => Ireturn r
  end.

(** Structural equality is used only to check that the guessed self symbol
    really denotes this function in the source compilation unit. *)
Definition instruction_eq: forall x y: instruction, {x = y} + {x <> y}.
Proof.
  generalize peq signature_eq eq_operation eq_addressing eq_condition chunk_eq
    external_function_eq (eq_builtin_arg peq) (eq_builtin_res peq).
  intros. decide equality; decide equality.
Defined.

Definition code_eq: forall x y: code, {x = y} + {x <> y}.
Proof.
  intros x y.
  destruct (PTree.beq (fun i j => if instruction_eq i j then true else false) x y) eqn:EQ.
  - left. apply PTree.extensionality. intro pc.
    rewrite PTree.beq_correct in EQ. specialize (EQ pc).
    destruct x!pc, y!pc; try contradiction; auto.
    destruct (instruction_eq i i0); congruence.
  - right. intro SAME. subst y.
    assert (PTree.beq (fun i j => if instruction_eq i j then true else false) x x = true).
    { apply PTree.beq_correct. intro pc. destruct x!pc; auto.
      destruct (instruction_eq i i); congruence. }
    congruence.
Defined.

Definition function_eq: forall x y: function, {x = y} + {x <> y}.
Proof.
  generalize signature_eq peq zeq code_eq.
  intros. decide equality; decide equality.
Defined.

Definition guess_self (f: function) : option ident :=
  List.fold_right (fun entry result =>
    match snd entry with
    | Icall _ (inr id) _ _ _ => Some id
    | _ => result
    end) None (PTree.elements f.(fn_code)).


(** * Return-copy normalization *)

Module Return.
(** Collapse bounded, pure move/nop/return continuations.  This exposes
    additions followed by administrative instructions to AccumRec. *)

Fixpoint return_value (fuel: nat) (f: function) (pc: node) : option reg :=
  match fuel with
  | O => None
  | S fuel' =>
      match (fn_code f)!pc with
      | Some (Ireturn (Some r)) => Some r
      | Some (Inop next) => return_value fuel' f next
      | Some (Iop Omove (src :: nil) dst next) =>
          match return_value fuel' f next with
          | Some r => Some (if peq r dst then src else r)
          | None => None
          end
      | _ => None
      end
  end.

Definition lookahead := 32%nat.
Definition transf_instruction (f: function) (pc: node) (i: instruction) :=
  match return_value lookahead f pc with
  | Some r => Ireturn (Some r)
  | None => i
  end.

Definition transf_function (f: function) := RTL.transf_function (transf_instruction f) f.
Definition transf_fundef := AST.transf_fundef transf_function.
Definition transf_program (p: program) := transform_program transf_fundef p.
End Return.

(** * Jump threading *)

Module Thread.
(** Bounded jump threading for generated loops and ordinary RTL code.
    Skip empty jumps, and repeated identical tests whose outcome is known
    from the incoming conditional edge. No instructions with effects cross. *)
Definition known_test := option (condition * list reg * bool).

Fixpoint shortcut (fuel: nat) (f: function) (known: known_test) (pc: node) : node :=
  match fuel with
  | O => pc
  | S fuel' =>
    match (fn_code f)!pc with
    | Some (Inop next) => shortcut fuel' f known next
    | Some (Icond cond args yes no) =>
      match known with
      | Some (old, oldargs, outcome) =>
        if eq_condition cond old then
        if list_eq_dec peq args oldargs then
          shortcut fuel' f known (if outcome then yes else no)
        else pc else pc
      | None => pc
      end
    | _ => pc
    end
  end.

Definition lookahead := 16%nat.
Definition transf_instr (f: function) (i: instruction) : instruction :=
  let skip := shortcut lookahead f None in
  match i with
  | Inop next => Inop (skip next)
  | Iop op args dst next => Iop op args dst (skip next)
  | Iload chunk addr args dst next => Iload chunk addr args dst (skip next)
  | Istore chunk addr args src next => Istore chunk addr args src (skip next)
  | Icall sg ros args dst next => Icall sg ros args dst (skip next)
  | Ibuiltin ef args dst next => Ibuiltin ef args dst (skip next)
  | Icond cond args yes no =>
    Icond cond args (shortcut lookahead f (Some (cond,args,true)) yes)
      (shortcut lookahead f (Some (cond,args,false)) no)
  | Ijumptable r targets => Ijumptable r (map skip targets)
  | _ => i
  end.

Definition transf_function (f: function) : function :=
  mkfunction (fn_sig f) (fn_params f) (fn_stacksize f)
    (PTree.map (fun _ i => transf_instr f i) (fn_code f))
    (shortcut lookahead f None (fn_entrypoint f)).

Definition transf_fundef := AST.transf_fundef transf_function.
Definition transf_program (p: program) := transform_program transf_fundef p.
End Thread.

(** * Recognition of additive continuations *)

(** Expand a return expression backwards through additions. Substitution
    accounts for destination/source aliases: the inputs are read before the
    destination is written. The recursive result must occur exactly once. *)
Definition substitute (dst: reg) (replacement terms: list reg) : list reg :=
  flat_map (fun r => if peq r dst then replacement else r :: nil) terms.
Fixpoint additive_terms (fuel: nat) (f: function) (pc: node) : option (list reg) :=
  match fuel with
  | O => None
  | S fuel' =>
    match (fn_code f)!pc with
    | Some (Ireturn (Some r)) => Some (r :: nil)
    | Some (Iop op (a :: b :: nil) dst next) =>
      if eq_operation op int_add_operation then
        match additive_terms fuel' f next with
        | Some terms =>
          let expanded := substitute dst (a :: b :: nil) terms in
          if Nat.leb (length expanded) 9 then Some expanded else None
        | None => None
        end
      else None
    | _ => None
    end
  end.

Definition suffix_fuel := 9%nat.
Fixpoint remove_once (r: reg) (terms: list reg) : option (list reg) :=
  match terms with
  | nil => None
  | x :: xs =>
    if peq x r then
      if existsb (fun y => if peq y r then true else false) xs then None else Some xs
    else match remove_once r xs with Some rest => Some (x :: rest) | None => None end
  end.

Record site := mksite {
  call_args: list reg;
  call_result: reg;
  call_next: node;
  saved_terms: list reg
}.

Definition raw_site (self: ident) (f: function) (pc: node) : option site :=
  match (fn_code f)!pc with
  | Some (Icall sg (inr callee) args res next) =>
    if ident_eq self callee then
    if signature_eq sg (fn_sig f) then
    if Nat.eqb (length args) (length (fn_params f)) then
      match additive_terms suffix_fuel f next with
      | Some terms =>
        match remove_once res terms with
        | Some (a :: rest) =>
          if Nat.leb (length (a :: rest)) 8 then Some (mksite args res next (a :: rest)) else None
        | _ => None
        end
      | None => None
      end
    else None else None else None
  | _ => None
  end.

(** * Whole-function eligibility *)

Definition int_signature (params: list reg) :=
  mksignature (map (fun _ => Xint) params) Xint cc_default.
Definition supported (self: ident) (f: function) (i: instruction) : bool :=
  match i with
  | Inop _ => true
  | Iop op args _ _ => supported_int_operation op args
  | Icond cond args _ _ => supported_int_condition cond args
  | Icall sg (inr callee) args _ _ =>
    if ident_eq callee self then
    if signature_eq sg (fn_sig f) then Nat.eqb (length args) (length (fn_params f)) else false else false
  | Ireturn (Some _) => true
  | _ => false
  end.

(** * Control-flow construction and parallel parameter assignments *)

(** Each source node owns 32 odd auxiliary nodes. They are disjoint from
    the even body nodes, initialization node 1 and return node 3. The fresh
    accumulator and parallel-move temporary are above all original registers. *)
Definition aux_pc (pc: node) (index: nat) : node :=
  Pos.of_nat (64 * Pos.to_nat pc + 2 * index + 1).

Definition temporary (f: function) (index: nat) : reg :=
  Pos.of_nat (Pos.to_nat (max_reg_function f) + 2 + index).

Definition linear_op := (operation * list reg * reg)%type.
(** A singleton parallel assignment is one move. The general case uses the
    verified parallel-move scheduler, including cycles and repeated sources. *)
Definition parameter_moves (f: function) (args: list reg) :=
  match args, fn_params f with
  | a :: nil, p :: nil => (a, p) :: nil
  | _, _ => Parmov.parmove2 reg peq (fun _ => temporary f 0) args (fn_params f)
  end.

(** Save addends BEFORE assigning parameters: an addend may be an old
    parameter value. Parallel moves then implement the recursive arguments. *)
Definition site_operations (f: function) (c: site) : list linear_op :=
  map (fun r => (int_add_operation, accumulator f :: r :: nil, accumulator f)) (saved_terms c)
  ++ map (fun pair => (Omove, fst pair :: nil, snd pair)) (parameter_moves f (call_args c)).

Definition find_site (self: ident) (f: function) (pc: node) : option site :=
  match raw_site self f pc with
  | Some c => if Nat.leb (length (site_operations f c)) 32 then Some c else None
  | None => None
  end.

Definition node_exists (f: function) (pc: node) : bool :=
  match (fn_code f)!pc with Some _ => true | None => false end.

Definition eligible (self: ident) (f: function) : bool :=
  if Archi.ptr64 then
  if signature_eq (fn_sig f) (int_signature (fn_params f)) then
  if zeq (fn_stacksize f) 0 then
  if list_norepet_dec peq (fn_params f) then
    Nat.leb 1 (length (fn_params f)) && Nat.leb (length (fn_params f)) 8 &&
    node_exists f (fn_entrypoint f) &&
    forallb (fun x => supported self f (snd x) &&
      forallb (node_exists f) (successors_instr (snd x))) (PTree.elements (fn_code f)) &&
    existsb (fun x => match find_site self f (fst x) with Some _ => true | None => false end)
      (PTree.elements (fn_code f))
  else false else false else false else false.

Definition operation_at (op: linear_op) (next: node) : instruction :=
  match op with (oper, args, dst) => Iop oper args dst next end.

Fixpoint install_tail (pc: node) (index: nat) (ops: list linear_op) (finish: node) (code: RTL.code) : RTL.code :=
  match ops with
  | nil => code
  | op :: rest =>
    PTree.set (aux_pc pc index)
      (operation_at op (match rest with nil => finish | _ => aux_pc pc (S index) end))
      (install_tail pc (S index) rest finish code)
  end.

Definition rewrite_instruction (self: ident) (f: function) (pc: node) (i: instruction) : instruction :=
  match find_site self f pc with
  | Some c =>
    match site_operations f c with
    | op :: rest =>
        operation_at op
          (match rest with nil => body_pc (fn_entrypoint f) | _ => aux_pc pc 0 end)
    | nil => relocate i
    end
  | None =>
    match i with
    | Ireturn (Some r) => Iop int_add_operation (accumulator f :: r :: nil) (accumulator f) 3%positive
    | _ => relocate i
    end
  end.

Definition insert_instruction (self: ident) (f: function) (code: RTL.code) (pc: node) (i: instruction) : RTL.code :=
  let code' := match find_site self f pc with
    | Some c => match site_operations f c with
                | _ :: rest => install_tail pc 0 rest (body_pc (fn_entrypoint f)) code
                | nil => code end
    | None => code end in
  PTree.set (body_pc pc) (rewrite_instruction self f pc i) code'.
Definition rewrite_code (self: ident) (f: function) : code :=
  PTree.set 1%positive (Iop (Ointconst Int.zero) nil (accumulator f) (body_pc (fn_entrypoint f)))
    (PTree.set 3%positive (Ireturn (Some (accumulator f)))
      (PTree.fold (insert_instruction self f) (fn_code f) (PTree.empty instruction))).

Definition transf_function (self: ident) (f: function) : function :=
  if eligible self f then
    mkfunction (fn_sig f) (fn_params f) (fn_stacksize f) (rewrite_code self f) 1%positive
  else f.
(** * Checked compilation-unit transformation *)

(** A syntactic direct call is not enough to establish self recursion.
    The compilation unit must associate its symbol with this exact function. *)
Definition contextual_function (cu: program) (f: function) : function :=
  match guess_self f with
  | Some id =>
      match (prog_defmap cu)!id with
      | Some (Gfun (Internal f')) =>
          if function_eq f f' then transf_function id f else f
      | _ => f
      end
  | None => f
  end.

Definition checked_function (cu: program) (f: function) : res function :=
  match type_function f with
  | OK _ => OK (contextual_function cu f)
  | Error msg => Error msg
  end.

Definition transf_program_rec (p: program) : res program :=
  transform_partial_program (AST.transf_partial_fundef (checked_function p)) p.

(** * Program transformation

    Normalize return continuations before recognizing recursion. Thread the
    resulting loop edges after rewriting. The compiler sees one RTL pass. *)
Definition transf_program (p: program) : res program :=
  match transf_program_rec (Return.transf_program p) with
  | OK tp => OK (Thread.transf_program tp)
  | Error msg => Error msg
  end.
