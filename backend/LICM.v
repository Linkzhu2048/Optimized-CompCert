(* *********************************************************************)
(*                                                                     *)
(*              The Compcert verified compiler                         *)
(*                                                                     *)
(* *********************************************************************)

(** Guarded LICM by eliminating repeated invariant evaluations. When the
    candidate is not at the loop entrance, preparation copies the first
    traversal without reordering operations. Later iterations reuse the
    computed result. Bounded repetition supports dependent expressions. *)

Require Import Coqlib Maps AST Op Registers RTL LoopRotate.

Record candidate := Candidate {
  location: node; invariant_op: operation; operands: list reg; result: reg
}.

Definition independent (p: candidate) (dst: reg) : bool :=
  if peq dst p.(result) then false else
  if In_dec peq dst p.(operands) then false else true.

Definition self_move (i: instruction) : bool :=
  match i with
  | Iop Omove (src :: nil) dst _ => if peq src dst then true else false
  | _ => false
  end.

Definition safe (p: candidate) (i: instruction) : bool :=
  if self_move i then true else match i with
  | Iop _ _ dst _ | Iload _ _ _ dst _ => independent p dst
  | Inop _ | Istore _ _ _ _ _ | Icond _ _ _ _ | Ijumptable _ _ => true
  | _ => false
  end.

(** A coarse priority, not a target latency estimate. Prefer costly
    arithmetic; consider cheap pure computations only in small regions. *)
Definition operation_cost (op: operation) : nat :=
  match op with
  | Omul | Omulimm _ | Omulhs | Omulhu | Odiv | Odivu | Omod | Omodu
  | Omull | Omullimm _ | Omullhs | Omullhu | Odivl | Odivlu | Omodl | Omodlu
  | Omulf | Odivf | Omulfs | Odivfs
  | Ointoffloat | Ofloatofint | Ointofsingle | Osingleofint
  | Olongoffloat | Ofloatoflong | Olongofsingle | Osingleoflong => 2%nat
  | Ocast8signed | Ocast8unsigned | Ocast16signed | Ocast16unsigned
  | Oneg | Osub | Oand | Oandimm _ | Oor | Oorimm _ | Oxor | Oxorimm _ | Onot
  | Oshl | Oshlimm _ | Oshr | Oshrimm _ | Oshrximm _ | Oshru | Oshruimm _
  | Ororimm _ | Oshldimm _ | Olea _
  | Omakelong | Olowlong | Ohighlong | Ocast32signed | Ocast32unsigned
  | Onegl | Oaddlimm _ | Osubl | Oandl | Oandlimm _ | Oorl | Oorlimm _
  | Oxorl | Oxorlimm _ | Onotl | Oshll | Oshllimm _ | Oshrl | Oshrlimm _
  | Oshrxlimm _ | Oshrlu | Oshrluimm _ | Ororlimm _ | Oleal _
  | Onegf | Oabsf | Oaddf | Osubf | Omaxf | Ominf
  | Onegfs | Oabsfs | Oaddfs | Osubfs | Osingleoffloat | Ofloatofsingle
  | Ocmp _ | Osel _ _ => 1%nat
  | _ => 0%nat
  end.

Definition costly (entry: node * instruction) :=
  match snd entry with Iop op _ _ _ => Nat.leb 2 (operation_cost op) | _ => false end.

(** Inlining introduces argument copies that can hide an invariant from
    the next round. Consider such copies when they feed a costly operation;
    the usual region checks still establish that their inputs are stable. *)
Definition worthwhile (needed: list reg) (op: operation) (dst: reg) :=
  negb (Nat.eqb (operation_cost op) 0) ||
  match op with
  | Omove => if In_dec peq dst needed then true else false
  | _ => false
  end.

(** Collect a bounded region after the candidate, stopping at the candidate
    itself, writes to protected registers, calls and returns. *)
Fixpoint region (fuel: nat) (f: function) (p: candidate)
                (work seen: list node) : list node :=
  match fuel, work with
  | S fuel', pc :: rest =>
      if peq pc p.(location) then region fuel' f p rest seen else
      if In_dec peq pc seen then region fuel' f p rest seen else
      match f.(fn_code)!pc with
      | Some i => if safe p i
                  then region fuel' f p (successors_instr i ++ rest) (pc :: seen)
                  else region fuel' f p rest seen
      | None => region fuel' f p rest seen
      end
  | _, _ => seen
  end.

(** Exclude exit-only paths, which can also be reached when the entry guard fails. *)
Definition loop_region (f: function) (p: candidate) (s: node) :=
  List.filter (fun pc => reaches_latch lookahead f p.(location) p.(location)
                         (pc :: nil) (PTree.empty _))
    (region 256 f p (s :: nil) nil).

(** The region must have a single external entrance: the candidate.
    In particular, initialization must not jump directly into the region.
    An unrotated while header normally fails this test; its copied latch
    allows the rotated loop to pass. These checks also handle extra CFG edges. *)
Definition valid_node (p: candidate) (body: list node) (pc: node) (i: instruction) :=
  if In_dec peq pc body then safe p i else
  if peq pc p.(location) then true else
  forallb (fun s => if In_dec peq s body then false else true) (successors_instr i).

Definition valid (f: function) (p: candidate) (body: list node) :=
  (if In_dec peq f.(fn_entrypoint) body then false else true) &&
  (if In_dec peq p.(location) body then false else true) &&
  forallb (fun entry => valid_node p body (fst entry) (snd entry)) (PTree.elements f.(fn_code)).

Definition has_backedge (f: function) (p: candidate) (body: list node) :=
  existsb (fun pc => match f.(fn_code)!pc with
    | Some i => if In_dec peq p.(location) (successors_instr i) then true else false
    | None => false
    end) body.

