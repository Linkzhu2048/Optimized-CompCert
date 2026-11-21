(* *********************************************************************)
(*                                                                     *)
(*              The Compcert verified compiler                         *)
(*                                                                     *)
(* *********************************************************************)

(** Semantic preservation for guarded preheader LICM. *)
Require Import Coqlib Maps AST Linking Values Memory Globalenvs Events Smallstep.
Require Import Op Registers RTL LoopRotate LoopRotateproof LICM.

Definition match_prog (p tp: RTL.program) :=
  match_program (fun ctx f tf => tf = transf_fundef f) eq p tp.
Lemma transf_program_match: forall p, match_prog p (transf_program p).
Proof. intros; apply match_transform_program; auto. Qed.

Definition known {F V} (ge: Genv.t F V) sp p rs m :=
  op_depends_on_memory p.(invariant_op) = false /\
  eval_operation ge sp p.(invariant_op) rs##(operands p) m = Some rs#(result p).

Lemma args_set: forall args (rs: regset) dst v, ~ In dst args ->
  (rs#dst <- v)##args = rs##args.
Proof.
  intros; apply list_map_exten; intros. symmetry; apply Regmap.gso; congruence.
Qed.

Lemma known_set: forall F V (ge: Genv.t F V) sp p rs m dst v,
  known ge sp p rs m -> independent p dst = true ->
  known ge sp p (rs#dst <- v) m.
Proof.
  unfold independent, known; intros.
  destruct (peq dst (result p)); try discriminate.
  destruct (In_dec peq dst (operands p)); try discriminate.
  rewrite args_set by auto. rewrite Regmap.gso by congruence. auto.
Qed.

Lemma known_mem: forall F V (ge: Genv.t F V) sp p rs m m',
  known ge sp p rs m -> known ge sp p rs m'.
Proof.
  intros; destruct H; split; auto.
  rewrite <- (@op_depends_on_memory_correct _ _ ge sp _ _ m m' H); auto.
Qed.

Definition preserves (i: instruction) (rs rs': regset) : Prop :=
  match i with
  | Iop _ _ dst _ | Iload _ _ _ dst _ => exists v, rs' = rs#dst <- v
  | Inop _ | Istore _ _ _ _ _ | Icond _ _ _ _ | Ijumptable _ _ => rs' = rs
  | _ => True
  end.

Lemma known_preserved: forall F V (ge: Genv.t F V) sp p rs m i rs' m',
  known ge sp p rs m -> safe p i = true -> preserves i rs rs' ->
  known ge sp p rs' m'.
Proof.
  intros. apply known_mem with m. destruct i; simpl in *; try discriminate;
    try (subst; auto); destruct H1 as [v ->]; eapply known_set; eauto.
Qed.

Ltac skip_candidate IH SEL :=
  apply IH in SEL; destruct SEL as [[next IN] REST];
  split; [exists next; right; exact IN | exact REST].

Lemma find_candidate_spec: forall f code p body,
  find_candidate f code = Some (p, body) ->
  (exists s, In (p.(location), Iop p.(invariant_op) p.(operands) p.(result) s) code) /\
  ~ In p.(result) p.(operands) /\ op_depends_on_memory p.(invariant_op) = false /\
  valid f p body = true.
Proof.
  intros f code; induction code as [|[pc i] rest IH]; cbn [find_candidate]; intros p body SEL; try discriminate.
  destruct i; try solve [skip_candidate IH SEL].
  destruct (worthwhile o) eqn:W; try solve [skip_candidate IH SEL].
  destruct (op_depends_on_memory o) eqn:MEM; try solve [skip_candidate IH SEL].
  destruct (In_dec peq r l); try solve [skip_candidate IH SEL].
  remember (loop_region f (Candidate pc o l r) n) as nodes in *.
  destruct (valid f (Candidate pc o l r) nodes &&
    has_backedge f (Candidate pc o l r) nodes &&
    Nat.leb (List.length nodes) (if Nat.leb 2 (operation_cost o) then 128 else 32)) eqn:CHECK.
  - injection SEL as EQ1 EQ2. subst p body.
    split. { exists n; left; reflexivity. }
    split; [assumption|]. split; [exact MEM|]. apply andb_true_iff in CHECK.
    destruct CHECK as [CHECK _]; apply andb_true_iff in CHECK; tauto.
  - skip_candidate IH SEL.
Qed.

Lemma selected_spec: forall f p body, selected f = Some (p, body) ->
  (exists s, f.(fn_code)!(location p) = Some (Iop p.(invariant_op) p.(operands) p.(result) s)) /\
  ~ In p.(result) p.(operands) /\ op_depends_on_memory p.(invariant_op) = false /\
  ~ In f.(fn_entrypoint) body /\ ~ In p.(location) body /\
  (forall pc i, f.(fn_code)!pc = Some i -> valid_node p body pc i = true).
Proof.
  intros f p body SEL; unfold selected in SEL; apply find_candidate_spec in SEL.
  destruct SEL as [[s IN] [ARGS [MEM VALID]]].
  assert (ORIGINAL: In (location p, Iop (invariant_op p) (operands p) (result p) s)
                      (PTree.elements (fn_code f))).
  { apply in_app_or in IN; destruct IN as [IN | IN]; apply filter_In in IN; tauto. }
  clear IN; rename ORIGINAL into IN. unfold valid in VALID.
  repeat rewrite andb_true_iff in VALID. destruct VALID as [[ENTRY LOC] NODES].
  destruct (In_dec peq (fn_entrypoint f) body); try discriminate.
  destruct (In_dec peq (location p) body); try discriminate.
  repeat split; auto.
  - exists s; apply PTree.elements_complete; auto.
  - intros pc i AT. apply forallb_forall with (x := (pc, i)) in NODES; auto.
    apply PTree.elements_correct; auto.
Qed.

Inductive match_pc {F V} (ge: Genv.t F V) sp (f: function) rs m: node -> node -> Prop :=
  | pc_original: forall pc,
      (forall p body, selected f = Some (p, body) -> In pc body -> known ge sp p rs m) ->
      match_pc ge sp f rs m pc pc
  | pc_reuse: forall p body,
      selected f = Some (p, body) -> known ge sp p rs m ->
      match_pc ge sp f rs m p.(location) (copy_node (max_pc_function f) p.(location)).

Lemma code_original: forall f p body pc i, f.(fn_code)!pc = Some i ->
  (transf_code f p body)!pc = Some (original f p body pc i).
Proof.
  intros; unfold transf_code.
  destruct (fn_code f)!(location p) as [ins|]; try (rewrite PTree.gmap, H; reflexivity).
  destruct ins; try (rewrite PTree.gmap, H; reflexivity).
  rewrite PTree.gso. rewrite PTree.gmap, H; reflexivity.
  eapply copy_node_fresh; eauto.
Qed.

Lemma sig_transf_function: forall f, fn_sig (transf_function f) = fn_sig f.
Proof. intros; unfold transf_function; destruct (selected f) as [[p ns]|]; reflexivity. Qed.
Lemma params_transf_function: forall f, fn_params (transf_function f) = fn_params f.
Proof. intros; unfold transf_function; destruct (selected f) as [[p ns]|]; reflexivity. Qed.
Lemma stacksize_transf_function: forall f, fn_stacksize (transf_function f) = fn_stacksize f.
Proof. intros; unfold transf_function; destruct (selected f) as [[p ns]|]; reflexivity. Qed.
Lemma entrypoint_transf_function: forall f, fn_entrypoint (transf_function f) = fn_entrypoint f.
Proof. intros; unfold transf_function; destruct (selected f) as [[p ns]|]; reflexivity. Qed.

Section PRESERVATION.
Variables prog tprog: program.
Hypothesis TRANSL: match_prog prog tprog.
Let ge := Genv.globalenv prog.
Let tge := Genv.globalenv tprog.

Inductive match_instruction f sp rs m: instruction -> instruction -> Prop :=
  | instruction_normal: forall i rename,
      (forall rs' m' s, preserves i rs rs' -> In s (successors_instr i) ->
        match_pc ge sp f rs' m' s (rename s)) ->
      match_instruction f sp rs m i (map_successors rename i)
  | instruction_compute: forall p s rename,
      ~ In p.(result) p.(operands) -> op_depends_on_memory p.(invariant_op) = false ->
      (forall v, eval_operation ge sp p.(invariant_op) rs##(operands p) m = Some v ->
        match_pc ge sp f (rs#(result p) <- v) m s (rename s)) ->
      match_instruction f sp rs m (Iop p.(invariant_op) p.(operands) p.(result) s)
        (Iop p.(invariant_op) p.(operands) p.(result) (rename s))
  | instruction_reuse: forall p s rename,
      known ge sp p rs m ->
      (forall v, eval_operation ge sp p.(invariant_op) rs##(operands p) m = Some v ->
        match_pc ge sp f (rs#(result p) <- v) m s (rename s)) ->
      match_instruction f sp rs m (Iop p.(invariant_op) p.(operands) p.(result) s)
        (Iop Omove (p.(result) :: nil) p.(result) (rename s)).

Lemma known_next: forall sp f p body rs m s,
  selected f = Some (p, body) -> known ge sp p rs m ->
  match_pc ge sp f rs m s (redirect f p s).
Proof.
  intros; unfold redirect. destruct (peq s p.(location)); subst.
  - econstructor; eauto.
  - constructor; intros p' body' SEL IN. rewrite H in SEL; inv SEL; auto.
Qed.

Lemma computed_next: forall sp f p body rs m s v,
  selected f = Some (p, body) ->
  eval_operation ge sp p.(invariant_op) rs##(operands p) m = Some v ->
  match_pc ge sp f (rs#(result p) <- v) m s s.
Proof.
  intros sp f p body rs m s v SEL EVAL. constructor; intros p' body' EQ IN.
  rewrite SEL in EQ; inv EQ. destruct (selected_spec _ _ _ SEL) as [_ [ARGS [MEM REST]]].
  split; auto. rewrite args_set by auto. rewrite Regmap.gss; auto.
Qed.

Lemma instruction_at: forall f sp rs m pc tpc i,
  match_pc ge sp f rs m pc tpc -> f.(fn_code)!pc = Some i ->
  exists ti, (transf_function f).(fn_code)!tpc = Some ti /\ match_instruction f sp rs m i ti.
Proof.
  intros f sp rs m pc tpc i PC AT; inv PC.
  - unfold transf_function; destruct (selected f) as [[p body]|] eqn:SEL.
    + destruct (selected_spec _ _ _ SEL) as [[s CODE] [ARGS [MEM [ENTRY [LOC NODES]]]]].
      simpl; rewrite (code_original _ _ _ _ _ AT). eexists; split; eauto.
      unfold original; destruct (In_dec peq tpc body) as [IN|OUT].
      * constructor; intros rs' m' s' PRES SUCC. apply known_next with body; auto.
        eapply known_preserved; eauto.
        specialize (NODES _ _ AT); unfold valid_node in NODES.
        destruct (In_dec peq tpc body); auto; contradiction.
      * destruct (peq tpc p.(location)) as [EQ|NE].
        -- subst tpc; rewrite CODE in AT; inv AT.
           eapply instruction_compute with (rename := fun s => s); eauto using computed_next.
        -- rewrite <- (map_successors_id i) at 2. constructor; intros rs' m' s' PRES SUCC.
           constructor; intros p' body' EQ IN. rewrite SEL in EQ; injection EQ as EQp EQb; subst p' body'.
           specialize (NODES _ _ AT); unfold valid_node in NODES.
           destruct (In_dec peq tpc body); try contradiction.
           destruct (peq tpc (location p)); try contradiction.
           apply forallb_forall with (x := s') in NODES; auto.
           destruct (In_dec peq s' body); discriminate || contradiction.
    + eexists; split; eauto. rewrite <- (map_successors_id i) at 2.
      constructor; intros; constructor; intros; congruence.
  - destruct (selected_spec _ _ _ H) as [[s CODE] [ARGS [MEM REST]]].
    rewrite CODE in AT; inv AT. unfold transf_function; rewrite H; simpl.
    unfold transf_code; rewrite CODE, PTree.gss. eexists; split; eauto.
    eapply instruction_reuse with (rename := fun s => s); eauto using computed_next.
Qed.

Lemma functions_translated:
  forall v f,
  Genv.find_funct ge v = Some f ->
  Genv.find_funct tge v = Some (transf_fundef f).
Proof (Genv.find_funct_transf TRANSL).

Lemma function_ptr_translated:
  forall v f,
  Genv.find_funct_ptr ge v = Some f ->
  Genv.find_funct_ptr tge v = Some (transf_fundef f).
Proof (Genv.find_funct_ptr_transf TRANSL).

Lemma symbols_preserved:
  forall id, Genv.find_symbol tge id = Genv.find_symbol ge id.
Proof (Genv.find_symbol_transf TRANSL).

Lemma senv_preserved:
  Senv.equiv ge tge.
Proof (Genv.senv_transf TRANSL).

Lemma sig_preserved:
  forall f, funsig (transf_fundef f) = funsig f.
Proof.
  destruct f; simpl; auto. apply sig_transf_function.
Qed.

Lemma find_function_translated:
  forall ros rs fd,
  find_function ge ros rs = Some fd ->
  find_function tge ros rs = Some (transf_fundef fd).
Proof.
  unfold find_function; intros. destruct ros as [r|id].
  - eapply functions_translated; eauto.
  - rewrite symbols_preserved. destruct (Genv.find_symbol ge id); try congruence.
    eapply function_ptr_translated; eauto.
Qed.

Inductive match_frames: RTL.stackframe -> RTL.stackframe -> Prop :=
  | match_frames_intro: forall res f sp pc rs tpc
        (PC: forall v m, match_pc ge sp f (rs#res <- v) m pc tpc),
      match_frames (Stackframe res f sp pc rs)
                   (Stackframe res (transf_function f) sp tpc rs).

Inductive match_states: RTL.state -> RTL.state -> Prop :=
  | match_regular_states: forall stk f sp pc rs m stk' tpc
        (STACKS: list_forall2 match_frames stk stk')
        (PC: match_pc ge sp f rs m pc tpc),
      match_states (State stk f sp pc rs m)
                   (State stk' (transf_function f) sp tpc rs m)
  | match_callstates: forall stk f args m stk'
        (STACKS: list_forall2 match_frames stk stk'),
      match_states (Callstate stk f args m)
                   (Callstate stk' (transf_fundef f) args m)
  | match_returnstates: forall stk v m stk'
        (STACKS: list_forall2 match_frames stk stk'),
      match_states (Returnstate stk v m) (Returnstate stk' v m).

Ltac TRANSF_AT :=
  match goal with
  | [ AT: (fn_code ?f)!?pc = Some ?i, PC: match_pc ge ?sp ?f ?rs ?m ?pc ?tpc |- _ ] =>
      destruct (instruction_at f sp rs m pc tpc i PC AT)
        as [ti [CODE INST]]; inv INST; simpl map_successors in CODE
  end.
Ltac NEXT :=
  match goal with
  | [ N: forall rs' m' s, preserves _ _ rs' -> _ -> _ |- _ ] =>
      eapply N; simpl; eauto
  | [ N: forall v, _ = Some v -> _ |- _ ] => eapply N; eauto
  end.

Lemma step_simulation:
  forall S1 t S2, RTL.step ge S1 t S2 ->
  forall S1', match_states S1 S1' ->
  exists S2', RTL.step tge S1' t S2' /\ match_states S2 S2'.
Proof.
  induction 1; intros S1' MS; inv MS; try TRANSF_AT.
  - (* nop *)
    econstructor; split. eapply exec_Inop; eauto.
    constructor; eauto; try NEXT.
  - (* operation *)
    econstructor; split.
    eapply exec_Iop; eauto.
      instantiate (1 := v). rewrite <- H0.
      apply eval_operation_preserved. exact symbols_preserved.
    constructor; eauto; try NEXT.
  - (* First evaluation establishes the invariant. *)
    econstructor; split.
    eapply exec_Iop; eauto.
      instantiate (1 := v). rewrite <- H0.
      apply eval_operation_preserved. exact symbols_preserved.
    constructor; eauto; NEXT.
  - (* A cached evaluation becomes a self move, eliminated by allocation. *)
    assert (VALUE: v = rs#(result p)).
    { match goal with K: known _ _ _ _ _ |- _ => destruct K as [_ K] end.
      congruence. }
    econstructor; split.
    eapply exec_Iop with (v := v); eauto. simpl; congruence.
    constructor; eauto; NEXT.
  - (* load *)
    assert (eval_addressing tge sp addr rs ## args = Some a).
    { rewrite <- H0. apply eval_addressing_preserved. exact symbols_preserved. }
    econstructor; split. eapply exec_Iload; eauto.
    constructor; eauto; try NEXT.
  - (* store *)
    assert (eval_addressing tge sp addr rs ## args = Some a).
    { rewrite <- H0. apply eval_addressing_preserved. exact symbols_preserved. }
    econstructor; split. eapply exec_Istore; eauto.
    constructor; eauto; try NEXT.
  - (* call *)
    econstructor; split.
    eapply exec_Icall with (fd := transf_fundef fd); eauto.
      eapply find_function_translated; eauto.
      apply sig_preserved.
    constructor. constructor; eauto. constructor; intros; try NEXT.
  - (* tail call *)
    econstructor; split.
    eapply exec_Itailcall with (fd := transf_fundef fd); eauto.
      eapply find_function_translated; eauto.
      apply sig_preserved.
      rewrite stacksize_transf_function; eauto.
    constructor; eauto; try NEXT.
  - (* builtin *)
    econstructor; split.
    eapply exec_Ibuiltin; eauto.
      eapply eval_builtin_args_preserved with (ge1 := ge); eauto.
      exact symbols_preserved.
      eapply external_call_symbols_preserved; eauto. apply senv_preserved.
    constructor; eauto; try NEXT.
  - (* condition *)
    econstructor; split. eapply exec_Icond; eauto.
    constructor; eauto. destruct b; NEXT.
  - (* jump table *)
    econstructor; split.
    eapply exec_Ijumptable; eauto.
      rewrite list_nth_z_map, H1. simpl; eauto.
    constructor; eauto. eapply H2; simpl; eauto using list_nth_z_in.
  - (* return *)
    econstructor; split. eapply exec_Ireturn; eauto.
    rewrite stacksize_transf_function; eauto.
    constructor; eauto; try NEXT.
  - (* internal function *)
    simpl. econstructor; split.
    { eapply exec_function_internal.
      - rewrite sig_transf_function; eauto.
      - rewrite stacksize_transf_function; eauto. }
    rewrite params_transf_function, entrypoint_transf_function.
    constructor; eauto. constructor; intros p body SEL IN.
    destruct (selected_spec _ _ _ SEL) as [_ [_ [_ [ENTRY _]]]]; contradiction.
  - (* external function *)
    econstructor; split. eapply exec_function_external; eauto.
      eapply external_call_symbols_preserved; eauto. apply senv_preserved.
    constructor; eauto; try NEXT.
  - (* return to caller *)
    inv STACKS. inv H1.
    econstructor; split. eapply exec_return; eauto.
    constructor; eauto; try NEXT.
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

Theorem transf_program_correct:
  forward_simulation (RTL.semantics prog) (RTL.semantics tprog).
Proof.
  eapply forward_simulation_step.
  - apply senv_preserved.
  - eexact transf_initial_states.
  - eexact transf_final_states.
  - exact step_simulation.
Qed.

End PRESERVATION.
