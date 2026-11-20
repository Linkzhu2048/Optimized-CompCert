(** Closed-form elimination of validated unit-stride summation loops.
    Run after AccumRec. Recognition is structural, never based on names.
    Ordinary, affine two-parameter and square sums have separate checked
    shapes. Division by two uses a widened product; all final results obey
    32-bit modular arithmetic. *)
Require Import Coqlib Maps AST Integers Op Registers RTL AccumRec.

(** Operand ordering is recorded in the certificate; both orders are checked. *)
Definition add_args (reversed: bool) (a b: reg) : list reg :=
  if reversed then b :: a :: nil else a :: b :: nil.
Definition reversed_args (a: reg) (args: list reg) : bool :=
  match args with r :: _ => negb (Pos.eqb a r) | nil => false end.

Definition zero_condition (less: bool) : Op.condition :=
  if less then Ccompuimm Clt Int.one else Ccompuimm Ceq Int.zero.
Definition less_guard (cond: Op.condition) : bool :=
  if eq_condition cond (Ccompuimm Clt Int.one) then true else
  if eq_condition cond (Ccompuimm Cge Int.one) then true else false.
Definition signed_guard (cond: Op.condition) : bool :=
  if eq_condition cond (Ccompimm Cle Int.zero) then true else
  if eq_condition cond (Ccompimm Cgt Int.zero) then true else false.
Definition reverse_guard (cond: Op.condition) : bool :=
  if eq_condition cond (Ccompuimm Cne Int.zero) then true else
  if eq_condition cond (Ccompuimm Cge Int.one) then true else
  if eq_condition cond (Ccompimm Cgt Int.zero) then true else false.
Definition guard_instruction (reverse: bool) (cond: Op.condition)
    (args: list reg) (yes no: node) : instruction :=
  if reverse then Icond (negate_condition cond) args no yes
  else Icond cond args yes no.

Module Basic.

Record shape := mkshape {
  add_reversed: bool; finish_reversed: bool; less_test: bool; reverse_test: bool;
  signed_test: bool;
  parameter: reg;
  accumulator_reg: reg;
  decrement_reg: reg;
  base_reg: reg;
  base_value: int;
  entry_node: node;
  test_node: node;
  base_node: node;
  decrement_node: node;
  add_node: node;
  move_node: node;
  finish_node: node;
  return_node: node
}.

Definition condition (c: shape) :=
  if signed_test c then Ccompimm Cle Int.zero else zero_condition (less_test c).

Definition registers (c: shape) :=
  parameter c :: accumulator_reg c :: decrement_reg c :: base_reg c :: nil.

Definition nodes (c: shape) :=
  entry_node c :: test_node c :: base_node c :: decrement_node c ::
  add_node c :: move_node c :: finish_node c :: return_node c :: nil.

Definition instructions (c: shape) : list (node * instruction) :=
  (entry_node c, Iop (Ointconst Int.zero) nil (accumulator_reg c) (test_node c)) ::
  (test_node c, guard_instruction (reverse_test c) (condition c) (parameter c :: nil) (base_node c) (decrement_node c)) ::
  (base_node c, Iop (Ointconst (base_value c)) nil (base_reg c) (finish_node c)) ::
  (decrement_node c, Iop (Olea (Aindexed (-1))) (parameter c :: nil) (decrement_reg c) (add_node c)) ::
  (add_node c, Iop int_add_operation (add_args (add_reversed c) (accumulator_reg c) (parameter c)) (accumulator_reg c) (move_node c)) ::
  (move_node c, Iop Omove (decrement_reg c :: nil) (parameter c) (test_node c)) ::
  (finish_node c, Iop int_add_operation (add_args (finish_reversed c) (accumulator_reg c) (base_reg c)) (accumulator_reg c) (return_node c)) ::
  (return_node c, Ireturn (Some (accumulator_reg c))) :: nil.

Definition validate (f: function) (c: shape) : bool :=
  if Archi.ptr64 then
  if signature_eq (fn_sig f) unary_int_signature then
  if zeq (fn_stacksize f) 0 then
  if list_eq_dec peq (fn_params f) (parameter c :: nil) then
  if peq (fn_entrypoint f) (entry_node c) then
  if list_norepet_dec peq (registers c) then
  if list_norepet_dec peq (nodes c) then
    forallb (fun entry =>
      match (fn_code f)!(fst entry) with
      | Some i => if instruction_eq i (snd entry) then true else false
      | None => false
      end) (instructions c)
  else false else false else false else false else false else false else false.

(** Discover node/register names; [validate] independently checks all edges
    and exact operations, as well as the aliasing restrictions. *)