Fixpoint find_candidate (needed: list reg)
                       (check: function -> candidate -> list node -> bool)
                       (f: function) (code: list (node * instruction))
                       : option (candidate * list node) :=
  match code with
  | nil => None
  | (pc, Iop op args dst s) :: rest =>
      if worthwhile needed op dst then
      if op_depends_on_memory op then find_candidate needed check f rest else
      if In_dec peq dst args then find_candidate needed check f rest else
      let p := Candidate pc op args dst in
      let body := loop_region f p s in
      (* Reject acyclic or oversized regions before the whole-code check. *)
      if has_backedge f p body &&
         Nat.leb (List.length body) (if Nat.leb 2 (operation_cost op) then 128 else 32) &&
         check f p body
      then Some (p, body) else find_candidate needed check f rest
      else find_candidate needed check f rest
  | _ :: rest => find_candidate needed check f rest
  end.

Definition select_with check (f: function) :=
  let code := PTree.elements f.(fn_code) in
  let expensive := List.filter costly code in
  let needed := List.flat_map (fun e => match snd e with
    | Iop _ args _ _ => args | _ => nil end) expensive in
  find_candidate needed (check needed) f
    (expensive ++ List.filter (fun e => negb (costly e)) code).

Definition selected := select_with (fun _ => valid).

Definition redirect (f: function) (p: candidate) (s: node) :=
  if peq s p.(location) then copy_node (max_pc_function f) p.(location) else s.

Definition original (f: function) (p: candidate) (body: list node)
                    (pc: node) (i: instruction) :=
  if In_dec peq pc body then map_successors (redirect f p) i else i.

(** A self move keeps the RTL simulation one step per source instruction.
    Register allocation removes it; the generated loop has no recomputation. *)
Definition transf_code (f: function) (p: candidate) (body: list node) :=
  let c := PTree.map (original f p body) f.(fn_code) in
  match f.(fn_code)!(location p) with
  | Some (Iop _ _ _ s) =>
      PTree.set (copy_node (max_pc_function f) p.(location))
        (Iop Omove (p.(result) :: nil) p.(result) s) c
  | _ => c
  end.

Definition eliminate_function (f: function) : function :=
  match selected f with
  | None => f
  | Some (p, body) => mkfunction f.(fn_sig) f.(fn_params) f.(fn_stacksize)
                        (transf_code f p body) f.(fn_entrypoint)
  end.

Definition eliminate_fundef := AST.transf_fundef eliminate_function.
Definition eliminate_program (p: program) : program := AST.transform_program eliminate_fundef p.

(** Preserve the first traversal in a copied region. In particular, loads,
    stores and guards before an invariant retain their execution order.
    The original region is entered only after the candidate has executed. *)
Definition peel_check (needed: list reg) (f: function) (p: candidate) (body: list node) :=
  (Nat.leb 2 (operation_cost p.(invariant_op)) ||
   if In_dec peq p.(result) needed then true else false) && negb (valid f p body).

(** Copying a region has a higher profitability threshold than reusing an
    existing entrance. Cheap operations justify copies only as direct inputs
    of costly operations. This heuristic does not guarantee a speedup. *)
Definition peel_selected (f: function) :=
  match selected f with
  | Some _ => None
  | None => select_with peel_check f
  end.

Definition peel_entry (f: function) (body: list node) (s: node) :=
  if In_dec peq s body then copy_node (max_pc_function f) s else s.

Definition peel_rename (f: function) (p: candidate) (body: list node) (pc: node) :=
  if peq pc p.(location) then (fun s => s) else
  if In_dec peq pc body then (fun s => s) else peel_entry f body.

Definition peel_code (f: function) (p: candidate) (body: list node) :=
  PTree.fold (fun c pc i =>
    if In_dec peq pc body then
      PTree.set (copy_node (max_pc_function f) pc)
        (map_successors (peel_entry f body) i) c else c)
    f.(fn_code) (PTree.map (fun pc i => map_successors (peel_rename f p body pc) i) f.(fn_code)).

Definition prepare_function (f: function) : function :=
  match peel_selected f with
  | None => f
  | Some (p, body) => mkfunction f.(fn_sig) f.(fn_params) f.(fn_stacksize)
      (peel_code f p body) (peel_entry f body f.(fn_entrypoint))
  end.

Definition prepare_program (p: program) :=
  AST.transform_program (AST.transf_fundef prepare_function) p.

(** Eight rounds bound compilation time and code growth. This is a search
    limit, not a correctness premise or a promise of profitability. Each
    round can expose operands of a later dependent invariant. *)
Definition round_function (f: function) := eliminate_function (prepare_function f).

(** Reuse the entry-candidate search instead of repeating it in preparation
    and elimination. [None] means that neither transformation applies, so
    further rounds would only repeat the same searches on the same code.
    The fallback keeps the existing candidate order and safety checks. *)
Definition round_step (f: function) : option function :=
  match selected f with
  | Some (p, body) => Some (mkfunction f.(fn_sig) f.(fn_params) f.(fn_stacksize)
                            (transf_code f p body) f.(fn_entrypoint))
  | None =>
      match select_with peel_check f with
      | None => None
      | Some (p, body) => Some (eliminate_function
          (mkfunction f.(fn_sig) f.(fn_params) f.(fn_stacksize)
            (peel_code f p body) (peel_entry f body f.(fn_entrypoint))))
      end
  end.

Fixpoint iterate (n: nat) (f: function) : function :=
  match n with
  | O => f
  | S n => match round_step f with None => f | Some f' => iterate n f' end
  end.
Definition transf_function := iterate 8.
Definition transf_fundef := AST.transf_fundef transf_function.
Definition transf_program (p: program) := AST.transform_program transf_fundef p.
