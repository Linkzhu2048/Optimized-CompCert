(* *********************************************************************)
(*                                                                     *)
(*              The Compcert verified compiler                         *)
(*                                                                     *)
(* *********************************************************************)

(** Semantic preservation for restricted loop rotation. *)

Require Import Coqlib Maps AST Linking.
Require Import Values Memory Globalenvs Events Smallstep.
Require Import Op Registers RTL LoopRotate.

Definition match_prog (p tp: RTL.program) :=
  match_program (fun ctx f tf => tf = transf_fundef f) eq p tp.

Lemma transf_program_match:
  forall p, match_prog p (transf_program p).
Proof.
  intros. eapply match_transform_program; eauto.
Qed.

(** A copied node represents the same source instruction as the original
    header. The correctness argument does not depend on the heuristic
    used to choose headers: it establishes a one-step simulation, with
    identical registers, memory and observable events. *)

Inductive match_pc (f: function): node -> node -> Prop :=
  | match_pc_original: forall pc,
      match_pc f pc pc
  | match_pc_copy: forall pc latch,
      (rotation_plan f)!latch = Some pc ->
      match_pc f pc (copy_node (max_pc_function f) latch).

Lemma copy_node_injective:
  forall bound x y, copy_node bound x = copy_node bound y -> x = y.
Proof.
  unfold copy_node; intros. extlia.
Qed.

Lemma copy_node_fresh:
  forall f pc i latch,
  f.(fn_code)!pc = Some i -> pc <> copy_node (max_pc_function f) latch.
Proof.
  intros. generalize (max_pc_function_sound _ _ _ H).
  unfold copy_node; intros. extlia.
Qed.

Lemma map_successors_id:
  forall i, map_successors (fun pc => pc) i = i.
Proof.
  destruct i; simpl; try reflexivity. rewrite List.map_id; reflexivity.
Qed.

Lemma redirect_correct:
  forall f pc s,
  match_pc f s (redirect (max_pc_function f) (rotation_plan f) pc s).
Proof.
  unfold redirect; intros.
  destruct (rotation_plan f)!pc as [h|] eqn:HEADER.
  - destruct (peq s h); subst; econstructor; eauto.
  - constructor.
Qed.

Lemma transf_code_original:
  forall f plan pc i, f.(fn_code)!pc = Some i ->
  (transf_code f plan)!pc =
  Some (map_successors (redirect (max_pc_function f) plan pc) i).
Proof.
  intros f plan pc i AT. unfold transf_code.
  apply PTree_Properties.fold_rec with
    (P := fun _ c => c!pc =
       Some (map_successors (redirect (max_pc_function f) plan pc) i)).
  - intros; auto.
  - rewrite PTree.gmap, AT. reflexivity.
  - intros. unfold add_copy. destruct (fn_code f)!v.
    + rewrite PTree.gso; auto. eapply copy_node_fresh; eauto.
    + auto.
Qed.

Lemma transf_code_copy:
  forall f plan latch h i,
  plan!latch = Some h -> f.(fn_code)!h = Some i ->
  (transf_code f plan)!(copy_node (max_pc_function f) latch) = Some i.
Proof.
  intros f plan. unfold transf_code.
  apply PTree_Properties.fold_rec with
    (P := fun p c => forall latch h i,
      p!latch = Some h -> f.(fn_code)!h = Some i ->
      c!(copy_node (max_pc_function f) latch) = Some i).
  - intros p p' c EQ IH latch h i AT CODE.
    apply (IH latch h i); auto. rewrite EQ; auto.
  - intros. rewrite PTree.gempty in H; discriminate.
  - intros p c k v EMPTY FULL IH latch h i AT CODE.
    rewrite PTree.gsspec in AT. destruct (peq latch k).
    + subst latch. inv AT. unfold add_copy. rewrite CODE. apply PTree.gss.
    + unfold add_copy. destruct (fn_code f)!v.
      * rewrite PTree.gso. apply (IH latch h i); auto.
        intro EQ. apply n. eapply copy_node_injective; eauto.
      * apply (IH latch h i); auto.
Qed.

Lemma transf_function_at:
  forall f pc tpc i,
  match_pc f pc tpc -> f.(fn_code)!pc = Some i ->
  exists rename,
    (transf_function f).(fn_code)!tpc = Some (map_successors rename i)
    /\ (forall s, match_pc f s (rename s)).
Proof.
  intros f pc tpc i MATCH AT.
  unfold transf_function.
  destruct (PTree.elements (rotation_plan f)) eqn:PLAN.
  - inv MATCH.
    + exists (fun pc => pc). rewrite map_successors_id.
      split; auto. intros; constructor.
    + apply PTree.elements_correct in H. rewrite PLAN in H. contradiction.
  - simpl fn_code. inv MATCH.
    + eexists. split. eapply transf_code_original; eauto. apply redirect_correct.
    + exists (fun pc => pc). rewrite map_successors_id.
      split. eapply transf_code_copy; eauto. intros; constructor.
