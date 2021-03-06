Require Import Coq.Unicode.Utf8 Arith FunctionalExtensionality String Coq.Program.Equality.

Load CpdtTactics.

Set Implicit Arguments.

Ltac iauto := try solve [intuition (eauto 3)].
Ltac iauto' := try solve [intuition eauto].
Ltac invert H := inversion H; clear H; try subst.


(* NOTE(dbp 2017-03-26): Often when inverting, we only want to handle
   cases that are _not_ variables. This will fail if C is a variable
   of type T *)
Ltac not_var C T :=
  match goal with
  |[ C' : T |- _ ] =>
   match C with
   | C' => fail 2
   | _ => fail 1
   end
  | _ => idtac
  end.

Tactic Notation "hint" constr(E) :=
  let H := fresh "Hint" in
  let t := type of E in
  assert (H : t) by (exact E).

Tactic Notation "hint" constr(E) "," constr(E1) := hint E; hint E1.
Tactic Notation "hint" constr(E) "," constr(E1) "," constr(E2) :=
  hint E; hint E1; hint E2.
Tactic Notation "hint" constr(E) "," constr(E1) "," constr(E2) "," constr(E3) :=
  hint E; hint E1; hint E2; hint E3.
Tactic Notation "hint" constr(E) "," constr(E1) "," constr(E2) "," constr(E3) "," constr(E4) :=
  hint E; hint E1; hint E2; hint E3; hint E4.
Tactic Notation "hint" constr(E) "," constr(E1) "," constr(E2) "," constr(E3) "," constr(E4) "," constr(E5) :=
  hint E; hint E1; hint E2; hint E3; hint E4; hint E5.


Inductive RR (A : Prop) : Prop :=
| rewrite_rule : forall a : A, RR A.

Definition unRR (A : Prop) (r : RR A) :=
  match r with
  | rewrite_rule rr => rr
  end.

Tactic Notation "hint_rewrite" constr(E) := 
  let H := fresh "Hint" in
  let t := type of E in
  assert (H : RR t) by (exact (rewrite_rule E)).

Tactic Notation "hint_rewrite" constr(E) "," constr(E1) :=
  hint_rewrite E; hint_rewrite E1.
Tactic Notation "hint_rewrite" constr(E) "," constr(E1) "," constr(E2) :=
  hint_rewrite E; hint_rewrite E1; hint_rewrite E2.
Tactic Notation "hint_rewrite" constr(E) "," constr(E1) "," constr(E2) "," constr(E3) :=
  hint_rewrite E; hint_rewrite E1; hint_rewrite E2; hint_rewrite E3.

Ltac swap_rewrite t :=
  match type of t with
  | ?v1 = ?v2 => constr:(eq_sym t) 
  | forall x : ?T, _ =>
    (* let ret :=  *)constr:(fun x : T => let r := t x in 
                                      ltac:(let r' := swap_rewrite r in
                                            exact r')) (* in *)
    (* let ret' := (eval cbv zeta in ret) in *)
    (* constr:(ret) *)
  end.

Tactic Notation "hint_rewrite" "<-" constr(E) := 
  let H := fresh "Hint" in
  let E' := swap_rewrite E in
  let t := type of E' in
  assert (H : RR t) by (exact (rewrite_rule E')).


Hint Extern 5 => match goal with
                |[H : RR (_ = _) |- _] =>
                 progress (rewrite (unRR H) in *)
                end.
Hint Extern 5 => match goal with
                |[H : RR (forall _, _ = _) |- _] =>
                 progress (rewrite (unRR H) in *)
                end.
Hint Extern 5 => match goal with
                |[H : RR (forall _ _, _ = _) |- _] =>
                 progress (rewrite (unRR H) in *)
                end.
Hint Extern 5 => match goal with
                |[H : RR (forall _ _ _, _ = _) |- _] =>
                 progress (rewrite (unRR H) in *)
                end.
Hint Extern 5 => match goal with
                |[H : RR (forall _ _ _ _, _ = _) |- _] =>
                 progress (rewrite (unRR H) in *) 
                end.
Hint Extern 5 => match goal with
                |[H : RR (forall _ _ _ _ _, _ = _) |- _] =>
                 progress (rewrite (unRR H) in *) 
                end.
Hint Extern 5 => match goal with
                |[H : RR (forall _ _ _ _ _ _, _ = _) |- _] =>
                 progress (rewrite (unRR H) in *) 
                end.
Hint Extern 5 => match goal with
                |[H : RR (forall _ _ _ _ _ _ _, _ = _) |- _] =>
                 progress (rewrite (unRR H) in *) 
                end.


Ltac simplify :=
  repeat (simpl in *;
          match goal with 
          |[H: True |- _] => clear H
          |[H: ?x <> ?x |- _] => exfalso; apply H; reflexivity
          |[|- ?P /\ ?Q] => try (solve [split; eauto 2] || (split; eauto 2; [idtac]))
          |[H: ?P /\ ?Q |- _] => invert H
          |[a: ?x * ?y |- _] => destruct a
          end).


(**************************************)
(************ 1. SYNTAX ***************)
(**************************************)

(** This section contains the types and terms for
    out simply typed lambda calculus (which has bools,
    if, and pairs).
*)

Inductive ty  : Set :=
| Bool : ty
| Fun : ty -> ty -> ty
| Product : ty -> ty -> ty.

Inductive exp : Set :=
| Var : string -> exp
| Const : bool -> exp
| Abs : string -> ty -> exp -> exp
| App : exp -> exp -> exp
| If : exp -> exp -> exp -> exp
| Pair : exp -> exp -> exp.

Inductive value : exp -> Prop :=
| VBool : forall b, value (Const b)
| VAbs : forall x t e, value (Abs x t e)
| VPair : forall v1 v2, value v1 -> value v2 -> value (Pair v1 v2).

Ltac value :=
  match goal with
    |[H : value _ |- _] => invert H
  end.

(**************************************)
(**** 2. SUBSTITUTION/ENVIRONMENTS ****)
(**************************************)

(** This section contains definitions of environments,
    extension, substitution, what it means to be
    closed, etc.

    In this presentation, environments are represented
    as lists, _not_ as functions as is sometimes done.
*)

Definition tyenv := list (string * ty).

Definition venv := list (string * exp).

Definition extend {T : Set} (G : list (string * T)) (x:string) (t : T) : list (string * T) :=
  cons (x,t) G.

Fixpoint mextend  {T : Set} (e : list (string * T)) (G : list (string * T)) {struct G} : list (string * T) :=
  match G with
    | nil => e
    | cons (x,v) G' => extend (mextend e G') x v
  end.

Fixpoint lookup {T : Set}
                (E : list (string * T))
                (x:string) : option T :=
  match E with
    |cons (y,t) rest => if string_dec y x then Some t else lookup rest x
    |nil => None
  end.

Fixpoint drop {T : Set}
         (x:string)
         (E : list (string * T)) : list (string * T) :=
  match E with
    | nil => nil
    | cons (y,t) rest => if string_dec x y then drop x rest else cons (y,t) (drop x rest)
  end.

Fixpoint sub (x:string) (e:exp) (e':exp) : exp :=
  match e with
    | Var y => if string_dec y x then e' else e
    | Const b => e
    | Abs y t body => if string_dec y x
                     then e
                     else Abs y t (sub x body e')
    | App e1 e2 => App (sub x e1 e') (sub x e2 e')
    | If ec e1 e2 => If (sub x ec e')
                       (sub x e1 e')
                       (sub x e2 e')
    | Pair e1 e2 => Pair (sub x e1 e') (sub x e2 e')
    end.

Notation "'[' x ':=' s ']' t" := (sub x t s) (at level 20).

Inductive free_in : string -> exp -> Prop :=
| free_var : forall x, free_in x (Var x)
| free_abs : forall x t y e, free_in x e ->
                      x <> y ->
                      free_in x (Abs y t e)
| free_app1 : forall x e1 e2, free_in x e1 ->
                         free_in x (App e1 e2)
| free_app2 : forall x e1 e2, free_in x e2 ->
                         free_in x (App e1 e2)
| free_if1 : forall x e1 e2 e3, free_in x e1 ->
                           free_in x (If e1 e2 e3)
| free_if2 : forall x e1 e2 e3, free_in x e2 ->
                           free_in x (If e1 e2 e3)
| free_if3 : forall x e1 e2 e3, free_in x e3 ->
                           free_in x (If e1 e2 e3)
| free_pair1 : forall x e1 e2, free_in x e1 ->
                          free_in x (Pair e1 e2)
| free_pair2 : forall x e1 e2, free_in x e2 ->
                          free_in x (Pair e1 e2).

Hint Constructors free_in.

Ltac free_in :=
  match goal with
    |[H : free_in _ _ |- _] => invert H
  end.

Definition closed t := forall x, ~ free_in x t.

Fixpoint closed_env (e:venv) :=
  match e with
    | nil => True
    | cons (_,e1) en => closed e1 /\ closed_env en
  end.

Fixpoint close (Σ : venv) (e : exp) : exp :=
  match Σ with
    |nil => e
    |cons (x,v) Σ' => close Σ' ([x:=v]e)
  end.


(**************************************)
(******** 3. TYPING JUDGEMENT *********)
(**************************************)

(** This section contains the main typing judgement.
*)

Reserved Notation "Γ '|--' e" (at level 10).

Inductive has_type : tyenv -> exp -> ty -> Prop :=
| TConst : forall Γ b, has_type Γ (Const b) Bool
| TVar : forall Γ x t, lookup Γ x = Some t -> has_type Γ (Var x) t
| TAbs : forall Γ x e t t', has_type (extend (drop x Γ) x t) e t' ->
                       has_type Γ (Abs x t e) (Fun t t')
| TApp : forall Γ e e' t1 t2, has_type Γ e (Fun t1 t2) ->
                         has_type Γ e' t1 ->
                         has_type Γ (App e e') t2
| TIf : forall Γ e1 e2 e3 t, has_type Γ e1 Bool ->
                        has_type Γ e2 t ->
                        has_type Γ e3 t ->
                        has_type Γ (If e1 e2 e3) t
| TPair : forall Γ e1 e2 t1 t2, has_type Γ e1 t1 ->
                           has_type Γ e2 t2 ->
                           has_type Γ (Pair e1 e2)
                                      (Product t1 t2)
where "Γ '|--' e" := (has_type Γ e).

Hint Constructors has_type ty exp value.

Ltac has_type := 
  match goal with
  |[H : _ |-- ?E ?T |- _ ] =>
   not_var E exp; invert H
  end.


(**************************************)
(****** 4. EVALUATION RELATION ********)
(**************************************)

(** This section contains the evaluation relation for
    the language, which is based on evaluation contexts.
*)

Inductive context : Set :=
| CHole : context
| CApp1 : context -> exp -> context
| CApp2 : exp -> context -> context
| CIf : context -> exp -> exp -> context
| CPair1 : context -> exp -> context
| CPair2 : exp -> context -> context.

Hint Constructors context.

Inductive plug : context -> exp -> exp -> Prop :=
| PHole : forall e, plug CHole e e
| PApp1 : forall e e' C e2, plug C e e' ->
                       plug (CApp1 C e2) e (App e' e2)
| PApp2 : forall e e' C v, plug C e e' ->
                       value v ->
                       plug (CApp2 v C) e (App v e')
| PIf : forall e e' C e2 e3, plug C e e' ->
                        plug (CIf C e2 e3) e (If e' e2 e3)
| PPair1 : forall e e' C e2, plug C e e' ->
                        plug (CPair1 C e2) e (Pair e' e2)
| PPair2 : forall e e' C v, plug C e e' ->
                       value v ->
                       plug (CPair2 v C) e (Pair v e').

Hint Constructors plug.

Ltac plug := let c := constr:(context) in
             match goal with
             |[H : plug ?C1 _ _ |- _ ] =>
              not_var C1 c; invert H
             end.

Inductive step_prim : exp -> exp -> Prop :=
| SBeta : forall x t e v, value v -> step_prim (App (Abs x t e) v)
                                         ([x:=v]e)
| SIfTrue : forall e1 e2, step_prim (If (Const true) e1 e2) e1
| SIfFalse : forall e1 e2, step_prim (If (Const false) e1 e2) e2.

Hint Constructors step_prim.

Ltac step_prim :=
  match goal with
    |[S : step_prim _ _ |- _] => invert S
  end.

Inductive step : exp -> exp -> Prop :=
| Step : forall C e1 e2 e1' e2', plug C e1 e1' ->
                            plug C e2 e2' ->
                            step_prim e1 e2 ->
                            step e1' e2'.

Hint Constructors step.

Ltac step :=
  match goal with
    |[H : step _ _ |- _] => invert H
  end.

Inductive multi A (R : A -> A -> Prop) : A -> A -> Prop :=
| MultiRefl : forall x,
  multi R x x
| MultiStep : forall x1 x2 x3,
  R x1 x2
  -> multi R x2 x3
  -> multi R x1 x3.

Hint Constructors multi.

Lemma multi_trans {A} : forall (R : A -> A -> Prop) a b c,
                      multi R a b ->
                      multi R b c ->
                      multi R a c.
Proof.
  intros.
  induction H; eauto.
Qed.

(**************************************)
(******* 5. LOGICAL RELATION **********)
(**************************************)

(** We define the primary relation, which due to
    positivity restrictions is a fixpoint rather than
    an inductive type, and also what it means for a
    substitution to contain values in the relation.
*)

Definition halts  (e:exp) : Prop :=
  exists e', multi step e e' /\  value e'.

Ltac halts :=
  match goal with
  |[H: halts _ |- _ ] => invert H
  end.

Fixpoint SN (T : ty) (t : exp) : Prop :=
  (nil |-- t T) /\ halts t /\
  (match T with
     | Bool => True
     | Fun T1 T2 => forall s, SN T1 s -> SN T2 (App t s)
     | Product T1 T2 => True
   end).

Reserved Notation "Γ '|=' Σ" (at level 40).

Inductive fulfills : tyenv -> venv -> Prop :=
| FNil : fulfills nil nil
| FCons : forall x t e Γ Σ,
            SN t e ->
            fulfills Γ Σ ->
            fulfills (cons (x,t) Γ) (cons (x,e) Σ)
where "Γ '|=' Σ" := (fulfills Γ Σ).

Hint Constructors fulfills.
Hint Extern 5 (_ |= _) => eapply FCons.
(* NOTE(dbp 2017-03-25): If there is an extend (for example) that needs to be
unfolded, the constructor won't match directly, so we try to use it anyway. *)

(**************************************)
(******** 6. MISC. PROPERTIES *********)
(**************************************)

(** This section contains a bunch of intermediate results
    about substition, evaluation contexts, etc.

    These mostly correspond to properties that are
    ellided in paper proofs, or at least, defined as
    proceeding by "straightforward induction on X".

    On first reading, you should probaby skip this
    section, proceeding either to the next section,
    which covers more interesting properties of the
    language (preservation, determinism, anti-reduction),
    etc, or probably skip right to the section titled
    "COMPATIBILITY LEMMAS", as those are the lemmas
    that are motivate all the other intermediate results.
 *)


Ltac completer :=
  match goal with
    |[IH : forall x, _ -> ?P x = ?Q x,
        H: ?P ?x = ?y
        |- ?Q ?x = ?y] => rewrite <- (IH x)
    |[IH : forall x, _ -> ?Q x = ?P x,
        H: ?P ?x = ?y
        |- ?Q ?x = ?y] => rewrite (IH x)
    |[IH : forall x y z, ?P x y -> ?Q x z -> y = z,
        H1 : ?P ?x ?y,
        H2 : ?Q ?x ?z
        |- _] => rewrite (IH x y z H1 H2)
    |[IH : forall x, (forall _, _ -> _) -> ?P x _ _ |- ?P ?x _ _] =>
     eapply (IH x)
    |[IH : forall a b, _ -> ?P b ?x a |- ?P ?b ?x ?a] =>
     eapply IH
  end.

Lemma plug_same : forall C x e1 e2,
                    plug C x e1 ->
                    plug C x e2 ->
                    e1 = e2.
Proof.
  intro C.
  induction C;
    intros; repeat plug; try completer; eauto.
Qed.

Lemma plug_exists : forall C e e' e1,
                      plug C e e' ->
                      multi step e e1 ->
                      exists e1', plug C e1 e1'.
Proof.
  intro C;
    induction C; intros; repeat plug; 

      (* This is uninteresting; the presence of existentials is only reason why
         it isn't shorter. *)
      try match goal with
          |[IH : forall _, _, H : plug ?C _ _ |- _ ] =>
           is_var C; eapply IH in H; eauto; inversion H
          end;
      
      eexists; eauto.
Qed.

Lemma plug_compose : forall C C' e e' e'',
                       plug C e e' ->
                       plug C' e' e'' ->
                       (exists C'', forall e1 e2 e3,
                                 plug C e1 e2 ->
                                 plug C' e2 e3 ->
                                 plug C'' e1 e3).
Proof.
  induction 2;
    (* Similar to last Lemma, this is essentially by induction; we just have to
    do some work to use what the induction hypothesis tells us. *)
  try match goal with
    |[IH : context[_:?P -> _],
          H : ?P |- _] => apply IH in H; inversion H
      end;
  eexists; intros; repeat plug; eauto.
Qed.

Lemma step_context : forall C e1 e2,
                        step e1 e2 ->
                        forall e1' e2',
                        plug C e1 e1' ->
                        plug C e2 e2' ->
                        step e1' e2'.
Proof.
  intros.
  invert H.
  destruct (plug_compose H2 H0). 
  eauto.
Qed.

Lemma multi_context : forall C e1 e2,
                        multi step e1 e2 ->
                        forall e1' e2',
                        plug C e1 e1' ->
                        plug C e2 e2' ->
                        multi step e1' e2'.
Proof.
  hint plug_exists, step_context.
  intros C e1 e2 H.
  induction H; intros.

  - match goal with
    |[H1: plug _ _ ?e1, H2: plug _ _ ?e2 |- multi step ?e1 ?e2] =>
     hint_rewrite (plug_same H1 H2)
    end; eauto 2.
  - assert (HF: exists ex2, plug C x2 ex2) by eauto.
    invert HF; eauto.
Qed.



Lemma close_const : forall Σ b, close Σ (Const b) = (Const b).
Proof.
  intros.
  induction Σ; eauto; simpl in *; simplify; eauto.
Qed.

Lemma halts_value : forall v, value v -> halts v.
Proof.
  intros; eexists; eauto.
Qed.

Lemma sn_halts : forall t e, SN t e -> halts e.
Proof.
  intros. destruct t;
  unfold SN in *;
  simplify;
  eauto.
Qed.

Lemma string_dec_refl : forall T s (t:T) (f:T), (if string_dec s s then t else f) = t.
Proof.
  intros.
  destruct (string_dec s s).
  - eauto.
  - exfalso; eauto.
Qed.

Lemma string_dec_ne : forall T s s' (t:T) (f:T), s <> s' -> (if string_dec s s' then t else f) = f.
Proof.
  intros.
  destruct (string_dec s s').
  - subst. contradiction H. eauto.
  - reflexivity.
Qed.

Ltac string :=
  match goal with
  |[ H : context[string_dec ?x ?y] |- _ ] =>
   match goal with
     [x : string, y : string |- _] =>
     destruct (string_dec x y); try subst
   end
  |[ H : context[string_dec ?x ?x] |- _ ] =>
   match goal with
     [x : string |- _] =>
     destruct (string_dec x x); try subst
   end   
  |[ H : _ |- context[string_dec ?x ?y] ] =>
   destruct (string_dec x y); try subst
  end.

Lemma lookup_fulfill_v : forall (Γ:tyenv) (Σ:venv),
                           Γ |= Σ ->
                           forall x (t:ty),
                             lookup Γ x = Some t ->
                             exists v, lookup Σ x = Some v.
Proof.
  intros Γ Σ H.
  induction H; intros;
    simpl in *; eauto;
  crush;
  string; eauto.
Qed.


Lemma sub_closed : forall x e, ~ free_in x e ->
                          forall e', [x:=e']e = e.
Proof.
  intros.
  induction e; simpl;
  try solve [intuition (eauto; crush)];
  string; crush.
Qed.

Lemma close_closed : forall Σ e, closed e -> close Σ e = e.
Proof.
  hint_rewrite sub_closed.
  unfold closed in *;
  intro Σ.
  induction Σ; crush; eauto.
Qed.

Lemma close_var : forall Σ x e, closed_env Σ ->
                           lookup Σ x = Some e ->
                           close Σ (Var x) = e.
Proof.
  hint close_closed.
  intros.
  induction Σ; crush; repeat (simplify; string); crush.
Qed.

Lemma lookup_fulfill_sn : forall Γ Σ,
                            Γ |= Σ ->
                            forall t x v,
                              lookup Γ x = Some t ->
                              lookup Σ x = Some v ->
                              SN t v.
Proof.
  intros Γ Σ H.
  induction H; intros; [crush|idtac].
  simpl in *; string; eauto; crush.
Qed.

Lemma lookup_drop : forall (Γ : list (string * ty)) x y,
                      x <> y ->
                      lookup (drop x Γ) y = lookup Γ y.
Proof.
  hint_rewrite string_dec_ne, string_dec_refl.
  intros.
  induction Γ; 
    repeat (eauto; simplify; string; simpl; eauto).
Qed.

Lemma free_in_context : forall x e t Γ,
                          free_in x e ->
                          Γ |-- e t ->
                              exists t', lookup Γ x = Some t'.
Proof.
  hint_rewrite string_dec_ne, string_dec_refl.

  intros.
  induction H0; free_in; crush; eauto.

  rewrite lookup_drop in *; eauto.
Qed.

Lemma typable_empty_closed : forall e t, nil |-- e t -> closed e.
Proof.
  unfold closed. unfold not. intros.
  destruct (free_in_context H0 H). crush.
Qed.

Lemma sn_typable_empty : forall e t, SN t e -> nil |-- e t.
Proof.
  intros.
  destruct t; crush.
Qed.

Lemma sn_closed : forall t e, SN t e -> closed e.
Proof.
  hint typable_empty_closed, sn_typable_empty.
  intros. eauto.
Qed.

Lemma fulfill_closed : forall Γ Σ, Γ |= Σ -> closed_env Σ.
Proof.
  hint typable_empty_closed, sn_typable_empty.
  
  intros.
  induction H; simpl; eauto.
Qed.



Lemma close_abs : forall Σ x t e, close Σ (Abs x t e) =
                             Abs x t (close (drop x Σ) e).
Proof.
  induction Σ; intros; simpl;
  repeat (simplify; string); crush.
Qed.

Lemma context_invariance : forall Γ Γ' e t,
     Γ |-- e t  ->
     (forall x, free_in x e -> lookup Γ x = lookup Γ' x)  ->
     Γ' |-- e t.
Proof.
  hint_rewrite lookup_drop.

  intros.
  generalize dependent Γ'.
  induction H; intros; crush;
  try solve [econstructor; completer; crush].

  econstructor; completer. intros.
  simpl in *. string; crush.
Qed.

Lemma free_closed : forall x v t, (nil |-- v t) ->
                             free_in x v -> False.
Proof.
  intros; destruct (free_in_context H0 H); crush.
Qed.

Lemma substitution_preserves_typing : forall Γ x t v e t',
     (extend Γ x t') |-- e t  ->
     nil |-- v t'   ->
     Γ |-- ([x:=v]e) t.
Proof.
  hint free_closed.
  hint_rewrite string_dec_ne, string_dec_refl.
  intros.
  generalize dependent Γ.
  generalize dependent t.
  induction e;
    intros; simpl; inversion H; subst;
    try solve[econstructor; eauto];
    try solve[crush; string; eauto].

  (* var *)
  simpl in *. string; crush.
  string.
  eapply context_invariance with (Γ := nil); eauto.
  intros.
  exfalso; eauto.
  exfalso; eauto.

  (* abs *)
  simpl in *.
  string; eauto.
  string; eauto.
  (* <> *)
  assert (s <> x) by eauto.
  rewrite (unRR Hint0). 
  econstructor.
  completer.
  eapply context_invariance; eauto.
  intros. simpl. string; crush.
  eauto.
Qed.

Lemma sn_types : forall t e, SN t e -> nil |-- e t.
Proof.
  hint sn_typable_empty.

  intros.
  destruct t; eauto.
Qed.


Lemma close_preserves : forall Γ Σ, Γ |= Σ ->
                        forall G e t,
                          (mextend G Γ) |-- e t ->
                          G |-- (close Σ e) t.
Proof.
  hint sn_typable_empty, substitution_preserves_typing.
  induction 1; intros;
  simpl in *; eauto.
Qed.

Lemma fulfills_drop : forall Γ Σ,
    Γ |= Σ ->
    forall x, (drop x Γ) |= (drop x Σ).
Proof.
  intros c e V. induction V; intros;
                simpl; try string; crush.
Qed.

Lemma extend_drop : forall {T:Set}
                      (Γ : list (string * T))
                      (Γ' : list (string * T)) x x',
  lookup (mextend Γ' (drop x' Γ)) x
  = if string_dec x x'
    then lookup Γ' x
    else lookup (mextend Γ' Γ) x.
Proof.
  intros. induction Γ; simplify; string; 
          repeat (simpl;
                  repeat string;
                  iauto).
Qed.

Lemma extend_drop'' : forall Γ x t t' e,
                        (extend (drop x Γ) x t) |-- e t' ->
                        (extend Γ x t) |-- e t'.
Proof.
  hint lookup_drop.
  intros.
  eapply context_invariance; eauto;
    intros;
  free_in; has_type;
  simpl; string; crush.
Qed.

Lemma lookup_same : forall Γ x (t:ty) (t':ty),
                      lookup x Γ = Some t ->
                      lookup x Γ = Some t' ->
                      t = t'.
Proof.
  intros. rewrite H in H0. crush.
Qed.

Lemma typed_hole : forall C e e' t,
                     nil |-- e t ->
                     plug C e' e ->
                     exists t', nil |-- e' t'.
Proof.
  intros.
  generalize dependent t.
  induction H0; intros;
  match goal with
  |[H : _ |-- _ _ |- _] => invert H
  end;
  eauto.
Qed.



Lemma plug_values : forall e v C, plug C e v ->
                             value v ->
                             value e.
Proof.
  intros e v C P H.
  induction P; value; eauto.
Qed.

Lemma multi_subst : forall x v1 v2 e,
                      closed v1 -> closed v2 ->
                      [x:=v1]([x:=v2]e) = [x:=v2]e.
Proof.
  intros.
  induction e; eauto; try solve[crush];
  simpl; string; eauto; simpl;
  try match goal with
    |[H: closed ?v |- [_ := _]?v = ?v] =>
     rewrite sub_closed; unfold closed in H; eauto
  end;
  string; eauto; crush.
Qed.

Ltac closed_tac :=
  match goal with
    |[H: closed ?v |- [_ := _]?v = ?v] =>
     rewrite sub_closed; unfold closed in H; eauto
    |[H: closed ?v |- ?v = [_ := _]?v] =>
     rewrite sub_closed; unfold closed in H; eauto
  end.

Lemma swap_sub : forall x1 x2 v1 v2 e,
                   x1 <> x2 ->
                   closed v1 ->
                   closed v2 ->
                   [x1:=v1]([x2:=v2]e) = [x2:=v2]([x1:=v1]e).
Proof.
  intros.
  induction e;
    simpl;
    repeat string; simpl;
    repeat string; eauto;
    try closed_tac; eauto;
    repeat string; eauto;
    crush.
Qed.

Lemma sub_close: forall Σ x v e,
                      closed v ->
                      closed_env Σ ->
                      close Σ ([x:=v]e) = [x:=v](close (drop x Σ) e).
Proof.
  intro Σ.
  induction Σ; intros; simpl; repeat (simplify; string); eauto;
  repeat string; simpl;
  try solve[rewrite multi_subst; eauto; crush];
  try solve[rewrite swap_sub; crush].
Qed.

Lemma multistep_App2 : forall v e e',
                         value v ->
                         multi step e e' ->
                         multi step (App v e) (App v e').
Proof.
  intros.
  eapply multi_context with (e1 := e) (e2 := e'); eauto.
Qed.

Lemma sub_close_extend :
  forall x v e Σ,
    closed v ->
    closed_env Σ ->
    [x:=v](close (drop x Σ) e) =
    close (extend (drop x Σ) x v) e.
Proof.
  intros.
  generalize dependent e.
  simpl.
  induction Σ; intros; eauto;
  simplify;
  string;
  simpl; try rewrite swap_sub; crush.
Qed.

Lemma drop_sub : forall Σ x v e,
                   closed v ->
                   closed_env Σ ->
                   close (drop x Σ) ([x:=v]e) =
                   close Σ ([x:=v]e).
Proof.
  intro Σ.
  induction Σ; intros;
  repeat string; iauto; simplify; string; simplify; simpl;
  try solve [rewrite multi_subst; crush];
  try solve [rewrite swap_sub; crush].
Qed.

Lemma extend_drop' : forall Σ (x:string) (v:exp) e,
                       closed_env Σ ->
                       closed v ->
                       close (extend (drop x Σ) x v) e
                       = close (cons (x,v) Σ) e.
Proof.
  induction Σ; intros; eauto; try (simplify; string; simplify); simpl;
  try (simplify; string; simplify); simpl;
  [rewrite drop_sub; eauto;
   try solve [rewrite multi_subst; eauto; crush];
   crush
  |rewrite swap_sub; crush].
Qed.

Lemma lookup_mextend : forall (Γ : list (string * ty)) x x0 t,
                        x <> x0 ->
                        lookup ((x, t) :: Γ) x0 =
                        lookup (mextend (cons (x, t) nil) Γ) x0.
Proof.
  intros.
  simpl.
  string; iauto.
  induction Γ; try solve [crush];
  repeat (simpl; string; iauto).
Qed.


Lemma close_app : forall Σ e1 e2,
                    close Σ (App e1 e2) =
                    App (close Σ e1) (close Σ e2).
Proof.
  intro Σ.
  induction Σ; simpl; intuition.
Qed.

Lemma close_if : forall Σ e1 e2 e3,
                    close Σ (If e1 e2 e3) =
                    If (close Σ e1) (close Σ e2) (close Σ e3).
Proof.
  intro Σ.
  induction Σ; simpl; intuition.
Qed.

Lemma drop_fulfills : forall Γ Σ x,
                        Γ |= Σ ->
                        drop x Γ |= drop x Σ.
Proof.
  hint fulfills_drop.
  intros.
  induction H; eauto.
Qed.

Lemma close_pair : forall Σ e1 e2,
                    close Σ (Pair e1 e2) =
                    Pair (close Σ e1) (close Σ e2).
Proof.
  intro Σ.
  induction Σ; simpl; intuition.
Qed.

(**************************************)
(**** 7. ANTI-REDUCTION/DETERMINISM ***)
(**************************************)

(** This section contains interesting results about
    the language - primarily, preservation of types (that
    if a well-typed term steps to another term which is
    well typed, at the same type) and also of halting
    (that if a term halts, anything it steps to will
    halt as well), anti-reduction (that if a term
    is well typed and steps to a term that is
    in the logical relation, then the original term
    must have been as well, determinism (that if two
    terms step, they must step to the same term).

    We also show that any well typed term has a unique
    type (which, interesting, is what requires that we
    provide a type binder on Abs), which is needed for
    the type preservation result.

    Of these, the result that perhaps seems the least
    necessary is determinism. But we need it to show
    preservation of halting, as we argue that the
    steps that allows a term e to halt must include
    the term e', and thus e' will halt as well. It's
    likely the result could work without determinism,
    but the definition of halting would probably need
    to change, and since STLC is deterministic, it's a
    reasonable property to check.
*)



Lemma preservation_prim_step : forall e1 e2 t,
                                 nil |-- e1 t ->
                                 step_prim e1 e2 ->
                                 nil |-- e2 t.
Proof.
  intros.
  step_prim; subst; eauto;
  has_type; subst; eauto;
  eapply substitution_preserves_typing; eauto;
  match goal with
    |[H: (nil |-- _) (Fun _ _) |- _] => inversion H
  end;
  subst; eauto.
Qed.


Lemma unique_typing : forall e Γ t t',
                        Γ |-- e t ->
                        Γ |-- e t' ->
                        t = t'.
Proof.
  hint lookup_same.
  intro e.
  induction e; intros; eauto;
  inversion H; inversion H0; eauto;
  try (apply f_equal); try (apply f_equal2); eauto.

  (* app *)
  assert (EQ : (Fun t1 t) = (Fun t0 t')). eauto.
  inversion EQ; eauto.
Qed.

Lemma preservation_plug : forall C e1 e2 e1' e2' t t',
                            nil |-- e1' t ->
                            nil |-- e1 t' ->
                            nil |-- e2 t' ->
                            plug C e1 e1' ->
                            plug C e2 e2' ->
                            nil |-- e2' t.
Proof.
  intro C.
  induction C; intros.

  repeat plug. assert (t = t') by (eapply unique_typing; eauto).
  subst; eauto.

  all: repeat plug; has_type; eauto 3.
Qed.

Lemma preservation_step : forall e1 e2 t, nil |-- e1 t ->
                                     step e1 e2 ->
                                     nil |-- e2 t.
Proof.
  hint preservation_plug, preservation_prim_step.
  intros.
  inversion H0; subst.
  match goal with
    |[H1: (_ |-- ?e) _, H2: plug C _ ?e |- _] =>
     destruct (typed_hole H1 H2)
  end;
  eauto.
Qed.

Lemma preservation : forall e1 e2 t, multi step e1 e2 ->
                                nil |-- e1 t ->
                                nil |-- e2 t.
Proof.
  hint preservation_step.
  intros.
  induction H; eauto.
Qed.


Lemma anti_reduct : forall e' e t, multi step e e' ->
                              SN t e' ->
                              nil |-- e t ->
                              SN t e.
Proof.
  hint sn_typable_empty, @multi_trans.
  intros.
  generalize dependent e.
  generalize dependent e'.
  induction t; intros; unfold SN; crush;
  try solve[match goal with
              |[H: halts _ |- halts _] => invert H
            end;
             crush;
             unfold halts;
             exists x; eauto];
  fold SN in *; intros;
  eapply IHt2; eauto;
  eapply multi_context with (C := CApp1 CHole s);
  eauto.
Qed.

Lemma values_dont_step : forall v e, value v -> ~step v e.
Proof.
  hint plug_values.
  unfold not. intros. step; value;
  match goal with
    |[H: plug _ _ (Const _) |- _] => invert H
    |[H: plug _ _ (Abs _ _ _) |- _] => invert H
    |[H: plug _ _ (Pair _ _) |- _] => invert H
  end; subst; try (assert (value e1) by iauto;
                   inversion H;
                   subst);
  step_prim.
Qed.

Lemma step_prim_deterministic : forall e1 e2 e2',
                                  step_prim e1 e2 ->
                                  step_prim e1 e2' ->
                                  e2 = e2'.
Proof.
  intros. repeat step_prim; eauto.
Qed.

Ltac smash :=
  repeat try match goal with
               |[H: plug _ ?e ?v,
                    H1: value ?v,
                        H2: step_prim ?e _ |- _] =>
                assert (value e) by (eapply plug_values;
                                     iauto);
                  exfalso; eapply values_dont_step; iauto
               |[H : App _ _ = App _ _ |- _] => invert H
               |[H : If _ _ _ = If _ _ _ |- _] => invert H
               |[H : Pair _ _ = Pair _ _ |- _] => invert H
               |[H : plug _ _ _ |- _] => invert H; []
               |[H : plug _ _ ?v, H1 : value ?v |- _] => invert H
               |[H : step_prim _ _ |- _] => invert H
               |[H : value (App _ _) |- _] => invert H
               |[H : value (If _ _ _) |- _] => invert H
               |[H : If _ _ _ = App _ _ |- _] => invert H
               |[H : App _ _ = If _ _ _ |- _] => invert H
               |[H : If _ _ _ = Pair _ _ |- _] => invert H
               |[H : App _ _ = Pair _ _ |- _] => invert H
               |[H : Pair _ _ = If _ _ _ |- _] => invert H
               |[H : Pair _ _ = App _ _ |- _] => invert H
             end.

Lemma plug_step_uniq : forall C e e1 e2,
                         plug C e1 e ->
                         step_prim e1 e2 ->
                         forall C' e1' e2',
                           plug C' e1' e ->
                           step_prim e1' e2' ->
                           C = C' /\ e1' = e1.
Proof.
  intros C e e1 e2 H H0.
  induction H; intros;
  try match goal with
        |[H1: step_prim ?e _, H2: plug _ _ ?e |- _] =>
         invert H1; invert H2; iauto; smash
      end;
  try match goal with
    |[H: value (Pair ?e _), H1: plug _ _ ?e |- _] =>
     invert H; eapply plug_values in H1; invert H1; iauto
    |[H: value (Pair _ ?e), H1: plug _ _ ?e |- _] =>
     invert H; eapply plug_values in H1; invert H1; iauto
  end;
  match goal with
    |[H: plug _ _ (App _ _) |- _] =>
     invert H; try solve [smash]
    |[H: plug _ _ (If _ _ _) |- _] =>
     invert H; try solve [smash]
    |[H: plug _ _ (Pair _ _) |- _] =>
     invert H; try solve [smash]
  end;
  match goal with
    |[H: _ -> forall C _ _, _ -> _ -> ?C0 = C /\ _ |-
       (CApp1 ?C0 ?e0 = CApp1 ?C1 ?e0 /\ ?P)] =>
     assert (C0 = C1 /\ P) by (eapply H; eauto); crush
    |[H: _ -> forall C _ _, _ -> _ -> ?C0 = C /\ _ |-
       (CApp2 ?v0 ?C0 = CApp2 ?v0 ?C1 /\ ?P)] =>
     assert (C0 = C1 /\ P) by (eapply H; eauto); crush
    |[H: _ -> forall C _ _, _ -> _ -> ?C0 = C /\ _ |-
                      (CIf ?C0 _ _ = CIf ?C1 _ _ /\ ?P)] =>
     assert (C0 = C1 /\ P) by (eapply H; eauto); crush
    |[H: _ -> forall C _ _, _ -> _ -> ?C0 = C /\ _ |-
       (CPair1 ?C0 ?e0 = CPair1 ?C1 ?e0 /\ ?P)] =>
     assert (C0 = C1 /\ P) by (eapply H; eauto); crush
    |[H: _ -> forall C _ _, _ -> _ -> ?C0 = C /\ _ |-
       (CPair2 ?v0 ?C0 = CPair2 ?v0 ?C1 /\ ?P)] =>
     assert (C0 = C1 /\ P) by (eapply H; eauto); crush
  end.
Qed.

Lemma step_deterministic : forall e1 e2 e2',
                             step e1 e2 ->
                             step e1 e2' ->
                             e2 = e2'.
Proof.
  induction 1; intros.
  step.
  destruct (plug_step_uniq H H1 H3 H5); subst.
  assert (e2 = e3).
  apply (step_prim_deterministic H1 H5).
  subst.
  destruct (plug_same H4 H0); eauto.
Qed.

Lemma step_preserves_halting : forall e e',
                                 step e e' ->
                                 (halts e <-> halts e').
Proof.
  hint step_deterministic.
  intros. unfold halts.
  split; intros; crush;
  try solve[exists x; eauto].
  match goal with
    |[H: multi step _ _ |- _] => invert H; subst
  end;
  try solve[exfalso; eapply values_dont_step; eauto];
  match goal with
    |[H: value ?x |- _] => exists x; eauto
  end;
  match goal with
    |[H1: multi step ?a _, H2: step ?e ?a,
      H3: step ?e ?b |- multi step ?b _ /\ value _] =>
     assert (a = b) by iauto; subst; eauto
  end.
Qed.

Lemma step_preserves_sn : forall t e e',
                            step e e' ->
                            SN t e ->
                            SN t e'.
Proof.
  hint step_context, preservation_step.

  induction t; intros e e' H H0; crush; eauto;
  try match goal with
        |[_: halts ?e, _: step ?e ?e' |- halts ?e'] =>
         eapply step_preserves_halting with (e:=e); eauto
      end;
  match goal with
    |[H: forall _ _, _ -> SN ?t _ -> _ |- SN ?t _] => eapply H
  end; eauto.
Qed.

Lemma multistep_preserves_sn : forall t e e',
                                 multi step e e' ->
                                 SN t e ->
                                 SN t e'.
Proof.
  hint step_preserves_sn.
  intros.
  induction H; eauto.
Qed.


(**************************************)
(****** 8. COMPATIBILITY LEMMAS *******)
(**************************************)

(** This section contains the primary results,
    which show for each term in the language, if
    it is well typed then it is in the logical
    relation.

    The most interesting one is certainly TAbs,
    which proceeds primarily by appealing to
    anti-reduction, but TIf has it's own trick,
    because in order to show that it halts, we have
    to step it to the intermediate term where the head
    position is a (Const b) value, and then handle each
    case separately by appealing to the corresponding
    hypothesis for the then or else branches.
*)


Lemma TConst_compat : forall Γ Σ b,
                        Γ |= Σ ->
                        SN Bool (close Σ (Const b)).
Proof.
  hint close_const, halts_value.
  crush.
Qed.

Lemma TVar_compat : forall Γ Σ x t,
                      Γ |= Σ ->
                      lookup Γ x = Some t ->
                      SN t (close Σ (Var x)).
Proof.
  hint lookup_fulfill_sn, fulfill_closed.
  intros.
  destruct (lookup_fulfill_v H x H0); eauto.
  rewrite close_var with (e := x0); eauto.
Qed.


Lemma TAbs_typing : forall Γ Σ x e t t',
                      Γ |= Σ ->
                      (extend (drop x Γ) x t) |-- e t' ->
                      nil |-- (Abs x t (close (drop x Σ) e)) (Fun t t').
Proof.
  hint lookup_drop, fulfills_drop.
  hint_rewrite string_dec_ne, string_dec_refl.

  intros.
  econstructor. eapply close_preserves.
  - eauto.
  - eapply context_invariance. iauto.
    intros. simpl. rewrite extend_drop.
    repeat string.
    * simpl. crush.
    * iauto.
    * iauto.
    * unfold extend.
      rewrite <- lookup_mextend.
      -- simpl. string.
         ** simplify.
         ** eauto.
      -- eauto.
Qed.

Lemma TAbs_app : forall x t Σ e xh,
                   value xh ->
                   closed xh ->
                   closed_env Σ ->
                   multi step (App (Abs x t (close (drop x Σ) e)) xh)
                         (close (extend (drop x Σ) x xh) e).
Proof.
  hint_rewrite sub_close_extend.

  intros; eauto.
Qed.

Lemma TAbs_compat : forall Γ Σ x e t t',
                      Γ |= Σ ->
                      (extend (drop x Γ) x t) |-- e t' ->
                      (forall v, SN t v -> SN t' (close (extend (drop x Σ) x v) e)) ->
                      SN (Fun t t') (close Σ (Abs x t e)).
Proof.
  hint_rewrite close_abs.
  hint TAbs_typing, lookup_fulfill_sn, fulfill_closed, TAbs_app, halts_value.
  hint sn_typable_empty, @multi_trans.
  intros.
  crush; eauto.

  assert (HH: halts s) by (hint sn_halts; eauto).
  inversion HH as [xh MS]. crush.
  assert (SN t xh) by (hint multistep_preserves_sn; eauto).
  assert (closed xh) by (hint sn_closed; eauto).


  eapply anti_reduct with (e' := close (extend (drop x Σ) x xh) e); try solve [crush]; try solve [eauto].
  eapply multi_trans with (b := (App (Abs x t (close (drop x Σ) e)) xh)); iauto';
  eapply multi_context with (e1 := s) (e2 := xh); iauto'.
Qed.

Lemma TApp_compat : forall Γ Σ e1 e2 t t',
                      Γ |= Σ ->
                      SN (Fun t t') (close Σ e1) ->
                      SN t (close Σ e2) ->
                      SN t' (close Σ (App e1 e2)).
Proof.
  hint_rewrite close_app.
  intros; crush.
Qed.

Lemma TIf_const : forall t b e1 e2 e3, SN t e2 ->
                                  SN t e3 ->
                                  nil |-- e1 Bool ->
                                  multi step e1 (Const b) ->
                                  SN t (If e1 e2 e3).
Proof.
  hint sn_types.
  intros.
  destruct b.
  (* This follows by case analysis on b, then anti-reduction, and finally we
     have to lift evaluation to the context. *)
  - eapply anti_reduct with (e' := e2); eauto;
      eapply multi_trans with (b := (If (Const true) e2 e3));
      eauto;
      eapply multi_context; eauto.
  - eapply anti_reduct with (e' := e3); eauto;
      eapply multi_trans with (b := (If (Const false) e2 e3));
      eauto;
      eapply multi_context; eauto.
Qed.


Lemma TIf_compat : forall Γ Σ e1 e2 e3 t,
                      Γ |= Σ ->
                      SN Bool (close Σ e1) ->
                      SN t (close Σ e2) ->
                      SN t (close Σ e3) ->
                      SN t (close Σ (If e1 e2 e3)).
Proof.
  hint sn_typable_empty, sn_halts.
  intros; simplify;
  rewrite close_if.

  (* We first figure out if the test expression evaluates to true or false. *) 
  match goal with
  |[H : (_ |-- ?e) Bool, H1 : halts ?e |- _] =>
   (* By figuring out the value that it runs to *)
     invert H1
  end; simplify;
  match goal with
  |[H0: value ?x, H1: multi step _ ?x |- _] =>
   (* And then using preservation to show that the value must be a bool. *)
   assert (nil |-- x Bool) by (hint preservation; eauto);
     destruct x; eauto; try solve [has_type]; try solve [inversion H0]
  end; simplify.

  (* At which point, the rest follows by case analylis on the bool and
     anti-reduction. *)
  hint TIf_const; eauto.
Qed.


Lemma TPair_halts : forall Σ e1 e2, halts (close Σ e1) ->
                               halts (close Σ e2) ->
                               halts (Pair (close Σ e1) (close Σ e2)).
Proof.
  intros; 
  repeat halts; (* Unfold halts to get values. *)
  simplify.

  match goal with
  |[H1: value ?v1, H2: value ?v2 |- _ ] =>
   (* Claim that we will step to a pair of the two values that came from inputs. *)
   eexists (Pair v1 v2) 
  end; simplify; 

  match goal with
  |[H: multi step ?e ?v' |- multi step _ (Pair ?v ?v')] =>
   (* Use transitivity with value (that has stepped) / expression (that will step) pair. *)
   eapply multi_trans with (b := (Pair v e))
  end;

  (* Lift stepping of term to stepping in (Pair [.] e) or (Pair e [.]) context. *)
  match goal with
  |[H: multi step _ ?v |- multi step (Pair ?e _) (Pair ?v _)] =>
   not_var e exp; eapply (multi_context H); eauto
  |[H: multi step _ ?v |- multi step (Pair _ ?e) (Pair _ ?v)] =>
   not_var e exp; eapply (multi_context H); eauto
  end.
Qed.
 

Lemma TPair_compat : forall Γ Σ e1 e2 t1 t2,
                      Γ |= Σ ->
                      SN t1 (close Σ e1) ->
                      SN t2 (close Σ e2) ->
                      SN (Product t1 t2)
                         (close Σ (Pair e1 e2)).
Proof.
  hint_rewrite close_pair.
  hint sn_typable_empty, sn_halts, TPair_halts.
  intros; unfold SN;
  repeat split; eauto.
Qed.


(**************************************)
(****** 9. FUNDAMENTAL THEOREM ********)
(**************************************)

(** The fundamental theorem simply states that
    a well-typed open term, when closed with a
    substitution that contains values that are
    in the logical relation, will be in the logical
    relation.

    We can then apply that (trivially) to an empty
    environment to get that any closed term halts.
*)

Theorem fundamental : forall e t Γ Σ,
                        Γ |-- e t ->
                            Γ |= Σ ->
                            SN t (close Σ e).
Proof.
  hint TConst_compat, TVar_compat, TAbs_compat.
  hint TApp_compat, TIf_compat, TPair_compat.
  hint fulfills_drop.
  intros.
  generalize dependent Σ.
  induction H; intros; eauto.
Qed.

Theorem strong_normalization : forall e t,
                                 nil |-- e t ->
                                 halts e.
Proof.
  hint fundamental, sn_halts.
  intros.
  assert (SN t (close nil e)); eauto.
Qed.