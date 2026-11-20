(** Closed-form summation: correctness proof.

    Mathematical identities, recognition soundness, target execution, the
    source-loop invariant and the whole-program simulation are kept together. *)
From Coq Require Import Ring.
Require Import Coqlib Maps AST Linking Integers Values Memory Globalenvs Events Smallstep.
Require Import Op Registers RTL AccumRec AccumRecproof SumClosed.
Lemma eval_add_args:
  forall (ge: genv) sp m rs order r1 r2 a b,
  rs#r1 = Vint a -> rs#r2 = Vint b ->
  eval_operation ge sp int_add_operation (rs##(add_args order r1 r2)) m =
    Some (Vint (Int.add a b)).
Proof.
  intros. destruct order; simpl; rewrite H, H0; simpl;
    rewrite Int.add_zero; [rewrite Int.add_commut | ]; reflexivity.
Qed.

Lemma eval_zero_condition:
  forall less n m, eval_condition (zero_condition less) (Vint n :: nil) m = Some (Int.eq n Int.zero).
Proof.
  intros. destruct less; [|reflexivity].
  change (Some (Int.ltu n Int.one) = Some (Int.eq n Int.zero)).
  unfold Int.ltu, Int.eq. rewrite Int.unsigned_one, Int.unsigned_zero.
  destruct (zlt (Int.unsigned n) 1); destruct (zeq (Int.unsigned n) 0);
    try reflexivity; generalize (Int.unsigned_range n); lia.
Qed.

Lemma guard_step:
  forall ge s f sp pc rs m reverse cond args yes no b t S2,
  (fn_code f)!pc = Some (guard_instruction reverse cond args yes no) ->
  eval_condition cond (rs##args) m = Some b ->
  step ge (State s f sp pc rs m) t S2 ->
  t = E0 /\ S2 = State s f sp (if b then yes else no) rs m.
Proof.
  intros ge s f sp pc rs m reverse cond args yes no b t S2 CODE EVAL STEP.
  destruct reverse; simpl in CODE; inv STEP; try congruence;
    match goal with H: (fn_code f)!pc = Some _ |- _ => rewrite CODE in H; inv H end;
    match goal with H: eval_condition _ _ _ = _ |- _ =>
      first [rewrite eval_negate_condition, EVAL in H | rewrite EVAL in H]; inv H end;
    try (destruct b); auto.
Qed.

Module BasicCorrect.
Import SumClosed.Basic.
Local Open Scope rtl.

(** * Arithmetic *)

Section ARITHMETIC.
(** Machine-integer arithmetic for the summation closed form. *)

Definition triangle (n: Z) := n * (n + 1) / 2.
Definition count (c: shape) (n: int) :=
  if signed_test c then Z.max 0 (Int.signed n) else Int.unsigned n.
Definition sum_value (c: shape) (n: int) := Int.repr (triangle (count c n)).
Definition answer (c: shape) (n: int) := Int.add (sum_value c n) (base_value c).
Definition is_base (c: shape) (n: int) :=
  if signed_test c then negb (Int.lt Int.zero n) else Int.eq n Int.zero.

Lemma triangle_step:
  forall n, triangle n = triangle (n - 1) + n.
Proof.
  intros. unfold triangle.
  replace (n * (n + 1)) with ((n - 1) * (n - 1 + 1) + n * 2) by ring.
  rewrite Z.div_add by lia. reflexivity.
Qed.

Lemma count_nonnegative:
  forall c n, 0 <= count c n.
Proof.
  intros. unfold count. destruct (signed_test c).
  apply Z.le_max_l. generalize (Int.unsigned_range n); lia.
Qed.

Lemma int_add_repr:
  forall a b, Int.add (Int.repr a) (Int.repr b) = Int.repr (a + b).
Proof.
  intros. unfold Int.add. apply Int.eqm_samerepr.
  apply Int.eqm_add; auto with ints.
Qed.

Lemma int64_add_repr:
  forall a b, Int64.add (Int64.repr a) (Int64.repr b) = Int64.repr (a + b).
Proof.
  intros. unfold Int64.add. apply Int64.eqm_samerepr.
  apply Int64.eqm_add; auto with ints.
Qed.

Lemma int64_mul_repr:
  forall a b, Int64.mul (Int64.repr a) (Int64.repr b) = Int64.repr (a * b).
Proof.
  intros. unfold Int64.mul. apply Int64.eqm_samerepr.
  apply Int64.eqm_mult; auto with ints.
Qed.

Lemma wide_triangle:
  forall n,
  Int64.loword
    (Int64.shru'
      (Int64.mul (Int64.repr (Int.unsigned n))
        (Int64.add (Int64.repr (Int.unsigned n)) Int64.one)) Int.one) =
  Int.repr (triangle (Int.unsigned n)).
Proof.
  intros. unfold Int64.one. rewrite int64_add_repr, int64_mul_repr.
  assert (RANGE: 0 <= Int.unsigned n <= 4294967295).
  { generalize (Int.unsigned_range n). change Int.modulus with 4294967296. lia. }
  assert (PRODUCT: 0 <= Int.unsigned n * (Int.unsigned n + 1) <= Int64.max_unsigned).
  { change Int64.max_unsigned with 18446744073709551615. nia. }
  unfold Int64.shru'. rewrite Int64.unsigned_repr by exact PRODUCT.
  rewrite Int.unsigned_one, Z.shiftr_div_pow2 by lia.
  change (2 ^ 1) with 2. unfold Int64.loword.
  rewrite Int64.unsigned_repr.
  reflexivity.
  split. apply Z.div_pos; lia.
  apply Z.div_le_upper_bound; lia.
Qed.

Lemma base_count_zero:
  forall c n, is_base c n = true -> count c n = 0.
Proof.
  intros c n. unfold is_base, count. destruct (signed_test c).
  - unfold Int.lt. rewrite Int.signed_zero.
    destruct (zlt 0 (Int.signed n)); simpl; intros; try discriminate. lia.
  - intro EQ. apply Int.same_if_eq in EQ. subst n. apply Int.unsigned_zero.
Qed.

Lemma nonbase_count:
  forall c n, is_base c n = false -> count c n = Int.unsigned n /\ 0 < count c n.
Proof.
  intros c n. unfold is_base, count. destruct (signed_test c).
  - unfold Int.lt. rewrite Int.signed_zero.
    destruct (zlt 0 (Int.signed n)); simpl; intros; try discriminate.
    assert (S: Int.signed n = Int.unsigned n).
    { unfold Int.signed in *. destruct (zlt (Int.unsigned n) Int.half_modulus); auto.
      generalize (Int.unsigned_range n). change Int.modulus with 4294967296 in *.
      change Int.half_modulus with 2147483648 in *. lia. }
    rewrite Z.max_r by lia. auto.
  - unfold Int.eq. rewrite Int.unsigned_zero.
    destruct (zeq (Int.unsigned n) 0); intros; try discriminate.
    generalize (Int.unsigned_range n); split; auto; lia.
Qed.

Lemma decrement_unsigned:
  forall n, 0 < Int.unsigned n ->
  Int.unsigned (Int.sub n Int.one) = Int.unsigned n - 1.
Proof.
  intros. unfold Int.sub. rewrite Int.unsigned_one, Int.unsigned_repr; auto.
  generalize (Int.unsigned_range n). unfold Int.max_unsigned. lia.
Qed.

Lemma decrement_count:
  forall c n, is_base c n = false ->
  count c (Int.sub n Int.one) = count c n - 1.
Proof.
  intros c n NB. destruct (nonbase_count _ _ NB) as [UN POS].
  assert (DEC: Int.unsigned (Int.sub n Int.one) = Int.unsigned n - 1).
  { apply decrement_unsigned. lia. }
  unfold count in *. destruct (signed_test c) eqn:MODE; auto.
  assert (SIGNED: 0 < Int.signed n).
  { unfold is_base, Int.lt in NB. rewrite MODE, Int.signed_zero in NB.
    destruct (zlt 0 (Int.signed n)); simpl in NB; congruence. }
  rewrite Z.max_r in UN by lia.
  assert (BOUND: Int.min_signed <= Int.unsigned n - 1 <= Int.max_signed).
  { generalize (Int.signed_range n). change Int.min_signed with (-2147483648). lia. }
  unfold Int.sub. rewrite Int.unsigned_one, Int.signed_repr by exact BOUND.
  rewrite Z.max_r by lia. lia.
Qed.

Lemma int_add_repr_left:
  forall a n, Int.add (Int.repr a) n = Int.repr (a + Int.unsigned n).
Proof.
  intros. unfold Int.add. apply Int.eqm_samerepr.
  apply Int.eqm_add; auto with ints.
Qed.

Lemma sum_value_step:
  forall c n, is_base c n = false ->
  sum_value c n = Int.add n (sum_value c (Int.sub n Int.one)).
Proof.
  intros c n NB. unfold sum_value. rewrite decrement_count by auto.
  rewrite triangle_step. rewrite (Int.add_commut n).
  rewrite int_add_repr_left.
  destruct (nonbase_count _ _ NB). congruence.
Qed.

Lemma eval_condition_base:
  forall c n m, eval_condition (condition c) (Vint n :: nil) m = Some (is_base c n).
Proof. intros. unfold condition, is_base. destruct (signed_test c); [reflexivity|apply eval_zero_condition]. Qed.
End ARITHMETIC.

(** * Recognition *)

Section RECOGNITION.
(** Soundness of the executable structural validator. *)

Record loop_spec (f: function) (c: shape): Prop := {
  spec_bits: Archi.ptr64 = true;
  spec_signature: fn_sig f = unary_int_signature;
  spec_stack: fn_stacksize f = 0;
  spec_parameters: fn_params f = parameter c :: nil;
  spec_entry: fn_entrypoint f = entry_node c;
  spec_registers: list_norepet (registers c);
  spec_nodes: list_norepet (nodes c);
  spec_code: forall pc i, In (pc,i) (instructions c) -> (fn_code f)!pc = Some i
}.

Theorem recognize_sound:
  forall f c, recognize f = Some c -> loop_spec f c.
Proof.
  intros f c REC. unfold recognize in REC.
  destruct (discover f) as [d|]; try discriminate.
  destruct (validate f d) eqn:VALID; inv REC.
  unfold validate in VALID.
  destruct Archi.ptr64 eqn:BITS; try discriminate.
  destruct (signature_eq (fn_sig f) unary_int_signature); try discriminate.
  destruct (zeq (fn_stacksize f) 0); try discriminate.
  destruct (list_eq_dec peq (fn_params f) (parameter c :: nil)); try discriminate.
  destruct (peq (fn_entrypoint f) (entry_node c)); try discriminate.
  destruct (list_norepet_dec peq (registers c)); try discriminate.
  destruct (list_norepet_dec peq (nodes c)); try discriminate.
  constructor; auto. intros pc i IN.
  apply forallb_forall with (x := (pc,i)) in VALID; auto. simpl in VALID.
  destruct ((fn_code f)!pc) eqn:CODE; try discriminate.
  destruct (instruction_eq i0 i); congruence.
Qed.

Lemma register_inequalities:
  forall f c, loop_spec f c ->
  parameter c <> accumulator_reg c /\ parameter c <> decrement_reg c /\
  parameter c <> base_reg c /\ accumulator_reg c <> decrement_reg c /\
  accumulator_reg c <> base_reg c /\ decrement_reg c <> base_reg c.
Proof.
  intros. pose proof (spec_registers _ _ H) as ND. unfold registers in ND.
  repeat match goal with H: list_norepet (_ :: _) |- _ => inv H end.
  simpl in *. intuition.
Qed.

Lemma function_signature:
  forall f, fn_sig (transf_function f) = fn_sig f.
Proof.
  intros. unfold transf_function. destruct (recognize f) as [c|] eqn:REC; auto.
  simpl. symmetry. eapply spec_signature. eapply recognize_sound; eauto.
Qed.
End RECOGNITION.

(** * Target execution *)

Section TARGET_EXECUTION.
(** Execution of the fixed-size target function. *)

Local Open Scope rtl.
Local Open Scope positive_scope.

Lemma fast_body_exec:
  forall ge c s sp rs m n,
  rs#(1%positive) = Vint n ->
  exists rs',
  plus RTL.step ge (State s (fast_function c) sp 2 rs m) E0
    (State s (fast_function c) sp 9 rs' m) /\
  rs'#(8%positive) = Vint (Int.add (Int.repr (triangle (Int.unsigned n))) (base_value c)).
Proof.
  intros ge c s sp rs m n ARG. eexists; split.
  - eapply plus_left.
    eapply exec_Iop; [reflexivity|]. simpl. rewrite ARG. reflexivity.
    eapply star_left.
    eapply exec_Iop; [reflexivity|]. simpl. rewrite Regmap.gss. reflexivity.
    eapply star_left.
    eapply exec_Iop; [reflexivity|]. simpl. rewrite Regmap.gso by discriminate.
    rewrite ! Regmap.gss. reflexivity.
    eapply star_left.
    eapply exec_Iop; [reflexivity|]. simpl. rewrite Regmap.gss. reflexivity.
    eapply star_left.
    eapply exec_Iop; [reflexivity|]. simpl. rewrite Regmap.gss. reflexivity.
    eapply star_left.
    eapply exec_Iop; [reflexivity|]. reflexivity.
    eapply star_left.
    eapply exec_Iop; [reflexivity|]. simpl. rewrite Regmap.gso by discriminate.
    rewrite ! Regmap.gss. reflexivity.
    apply star_refl.
    all: reflexivity.
  - rewrite Regmap.gss. simpl. change (Vint (Int.add (Int.add (Int64.loword (Int64.shru' (Int64.mul (Int64.repr (Int.unsigned n)) (Int64.add (Int64.repr (Int.unsigned n)) Int64.one)) Int.one)) (base_value c)) Int.zero) = Vint (Int.add (Int.repr (triangle (Int.unsigned n))) (base_value c))). rewrite wide_triangle, Int.add_zero. reflexivity.
Qed.

Lemma fast_function_exec:
  forall ge c s sp m n,
  exists rs',
  plus RTL.step ge
    (State s (fast_function c) sp (fn_entrypoint (fast_function c))
      (init_regs (Vint n :: nil) (fn_params (fast_function c))) m) E0
    (State s (fast_function c) sp 9 rs' m) /\
    rs'#(8%positive) = Vint (answer c n).
Proof.
  intros. destruct (signed_test c) eqn:MODE.
  - assert (ENTRY: fn_entrypoint (fast_function c) = 1%positive) by (simpl; rewrite MODE; reflexivity).
    rewrite ENTRY. destruct (is_base c n) eqn:BASE.
    + eexists; split.
      eapply plus_left. eapply exec_Icond with (b := true); [reflexivity| |reflexivity].
      change (eval_condition (condition c) (Vint n :: nil) m = Some true).
      rewrite eval_condition_base, BASE. reflexivity.
      apply star_one. eapply exec_Iop; reflexivity. reflexivity.
      rewrite Regmap.gss. unfold answer, sum_value. rewrite base_count_zero by auto.
      change (Vint (base_value c) = Vint (Int.add Int.zero (base_value c))). rewrite Int.add_zero_l.
      reflexivity.
    + destruct (fast_body_exec ge c s sp
        (init_regs (Vint n :: nil) (fn_params (fast_function c))) m n)
        as (rs' & STEPS & RESULT); [reflexivity|].
      exists rs'. split.
      eapply plus_left. eapply exec_Icond with (b := false); [reflexivity| |reflexivity].
      change (eval_condition (condition c) (Vint n :: nil) m = Some false).
      rewrite eval_condition_base, BASE. reflexivity.
      apply plus_star. exact STEPS. reflexivity.
      rewrite RESULT. unfold answer, sum_value.
      rewrite (proj1 (nonbase_count _ _ BASE)). reflexivity.
  - destruct (fast_body_exec ge c s sp
      (init_regs (Vint n :: nil) (fn_params (fast_function c))) m n)
      as (rs' & STEPS & RESULT); [reflexivity|].
    exists rs'. split.
    change (plus RTL.step ge (State s (fast_function c) sp
      (if signed_test c then 1%positive else 2%positive)
      (init_regs (Vint n :: nil) (fn_params (fast_function c))) m) E0 (State s (fast_function c) sp 9 rs' m)).
    rewrite MODE. exact STEPS.
    rewrite RESULT. unfold answer, sum_value, count. rewrite MODE. reflexivity.
Qed.
End TARGET_EXECUTION.

(** * Source loop *)

Section SOURCE_LOOP.
(** A decreasing invariant for the original summation loop. *)
Local Open Scope rtl.

Definition rank (c: shape) (n: int) (phase: Z) := Z.to_nat (4 * count c n + phase).

Inductive loop_state (c: shape): nat -> node -> regset -> int -> Prop :=
| loop_entry: forall rs n,
    rs#(parameter c) = Vint n ->
    loop_state c (rank c n 5) (entry_node c) rs (answer c n)
| loop_test: forall rs n a,
    rs#(parameter c) = Vint n -> rs#(accumulator_reg c) = Vint a ->
    loop_state c (rank c n 4) (test_node c) rs (Int.add a (answer c n))
| loop_decrement: forall rs n a,
    rs#(parameter c) = Vint n -> rs#(accumulator_reg c) = Vint a ->
    is_base c n = false ->
    loop_state c (rank c n 3) (decrement_node c) rs (Int.add a (answer c n))
| loop_add: forall rs n a,
    rs#(parameter c) = Vint n -> rs#(accumulator_reg c) = Vint a ->
    rs#(decrement_reg c) = Vint (Int.sub n Int.one) -> is_base c n = false ->
    loop_state c (rank c n 2) (add_node c) rs (Int.add a (answer c n))
| loop_move: forall rs n a,
    rs#(accumulator_reg c) = Vint (Int.add a n) ->
    rs#(decrement_reg c) = Vint (Int.sub n Int.one) -> is_base c n = false ->
    loop_state c (rank c n 1) (move_node c) rs (Int.add a (answer c n))
| loop_base: forall rs a,
    rs#(accumulator_reg c) = Vint a ->
    loop_state c 3%nat (base_node c) rs (Int.add a (base_value c))
| loop_finish: forall rs a,
    rs#(accumulator_reg c) = Vint a -> rs#(base_reg c) = Vint (base_value c) ->
    loop_state c 2%nat (finish_node c) rs (Int.add a (base_value c))
| loop_return: forall rs v,
    rs#(accumulator_reg c) = Vint v ->
    loop_state c 1%nat (return_node c) rs v.

Lemma rank_phase:
  forall c n x y, 0 <= x < y -> (rank c n x < rank c n y)%nat.
Proof. intros. unfold rank. apply Z2Nat.inj_lt; generalize (count_nonnegative c n); lia. Qed.
Lemma rank_decrement:
  forall c n, is_base c n = false ->
  (rank c (Int.sub n Int.one) 4 < rank c n 1)%nat.
Proof.
  intros. unfold rank. rewrite decrement_count by auto.
  destruct (nonbase_count _ _ H). apply Z2Nat.inj_lt; lia.
Qed.
Lemma answer_base:
  forall c n, is_base c n = true -> answer c n = base_value c.
Proof.
  intros. unfold answer, sum_value. rewrite base_count_zero by auto.
  change (Int.add Int.zero (base_value c) = base_value c). apply Int.add_zero_l.
Qed.
Lemma answer_step:
  forall c n a, is_base c n = false ->
  Int.add a (answer c n) = Int.add (Int.add a n) (answer c (Int.sub n Int.one)).
Proof.
  intros. unfold answer. rewrite sum_value_step by auto. repeat rewrite Int.add_assoc. reflexivity.
Qed.
Lemma decrement_op:
  forall n, Int.add n (Int.repr (-1)) = Int.sub n Int.one.
Proof. intros. rewrite Int.sub_add_opp. reflexivity. Qed.

Section LOOP.
Variables (ge: genv) (f: function) (c: shape).
Hypothesis SPEC: loop_spec f c.

Lemma loop_step:
  forall k pc rs v s stk m t S2,
  loop_state c k pc rs v ->
  step ge (State s f (Vptr stk Ptrofs.zero) pc rs m) t S2 ->
  (exists k' pc' rs', t = E0 /\
     S2 = State s f (Vptr stk Ptrofs.zero) pc' rs' m /\
     (k' < k)%nat /\ loop_state c k' pc' rs' v) \/
  (exists m', t = E0 /\ S2 = Returnstate s (Vint v) m' /\
     Mem.free m stk 0 0 = Some m').
Proof.
  intros k pc rs v s stk m t S2 LOOP STEP.
  destruct (register_inequalities _ _ SPEC) as (PA & PD & PB & AD & AB & DB).
  assert (CODE: forall pc i, In (pc,i) (instructions c) -> (fn_code f)!pc = Some i)
    by (apply spec_code; exact SPEC).
  destruct LOOP as [rs n ARG | rs n a ARG ACC | rs n a ARG ACC NB |
    rs n a ARG ACC DEC NB | rs n a ACC DEC NB | rs a ACC | rs a ACC BASE | rs v ACC].
  - assert (C: (fn_code f)!(entry_node c) = Some (Iop (Ointconst Int.zero) nil (accumulator_reg c) (test_node c)))
      by (apply CODE; unfold instructions; simpl; tauto).
    inv STEP; try congruence;
      match goal with H: (fn_code f)!(entry_node c) = Some _ |- _ => rewrite C in H; inv H end.
    match goal with E: eval_operation _ _ _ _ _ = _ |- _ => rename E into EVAL end.
    cbn [List.map] in EVAL. simpl in EVAL. inv EVAL. left.
    exists (rank c n 4), (test_node c), (rs#(accumulator_reg c) <- (Vint Int.zero)).
    repeat split; auto. apply rank_phase; lia.
    rewrite <- (Int.add_zero_l (answer c n)). constructor.
    rewrite Regmap.gso; auto. apply Regmap.gss.
  - assert (C: (fn_code f)!(test_node c) = Some
      (guard_instruction (reverse_test c) (condition c) (parameter c :: nil) (base_node c) (decrement_node c)))
      by (apply CODE; unfold instructions; simpl; tauto).
    assert (EVAL: eval_condition (condition c) (rs##(parameter c :: nil)) m = Some (is_base c n)).
    { cbn [List.map]. rewrite ARG, eval_condition_base. reflexivity. }
    destruct (guard_step _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ C EVAL STEP) as [TRACE EQ]. subst t S2.
    destruct (is_base c n) eqn:BASE.
    + left. rewrite answer_base by auto.
      exists 3%nat, (base_node c), rs. repeat split; auto.
      unfold rank. rewrite base_count_zero by auto. simpl. lia.
      constructor; auto.
    + left. exists (rank c n 3), (decrement_node c), rs.
      repeat split; auto. apply rank_phase; lia. constructor; auto.
  - assert (C: (fn_code f)!(decrement_node c) = Some (Iop (Olea (Aindexed (-1))) (parameter c :: nil) (decrement_reg c) (add_node c)))
      by (apply CODE; unfold instructions; simpl; tauto).
    inv STEP; try congruence;
      match goal with H: (fn_code f)!(decrement_node c) = Some _ |- _ => rewrite C in H; inv H end.
    match goal with E: eval_operation _ _ _ _ _ = _ |- _ => rename E into EVAL end.
    cbn [List.map] in EVAL. rewrite ARG in EVAL. simpl in EVAL. rewrite decrement_op in EVAL. inv EVAL.
    left. exists (rank c n 2); eexists; eexists. repeat split; auto.
    apply rank_phase; lia.
    econstructor; eauto; rewrite ?Regmap.gss, ?Regmap.gso; auto.
  - assert (C: (fn_code f)!(add_node c) = Some (Iop int_add_operation (add_args (add_reversed c) (accumulator_reg c) (parameter c)) (accumulator_reg c) (move_node c)))
      by (apply CODE; unfold instructions; simpl; tauto).
    inv STEP; try congruence;
      match goal with H: (fn_code f)!(add_node c) = Some _ |- _ => rewrite C in H; inv H end.
    match goal with E: eval_operation _ _ _ _ _ = _ |- _ => rename E into EVAL end.
    rewrite (eval_add_args _ _ _ _ _ _ _ _ _ ACC ARG) in EVAL. inv EVAL.
    left. exists (rank c n 1); eexists; eexists. repeat split; auto.
    apply rank_phase; lia.
    econstructor; eauto; rewrite ?Regmap.gss, ?Regmap.gso; auto.
  - assert (C: (fn_code f)!(move_node c) = Some (Iop Omove (decrement_reg c :: nil) (parameter c) (test_node c)))
      by (apply CODE; unfold instructions; simpl; tauto).
    inv STEP; try congruence;
      match goal with H: (fn_code f)!(move_node c) = Some _ |- _ => rewrite C in H; inv H end.
    match goal with E: eval_operation _ _ _ _ _ = _ |- _ => rename E into EVAL end.
    cbn [List.map] in EVAL. rewrite DEC in EVAL. simpl in EVAL. inv EVAL.
    left. rewrite answer_step by auto.
    exists (rank c (Int.sub n Int.one) 4), (test_node c),
      (rs#(parameter c) <- (Vint (Int.sub n Int.one))).
    repeat split; auto. apply rank_decrement; auto.
    constructor. apply Regmap.gss. rewrite Regmap.gso; congruence.
  - assert (C: (fn_code f)!(base_node c) = Some (Iop (Ointconst (base_value c)) nil (base_reg c) (finish_node c)))
      by (apply CODE; unfold instructions; simpl; tauto).
    inv STEP; try congruence;
      match goal with H: (fn_code f)!(base_node c) = Some _ |- _ => rewrite C in H; inv H end.
    match goal with E: eval_operation _ _ _ _ _ = _ |- _ => rename E into EVAL end.
    cbn [List.map] in EVAL. simpl in EVAL. inv EVAL. left.
    exists 2%nat, (finish_node c), (rs#(base_reg c) <- (Vint (base_value c))).
    repeat split; auto. constructor. rewrite Regmap.gso; auto. apply Regmap.gss.
  - assert (C: (fn_code f)!(finish_node c) = Some (Iop int_add_operation (add_args (finish_reversed c) (accumulator_reg c) (base_reg c)) (accumulator_reg c) (return_node c)))
      by (apply CODE; unfold instructions; simpl; tauto).
    inv STEP; try congruence;
      match goal with H: (fn_code f)!(finish_node c) = Some _ |- _ => rewrite C in H; inv H end.
    match goal with E: eval_operation _ _ _ _ _ = _ |- _ => rename E into EVAL end.
    rewrite (eval_add_args _ _ _ _ _ _ _ _ _ ACC BASE) in EVAL. inv EVAL.
    left. exists 1%nat, (return_node c), (rs#(accumulator_reg c) <- (Vint (Int.add a (base_value c)))).
    repeat split; auto. constructor. apply Regmap.gss.
  - assert (C: (fn_code f)!(return_node c) = Some (Ireturn (Some (accumulator_reg c))))
      by (apply CODE; unfold instructions; simpl; tauto).
    inv STEP; try congruence;
      match goal with H: (fn_code f)!(return_node c) = Some _ |- _ => rewrite C in H; inv H end.
    right. exists m'. simpl. rewrite ACC. repeat split; auto.
    match goal with F: Mem.free _ _ _ _ = _ |- _ => rewrite (spec_stack _ _ SPEC) in F; exact F end.
Qed.
End LOOP.
End SOURCE_LOOP.

(** * Program simulation *)

Section PROGRAM_SIMULATION.
(** Whole-program forward simulation.  Source loop steps stutter against a
    computed target result; [rank] rules out infinite silent stuttering. *)
Local Open Scope rtl.

Definition match_prog (p tp: program) :=
  match_program (fun ctx f tf => tf = SumClosed.Basic.transf_fundef f) eq p tp.
Lemma transf_program_match:
  forall p, match_prog p (SumClosed.Basic.transf_program p).
Proof. intros. eapply match_transform_program; eauto. Qed.

Inductive match_states: nat -> state -> state -> Prop :=
| match_plain: forall s f sp pc rs m,
    match_states O (State s f sp pc rs m) (State s f sp pc rs m)
| match_call: forall s fd args m,
    match_states O (Callstate s fd args m) (Callstate s (SumClosed.Basic.transf_fundef fd) args m)
| match_return: forall s v m,
    match_states O (Returnstate s v m) (Returnstate s v m)
| match_loop: forall s f c stk pc rs m k v trs,
    recognize f = Some c -> loop_state c k pc rs v -> trs#(8%positive) = Vint v ->
    match_states k (State s f (Vptr stk Ptrofs.zero) pc rs m)
      (State s (fast_function c) (Vptr stk Ptrofs.zero) 9%positive trs m).

Section PRESERVATION.
Variables prog tprog: program.
Hypothesis TRANSL: match_prog prog tprog.
Let ge := Genv.globalenv prog.
Let tge := Genv.globalenv tprog.

Lemma functions_translated:
  forall v f, Genv.find_funct ge v = Some f ->
  Genv.find_funct tge v = Some (SumClosed.Basic.transf_fundef f).
Proof (Genv.find_funct_transf TRANSL).
Lemma function_ptr_translated:
  forall v f, Genv.find_funct_ptr ge v = Some f ->
  Genv.find_funct_ptr tge v = Some (SumClosed.Basic.transf_fundef f).
Proof (Genv.find_funct_ptr_transf TRANSL).
Lemma symbols_preserved:
  forall id, Genv.find_symbol tge id = Genv.find_symbol ge id.
Proof (Genv.find_symbol_transf TRANSL).
Lemma senv_preserved: Senv.equiv ge tge.
Proof (Genv.senv_transf TRANSL).
Lemma sig_preserved:
  forall f, funsig (SumClosed.Basic.transf_fundef f) = funsig f.
Proof. destruct f; simpl; auto. apply function_signature. Qed.
Lemma find_function_translated:
  forall ros rs fd, find_function ge ros rs = Some fd ->
  find_function tge ros rs = Some (SumClosed.Basic.transf_fundef fd).
Proof.
  unfold find_function; intros. destruct ros as [r|id].
  eapply functions_translated; eauto.
  rewrite symbols_preserved. destruct (Genv.find_symbol ge id); try congruence.
  eapply function_ptr_translated; eauto.
Qed.

Definition progress (S: state) (t: trace) (T: state): Prop :=
  exists k T', plus step tge T t T' /\ match_states k S T'.

Lemma plain_step:
  forall s f sp pc rs m t S,
  step ge (State s f sp pc rs m) t S ->
  progress S t (State s f sp pc rs m).
Proof.
  intros s f sp pc rs m t S STEP. inv STEP; unfold progress.
  - exists O. eexists; split. apply plus_one. eapply exec_Inop; eauto. constructor.
  - exists O. eexists; split. apply plus_one. eapply exec_Iop; eauto.
    match goal with E: eval_operation _ _ _ _ _ = _ |- _ => rewrite <- E end.
    apply eval_operation_preserved. exact symbols_preserved. constructor.
  - exists O. eexists; split. apply plus_one. eapply exec_Iload; eauto.
    match goal with E: eval_addressing _ _ _ _ = _ |- _ => rewrite <- E end.
    apply eval_addressing_preserved. exact symbols_preserved. constructor.
  - exists O. eexists; split. apply plus_one. eapply exec_Istore; eauto.
    match goal with E: eval_addressing _ _ _ _ = _ |- _ => rewrite <- E end.
    apply eval_addressing_preserved. exact symbols_preserved. constructor.
  - exists O. eexists; split. apply plus_one.
    eapply exec_Icall with (fd := SumClosed.Basic.transf_fundef fd); eauto using find_function_translated.
    rewrite sig_preserved; auto. constructor.
  - exists O. eexists; split. apply plus_one.
    eapply exec_Itailcall with (fd := SumClosed.Basic.transf_fundef fd); eauto using find_function_translated.
    rewrite sig_preserved; auto. constructor.
  - exists O. eexists; split. apply plus_one. eapply exec_Ibuiltin; eauto.
    eapply eval_builtin_args_preserved with (ge1 := ge); eauto. exact symbols_preserved.
    eapply external_call_symbols_preserved; eauto. apply senv_preserved. constructor.
  - exists O. eexists; split. apply plus_one. eapply exec_Icond; eauto. constructor.
  - exists O. eexists; split. apply plus_one. eapply exec_Ijumptable; eauto. constructor.
  - exists O. eexists; split. apply plus_one. eapply exec_Ireturn; eauto. constructor.

Qed.

Lemma unary_args:
  forall f c args, loop_spec f c -> Val.has_argtype_list args (sig_args (fn_sig f)) ->
  exists n, args = Vint n :: nil.
Proof.
  intros f c args SPEC ARGS. rewrite (spec_signature _ _ SPEC) in ARGS.
  inversion ARGS as [|v x vl xl TYPE REST]; subst.
  inv REST. destruct v; simpl in TYPE; try contradiction; eauto.
  rewrite (spec_bits _ _ SPEC) in TYPE. discriminate.
Qed.

Lemma call_step:
  forall s fd args m t S,
  step ge (Callstate s fd args m) t S ->
  progress S t (Callstate s (SumClosed.Basic.transf_fundef fd) args m).
Proof.
  intros s fd args m t S STEP. inv STEP.
  - match goal with A: Val.has_argtype_list _ _ |- _ => rename A into ARGS end.
    match goal with A: Mem.alloc _ _ _ = _ |- _ => rename A into ALLOC end.
    destruct (recognize f) as [c|] eqn:REC.
    + pose proof (recognize_sound _ _ REC) as SPEC.
      destruct (unary_args _ _ _ SPEC ARGS) as (n & EQ). subst args.
      destruct (fast_function_exec tge c s (Vptr stk Ptrofs.zero) m' n)
        as (trs & STEPS & RESULT).
      unfold progress. exists (rank c n 5).
      exists (State s (fast_function c) (Vptr stk Ptrofs.zero) 9%positive trs m'). split.
      * eapply plus_left.
        cbn [SumClosed.Basic.transf_fundef AST.transf_fundef].
        unfold SumClosed.Basic.transf_function. rewrite REC.
        eapply exec_function_internal.
        change (Val.has_argtype_list (Vint n :: nil) (sig_args unary_int_signature)). rewrite <- (spec_signature _ _ SPEC). exact ARGS.
        simpl. rewrite <- (spec_stack _ _ SPEC) at 2. exact ALLOC.
        apply plus_star. exact STEPS. reflexivity.
      * eapply match_loop; eauto. rewrite (spec_entry _ _ SPEC), (spec_parameters _ _ SPEC).
        constructor. simpl. apply Regmap.gss.
    + unfold progress. exists O. eexists; split.
      apply plus_one. cbn [SumClosed.Basic.transf_fundef AST.transf_fundef].
      unfold SumClosed.Basic.transf_function. rewrite REC. eapply exec_function_internal; eauto.
      constructor.
  - unfold progress. exists O. eexists; split. apply plus_one.
    eapply exec_function_external. eapply external_call_symbols_preserved; eauto. apply senv_preserved.
    constructor.
Qed.

Lemma step_simulation:
  forall S t S', step ge S t S' -> forall k T, match_states k S T ->
  exists k' T', (plus step tge T t T' \/ (star step tge T t T' /\ (k' < k)%nat)) /\
    match_states k' S' T'.
Proof.
  intros S t S' STEP k T MATCH. inv MATCH.
  - destruct (plain_step _ _ _ _ _ _ _ _ STEP) as (k' & T' & A & B).
    exists k', T'. auto.
  - destruct (call_step _ _ _ _ _ _ STEP) as (k' & T' & A & B).
    exists k', T'. auto.
  - inv STEP. exists O. eexists. split. left. apply plus_one. constructor. constructor.
  - destruct (loop_step ge f c (recognize_sound _ _ H) _ _ _ _ _ _ _ _ _ H0 STEP)
      as [(k' & pc' & rs' & TRACE & EQ & LESS & LOOP) | (m' & TRACE & EQ & FREE)]; subst.
    + exists k', (State s (fast_function c) (Vptr stk Ptrofs.zero) 9%positive trs m).
      split. right. split; auto. apply star_refl. eapply match_loop; eauto.
    + exists O, (Returnstate s (Vint v) m'). split.
      left. apply plus_one.
      replace (Vint v) with (regmap_optget (Some 8%positive) Vundef trs) by (simpl; auto).
      eapply exec_Ireturn; [reflexivity|exact FREE]. constructor.
Qed.

Lemma transf_initial_states:
  forall S, initial_state prog S -> exists k T, initial_state tprog T /\ match_states k S T.
Proof.
  intros S INIT. inv INIT. exists O. eexists; split.
  econstructor.
  eapply (Genv.init_mem_transf TRANSL); eauto.
  rewrite symbols_preserved. replace (prog_main tprog) with (prog_main prog). eauto.
  symmetry. eapply match_program_main; eauto.
  eapply function_ptr_translated; eauto.
  rewrite sig_preserved; eauto.
  constructor.
Qed.

Theorem transf_program_correct:
  forward_simulation (RTL.semantics prog) (RTL.semantics tprog).
Proof.
  apply Forward_simulation with lt match_states. constructor.
  - apply lt_wf.
  - exact transf_initial_states.
  - intros k S T r MATCH FINAL. inv FINAL. inv MATCH. constructor.
  - exact step_simulation.
  - apply senv_preserved.
Qed.
End PRESERVATION.
End PROGRAM_SIMULATION.


End BasicCorrect.

Module AffineCorrect.
Import SumClosed.Affine.
Local Open Scope rtl.

Lemma int_ring_theory:
  ring_theory Int.zero Int.one Int.add Int.mul Int.sub Int.neg eq.
Proof.
  constructor; intros.
  - apply Int.add_zero_l.
  - apply Int.add_commut.
  - symmetry; apply Int.add_assoc.
  - rewrite Int.mul_commut; apply Int.mul_one.
  - apply Int.mul_commut.
  - symmetry; apply Int.mul_assoc.
  - apply Int.mul_add_distr_l.
  - apply Int.sub_add_opp.
  - apply Int.add_neg_zero.
Qed.
Add Ring int32_ring: int_ring_theory.

Definition answer (n a: int) := Int.add a (Int.mul n (Int.add n Int.one)).
Definition is_base (n: int) := Int.eq n Int.zero.
Definition rank (n: int) (phase: Z) := Z.to_nat (6 * Int.unsigned n + phase).
Lemma answer_base: forall n a, is_base n = true -> answer n a = a.
Proof.
  intros n a H; apply Int.same_if_eq in H; subst; unfold answer; ring.
Qed.
Lemma answer_step:
  forall n a b, Int.add b (answer n a) =
    Int.add (Int.add b n) (answer (Int.sub n Int.one) (Int.add a n)).
Proof. intros; unfold answer; ring. Qed.
Lemma rank_phase: forall n x y, 0 <= x < y -> (rank n x < rank n y)%nat.
Proof.
  intros; unfold rank; apply Z2Nat.inj_lt; generalize (Int.unsigned_range n); lia.
Qed.
Lemma rank_decrement:
  forall n, is_base n = false -> (rank (Int.sub n Int.one) 7 < rank n 2)%nat.
Proof.
  intros n H. assert (POS: 0 < Int.unsigned n).
  { unfold is_base, Int.eq in H; rewrite Int.unsigned_zero in H.
    destruct (zeq (Int.unsigned n) 0); try discriminate.
    generalize (Int.unsigned_range n); lia. }
  unfold rank; rewrite BasicCorrect.decrement_unsigned by auto.
  apply Z2Nat.inj_lt; lia.
Qed.

Record loop_spec (f: function) (c: shape): Prop := {
  spec_bits: Archi.ptr64 = true;
  spec_signature: fn_sig f = signature;
  spec_stack: fn_stacksize f = 0;
  spec_parameters: fn_params f = parameter c :: initial_reg c :: nil;
  spec_entry: fn_entrypoint f = entry_node c;
  spec_registers: list_norepet (registers c);
  spec_nodes: list_norepet (nodes c);
  spec_code: forall pc i, In (pc,i) (instructions c) -> (fn_code f)!pc = Some i
}.

Theorem recognize_sound:
  forall f c, recognize f = Some c -> loop_spec f c.
Proof.
  intros f c REC. unfold recognize in REC.
  destruct (discover f) as [d|]; try discriminate.
  destruct (validate f d) eqn:VALID; inv REC.
  unfold validate in VALID.
  destruct Archi.ptr64 eqn:BITS; try discriminate.
  destruct (signature_eq (fn_sig f) signature); try discriminate.
  destruct (zeq (fn_stacksize f) 0); try discriminate.
  destruct (list_eq_dec peq (fn_params f) (parameter c :: initial_reg c :: nil)); try discriminate.
  destruct (peq (fn_entrypoint f) (entry_node c)); try discriminate.
  destruct (list_norepet_dec peq (registers c)); try discriminate.
  destruct (list_norepet_dec peq (nodes c)); try discriminate.
  constructor; auto. intros pc i IN.
  apply forallb_forall with (x := (pc,i)) in VALID; auto. simpl in VALID.
  destruct ((fn_code f)!pc) eqn:CODE; try discriminate.
  destruct (instruction_eq i0 i); congruence.
Qed.

Lemma function_signature:
  forall f, fn_sig (transf_function f) = fn_sig f.
Proof.
  intros. unfold transf_function. destruct (recognize f) as [c|] eqn:REC; auto.
  simpl. symmetry. eapply spec_signature. eapply recognize_sound; eauto.
Qed.

Lemma register_inequalities:
  forall f c, loop_spec f c ->
  parameter c <> initial_reg c /\ parameter c <> accumulator_reg c /\
  parameter c <> decrement_reg c /\ parameter c <> update_reg c /\
  initial_reg c <> accumulator_reg c /\ initial_reg c <> decrement_reg c /\
  initial_reg c <> update_reg c /\ accumulator_reg c <> decrement_reg c /\
  accumulator_reg c <> update_reg c /\ decrement_reg c <> update_reg c.
Proof.
  intros. pose proof (spec_registers _ _ H) as ND. unfold registers in ND.
  repeat match goal with H: list_norepet (_ :: _) |- _ => inv H end.
  simpl in *. intuition.
Qed.

Lemma fast_function_exec:
  forall ge s sp m n a,
  exists rs', plus RTL.step ge
    (State s fast_function sp 1%positive
      (init_regs (Vint n :: Vint a :: nil) (fn_params fast_function)) m) E0
    (State s fast_function sp 4%positive rs' m) /\
    rs'#(5%positive) = Vint (answer n a).
Proof.
  intros. eexists; split.
  - eapply plus_left.
    eapply exec_Iop; [reflexivity|]. reflexivity.
    eapply star_left.
    eapply exec_Iop; [reflexivity|]. reflexivity.
    eapply star_left.
    eapply exec_Iop; [reflexivity|]. reflexivity.
    apply star_refl. all: reflexivity.
  - rewrite Regmap.gss. simpl. unfold answer. rewrite Int.add_zero. reflexivity.
Qed.

Inductive loop_state (c: shape): nat -> node -> regset -> int -> Prop :=
| loop_entry: forall rs n a,
    rs#(parameter c) = Vint n -> rs#(initial_reg c) = Vint a ->
    loop_state c (rank n 8) (entry_node c) rs (answer n a)
| loop_test: forall rs n a b,
    rs#(parameter c) = Vint n -> rs#(initial_reg c) = Vint a ->
    rs#(accumulator_reg c) = Vint b ->
    loop_state c (rank n 7) (test_node c) rs (Int.add b (answer n a))
| loop_decrement: forall rs n a b,
    rs#(parameter c) = Vint n -> rs#(initial_reg c) = Vint a ->
    rs#(accumulator_reg c) = Vint b -> is_base n = false ->
    loop_state c (rank n 6) (decrement_node c) rs (Int.add b (answer n a))
| loop_update: forall rs n a b,
    rs#(parameter c) = Vint n -> rs#(initial_reg c) = Vint a ->
    rs#(accumulator_reg c) = Vint b ->
    rs#(decrement_reg c) = Vint (Int.sub n Int.one) -> is_base n = false ->
    loop_state c (rank n 5) (update_node c) rs (Int.add b (answer n a))
| loop_add: forall rs n a b,
    rs#(parameter c) = Vint n -> rs#(accumulator_reg c) = Vint b ->
    rs#(decrement_reg c) = Vint (Int.sub n Int.one) ->
    rs#(update_reg c) = Vint (Int.add a n) -> is_base n = false ->
    loop_state c (rank n 4) (add_node c) rs (Int.add b (answer n a))
| loop_move: forall rs n a b,
    rs#(accumulator_reg c) = Vint (Int.add b n) ->
    rs#(decrement_reg c) = Vint (Int.sub n Int.one) ->
    rs#(update_reg c) = Vint (Int.add a n) -> is_base n = false ->
    loop_state c (rank n 3) (move_node c) rs (Int.add b (answer n a))
| loop_assign: forall rs n a b,
    rs#(accumulator_reg c) = Vint (Int.add b n) ->
    rs#(parameter c) = Vint (Int.sub n Int.one) ->
    rs#(update_reg c) = Vint (Int.add a n) -> is_base n = false ->
    loop_state c (rank n 2) (assign_node c) rs (Int.add b (answer n a))
| loop_finish: forall rs a b,
    rs#(accumulator_reg c) = Vint b -> rs#(initial_reg c) = Vint a ->
    loop_state c 2%nat (finish_node c) rs (Int.add b a)
| loop_return: forall rs v,
    rs#(accumulator_reg c) = Vint v ->
    loop_state c 1%nat (return_node c) rs v.

Section LOOP.
Variables (ge: genv) (f: function) (c: shape).
Hypothesis SPEC: loop_spec f c.
Lemma loop_step:
  forall k pc rs v s stk m t S2,
  loop_state c k pc rs v ->
  step ge (State s f (Vptr stk Ptrofs.zero) pc rs m) t S2 ->
  (exists k' pc' rs', t = E0 /\
     S2 = State s f (Vptr stk Ptrofs.zero) pc' rs' m /\
     (k' < k)%nat /\ loop_state c k' pc' rs' v) \/
  (exists m', t = E0 /\ S2 = Returnstate s (Vint v) m' /\
     Mem.free m stk 0 0 = Some m').
Proof.
  intros k pc rs v s stk m t S2 LOOP STEP.
  destruct (register_inequalities _ _ SPEC) as (NA & NB & ND & NU & AB & AD & AU & BD & BU & DU).
  assert (CODE: forall pc i, In (pc,i) (instructions c) -> (fn_code f)!pc = Some i)
    by (apply spec_code; exact SPEC).
  destruct LOOP as [rs n a N A | rs n a b N A B | rs n a b N A B NZ |
    rs n a b N A B D NZ | rs n a b N B D U NZ | rs n a b B D U NZ |
    rs n a b B N U NZ | rs a b B A | rs v B].
  - assert (C: (fn_code f)!(entry_node c) = Some (Iop (Ointconst Int.zero) nil (accumulator_reg c) (test_node c)))
      by (apply CODE; unfold instructions; simpl; tauto).
    inv STEP; try congruence;
      match goal with H: (fn_code f)!(entry_node c) = Some _ |- _ => rewrite C in H; inv H end.
    match goal with E: eval_operation _ _ _ _ _ = _ |- _ => rename E into EVAL end.

    cbn [List.map] in EVAL. simpl in EVAL. inv EVAL. left.
    exists (rank n 7), (test_node c), (rs#(accumulator_reg c) <- (Vint Int.zero)).
    repeat split; auto. apply rank_phase; lia.
    rewrite <- (Int.add_zero_l (answer n a)). constructor;
      rewrite ?Regmap.gss, ?Regmap.gso; auto.
  - assert (C: (fn_code f)!(test_node c) = Some
      (guard_instruction (reverse_test c) (zero_condition (less_test c)) (parameter c :: nil) (finish_node c) (decrement_node c)))
      by (apply CODE; unfold instructions; simpl; tauto).
    assert (EVAL: eval_condition (zero_condition (less_test c)) (rs##(parameter c :: nil)) m = Some (is_base n)).
    { cbn [List.map]. rewrite N, eval_zero_condition. reflexivity. }
    destruct (guard_step _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ C EVAL STEP) as [TRACE EQ]. subst t S2.
    destruct (is_base n) eqn:BASE.
    + left. rewrite answer_base by auto.
      exists 2%nat, (finish_node c), rs. repeat split; auto.
      unfold rank. generalize (Int.unsigned_range n); lia. constructor; auto.
    + left. exists (rank n 6), (decrement_node c), rs.
      repeat split; auto. apply rank_phase; lia. constructor; auto.
  - assert (C: (fn_code f)!(decrement_node c) = Some (Iop (Olea (Aindexed (-1))) (parameter c :: nil) (decrement_reg c) (update_node c)))
      by (apply CODE; unfold instructions; simpl; tauto).
    inv STEP; try congruence;
      match goal with H: (fn_code f)!(decrement_node c) = Some _ |- _ => rewrite C in H; inv H end.
    match goal with E: eval_operation _ _ _ _ _ = _ |- _ => rename E into EVAL end.

    cbn [List.map] in EVAL. rewrite N in EVAL. simpl in EVAL.
    rewrite BasicCorrect.decrement_op in EVAL. inv EVAL.
    left. exists (rank n 5); eexists; eexists. repeat split; auto.
    apply rank_phase; lia. econstructor; eauto;
      rewrite ?Regmap.gss, ?Regmap.gso; auto.
  - assert (C: (fn_code f)!(update_node c) = Some (Iop int_add_operation (add_args (update_reversed c) (initial_reg c) (parameter c)) (update_reg c) (add_node c)))
      by (apply CODE; unfold instructions; simpl; tauto).
    inv STEP; try congruence;
      match goal with H: (fn_code f)!(update_node c) = Some _ |- _ => rewrite C in H; inv H end.
    match goal with E: eval_operation _ _ _ _ _ = _ |- _ => rename E into EVAL end.

    rewrite (eval_add_args _ _ _ _ _ _ _ _ _ A N) in EVAL. inv EVAL.
    left. exists (rank n 4); eexists; eexists. repeat split; auto.
    apply rank_phase; lia. econstructor; eauto;
      rewrite ?Regmap.gss, ?Regmap.gso; auto.
  - assert (C: (fn_code f)!(add_node c) = Some (Iop int_add_operation (add_args (add_reversed c) (accumulator_reg c) (parameter c)) (accumulator_reg c) (move_node c)))
      by (apply CODE; unfold instructions; simpl; tauto).
    inv STEP; try congruence;
      match goal with H: (fn_code f)!(add_node c) = Some _ |- _ => rewrite C in H; inv H end.
    match goal with E: eval_operation _ _ _ _ _ = _ |- _ => rename E into EVAL end.

    rewrite (eval_add_args _ _ _ _ _ _ _ _ _ B N) in EVAL. inv EVAL.
    left. exists (rank n 3); eexists; eexists. repeat split; auto.
    apply rank_phase; lia. econstructor; eauto;
      rewrite ?Regmap.gss, ?Regmap.gso; auto.
  - assert (C: (fn_code f)!(move_node c) = Some (Iop Omove (decrement_reg c :: nil) (parameter c) (assign_node c)))
      by (apply CODE; unfold instructions; simpl; tauto).
    inv STEP; try congruence;
      match goal with H: (fn_code f)!(move_node c) = Some _ |- _ => rewrite C in H; inv H end.
    match goal with E: eval_operation _ _ _ _ _ = _ |- _ => rename E into EVAL end.

    cbn [List.map] in EVAL. rewrite D in EVAL. simpl in EVAL. inv EVAL.
    left. exists (rank n 2); eexists; eexists. repeat split; auto.
    apply rank_phase; lia. econstructor; eauto;
      rewrite ?Regmap.gss, ?Regmap.gso; auto.
  - assert (C: (fn_code f)!(assign_node c) = Some (Iop Omove (update_reg c :: nil) (initial_reg c) (test_node c)))
      by (apply CODE; unfold instructions; simpl; tauto).
    inv STEP; try congruence;
      match goal with H: (fn_code f)!(assign_node c) = Some _ |- _ => rewrite C in H; inv H end.
    match goal with E: eval_operation _ _ _ _ _ = _ |- _ => rename E into EVAL end.

    cbn [List.map] in EVAL. rewrite U in EVAL. simpl in EVAL. inv EVAL.
    left. rewrite answer_step.
    exists (rank (Int.sub n Int.one) 7), (test_node c),
      (rs#(initial_reg c) <- (Vint (Int.add a n))).
    repeat split; auto. apply rank_decrement; auto.
    constructor; rewrite ?Regmap.gss, ?Regmap.gso; auto.
  - assert (C: (fn_code f)!(finish_node c) = Some (Iop int_add_operation (add_args (finish_reversed c) (accumulator_reg c) (initial_reg c)) (accumulator_reg c) (return_node c)))
      by (apply CODE; unfold instructions; simpl; tauto).
    inv STEP; try congruence;
      match goal with H: (fn_code f)!(finish_node c) = Some _ |- _ => rewrite C in H; inv H end.
    match goal with E: eval_operation _ _ _ _ _ = _ |- _ => rename E into EVAL end.

    rewrite (eval_add_args _ _ _ _ _ _ _ _ _ B A) in EVAL. inv EVAL.
    left. exists 1%nat, (return_node c), (rs#(accumulator_reg c) <- (Vint (Int.add b a))).
    repeat split; auto. constructor; apply Regmap.gss.
  - assert (C: (fn_code f)!(return_node c) = Some (Ireturn (Some (accumulator_reg c))))
      by (apply CODE; unfold instructions; simpl; tauto).
    inv STEP; try congruence;
      match goal with H: (fn_code f)!(return_node c) = Some _ |- _ => rewrite C in H; inv H end.

    right. exists m'. simpl. rewrite B. repeat split; auto.
    match goal with F: Mem.free _ _ _ _ = _ |- _ => rewrite (spec_stack _ _ SPEC) in F; exact F end.
Qed.
End LOOP.
Section PROGRAM_SIMULATION.
(** Whole-program forward simulation.  Source loop steps stutter against a
    computed target result; [rank] rules out infinite silent stuttering. *)
Local Open Scope rtl.

Definition match_prog (p tp: program) :=
  match_program (fun ctx f tf => tf = SumClosed.Affine.transf_fundef f) eq p tp.
Lemma transf_program_match:
  forall p, match_prog p (SumClosed.Affine.transf_program p).
Proof. intros. eapply match_transform_program; eauto. Qed.

Inductive match_states: nat -> state -> state -> Prop :=
| match_plain: forall s f sp pc rs m,
    match_states O (State s f sp pc rs m) (State s f sp pc rs m)
| match_call: forall s fd args m,
    match_states O (Callstate s fd args m) (Callstate s (SumClosed.Affine.transf_fundef fd) args m)
| match_return: forall s v m,
    match_states O (Returnstate s v m) (Returnstate s v m)
| match_loop: forall s f c stk pc rs m k v trs,
    recognize f = Some c -> loop_state c k pc rs v -> trs#(5%positive) = Vint v ->
    match_states k (State s f (Vptr stk Ptrofs.zero) pc rs m)
      (State s (fast_function) (Vptr stk Ptrofs.zero) 4%positive trs m).

Section PRESERVATION.
Variables prog tprog: program.
Hypothesis TRANSL: match_prog prog tprog.
Let ge := Genv.globalenv prog.
Let tge := Genv.globalenv tprog.

Lemma functions_translated:
  forall v f, Genv.find_funct ge v = Some f ->
  Genv.find_funct tge v = Some (SumClosed.Affine.transf_fundef f).
Proof (Genv.find_funct_transf TRANSL).
Lemma function_ptr_translated:
  forall v f, Genv.find_funct_ptr ge v = Some f ->
  Genv.find_funct_ptr tge v = Some (SumClosed.Affine.transf_fundef f).
Proof (Genv.find_funct_ptr_transf TRANSL).
Lemma symbols_preserved:
  forall id, Genv.find_symbol tge id = Genv.find_symbol ge id.
Proof (Genv.find_symbol_transf TRANSL).
Lemma senv_preserved: Senv.equiv ge tge.
Proof (Genv.senv_transf TRANSL).
Lemma sig_preserved:
  forall f, funsig (SumClosed.Affine.transf_fundef f) = funsig f.
Proof. destruct f; simpl; auto. apply function_signature. Qed.
Lemma find_function_translated:
  forall ros rs fd, find_function ge ros rs = Some fd ->
  find_function tge ros rs = Some (SumClosed.Affine.transf_fundef fd).
Proof.
  unfold find_function; intros. destruct ros as [r|id].
  eapply functions_translated; eauto.
  rewrite symbols_preserved. destruct (Genv.find_symbol ge id); try congruence.
  eapply function_ptr_translated; eauto.
Qed.

Definition progress (S: state) (t: trace) (T: state): Prop :=
  exists k T', plus step tge T t T' /\ match_states k S T'.

Lemma plain_step:
  forall s f sp pc rs m t S,
  step ge (State s f sp pc rs m) t S ->
  progress S t (State s f sp pc rs m).
Proof.
  intros s f sp pc rs m t S STEP. inv STEP; unfold progress.
  - exists O. eexists; split. apply plus_one. eapply exec_Inop; eauto. constructor.
  - exists O. eexists; split. apply plus_one. eapply exec_Iop; eauto.
    match goal with E: eval_operation _ _ _ _ _ = _ |- _ => rewrite <- E end.
    apply eval_operation_preserved. exact symbols_preserved. constructor.
  - exists O. eexists; split. apply plus_one. eapply exec_Iload; eauto.
    match goal with E: eval_addressing _ _ _ _ = _ |- _ => rewrite <- E end.
    apply eval_addressing_preserved. exact symbols_preserved. constructor.
  - exists O. eexists; split. apply plus_one. eapply exec_Istore; eauto.
    match goal with E: eval_addressing _ _ _ _ = _ |- _ => rewrite <- E end.
    apply eval_addressing_preserved. exact symbols_preserved. constructor.
  - exists O. eexists; split. apply plus_one.
    eapply exec_Icall with (fd := SumClosed.Affine.transf_fundef fd); eauto using find_function_translated.
    rewrite sig_preserved; auto. constructor.
  - exists O. eexists; split. apply plus_one.
    eapply exec_Itailcall with (fd := SumClosed.Affine.transf_fundef fd); eauto using find_function_translated.
    rewrite sig_preserved; auto. constructor.
  - exists O. eexists; split. apply plus_one. eapply exec_Ibuiltin; eauto.
    eapply eval_builtin_args_preserved with (ge1 := ge); eauto. exact symbols_preserved.
    eapply external_call_symbols_preserved; eauto. apply senv_preserved. constructor.
  - exists O. eexists; split. apply plus_one. eapply exec_Icond; eauto. constructor.
  - exists O. eexists; split. apply plus_one. eapply exec_Ijumptable; eauto. constructor.
  - exists O. eexists; split. apply plus_one. eapply exec_Ireturn; eauto. constructor.

Qed.

Lemma binary_args:
  forall f c args, loop_spec f c -> Val.has_argtype_list args (sig_args (fn_sig f)) ->
  exists n a, args = Vint n :: Vint a :: nil.
Proof.
  intros f c args SPEC ARGS. rewrite (spec_signature _ _ SPEC) in ARGS.
  inversion ARGS as [|v x vl xl TYPE REST]; subst.
  inversion REST as [|w y wl yl TYPE2 REST2]; subst. inv REST2.
  destruct v; simpl in TYPE; try contradiction;
    try (rewrite (spec_bits _ _ SPEC) in TYPE; discriminate).
  destruct w; simpl in TYPE2; try contradiction;
    try (rewrite (spec_bits _ _ SPEC) in TYPE2; discriminate); eauto.
Qed.

Lemma call_step:
  forall s fd args m t S,
  step ge (Callstate s fd args m) t S ->
  progress S t (Callstate s (SumClosed.Affine.transf_fundef fd) args m).
Proof.
  intros s fd args m t S STEP. inv STEP.
  - match goal with A: Val.has_argtype_list _ _ |- _ => rename A into ARGS end.
    match goal with A: Mem.alloc _ _ _ = _ |- _ => rename A into ALLOC end.
    destruct (recognize f) as [c|] eqn:REC.
    + pose proof (recognize_sound _ _ REC) as SPEC.
      destruct (binary_args _ _ _ SPEC ARGS) as (n & a & EQ). subst args.
      destruct (fast_function_exec tge s (Vptr stk Ptrofs.zero) m' n a)
        as (trs & STEPS & RESULT).
      unfold progress. exists (rank n 8).
      exists (State s (fast_function) (Vptr stk Ptrofs.zero) 4%positive trs m'). split.
      * eapply plus_left.
        cbn [SumClosed.Affine.transf_fundef AST.transf_fundef].
        unfold SumClosed.Affine.transf_function. rewrite REC.
        eapply exec_function_internal.
        change (Val.has_argtype_list (Vint n :: Vint a :: nil) (sig_args signature)). rewrite <- (spec_signature _ _ SPEC). exact ARGS.
        simpl. rewrite <- (spec_stack _ _ SPEC) at 2. exact ALLOC.
        apply plus_star. exact STEPS. reflexivity.
      * eapply match_loop; eauto. rewrite (spec_entry _ _ SPEC), (spec_parameters _ _ SPEC).
        constructor.
        { simpl. apply Regmap.gss. }
        { simpl. rewrite Regmap.gso. apply Regmap.gss.
          destruct (register_inequalities _ _ SPEC); congruence. }
    + unfold progress. exists O. eexists; split.
      apply plus_one. cbn [SumClosed.Affine.transf_fundef AST.transf_fundef].
      unfold SumClosed.Affine.transf_function. rewrite REC. eapply exec_function_internal; eauto.
      constructor.
  - unfold progress. exists O. eexists; split. apply plus_one.
    eapply exec_function_external. eapply external_call_symbols_preserved; eauto. apply senv_preserved.
    constructor.
Qed.

Lemma step_simulation:
  forall S t S', step ge S t S' -> forall k T, match_states k S T ->
  exists k' T', (plus step tge T t T' \/ (star step tge T t T' /\ (k' < k)%nat)) /\
    match_states k' S' T'.
Proof.
  intros S t S' STEP k T MATCH. inv MATCH.
  - destruct (plain_step _ _ _ _ _ _ _ _ STEP) as (k' & T' & A & B).
    exists k', T'. auto.
  - destruct (call_step _ _ _ _ _ _ STEP) as (k' & T' & A & B).
    exists k', T'. auto.
  - inv STEP. exists O. eexists. split. left. apply plus_one. constructor. constructor.
  - destruct (loop_step ge f c (recognize_sound _ _ H) _ _ _ _ _ _ _ _ _ H0 STEP)
      as [(k' & pc' & rs' & TRACE & EQ & LESS & LOOP) | (m' & TRACE & EQ & FREE)]; subst.
    + exists k', (State s (fast_function) (Vptr stk Ptrofs.zero) 4%positive trs m).
      split. right. split; auto. apply star_refl. eapply match_loop; eauto.
    + exists O, (Returnstate s (Vint v) m'). split.
      left. apply plus_one.
      replace (Vint v) with (regmap_optget (Some 5%positive) Vundef trs) by (simpl; auto).
      eapply exec_Ireturn; [reflexivity|exact FREE]. constructor.
Qed.

Lemma transf_initial_states:
  forall S, initial_state prog S -> exists k T, initial_state tprog T /\ match_states k S T.
Proof.
  intros S INIT. inv INIT. exists O. eexists; split.
  econstructor.
  eapply (Genv.init_mem_transf TRANSL); eauto.
  rewrite symbols_preserved. replace (prog_main tprog) with (prog_main prog). eauto.
  symmetry. eapply match_program_main; eauto.
  eapply function_ptr_translated; eauto.
  rewrite sig_preserved; eauto.
  constructor.
Qed.

Theorem transf_program_correct:
  forward_simulation (RTL.semantics prog) (RTL.semantics tprog).
Proof.
  apply Forward_simulation with lt match_states. constructor.
  - apply lt_wf.
  - exact transf_initial_states.
  - intros k S T r MATCH FINAL. inv FINAL. inv MATCH. constructor.
  - exact step_simulation.
  - apply senv_preserved.
Qed.
End PRESERVATION.
End PROGRAM_SIMULATION.


End AffineCorrect.

Module SquareCorrect.
Import SumClosed.Square.
Local Open Scope rtl.

(** * Arithmetic *)

Add Ring square_int32_ring: AffineCorrect.int_ring_theory.
Section ARITHMETIC.
(** Machine-integer arithmetic for the summation closed form. *)

Definition triangle (n: Z) := n * (n + 1) / 2.
Definition count (c: shape) (n: int) :=
  if signed_test c then Z.max 0 (Int.signed n) else Int.unsigned n.
Definition square_sum (n: Z) :=
  Int.mul (Int.mul (Int.repr (triangle n))
    (Int.add (Int.mul (Int.repr n) (Int.repr 2)) Int.one)) (Int.repr 2863311531).
Definition sum_value (c: shape) (n: int) := square_sum (count c n).
Definition answer (c: shape) (n: int) := Int.add (sum_value c n) (base_value c).
Definition is_base (c: shape) (n: int) :=
  if signed_test c then negb (Int.lt Int.zero n) else Int.eq n Int.zero.

Lemma triangle_step:
  forall n, triangle n = triangle (n - 1) + n.
Proof.
  intros. unfold triangle.
  replace (n * (n + 1)) with ((n - 1) * (n - 1 + 1) + n * 2) by ring.
  rewrite Z.div_add by lia. reflexivity.
Qed.

Lemma count_nonnegative:
  forall c n, 0 <= count c n.
Proof.
  intros. unfold count. destruct (signed_test c).
  apply Z.le_max_l. generalize (Int.unsigned_range n); lia.
Qed.

Lemma int_add_repr:
  forall a b, Int.add (Int.repr a) (Int.repr b) = Int.repr (a + b).
Proof.
  intros. unfold Int.add. apply Int.eqm_samerepr.
  apply Int.eqm_add; auto with ints.
Qed.

Lemma int64_add_repr:
  forall a b, Int64.add (Int64.repr a) (Int64.repr b) = Int64.repr (a + b).
Proof.
  intros. unfold Int64.add. apply Int64.eqm_samerepr.
  apply Int64.eqm_add; auto with ints.
Qed.

Lemma int64_mul_repr:
  forall a b, Int64.mul (Int64.repr a) (Int64.repr b) = Int64.repr (a * b).
Proof.
  intros. unfold Int64.mul. apply Int64.eqm_samerepr.
  apply Int64.eqm_mult; auto with ints.
Qed.

Lemma wide_triangle:
  forall n,
  Int64.loword
    (Int64.shru'
      (Int64.mul (Int64.repr (Int.unsigned n))
        (Int64.add (Int64.repr (Int.unsigned n)) Int64.one)) Int.one) =
  Int.repr (triangle (Int.unsigned n)).
Proof.
  intros. unfold Int64.one. rewrite int64_add_repr, int64_mul_repr.
  assert (RANGE: 0 <= Int.unsigned n <= 4294967295).
  { generalize (Int.unsigned_range n). change Int.modulus with 4294967296. lia. }
  assert (PRODUCT: 0 <= Int.unsigned n * (Int.unsigned n + 1) <= Int64.max_unsigned).
  { change Int64.max_unsigned with 18446744073709551615. nia. }
  unfold Int64.shru'. rewrite Int64.unsigned_repr by exact PRODUCT.
  rewrite Int.unsigned_one, Z.shiftr_div_pow2 by lia.
  change (2 ^ 1) with 2. unfold Int64.loword.
  rewrite Int64.unsigned_repr.
  reflexivity.
  split. apply Z.div_pos; lia.
  apply Z.div_le_upper_bound; lia.
Qed.

Lemma base_count_zero:
  forall c n, is_base c n = true -> count c n = 0.
Proof.
  intros c n. unfold is_base, count. destruct (signed_test c).
  - unfold Int.lt. rewrite Int.signed_zero.
    destruct (zlt 0 (Int.signed n)); simpl; intros; try discriminate. lia.
  - intro EQ. apply Int.same_if_eq in EQ. subst n. apply Int.unsigned_zero.
Qed.

Lemma nonbase_count:
  forall c n, is_base c n = false -> count c n = Int.unsigned n /\ 0 < count c n.
Proof.
  intros c n. unfold is_base, count. destruct (signed_test c).
  - unfold Int.lt. rewrite Int.signed_zero.
    destruct (zlt 0 (Int.signed n)); simpl; intros; try discriminate.
    assert (S: Int.signed n = Int.unsigned n).
    { unfold Int.signed in *. destruct (zlt (Int.unsigned n) Int.half_modulus); auto.
      generalize (Int.unsigned_range n). change Int.modulus with 4294967296 in *.
      change Int.half_modulus with 2147483648 in *. lia. }
    rewrite Z.max_r by lia. auto.
  - unfold Int.eq. rewrite Int.unsigned_zero.
    destruct (zeq (Int.unsigned n) 0); intros; try discriminate.
    generalize (Int.unsigned_range n); split; auto; lia.
Qed.

Lemma decrement_unsigned:
  forall n, 0 < Int.unsigned n ->
  Int.unsigned (Int.sub n Int.one) = Int.unsigned n - 1.
Proof.
  intros. unfold Int.sub. rewrite Int.unsigned_one, Int.unsigned_repr; auto.
  generalize (Int.unsigned_range n). unfold Int.max_unsigned. lia.
Qed.

Lemma decrement_count:
  forall c n, is_base c n = false ->
  count c (Int.sub n Int.one) = count c n - 1.
Proof.
  intros c n NB. destruct (nonbase_count _ _ NB) as [UN POS].
  assert (DEC: Int.unsigned (Int.sub n Int.one) = Int.unsigned n - 1).
  { apply decrement_unsigned. lia. }
  unfold count in *. destruct (signed_test c) eqn:MODE; auto.
  assert (SIGNED: 0 < Int.signed n).
  { unfold is_base, Int.lt in NB. rewrite MODE, Int.signed_zero in NB.
    destruct (zlt 0 (Int.signed n)); simpl in NB; congruence. }
  rewrite Z.max_r in UN by lia.
  assert (BOUND: Int.min_signed <= Int.unsigned n - 1 <= Int.max_signed).
  { generalize (Int.signed_range n). change Int.min_signed with (-2147483648). lia. }
  unfold Int.sub. rewrite Int.unsigned_one, Int.signed_repr by exact BOUND.
  rewrite Z.max_r by lia. lia.
Qed.

Lemma int_add_repr_left:
  forall a n, Int.add (Int.repr a) n = Int.repr (a + Int.unsigned n).
Proof.
  intros. unfold Int.add. apply Int.eqm_samerepr.
  apply Int.eqm_add; auto with ints.
Qed.

Lemma triangle_twice:
  forall n, 2 * triangle n = n * (n + 1).
Proof.
  intros n. unfold triangle.
  pose proof (Z.div_mod n 2 ltac:(lia)) as D.
  pose proof (Z.mod_pos_bound n 2 ltac:(lia)) as R.
  assert (E: exists q, n * (n + 1) = q * 2).
  { destruct (Z.eq_dec (n mod 2) 0).
    - exists ((n / 2) * (n + 1)); nia.
    - assert (n mod 2 = 1) by lia. exists (n * (n / 2 + 1)); nia. }
  destruct E as [q E]. rewrite E, Z.div_mul by lia. ring.
Qed.
Lemma triangle_twice_int:
  forall n, Int.mul (Int.repr (triangle n)) (Int.repr 2) =
    Int.mul (Int.repr n) (Int.add (Int.repr n) Int.one).
Proof.
  intros. unfold Int.one. rewrite int_add_repr.
  assert (M: forall x y, Int.mul (Int.repr x) (Int.repr y) = Int.repr (x * y)).
  { intros. unfold Int.mul. apply Int.eqm_samerepr. apply Int.eqm_mult; auto with ints. }
  rewrite !M. f_equal. pose proof (triangle_twice n); nia.
Qed.
Lemma square_sum_zero: square_sum 0 = Int.zero.
Proof. reflexivity. Qed.
Lemma square_sum_step:
  forall n, square_sum n = Int.add (Int.mul (Int.repr n) (Int.repr n)) (square_sum (n - 1)).
Proof.
  intros n. unfold square_sum. rewrite triangle_step.
  rewrite <- int_add_repr.
  assert (N: Int.repr (n - 1) = Int.sub (Int.repr n) Int.one).
  { unfold Int.sub, Int.one. apply Int.eqm_samerepr.
    apply Int.eqm_sub; auto with ints. }
  rewrite N.
  pose proof (triangle_twice_int (n - 1)) as T. rewrite N in T.
  assert (TWO: Int.repr 2 = Int.add Int.one Int.one) by reflexivity.
  assert (THREE: Int.mul (Int.add (Int.add Int.one Int.one) Int.one)
    (Int.repr 2863311531) = Int.one) by (apply Int.same_if_eq; vm_compute; reflexivity).
  rewrite TWO in *.
  replace (Int.mul (Int.mul (Int.add (Int.repr (triangle (n - 1))) (Int.repr n))
    (Int.add (Int.mul (Int.repr n) (Int.add Int.one Int.one)) Int.one)) (Int.repr 2863311531))
    with (Int.add (Int.mul (Int.mul (Int.repr (triangle (n - 1)))
      (Int.add (Int.mul (Int.sub (Int.repr n) Int.one) (Int.add Int.one Int.one)) Int.one))
      (Int.repr 2863311531))
      (Int.mul (Int.add (Int.mul (Int.repr (triangle (n - 1))) (Int.add Int.one Int.one))
        (Int.add (Int.mul (Int.add Int.one Int.one) (Int.mul (Int.repr n) (Int.repr n)))
          (Int.repr n))) (Int.repr 2863311531))) by ring.
  rewrite T.
  replace (Int.add (Int.mul (Int.sub (Int.repr n) Int.one)
      (Int.add (Int.sub (Int.repr n) Int.one) Int.one))
    (Int.add (Int.mul (Int.add Int.one Int.one) (Int.mul (Int.repr n) (Int.repr n))) (Int.repr n)))
    with (Int.mul (Int.mul (Int.repr n) (Int.repr n))
      (Int.add (Int.add Int.one Int.one) Int.one)) by ring.
  replace (Int.mul (Int.mul (Int.mul (Int.repr n) (Int.repr n))
    (Int.add (Int.add Int.one Int.one) Int.one)) (Int.repr 2863311531))
    with (Int.mul (Int.repr n) (Int.repr n)).
  - ring.
  - rewrite (Int.mul_assoc (Int.mul (Int.repr n) (Int.repr n))), THREE. ring.
Qed.
Lemma sum_value_step:
  forall c n, is_base c n = false ->
  sum_value c n = Int.add (Int.mul n n) (sum_value c (Int.sub n Int.one)).
Proof.
  intros c n NB. unfold sum_value. rewrite decrement_count by auto.
  rewrite square_sum_step at 1.
  destruct (nonbase_count _ _ NB) as [E _]. rewrite E, Int.repr_unsigned. reflexivity.
Qed.

Lemma eval_condition_base:
  forall c n m, eval_condition (condition c) (Vint n :: nil) m = Some (is_base c n).
Proof. intros. unfold condition, is_base. destruct (signed_test c); [reflexivity|apply eval_zero_condition]. Qed.
End ARITHMETIC.

(** * Recognition *)

Section RECOGNITION.
(** Soundness of the executable structural validator. *)

Record loop_spec (f: function) (c: shape): Prop := {
  spec_bits: Archi.ptr64 = true;
  spec_signature: fn_sig f = unary_int_signature;
  spec_stack: fn_stacksize f = 0;
  spec_parameters: fn_params f = parameter c :: nil;
  spec_entry: fn_entrypoint f = entry_node c;
  spec_registers: list_norepet (registers c);
  spec_nodes: list_norepet (nodes c);
  spec_code: forall pc i, In (pc,i) (instructions c) -> (fn_code f)!pc = Some i
}.

Theorem recognize_sound:
  forall f c, recognize f = Some c -> loop_spec f c.
Proof.
  intros f c REC. unfold recognize in REC.
  destruct (discover f) as [d|]; try discriminate.
  destruct (validate f d) eqn:VALID; inv REC.
  unfold validate in VALID.
  destruct Archi.ptr64 eqn:BITS; try discriminate.
  destruct (signature_eq (fn_sig f) unary_int_signature); try discriminate.
  destruct (zeq (fn_stacksize f) 0); try discriminate.
  destruct (list_eq_dec peq (fn_params f) (parameter c :: nil)); try discriminate.
  destruct (peq (fn_entrypoint f) (entry_node c)); try discriminate.
  destruct (list_norepet_dec peq (registers c)); try discriminate.
  destruct (list_norepet_dec peq (nodes c)); try discriminate.
  constructor; auto. intros pc i IN.
  apply forallb_forall with (x := (pc,i)) in VALID; auto. simpl in VALID.
  destruct ((fn_code f)!pc) eqn:CODE; try discriminate.
  destruct (instruction_eq i0 i); congruence.
Qed.

Lemma register_inequalities:
  forall f c, loop_spec f c ->
  parameter c <> accumulator_reg c /\ parameter c <> decrement_reg c /\
  parameter c <> base_reg c /\ accumulator_reg c <> decrement_reg c /\
  accumulator_reg c <> base_reg c /\ decrement_reg c <> base_reg c /\
  parameter c <> square_reg c /\ accumulator_reg c <> square_reg c /\
  decrement_reg c <> square_reg c /\ base_reg c <> square_reg c.
Proof.
  intros. pose proof (spec_registers _ _ H) as ND. unfold registers in ND.
  repeat match goal with H: list_norepet (_ :: _) |- _ => inv H end.
  simpl in *. intuition.
Qed.

Lemma function_signature:
  forall f, fn_sig (transf_function f) = fn_sig f.
Proof.
  intros. unfold transf_function. destruct (recognize f) as [c|] eqn:REC; auto.
  simpl. symmetry. eapply spec_signature. eapply recognize_sound; eauto.
Qed.
End RECOGNITION.

(** * Target execution *)

Section TARGET_EXECUTION.
(** Execution of the fixed-size target function. *)

Local Open Scope rtl.
Local Open Scope positive_scope.

Lemma fast_body_exec:
  forall ge c s sp rs m n,
  rs#(1%positive) = Vint n ->
  exists rs',
  plus RTL.step ge (State s (fast_function c) sp 2 rs m) E0
    (State s (fast_function c) sp 9 rs' m) /\
  rs'#(8%positive) = Vint (Int.add (square_sum (Int.unsigned n)) (base_value c)).
Proof.
  intros ge c s sp rs m n ARG. eexists; split.
  - eapply plus_left.
    eapply exec_Iop; [reflexivity|]. simpl. rewrite ARG. reflexivity.
    do 9 (eapply star_left;
      [eapply exec_Iop; [reflexivity|simpl; rewrite ?Regmap.gss;
        repeat rewrite Regmap.gso by discriminate; rewrite ?Regmap.gss, ?ARG; reflexivity] | | reflexivity]).
    apply star_refl. reflexivity.
  - rewrite Regmap.gss. simpl.
    repeat rewrite Regmap.gso by discriminate.
    rewrite ?Regmap.gss, ?ARG. simpl.
    unfold square_sum. rewrite Int.repr_unsigned.
    change (Vint (Int.add (Int.add
      (Int.mul (Int.mul (Int64.loword
        (Int64.shru' (Int64.mul (Int64.repr (Int.unsigned n))
          (Int64.add (Int64.repr (Int.unsigned n)) Int64.one)) Int.one))
        (Int.add (Int.mul n (Int.repr 2)) Int.one)) (Int.repr 2863311531))
      (base_value c)) Int.zero) = Vint (Int.add
        (Int.mul (Int.mul (Int.repr (triangle (Int.unsigned n)))
          (Int.add (Int.mul n (Int.repr 2)) Int.one)) (Int.repr 2863311531)) (base_value c))).
    rewrite BasicCorrect.wide_triangle, Int.add_zero.
    reflexivity.
Qed.

Lemma fast_function_exec:
  forall ge c s sp m n,
  exists rs',
  plus RTL.step ge
    (State s (fast_function c) sp (fn_entrypoint (fast_function c))
      (init_regs (Vint n :: nil) (fn_params (fast_function c))) m) E0
    (State s (fast_function c) sp 9 rs' m) /\
    rs'#(8%positive) = Vint (answer c n).
Proof.
  intros. destruct (signed_test c) eqn:MODE.
  - assert (ENTRY: fn_entrypoint (fast_function c) = 1%positive) by (simpl; rewrite MODE; reflexivity).
    rewrite ENTRY. destruct (is_base c n) eqn:BASE.
    + eexists; split.
      eapply plus_left. eapply exec_Icond with (b := true); [reflexivity| |reflexivity].
      change (eval_condition (condition c) (Vint n :: nil) m = Some true).
      rewrite eval_condition_base, BASE. reflexivity.
      apply star_one. eapply exec_Iop; reflexivity. reflexivity.
      rewrite Regmap.gss. unfold answer, sum_value. rewrite base_count_zero by auto.
      change (Vint (base_value c) = Vint (Int.add Int.zero (base_value c))). rewrite Int.add_zero_l.
      reflexivity.
    + destruct (fast_body_exec ge c s sp
        (init_regs (Vint n :: nil) (fn_params (fast_function c))) m n)
        as (rs' & STEPS & RESULT); [reflexivity|].
      exists rs'. split.
      eapply plus_left. eapply exec_Icond with (b := false); [reflexivity| |reflexivity].
      change (eval_condition (condition c) (Vint n :: nil) m = Some false).
      rewrite eval_condition_base, BASE. reflexivity.
      apply plus_star. exact STEPS. reflexivity.
      rewrite RESULT. unfold answer, sum_value.
      rewrite (proj1 (nonbase_count _ _ BASE)). reflexivity.
  - destruct (fast_body_exec ge c s sp
      (init_regs (Vint n :: nil) (fn_params (fast_function c))) m n)
      as (rs' & STEPS & RESULT); [reflexivity|].
    exists rs'. split.
    change (plus RTL.step ge (State s (fast_function c) sp
      (if signed_test c then 1%positive else 2%positive)
      (init_regs (Vint n :: nil) (fn_params (fast_function c))) m) E0 (State s (fast_function c) sp 9 rs' m)).
    rewrite MODE. exact STEPS.
    rewrite RESULT. unfold answer, sum_value, count. rewrite MODE. reflexivity.
Qed.
End TARGET_EXECUTION.

(** * Source loop *)

Section SOURCE_LOOP.
(** A decreasing invariant for the original summation loop. *)
Local Open Scope rtl.

Definition rank (c: shape) (n: int) (phase: Z) := Z.to_nat (5 * count c n + phase).

Inductive loop_state (c: shape): nat -> node -> regset -> int -> Prop :=
| loop_entry: forall rs n,
    rs#(parameter c) = Vint n ->
    loop_state c (rank c n 6) (entry_node c) rs (answer c n)
| loop_test: forall rs n a,
    rs#(parameter c) = Vint n -> rs#(accumulator_reg c) = Vint a ->
    loop_state c (rank c n 5) (test_node c) rs (Int.add a (answer c n))
| loop_square: forall rs n a,
    rs#(parameter c) = Vint n -> rs#(accumulator_reg c) = Vint a ->
    is_base c n = false ->
    loop_state c (rank c n 4) (square_node c) rs (Int.add a (answer c n))
| loop_decrement: forall rs n a,
    rs#(parameter c) = Vint n -> rs#(accumulator_reg c) = Vint a ->
    rs#(square_reg c) = Vint (Int.mul n n) -> is_base c n = false ->
    loop_state c (rank c n 3) (decrement_node c) rs (Int.add a (answer c n))
| loop_add: forall rs n a,
    rs#(parameter c) = Vint n -> rs#(accumulator_reg c) = Vint a ->
    rs#(decrement_reg c) = Vint (Int.sub n Int.one) ->
    rs#(square_reg c) = Vint (Int.mul n n) -> is_base c n = false ->
    loop_state c (rank c n 2) (add_node c) rs (Int.add a (answer c n))
| loop_move: forall rs n a,
    rs#(accumulator_reg c) = Vint (Int.add a (Int.mul n n)) ->
    rs#(decrement_reg c) = Vint (Int.sub n Int.one) -> is_base c n = false ->
    loop_state c (rank c n 1) (move_node c) rs (Int.add a (answer c n))
| loop_base: forall rs a,
    rs#(accumulator_reg c) = Vint a ->
    loop_state c 3%nat (base_node c) rs (Int.add a (base_value c))
| loop_finish: forall rs a,
    rs#(accumulator_reg c) = Vint a -> rs#(base_reg c) = Vint (base_value c) ->
    loop_state c 2%nat (finish_node c) rs (Int.add a (base_value c))
| loop_return: forall rs v,
    rs#(accumulator_reg c) = Vint v ->
    loop_state c 1%nat (return_node c) rs v.

Lemma rank_phase:
  forall c n x y, 0 <= x < y -> (rank c n x < rank c n y)%nat.
Proof. intros. unfold rank. apply Z2Nat.inj_lt; generalize (count_nonnegative c n); lia. Qed.
Lemma rank_decrement:
  forall c n, is_base c n = false ->
  (rank c (Int.sub n Int.one) 5 < rank c n 1)%nat.
Proof.
  intros. unfold rank. rewrite decrement_count by auto.
  destruct (nonbase_count _ _ H). apply Z2Nat.inj_lt; lia.
Qed.
Lemma answer_base:
  forall c n, is_base c n = true -> answer c n = base_value c.
Proof.
  intros. unfold answer, sum_value. rewrite base_count_zero by auto.
  change (Int.add Int.zero (base_value c) = base_value c). apply Int.add_zero_l.
Qed.
Lemma answer_step:
  forall c n a, is_base c n = false ->
  Int.add a (answer c n) = Int.add (Int.add a (Int.mul n n)) (answer c (Int.sub n Int.one)).
Proof.
  intros. unfold answer. rewrite sum_value_step by auto. repeat rewrite Int.add_assoc. reflexivity.
Qed.
Lemma decrement_op:
  forall n, Int.add n (Int.repr (-1)) = Int.sub n Int.one.
Proof. intros. rewrite Int.sub_add_opp. reflexivity. Qed.

Section LOOP.
Variables (ge: genv) (f: function) (c: shape).
Hypothesis SPEC: loop_spec f c.

Lemma loop_step:
  forall k pc rs v s stk m t S2,
  loop_state c k pc rs v ->
  step ge (State s f (Vptr stk Ptrofs.zero) pc rs m) t S2 ->
  (exists k' pc' rs', t = E0 /\
     S2 = State s f (Vptr stk Ptrofs.zero) pc' rs' m /\
     (k' < k)%nat /\ loop_state c k' pc' rs' v) \/
  (exists m', t = E0 /\ S2 = Returnstate s (Vint v) m' /\
     Mem.free m stk 0 0 = Some m').
Proof.
  intros k pc rs v s stk m t S2 LOOP STEP.
  destruct (register_inequalities _ _ SPEC) as (PA & PD & PB & AD & AB & DB & PQ & AQ & DQ & BQ).
  assert (CODE: forall pc i, In (pc,i) (instructions c) -> (fn_code f)!pc = Some i)
    by (apply spec_code; exact SPEC).
  destruct LOOP as [rs n ARG | rs n a ARG ACC | rs n a ARG ACC NB | rs n a ARG ACC SQUARE NB |
    rs n a ARG ACC DEC SQUARE NB | rs n a ACC DEC NB | rs a ACC | rs a ACC BASE | rs v ACC].
  - assert (C: (fn_code f)!(entry_node c) = Some (Iop (Ointconst Int.zero) nil (accumulator_reg c) (test_node c)))
      by (apply CODE; unfold instructions; simpl; tauto).
    inv STEP; try congruence;
      match goal with H: (fn_code f)!(entry_node c) = Some _ |- _ => rewrite C in H; inv H end.
    match goal with E: eval_operation _ _ _ _ _ = _ |- _ => rename E into EVAL end.
    cbn [List.map] in EVAL. simpl in EVAL. inv EVAL. left.
    exists (rank c n 5), (test_node c), (rs#(accumulator_reg c) <- (Vint Int.zero)).
    repeat split; auto. apply rank_phase; lia.
    rewrite <- (Int.add_zero_l (answer c n)). constructor.
    rewrite Regmap.gso; auto. apply Regmap.gss.
  - assert (C: (fn_code f)!(test_node c) = Some
      (guard_instruction (reverse_test c) (condition c) (parameter c :: nil) (base_node c) (square_node c)))
      by (apply CODE; unfold instructions; simpl; tauto).
    assert (EVAL: eval_condition (condition c) (rs##(parameter c :: nil)) m = Some (is_base c n)).
    { cbn [List.map]. rewrite ARG, eval_condition_base. reflexivity. }
    destruct (guard_step _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ C EVAL STEP) as [TRACE EQ]. subst t S2.
    destruct (is_base c n) eqn:BASE.
    + left. rewrite answer_base by auto.
      exists 3%nat, (base_node c), rs. repeat split; auto.
      unfold rank. rewrite base_count_zero by auto. simpl. lia.
      constructor; auto.
    + left. exists (rank c n 4), (square_node c), rs.
      repeat split; auto. apply rank_phase; lia. constructor; auto.
  - assert (C: (fn_code f)!(square_node c) = Some
      (Iop Omul (parameter c :: parameter c :: nil) (square_reg c) (decrement_node c)))
      by (apply CODE; unfold instructions; simpl; tauto).
    inv STEP; try congruence;
      match goal with H: (fn_code f)!(square_node c) = Some _ |- _ => rewrite C in H; inv H end.
    match goal with E: eval_operation _ _ _ _ _ = _ |- _ => rename E into EVAL end.
    cbn [List.map] in EVAL. rewrite ARG in EVAL. simpl in EVAL. inv EVAL.
    left. exists (rank c n 3); eexists; eexists. repeat split; auto.
    apply rank_phase; lia. econstructor; eauto; rewrite ?Regmap.gss, ?Regmap.gso; auto.
  - assert (C: (fn_code f)!(decrement_node c) = Some (Iop (Olea (Aindexed (-1))) (parameter c :: nil) (decrement_reg c) (add_node c)))
      by (apply CODE; unfold instructions; simpl; tauto).
    inv STEP; try congruence;
      match goal with H: (fn_code f)!(decrement_node c) = Some _ |- _ => rewrite C in H; inv H end.
    match goal with E: eval_operation _ _ _ _ _ = _ |- _ => rename E into EVAL end.
    cbn [List.map] in EVAL. rewrite ARG in EVAL. simpl in EVAL. rewrite decrement_op in EVAL. inv EVAL.
    left. exists (rank c n 2); eexists; eexists. repeat split; auto.
    apply rank_phase; lia.
    econstructor; eauto; rewrite ?Regmap.gss, ?Regmap.gso; auto.
  - assert (C: (fn_code f)!(add_node c) = Some (Iop int_add_operation (add_args (add_reversed c) (accumulator_reg c) (square_reg c)) (accumulator_reg c) (move_node c)))
      by (apply CODE; unfold instructions; simpl; tauto).
    inv STEP; try congruence;
      match goal with H: (fn_code f)!(add_node c) = Some _ |- _ => rewrite C in H; inv H end.
    match goal with E: eval_operation _ _ _ _ _ = _ |- _ => rename E into EVAL end.
    rewrite (eval_add_args _ _ _ _ _ _ _ _ _ ACC SQUARE) in EVAL. inv EVAL.
    left. exists (rank c n 1); eexists; eexists. repeat split; auto.
    apply rank_phase; lia.
    econstructor; eauto; rewrite ?Regmap.gss, ?Regmap.gso; auto.
  - assert (C: (fn_code f)!(move_node c) = Some (Iop Omove (decrement_reg c :: nil) (parameter c) (test_node c)))
      by (apply CODE; unfold instructions; simpl; tauto).
    inv STEP; try congruence;
      match goal with H: (fn_code f)!(move_node c) = Some _ |- _ => rewrite C in H; inv H end.
    match goal with E: eval_operation _ _ _ _ _ = _ |- _ => rename E into EVAL end.
    cbn [List.map] in EVAL. rewrite DEC in EVAL. simpl in EVAL. inv EVAL.
    left. rewrite answer_step by auto.
    exists (rank c (Int.sub n Int.one) 5), (test_node c),
      (rs#(parameter c) <- (Vint (Int.sub n Int.one))).
    repeat split; auto. apply rank_decrement; auto.
    constructor. apply Regmap.gss. rewrite Regmap.gso; congruence.
  - assert (C: (fn_code f)!(base_node c) = Some (Iop (Ointconst (base_value c)) nil (base_reg c) (finish_node c)))
      by (apply CODE; unfold instructions; simpl; tauto).
    inv STEP; try congruence;
      match goal with H: (fn_code f)!(base_node c) = Some _ |- _ => rewrite C in H; inv H end.
    match goal with E: eval_operation _ _ _ _ _ = _ |- _ => rename E into EVAL end.
    cbn [List.map] in EVAL. simpl in EVAL. inv EVAL. left.
    exists 2%nat, (finish_node c), (rs#(base_reg c) <- (Vint (base_value c))).
    repeat split; auto. constructor. rewrite Regmap.gso; auto. apply Regmap.gss.
  - assert (C: (fn_code f)!(finish_node c) = Some (Iop int_add_operation (add_args (finish_reversed c) (accumulator_reg c) (base_reg c)) (accumulator_reg c) (return_node c)))
      by (apply CODE; unfold instructions; simpl; tauto).
    inv STEP; try congruence;
      match goal with H: (fn_code f)!(finish_node c) = Some _ |- _ => rewrite C in H; inv H end.
    match goal with E: eval_operation _ _ _ _ _ = _ |- _ => rename E into EVAL end.
    rewrite (eval_add_args _ _ _ _ _ _ _ _ _ ACC BASE) in EVAL. inv EVAL.
    left. exists 1%nat, (return_node c), (rs#(accumulator_reg c) <- (Vint (Int.add a (base_value c)))).
    repeat split; auto. constructor. apply Regmap.gss.
  - assert (C: (fn_code f)!(return_node c) = Some (Ireturn (Some (accumulator_reg c))))
      by (apply CODE; unfold instructions; simpl; tauto).
    inv STEP; try congruence;
      match goal with H: (fn_code f)!(return_node c) = Some _ |- _ => rewrite C in H; inv H end.
    right. exists m'. simpl. rewrite ACC. repeat split; auto.
    match goal with F: Mem.free _ _ _ _ = _ |- _ => rewrite (spec_stack _ _ SPEC) in F; exact F end.
Qed.
End LOOP.
End SOURCE_LOOP.

(** * Program simulation *)

Section PROGRAM_SIMULATION.
(** Whole-program forward simulation.  Source loop steps stutter against a
    computed target result; [rank] rules out infinite silent stuttering. *)
Local Open Scope rtl.

Definition match_prog (p tp: program) :=
  match_program (fun ctx f tf => tf = SumClosed.Square.transf_fundef f) eq p tp.
Lemma transf_program_match:
  forall p, match_prog p (SumClosed.Square.transf_program p).
Proof. intros. eapply match_transform_program; eauto. Qed.

Inductive match_states: nat -> state -> state -> Prop :=
| match_plain: forall s f sp pc rs m,
    match_states O (State s f sp pc rs m) (State s f sp pc rs m)
| match_call: forall s fd args m,
    match_states O (Callstate s fd args m) (Callstate s (SumClosed.Square.transf_fundef fd) args m)
| match_return: forall s v m,
    match_states O (Returnstate s v m) (Returnstate s v m)
| match_loop: forall s f c stk pc rs m k v trs,
    recognize f = Some c -> loop_state c k pc rs v -> trs#(8%positive) = Vint v ->
    match_states k (State s f (Vptr stk Ptrofs.zero) pc rs m)
      (State s (fast_function c) (Vptr stk Ptrofs.zero) 9%positive trs m).

Section PRESERVATION.
Variables prog tprog: program.
Hypothesis TRANSL: match_prog prog tprog.
Let ge := Genv.globalenv prog.
Let tge := Genv.globalenv tprog.

Lemma functions_translated:
  forall v f, Genv.find_funct ge v = Some f ->
  Genv.find_funct tge v = Some (SumClosed.Square.transf_fundef f).
Proof (Genv.find_funct_transf TRANSL).
Lemma function_ptr_translated:
  forall v f, Genv.find_funct_ptr ge v = Some f ->
  Genv.find_funct_ptr tge v = Some (SumClosed.Square.transf_fundef f).
Proof (Genv.find_funct_ptr_transf TRANSL).
Lemma symbols_preserved:
  forall id, Genv.find_symbol tge id = Genv.find_symbol ge id.
Proof (Genv.find_symbol_transf TRANSL).
Lemma senv_preserved: Senv.equiv ge tge.
Proof (Genv.senv_transf TRANSL).
Lemma sig_preserved:
  forall f, funsig (SumClosed.Square.transf_fundef f) = funsig f.
Proof. destruct f; simpl; auto. apply function_signature. Qed.
Lemma find_function_translated:
  forall ros rs fd, find_function ge ros rs = Some fd ->
  find_function tge ros rs = Some (SumClosed.Square.transf_fundef fd).
Proof.
  unfold find_function; intros. destruct ros as [r|id].
  eapply functions_translated; eauto.
  rewrite symbols_preserved. destruct (Genv.find_symbol ge id); try congruence.
  eapply function_ptr_translated; eauto.
Qed.

Definition progress (S: state) (t: trace) (T: state): Prop :=
  exists k T', plus step tge T t T' /\ match_states k S T'.

Lemma plain_step:
  forall s f sp pc rs m t S,
  step ge (State s f sp pc rs m) t S ->
  progress S t (State s f sp pc rs m).
Proof.
  intros s f sp pc rs m t S STEP. inv STEP; unfold progress.
  - exists O. eexists; split. apply plus_one. eapply exec_Inop; eauto. constructor.
  - exists O. eexists; split. apply plus_one. eapply exec_Iop; eauto.
    match goal with E: eval_operation _ _ _ _ _ = _ |- _ => rewrite <- E end.
    apply eval_operation_preserved. exact symbols_preserved. constructor.
  - exists O. eexists; split. apply plus_one. eapply exec_Iload; eauto.
    match goal with E: eval_addressing _ _ _ _ = _ |- _ => rewrite <- E end.
    apply eval_addressing_preserved. exact symbols_preserved. constructor.
  - exists O. eexists; split. apply plus_one. eapply exec_Istore; eauto.
    match goal with E: eval_addressing _ _ _ _ = _ |- _ => rewrite <- E end.
    apply eval_addressing_preserved. exact symbols_preserved. constructor.
  - exists O. eexists; split. apply plus_one.
    eapply exec_Icall with (fd := SumClosed.Square.transf_fundef fd); eauto using find_function_translated.
    rewrite sig_preserved; auto. constructor.
  - exists O. eexists; split. apply plus_one.
    eapply exec_Itailcall with (fd := SumClosed.Square.transf_fundef fd); eauto using find_function_translated.
    rewrite sig_preserved; auto. constructor.
  - exists O. eexists; split. apply plus_one. eapply exec_Ibuiltin; eauto.
    eapply eval_builtin_args_preserved with (ge1 := ge); eauto. exact symbols_preserved.
    eapply external_call_symbols_preserved; eauto. apply senv_preserved. constructor.
  - exists O. eexists; split. apply plus_one. eapply exec_Icond; eauto. constructor.
  - exists O. eexists; split. apply plus_one. eapply exec_Ijumptable; eauto. constructor.
  - exists O. eexists; split. apply plus_one. eapply exec_Ireturn; eauto. constructor.

Qed.

Lemma unary_args:
  forall f c args, loop_spec f c -> Val.has_argtype_list args (sig_args (fn_sig f)) ->
  exists n, args = Vint n :: nil.
Proof.
  intros f c args SPEC ARGS. rewrite (spec_signature _ _ SPEC) in ARGS.
  inversion ARGS as [|v x vl xl TYPE REST]; subst.
  inv REST. destruct v; simpl in TYPE; try contradiction; eauto.
  rewrite (spec_bits _ _ SPEC) in TYPE. discriminate.
Qed.

Lemma call_step:
  forall s fd args m t S,
  step ge (Callstate s fd args m) t S ->
  progress S t (Callstate s (SumClosed.Square.transf_fundef fd) args m).
Proof.
  intros s fd args m t S STEP. inv STEP.
  - match goal with A: Val.has_argtype_list _ _ |- _ => rename A into ARGS end.
    match goal with A: Mem.alloc _ _ _ = _ |- _ => rename A into ALLOC end.
    destruct (recognize f) as [c|] eqn:REC.
    + pose proof (recognize_sound _ _ REC) as SPEC.
      destruct (unary_args _ _ _ SPEC ARGS) as (n & EQ). subst args.
      destruct (fast_function_exec tge c s (Vptr stk Ptrofs.zero) m' n)
        as (trs & STEPS & RESULT).
      unfold progress. exists (rank c n 6).
      exists (State s (fast_function c) (Vptr stk Ptrofs.zero) 9%positive trs m'). split.
      * eapply plus_left.
        cbn [SumClosed.Square.transf_fundef AST.transf_fundef].
        unfold SumClosed.Square.transf_function. rewrite REC.
        eapply exec_function_internal.
        change (Val.has_argtype_list (Vint n :: nil) (sig_args unary_int_signature)). rewrite <- (spec_signature _ _ SPEC). exact ARGS.
        simpl. rewrite <- (spec_stack _ _ SPEC) at 2. exact ALLOC.
        apply plus_star. exact STEPS. reflexivity.
      * eapply match_loop; eauto. rewrite (spec_entry _ _ SPEC), (spec_parameters _ _ SPEC).
        constructor. simpl. apply Regmap.gss.
    + unfold progress. exists O. eexists; split.
      apply plus_one. cbn [SumClosed.Square.transf_fundef AST.transf_fundef].
      unfold SumClosed.Square.transf_function. rewrite REC. eapply exec_function_internal; eauto.
      constructor.
  - unfold progress. exists O. eexists; split. apply plus_one.
    eapply exec_function_external. eapply external_call_symbols_preserved; eauto. apply senv_preserved.
    constructor.
Qed.

Lemma step_simulation:
  forall S t S', step ge S t S' -> forall k T, match_states k S T ->
  exists k' T', (plus step tge T t T' \/ (star step tge T t T' /\ (k' < k)%nat)) /\
    match_states k' S' T'.
Proof.
  intros S t S' STEP k T MATCH. inv MATCH.
  - destruct (plain_step _ _ _ _ _ _ _ _ STEP) as (k' & T' & A & B).
    exists k', T'. auto.
  - destruct (call_step _ _ _ _ _ _ STEP) as (k' & T' & A & B).
    exists k', T'. auto.
  - inv STEP. exists O. eexists. split. left. apply plus_one. constructor. constructor.
  - destruct (loop_step ge f c (recognize_sound _ _ H) _ _ _ _ _ _ _ _ _ H0 STEP)
      as [(k' & pc' & rs' & TRACE & EQ & LESS & LOOP) | (m' & TRACE & EQ & FREE)]; subst.
    + exists k', (State s (fast_function c) (Vptr stk Ptrofs.zero) 9%positive trs m).
      split. right. split; auto. apply star_refl. eapply match_loop; eauto.
    + exists O, (Returnstate s (Vint v) m'). split.
      left. apply plus_one.
      replace (Vint v) with (regmap_optget (Some 8%positive) Vundef trs) by (simpl; auto).
      eapply exec_Ireturn; [reflexivity|exact FREE]. constructor.
Qed.

Lemma transf_initial_states:
  forall S, initial_state prog S -> exists k T, initial_state tprog T /\ match_states k S T.
Proof.
  intros S INIT. inv INIT. exists O. eexists; split.
  econstructor.
  eapply (Genv.init_mem_transf TRANSL); eauto.
  rewrite symbols_preserved. replace (prog_main tprog) with (prog_main prog). eauto.
  symmetry. eapply match_program_main; eauto.
  eapply function_ptr_translated; eauto.
  rewrite sig_preserved; eauto.
  constructor.
Qed.

Theorem transf_program_correct:
  forward_simulation (RTL.semantics prog) (RTL.semantics tprog).
Proof.
  apply Forward_simulation with lt match_states. constructor.
  - apply lt_wf.
  - exact transf_initial_states.
  - intros k S T r MATCH FINAL. inv FINAL. inv MATCH. constructor.
  - exact step_simulation.
  - apply senv_preserved.
Qed.
End PRESERVATION.
End PROGRAM_SIMULATION.


End SquareCorrect.
(** The checked recognizers remain internal to the same RTL pass. *)
Definition match_prog (p tp: program): Prop :=
  exists m1 m2, BasicCorrect.match_prog p m1 /\ AffineCorrect.match_prog m1 m2 /\ SquareCorrect.match_prog m2 tp.
Theorem transf_program_match:
  forall p, match_prog p (SumClosed.transf_program p).
Proof.
  intros; exists (SumClosed.Basic.transf_program p),
    (SumClosed.Affine.transf_program (SumClosed.Basic.transf_program p)); repeat split.
  - apply BasicCorrect.transf_program_match.
  - apply AffineCorrect.transf_program_match.
  - apply SquareCorrect.transf_program_match.
Qed.
Global Instance transf_program_link: TransfLink match_prog.
Proof.
  red; intros p1 p2 tp1 tp2 p LINK (m1 & a1 & B1 & A1 & S1) (m2 & a2 & B2 & A2 & S2).
  destruct (transf_link (transf := BasicCorrect.match_prog) _ _ _ _ _ LINK B1 B2)
    as (m & LM & B).
  destruct (transf_link (transf := AffineCorrect.match_prog) _ _ _ _ _ LM A1 A2)
    as (t & LT & A).
  destruct (transf_link (transf := SquareCorrect.match_prog) _ _ _ _ _ LT S1 S2)
    as (u & LU & S).
  exists u; split; auto. exists m, t; auto.
Qed.
Theorem transf_program_correct:
  forall p tp, match_prog p tp ->
  forward_simulation (RTL.semantics p) (RTL.semantics tp).
Proof.
  intros p tp (m & a & B & A & S). eapply compose_forward_simulations.
  - eapply BasicCorrect.transf_program_correct; eauto.
  - eapply compose_forward_simulations.
    + eapply AffineCorrect.transf_program_correct; eauto.
    + eapply SquareCorrect.transf_program_correct; eauto.
Qed.
