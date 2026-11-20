(** Accumulator recursion elimination: correctness proof.

    The proof follows the usual RTL pass structure: syntactic properties,
    register and memory invariants, matching states, simulation of each step,
    initial/final states, and the program-level correctness theorem.
    The small normalization/cleanup proofs are enclosed in local modules. *)

Require Import Coqlib Axioms Maps Errors AST Linking Integers Values Memory.
Require Import Events Globalenvs Smallstep Parmov Op Registers RTL RTLtyping AccumRec.
From Coq Require Import Sorting.Permutation.
Local Open Scope rtl.

(** * Return normalization correctness *)

Module ReturnCorrect.
Import AccumRec.Return.
(** Source administrative steps stutter while the target waits at a return.
    Both sides free the same frame on the source return step, so no memory
    injection or early-free assumption is needed. *)
Local Open Scope rtl.

Inductive returns (f: function): nat -> node -> regset -> val -> Prop :=
| returns_return: forall pc rs r,
    (fn_code f)!pc = Some (Ireturn (Some r)) ->
    returns f 1%nat pc rs rs#r
| returns_nop: forall fuel pc next rs v,
    (fn_code f)!pc = Some (Inop next) -> returns f fuel next rs v ->
    returns f (S fuel) pc rs v
| returns_move: forall fuel pc next rs src dst v,
    (fn_code f)!pc = Some (Iop Omove (src :: nil) dst next) ->
    returns f fuel next (rs#dst <- (rs#src)) v ->
    returns f (S fuel) pc rs v.

Lemma return_value_sound:
  forall fuel f pc r, return_value fuel f pc = Some r ->
  forall rs, exists k, (k <= fuel)%nat /\ returns f k pc rs rs#r.
Proof.
  induction fuel; simpl; intros; try discriminate.
  destruct ((fn_code f)!pc) as [i|] eqn:CODE; try discriminate.
  destruct i; try discriminate.
  - destruct (IHfuel _ _ _ H rs) as (k & B & R). exists (S k). split; [lia|econstructor; eauto].
  - destruct o; try discriminate. destruct l as [|src l]; try discriminate.
    destruct l; try discriminate. destruct (return_value fuel f n) as [rr|] eqn:RET; try discriminate.
    inv H. destruct (IHfuel _ _ _ RET (rs#r0 <- (rs#src))) as (k & B & R).
    exists (S k). split; [lia|]. eapply returns_move; [exact CODE|].
    rewrite Regmap.gsspec in R. destruct (peq rr r0); auto.
  - destruct o; inv H. exists 1%nat. split; [lia|constructor; auto].
Qed.

Definition match_prog (p tp: program) :=
  match_program (fun ctx f tf => tf = Return.transf_fundef f) eq p tp.
Lemma transf_program_match: forall p, match_prog p (Return.transf_program p).
Proof. intros. apply match_transform_program; auto. Qed.

Inductive match_frames: stackframe -> stackframe -> Prop :=
| match_frame: forall res f sp pc rs,
    match_frames (Stackframe res f sp pc rs)
      (Stackframe res (transf_function f) sp pc rs).
Inductive match_states: nat -> state -> state -> Prop :=
| match_regular: forall s ts f sp pc rs m,
    list_forall2 match_frames s ts ->
    match_states (S lookahead) (State s f sp pc rs m)
      (State ts (transf_function f) sp pc rs m)
| match_pending: forall s ts f sp pc rs m k v tpc trs r,
    list_forall2 match_frames s ts -> returns f k pc rs v ->
    (fn_code (transf_function f))!tpc = Some (Ireturn (Some r)) -> trs#r = v ->
    match_states k (State s f sp pc rs m)
      (State ts (transf_function f) sp tpc trs m)
| match_call: forall s ts fd args m,
    list_forall2 match_frames s ts ->
    match_states (S lookahead) (Callstate s fd args m)
      (Callstate ts (Return.transf_fundef fd) args m)
| match_return: forall s ts v m,
    list_forall2 match_frames s ts ->
    match_states (S lookahead) (Returnstate s v m) (Returnstate ts v m).

Section PRESERVATION.
Variables prog tprog: program.
Hypothesis TRANSL: match_prog prog tprog.
Let ge := Genv.globalenv prog.
Let tge := Genv.globalenv tprog.
Lemma functions_translated:
  forall v f, Genv.find_funct ge v = Some f ->
  Genv.find_funct tge v = Some (Return.transf_fundef f).
Proof (Genv.find_funct_transf TRANSL).
Lemma function_ptr_translated:
  forall v f, Genv.find_funct_ptr ge v = Some f ->
  Genv.find_funct_ptr tge v = Some (Return.transf_fundef f).
Proof (Genv.find_funct_ptr_transf TRANSL).
Lemma symbols_preserved:
  forall id, Genv.find_symbol tge id = Genv.find_symbol ge id.
Proof (Genv.find_symbol_transf TRANSL).
Lemma senv_preserved: Senv.equiv ge tge.
Proof (Genv.senv_transf TRANSL).
Lemma find_function_translated:
  forall ros rs fd, find_function ge ros rs = Some fd ->
  find_function tge ros rs = Some (Return.transf_fundef fd).
Proof.
  unfold find_function; intros. destruct ros as [r|id]. eapply functions_translated; eauto.
  rewrite symbols_preserved. destruct (Genv.find_symbol ge id); try congruence.
  eapply function_ptr_translated; eauto.
Qed.
Lemma sig_preserved: forall fd, funsig (Return.transf_fundef fd) = funsig fd.
Proof. destruct fd; reflexivity. Qed.
Lemma code_preserved:
  forall f pc i, (fn_code f)!pc = Some i -> return_value lookahead f pc = None ->
  (fn_code (transf_function f))!pc = Some i.
Proof. intros. simpl. rewrite PTree.gmap, H. simpl. unfold transf_instruction. rewrite H0. auto. Qed.
Lemma code_collapsed:
  forall f pc r, return_value lookahead f pc = Some r ->
  (fn_code (transf_function f))!pc = Some (Ireturn (Some r)).
Proof.
  intros. assert (exists i, (fn_code f)!pc = Some i).
  { generalize H. generalize lookahead. intros fuel R. destruct fuel; [discriminate|].
    cbn [return_value] in R. destruct ((fn_code f)!pc); try discriminate; eauto. }
  destruct H0 as [i CODE]. simpl. rewrite PTree.gmap, CODE.
  simpl. unfold transf_instruction. rewrite H. reflexivity.
Qed.

Definition simulation (k: nat) (S: state) (t: trace) (S' T: state) :=
  exists k' T', (plus step tge T t T' \/ (star step tge T t T' /\ (k' < k)%nat)) /\
    match_states k' S' T'.

Lemma pending_step:
  forall s ts f sp pc rs m k v tpc trs r t S',
  list_forall2 match_frames s ts -> returns f k pc rs v ->
  (fn_code (transf_function f))!tpc = Some (Ireturn (Some r)) -> trs#r = v ->
  step ge (State s f sp pc rs m) t S' ->
  simulation k (State s f sp pc rs m) t S'
    (State ts (transf_function f) sp tpc trs m).
Proof.
  intros s ts f sp pc rs m k v tpc trs r t S' STACK RET CODE VALUE STEP.
  inv RET; inv STEP; try congruence;
    match goal with A: (fn_code f)!pc = Some _, B: (fn_code f)!pc = Some _ |- _ =>
      rewrite A in B; inv B end.
  - unfold simulation. exists (S lookahead), (Returnstate ts rs#r0 m'). split.
    left. apply plus_one. replace (rs#r0) with (regmap_optget (Some r) Vundef trs) by (simpl; auto).
    eapply exec_Ireturn; eauto. constructor; auto.
  - unfold simulation. exists fuel, (State ts (transf_function f) sp tpc trs m).
    split. right. split; [apply star_refl|lia]. econstructor; eauto.
  - match goal with E: eval_operation _ _ _ _ _ = _ |- _ => simpl in E; inv E end.
    unfold simulation. exists fuel, (State ts (transf_function f) sp tpc trs m).
    split. right. split; [apply star_refl|lia]. econstructor; eauto.
Qed.

Lemma regular_step:
  forall s ts f sp pc rs m t S', list_forall2 match_frames s ts ->
  step ge (State s f sp pc rs m) t S' ->
  simulation (S lookahead) (State s f sp pc rs m) t S'
    (State ts (transf_function f) sp pc rs m).
Proof.
  intros s ts f sp pc rs m t S' STACK STEP.
  destruct (return_value lookahead f pc) as [r|] eqn:RET.
  - destruct (return_value_sound _ _ _ _ RET rs) as (k & B & R).
    destruct (pending_step _ _ _ _ _ _ _ _ _ _ _ _ _ _ STACK R
      (code_collapsed _ _ _ RET) eq_refl STEP) as (k' & T' & RUN & MATCH).
    exists k', T'. split; auto. destruct RUN as [PLUS|[STAR LESS]]; auto.
    right. split; auto. lia.
  - inv STEP; unfold simulation.
    + exists (S lookahead). eexists; split. left. apply plus_one. eapply exec_Inop; eauto using code_preserved.
      constructor; auto.
    + exists (S lookahead). eexists; split. left. apply plus_one. eapply exec_Iop; eauto using code_preserved.
      match goal with E: eval_operation _ _ _ _ _ = _ |- _ => rewrite <- E end.
      apply eval_operation_preserved. exact symbols_preserved. constructor; auto.
    + exists (S lookahead). eexists; split. left. apply plus_one. eapply exec_Iload; eauto using code_preserved.
      match goal with E: eval_addressing _ _ _ _ = _ |- _ => rewrite <- E end.
      apply eval_addressing_preserved. exact symbols_preserved. constructor; auto.
    + exists (S lookahead). eexists; split. left. apply plus_one. eapply exec_Istore; eauto using code_preserved.
      match goal with E: eval_addressing _ _ _ _ = _ |- _ => rewrite <- E end.
      apply eval_addressing_preserved. exact symbols_preserved. constructor; auto.
    + exists (S lookahead). eexists; split. left. apply plus_one.
      eapply exec_Icall with (fd := Return.transf_fundef fd); eauto using code_preserved, find_function_translated.
      rewrite sig_preserved; auto. constructor. constructor; auto. constructor.
    + exists (S lookahead). eexists; split. left. apply plus_one.
      eapply exec_Itailcall with (fd := Return.transf_fundef fd); eauto using code_preserved, find_function_translated.
      rewrite sig_preserved; auto. constructor; auto.
    + exists (S lookahead). eexists; split. left. apply plus_one. eapply exec_Ibuiltin; eauto using code_preserved.
      eapply eval_builtin_args_preserved with (ge1 := ge); eauto. exact symbols_preserved.
      eapply external_call_symbols_preserved; eauto. apply senv_preserved. constructor; auto.
    + exists (S lookahead). eexists; split. left. apply plus_one. eapply exec_Icond; eauto using code_preserved.
      constructor; auto.
    + exists (S lookahead). eexists; split. left. apply plus_one. eapply exec_Ijumptable; eauto using code_preserved.
      constructor; auto.
    + exists (S lookahead). eexists; split. left. apply plus_one. eapply exec_Ireturn; eauto using code_preserved.
      constructor; auto.
Qed.

Lemma step_simulation:
  forall S t S', step ge S t S' -> forall k T, match_states k S T -> simulation k S t S' T.
Proof.
  intros S t S' STEP k T MATCH. inv MATCH.
  - eapply regular_step; eauto.
  - eapply pending_step; eauto.
  - inv STEP; unfold simulation.
    + exists (S lookahead). eexists; split. left. apply plus_one.
      eapply exec_function_internal; eauto. constructor; auto.
    + exists (S lookahead). eexists; split. left. apply plus_one.
      eapply exec_function_external. eapply external_call_symbols_preserved; eauto. apply senv_preserved.
      constructor; auto.
  - inv STEP. match goal with ST: list_forall2 _ (_ :: _) _ |- _ => inv ST end. match goal with F: match_frames _ _ |- _ => inv F end.
    unfold simulation. exists (S lookahead). eexists; split. left. apply plus_one. constructor. constructor; auto.
Qed.
Lemma initial_states:
  forall S, RTL.initial_state prog S -> exists k T, RTL.initial_state tprog T /\ match_states k S T.
Proof.
  intros S INIT. inv INIT. exists (S lookahead). eexists; split. econstructor.
  eapply (Genv.init_mem_transf TRANSL); eauto.
  rewrite symbols_preserved. replace (prog_main tprog) with (prog_main prog). eauto.
  symmetry. eapply match_program_main; eauto.
  eapply function_ptr_translated; eauto.
  rewrite sig_preserved; eauto. constructor. constructor.
Qed.
Theorem transf_program_correct:
  forward_simulation (RTL.semantics prog) (RTL.semantics tprog).
Proof.
  apply Forward_simulation with lt match_states. constructor.
  apply lt_wf. exact initial_states.
  intros k S T r MATCH FINAL. inv FINAL. inv MATCH. match goal with ST: list_forall2 _ nil _ |- _ => inv ST end. constructor.
  exact step_simulation. apply senv_preserved.
Qed.
End PRESERVATION.
End ReturnCorrect.

(** * Thread normalization correctness *)

Module ThreadCorrect.
Import AccumRec.Thread.
(** Each skipped source instruction has no effect and consumes a strictly
    decreasing path index. Cyclic jumps remain divergent, even at the bound. *)
Local Open Scope rtl.

Inductive path (f: function) (rs: regset) (m: mem): nat -> node -> node -> Prop :=
| path_refl: forall pc, path f rs m O pc pc
| path_nop: forall k pc next finish,
    (fn_code f)!pc = Some (Inop next) -> path f rs m k next finish ->
    path f rs m (S k) pc finish
| path_cond: forall k pc cond args yes no b finish,
    (fn_code f)!pc = Some (Icond cond args yes no) ->
    eval_condition cond rs##args m = Some b ->
    path f rs m k (if b then yes else no) finish ->
    path f rs m (S k) pc finish.
Definition valid_known (known: known_test) (rs: regset) (m: mem): Prop :=
  match known with Some (cond,args,b) => eval_condition cond rs##args m = Some b | None => True end.
Lemma shortcut_sound:
  forall fuel f known pc rs m, valid_known known rs m ->
  exists k, path f rs m k pc (shortcut fuel f known pc).
Proof.
  induction fuel; intros; simpl; [exists O; constructor|].
  destruct ((fn_code f)!pc) as [i|] eqn:CODE; try (exists O; constructor).
  destruct i; try (exists O; constructor).
  - destruct (IHfuel f known n rs m H) as [k P]. exists (S k). econstructor; eauto.
  - destruct known as [[[old oldargs] outcome]|]; try (exists O; constructor).
    destruct (eq_condition c old); try (exists O; constructor).
    destruct (list_eq_dec peq l oldargs); try (exists O; constructor). subst c l.
    destruct (IHfuel f (Some (old,oldargs,outcome)) (if outcome then n else n0) rs m H) as [k P].
    exists (S k). eapply path_cond; eauto.
Qed.
Definition match_prog (p tp: program) :=
  match_program (fun ctx f tf => tf = Thread.transf_fundef f) eq p tp.
Lemma transf_program_match: forall p, match_prog p (Thread.transf_program p).
Proof. intros. apply match_transform_program; auto. Qed.
Inductive match_frames: stackframe -> stackframe -> Prop :=
| match_frame: forall res f sp pc rs,
    match_frames (Stackframe res f sp pc rs)
      (Stackframe res (transf_function f) sp (shortcut lookahead f None pc) rs).
Inductive match_states: nat -> state -> state -> Prop :=
| match_regular: forall s ts f sp pc rs m k tpc,
    list_forall2 match_frames s ts -> path f rs m k pc tpc ->
    match_states k (State s f sp pc rs m) (State ts (transf_function f) sp tpc rs m)
| match_call: forall s ts fd args m,
    list_forall2 match_frames s ts ->
    match_states O (Callstate s fd args m) (Callstate ts (Thread.transf_fundef fd) args m)
| match_return: forall s ts v m,
    list_forall2 match_frames s ts ->
    match_states O (Returnstate s v m) (Returnstate ts v m).
Section PRESERVATION.
Variables prog tprog: program.
Hypothesis TRANSL: match_prog prog tprog.
Let ge := Genv.globalenv prog.
Let tge := Genv.globalenv tprog.
Lemma functions_translated:
  forall v f, Genv.find_funct ge v = Some f -> Genv.find_funct tge v = Some (Thread.transf_fundef f).
Proof (Genv.find_funct_transf TRANSL).
Lemma function_ptr_translated:
  forall v f, Genv.find_funct_ptr ge v = Some f -> Genv.find_funct_ptr tge v = Some (Thread.transf_fundef f).
Proof (Genv.find_funct_ptr_transf TRANSL).
Lemma symbols_preserved:
  forall id, Genv.find_symbol tge id = Genv.find_symbol ge id.
Proof (Genv.find_symbol_transf TRANSL).
Lemma senv_preserved: Senv.equiv ge tge.
Proof (Genv.senv_transf TRANSL).
Lemma sig_preserved: forall fd, funsig (Thread.transf_fundef fd) = funsig fd.
Proof. destruct fd; reflexivity. Qed.
Lemma find_function_translated:
  forall ros rs fd, find_function ge ros rs = Some fd ->
  find_function tge ros rs = Some (Thread.transf_fundef fd).
Proof.
  unfold find_function; intros. destruct ros as [r|id]. eapply functions_translated; eauto.
  rewrite symbols_preserved. destruct (Genv.find_symbol ge id); try congruence.
  eapply function_ptr_translated; eauto.
Qed.
Lemma code_translated:
  forall f pc i, (fn_code f)!pc = Some i ->
  (fn_code (transf_function f))!pc = Some (transf_instr f i).
Proof. intros. simpl. rewrite PTree.gmap, H. reflexivity. Qed.
Definition simulation (k: nat) (S: state) (t: trace) (S' T: state) :=
  exists k' T', (plus step tge T t T' \/ (star step tge T t T' /\ (k' < k)%nat)) /\ match_states k' S' T'.
Lemma skipped_step:
  forall s ts f sp pc rs m k tpc t S',
  list_forall2 match_frames s ts -> path f rs m (S k) pc tpc ->
  step ge (State s f sp pc rs m) t S' ->
  simulation (S k) (State s f sp pc rs m) t S' (State ts (transf_function f) sp tpc rs m).
Proof.
  intros s ts f sp pc rs m k tpc t S' STACK PATH STEP.
  inv PATH; inv STEP; try congruence;
    match goal with A: (fn_code f)!pc = Some _, B: (fn_code f)!pc = Some _ |- _ => rewrite A in B; inv B end.
  - exists k, (State ts (transf_function f) sp tpc rs m). split.
    right. split; [apply star_refl|lia]. constructor; auto.
  - match goal with A: eval_condition _ _ _ = Some _, B: eval_condition _ _ _ = Some _ |- _ =>
      rewrite A in B; inv B end.
    exists k, (State ts (transf_function f) sp tpc rs m). split.
    right. split; [apply star_refl|lia]. constructor; auto.
Qed.
Lemma ordinary_step:
  forall s ts f sp pc rs m t S', list_forall2 match_frames s ts ->
  step ge (State s f sp pc rs m) t S' ->
  exists k' T', plus step tge (State ts (transf_function f) sp pc rs m) t T' /\ match_states k' S' T'.
Proof.
  intros s ts f sp pc rs m t S' STACK STEP. inv STEP;
    match goal with C: (fn_code f)!pc = Some ?i |- _ =>
      pose proof (code_translated f pc i C) as CODE; cbn [transf_instr] in CODE end.
  - destruct (shortcut_sound lookahead f None pc' rs m I) as [k P].
    exists k. eexists; split. apply plus_one. eapply exec_Inop. exact CODE. constructor; auto.
  - destruct (shortcut_sound lookahead f None pc' (rs#res <- v) m I) as [k P].
    exists k. eexists; split. apply plus_one. eapply exec_Iop. exact CODE.
    match goal with E: eval_operation _ _ _ _ _ = _ |- _ => rewrite <- E end.
    apply eval_operation_preserved. exact symbols_preserved. constructor; auto.
  - destruct (shortcut_sound lookahead f None pc' (rs#dst <- v) m I) as [k P].
    exists k. eexists; split. apply plus_one. eapply exec_Iload. exact CODE.
    match goal with E: eval_addressing _ _ _ _ = _ |- _ => rewrite <- E end.
    apply eval_addressing_preserved. exact symbols_preserved. eauto. constructor; auto.
  - destruct (shortcut_sound lookahead f None pc' rs m' I) as [k P].
    exists k. eexists; split. apply plus_one. eapply exec_Istore. exact CODE.
    match goal with E: eval_addressing _ _ _ _ = _ |- _ => rewrite <- E end.
    apply eval_addressing_preserved. exact symbols_preserved. eauto. constructor; auto.
  - exists O. eexists; split. apply plus_one.
    eapply exec_Icall with (fd := Thread.transf_fundef fd). exact CODE.
    eapply find_function_translated; eauto. rewrite sig_preserved; auto.
    constructor. constructor; auto. constructor.
  - exists O. eexists; split. apply plus_one.
    eapply exec_Itailcall with (fd := Thread.transf_fundef fd). exact CODE.
    eapply find_function_translated; eauto. rewrite sig_preserved; auto. eauto. constructor; auto.
  - destruct (shortcut_sound lookahead f None pc' (regmap_setres res vres rs) m' I) as [k P].
    exists k. eexists; split. apply plus_one. eapply exec_Ibuiltin. exact CODE.
    eapply eval_builtin_args_preserved with (ge1 := ge); eauto. exact symbols_preserved.
    eapply external_call_symbols_preserved; eauto. apply senv_preserved. constructor; auto.
  - assert (VALID: valid_known (Some (cond,args,b)) rs m) by assumption.
    destruct (shortcut_sound lookahead f (Some (cond,args,b)) (if b then ifso else ifnot) rs m VALID) as [k P].
    exists k. eexists; split. apply plus_one. eapply exec_Icond. exact CODE. eauto. reflexivity.
    destruct b; constructor; auto.
  - destruct (shortcut_sound lookahead f None pc' rs m I) as [k P].
    exists k. eexists; split. apply plus_one. eapply exec_Ijumptable. exact CODE. eauto.
    rewrite list_nth_z_map. match goal with N: list_nth_z _ _ = _ |- _ => rewrite N end. reflexivity.
    constructor; auto.
  - exists O. eexists; split. apply plus_one. eapply exec_Ireturn. exact CODE. eauto.
    constructor; auto.
Qed.
Lemma step_simulation:
  forall S t S', step ge S t S' -> forall k T, match_states k S T -> simulation k S t S' T.
Proof.
  intros S t S' STEP k T MATCH. inv MATCH.
  - destruct k as [|k].
    + inv H0. destruct (ordinary_step _ _ _ _ _ _ _ _ _ H STEP) as (k' & T' & RUN & M).
      exists k', T'; auto.
    + eapply skipped_step; eauto.
  - inv STEP.
    + destruct (shortcut_sound lookahead f None (fn_entrypoint f) (init_regs args (fn_params f)) m' I) as [k P].
      exists k. eexists; split. left. apply plus_one. eapply exec_function_internal; eauto. constructor; auto.
    + exists O. eexists; split. left. apply plus_one. eapply exec_function_external.
      eapply external_call_symbols_preserved; eauto. apply senv_preserved. constructor; auto.
  - inv STEP. match goal with ST: list_forall2 _ (_ :: _) _ |- _ => inv ST end.
    match goal with F: match_frames _ _ |- _ => inv F end.
    destruct (shortcut_sound lookahead f None pc (rs#res <- v) m I) as [k P].
    exists k. eexists; split. left. apply plus_one. constructor. constructor; auto.
Qed.
Lemma initial_states:
  forall S, RTL.initial_state prog S -> exists k T, RTL.initial_state tprog T /\ match_states k S T.
Proof.
  intros S INIT. inv INIT. exists O. eexists; split. econstructor.
  eapply (Genv.init_mem_transf TRANSL); eauto.
  rewrite symbols_preserved. replace (prog_main tprog) with (prog_main prog). eauto.
  symmetry. eapply match_program_main; eauto.
  eapply function_ptr_translated; eauto. rewrite sig_preserved; eauto. constructor. constructor.
Qed.
Theorem transf_program_correct:
  forward_simulation (RTL.semantics prog) (RTL.semantics tprog).
Proof.
  apply Forward_simulation with lt match_states. constructor.
  apply lt_wf. exact initial_states.
  intros k S T r MATCH FINAL. inv FINAL. inv MATCH.
  match goal with ST: list_forall2 _ nil _ |- _ => inv ST end. constructor.
  exact step_simulation. apply senv_preserved.
Qed.
End PRESERVATION.
End ThreadCorrect.

(** * Arithmetic and pending sums *)

Lemma eval_int_add_operation:
  forall (F V: Type) (ge: Genv.t F V) sp m x y,
  eval_operation ge sp int_add_operation (Vint x :: Vint y :: nil) m =
  Some (Vint (Int.add x y)).
Proof.
  intros. unfold int_add_operation. simpl.
  rewrite Int.add_zero. reflexivity.
Qed.

Definition integer_value (v: val) : Prop :=
  match v with Vundef | Vint _ => True | _ => False end.

Lemma integer_value_tint:
  forall v, Archi.ptr64 = true -> Val.has_type v Tint -> integer_value v.
Proof. destruct v; simpl; intros; auto; congruence. Qed.


Lemma integer_add:
  forall a b, integer_value a -> integer_value b -> integer_value (Val.add a b).
Proof. destruct a, b; simpl; tauto. Qed.

Lemma integer_add_zero:
  forall v, integer_value v -> Val.add (Vint Int.zero) v = v.
Proof.
  destruct v; simpl; intros; try contradiction; auto.
  rewrite Int.add_zero_l. reflexivity.
Qed.

Lemma integer_add_assoc:
  forall a b c, integer_value a -> integer_value b -> integer_value c ->
  Val.add (Val.add a b) c = Val.add a (Val.add b c).
Proof.
  destruct a, b, c; simpl; intros; try contradiction; auto.
  rewrite Int.add_assoc. reflexivity.
Qed.

Lemma integer_add_commut:
  forall a b, integer_value a -> integer_value b -> Val.add a b = Val.add b a.
Proof.
  destruct a, b; simpl; intros; try contradiction; auto.
  rewrite Int.add_commut. reflexivity.
Qed.

Definition pending_value (pending: option val) : val :=
  match pending with None => Vint Int.zero | Some a => a end.

Definition apply_pending (pending: option val) (v: val) : val :=
  match pending with None => v | Some a => Val.add a v end.

Definition pending_integer (pending: option val) : Prop :=
  integer_value (pending_value pending).

Lemma apply_pending_integer:
  forall pending v, pending_integer pending -> integer_value v ->
  apply_pending pending v = Val.add (pending_value pending) v.
Proof.
  destruct pending; simpl; intros; auto. symmetry. apply integer_add_zero; auto.
Qed.

Lemma pending_push:
  forall pending saved v,
  pending_integer pending -> integer_value saved -> integer_value v ->
  apply_pending (Some (Val.add (pending_value pending) saved)) v =
  apply_pending pending (Val.add saved v).
Proof.
  intros. rewrite (apply_pending_integer pending (Val.add saved v))
    by auto using integer_add.
  simpl. apply integer_add_assoc; auto.
Qed.

(** The target operands may be more defined than the source operands.
    In particular an undefined source operand does not justify assuming
    an integer target operand. *)
Lemma eval_add_inject:
  forall (F V: Type) (ge: Genv.t F V) sp m j a b a' b',
  integer_value a -> integer_value b ->
  Val.inject j a a' -> Val.inject j b b' ->
  exists v', eval_operation ge sp int_add_operation (a' :: b' :: nil) m = Some v' /\
    Val.inject j (Val.add a b) v'.
Proof.
  intros. destruct a, b; simpl in *; try contradiction.
  - eexists; split; [reflexivity|constructor].
  - eexists; split; [reflexivity|constructor].
  - eexists; split; [reflexivity|constructor].
  - inv H1. inv H2. exists (Vint (Int.add i i0)). split.
    simpl. rewrite Int.add_zero. reflexivity. constructor.
Qed.

Lemma supported_operation_stack:
  forall (ge: genv) sp sp' m op args vl,
  supported_int_operation op args = true ->
  eval_operation ge sp op vl m = eval_operation ge sp' op vl m.
Proof.
  intros ge sp sp' m op args vl SUP.
  destruct op; simpl in SUP; try discriminate; auto.
Qed.

Lemma eval_add_integer:
  forall (F V: Type) (ge: Genv.t F V) sp m a b,
  integer_value a -> integer_value b ->
  eval_operation ge sp int_add_operation (a :: b :: nil) m = Some (Val.add a b).
Proof.
  destruct a, b; simpl; intros; try contradiction; auto.
  rewrite Int.add_zero. reflexivity.
Qed.


(** * Memory injection for eliminated stack frames *)

(** Memory injections permit eliminated, unobservable empty stack blocks. *)

Section GLOBALS.
Variable ge: genv.

Record global_injection (j: meminj) : Prop := {
  global_domain: forall b, Plt b (Genv.genv_next ge) -> j b = Some (b, 0);
  global_image: forall b b' delta,
    j b = Some (b', delta) -> Plt b' (Genv.genv_next ge) -> b = b'
}.

Lemma global_injection_preserves:
  forall j, global_injection j -> meminj_preserves_globals ge j.
Proof.
  intros j [DOMAIN IMAGE]. repeat split; intros.
  - apply DOMAIN. eapply Genv.genv_symb_range; eauto.
  - apply DOMAIN. eapply Genv.genv_defs_range.
    apply Genv.find_var_info_iff; eauto.
  - symmetry. eapply IMAGE; eauto.
    eapply Genv.genv_defs_range. apply Genv.find_var_info_iff; eauto.
Qed.

Lemma global_injection_incr:
  forall j j' m m',
  global_injection j -> inject_incr j j' ->
  inject_separated j j' m m' ->
  Ple (Genv.genv_next ge) (Mem.nextblock m') ->
  global_injection j'.
Proof.
  intros j j' m m' [DOMAIN IMAGE] INCR SEP BOUND.
  constructor; intros.
  - eapply INCR. apply DOMAIN; auto.
  - destruct (j b) as [[b2 delta2]|] eqn:OLD.
    + exploit INCR; eauto. intro EQ. rewrite H in EQ. inv EQ. eauto.
    + exploit SEP; eauto. intros [_ INVALID].
      elim INVALID. unfold Mem.valid_block. extlia.
Qed.

Lemma parallel_alloc_separated:
  forall j j' m m' lo hi sm sb tm tb,
  Mem.inject j m m' ->
  Mem.alloc m lo hi = (sm, sb) -> Mem.alloc m' lo hi = (tm, tb) ->
  j' sb = Some (tb, 0) ->
  (forall b, b <> sb -> j' b = j b) ->
  inject_separated j j' m m'.
Proof.
  intros j j' m m' lo hi sm sb tm tb INJ SRC TGT NEW OTHER.
  red; intros b b' delta OLD MAP.
  destruct (eq_block b sb).
  - subst b. rewrite NEW in MAP. inv MAP.
    split; eauto using Mem.fresh_block_alloc.
  - rewrite OTHER in MAP by auto. congruence.
Qed.

End GLOBALS.

Lemma alloc_unmapped_same_injection:
  forall j m m' sm sb lo hi,
  Mem.inject j m m' -> Mem.alloc m lo hi = (sm, sb) ->
  Mem.inject j sm m'.
Proof.
  intros j m m' sm sb lo hi INJ ALLOC.
  destruct (Mem.alloc_left_unmapped_inject _ _ _ _ _ _ _ INJ ALLOC)
    as (j' & NEW & INCR & NONE & OTHER).
  assert (EQ: j' = j).
  { apply functional_extensionality. intro b.
    destruct (eq_block b sb).
    - subst b. rewrite NONE. symmetry.
      eapply Mem.mi_freeblocks; eauto using Mem.fresh_block_alloc.
    - auto. }
  subst j'. auto.
Qed.

Lemma free_empty_target:
  forall j m m' b,
  Mem.inject j m m' ->
  exists tm, Mem.free m' b 0 0 = Some tm /\ Mem.inject j m tm.
Proof.
  intros. destruct (Mem.range_perm_free m' b 0 0) as [tm FREE].
  red; intros; lia.
  exists tm. split; auto. eapply Mem.free_right_inject; eauto. intros; lia.
Qed.

(** * Additive-continuation specification *)

(** Symbolic additive continuations and their source semantics. *)
Local Open Scope rtl.

Fixpoint sum_terms (rs: regset) (terms: list reg): val :=
  match terms with nil => Vint Int.zero | r :: rest => Val.add rs#r (sum_terms rs rest) end.
Definition integer_terms (rs: regset) (terms: list reg) :=
  forall r, In r terms -> integer_value rs#r.
Lemma terms_head: forall rs r rest, integer_terms rs (r :: rest) -> integer_value rs#r.
Proof. intros. apply H. simpl; auto. Qed.
Lemma terms_tail: forall rs r rest, integer_terms rs (r :: rest) -> integer_terms rs rest.
Proof. unfold integer_terms; auto with coqlib. Qed.
Local Hint Resolve terms_head terms_tail : core.
Lemma sum_integer: forall rs terms, integer_terms rs terms -> integer_value (sum_terms rs terms).
Proof. induction terms; simpl; intros; auto. apply integer_add. apply H; auto with coqlib. apply IHterms. red; intros; apply H; auto with coqlib. Qed.
Lemma integer_add_zero_r:
  forall v, integer_value v -> Val.add v (Vint Int.zero) = v.
Proof. intros. rewrite (integer_add_commut v (Vint Int.zero)) by (simpl; auto). apply integer_add_zero; auto. Qed.
Lemma sum_single: forall rs r, integer_value rs#r -> sum_terms rs (r :: nil) = rs#r.
Proof. intros. simpl. apply integer_add_zero_r; auto. Qed.
Lemma sum_app:
  forall rs a b, integer_terms rs a -> integer_terms rs b ->
  sum_terms rs (a ++ b) = Val.add (sum_terms rs a) (sum_terms rs b).
Proof.
  intros rs a. induction a as [|r rest IH]; intros b A B; simpl.
  - symmetry. apply integer_add_zero. apply sum_integer; auto.
  - rewrite IH; auto. symmetry. apply integer_add_assoc.
    eapply terms_head; eauto. apply sum_integer. eapply terms_tail; eauto.
    apply sum_integer; auto. eapply terms_tail; eauto.
Qed.
Lemma sum_ext:
  forall a rs rs', (forall r, In r a -> rs#r = rs'#r) -> sum_terms rs a = sum_terms rs' a.
Proof. induction a; simpl; intros; auto. rewrite H by auto. rewrite IHa with (rs' := rs'); auto with coqlib. Qed.
Lemma sum_set_substitute:
  forall terms dst repl rs,
  integer_terms rs repl ->
  integer_terms (rs#dst <- (sum_terms rs repl)) terms ->
  sum_terms rs (substitute dst repl terms) = sum_terms (rs#dst <- (sum_terms rs repl)) terms.
Proof.
  induction terms as [|r rest IH]; intros; simpl; auto.
  unfold substitute in *. simpl. destruct (peq r dst) as [EQ|NE].
  - subst r. rewrite sum_app; auto.
    rewrite IH; try (red; auto with coqlib). simpl. rewrite Regmap.gss. reflexivity.
    red; intros x IN. apply in_flat_map in IN. destruct IN as (y & Y & IN).
    destruct (peq y dst); auto. simpl in IN. destruct IN as [EQ|[]]; subst x.
    specialize (H0 y (or_intror Y)). rewrite Regmap.gso in H0; auto.
  - simpl. rewrite Regmap.gso by auto. rewrite IH; auto. red; auto with coqlib.
Qed.
Lemma sum_permutation:
  forall a b, Permutation a b -> forall rs, integer_terms rs a -> sum_terms rs a = sum_terms rs b.
Proof.
  induction 1; intros; simpl; auto.
  - rewrite IHPermutation; auto. red; auto with coqlib.
  - assert (X: integer_value rs#x) by (apply H; simpl; auto).
    assert (Y: integer_value rs#y) by (apply H; simpl; auto).
    assert (REST: integer_terms rs l) by (red; intros; apply H; simpl; auto).
    rewrite <- ! integer_add_assoc by auto using sum_integer.
    rewrite (integer_add_commut (rs#y) (rs#x)); auto.
  - rewrite IHPermutation1; auto. apply IHPermutation2. red; intros.
    apply H1. eapply Permutation_in; [apply Permutation_sym; eauto|eauto].
Qed.
Lemma remove_once_sound:
  forall terms r saved, remove_once r terms = Some saved ->
  Permutation terms (r :: saved) /\ ~In r saved.
Proof.
  induction terms as [|x xs IH]; intros; simpl in H; try discriminate.
  destruct (peq x r) as [EQ|NE].
  - subst x. destruct (existsb (fun y => if peq y r then true else false) xs) eqn:REST; try discriminate. injection H as EQ; subst saved.
    split; auto. intro IN. assert (existsb (fun y => if peq y r then true else false) xs = true).
    { apply existsb_exists. exists r; split; auto. destruct (peq r r); congruence. }
    congruence.
  - destruct (remove_once r xs) as [ys|] eqn:REST; try discriminate. injection H as EQ; subst saved.
    destruct (IH _ _ REST) as [P N]. split; simpl; auto.
    eapply Permutation_trans. apply perm_skip; eauto. apply perm_swap. intuition.
Qed.
Lemma restored_sum:
  forall terms r saved rs v,
  remove_once r terms = Some saved -> integer_terms rs saved -> integer_value v ->
  sum_terms (rs#r <- v) terms = Val.add (sum_terms rs saved) v.
Proof.
  intros. destruct (remove_once_sound _ _ _ H) as [PERM NE].
  assert (SAME: sum_terms (rs#r <- v) saved = sum_terms rs saved).
  { apply sum_ext. intros. rewrite Regmap.gso; auto. intro EQ; subst; auto. }
  rewrite (sum_permutation _ _ PERM). simpl. rewrite Regmap.gss, SAME.
  apply integer_add_commut; auto using sum_integer.
  red; intros x IN. apply (Permutation_in x PERM) in IN. simpl in IN.
  destruct IN as [EQ|IN]; subst; [rewrite Regmap.gss; auto|].
  rewrite Regmap.gso; auto. intro EQ; subst; auto.
Qed.

Inductive additive_suffix (f: function): nat -> node -> list reg -> Prop :=
| suffix_return: forall pc r,
    (fn_code f)!pc = Some (Ireturn (Some r)) -> additive_suffix f 1%nat pc (r :: nil)
| suffix_add: forall k pc next lhs rhs dst terms,
    (fn_code f)!pc = Some (Iop int_add_operation (lhs :: rhs :: nil) dst next) ->
    additive_suffix f k next terms ->
    additive_suffix f (S k) pc (substitute dst (lhs :: rhs :: nil) terms).
Lemma additive_terms_sound:
  forall fuel f pc terms, additive_terms fuel f pc = Some terms ->
  exists k, (k <= fuel)%nat /\ additive_suffix f k pc terms.
Proof.
  induction fuel; simpl; intros; try discriminate.
  destruct ((fn_code f)!pc) as [i|] eqn:CODE; try discriminate. destruct i; try discriminate.
  - destruct l as [|a l]; try discriminate. destruct l as [|b l]; try discriminate.
    destruct l; try discriminate. destruct (eq_operation o int_add_operation); try discriminate; subst o.
    destruct (additive_terms fuel f n) as [ts|] eqn:REC; try discriminate.
    destruct (Nat.leb (length (substitute r (a :: b :: nil) ts)) 9); inv H.
    destruct (IHfuel _ _ _ REC) as (k & B & SUF).
    exists (S k). split; [lia|eapply suffix_add; eauto].
  - destruct o; inv H. exists 1%nat. split; [lia|constructor; auto].
Qed.
Lemma substitute_in:
  forall dst repl terms r, In r (substitute dst repl terms) ->
  In r repl \/ (In r terms /\ r <> dst).
Proof.
  unfold substitute; intros. apply in_flat_map in H. destruct H as (x & IN & CHOICE).
  destruct (peq x dst); auto. simpl in CHOICE. destruct CHOICE as [EQ|[]]; subst; auto.
Qed.
Lemma suffix_bounds:
  forall f k pc terms, additive_suffix f k pc terms ->
  forall r, In r terms -> (r <= max_reg_function f)%positive.
Proof.
  induction 1; intros.
  - simpl in H0. destruct H0 as [EQ|[]]; subst.
    eapply max_reg_function_use; eauto. simpl; auto.
  - apply substitute_in in H1. destruct H1 as [IN|[IN NE]]; eauto.
    eapply max_reg_function_use; eauto.
Qed.
Lemma suffix_types:
  forall f k pc terms, additive_suffix f k pc terms ->
  forall env, wt_function f env -> sig_res (fn_sig f) = Xint ->
  forall r, In r terms -> env r = Tint.
Proof.
  induction 1; intros env WT SIG r0 IN.
  - simpl in IN. destruct IN as [EQ|[]]; subst.
    pose proof (wt_instr_at _ _ _ _ WT H) as TI. inv TI.
    unfold proj_sig_res in *. rewrite SIG in *. auto.
  - apply substitute_in in IN. destruct IN as [IN|[IN NE]]; eauto.
    pose proof (wt_instr_at _ _ _ _ WT H) as TI. inv TI.
    simpl in IN. destruct IN as [EQ|[EQ|[]]]; subst;
      match goal with T: map env (_ :: _ :: nil) = _ |- _ => simpl in T; inversion T; auto end.
Qed.

Fixpoint suffix_length (fuel: nat) (f: function) (pc: node): nat :=
  match fuel with
  | O => O
  | S fuel' => match (fn_code f)!pc with
    | Some (Ireturn _) => 1%nat
    | Some (Iop _ _ _ next) => S (suffix_length fuel' f next)
    | _ => O end
  end.
Lemma suffix_length_bound:
  forall fuel f pc, (suffix_length fuel f pc <= fuel)%nat.
Proof. induction fuel; simpl; intros; auto. destruct ((fn_code f)!pc) as [i|]; auto. destruct i; simpl; auto with arith. all: lia. Qed.
Lemma suffix_length_exact:
  forall f k pc terms, additive_suffix f k pc terms ->
  forall fuel, (k <= fuel)%nat -> suffix_length fuel f pc = k.
Proof.
  induction 1; intros fuel B; destruct fuel; try lia; simpl; rewrite H; auto.
  rewrite IHadditive_suffix; auto; lia.
Qed.

Lemma additive_suffix_step:
  forall ge f k pc terms s stk rs m t S',
  additive_suffix f k pc terms ->
  (exists env, wt_function f env /\ wt_regset env rs) ->
  Archi.ptr64 = true -> sig_res (fn_sig f) = Xint ->
  step ge (State s f (Vptr stk Ptrofs.zero) pc rs m) t S' ->
  (exists k' pc' terms' rs', t = E0 /\
    S' = State s f (Vptr stk Ptrofs.zero) pc' rs' m /\ (k' < k)%nat /\
    additive_suffix f k' pc' terms' /\ sum_terms rs terms = sum_terms rs' terms') \/
  (exists m', t = E0 /\ S' = Returnstate s (sum_terms rs terms) m' /\
    Mem.free m stk 0 (fn_stacksize f) = Some m').
Proof.
  intros ge f k pc terms s stk rs m t S' SUF [env [WT REGS]] BITS SIG STEP.
  inv SUF; inv STEP; try congruence;
    match goal with A: (fn_code f)!pc = Some _, B: (fn_code f)!pc = Some _ |- _ => rewrite A in B; inv B end.
  - right. exists m'. repeat split; auto. simpl. rewrite integer_add_zero_r; auto.
    assert (T: env r = Tint).
    { eapply suffix_types; eauto. constructor; eauto. simpl; auto. }
    eapply integer_value_tint; eauto. rewrite <- T. apply REGS.
  - assert (T: env lhs = Tint /\ env rhs = Tint).
    { pose proof (wt_instr_at _ _ _ _ WT H) as TI. inv TI.
      match goal with T: map env (_ :: _ :: nil) = _ |- _ => simpl in T; inversion T; auto end. }
    destruct T as [TL TR].
    assert (L: integer_value rs#lhs) by (eapply integer_value_tint; eauto; rewrite <- TL; apply REGS).
    assert (R: integer_value rs#rhs) by (eapply integer_value_tint; eauto; rewrite <- TR; apply REGS).
    match goal with E: eval_operation _ _ _ _ _ = _ |- _ =>
      change (eval_operation ge (Vptr stk Ptrofs.zero) int_add_operation (rs#lhs :: rs#rhs :: nil) m = Some v) in E;
      rewrite eval_add_integer in E by auto; inv E end.
    left. exists k0. eexists. exists terms0. eexists. repeat split; auto; try lia.
    replace (Val.add rs#lhs rs#rhs) with (sum_terms rs (lhs :: rhs :: nil)).
    apply sum_set_substitute. red; simpl; intros; intuition congruence.
    red; intros r IN. rewrite Regmap.gsspec. destruct (peq r res).
    + simpl. rewrite integer_add_zero_r by exact R. apply integer_add; auto.
    + eapply integer_value_tint; eauto. rewrite <- (suffix_types _ _ _ _ H0 env WT SIG r IN). apply REGS.
    + simpl. rewrite integer_add_zero_r; auto.
Qed.

(** * Soundness of recognition *)

(** Soundness and basic bounds of the additive-continuation analyzer. *)

Record site_spec (self: ident) (f: function) (pc: node) (c: site): Prop := {
  site_call: (fn_code f)!pc = Some (Icall (fn_sig f) (inr self) (call_args c) (call_result c) (call_next c));
  site_arity: length (call_args c) = length (fn_params f);
  site_suffix: exists terms k, additive_terms suffix_fuel f (call_next c) = Some terms /\
    remove_once (call_result c) terms = Some (saved_terms c) /\
    (k <= suffix_fuel)%nat /\ additive_suffix f k (call_next c) terms;
  site_nonempty: saved_terms c <> nil;
  site_length: (length (site_operations f c) <= 32)%nat
}.
Lemma find_site_sound:
  forall self f pc c, find_site self f pc = Some c -> site_spec self f pc c.
Proof.
  intros self f pc c FIND. unfold find_site in FIND.
  destruct (raw_site self f pc) as [d|] eqn:RAW; try discriminate.
  destruct (Nat.leb (length (site_operations f d)) 32) eqn:LEN; inv FIND.
  apply Nat.leb_le in LEN. unfold raw_site in RAW.
  destruct ((fn_code f)!pc) as [i|] eqn:CODE; try discriminate.
  destruct i; try discriminate. destruct s0; try discriminate.
  destruct (ident_eq self i); try discriminate; subst i.
  destruct (signature_eq s (fn_sig f)); try discriminate; subst s.
  destruct (Nat.eqb (length l) (length (fn_params f))) eqn:ARITY; try discriminate.
  apply Nat.eqb_eq in ARITY.
  destruct (additive_terms suffix_fuel f n) as [terms|] eqn:SUF; try discriminate.
  destruct (remove_once r terms) as [saved|] eqn:REMOVE; try discriminate.
  destruct saved as [|a rest]; try discriminate.
  destruct (Nat.leb (length (a :: rest)) 8); inv RAW.
  constructor; simpl; auto; try discriminate.
  destruct (additive_terms_sound _ _ _ _ SUF) as (k & B & S).
  exists terms, k; auto.
Qed.
Lemma saved_bound:
  forall self f pc c r, site_spec self f pc c -> In r (saved_terms c) ->
  (r <= max_reg_function f)%positive.
Proof.
  intros. destruct (site_suffix _ _ _ _ H) as (terms & k & SCAN & RM & B & SUF).
  destruct (remove_once_sound _ _ _ RM) as [PERM N].
  eapply suffix_bounds; eauto. eapply Permutation_in. apply Permutation_sym; exact PERM. simpl; auto.
Qed.
Lemma saved_type:
  forall self f pc c env, site_spec self f pc c -> wt_function f env ->
  sig_res (fn_sig f) = Xint -> forall r, In r (saved_terms c) -> env r = Tint.
Proof.
  intros. destruct (site_suffix _ _ _ _ H) as (terms & k & SCAN & RM & B & SUF).
  destruct (remove_once_sound _ _ _ RM) as [PERM N]. eapply suffix_types; eauto.
  eapply Permutation_in. apply Permutation_sym; exact PERM. simpl; auto.
Qed.
Record function_spec (self: ident) (f: function): Prop := {
  spec_bits: Archi.ptr64 = true;
  spec_sig: fn_sig f = int_signature (fn_params f);
  spec_stack: fn_stacksize f = 0;
  spec_params: list_norepet (fn_params f);
  spec_params_bound: (1 <= length (fn_params f) <= 8)%nat;
  spec_instructions: forall pc i, (fn_code f)!pc = Some i -> supported self f i = true
}.
Lemma eligible_sound:
  forall self f, AccumRec.eligible self f = true -> function_spec self f.
Proof.
  intros self f EL. unfold AccumRec.eligible in EL.
  destruct Archi.ptr64 eqn:BITS; try discriminate.
  destruct (signature_eq (fn_sig f) (int_signature (fn_params f))); try discriminate.
  destruct (zeq (fn_stacksize f) 0); try discriminate.
  destruct (list_norepet_dec peq (fn_params f)); try discriminate.
  repeat rewrite andb_true_iff in EL. destruct EL as [[[[LOW HIGH] ENTRY] ALL] SOME].
  apply Nat.leb_le in LOW. apply Nat.leb_le in HIGH. constructor; auto.
  intros pc i CODE. apply forallb_forall with (x := (pc,i)) in ALL.
  apply andb_true_iff in ALL; tauto. apply PTree.elements_correct; auto.
Qed.
Lemma signature_preserved:
  forall self f, fn_sig (AccumRec.transf_function self f) = fn_sig f.
Proof. intros; unfold AccumRec.transf_function; destruct (AccumRec.eligible self f); reflexivity. Qed.
Lemma supported_call:
  forall self f sg ros args res next, supported self f (Icall sg ros args res next) = true ->
  ros = inr self /\ sg = fn_sig f /\ length args = length (fn_params f).
Proof.
  intros. destruct ros; try discriminate. simpl in H.
  destruct (ident_eq i self); try discriminate.
  destruct (signature_eq sg (fn_sig f)); try discriminate.
  apply Nat.eqb_eq in H; intuition congruence.
Qed.
Lemma noncall_not_site:
  forall self f pc i, (fn_code f)!pc = Some i ->
  (match i with Icall _ _ _ _ _ => False | _ => True end) -> find_site self f pc = None.
Proof.
  intros. destruct (find_site self f pc) as [c|] eqn:SITE; auto.
  pose proof (site_call _ _ _ _ (find_site_sound _ _ _ _ SITE)) as C.
  rewrite H in C. inv C. contradiction.
Qed.
Lemma site_operations_nonempty:
  forall self f pc c, site_spec self f pc c -> site_operations f c <> nil.
Proof.
  intros. unfold site_operations. destruct (saved_terms c) eqn:SAVED; simpl; try discriminate.
  exfalso. eapply site_nonempty; eauto.
Qed.
Lemma rejected_function_unchanged:
  forall self f, AccumRec.eligible self f = false -> AccumRec.transf_function self f = f.
Proof. intros; unfold AccumRec.transf_function; rewrite H; auto. Qed.

(** * Generated instructions and local execution *)

(** Disjoint instruction blocks and execution of generated straight-line code. *)
Local Open Scope rtl.

Lemma aux_nat:
  forall pc index, Pos.to_nat (aux_pc pc index) = (64 * Pos.to_nat pc + 2 * index + 1)%nat.
Proof. intros; unfold aux_pc; rewrite Nat2Pos.id; lia. Qed.
Lemma body_nat:
  forall pc, Pos.to_nat (body_pc pc) = (2 * Pos.to_nat pc)%nat.
Proof. intros; unfold body_pc. rewrite Pos2Nat.inj_xO. reflexivity. Qed.
Lemma aux_body_distinct:
  forall pc i q, aux_pc pc i <> body_pc q.
Proof. intros pc i q EQ. apply (f_equal Pos.to_nat) in EQ. rewrite aux_nat, body_nat in EQ. lia. Qed.
Lemma aux_reserved:
  forall pc i, aux_pc pc i <> 1%positive /\ aux_pc pc i <> 3%positive.
Proof.
  intros. generalize (Pos2Nat.is_pos pc); intro POS.
  split; intro EQ; apply (f_equal Pos.to_nat) in EQ; rewrite aux_nat in EQ; simpl in EQ; lia.
Qed.
Lemma aux_injective:
  forall pc i q j, (i < 32)%nat -> (j < 32)%nat ->
  aux_pc pc i = aux_pc q j -> pc = q /\ i = j.
Proof.
  intros. apply (f_equal Pos.to_nat) in H1. rewrite !aux_nat in H1.
  assert (N: Pos.to_nat pc = Pos.to_nat q) by lia.
  split. apply Pos2Nat.inj; auto. lia.
Qed.
Lemma aux_index_injective:
  forall pc i j, aux_pc pc i = aux_pc pc j -> i = j.
Proof. intros. apply (f_equal Pos.to_nat) in H. rewrite !aux_nat in H. lia. Qed.
Lemma install_other:
  forall ops pc start finish code q,
  (forall i, (start <= i < start + length ops)%nat -> q <> aux_pc pc i) ->
  (install_tail pc start ops finish code)!q = code!q.
Proof.
  induction ops; simpl; intros; auto.
  rewrite PTree.gso. apply IHops. intros. apply H; lia. apply H; lia.
Qed.
Lemma install_nth:
  forall ops pc start finish code i op,
  nth_error ops i = Some op ->
  (install_tail pc start ops finish code)!(aux_pc pc (start + i)) =
  Some (operation_at op (if Nat.eqb (S i) (length ops) then finish else aux_pc pc (start + S i))).
Proof.
  induction ops as [|first rest IH]; intros pc start finish code i op NTH; destruct i; simpl in NTH; try discriminate.
  - inv NTH. simpl. rewrite Nat.add_0_r, PTree.gss. destruct rest; simpl; replace (start + 1)%nat with (S start) by lia; reflexivity.
  - simpl. rewrite PTree.gso.
    replace (start + S i)%nat with (S start + i)%nat by lia.
    rewrite (IH pc (S start) finish code i op NTH).
    replace (start + S (S i))%nat with (S start + S i)%nat by lia. reflexivity.
    intro EQ. apply aux_index_injective in EQ. lia.
Qed.
Lemma insert_body_same:
  forall self f code pc i,
  (insert_instruction self f code pc i)!(body_pc pc) = Some (rewrite_instruction self f pc i).
Proof. intros. unfold insert_instruction. apply PTree.gss. Qed.
Lemma insert_body_other:
  forall self f code pc i q, q <> pc ->
  (insert_instruction self f code pc i)!(body_pc q) = code!(body_pc q).
Proof.
  intros. unfold insert_instruction. rewrite PTree.gso by (unfold body_pc; congruence).
  destruct (find_site self f pc); auto. destruct (site_operations f s); auto.
  apply install_other. intros; symmetry; apply aux_body_distinct.
Qed.
Lemma insert_aux_same:
  forall self f code pc instr c ops first i op,
  find_site self f pc = Some c -> site_operations f c = first :: ops -> nth_error ops i = Some op ->
  (insert_instruction self f code pc instr)!(aux_pc pc i) =
  Some (operation_at op (if Nat.eqb (S i) (length ops) then body_pc (fn_entrypoint f) else aux_pc pc (S i))).
Proof.
  intros. unfold insert_instruction. rewrite H, H0.
  rewrite PTree.gso by apply aux_body_distinct. apply (install_nth ops pc 0); auto.
Qed.
Lemma insert_aux_other:
  forall self f code pc instr q j,
  q <> pc -> (j < 32)%nat ->
  (insert_instruction self f code pc instr)!(aux_pc q j) = code!(aux_pc q j).
Proof.
  intros. unfold insert_instruction. rewrite PTree.gso by apply aux_body_distinct.
  destruct (find_site self f pc) as [c|] eqn:SITE; auto.
  pose proof (site_length _ _ _ _ (find_site_sound _ _ _ _ SITE)) as B.
  destruct (site_operations f c) as [|first rest]; auto. simpl in B.
  apply install_other. intros i IN EQ. destruct (aux_injective q j pc i H0 ltac:(lia) EQ); congruence.
Qed.
Lemma code_body:
  forall self f pc i, (fn_code f)!pc = Some i ->
  (rewrite_code self f)!(body_pc pc) = Some (rewrite_instruction self f pc i).
Proof.
  intros self f pc i CODE. unfold rewrite_code.
  rewrite ! PTree.gso by (unfold body_pc; discriminate).
  revert pc i CODE. apply PTree_Properties.fold_rec with
    (P := fun c tc => forall pc i, c!pc = Some i -> tc!(body_pc pc) = Some (rewrite_instruction self f pc i)).
  - intros; apply H0; rewrite H; auto.
  - intros; rewrite PTree.gempty in H; discriminate.
  - intros. rewrite PTree.gsspec in H2. destruct (peq pc k).
    subst pc. inv H2. apply insert_body_same.
    rewrite insert_body_other; eauto.
Qed.
Lemma code_aux:
  forall self f pc instr c first ops j op,
  (fn_code f)!pc = Some instr -> find_site self f pc = Some c ->
  site_operations f c = first :: ops -> nth_error ops j = Some op ->
  (rewrite_code self f)!(aux_pc pc j) =
  Some (operation_at op (if Nat.eqb (S j) (length ops) then body_pc (fn_entrypoint f) else aux_pc pc (S j))).
Proof.
  intros self f pc instr c first ops j op CODE SITE OPS NTH.
  assert (J: (j < 32)%nat).
  { pose proof (site_length _ _ _ _ (find_site_sound _ _ _ _ SITE)) as B.
    rewrite OPS in B. assert (j < length ops)%nat by (apply nth_error_Some; congruence). simpl in B; lia. }
  unfold rewrite_code. rewrite ! PTree.gso by (destruct (aux_reserved pc j); auto).
  revert pc instr c first ops j op CODE SITE OPS NTH J.
  apply PTree_Properties.fold_rec with
    (P := fun code tc => forall pc instr c first ops j op,
      code!pc = Some instr -> find_site self f pc = Some c ->
      site_operations f c = first :: ops -> nth_error ops j = Some op -> (j < 32)%nat ->
      tc!(aux_pc pc j) = Some (operation_at op
        (if Nat.eqb (S j) (length ops) then body_pc (fn_entrypoint f) else aux_pc pc (S j)))).
  - intros. eapply H0; eauto. rewrite H; eauto.
  - intros. rewrite PTree.gempty in H; discriminate.
  - intros. rewrite PTree.gsspec in H2. destruct (peq pc k).
    subst pc. inv H2. eapply insert_aux_same; eauto.
    rewrite insert_aux_other; eauto.
Qed.
Lemma code_init:
  forall self f, (rewrite_code self f)!1%positive =
    Some (Iop (Ointconst Int.zero) nil (accumulator f) (body_pc (fn_entrypoint f))).
Proof. intros. apply PTree.gss. Qed.
Lemma code_exit:
  forall self f, (rewrite_code self f)!3%positive = Some (Ireturn (Some (accumulator f))).
Proof. intros. unfold rewrite_code. rewrite PTree.gso by discriminate. apply PTree.gss. Qed.

Inductive run_operations (ge: genv) (sp: val) (m: mem): list linear_op -> regset -> regset -> Prop :=
| run_nil: forall rs, run_operations ge sp m nil rs rs
| run_cons: forall op args dst rest rs rs' v,
    eval_operation ge sp op rs##args m = Some v ->
    run_operations ge sp m rest (rs#dst <- v) rs' ->
    run_operations ge sp m ((op,args,dst) :: rest) rs rs'.
Lemma run_operations_app:
  forall ge sp m a b rs mid final,
  run_operations ge sp m a rs mid -> run_operations ge sp m b mid final ->
  run_operations ge sp m (a ++ b) rs final.
Proof. induction 1; simpl; intros; eauto using run_operations. Qed.
Lemma operations_exec:
  forall ge sp m ops rs rs', run_operations ge sp m ops rs rs' ->
  forall tf s pc start finish,
  (forall i op, nth_error ops i = Some op ->
    (fn_code tf)!(aux_pc pc (start + i)) = Some (operation_at op
      (if Nat.eqb (S i) (length ops) then finish else aux_pc pc (start + S i)))) ->
  star step ge (State s tf sp (match ops with nil => finish | _ => aux_pc pc start end) rs m) E0
    (State s tf sp finish rs' m).
Proof.
  induction 1; intros; simpl; [apply star_refl|].
  eapply star_left. eapply exec_Iop.
  specialize (H1 0%nat (op,args,dst) eq_refl). simpl in H1. rewrite Nat.add_0_r in H1. exact H1.
  exact H.
  destruct rest as [|head tail] eqn:REST.
  - inv H0. apply star_refl.
  - simpl. replace (start + 1)%nat with (S start) by lia. apply IHrun_operations with (pc := pc) (start := S start).
    intros i instr NTH. specialize (H1 (S i) instr NTH). simpl in H1.
    replace (start + S i)%nat with (S start + i)%nat in H1 by lia.
    replace (start + S (S i))%nat with (S start + S i)%nat in H1 by lia. exact H1.
  - reflexivity.
Qed.
Lemma site_exec:
  forall ge self f tf pc instr c s sp m rs rs',
  fn_code tf = rewrite_code self f -> (fn_code f)!pc = Some instr ->
  find_site self f pc = Some c -> run_operations ge sp m (site_operations f c) rs rs' ->
  plus step ge (State s tf sp (body_pc pc) rs m) E0
    (State s tf sp (body_pc (fn_entrypoint f)) rs' m).
Proof.
  intros ge self f tf pc instr c s sp m rs rs' TARGET CODE SITE RUN.
  assert (NE: site_operations f c <> nil) by (eapply site_operations_nonempty; eapply find_site_sound; eauto).
  destruct (site_operations f c) as [|[[op args] dst] rest] eqn:OPS; try contradiction.
  inversion RUN as [|op0 args0 dst0 rest0 rs0 rs1 v EVAL TAIL]; subst.
  eapply plus_left. eapply exec_Iop.
  rewrite TARGET, (code_body self f pc instr CODE). unfold rewrite_instruction. rewrite SITE, OPS. reflexivity.
  exact EVAL.
  eapply operations_exec with (pc := pc) (start := 0%nat); eauto.
  intros. rewrite TARGET. eapply code_aux; eauto.
  reflexivity.
Qed.

(** * Register agreement and parallel moves *)

(** Original-register agreement, accumulator sums and verified parallel moves. *)
Local Open Scope rtl.

Definition original_reg (f: function) (r: reg) := (r <= max_reg_function f)%positive.
Definition agree_regs (j: meminj) (f: function) (rs tr: regset) :=
  forall r, original_reg f r -> Val.inject j rs#r tr#r.
Lemma original_used:
  forall f pc i r, (fn_code f)!pc = Some i -> In r (instr_uses i) -> original_reg f r.
Proof. intros. unfold original_reg. pose proof (max_reg_function_use _ _ _ _ H H0). extlia. Qed.
Lemma original_defined:
  forall f pc i r, (fn_code f)!pc = Some i -> instr_defs i = Some r -> original_reg f r.
Proof. intros. unfold original_reg. pose proof (max_reg_function_def _ _ _ _ H H0). extlia. Qed.
Lemma original_parameter:
  forall f r, In r (fn_params f) -> original_reg f r.
Proof. intros. unfold original_reg. pose proof (max_reg_function_params _ _ H). extlia. Qed.
Lemma accumulator_fresh:
  forall f r, original_reg f r -> r <> accumulator f.
Proof. unfold original_reg, accumulator, AccumRec.accumulator; intros; extlia. Qed.
Lemma temporary_fresh:
  forall f r i, original_reg f r -> r <> temporary f i.
Proof.
  intros f r i R EQ. apply (f_equal Pos.to_nat) in EQ.
  unfold temporary in EQ. rewrite Nat2Pos.id in EQ by lia.
  unfold original_reg in R. apply Pos2Nat.inj_le in R. lia.
Qed.
Lemma temporary_not_accumulator:
  forall f i, accumulator f <> temporary f i.
Proof.
  intros f i EQ. apply (f_equal Pos.to_nat) in EQ.
  unfold temporary, accumulator in EQ.
  rewrite Nat2Pos.id in EQ by lia. rewrite Pos2Nat.inj_succ in EQ. lia.
Qed.
Lemma agree_incr:
  forall j j' f rs tr, inject_incr j j' -> agree_regs j f rs tr -> agree_regs j' f rs tr.
Proof. unfold agree_regs; eauto. Qed.
Lemma agree_set:
  forall j f rs tr r v tv, agree_regs j f rs tr -> Val.inject j v tv ->
  agree_regs j f (rs#r <- v) (tr#r <- tv).
Proof. unfold agree_regs; intros. rewrite !Regmap.gsspec. destruct (peq r0 r); auto. Qed.
Lemma agree_acc:
  forall j f rs tr v, agree_regs j f rs tr -> agree_regs j f rs (tr#(accumulator f) <- v).
Proof. unfold agree_regs; intros. rewrite Regmap.gso; auto. apply accumulator_fresh; auto. Qed.
Lemma agree_args:
  forall j f rs tr args, agree_regs j f rs tr ->
  (forall r, In r args -> original_reg f r) -> Val.inject_list j rs##args tr##args.
Proof. induction args; intros; simpl; constructor; auto with coqlib. Qed.
Lemma init_target_agree:
  forall j args params tr,
  Val.inject_list j args tr##params ->
  forall r, Val.inject j (init_regs args params)#r tr#r.
Proof.
  induction args as [|v args IH]; intros params tr INJ r; destruct params as [|p ps]; simpl; try (rewrite Regmap.gi; constructor).
  inv INJ. rewrite Regmap.gsspec. destruct (peq r p); subst; auto.
Qed.

Fixpoint exec_moves (moves: list (reg * reg)) (rs: regset): regset :=
  match moves with nil => rs | (src,dst) :: rest => exec_moves rest (rs#dst <- (rs#src)) end.
Lemma moves_environment:
  forall moves rs r,
  (exec_moves moves rs)#r = Parmov.exec_seq reg peq val moves (fun r => rs#r) r.
Proof.
  induction moves as [|[src dst] rest IH]; intros; simpl; auto. rewrite IH.
  assert (E: (fun r => (rs#dst <- (rs#src))#r) = Parmov.update reg peq val dst rs#src (fun r => rs#r)).
  { apply extensionality; intro. unfold Parmov.update. rewrite Regmap.gsspec. reflexivity. }
  exact (f_equal (fun e => Parmov.exec_seq reg peq val rest e r) E).
Qed.
Lemma moves_execute:
  forall ge sp m moves rs,
  run_operations ge sp m (map (fun pair => (Omove, fst pair :: nil, snd pair)) moves)
    rs (exec_moves moves rs).
Proof. induction moves as [|[src dst] rest IH]; intros; simpl. apply run_nil. eapply run_cons; [reflexivity|apply IH]. Qed.
Lemma parameter_moves_correct:
  forall f args rs,
  length args = length (fn_params f) -> list_norepet (fn_params f) ->
  (forall r, In r args -> original_reg f r) ->
  let tr := exec_moves (parameter_moves f args) rs in
  tr##(fn_params f) = rs##args /\ tr#(accumulator f) = rs#(accumulator f).
Proof.
  intros f args rs LENGTH UNIQUE ARGS tr.
  set (general_moves := exec_moves
    (Parmov.parmove2 reg peq (fun _ => temporary f 0) args (fn_params f)) rs).
  assert (GENERAL: general_moves##(fn_params f) = rs##args /\
      general_moves#(accumulator f) = rs#(accumulator f)).
  {
  pose proof (Parmov.parmove2_correctness reg peq (fun _ => temporary f 0) val
    args (fn_params f) LENGTH UNIQUE) as CORRECT.
  assert (ARGNT: forall r, In r args -> Parmov.is_not_temp reg (fun _ => temporary f 0) r).
  { intros. unfold Parmov.is_not_temp. intro. apply temporary_fresh; auto. }
  assert (PARAMNT: forall r, In r (fn_params f) -> Parmov.is_not_temp reg (fun _ => temporary f 0) r).
  { intros. unfold Parmov.is_not_temp. intro. apply temporary_fresh. apply original_parameter; auto. }
  destruct (CORRECT ARGNT PARAMNT (fun r => rs#r)) as [PARAMS OTHER].
  split.
  - unfold general_moves. etransitivity; [|exact PARAMS]. apply map_ext. intro r. apply moves_environment.
  - unfold general_moves. rewrite moves_environment. apply OTHER.
    intro IN. pose proof (accumulator_fresh f (accumulator f) (original_parameter _ _ IN)); auto.
    red; intros. apply temporary_not_accumulator.
  }
  unfold tr, parameter_moves.
  destruct args as [|a args]; [exact GENERAL|].
  destruct args as [|b args]; [|exact GENERAL].
  destruct (fn_params f) as [|p params] eqn:PARAMS; [exact GENERAL|].
  destruct params as [|q params]; [|exact GENERAL].
  simpl. rewrite Regmap.gss. split; auto.
  rewrite Regmap.gso; auto.
  apply not_eq_sym. apply accumulator_fresh. apply original_parameter. rewrite PARAMS; simpl; auto.
Qed.

Lemma accumulate_terms_execute:
  forall ge sp m f terms rs tr j pending,
  integer_terms rs terms -> pending_integer pending ->
  (forall r, In r terms -> original_reg f r) ->
  agree_regs j f rs tr -> Val.inject j (pending_value pending) tr#(accumulator f) ->
  exists tr', run_operations ge sp m
    (map (fun r => (int_add_operation, accumulator f :: r :: nil, accumulator f)) terms) tr tr' /\
    agree_regs j f rs tr' /\
    Val.inject j (Val.add (pending_value pending) (sum_terms rs terms)) tr'#(accumulator f).
Proof.
  induction terms as [|r rest IH]; intros rs tr j pending INTS PENDING BOUND AGREE ACC; simpl.
  - exists tr. split; [constructor|]. split; auto.
    rewrite integer_add_zero_r; auto.
  - assert (R: integer_value rs#r) by (apply INTS; simpl; auto).
    destruct (eval_add_inject _ _ ge sp m j (pending_value pending) rs#r
      tr#(accumulator f) tr#r PENDING R ACC (AGREE r ltac:(apply BOUND; simpl; auto)))
      as (value & EVAL & INJECT).
    destruct (IH rs (tr#(accumulator f) <- value) j
      (Some (Val.add (pending_value pending) rs#r))) as (tr' & RUN & AGREES & SUM).
    eapply terms_tail; eauto. red; simpl. apply integer_add; auto.
    intros; apply BOUND; simpl; auto. apply agree_acc; auto. rewrite Regmap.gss; exact INJECT.
    exists tr'. split. econstructor; eauto. split; auto.
    simpl in SUM. rewrite integer_add_assoc in SUM; auto using sum_integer.
    apply sum_integer. eapply terms_tail; eauto.
Qed.

Lemma site_operations_execute:
  forall ge self f pc c sp m rs tr j pending,
  site_spec self f pc c -> function_spec self f ->
  integer_terms rs (saved_terms c) -> pending_integer pending ->
  agree_regs j f rs tr -> Val.inject j (pending_value pending) tr#(accumulator f) ->
  exists tr', run_operations ge sp m (site_operations f c) tr tr' /\
    agree_regs j f (init_regs rs##(call_args c) (fn_params f)) tr' /\
    Val.inject j (Val.add (pending_value pending) (sum_terms rs (saved_terms c))) tr'#(accumulator f).
Proof.
  intros ge self f pc c sp m rs tr j pending SITE FN INTS PI AGREE ACC.
  assert (SAVED: forall r, In r (saved_terms c) -> original_reg f r)
    by (intros; eapply saved_bound; eauto).
  assert (ARGS: forall r, In r (call_args c) -> original_reg f r).
  { intros. eapply original_used. apply (site_call _ _ _ _ SITE). simpl; auto. }
  destruct (accumulate_terms_execute ge sp m f (saved_terms c) rs tr j pending INTS PI SAVED AGREE ACC)
    as (mid & RUN & AGREE' & ACC').
  exists (exec_moves (parameter_moves f (call_args c)) mid).
  destruct (parameter_moves_correct f (call_args c) mid (site_arity _ _ _ _ SITE)
    (spec_params _ _ FN) ARGS) as [PARAMS ACCS].
  split. unfold site_operations. eapply run_operations_app; eauto using moves_execute.
  split. red; intros. apply init_target_agree. rewrite PARAMS. eapply agree_args; eauto.
  rewrite ACCS; auto.
Qed.

(** * Compilation-unit matching and typing *)

(** Program-level specification, including checked self-symbol resolution
    and the source typing invariant used by semantic preservation. *)

Definition core_match_prog (p tp: program) :=
  match_program
    (fun cu fd tfd => AST.transf_partial_fundef (checked_function cu) fd = OK tfd)
    eq p tp.

Theorem core_transf_program_match:
  forall p tp, transf_program_rec p = OK tp -> core_match_prog p tp.
Proof.
  intros. eapply match_transform_partial_program_contextual; eauto.
Qed.

Lemma contextual_function_cases:
  forall cu f,
  contextual_function cu f = f \/
  exists id,
    (prog_defmap cu)!id = Some (Gfun (Internal f)) /\
    eligible id f = true /\
    contextual_function cu f = transf_function id f.
Proof.
  intros. unfold contextual_function.
  destruct (guess_self f) as [id|]; auto.
  destruct ((prog_defmap cu)!id) as [[fd|gv]|] eqn:DEF; auto.
  destruct fd as [f'|ef]; auto.
  destruct (function_eq f f'); auto. subst f'.
  destruct (eligible id f) eqn:EL.
  - right. exists id. auto.
  - left. apply rejected_function_unchanged; auto.
Qed.

Lemma checked_function_sig:
  forall cu f tf, checked_function cu f = OK tf -> fn_sig tf = fn_sig f.
Proof.
  intros. unfold checked_function in H.
  destruct (type_function f); try discriminate. inv H.
  destruct (contextual_function_cases cu f) as [EQ|[id [DEF [EL EQ]]]];
    rewrite EQ; auto using signature_preserved.
Qed.

Lemma checked_function_wt:
  forall cu f tf, checked_function cu f = OK tf -> exists env, wt_function f env.
Proof.
  intros. unfold checked_function in H.
  destruct (type_function f) as [env|] eqn:TY; try discriminate.
  exists env. eapply type_function_correct; eauto.
Qed.

Lemma checked_fundef_sig:
  forall cu fd tfd,
  AST.transf_partial_fundef (checked_function cu) fd = OK tfd ->
  funsig tfd = funsig fd.
Proof.
  intros. destruct fd; simpl in H; monadInv H; simpl; auto.
  eapply checked_function_sig; eauto.
Qed.

Section PROGRAM.
Variables prog tprog: program.
Hypothesis TRANSF: core_match_prog prog tprog.
Let ge := Genv.globalenv prog.
Let tge := Genv.globalenv tprog.

Lemma symbols_preserved:
  forall id, Genv.find_symbol tge id = Genv.find_symbol ge id.
Proof (Genv.find_symbol_match TRANSF).

Lemma senv_preserved: Senv.equiv ge tge.
Proof (Genv.senv_match TRANSF).

Lemma function_ptr_translated:
  forall b fd, Genv.find_funct_ptr ge b = Some fd ->
  exists cu tfd,
    Genv.find_funct_ptr tge b = Some tfd /\
    AST.transf_partial_fundef (checked_function cu) fd = OK tfd /\
    linkorder cu prog.
Proof (Genv.find_funct_ptr_match TRANSF).

Lemma functions_translated:
  forall v fd, Genv.find_funct ge v = Some fd ->
  exists cu tfd,
    Genv.find_funct tge v = Some tfd /\
    AST.transf_partial_fundef (checked_function cu) fd = OK tfd /\
    linkorder cu prog.
Proof (Genv.find_funct_match TRANSF).

Lemma wt_prog: wt_program prog.
Proof.
  red; intros.
  exploit list_forall2_in_left. eexact (proj1 TRANSF). eauto.
  intros ([id gd] & SAME & IN & MATCH). simpl in *; subst id.
  inv MATCH. destruct f; simpl in *.
  - monadInv H2. destruct (checked_function_wt _ _ _ EQ) as [env WT].
    econstructor; eauto.
  - constructor.
Qed.

Lemma self_resolves:
  forall cu id f rs,
  linkorder cu prog -> (prog_defmap cu)!id = Some (Gfun (Internal f)) ->
  find_function ge (inr id) rs = Some (Internal f).
Proof.
  intros cu id f rs LINK DEF.
  exploit (prog_defmap_linkorder cu prog); eauto.
  intros (gd & DEF' & ORDER). inv ORDER.
  match goal with H: linkorder (Internal _) _ |- _ => inv H end.
  apply Genv.find_def_symbol in DEF'. destruct DEF' as (b & SYMBOL & FUN).
  unfold find_function, ge. rewrite SYMBOL.
  apply Genv.find_funct_ptr_iff. exact FUN.
Qed.
End PROGRAM.

(** * Ordinary instruction injection *)

(** Injection lemmas shared by unchanged and transformed RTL instructions. *)

Section PROGRAM.
Variables prog tprog: program.
Hypothesis TRANSF: core_match_prog prog tprog.
Let ge := Genv.globalenv prog.
Let tge := Genv.globalenv tprog.

Lemma symbol_inject:
  forall j id ofs, global_injection ge j ->
  Val.inject j (Genv.symbol_address ge id ofs) (Genv.symbol_address tge id ofs).
Proof.
  intros. unfold Genv.symbol_address. rewrite (symbols_preserved _ _ TRANSF). fold ge.
  destruct (Genv.find_symbol ge id) as [b|] eqn:FIND; auto.
  econstructor. eapply global_domain; eauto using Genv.genv_symb_range.
  rewrite Ptrofs.add_zero. reflexivity.
Qed.

Lemma stack_inject:
  forall j b b', j b = Some (b', 0) ->
  Val.inject j (Vptr b Ptrofs.zero) (Vptr b' Ptrofs.zero).
Proof. intros; econstructor; eauto. Qed.

Lemma operation_inject:
  forall j m m' sp sp' op args args' v,
  global_injection ge j -> Mem.inject j m m' ->
  Val.inject j sp sp' -> Val.inject_list j args args' ->
  eval_operation ge sp op args m = Some v ->
  exists v', eval_operation tge sp' op args' m' = Some v' /\ Val.inject j v v'.
Proof.
  intros. eapply eval_operation_inj; eauto.
  - intros; eapply Mem.valid_pointer_inject_val; eauto.
  - intros; eapply Mem.weak_valid_pointer_inject_val; eauto.
  - intros; eapply Mem.weak_valid_pointer_inject_no_overflow; eauto.
  - intros; eapply Mem.different_pointers_inject; eauto.
  - intros; apply symbol_inject; auto.
Qed.

Lemma addressing_inject:
  forall j sp sp' addr args args' v,
  global_injection ge j ->
  Val.inject j sp sp' -> Val.inject_list j args args' ->
  eval_addressing ge sp addr args = Some v ->
  exists v', eval_addressing tge sp' addr args' = Some v' /\ Val.inject j v v'.
Proof.
  intros. eapply eval_addressing_inj; eauto.
  intros; apply symbol_inject; auto.
Qed.

Lemma function_inject:
  forall j ros rs rs' fd,
  global_injection ge j ->
  (forall r, Val.inject j rs#r rs'#r) ->
  find_function ge ros rs = Some fd ->
  exists cu tfd, find_function tge ros rs' = Some tfd /\
    AST.transf_partial_fundef (AccumRec.checked_function cu) fd = Errors.OK tfd /\
    linkorder cu prog.
Proof.
  intros j ros rs rs' fd GLOBAL REGS FIND.
  destruct ros as [r|id]; simpl in *.
  - exploit Genv.find_funct_inv; eauto. intros (b & EQ).
    specialize (REGS r). rewrite EQ in REGS, FIND. inv REGS.
    assert (MAP: j b = Some (b, 0)).
    { eapply global_domain; eauto. eapply Genv.genv_defs_range.
      apply Genv.find_funct_ptr_iff. exact FIND. }
    rewrite MAP in H2. inv H2.
    change (exists cu tfd, Genv.find_funct_ptr tge b2 = Some tfd /\
      transf_partial_fundef (AccumRec.checked_function cu) fd = Errors.OK tfd /\ linkorder cu prog).
    eapply function_ptr_translated; eauto.
  - rewrite (symbols_preserved _ _ TRANSF). fold ge.
    destruct (Genv.find_symbol ge id); try discriminate.
    eapply function_ptr_translated; eauto.
Qed.

Lemma external_inject:
  forall ef args m t v m2 j m' args',
  global_injection ge j ->
  external_call ef ge args m t v m2 ->
  Mem.inject j m m' -> Val.inject_list j args args' ->
  exists j' v' tm,
    external_call ef tge args' m' t v' tm /\ Val.inject j' v v' /\
    Mem.inject j' m2 tm /\ inject_incr j j' /\ inject_separated j j' m m'.
Proof.
  intros. exploit external_call_mem_inject; eauto using global_injection_preserves.
  intros (j' & v' & tm & CALL & VINJ & MINJ & _ & _ & INCR & SEP).
  exists j', v', tm. split; [| auto].
  eapply external_call_symbols_preserved; eauto.
  eapply senv_preserved; eauto.
Qed.

Lemma builtin_arg_inject:
  forall rs sp m j rs' sp' m' a v,
  eval_builtin_arg ge (fun r => rs#r) (Vptr sp Ptrofs.zero) m a v ->
  j sp = Some (sp', 0) -> global_injection ge j ->
  (forall r, Val.inject j rs#r rs'#r) -> Mem.inject j m m' ->
  exists v', eval_builtin_arg tge (fun r => rs'#r) (Vptr sp' Ptrofs.zero) m' a v' /\
    Val.inject j v v'.
Proof.
  induction 1; intros SP GL RS MI.
  - exists rs'#x; split; auto. constructor.
  - econstructor; eauto with barg.
  - econstructor; eauto with barg.
  - econstructor; eauto with barg.
  - econstructor; eauto with barg.
  - simpl in H. exploit Mem.load_inject; eauto. rewrite Z.add_0_r.
    intros (v' & A & B). exists v'; auto with barg.
  - econstructor; split; eauto with barg. simpl.
    econstructor; eauto. rewrite Ptrofs.add_zero; auto.
  - assert (Val.inject j (Senv.symbol_address ge id ofs) (Senv.symbol_address tge id ofs)).
    { apply symbol_inject; auto. }
    exploit Mem.loadv_inject; eauto. intros (v' & A & B). exists v'; auto with barg.
  - econstructor; split; eauto with barg. apply symbol_inject; auto.
  - destruct IHeval_builtin_arg1 as (v1' & A1 & B1); eauto.
    destruct IHeval_builtin_arg2 as (v2' & A2 & B2); eauto.
    exists (Val.longofwords v1' v2'); split; auto with barg.
    apply Val.longofwords_inject; auto.
  - destruct IHeval_builtin_arg1 as (v1' & A1 & B1); eauto.
    destruct IHeval_builtin_arg2 as (v2' & A2 & B2); eauto.
    econstructor; split; eauto with barg.
    destruct Archi.ptr64; auto using Val.add_inject, Val.addl_inject.
Qed.

Lemma builtin_args_inject:
  forall rs sp m j rs' sp' m' al vl,
  eval_builtin_args ge (fun r => rs#r) (Vptr sp Ptrofs.zero) m al vl ->
  j sp = Some (sp', 0) -> global_injection ge j ->
  (forall r, Val.inject j rs#r rs'#r) -> Mem.inject j m m' ->
  exists vl', eval_builtin_args tge (fun r => rs'#r) (Vptr sp' Ptrofs.zero) m' al vl' /\
    Val.inject_list j vl vl'.
Proof.
  induction 1; intros.
  - exists (@nil val); split; constructor.
  - exploit builtin_arg_inject; eauto. intros (v' & A & B).
    destruct IHlist_forall2 as (vl' & C & D); eauto.
    exists (v' :: vl'); split; constructor; auto.
Qed.
End PROGRAM.

(** * Simulation of recursive execution *)

(** Complete forward simulation for accumulator recursion.

    [match_stacks] relates ordinary frames one-to-one and folds eliminated
    frames into [pending]. In an optimized function the target accumulator
    injects [pending_value pending]. A kept call saves this invariant in its
    ordinary caller frame and starts the callee with an empty pending sum.

    Source-only allocations and return continuations take zero target steps.
    [measure] strictly decreases on these stuttering steps, so an infinite
    source execution cannot disappear into finitely many target steps.
    [Mem.inject] permits eliminated empty stack blocks to remain unmapped;
    global symbols stay fixed and ordinary memory operations still simulate.
*)

Definition full_agree (j: meminj) (rs rs': regset) :=
  forall r, Val.inject j rs#r rs'#r.

Lemma full_agree_incr:
  forall j j' rs rs', inject_incr j j' -> full_agree j rs rs' -> full_agree j' rs rs'.
Proof. unfold full_agree; eauto. Qed.

Lemma full_agree_args:
  forall j rs rs', full_agree j rs rs' -> forall args, Val.inject_list j rs##args rs'##args.
Proof. induction args; simpl; constructor; auto. Qed.

Lemma full_agree_set:
  forall j rs rs' r v v', full_agree j rs rs' -> Val.inject j v v' ->
  full_agree j (rs#r <- v) (rs'#r <- v').
Proof.
  unfold full_agree; intros. rewrite ! Regmap.gsspec.
  destruct (peq r0 r); auto.
Qed.

Lemma full_agree_init:
  forall j args args', Val.inject_list j args args' -> forall params,
  full_agree j (init_regs args params) (init_regs args' params).
Proof.
  induction 1; intros; destruct params; simpl;
    try (red; intros; rewrite ! Regmap.gi; constructor).
  apply full_agree_set; auto.
Qed.

Definition state_memory (s: state) : mem :=
  match s with State _ _ _ _ _ m | Callstate _ _ _ m | Returnstate _ _ m => m end.

Definition measure (s: state) : nat :=
  match s with
  | State stack f _ pc _ _ => ((suffix_fuel + 2) * length stack + suffix_length suffix_fuel f pc)%nat
  | Callstate stack _ _ _ => ((suffix_fuel + 2) * length stack + S suffix_fuel)%nat
  | Returnstate stack _ _ => ((suffix_fuel + 2) * length stack)%nat
  end.

Section PRESERVATION.
Variables prog tprog: program.
Hypothesis TRANSF: core_match_prog prog tprog.
Let ge := Genv.globalenv prog.
Let tge := Genv.globalenv tprog.

Record optimized (self: ident) (f tf: function): Prop := {
  optimized_eligible: eligible self f = true;
  optimized_target: tf = transf_function self f;
  optimized_self: forall rs, find_function ge (inr self) rs = Some (Internal f)
}.
Lemma optimized_properties:
  forall self f tf, optimized self f tf ->
  fn_sig f = int_signature (fn_params f) /\ fn_stacksize f = 0 /\
  fn_sig tf = fn_sig f /\ fn_params tf = fn_params f /\
  fn_stacksize tf = 0 /\ fn_entrypoint tf = 1%positive /\ fn_code tf = rewrite_code self f.
Proof.
  intros self f tf [EL TARGET SELF]. pose proof (eligible_sound _ _ EL) as SPEC.
  subst tf. unfold transf_function. rewrite EL. simpl.
  repeat split; eauto using spec_sig, spec_stack.
Qed.
Definition translated_fundef (fd tfd: fundef): Prop :=
  exists cu, AST.transf_partial_fundef (checked_function cu) fd = OK tfd /\ linkorder cu prog.
Lemma checked_function_mode:
  forall cu f tf, checked_function cu f = OK tf -> linkorder cu prog ->
  tf = f \/ exists self, optimized self f tf.
Proof.
  intros cu f tf CHECK LINK. unfold checked_function in CHECK.
  destruct (type_function f); try discriminate. inv CHECK.
  destruct (contextual_function_cases cu f) as [SAME|[self [DEF [EL EQ]]]]; auto.
  right. exists self. constructor; auto.
  intro rs. eapply self_resolves; eauto.
Qed.

Inductive match_frames (j: meminj) (pending: option val): stackframe -> stackframe -> Prop :=
  | frame_plain: forall res f stk stk' pc rs rs',
      pending = None -> j stk = Some (stk', 0) -> full_agree j rs rs' ->
      match_frames j pending
        (Stackframe res f (Vptr stk Ptrofs.zero) pc rs)
        (Stackframe res f (Vptr stk' Ptrofs.zero) pc rs')
  | frame_optimized: forall self f tf res stk stk' pc rs rs',
      optimized self f tf -> res <> accumulator f ->
      agree_regs j f rs rs' -> Val.inject j (pending_value pending) rs'#(accumulator f) ->
      match_frames j pending
        (Stackframe res f (Vptr stk Ptrofs.zero) pc rs)
        (Stackframe res tf (Vptr stk' Ptrofs.zero) (body_pc pc) rs').

Inductive match_stacks (j: meminj): list stackframe -> list stackframe -> option val -> Prop :=
  | stacks_nil: match_stacks j nil nil None
  | stacks_normal: forall s s' pending frame frame',
      match_stacks j s s' pending -> match_frames j pending frame frame' ->
      match_stacks j (frame :: s) (frame' :: s') None
  | stacks_eliminated: forall s s' pending f res stk pc rs terms saved,
      match_stacks j s s' pending -> fn_stacksize f = 0 -> Archi.ptr64 = true ->
      sig_res (fn_sig f) = Xint ->
      additive_terms suffix_fuel f pc = Some terms -> remove_once res terms = Some saved ->
      integer_terms rs saved ->
      match_stacks j (Stackframe res f (Vptr stk Ptrofs.zero) pc rs :: s) s'
        (Some (Val.add (pending_value pending) (sum_terms rs saved))).

Lemma match_stacks_integer:
  forall j s s' pending, match_stacks j s s' pending -> pending_integer pending.
Proof.
  induction 1.
  - exact I.
  - exact I.
  - unfold pending_integer, pending_value. apply integer_add; auto using sum_integer.
Qed.

Lemma match_frames_incr:
  forall j j' p fr fr', inject_incr j j' -> match_frames j p fr fr' -> match_frames j' p fr fr'.
Proof.
  intros. inv H0; econstructor; eauto using agree_incr, full_agree_incr.
Qed.

Lemma match_stacks_incr:
  forall j j' s s' p, inject_incr j j' -> match_stacks j s s' p -> match_stacks j' s s' p.
Proof.
  induction 2; econstructor; eauto using match_frames_incr.
Qed.

Inductive match_core (j: meminj): state -> state -> Prop :=
  | core_plain: forall s s' f stk stk' pc rs rs' m m',
      match_stacks j s s' None ->
      j stk = Some (stk', 0) -> full_agree j rs rs' ->
      match_core j (State s f (Vptr stk Ptrofs.zero) pc rs m)
        (State s' f (Vptr stk' Ptrofs.zero) pc rs' m')
  | core_optimized: forall self f tf s s' pending stk stk' pc rs rs' m m',
      optimized self f tf -> match_stacks j s s' pending ->
      agree_regs j f rs rs' -> Val.inject j (pending_value pending) rs'#(accumulator f) ->
      match_core j (State s f (Vptr stk Ptrofs.zero) pc rs m)
        (State s' tf (Vptr stk' Ptrofs.zero) (body_pc pc) rs' m')
  | core_call: forall s s' fd tfd args args' m m',
      translated_fundef fd tfd -> match_stacks j s s' None ->
      Val.inject_list j args args' ->
      match_core j (Callstate s fd args m) (Callstate s' tfd args' m')
  | core_loop_call: forall self f tf s s' pending args stk' rs' m m',
      optimized self f tf -> match_stacks j s s' pending ->
      agree_regs j f (init_regs args (fn_params f)) rs' ->
      Val.inject j (pending_value pending) rs'#(accumulator f) ->
      match_core j (Callstate s (Internal f) args m)
        (State s' tf (Vptr stk' Ptrofs.zero) (body_pc (fn_entrypoint f)) rs' m')
  | core_return: forall s s' pending v v' m m',
      match_stacks j s s' pending -> Val.inject j (apply_pending pending v) v' ->
      match_core j (Returnstate s v m) (Returnstate s' v' m')
  | core_unwind: forall s s' pending f stk pc rs v' m m' k terms,
      match_stacks j s s' pending -> fn_stacksize f = 0 -> Archi.ptr64 = true ->
      sig_res (fn_sig f) = Xint -> additive_suffix f k pc terms -> (k <= suffix_fuel)%nat ->
      Val.inject j (apply_pending pending (sum_terms rs terms)) v' ->
      match_core j (State s f (Vptr stk Ptrofs.zero) pc rs m) (Returnstate s' v' m').

Lemma match_core_incr:
  forall j j' S T, inject_incr j j' -> match_core j S T -> match_core j' S T.
Proof.
  intros. inv H0;
    eauto using core_plain, core_optimized, core_call, core_loop_call, core_return,
      core_unwind, match_stacks_incr, agree_incr, full_agree_incr.
Qed.

Inductive match_states: state -> state -> Prop :=
  | match_states_intro: forall j S T,
      match_core j S T -> wt_state S ->
      Mem.inject j (state_memory S) (state_memory T) ->
      global_injection ge j ->
      Ple (Genv.genv_next ge) (Mem.nextblock (state_memory S)) ->
      Ple (Genv.genv_next ge) (Mem.nextblock (state_memory T)) ->
      match_states S T.

Inductive simulation_result (S: state) (t: trace) (S2 T: state): Prop :=
  | result_steps: forall j' T2,
      plus step tge T t T2 -> match_core j' S2 T2 ->
      Mem.inject j' (state_memory S2) (state_memory T2) ->
      global_injection ge j' -> simulation_result S t S2 T
  | result_stutter: forall j',
      t = E0 -> (measure S2 < measure S)%nat -> match_core j' S2 T ->
      Mem.inject j' (state_memory S2) (state_memory T) ->
      global_injection ge j' -> simulation_result S t S2 T.

Lemma plain_step:
  forall s f stk pc rs m t S2, step ge (State s f (Vptr stk Ptrofs.zero) pc rs m) t S2 ->
  forall j s' stk' rs' m',
  match_stacks j s s' None -> j stk = Some (stk', 0) -> full_agree j rs rs' ->
  Mem.inject j m m' -> global_injection ge j ->
  Ple (Genv.genv_next ge) (Mem.nextblock m') ->
  simulation_result (State s f (Vptr stk Ptrofs.zero) pc rs m) t S2
    (State s' f (Vptr stk' Ptrofs.zero) pc rs' m').
Proof.
  intros s f stk pc rs m t S2 STEP j s' stk' rs' m' STACK SP REGS MI GL BOUND.
  inv STEP.
  - eapply result_steps; [apply plus_one; eapply exec_Inop; eauto| |exact MI|exact GL].
    eapply core_plain; eauto.
  - exploit (operation_inject _ _ TRANSF j m m' (Vptr stk Ptrofs.zero) (Vptr stk' Ptrofs.zero) op rs##args rs'##args v); eauto using stack_inject, full_agree_args.
    intros (v' & EVAL & VI).
    eapply result_steps; [apply plus_one; eapply exec_Iop; eauto| |exact MI|exact GL].
    eapply core_plain; eauto using full_agree_set.
  - exploit (addressing_inject _ _ TRANSF j (Vptr stk Ptrofs.zero) (Vptr stk' Ptrofs.zero) addr rs##args rs'##args a); eauto using stack_inject, full_agree_args.
    intros (a' & EVAL & AI).
    exploit Mem.loadv_inject; eauto. intros (v' & LOAD & VI).
    eapply result_steps; [apply plus_one; eapply exec_Iload; eauto| |exact MI|exact GL].
    eapply core_plain; eauto using full_agree_set.
  - exploit (addressing_inject _ _ TRANSF j (Vptr stk Ptrofs.zero) (Vptr stk' Ptrofs.zero) addr rs##args rs'##args a); eauto using stack_inject, full_agree_args.
    intros (a' & EVAL & AI).
    exploit Mem.storev_mapped_inject; eauto. intros (tm & STORE & MI').
    eapply result_steps; [apply plus_one; eapply exec_Istore; eauto| |exact MI'|exact GL].
    eapply core_plain; eauto.
  - exploit (function_inject _ _ TRANSF); eauto.
    intros (cu & tfd & FIND & CHECK & LINK).
    eapply result_steps.
    + apply plus_one. eapply exec_Icall; eauto.
      rewrite (checked_fundef_sig _ _ _ CHECK); eauto.
    + eapply core_call. exists cu; auto.
      eapply stacks_normal; eauto. eapply frame_plain; eauto.
      apply full_agree_args; auto.
    + exact MI.
    + exact GL.
  - exploit (function_inject _ _ TRANSF); eauto.
    intros (cu & tfd & FIND & CHECK & LINK).
    exploit Mem.free_parallel_inject; eauto.
    rewrite ! Z.add_0_r. intros (tm & FREE & MI').
    eapply result_steps.
    + apply plus_one. eapply exec_Itailcall; eauto.
      rewrite (checked_fundef_sig _ _ _ CHECK); eauto.
    + eapply core_call. exists cu; auto. exact STACK. apply full_agree_args; auto.
    + exact MI'.
    + exact GL.
  - exploit (builtin_args_inject _ _ TRANSF); eauto.
    intros (args' & EVAL & AI).
    exploit (external_inject _ _ TRANSF); eauto.
    intros (j' & v' & tm & CALL & VI & MI' & INCR & SEP).
    eapply result_steps with (j' := j').
    + apply plus_one. eapply exec_Ibuiltin; eauto.
    + eapply core_plain; eauto using match_stacks_incr.
      destruct res; simpl; eauto using full_agree_incr, full_agree_set.

    + exact MI'.
    + eapply global_injection_incr; eauto.
  - assert (EVAL: eval_condition cond rs'##args m' = Some b).
    { eapply eval_condition_inject; eauto using full_agree_args. }
    eapply result_steps; [apply plus_one; eapply exec_Icond; eauto| |exact MI|exact GL].
    eapply core_plain; eauto.
  - assert (VAL: rs'#arg = Vint n).
    { specialize (REGS arg). rewrite H8 in REGS. inv REGS. reflexivity. }
    eapply result_steps; [apply plus_one; eapply exec_Ijumptable; eauto| |exact MI|exact GL].
    eapply core_plain; eauto.
  - exploit Mem.free_parallel_inject; eauto.
    rewrite ! Z.add_0_r. intros (tm & FREE & MI').
    eapply result_steps; [apply plus_one; eapply exec_Ireturn; eauto| |exact MI'|exact GL].
    eapply core_return; eauto. destruct or; simpl; auto.
Qed.

Lemma call_step:
  forall s fd args m t S2, step ge (Callstate s fd args m) t S2 ->
  forall j s' tfd args' m',
  translated_fundef fd tfd -> match_stacks j s s' None ->
  Val.inject_list j args args' -> Mem.inject j m m' -> global_injection ge j ->
  Ple (Genv.genv_next ge) (Mem.nextblock m') ->
  simulation_result (Callstate s fd args m) t S2 (Callstate s' tfd args' m').
Proof.
  intros s fd args m t S2 STEP j s' tfd args' m' [cu [CHECK LINK]] STACK ARGS MI GL BOUND.
  inv STEP.
  - simpl in CHECK. monadInv CHECK.
    exploit Mem.alloc_parallel_inject; eauto; try apply Z.le_refl.
    intros (j' & tm & tstk & ALLOC & MI' & INCR & SP & OTHER).
    assert (GL': global_injection ge j').
    { eapply global_injection_incr; eauto.
      eapply parallel_alloc_separated; eauto. }
    assert (ARGS': Val.inject_list j' args args') by eauto.
    destruct (checked_function_mode _ _ _ EQ LINK) as [SAME|[self OPT]].
    + subst x. eapply result_steps with (j' := j').
      * apply plus_one. eapply exec_function_internal; eauto using Val.has_argtype_list_inject.
      * eapply core_plain; eauto using match_stacks_incr, full_agree_init.
      * exact MI'.
      * exact GL'.
    + destruct (optimized_properties _ _ _ OPT)
        as (SIG & EMPTY & TSIG & PARAMS & TEMPTY & ENTRY & CODE).
      eapply result_steps with (j' := j').
      * eapply plus_left.
        eapply exec_function_internal.
        rewrite TSIG. eapply Val.has_argtype_list_inject; eauto.
        replace (fn_stacksize x) with (fn_stacksize f) by congruence. exact ALLOC.
        apply star_one. rewrite ENTRY. eapply exec_Iop. rewrite CODE. apply code_init. reflexivity.
        reflexivity.
      * eapply core_optimized; eauto using match_stacks_incr.
        rewrite PARAMS. apply agree_acc. red; intros.
        apply full_agree_init; auto.
        rewrite Regmap.gss. constructor.
      * exact MI'.
      * exact GL'.
  - simpl in CHECK. inv CHECK.
    exploit (external_inject _ _ TRANSF); eauto.
    intros (j' & v' & tm & CALL & VI & MI' & INCR & SEP).
    eapply result_steps with (j' := j').
    + apply plus_one. eapply exec_function_external; eauto.
    + eapply core_return; eauto using match_stacks_incr.
    + exact MI'.
    + eapply global_injection_incr; eauto.
Qed.

Lemma loop_call_step:
  forall self f tf s s' pending args stk' rs' m m' j t S2,
  optimized self f tf -> match_stacks j s s' pending ->
  agree_regs j f (init_regs args (fn_params f)) rs' ->
  Val.inject j (pending_value pending) rs'#(accumulator f) ->
  Mem.inject j m m' -> global_injection ge j ->
  step ge (Callstate s (Internal f) args m) t S2 ->
  simulation_result (Callstate s (Internal f) args m) t S2
    (State s' tf (Vptr stk' Ptrofs.zero) (body_pc (fn_entrypoint f)) rs' m').
Proof.
  intros self f tf s s' pending args stk' rs' m m' j t S2 OPT STACK REGS ACC MI GL STEP.
  inv STEP. eapply result_stutter with (j' := j); auto.
  - unfold measure. pose proof (suffix_length_bound suffix_fuel f (fn_entrypoint f)). lia.
  - eapply core_optimized; eauto.
  - eapply alloc_unmapped_same_injection; eauto.
Qed.

Lemma return_step:
  forall s v m t S2, step ge (Returnstate s v m) t S2 ->
  forall j s' pending v' m',
  match_stacks j s s' pending -> Val.inject j (apply_pending pending v) v' ->
  wt_state (Returnstate s v m) -> Mem.inject j m m' -> global_injection ge j ->
  simulation_result (Returnstate s v m) t S2 (Returnstate s' v' m').
Proof.
  intros s v m t S2 STEP j s' pending v' m' STACK VI WT MI GL.
  inv STEP. inv STACK.
  - match goal with FR: match_frames _ _ _ _ |- _ => inv FR end.
    + eapply result_steps; [apply plus_one; apply exec_return| |exact MI|exact GL].
      eapply core_plain; eauto using full_agree_set.
    + eapply result_steps; [apply plus_one; apply exec_return| |exact MI|exact GL].
      eapply core_optimized; eauto using agree_set.
      rewrite Regmap.gso; auto.
  - match goal with SCAN: additive_terms _ _ _ = Some _ |- _ =>
      destruct (additive_terms_sound _ _ _ _ SCAN) as (k & BOUND & SUF) end.
    assert (VALUE: integer_value v).
    { inv WT. match goal with ST: wt_stackframes (_ :: _) _ |- _ => inv ST end.
      match goal with RM: remove_once res terms = Some saved |- _ =>
        destruct (remove_once_sound _ _ _ RM) as [PERM NE] end.
      assert (IN: In res terms) by (eapply Permutation_in; [apply Permutation_sym; eauto|simpl; auto]).
      match goal with WF: wt_function f ?env |- _ =>
        pose proof (suffix_types _ _ _ _ SUF env WF ltac:(assumption) res IN) as TYPE end.
      eapply integer_value_tint; eauto. congruence. }
    eapply result_stutter with (j' := j); auto.
    + unfold measure. simpl length. pose proof (suffix_length_bound suffix_fuel f pc). lia.
    + eapply core_unwind; eauto.
      rewrite (restored_sum terms res saved rs v) by eauto.
      rewrite <- pending_push; eauto using match_stacks_integer, sum_integer.
Qed.

Lemma unwind_step:
  forall j s s' pending f stk pc rs v' m m' t S2 k terms,
  match_stacks j s s' pending -> fn_stacksize f = 0 -> Archi.ptr64 = true ->
  sig_res (fn_sig f) = Xint -> additive_suffix f k pc terms -> (k <= suffix_fuel)%nat ->
  Val.inject j (apply_pending pending (sum_terms rs terms)) v' ->
  wt_state (State s f (Vptr stk Ptrofs.zero) pc rs m) ->
  Mem.inject j m m' -> global_injection ge j ->
  step ge (State s f (Vptr stk Ptrofs.zero) pc rs m) t S2 ->
  simulation_result (State s f (Vptr stk Ptrofs.zero) pc rs m) t S2 (Returnstate s' v' m').
Proof.
  intros j s s' pending f stk pc rs v' m m' t S2 k terms STACK EMPTY BITS SIG SUF BOUND VI WT MI GL STEP.
  assert (TYPED: exists env, wt_function f env /\ wt_regset env rs) by (inv WT; eauto).
  destruct (additive_suffix_step ge f k pc terms s stk rs m t S2 SUF TYPED BITS SIG STEP)
    as [(k' & pc' & terms' & rs' & TRACE & EQ & LESS & SUF' & SUM)| (m2 & TRACE & EQ & FREE)]; subst.
  - eapply result_stutter with (j' := j); auto.
    unfold measure. rewrite (suffix_length_exact _ _ _ _ SUF _ BOUND).
    rewrite (suffix_length_exact _ _ _ _ SUF' suffix_fuel) by lia. lia.
    eapply core_unwind; eauto; try lia. rewrite <- SUM; auto.
  - eapply result_stutter with (j' := j); auto.
    unfold measure. rewrite (suffix_length_exact _ _ _ _ SUF _ BOUND).
    inv SUF; lia.
    eapply core_return; eauto.
    eapply Mem.free_left_inject; eauto.
Qed.

Lemma optimized_step:
  forall self f tf s s' pending stk stk' pc rs rs' m m' j t S2,
  optimized self f tf -> match_stacks j s s' pending ->
  agree_regs j f rs rs' -> Val.inject j (pending_value pending) rs'#(accumulator f) ->
  wt_state (State s f (Vptr stk Ptrofs.zero) pc rs m) ->
  Mem.inject j m m' -> global_injection ge j ->
  step ge (State s f (Vptr stk Ptrofs.zero) pc rs m) t S2 ->
  simulation_result (State s f (Vptr stk Ptrofs.zero) pc rs m) t S2
    (State s' tf (Vptr stk' Ptrofs.zero) (body_pc pc) rs' m').
Proof.
  intros self f tf s s' pending stk stk' pc rs rs' m m' j t S2
    OPT STACK REGS ACC WT MI GL STEP.
  destruct (optimized_properties _ _ _ OPT)
    as (SIG & EMPTY & TSIG & PARAMS & TEMPTY & ENTRY & TARGET).
  pose proof (optimized_eligible _ _ _ OPT) as EL.
  pose proof (eligible_sound _ _ EL) as FN.
  pose proof (spec_instructions _ _ FN) as ALL.
  pose proof (spec_bits _ _ FN) as BITS.
  assert (PENDING: pending_integer pending) by (eapply match_stacks_integer; eauto).
  inv WT. inv STEP;
    match goal with CODE: (fn_code f)!pc = Some ?i |- _ =>
      let H := fresh "SUP" in pose proof (ALL pc i CODE) as H
    end; try discriminate.
  - assert (SITE: find_site self f pc = None) by (eapply noncall_not_site; eauto; exact I).
    eapply result_steps; [apply plus_one; eapply exec_Inop| |exact MI|exact GL].
    rewrite TARGET. erewrite code_body by eauto.
    unfold rewrite_instruction. rewrite SITE. reflexivity.
    eapply core_optimized; eauto.
  - assert (SITE: find_site self f pc = None) by (eapply noncall_not_site; eauto; exact I).
    assert (ARGS: Val.inject_list j rs##args rs'##args).
    { eapply agree_args; eauto. intros. eapply original_used; eauto; simpl; auto. }
    assert (EVAL: eval_operation ge Vundef op rs##args m = Some v).
    { erewrite <- supported_operation_stack; eauto. }
    destruct (operation_inject _ _ TRANSF j m m' Vundef Vundef op rs##args rs'##args v
      GL MI (Val.val_inject_undef j Vundef) ARGS EVAL) as (v' & EVAL' & VI).
    assert (FRESH: res <> accumulator f) by (apply accumulator_fresh; eapply original_defined; eauto).
    eapply result_steps; [apply plus_one; eapply exec_Iop| |exact MI|exact GL].
    rewrite TARGET. erewrite code_body by eauto.
    unfold rewrite_instruction. rewrite SITE. reflexivity.
    erewrite supported_operation_stack; eauto.
    eapply core_optimized; eauto using agree_set.
    rewrite Regmap.gso by congruence. exact ACC.
  - destruct (supported_call _ _ _ _ _ _ _ SUP) as (ROS & SG & ARGL).
    subst ros.
    assert (SELF: fd = Internal f).
    { pose proof (optimized_self _ _ _ OPT rs). congruence. }
    subst fd.
    destruct (find_site self f pc) as [c|] eqn:SITE.
    + pose proof (find_site_sound _ _ _ _ SITE) as SPEC.
      pose proof (site_call _ _ _ _ SPEC) as CALL.
      assert (IDS: args = call_args c /\ res = call_result c /\ pc' = call_next c)
        by (repeat split; congruence).
      destruct IDS as (ARGID & RESID & NEXTID).
      assert (SAVED: integer_terms rs (saved_terms c)).
      { red; intros r IN. eapply integer_value_tint; eauto.
        rewrite <- (saved_type _ _ _ _ _ SPEC WT_FN ltac:(rewrite SIG; reflexivity) r IN). apply WT_RS. }
      destruct (site_operations_execute tge self f pc c (Vptr stk' Ptrofs.zero) m'
        rs rs' j pending SPEC FN SAVED PENDING REGS ACC) as (trs & RUN & NEWREGS & NEWACC).
      eapply result_steps with (j' := j).
      * eapply site_exec; eauto.
      * rewrite ARGID, RESID, NEXTID. eapply core_loop_call; eauto.
        destruct (site_suffix _ _ _ _ SPEC) as (terms & k & SCAN & RM & K & SUF).
        eapply stacks_eliminated; eauto. rewrite SIG; reflexivity.
        exact NEWACC.
      * exact MI.
      * exact GL.
    + assert (SYMFIND: exists cu tfd, find_function tge (inr self) rs' = Some tfd /\
        AST.transf_partial_fundef (checked_function cu) (Internal f) = OK tfd /\ linkorder cu prog).
      { unfold find_function in *.
        rewrite (symbols_preserved _ _ TRANSF). fold ge.
        destruct (Genv.find_symbol ge self); try discriminate.
        eapply function_ptr_translated; eauto. }
      destruct SYMFIND as (cu & tfd & FIND & CHECK & LINK).
      assert (FRESH: res <> accumulator f) by (apply accumulator_fresh; eapply original_defined; eauto).
      eapply result_steps.
      * apply plus_one. eapply exec_Icall.
        rewrite TARGET. erewrite code_body by eauto.
        unfold rewrite_instruction. rewrite SITE. reflexivity.
        exact FIND.
        rewrite (checked_fundef_sig _ _ _ CHECK). reflexivity.
      * eapply core_call. exists cu; auto.
        eapply stacks_normal; eauto. eapply frame_optimized; eauto.
        eapply agree_args; eauto. intros. eapply original_used; eauto; simpl; auto.
      * exact MI.
      * exact GL.
  - assert (SITE: find_site self f pc = None) by (eapply noncall_not_site; eauto; exact I).
    assert (ARGS: Val.inject_list j rs##args rs'##args).
    { eapply agree_args; eauto. intros. eapply original_used; eauto; simpl; auto. }
    assert (EVAL: eval_condition cond rs'##args m' = Some b) by (eapply eval_condition_inject; eauto).
    eapply result_steps; [apply plus_one; eapply exec_Icond| |exact MI|exact GL].
    rewrite TARGET. erewrite code_body by eauto.
    unfold rewrite_instruction. rewrite SITE. reflexivity.
    exact EVAL. reflexivity.
    destruct b; eapply core_optimized; eauto.
  - destruct or as [r|]; try discriminate.
    assert (SITE: find_site self f pc = None) by (eapply noncall_not_site; eauto; exact I).
    assert (VALUE: integer_value rs#r).
    { match goal with CODE: (fn_code f)!pc = Some (Ireturn _) |- _ =>
        pose proof (wt_instr_at _ _ _ _ WT_FN CODE) as WTI end.
      inv WTI. eapply integer_value_tint; eauto.
      specialize (WT_RS r). unfold proj_sig_res in *. rewrite SIG in *. simpl in *. congruence. }
    assert (BOUND: original_reg f r) by (eapply original_used; eauto; simpl; auto).
    destruct (eval_add_inject _ _ tge (Vptr stk' Ptrofs.zero) m' j
      (pending_value pending) rs#r rs'#(accumulator f) rs'#r
      PENDING VALUE ACC (REGS _ BOUND)) as (sum & ADD & SUM).
    assert (MI2: Mem.inject j m'0 m') by (eapply Mem.free_left_inject; eauto).
    destruct (free_empty_target _ _ _ stk' MI2) as (tm & FREE & MI').
    eapply result_steps with (j' := j).
    + eapply plus_left.
      eapply exec_Iop. rewrite TARGET. erewrite code_body by eauto.
      unfold rewrite_instruction. rewrite SITE. reflexivity. exact ADD.
      apply star_one. eapply exec_Ireturn. rewrite TARGET. apply code_exit.
      rewrite TEMPTY. exact FREE. reflexivity.
    + eapply core_return; eauto. simpl. rewrite Regmap.gss.
      rewrite apply_pending_integer by auto. exact SUM.
    + exact MI'.
    + exact GL.
Qed.

Lemma step_nextblock:
  forall g S t S2, step g S t S2 ->
  Ple (Mem.nextblock (state_memory S)) (Mem.nextblock (state_memory S2)).
Proof.
  intros g S t S2 STEP. inv STEP; simpl; try apply Ple_refl.
  - unfold Mem.storev in H1. destruct a; try discriminate.
    rewrite (Mem.nextblock_store _ _ _ _ _ _ H1). apply Ple_refl.
  - match goal with F: Mem.free _ _ _ _ = Some _ |- _ => rewrite (Mem.nextblock_free _ _ _ _ _ F) end. apply Ple_refl.
  - eapply external_call_nextblock; eauto.
  - match goal with F: Mem.free _ _ _ _ = Some _ |- _ => rewrite (Mem.nextblock_free _ _ _ _ _ F) end. apply Ple_refl.
  - match goal with A: Mem.alloc _ _ _ = (_, _) |- _ => rewrite (Mem.nextblock_alloc _ _ _ _ _ A) end. apply Ple_succ.
  - eapply external_call_nextblock; eauto.
Qed.

Lemma star_nextblock:
  forall g S t S2, star step g S t S2 ->
  Ple (Mem.nextblock (state_memory S)) (Mem.nextblock (state_memory S2)).
Proof.
  induction 1; eauto using Ple_refl, Ple_trans, step_nextblock.
Qed.

Theorem step_simulation:
  forall S t S2, step ge S t S2 -> forall T, match_states S T ->
  (exists T2, plus step tge T t T2 /\ match_states S2 T2) \/
  ((measure S2 < measure S)%nat /\ t = E0 /\ match_states S2 T).
Proof.
  intros S t S2 STEP T MATCH.
  inversion MATCH as [j S0 T0 CORE WT MI GL BOUND TBOUND]; subst.
  assert (RESULT: simulation_result S t S2 T).
  { inv CORE; simpl in *;
      eauto using plain_step, optimized_step, call_step, loop_call_step,
        return_step, unwind_step. }
  assert (WT2: wt_state S2) by (eapply subject_reduction; eauto using wt_prog).
  assert (BOUND2: Ple (Genv.genv_next ge) (Mem.nextblock (state_memory S2))) by
    (eapply Ple_trans; [exact BOUND|eapply step_nextblock; eauto]).
  inv RESULT.
  - left. eexists; split; eauto. eapply match_states_intro; eauto.
    eapply Ple_trans; [exact TBOUND|]. eapply star_nextblock. eapply plus_star; eauto.
  - right. repeat split; auto. eapply match_states_intro; eauto.
Qed.

Lemma initial_states_match:
  forall S, initial_state prog S -> exists T, initial_state tprog T /\ match_states S T.
Proof.
  intros S INIT. inversion INIT; subst.
  destruct (function_ptr_translated _ _ TRANSF _ _ H1)
    as (cu & tfd & FIND & CHECK & LINK).
  exists (Callstate nil tfd nil m0). split.
  - econstructor.
    + eapply (Genv.init_mem_match TRANSF); eauto.
    + rewrite (symbols_preserved _ _ TRANSF).
      replace (prog_main tprog) with (prog_main prog). exact H0.
      symmetry; eapply match_program_main; eauto.
    + exact FIND.
    + rewrite <- H2. eapply checked_fundef_sig; eauto.
  - eapply match_states_intro with (j := Mem.flat_inj (Mem.nextblock m0)).
    + econstructor. exists cu; auto. constructor. constructor.
    + eapply wt_initial_state; eauto. eapply wt_prog; eauto.
    + eapply Genv.initmem_inject; eauto.
    + constructor.
      * intros bb BOUND. unfold Mem.flat_inj.
        unfold ge in BOUND. rewrite (Genv.init_mem_genv_next _ H) in BOUND.
        apply pred_dec_true; auto.
      * intros bb bb' delta MAP BOUND. unfold Mem.flat_inj in MAP.
        destruct (plt bb (Mem.nextblock m0)); congruence.
    + simpl. unfold ge. rewrite (Genv.init_mem_genv_next _ H). apply Ple_refl.
    + simpl. unfold ge. rewrite (Genv.init_mem_genv_next _ H). apply Ple_refl.
Qed.

Lemma final_states_match:
  forall S T r, match_states S T -> final_state S r -> final_state T r.
Proof.
  intros S T r MATCH FINAL. inv FINAL. inv MATCH. inv H.
  match goal with ST: match_stacks _ nil _ _ |- _ => inv ST end.
  match goal with VI: Val.inject _ _ _ |- _ => simpl in VI; inv VI end.
  constructor.
Qed.

Theorem core_transf_program_correct:
  forward_simulation (RTL.semantics prog) (RTL.semantics tprog).
Proof.
  eapply forward_simulation_star with (measure := measure) (match_states := match_states).
  - apply (senv_preserved _ _ TRANSF).
  - exact initial_states_match.
  - exact final_states_match.
  - exact step_simulation.
Qed.

End PRESERVATION.

(** * Correctness of the complete pass and compatibility with linking *)

Definition match_prog (p tp: program): Prop :=
  exists p1 p2,
    ReturnCorrect.match_prog p p1 /\
    core_match_prog p1 p2 /\
    ThreadCorrect.match_prog p2 tp.

Theorem transf_program_match:
  forall p tp, transf_program p = OK tp -> match_prog p tp.
Proof.
  intros p tp T. unfold transf_program in T.
  destruct (transf_program_rec (Return.transf_program p)) as [p2|msg] eqn:CORE;
    try discriminate. inv T.
  exists (Return.transf_program p), p2. split.
  - apply ReturnCorrect.transf_program_match.
  - split.
    + apply core_transf_program_match; auto.
    + apply ThreadCorrect.transf_program_match.
Qed.

Global Instance transf_program_link: TransfLink match_prog.
Proof.
  red; intros p1 p2 tp1 tp2 p LINK
    (r1 & c1 & R1 & C1 & T1) (r2 & c2 & R2 & C2 & T2).
  destruct (transf_link (transf := ReturnCorrect.match_prog) _ _ _ _ _ LINK R1 R2)
    as (r & LR & R).
  destruct (transf_link (transf := core_match_prog) _ _ _ _ _ LR C1 C2)
    as (c & LC & C).
  destruct (transf_link (transf := ThreadCorrect.match_prog) _ _ _ _ _ LC T1 T2)
    as (t & LT & T).
  exists t; split; auto. exists r, c; auto.
Qed.

Theorem transf_program_correct:
  forall p tp, match_prog p tp ->
  forward_simulation (RTL.semantics p) (RTL.semantics tp).
Proof.
  intros p tp (p1 & p2 & R & C & T).
  eapply compose_forward_simulations.
  - eapply ReturnCorrect.transf_program_correct; eauto.
  - eapply compose_forward_simulations.
    + eapply core_transf_program_correct; eauto.
    + eapply ThreadCorrect.transf_program_correct; eauto.
Qed.