Definition discover (f: function) : option shape :=
  match fn_params f, (fn_code f)!(fn_entrypoint f) with
  | p :: nil, Some (Iop _ _ acc test) =>
    match (fn_code f)!test with
    | Some (Icond cond _ yes no) =>
      let reverse := reverse_guard cond in
      let base := if reverse then no else yes in
      let dec := if reverse then yes else no in
      let mode := signed_guard cond in
      match (fn_code f)!base, (fn_code f)!dec with
      | Some (Iop (Ointconst k) _ rb finish), Some (Iop _ _ rd add) =>
        match (fn_code f)!add, (fn_code f)!finish with
        | Some (Iop _ aargs _ move), Some (Iop _ fargs _ ret) =>
          Some (mkshape (reversed_args acc aargs) (reversed_args acc fargs) (less_guard cond) reverse mode p acc rd rb k (fn_entrypoint f) test base dec add move finish ret)
        | _, _ => None
        end
      | _, _ => None
      end
    | _ => None
    end
  | _, _ => None
  end.

Definition recognize (f: function) : option shape :=
  match discover f with Some c => if validate f c then Some c else None | None => None end.

Local Open Scope positive_scope.
Definition fast_code (c: shape) : code :=
  PTree.set 1 (Icond (condition c) (1%positive :: nil) 10 2)
  (PTree.set 2 (Iop Ocast32unsigned (1%positive :: nil) 2 3)
  (PTree.set 3 (Iop (Oaddlimm Int64.one) (2%positive :: nil) 3 4)
  (PTree.set 4 (Iop Omull (2%positive :: 3%positive :: nil) 4 5)
  (PTree.set 5 (Iop (Oshrluimm Int.one) (4%positive :: nil) 5 6)
  (PTree.set 6 (Iop Olowlong (5%positive :: nil) 6 7)
  (PTree.set 7 (Iop (Ointconst (base_value c)) nil 7 8)
  (PTree.set 8 (Iop int_add_operation (6%positive :: 7%positive :: nil) 8 9)
  (PTree.set 9 (Ireturn (Some 8%positive))
  (PTree.set 10 (Iop (Ointconst (base_value c)) nil 8 9) (PTree.empty instruction)))))))))).

Definition fast_function (c: shape) : function :=
  mkfunction unary_int_signature (1%positive :: nil) 0%Z (fast_code c)
    (if signed_test c then 1 else 2).

Definition transf_function (f: function) : function :=
  match recognize f with Some c => fast_function c | None => f end.

Definition transf_fundef := AST.transf_fundef transf_function.
Definition transf_program (p: program) := transform_program transf_fundef p.

End Basic.

(** Two-parameter summation.  The second parameter and the accumulator
    both receive the current counter before it is decremented.  The base
    case returns their sum, so the result is [a + n * (n + 1)]. *)
Module Affine.
Record shape := mkshape {
  add_reversed: bool; finish_reversed: bool; less_test: bool; reverse_test: bool; update_reversed: bool;
  parameter: reg; initial_reg: reg; accumulator_reg: reg;
  decrement_reg: reg; update_reg: reg;
  entry_node: node; test_node: node; decrement_node: node;
  update_node: node; add_node: node; move_node: node;
  assign_node: node; finish_node: node; return_node: node
}.
Definition signature := int_signature (1%positive :: 2%positive :: nil).
Definition registers (c: shape) :=
  parameter c :: initial_reg c :: accumulator_reg c :: decrement_reg c :: update_reg c :: nil.
Definition nodes (c: shape) :=
  entry_node c :: test_node c :: decrement_node c :: update_node c :: add_node c ::
  move_node c :: assign_node c :: finish_node c :: return_node c :: nil.
Definition instructions (c: shape) : list (node * instruction) :=
  (entry_node c, Iop (Ointconst Int.zero) nil (accumulator_reg c) (test_node c)) ::
  (test_node c, guard_instruction (reverse_test c) (zero_condition (less_test c)) (parameter c :: nil) (finish_node c) (decrement_node c)) ::
  (decrement_node c, Iop (Olea (Aindexed (-1))) (parameter c :: nil) (decrement_reg c) (update_node c)) ::
  (update_node c, Iop int_add_operation (add_args (update_reversed c) (initial_reg c) (parameter c)) (update_reg c) (add_node c)) ::
  (add_node c, Iop int_add_operation (add_args (add_reversed c) (accumulator_reg c) (parameter c)) (accumulator_reg c) (move_node c)) ::
  (move_node c, Iop Omove (decrement_reg c :: nil) (parameter c) (assign_node c)) ::
  (assign_node c, Iop Omove (update_reg c :: nil) (initial_reg c) (test_node c)) ::
  (finish_node c, Iop int_add_operation (add_args (finish_reversed c) (accumulator_reg c) (initial_reg c)) (accumulator_reg c) (return_node c)) ::
  (return_node c, Ireturn (Some (accumulator_reg c))) :: nil.
