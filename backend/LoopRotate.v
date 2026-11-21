(* *********************************************************************)
(*                                                                     *)
(*              The Compcert verified compiler                         *)
(*                                                                     *)
(* *********************************************************************)

(** Restricted loop rotation by copying conditional loop headers. *)

Require Import Coqlib Maps AST RTL.

(** Only conditional headers are copied; computations and calls stay
    at their original nodes. A bounded search recognizes short paths
    through calls and internal branches, including early exits. *)

Definition single_successor (i: instruction) : option node :=
  match i with
  | Inop s | Iop _ _ _ s | Iload _ _ _ _ s | Istore _ _ _ _ s
  | Icall _ _ _ _ s | Ibuiltin _ _ _ s => Some s
  | _ => None
  end.

Fixpoint reaches_latch (fuel: nat) (f: function) (stop header: node)
                      (work: list node) (seen: PTree.t unit) : bool :=
  match work with
  | nil => false
  | pc :: rest =>
      if peq pc stop then true else
      match fuel with
      | O => false
      | S fuel' =>
          if peq pc header then reaches_latch fuel' f stop header rest seen else
          match seen!pc with
          | Some _ => reaches_latch fuel' f stop header rest seen
          | None =>
              let next :=
                match f.(fn_code)!pc with
                | Some i => successors_instr i
                | None => nil
                end in
              reaches_latch fuel' f stop header (next ++ rest)
                (PTree.set pc tt seen)
          end
      end
  end.

Definition lookahead := 128%nat.

(** Check that entry cannot reach the latch without crossing the header.
    Exhaustion rejects the candidate, rather than claiming unreachability.
    This avoids depending on node numbering or rotating internal joins. *)
Fixpoint entry_through_header (fuel: nat) (f: function) (latch header: node)
                             (work: list node) (seen: PTree.t unit) : bool :=
  match work with
  | nil => true
  | pc :: rest =>
      match fuel with
      | O => false
      | S fuel' =>
          if peq pc header then entry_through_header fuel' f latch header rest seen else
          if peq pc latch then false else
          match seen!pc with
          | Some _ => entry_through_header fuel' f latch header rest seen
          | None =>
              let next := match f.(fn_code)!pc with
                          | Some i => successors_instr i | None => nil end in
              entry_through_header fuel' f latch header (next ++ rest)
                (PTree.set pc tt seen)
          end
      end
  end.

(** Selection is a heuristic, not a premise of semantic preservation.
    Exactly one arm must reach the latch within the search budget without
    crossing the header again. Each selected edge gets its own copy. *)

Definition loop_header (f: function) (pc: node) : option node :=
  match f.(fn_code)!pc with
  | Some i =>
      match single_successor i with
      | Some h =>
          match f.(fn_code)!h with
          | Some (Icond _ _ yes no) =>
              if xorb (reaches_latch lookahead f pc h (yes :: nil) (PTree.empty _))
                      (reaches_latch lookahead f pc h (no :: nil) (PTree.empty _))
                 && entry_through_header lookahead f pc h
                      (f.(fn_entrypoint) :: nil) (PTree.empty _)
              then Some h else None
          | _ => None
          end
      | None => None
      end
  | None => None
  end.

(** Analyze once, and retain original node numbers. Copies are allocated
    above the largest existing node. Unselected functions are returned
    unchanged, avoiding perturbations of subsequent register allocation. *)

Definition rotation_plan (f: function) : PTree.t node :=
  PTree.map_filter1 (fun h => h)
    (PTree.map (fun pc _ => loop_header f pc) f.(fn_code)).

Definition copy_node (bound pc: node) : node := (bound + pc)%positive.

Definition map_successors (rename: node -> node) (i: instruction) :=
  match i with
  | Inop s => Inop (rename s)
  | Iop op args dst s => Iop op args dst (rename s)
  | Iload chunk addr args dst s => Iload chunk addr args dst (rename s)
  | Istore chunk addr args src s => Istore chunk addr args src (rename s)
  | Icall sg ros args dst s => Icall sg ros args dst (rename s)
  | Itailcall sg ros args => i
  | Ibuiltin ef args dst s => Ibuiltin ef args dst (rename s)
  | Icond cond args yes no => Icond cond args (rename yes) (rename no)
  | Ijumptable arg tbl => Ijumptable arg (List.map rename tbl)
  | Ireturn arg => i
  end.

Definition redirect (bound: node) (plan: PTree.t node) (pc s: node) : node :=
  match plan!pc with
  | Some h => if peq s h then copy_node bound pc else s
  | None => s
  end.

Definition add_copy (f: function) (bound: node)
                    (c: code) (pc h: node) : code :=
  match f.(fn_code)!h with
  | Some i => PTree.set (copy_node bound pc) i c
  | None => c
  end.

Definition transf_code (f: function) (plan: PTree.t node) : code :=
  let bound := max_pc_function f in
  PTree.fold (add_copy f bound) plan
    (PTree.map (fun pc i => map_successors (redirect bound plan pc) i)
      f.(fn_code)).

Definition transf_function (f: function) : function :=
  let plan := rotation_plan f in
  match PTree.elements plan with
  | nil => f
  | _ => mkfunction f.(fn_sig) f.(fn_params) f.(fn_stacksize)
           (transf_code f plan) f.(fn_entrypoint)
  end.

Definition transf_fundef (fd: fundef) : fundef :=
  AST.transf_fundef transf_function fd.

Definition transf_program (p: program) : program :=
  AST.transform_program transf_fundef p.