Qed.

Lemma sig_transf_function:
  forall f, fn_sig (transf_function f) = fn_sig f.
Proof.
  intros; unfold transf_function; destruct (PTree.elements (rotation_plan f)); reflexivity.
Qed.

Lemma params_transf_function:
  forall f, fn_params (transf_function f) = fn_params f.
Proof.
  intros; unfold transf_function; destruct (PTree.elements (rotation_plan f)); reflexivity.
Qed.

Lemma stacksize_transf_function:
  forall f, fn_stacksize (transf_function f) = fn_stacksize f.
Proof.
  intros; unfold transf_function; destruct (PTree.elements (rotation_plan f)); reflexivity.
Qed.

Lemma entrypoint_transf_function:
  forall f, fn_entrypoint (transf_function f) = fn_entrypoint f.
Proof.
  intros; unfold transf_function; destruct (PTree.elements (rotation_plan f)); reflexivity.
Qed.

Lemma transf_function_identity:
  forall f, PTree.elements (rotation_plan f) = nil -> transf_function f = f.
Proof.
  intros; unfold transf_function; rewrite H; reflexivity.
Qed.

(** Shared one-step simulation for register-preserving CFG copies.
    The concrete transformation supplies its instruction correspondence. *)
Section PRESERVATION.

Variable transform: function -> function.
Variable relate_pc: function -> node -> node -> Prop.
Hypothesis instruction_at: forall f pc tpc i,
  relate_pc f pc tpc -> f.(fn_code)!pc = Some i ->
  exists rename,
    (transform f).(fn_code)!tpc = Some (map_successors rename i)
    /\ (forall s, In s (successors_instr i) -> relate_pc f s (rename s)).
Hypothesis sig_transform: forall f, fn_sig (transform f) = fn_sig f.
Hypothesis params_transform: forall f, fn_params (transform f) = fn_params f.
Hypothesis stacksize_transform: forall f, fn_stacksize (transform f) = fn_stacksize f.
Hypothesis entrypoint_match: forall f,
  relate_pc f f.(fn_entrypoint) (transform f).(fn_entrypoint).
Let transform_fundef := AST.transf_fundef transform.

Variables prog tprog: program.
Hypothesis TRANSL: match_program (fun ctx f tf => tf = transform_fundef f) eq prog tprog.
Let ge := Genv.globalenv prog.
Let tge := Genv.globalenv tprog.

Lemma functions_translated:
  forall v f,
  Genv.find_funct ge v = Some f ->
  Genv.find_funct tge v = Some (transform_fundef f).
Proof (Genv.find_funct_transf TRANSL).

Lemma function_ptr_translated:
  forall v f,
  Genv.find_funct_ptr ge v = Some f ->
  Genv.find_funct_ptr tge v = Some (transform_fundef f).
Proof (Genv.find_funct_ptr_transf TRANSL).

Lemma symbols_preserved:
  forall id, Genv.find_symbol tge id = Genv.find_symbol ge id.
Proof (Genv.find_symbol_transf TRANSL).

Lemma senv_preserved:
  Senv.equiv ge tge.
Proof (Genv.senv_transf TRANSL).

Lemma sig_preserved:
  forall f, funsig (transform_fundef f) = funsig f.
Proof.
  destruct f; simpl; auto.
Qed.

Lemma find_function_translated:
  forall ros rs fd,
  find_function ge ros rs = Some fd ->
  find_function tge ros rs = Some (transform_fundef fd).
Proof.
  unfold find_function; intros. destruct ros as [r|id].
  - eapply functions_translated; eauto.
  - rewrite symbols_preserved. destruct (Genv.find_symbol ge id); try congruence.
    eapply function_ptr_translated; eauto.
Qed.

Inductive match_frames: RTL.stackframe -> RTL.stackframe -> Prop :=
  | match_frames_intro: forall res f sp pc rs tpc
        (PC: relate_pc f pc tpc),
      match_frames (Stackframe res f sp pc rs)
                   (Stackframe res (transform f) sp tpc rs).