Definition validate (f: function) (c: shape) : bool :=
  if Archi.ptr64 then
  if signature_eq (fn_sig f) signature then
  if zeq (fn_stacksize f) 0 then
  if list_eq_dec peq (fn_params f) (parameter c :: initial_reg c :: nil) then
  if peq (fn_entrypoint f) (entry_node c) then
  if list_norepet_dec peq (registers c) then
  if list_norepet_dec peq (nodes c) then
    forallb (fun entry => match (fn_code f)!(fst entry) with
      | Some i => if instruction_eq i (snd entry) then true else false
      | None => false end) (instructions c)
  else false else false else false else false else false else false else false.
Definition discover (f: function) : option shape :=
  match fn_params f, (fn_code f)!(fn_entrypoint f) with
  | n :: a :: nil, Some (Iop _ _ acc test) =>
    match (fn_code f)!test with
    | Some (Icond cond _ yes no) =>
      let reverse := reverse_guard cond in
      let finish := if reverse then no else yes in
      let dec := if reverse then yes else no in
      match (fn_code f)!dec, (fn_code f)!finish with
      | Some (Iop _ _ rd update), Some (Iop _ fargs _ ret) =>
        match (fn_code f)!update with
        | Some (Iop _ uargs ru add) =>
          match (fn_code f)!add with
          | Some (Iop _ aargs _ move) =>
            match (fn_code f)!move with
            | Some (Iop _ _ _ assign) => Some (mkshape (reversed_args acc aargs) (reversed_args acc fargs) (less_guard cond) reverse (reversed_args a uargs) n a acc rd ru
                (fn_entrypoint f) test dec update add move assign finish ret)
            | _ => None end
          | _ => None end
        | _ => None end
      | _,_ => None end
    | _ => None end
  | _,_ => None end.
Definition recognize (f: function) : option shape :=
  match discover f with Some c => if validate f c then Some c else None | None => None end.

Local Open Scope positive_scope.
Definition fast_code : code :=
  PTree.set 1 (Iop (Olea (Aindexed 1)) (1%positive :: nil) 3 2)
  (PTree.set 2 (Iop Omul (1%positive :: 3%positive :: nil) 4 3)
  (PTree.set 3 (Iop int_add_operation (2%positive :: 4%positive :: nil) 5 4)
  (PTree.set 4 (Ireturn (Some 5%positive)) (PTree.empty instruction)))).
Definition fast_function : function :=
  mkfunction signature (1%positive :: 2%positive :: nil) 0 fast_code 1.
Definition transf_function (f: function) : function :=
  match recognize f with Some _ => fast_function | None => f end.
Definition transf_fundef := AST.transf_fundef transf_function.
Definition transf_program (p: program) := transform_program transf_fundef p.
End Affine.

(** Squared summands use exact division by two followed by the inverse
    of three modulo 2^32.  No overflowing 64-bit cubic is evaluated. *)
Module Square.
Record shape := mkshape {
  add_reversed: bool; finish_reversed: bool; less_test: bool; reverse_test: bool;
  signed_test: bool;
  square_reg: reg;
  square_node: node;
  parameter: reg;
  accumulator_reg: reg;
  decrement_reg: reg;
  base_reg: reg;
  base_value: int;
  entry_node: node;
  test_node: node;
  base_node: node;
  decrement_node: node;
  add_node: node;
  move_node: node;
  finish_node: node;
  return_node: node
}.

Definition condition (c: shape) :=
  if signed_test c then Ccompimm Cle Int.zero else zero_condition (less_test c).

Definition registers (c: shape) :=
  parameter c :: accumulator_reg c :: decrement_reg c :: base_reg c :: square_reg c :: nil.

Definition nodes (c: shape) :=
  square_node c :: entry_node c :: test_node c :: base_node c :: decrement_node c ::
  add_node c :: move_node c :: finish_node c :: return_node c :: nil.

