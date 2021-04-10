(* Copyright 2017-2019 Pierre Courtieu *)
(* This file is part of LibHyps.

    LibHyps is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    LibHyps is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with LibHyps.  If not, see <https://www.gnu.org/licenses/>.
*)

(** Demonstration file for LibHyps tactics and tacticals. this makes
    use of the old syntax !tac and !!tac. Se the LibHypsTest.v file
    for up to date examples. *)

Require Import Arith ZArith LibHyps.LibHyps List.
Import TacNewHyps.Notations.
Import LibHyps.Notations.

(* 1 the "tac1;{ tac2}" TACTICAL (and its synonym "tac1;;tac2") and
   auto(re)naming of hypothesis *)
Ltac rename_depth ::= constr:(3).

Lemma foo: forall (x:nat) (b1:bool) (y:nat) (b2:bool),
    x = y
    -> forall  a b:nat, forall b3:bool, forall t : nat,
      let aa := a + 1 in 
      a+1 = t+2
      -> b + 5 = t - 7
      -> forall z, forall b4:bool, forall z',
          (forall u v, v+1 = 1 -> u+1 = 1 -> aa = z+2)
          -> z = b + x-> z' + 1 = b + x-> True.
Proof.
  
  (* intros gives bad names: *)
  intros.
  (* We can auto rename tactics afterwards: *)
  autorename H3.
  autorename H1.

  Undo 3. (* Be careful this may not be supported by your ide. *)
  Show.
  (* Better: apply autorename to each new hyps using the ;; tactical: *)
  intros ;{ autorename }.

  Undo.
  (* Other syntax *)
  intros ;; autorename .

  Undo.
  (* [!tac] is a shortcut for [tac ;; autorename]. Actually it
     performs a bit more: it would reverts hyps for which it could not
     compute a name for. *)
  intros /n.
  Undo.

  (* same but also use subst if possible. *)
  intros;; substHyp;; autorename.
  Undo.

  (* Shortcut (also reverts when no name is found): *)
  intros /s/n.
  Undo.

  (* shorter *)
  intros /sn.
  Undo.

  (* same but also push non-prop hyps to the top of the goal (i.e. out
     of sight). *)
  intros;;substHyp;;autorename;;move_up_types.
  Undo.
  
  (* This can be done like this too:  *)
  intros /n/g;; move_up_types.
  Undo.

  (* or even shorter: *)
  intros /s/n/g.
  Undo.

  (* or even: *)
  intros /sng.
  Undo.


  (* the "tac1 ;; tac2" tactical can be used after any tactic tac1.
  The only restriction is that tac2 should expect a (single)
  hypothesis name as argument *)
  induction z ;; substHyp;;autorename.
  Undo.

  (* shortcut also apply to any tactic. *)
  induction z /sn.
  Undo.

  (* Finally see at the end of this demo for customizing the
     autonaming heuristic. *)

  (* # USING ESPECIALIZE. *)
  intros /n.

  (* Let us start a proof to instantiate the 2nd premis (u+1=1) of
     h_all_eq_add_add without a verbose assert: *)
  especialize h_all_eq_aa_add_ at 2.
  { apply Nat.add_0_l. }
  (* now h_all_eq_add_add is specialized *)

  Undo 6.
  Show.
  intros ? ? ? ? ? /n.
  (** Do subst on new hyps only, notice how x=y is not subst and
    remains as 0 = y. Contrary to z = b  + x which is substituted. *)
  destruct x eqn:heq;intros / s.
  - apply I.
  - apply I.
Qed.

(** Example of tactic notations to define shortcuts for the examples
   above: here =tac does "apply tac and try subst on all new hypothesis" *)
Local Tactic Notation "=" tactic3(Tac) := Tac ;{< substHyp }.

Lemma bar: forall x y a t u v : nat,
    x = v -> a = t -> u = x -> u = y -> x = y.
Proof.
  =intros.
  Undo.
  intros.
  =destruct x eqn:heq. (* heq subst'ed *)
  - subst;auto.
  - subst;auto.
Qed.


(** Example of tactic notations to define shortcuts: <=tac means "apply
   tac and reverts all created hypothesis" *)
Local Tactic Notation "<=" tactic3(Tac) := Tac ;!; revertHyp.

Lemma bar2: forall x y a t u v : nat,
    x = v -> a = t -> u = x -> u = y -> x = y.
Proof.
  intros.
  revert dependent x.
  intro x.
  <=destruct (x). (* Careful, if "x" is reused (destruct x.),
                           then it is not detected as "new". *)
  - intros;subst;auto.
  - intros;subst;auto.
Qed.



(** Another exampe: <-tac means "apply tac and try subst on all created
   hypothesis, revert when subst fails" *)
Local Tactic Notation "<-" tactic3(Tac) := Tac ;!; subst_or_revert.

Lemma bar': forall x y a t u v : nat,
    x < v -> a = t -> u > x -> u = y -> x < y.
Proof.
  <-intros.
  auto.
Qed.


(** 1 especialize allows to do forward reasoning without copy pasting statements.
   from a goal of the form 
H: forall ..., h1 -> h2 ... hn-1 -> hn -> hn+1 ... -> concl.
========================
G
especialize H at n.
gives two subgoals:
H: forall ..., h1 -> h2 ... hn-1 -> hn+1 ... -> concl.
========================
G
========================
hn
this creates as much evars as necessary for all parameters of H that
need to be instantiated.
Example: *)

Definition test n := n = 1.
Definition Q (x:nat) (b:bool) (l:list nat):= True.

Lemma foo':
  (forall n b l, b = true -> test n -> Q n b l) ->
  Q 1 true (cons 1 nil).
Proof.
  intro hyp.
  (* I want to prove the (test n) hypothesis of hyp, without knowing n
     yet, and specialize hyp with it immediately. *)

  especialize hyp at 2.
  { reflexivity. }
  Undo 4.

  (* Same thing with a given name for the new premis once proved *)
  especialize hyp at 2:foo.
  { reflexivity. }
  Undo 4.

  (* Build a new hypothesis instead of specializing hyp itself *)
  especialize hyp at 2 as h.
  { reflexivity. }
  specialize hyp with (2:=hyp_prem).
  Undo 5.

  (* same with a given name for the premiss *)
  especialize hyp at 2 : foo as h.
  { reflexivity. }
  specialize hyp with (2:=foo).
  Undo 5.

  apply I.
Qed.



(** 1 Auto naming hypothesis *)

(** Let us custmize the naming scheme:  *)

(* First open the some dedicated notations (namely `id` and x#n below). *)
Local Open Scope autonaming_scope.
Import ListNotations.

(* Define the naming scheme as new tactic pattern matching on the type
th of the hypothesis (h being the hyp name), and the depth n of the
recursive naming analysis. Here we state that a type starting with
Nat.eqb should start with _Neqb, followed by the name of both
arguments. #n here means normal decrement of depth. *)
Ltac rename_hyp_2 n th :=
  match th with
  | Nat.eqb ?x ?y = _ => name(`_Neqb` ++ x#n ++ y#n)
  | _ = Nat.eqb ?x ?y => name(`_Neqb` ++ x#n ++ y#n)
  end.

(* Then overwrite the customization hook of the naming tactic *)
Ltac rename_hyp ::= rename_hyp_2.

(** Suppose I want to add another naming rule: I need to cumulate the
    previous scheme with the new one. First define a new tactic that
    will replace the old one. it should call previous naming schemes
    in case of failure of the new scheme *)
Ltac rename_hyp_3 n th :=
  match th with
  | true <> false => name(`_tNEQf`)
  | true = false => name(`_tEQf`)
  (* if all failed, call the previously defined naming tactic, which
     must not be rename_hyp since it will be overwritten: *)
  | _ => rename_hyp_2 n th
  end.

(* Then update the customization hook *)
Ltac rename_hyp ::= rename_hyp_3.
(* Close the naming scope *)
Local Close Scope autonaming_scope.

(* Fix the naming depth 2 should be ok in most situations. 3 gives
very long names by default *)
Ltac rename_depth ::= constr:(2).


(** 2 Example of uses of the naming schemes. *)
Lemma dummy: forall x y,
    (forall nat : Type, (nat -> nat -> Prop) -> list nat -> Prop) ->
    (let a := 0 in a = 0) -> (* this is is not treated for renaming *)
    (exists x, (let a := x in a = 0) /\ (x >=0)) -> (* this too, once decomposed *)
    0 <= 1 ->
    0 = 1 ->
    (0%Z <= 1%Z)%Z ->
    (0%Z <= 6%Z)%Z ->
    x <= y ->
    x = y ->
    0 = 3 ->
    (1 = 8)%Z ->
    ~x = y ->
    true = Nat.eqb 3 4  ->
    Nat.eqb 3 4 = true  ->
    true = Nat.leb 3 4  ->
    1 = 0 ->
    ~x = y ->
    ~1 < 0 ->
     (forall w w':nat , w = w' -> ~true=false)=(forall w w':nat , w = w' -> ~true=false) ->
     (forall w w':nat , w = w' -> ~true=false) ->
     (forall w w':nat , w = w' -> true=false /\ True) ->
     (forall w w':nat , w = w' -> true=false) ->
     (forall w w':nat , w = w' -> False /\ True) ->
     (exists w:nat , ~(true=(andb false true)) /\ le w w /\ w = x) ->
     (exists w:nat , w = w -> ~(true=(andb false true)) /\ False) ->
     (exists w:nat , w = w -> True /\ False) ->
     (forall w w':nat , w = w' -> true=false) ->
     (forall w:nat , w = w -> true=false) ->
     (forall w:nat, (Nat.eqb w w)=false) ->
     (forall w w':nat , w = w' -> Nat.eqb 3 4=Nat.eqb 4 3) ->
    List.length (cons 3 nil) = (fun x => 0)1 ->
    List.length (cons 3 nil) = x ->
    plus 0 y = y ->
    plus (plus (plus x y) y) y = y ->
    (true=false) ->
    (true<>false) ->
    (False -> (true=false)) ->
    forall (a b: nat) (env : list nat),
      ~ List.In a nil ->
      cons a (cons 3 env) = cons 2 env ->
    forall z t:nat,
      IDProp ->
      a = b ->
      (0 < 1 -> 0 < 0 -> true = false -> ~(true=false)) ->
      (~(true=false)) ->
      (forall w w',w < w' -> ~(true=false)) ->
      plus (plus (plus x y) a) b = t ->
      plus (plus (plus x y) a) b < 0 ->
      (0 < 1 -> ~(1<0)) ->
      (0 < 1 -> 1<0) -> 0 < z -> True.
  (* auto naming at intro: *)
Proof.
  intros.
  onAllHyps autorename.
  Undo 2.
  (* Shorter: the ! tactical applies a tactic and then applies
     autorename on new hypothesis: *)
  intros/n.
  Undo.
  (* combining ! and = defined previously (subst) *)
  =intros/n.
  Undo.
  (** Reduce renaming depth to 2: *)
  Ltac rename_depth ::= constr:(1).
  (* names are shorter, more collisions *)
  intros/n.
  Undo.
  Ltac rename_depth ::= constr:(3).
  intros/n.
  (** move up all non prop hypothesis *)
  Undo.
  (* Let us have really big names. *)
  Ltac rename_depth ::= constr:(5).
  intros/n.
  Undo 2.
  Ltac rename_depth ::= constr:(3).
  intros/n.
  (* decompose and revert all new hyps *)
  decompose [ex and] h_ex_and_neq_and_ ;!; revertHyp.
  Undo.
  (* decompose and subst or revert all new hyps *)
  decompose [ex and] h_ex_and_neq_and_ ;!; subst_or_revert.
  Undo.
  (* decompose and rename all new hyps *)
  decompose [ex and] h_ex_and_neq_and_ ;!; autorename.
  Undo.
  (* in short: *)
  decompose [ex and] h_ex_and_neq_and_ /n.
  Undo.
  (* decompose and subst or rename all new hyps *)
  decompose [ex and] h_ex_and_neq_and_;; substHyp.
  Undo.
  (* decompose and subst or rename all new hyps, revert if nothing applies *)
  decompose [ex and] h_ex_and_ge_ /s ;!; revert_if_norename /n.
  intros h1.
  exact I.
Qed.
