(***********************************************************************)
(*                                                                     *)
(*                           Objective Caml                            *)
(*                                                                     *)
(*            Xavier Leroy, projet Cristal, INRIA Rocquencourt         *)
(*                                                                     *)
(*  Copyright 1997 Institut National de Recherche en Informatique et   *)
(*  en Automatique.  All rights reserved.  This file is distributed    *)
(*  under the terms of the Q Public License version 1.0.               *)
(*                                                                     *)
(***********************************************************************)

(* $Id: selection.ml 7812 2007-01-29 12:11:18Z xleroy $ *)

(* Instruction selection for the IA32 architecture *)

open Misc
open Arch
open Proc
open Cmm
open Reg
open Mach

(* Auxiliary for recognizing addressing modes *)

type addressing_expr =
    Asymbol of string
  | Alinear of expression
  | Aadd of expression * expression
  | Ascale of expression * int
  | Ascaledadd of expression * expression * int

let rec select_addr exp =
  match exp with
    Cconst_symbol s ->
      (Asymbol s, 0)
  | Cop((Caddi | Cadda), [arg; Cconst_int m]) ->
      let (a, n) = select_addr arg in (a, n + m)
  | Cop((Csubi | Csuba), [arg; Cconst_int m]) ->
      let (a, n) = select_addr arg in (a, n - m)
  | Cop((Caddi | Cadda), [Cconst_int m; arg]) ->
      let (a, n) = select_addr arg in (a, n + m)
  | Cop(Clsl, [arg; Cconst_int(1|2|3 as shift)]) ->
      begin match select_addr arg with
        (Alinear e, n) -> (Ascale(e, 1 lsl shift), n lsl shift)
      | _ -> (Alinear exp, 0)
      end
  | Cop(Cmuli, [arg; Cconst_int(2|4|8 as mult)]) ->
      begin match select_addr arg with
        (Alinear e, n) -> (Ascale(e, mult), n * mult)
      | _ -> (Alinear exp, 0)
      end
  | Cop(Cmuli, [Cconst_int(2|4|8 as mult); arg]) ->
      begin match select_addr arg with
        (Alinear e, n) -> (Ascale(e, mult), n * mult)
      | _ -> (Alinear exp, 0)
      end
  | Cop((Caddi | Cadda), [arg1; arg2]) ->
      begin match (select_addr arg1, select_addr arg2) with
          ((Alinear e1, n1), (Alinear e2, n2)) ->
              (Aadd(e1, e2), n1 + n2)
        | ((Alinear e1, n1), (Ascale(e2, scale), n2)) ->
              (Ascaledadd(e1, e2, scale), n1 + n2)
        | ((Ascale(e1, scale), n1), (Alinear e2, n2)) ->
              (Ascaledadd(e2, e1, scale), n1 + n2)
        | (_, (Ascale(e2, scale), n2)) ->
              (Ascaledadd(arg1, e2, scale), n2)
        | ((Ascale(e1, scale), n1), _) ->
              (Ascaledadd(arg2, e1, scale), n1)
        | _ ->
              (Aadd(arg1, arg2), 0)
      end
  | arg ->
      (Alinear arg, 0)
    
(* C functions to be turned into Ifloatspecial instructions if -ffast-math *)

let inline_float_ops =
  ["atan"; "atan2"; "cos"; "log"; "log10"; "sin"; "sqrt"; "tan"]

(* Special constraints on operand and result registers *)

exception Use_default

let eax = phys_reg 0
let ecx = phys_reg 2
let edx = phys_reg 3
let tos = phys_reg 100

let pseudoregs_for_operation op arg res =
  match op with
  (* Two-address binary operations *)
    Iintop(Iadd|Isub|Imul|Iand|Ior|Ixor)  | Iaddf|Isubf|Imulf|Idivf ->
      ([|res.(0); arg.(1)|], res)
  (* Two-address unary operations *)
  | Iintop_imm((Iadd|Isub|Imul|Idiv|Iand|Ior|Ixor|Ilsl|Ilsr|Iasr), _)
  | Inegf|Iabsf ->
      (res, res)
  (* For shifts with variable shift count, second arg must be in ecx *)
  | Iintop(Ilsl|Ilsr|Iasr) ->
      ([|res.(0); ecx|], res)
  (* For div and mod, first arg must be in eax, edx is clobbered,
     and result is in eax or edx respectively.
     Keep it simple, just force second argument in ecx. *)
  | Iintop(Idiv) ->
      ([| eax; ecx |], [| eax |])
  | Iintop(Imod) ->
      ([| eax; ecx |], [| edx |])
  (* For mod with immediate operand, arg must not be in eax.
     Keep it simple, force it in edx. *)
  | Iintop_imm(Imod, _) ->
      ([| edx |], [| edx |])
  (* For storing a byte, the argument must be in eax...edx.
     (But for a short, any reg will do!)
     Keep it simple, just force the argument to be in edx. *)
  | Istore((Byte_unsigned | Byte_signed), addr) ->
      let newarg = Array.copy arg in
      newarg.(0) <- edx;
      (newarg, res)
  (* Inline trig & exp functions have arguments and result on the FP stack *)
  | Ispecific(Ifloatspecial _) ->
      (Array.map (fun _ -> tos) arg, [| tos |])
  (* Other instructions are regular *)
  | _ -> raise Use_default