Definition instructions (c: shape) : list (node * instruction) :=
  (entry_node c, Iop (Ointconst Int.zero) nil (accumulator_reg c) (test_node c)) ::
  (test_node c, guard_instruction (reverse_test c) (condition c) (parameter c :: nil) (base_node c) (square_node c)) ::
  (square_node c, Iop Omul (parameter c :: parameter c :: nil) (square_reg c) (decrement_node c)) ::
  (base_node c, Iop (Ointconst (base_value c)) nil (base_reg c) (finish_node c)) ::
  (decrement_node c, Iop (Olea (Aindexed (-1))) (parameter c :: nil) (decrement_reg c) (add_node c)) ::
  (add_node c, Iop int_add_operation (add_args (add_reversed c) (accumulator_reg c) (square_reg c)) (accumulator_reg c) (move_node c)) ::
  (move_node c, Iop Omove (decrement_reg c :: nil) (parameter c) (test_node c)) ::
  (finish_node c, Iop int_add_operation (add_args (finish_reversed c) (accumulator_reg c) (base_reg c)) (accumulator_reg c) (return_node c)) ::
  (return_node c, Ireturn (Some (accumulator_reg c))) :: nil.

Definition validate (f: function) (c: shape) : bool :=
  if Archi.ptr64 then
  if signature_eq (fn_sig f) unary_int_signature then
  if zeq (fn_stacksize f) 0 then
  if list_eq_dec peq (fn_params f) (parameter c :: nil) then
  if peq (fn_entrypoint f) (entry_node c) then
  if list_norepet_dec peq (registers c) then
  if list_norepet_dec peq (nodes c) then
    forallb (fun entry =>
      match (fn_code f)!(fst entry) with
      | Some i => if instruction_eq i (snd entry) then true else false
      | None => false
      end) (instructions c)
  else false else false else false else false else false else false else false.

(** Discover node/register names; [validate] independently checks all edges
    and exact operations, as well as the aliasing restrictions. *)
Definition discover (f: function) : option shape :=
  match fn_params f, (fn_code f)!(fn_entrypoint f) with
  | p :: nil, Some (Iop _ _ acc test) =>
    match (fn_code f)!test with
    | Some (Icond cond _ yes no) =>
      let reverse := reverse_guard cond in
      let base := if reverse then no else yes in
      let square := if reverse then yes else no in
      let mode := signed_guard cond in
      match (fn_code f)!base, (fn_code f)!square with
      | Some (Iop (Ointconst k) _ rb finish), Some (Iop _ _ rq dec) =>
        match (fn_code f)!dec with
        | Some (Iop _ _ rd add) =>
          match (fn_code f)!add, (fn_code f)!finish with
          | Some (Iop _ aargs _ move), Some (Iop _ fargs _ ret) =>
            Some (mkshape (reversed_args acc aargs) (reversed_args acc fargs) (less_guard cond) reverse mode rq square p acc rd rb k
              (fn_entrypoint f) test base dec add move finish ret)
          | _,_ => None end
        | _ => None end
      | _,_ => None end
    | _ => None end
  | _,_ => None end.

Definition recognize (f: function) : option shape :=
  match discover f with Some c => if validate f c then Some c else None | None => None end.

Local Open Scope positive_scope.
Definition fast_code (c: shape) : code :=
  PTree.set 1 (Icond (condition c) (1%positive :: nil) 10 2)
  (PTree.set 2 (Iop Ocast32unsigned (1%positive :: nil) 2 3)
  (PTree.set 3 (Iop (Oaddlimm Int64.one) (2%positive :: nil) 3 4)
  (PTree.set 4 (Iop Omull (2%positive :: 3%positive :: nil) 4 5)
  (PTree.set 5 (Iop (Oshrluimm Int.one) (4%positive :: nil) 5 6)
  (PTree.set 6 (Iop Olowlong (5%positive :: nil) 6 11)
  (PTree.set 7 (Iop (Ointconst (base_value c)) nil 7 8)
  (PTree.set 8 (Iop int_add_operation (6%positive :: 7%positive :: nil) 8 9)
  (PTree.set 9 (Ireturn (Some 8%positive))
  (PTree.set 10 (Iop (Ointconst (base_value c)) nil 8 9)
  (PTree.set 11 (Iop (Olea (Ascaled 2 1)) (1%positive :: nil) 9 12)
  (PTree.set 12 (Iop Omul (6%positive :: 9%positive :: nil) 10 13)
  (PTree.set 13 (Iop (Omulimm (Int.repr 2863311531)) (10%positive :: nil) 6 7)
    (PTree.empty instruction))))))))))))).

Definition fast_function (c: shape) : function :=
  mkfunction unary_int_signature (1%positive :: nil) 0%Z (fast_code c)
    (if signed_test c then 1 else 2).

Definition transf_function (f: function) : function :=
  match recognize f with Some c => fast_function c | None => f end.

Definition transf_fundef := AST.transf_fundef transf_function.
Definition transf_program (p: program) := transform_program transf_fundef p.

End Square.

Definition transf_program (p: program) :=
  Square.transf_program (Affine.transf_program (Basic.transf_program p)).