Inductive match_states: RTL.state -> RTL.state -> Prop :=
  | match_regular_states: forall stk f sp pc rs m stk' tpc
        (STACKS: list_forall2 match_frames stk stk')
        (PC: relate_pc f pc tpc),
      match_states (State stk f sp pc rs m)
                   (State stk' (transform f) sp tpc rs m)
  | match_callstates: forall stk f args m stk'
        (STACKS: list_forall2 match_frames stk stk'),
      match_states (Callstate stk f args m)
                   (Callstate stk' (transform_fundef f) args m)
  | match_returnstates: forall stk v m stk'
        (STACKS: list_forall2 match_frames stk stk'),
      match_states (Returnstate stk v m) (Returnstate stk' v m).

Ltac TRANSF_AT :=
  match goal with
  | [ AT: (fn_code ?f)!?pc = Some ?i, PC: relate_pc ?f ?pc ?tpc |- _ ] =>
      destruct (instruction_at f pc tpc i PC AT)
        as [rename [CODE SUCC]]; simpl map_successors in CODE; simpl in SUCC
  end.

Lemma step_simulation:
  forall S1 t S2, RTL.step ge S1 t S2 ->
  forall S1', match_states S1 S1' ->
  exists S2', RTL.step tge S1' t S2' /\ match_states S2 S2'.
Proof.
  induction 1; intros S1' MS; inv MS; try TRANSF_AT.
  - (* nop *)
    econstructor; split. eapply exec_Inop; eauto.
    constructor; eauto.
  - (* operation *)
    econstructor; split.
    eapply exec_Iop; eauto.
      instantiate (1 := v). rewrite <- H0.
      apply eval_operation_preserved. exact symbols_preserved.
    constructor; eauto.
  - (* load *)
    assert (eval_addressing tge sp addr rs ## args = Some a).
    { rewrite <- H0. apply eval_addressing_preserved. exact symbols_preserved. }
    econstructor; split. eapply exec_Iload; eauto.
    constructor; eauto.
  - (* store *)
    assert (eval_addressing tge sp addr rs ## args = Some a).
    { rewrite <- H0. apply eval_addressing_preserved. exact symbols_preserved. }
    econstructor; split. eapply exec_Istore; eauto.
    constructor; eauto.
  - (* call *)
    econstructor; split.
    eapply exec_Icall with (fd := transform_fundef fd); eauto.
      eapply find_function_translated; eauto.
      apply sig_preserved.
    constructor. constructor; eauto. constructor; eauto.
  - (* tail call *)
    econstructor; split.
    eapply exec_Itailcall with (fd := transform_fundef fd); eauto.
      eapply find_function_translated; eauto.
      apply sig_preserved.
      rewrite stacksize_transform; eauto.
    constructor; eauto.
  - (* builtin *)
    econstructor; split.
    eapply exec_Ibuiltin; eauto.
      eapply eval_builtin_args_preserved with (ge1 := ge); eauto.
      exact symbols_preserved.
      eapply external_call_symbols_preserved; eauto. apply senv_preserved.
    constructor; eauto.
  - (* condition *)
    econstructor; split. eapply exec_Icond; eauto.
    constructor; eauto. destruct b; apply SUCC; auto.
  - (* jump table *)
    econstructor; split.
    eapply exec_Ijumptable; eauto.
      rewrite list_nth_z_map, H1. simpl; eauto.
    constructor; eauto. apply SUCC. eapply list_nth_z_in; eauto.
  - (* return *)
    econstructor; split. eapply exec_Ireturn; eauto.
    rewrite stacksize_transform; eauto.
    constructor; eauto.
  - (* internal function *)
    simpl. econstructor; split.
    { eapply exec_function_internal.
      - rewrite sig_transform; eauto.
      - rewrite stacksize_transform; eauto. }
    rewrite params_transform.
    constructor; eauto.
  - (* external function *)
    econstructor; split. eapply exec_function_external; eauto.
      eapply external_call_symbols_preserved; eauto. apply senv_preserved.
    constructor; eauto.
  - (* return to caller *)
    inv STACKS. inv H1.
    econstructor; split. eapply exec_return; eauto.
    constructor; eauto.
Qed.

Lemma transf_initial_states:
  forall S1, RTL.initial_state prog S1 ->
  exists S2, RTL.initial_state tprog S2 /\ match_states S1 S2.
Proof.
  intros. inv H. econstructor; split.
  econstructor.
  - eapply (Genv.init_mem_transf TRANSL); eauto.
  - rewrite symbols_preserved. unfold fundef.
    rewrite (match_program_main TRANSL). eauto.
  - eapply function_ptr_translated; eauto.
  - rewrite <- H3; apply sig_preserved.
  - constructor. constructor.
Qed.

Lemma transf_final_states:
  forall S1 S2 r,
  match_states S1 S2 -> RTL.final_state S1 r -> RTL.final_state S2 r.
Proof.
  intros. inv H0. inv H. inv STACKS. constructor.
Qed.

Theorem code_copy_correct:
  forward_simulation (RTL.semantics prog) (RTL.semantics tprog).
Proof.
  eapply forward_simulation_step.
  - apply senv_preserved.
  - eexact transf_initial_states.
  - eexact transf_final_states.
  - exact step_simulation.
Qed.

End PRESERVATION.

Theorem transf_program_correct:
  forall prog tprog, match_prog prog tprog ->
  forward_simulation (RTL.semantics prog) (RTL.semantics tprog).
Proof.
  intros. eapply code_copy_correct with
    (transform := transf_function) (relate_pc := match_pc); eauto.
  - intros. edestruct transf_function_at as [rename [AT NEXT]]; eauto.
  - exact sig_transf_function.
  - exact params_transf_function.
  - exact stacksize_transf_function.
  - intros; rewrite entrypoint_transf_function; constructor.
Qed.
