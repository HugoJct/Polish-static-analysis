open Printf
open Types
open Eval_polish

(** Projet Polish -- Analyse statique d'un mini-langage impératif *)

(** Note : cet embryon de projet est pour l'instant en un seul fichier
    polish.ml. Il est recommandé d'architecturer ultérieurement votre
    projet en plusieurs fichiers source de tailles raisonnables *)



(* Ici on évalue la valeur de vérité de deux valeurs en fonction d'un opérateur logique *)
let eval_comp condition =
  let compare val1 comp_type val2 =
    match comp_type with
      | Eq -> if val1 = val2 then true else false
      | Ne -> if val1 = val2 then false else true
      | Lt -> if val1 < val2 then true else false
      | Le -> if val1 <= val2 then true else false
      | Gt -> if val1 > val1 then true else false
      | Ge -> if val1 >= val2 then true else false
    in match condition with (val1, comp_type, val2) -> compare val1 comp_type val2;;


(* Ici, via un chemin passé en argument, on récupère le contenu
 d'un fichier de type Polish dans une chaine de charactère. On va ensuite
 transférer le contenu de cette variable dans une liste de chaines de caractères 
 avec, pour chaque élément de cette liste, un "mot" identifié préalablement par 
 des caractères vides comme délimiteurs en début et fin
*)
let read_file (file:string) : (string list)=
  let ic = open_in file in
  let try_read () =
    try Some (input_line ic) with End_of_file -> None in
  let rec loop acc = match try_read () with
    | Some s -> loop (s :: acc)
    | None -> close_in ic; List.rev acc in
  loop []

(* Fonction appelée si l'instruction en préfix est de type READ.
  On renvoie donc e la suite de la ligne à lire*)
let collect_name line : name =
  match line with 
    | [] -> failwith("empty line")
    | e::line' -> e;;

(* Fonction pour évaluer si l'argument est un entier *)
let is_int str : bool=
  let verif_num n =
    try (int_of_string n |> string_of_int) = n
    with Failure _ -> false in 
  verif_num str;;

(* Ici on parcourt la ligne pour identifier les opérateurs qu'on va ajouter
  dans une structure Op avec ses valeurs *)
let rec collect_expr (line:string list) : expr =
  match line with
    | [] -> failwith("Unrecognized operator")
    | e::e'::l -> (match e with
      | "+" -> Op(Add, collect_expr (e'::l), collect_expr l)
      | "-" -> Op(Sub, collect_expr (e'::l), collect_expr l)
      | "*" -> Op(Mul, collect_expr (e'::l), collect_expr l)
      | "/" -> Op(Div, collect_expr (e'::l), collect_expr l)
      | "%" -> Op(Mod, collect_expr (e'::l), collect_expr l)
      | _ -> if is_int e then Num(int_of_string e) else Var(e))
    | e::l -> if is_int e then Num(int_of_string e) else Var(e)

let rec get_set_index (line: string list) (ind:int): int =
  match line with 
  | [] -> failwith("No affectation symbol found")
  | e::l -> (match e with
              | ":=" -> ind
              | _ -> get_set_index l (ind+1));;

let rec get_string_from_i (str:'a list) (i:int) : 'a list =
  match str with
  |[] -> failwith("Empty")
  |e::l -> if i = 0 then l else get_string_from_i l (i-1);; 

let collect_set (line: string list) : instr =
  let index = get_set_index line 0 in
  Set((collect_name line) , (collect_expr (get_string_from_i line index ) ));;

let get_indentation (line:(int * string)) :int =
    let words = (String.split_on_char ' ' (snd line)) in 
    let rec aux (words: string list) acc = 
      match words with
      | [] -> acc
      | e::l -> if (String.equal e "") then (aux l (acc+1)) else acc in
      (aux words 0) / 2;;

let rec is_comp (str: string list) (ind:int) : (comp * int) = 
  (match str with
  | [] -> failwith("No comparator found")
  |e::l -> (match e with
            | "=" -> (Eq,ind)
            | "<" -> (Lt,ind)
            | "<=" -> (Le,ind)
            | ">" -> (Gt,ind)
            | ">=" -> (Ge,ind)
            | "<>" -> (Ne,ind)
            | _ -> is_comp l (ind+1)));;

let rec get_string_without_indentation (str: string list) = 
  match str with
  | [] -> []
  | e::l -> if (String.equal e "") then get_string_without_indentation l else str;;

let collect_cond (line:string list) : cond = 
  let op = is_comp line 0 in
    ((collect_expr line) , (fst op) , (collect_expr (get_string_from_i line (snd op))) );;

let rec collect_block (lines: (position * string) list) (ind:int) : (block * ((position * string) list) ) = 
  (match lines with
  | [] -> ([],[])
  | e::l -> if get_indentation e = ind 
            then 
              let first_instruction = (collect_instr lines) in
              let block = collect_block (snd first_instruction) ind in
              (((fst first_instruction)::(fst block)),(snd block))
            else
              ([],lines)) 

and

(* Ici on va chercher à collecter le type d'instruction du début de la ligne 
  passée en argument. Pour chaque type d'instruction identifiée, on crée la bonne
  structure avec les opérateurs et expressions associées *)
collect_instr (lines:(position * string) list ) : ( (position * instr) * ((position * string) list))=
  (match lines with
  | [] -> failwith("Empty line start collect instr")
  | e::l -> let line = snd e and 
              pos = fst e in
              let line_split = get_string_without_indentation (String.split_on_char ' ' line) and
              ind = get_indentation e in
            (match line_split with
             | [] -> failwith("Empty string split on char")
             | first::rest -> (match first with
                                | "READ" -> ( (pos,Read(collect_name rest)) ,l)
                                | "IF" -> (let condition = (collect_cond rest) in 
                                          let block_if = (collect_block l (ind+1)) in
                                          let block_else = (collect_else (snd block_if) (ind+1) ) in 
                                          ((pos,If(condition,(fst block_if),(fst block_else))),(snd block_else)) )  
                                | "WHILE" -> let condition = (collect_cond rest) and 
                                                block = (collect_block l (ind+1)) in 
                                                ( (pos,While(condition,(fst block))), (snd block))
                                | "PRINT" -> ( (pos,Print(collect_expr rest)) ,l)
                                | "COMMENT" -> (collect_instr l)
                                | _ -> ((pos,(collect_set line_split )),l) ))) 
and

collect_else (lines: (position * string) list) (ind:int) : (block * ((position * string) list)) =
  match lines with
  | [] -> ([],[])
  | e::l -> if String.equal (snd e) "ELSE" then (collect_block l ind) else ([],lines);;

let is_empty (ls: 'a list) : bool = List.length ls = 0;;

let rec reprint_polish (program:program) (ind_nbr:int) : unit= 
        let rec print_indentation ind =
                if ind > 0 then (printf "  " ; print_indentation (ind-1)) else printf "" and
        print_expr (expr:expr) =
                (match expr with 
                | Num(i) -> printf "%d " i
                | Var(n) -> printf "%s " n
                | Op(o,e1,e2) -> print_op o ; print_expr e1 ; print_expr e2) and
        print_op (op:op) = 
                (match op with
                | Add -> printf "+ " 
                | Sub -> printf "- " 
                | Mul -> printf "* "
                | Div -> printf"/ " 
                | Mod -> printf "%% ") and 
        print_cond (cond:cond) = 
                (match cond with
                | (e1,c,e2) -> print_expr e1 ; print_comp c ; print_expr e2) and
        print_comp (comp:comp) =
                (match comp with
                | Eq -> printf "= "
                | Ne -> printf "<> "
                | Lt -> printf "< "
                | Le -> printf "<= "
                | Gt -> printf "> "
                | Ge -> printf ">= ") and
        print_block (block:block) ind_nbr = 
                printf "\n" ; reprint_polish block ind_nbr and
        print_instr (instr:instr) ind_nbr =
                print_indentation ind_nbr ;
              (match instr with
                | Set(n,e) -> (printf "%s := " n ) ; (print_expr e)
                | Read(n) -> printf "READ %s" n 
                | Print(e) -> printf "PRINT " ; print_expr e 
                | If(c,b,b2) -> printf "IF " ; print_cond c ; print_block b (ind_nbr+1);  if not(is_empty b2) then (printf "\nELSE " ; print_block b2 (ind_nbr+1))
                | While(c,b) -> printf "WHILE " ; print_cond c ; print_block b (ind_nbr+1) ) in
        match program with
        | e::[] -> print_instr (snd e) ind_nbr
        | e::l -> print_instr (snd e) ind_nbr; printf "\n"  ; reprint_polish l ind_nbr
        | _ -> printf "";;

(***********************************************************************)

(* tests *)
(* let file_content = read_file "exemples/abs.p";; *)
(* let () = List.iter (printf "%s ") file_content;; *)

(* absolute value function *)
let condi = (Var("n"),Lt,Num(0));;
let block1 = [(3,Set("res",Op(Sub,Num(0),Var("n"))));(0,Print(Var("Test")))];;
let block2 = [(5,Set("res",Var("n")))];;
let ifs = If(condi,block1,block2);;
let abs = [(1,Read("n"));(2,ifs);(6,Print(Var("res")))];;
let test = [(1,Set("t",Var("n"))); (6,Print(Var("t")))];;
(* reprint_polish abs 0;
printf "\n";; *)


(***********************************************************************)

let read_polish (filename:string) : program = 
  let program = read_file filename in 
  let rec number_lines (prg: string list) acc : (position * string ) list =
      match prg with 
      | [] -> []
      | e::l -> (acc,e)::(number_lines l (acc+1)) in
  let lines_raw = number_lines program 1 in
  let rec browse_string_list (lines_to_parse:(position * string) list) : program=
    let res = (collect_instr lines_to_parse) in
    match (snd res) with
    | [] -> (fst res)::[]
    | _ -> (fst res)::(browse_string_list (snd res))
  in browse_string_list lines_raw;;
  

let print_polish (p:program) : unit = reprint_polish p 0;;

let eval_polish (p:program) : unit = (* browse_program program [] *)
  failwith "TODO"

let usage () =
  print_string "Polish : analyse statique d'un mini-langage\n";
  print_string "usage: à documenter (TODO)\n"

let main () =
  match Sys.argv with
  | [|_;"--reprint";file|] -> print_polish (read_polish file)
  | [|_;"--eval";file|] -> eval_polish (read_polish file)
  | _ -> usage ()

(* lancement de ce main *)
let () = main ()