let chunk_double = function
    Single -> false
  | Double -> true
  | Double_u -> true
  | _ -> assert false

(* The selector class *)

class selector = object (self)

inherit Selectgen.selector_generic as super

method is_immediate (n : int) = true

method select_addressing exp =
  match select_addr exp with
    (Asymbol s, d) ->
      (Ibased(s, d), Ctuple [])
  | (Alinear e, d) ->
      (Iindexed d, e)
  | (Aadd(e1, e2), d) ->
      (Iindexed2 d, Ctuple[e1; e2])
  | (Ascale(e, scale), d) ->
      (Iscaled(scale, d), e)
  | (Ascaledadd(e1, e2, scale), d) ->
      (Iindexed2scaled(scale, d), Ctuple[e1; e2])

method select_store addr exp =
  match exp with
    Cconst_int n ->
      (Ispecific(Istore_int(Nativeint.of_int n, addr)), Ctuple [])
  | Cconst_natint n ->
      (Ispecific(Istore_int(n, addr)), Ctuple [])
  | Cconst_pointer n ->
      (Ispecific(Istore_int(Nativeint.of_int n, addr)), Ctuple [])
  | Cconst_natpointer n ->
      (Ispecific(Istore_int(n, addr)), Ctuple [])
  | Cconst_symbol s ->
      (Ispecific(Istore_symbol(s, addr)), Ctuple [])
  | _ ->
      super#select_store addr exp

method select_operation op args =
  match op with
  (* Recognize the LEA instruction *)
    Caddi | Cadda | Csubi | Csuba ->
      begin match self#select_addressing (Cop(op, args)) with
        (Iindexed d, _) -> super#select_operation op args
      | (Iindexed2 0, _) -> super#select_operation op args
      | (addr, arg) -> (Ispecific(Ilea addr), [arg])
      end
  (* Recognize (x / cst) and (x % cst) only if cst is a power of 2. *)
  | Cdivi ->
      begin match args with
        [arg1; Cconst_int n] when n = 1 lsl (Misc.log2 n) ->
          (Iintop_imm(Idiv, n), [arg1])
      | _ -> (Iintop Idiv, args)
      end
  | Cmodi ->
      begin match args with
        [arg1; Cconst_int n] when n = 1 lsl (Misc.log2 n) ->
          (Iintop_imm(Imod, n), [arg1])
      | _ -> (Iintop Imod, args)
      end
  (* Recognize store instructions *)
  | Cstore Word ->
      begin match args with
        [loc; Cop(Caddi, [Cop(Cload _, [loc']); Cconst_int n])]
        when loc = loc' ->
          let (addr, arg) = self#select_addressing loc in
          (Ispecific(Ioffset_loc(n, addr)), [arg])
      | _ ->
          super#select_operation op args
      end
  (* Recognize inlined trig & exp floating point operations *)
  | Cextcall(fn, ty_res, false, dbg)
    when !fast_math && List.mem fn inline_float_ops ->
      (Ispecific(Ifloatspecial fn), args)
  (* Default *)
  | _ -> super#select_operation op args

(* Deal with register constraints *)

method insert_op_debug op dbg rs rd =
  try
    let (rsrc, rdst) = pseudoregs_for_operation op rs rd in
    self#insert_moves rs rsrc;
    self#insert_debug (Iop op) dbg rsrc rdst;
    self#insert_moves rdst rd;
    rd
  with Use_default ->
    super#insert_op_debug op dbg rs rd

method insert_op op rs rd =
  self#insert_op_debug op Debuginfo.none rs rd

(* Selection of push instructions for external calls *)

method select_push exp =
  match exp with
    Cconst_int n -> (Ispecific(Ipush_int(Nativeint.of_int n)), Ctuple [])
  | Cconst_natint n -> (Ispecific(Ipush_int n), Ctuple [])
  | Cconst_pointer n -> (Ispecific(Ipush_int(Nativeint.of_int n)), Ctuple [])
  | Cconst_natpointer n -> (Ispecific(Ipush_int n), Ctuple [])
  | Cconst_symbol s -> (Ispecific(Ipush_symbol s), Ctuple [])
  | Cop(Cload Word, [loc]) ->
      let (addr, arg) = self#select_addressing loc in
      (Ispecific(Ipush_load addr), arg)
  | Cop(Cload Double_u, [loc]) ->
      let (addr, arg) = self#select_addressing loc in
      (Ispecific(Ipush_load_float addr), arg)
  | _ -> (Ispecific(Ipush), exp)

method emit_extcall_args env args =
  let rec size_pushes = function
  | [] -> 0
  | e :: el -> Selectgen.size_expr env e + size_pushes el in
  let sz1 = size_pushes args in
  let sz2 = Misc.align sz1 stack_alignment in
  let rec emit_pushes = function
  | [] ->
      if sz2 > sz1 then 
        self#insert (Iop (Istackoffset (sz2 - sz1))) [||] [||]
  | e :: el ->
      emit_pushes el;
      let (op, arg) = self#select_push e in
      match self#emit_expr env arg with
      | None -> ()
      | Some r -> self#insert (Iop op) r [||] in
  emit_pushes args;
  ([||], sz2)

end

let fundecl f = (new selector)#emit_fundecl f
