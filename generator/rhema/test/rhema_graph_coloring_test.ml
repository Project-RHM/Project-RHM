(* Independent checks for graph_coloring.rhm. Every question is matched
   against the whole sentence of its form, the numbers are read back from it,
   the graph it describes is built here as a list of edges, and the answer is
   found again by brute force from the definition, never by the closed
   formulas the grammar uses.

   A colouring gives each vertex one of k colours; it is proper when the two
   ends of every edge differ. The proper colourings of a graph are counted
   twice over: by a search that colours the vertices one after another and
   gives a vertex only the colours none of its neighbours coloured so far
   has, and, wherever there are at most a million and a half assignments, by
   going through every assignment of the k colours to the vertices and
   keeping the proper ones. The two counts must agree. Counts are remembered
   per graph and per question, so each is made once.

   tree                 the graph is the path (each vertex joined to the
                        next), the star (a centre joined to every leaf; the
                        prompt gives the leaves, one fewer than the vertices)
                        or, for "a tree", any tree. Every tree in which each
                        vertex after the first is joined to one earlier
                        vertex is built ((n - 1)! of them, every shape of
                        tree among them, the path and the star too); each
                        must have n vertices and n - 1 edges and be
                        connected, and all must have the same count, which
                        is what the wording "a tree with n vertices" relies
                        on. The path's and the star's own counts must be
                        that count too.
   complete             every two of the n vertices are joined. There are at
                        least as many colours as vertices, and so at least
                        one colouring.
   cycle                each vertex is joined to the next and the last to
                        the first. With 2 colours an odd cycle has no
                        colouring, and it is asked.
   bipartite            K_{2,n}: each of the 2 vertices of the small side is
                        joined to each of the n others.
   chromatic_cycle, chromatic_wheel, chromatic_complete_less, chromatic_joined
                        the graph is built, and the colourings with 1, 2, 3,
                        ... colours are counted until there is one: that
                        number of colours is the answer. The wheel is a
                        cycle and one more vertex joined to all of it. The
                        complete graph K_n with m edges removed is built
                        twice, with two different sets of m edges that no
                        two of share a vertex (the prompt writes "one of its
                        edges" for m = 1 and the number from 2 up; twice m
                        is at most n), and both must need the same number
                        of colours. The joined graph is two cycles laid as
                        for joined_at_vertex below, with exactly one vertex
                        and no edge in common. What the grammar's comment
                        says of these numbers is then checked on them: an
                        even cycle 2 and an odd one 3, a wheel one more than
                        its rim (the rim's own number found in the same
                        way), the complete graph n - m, the joined cycles 3
                        when either is odd and 2 otherwise. The four kinds
                        must come up about equally often, as the comment
                        says: the rarest at least four fifths as often as
                        the commonest.
   wheel                a cycle of n vertices and a hub joined to all of
                        them; the number of vertices the prompt states must
                        be that of the graph built. The count must be k
                        times the count of the rim with k - 1 colours, as
                        the comment says (both counted here).
   joined_at_vertex, joined_at_edge
                        the first cycle is laid on new vertices, the second
                        on one of them (or on two neighbours of the first
                        cycle) and new ones. The two cycles must have
                        exactly one vertex and no edge in common, or exactly
                        two vertices and the edge between them, and the
                        number of vertices the prompt states must be that of
                        the graph built.

   The mistakes are found again from what their descriptions say the student
   does. only_previous_vertex colours the vertices in the order they are
   named and makes each differ from the one before it only: of a complete
   graph, a cycle or the rim of a wheel that leaves a path (the hub of the
   wheel still differs from every vertex of the rim); the colourings of the
   graph with those edges alone are counted, by the same brute force.
   sides_always_differ counts, among all assignments, only the proper
   colourings in which the two vertices of the small side have different
   colours. shared_part_counted_twice multiplies the counts of the two
   cycles, each counted on its own. A mistake whose working leaves the
   answer as it is concerns no question, by the rules of the language, so a
   question lists exactly the mistakes of its form whose value found here
   differs from the right answer. That happens only where forgetting the
   closing edge does no harm: on an even cycle with 2 colours and on a wheel
   with an even rim and 3 colours; those questions are pinned, and every
   other mistake must differ from the right answer. Every listed mistake
   must be more than 1% away from the right answer, so that a marker with a
   tolerance of one part in a thousand cannot take it for right, must be
   listed on its form somewhere, and is described as itself, word for word
   as the grammar declares it.

   Every kind must come up at its price and at no other, the budget must be
   spent, the grammar's own budget must give a question of price 2, a budget
   outside 1 to 3 must give no question, and every answer must be one whole
   number, not negative. What each form is asked with is pinned as well:
   every choice the grammar offers must come up, and nothing else. So are
   the questions whose answer is 0: the odd cycles with 2 colours and the
   wheels with an odd rim and 3 colours. The weights of the forms are not
   pinned, beyond the balance of the four chromatic kinds. *)

let failures = ref 0

let fail message =
  incr failures;
  prerr_endline ("FAIL: " ^ message)

let load_file filename =
  match Rhema_load.parse_file filename with
  | Ok spec -> spec
  | Error errors ->
      List.iter (fun error -> fail (Rhema_load.string_of_failure error)) errors;
      exit 1

let with_initial spec name value =
  match Rhema_check.with_initial spec name value with Ok s -> s | Error m -> fail m; spec

let kind (q : Rhema_engine.question) =
  match Rhema_engine.attribute q.Rhema_engine.tree "kind" with Rhema_engine.Text t -> t | _ -> "?"

let whole = function
  | Rhema_engine.Num n when Rhema_number.is_integer n -> Some n.Rhema_number.numerator
  | _ -> None

(* ---- Reading a question ---- *)

(* The pattern of a prompt is the whole sentence, with a group wherever a
   number stands. A number is written without a sign and without a leading
   zero; no form prints a zero. *)
let words = Str.quote
let a_number = "\\([1-9][0-9]*\\)"

let numbers_of count pattern text =
  if Str.string_match (Str.regexp pattern) text 0 && Str.match_end () = String.length text then
    List.init count (fun n -> int_of_string (Str.matched_group (n + 1) text))
  else failwith "the wording is not the expected one"

let range first last = List.init (max 0 (last - first + 1)) (fun i -> first + i)
let size = List.length
let numbers values = String.concat " " (List.map string_of_int values)

(* ---- Graphs ---- *)

(* A graph on the vertices 0, ..., vertices - 1, each edge written once,
   smaller end first. Every graph here is connected, so its vertices are the
   ends of its edges. *)
type graph = { vertices : int; edges : (int * int) list }

let graph_of edges =
  let edges =
    List.sort_uniq compare
      (List.map (fun (u, v) -> if u = v then failwith "an edge from a vertex to itself" else (min u v, max u v)) edges)
  in
  let ends = List.sort_uniq compare (List.concat_map (fun (u, v) -> [ u; v ]) edges) in
  if ends <> range 0 (size ends - 1) then failwith "the vertices are not numbered from 0 without a gap";
  { vertices = size ends; edges }

(* The edges that join each vertex of a list to the next, and those that
   close the list into a cycle as well. *)
let rec path_on = function a :: (b :: _ as rest) -> (a, b) :: path_on rest | _ -> []

let cycle_on = function
  | first :: _ :: _ :: _ as list -> (List.nth list (size list - 1), first) :: path_on list
  | _ -> failwith "a cycle has three vertices or more"

let all_pairs left right = List.concat_map (fun u -> List.map (fun v -> (u, v)) right) left
let path n = graph_of (path_on (range 0 (n - 1)))
let star leaves = graph_of (all_pairs [ 0 ] (range 1 leaves))
let cycle n = graph_of (cycle_on (range 0 (n - 1)))
let complete n = graph_of (List.filter (fun (u, v) -> u < v) (all_pairs (range 0 (n - 1)) (range 0 (n - 1))))

(* K_{m,n}: the vertices 0, ..., m - 1 on one side, the n others on the
   other. *)
let bipartite m n = graph_of (all_pairs (range 0 (m - 1)) (range m (m + n - 1)))

(* The wheel: the rim 0, ..., n - 1 and the hub n. *)
let spokes n = all_pairs [ n ] (range 0 (n - 1))
let wheel n = graph_of (cycle_on (range 0 (n - 1)) @ spokes n)

(* Every tree in which each vertex after the first is joined to one earlier
   vertex. *)
let trees n =
  let rec go v =
    if v >= n then [ [] ]
    else List.concat_map (fun rest -> List.map (fun parent -> (parent, v) :: rest) (range 0 (v - 1))) (go (v + 1))
  in
  List.map graph_of (go 1)

(* Whether every vertex is reached from vertex 0 along the edges. *)
let is_connected g =
  let reached = Array.make g.vertices false in
  let rec visit v =
    if not reached.(v) then begin
      reached.(v) <- true;
      List.iter (fun (a, b) -> if a = v then visit b else if b = v then visit a) g.edges
    end
  in
  visit 0;
  Array.for_all (fun r -> r) reached

let is_tree g = size g.edges = g.vertices - 1 && is_connected g

(* The graph a student is left with who forgets some of the edges: the same
   vertices, and edges of the graph only. *)
let with_edges_only g edges =
  let reduced = graph_of edges in
  if reduced.vertices <> g.vertices then failwith "the graph with fewer edges has other vertices";
  if not (List.for_all (fun e -> List.mem e g.edges) reduced.edges) then failwith "an edge that the graph does not have";
  if size reduced.edges >= size g.edges then failwith "no edge is forgotten";
  reduced

(* ---- Counting colourings by brute force ---- *)

(* Every assignment of k colours to the vertices is gone through; the proper
   ones that `keep` holds of are counted. *)
let by_every_assignment g k keep =
  let n = g.vertices in
  let colour = Array.make n 0 in
  (* the next assignment, as a number written with n digits in base k *)
  let rec next i =
    if i = n then false
    else if colour.(i) + 1 < k then begin
      colour.(i) <- colour.(i) + 1;
      true
    end
    else begin
      colour.(i) <- 0;
      next (i + 1)
    end
  in
  let count = ref 0 and more = ref (k >= 1) in
  while !more do
    if List.for_all (fun (u, v) -> colour.(u) <> colour.(v)) g.edges && keep colour then incr count;
    more := next 0
  done;
  !count

(* The vertices are coloured one after another; a vertex takes each colour
   that none of its neighbours coloured before it has. *)
let by_search g k =
  let n = g.vertices in
  let earlier = Array.make n [] in
  List.iter (fun (u, v) -> earlier.(v) <- u :: earlier.(v)) g.edges;
  let colour = Array.make n (-1) in
  let rec go v =
    if v = n then 1
    else begin
      let total = ref 0 in
      for c = 0 to k - 1 do
        if List.for_all (fun u -> colour.(u) <> c) earlier.(v) then begin
          colour.(v) <- c;
          total := !total + go (v + 1)
        end
      done;
      !total
    end
  in
  go 0

let few_assignments g k = float_of_int k ** float_of_int g.vertices <= 1.5e6

(* The number of proper colourings of a graph with k colours, remembered. *)
let counted : (graph * int, int) Hashtbl.t = Hashtbl.create 4096

let colourings g k =
  match Hashtbl.find_opt counted (g, k) with
  | Some count -> count
  | None ->
      let count = by_search g k in
      if few_assignments g k && by_every_assignment g k (fun _ -> true) <> count then
        failwith "the two counts of the colourings disagree";
      Hashtbl.replace counted (g, k) count;
      count

(* The least number of colours with which there is a colouring. *)
let chromatic_number g =
  let rec go k =
    if k > g.vertices then failwith "no colouring with as many colours as vertices"
    else if colourings g k > 0 then k
    else go (k + 1)
  in
  go 1

(* ---- The answer of each form, found again ---- *)

let proper =
  " A colouring gives every vertex one of the colours so that the two ends of every edge have different colours; the \
   vertices are told apart, and not every colour has to be used."

(* "In how many ways can the vertices of ... be coloured with k colours?",
   and "What is the least number of colours ...?" *)
let how_many graph_words =
  words "In how many ways can the vertices of " ^ graph_words ^ words " be coloured with [`" ^ a_number
  ^ words ("`] colours?" ^ proper)

let how_few graph_words =
  words "What is the least number of colours with which the vertices of " ^ graph_words
  ^ words " can be coloured so that the two ends of every edge have different colours?"

(* What a question was asked with, its right answer, and the answer of each
   mistake its form is open to, with whether that mistake may come to the
   right answer. *)
type found = { what : string; want : int; slips : (string * int * bool) list }

let common list other = List.filter (fun x -> List.mem x other) list

(* Two cycles with a and b vertices that share one vertex, or two vertices
   and the edge between them: the first on 0, ..., a - 1, the second on its
   first vertex, or its first two, and new vertices. *)
let joined a b shared =
  let first = range 0 (a - 1) in
  let second = range 0 (shared - 1) @ range a (a + b - shared - 1) in
  if size first <> a || size second <> b then failwith "the cycles built do not have the stated lengths";
  let ordered (u, v) = (min u v, max u v) in
  let first_edges = List.map ordered (cycle_on first) and second_edges = List.map ordered (cycle_on second) in
  if size (common first second) <> shared then failwith "the cycles do not share the vertices they should";
  if size (common first_edges second_edges) <> shared - 1 then failwith "the cycles do not share the edges they should";
  let g = graph_of (first_edges @ second_edges) in
  if size g.edges <> a + b - (shared - 1) then failwith "the graph built does not have the edges of both cycles";
  g

(* The complete graph on n vertices less the given edges, which must be
   edges of it no two of which share a vertex. *)
let complete_less n removed =
  let all = (complete n).edges in
  let ends = List.concat_map (fun (u, v) -> [ u; v ]) removed in
  if not (List.for_all (fun e -> List.mem e all) removed) then failwith "an edge removed that the complete graph does not have";
  if size (List.sort_uniq compare ends) <> 2 * size removed then failwith "two of the edges removed share a vertex";
  let g = graph_of (List.filter (fun e -> not (List.mem e removed)) all) in
  if g.vertices <> n || size g.edges <> size all - size removed then failwith "not the complete graph less the edges";
  g

let find_again k p =
  match k with
  | "tree" ->
      (* the three descriptions; the star is given by its leaves *)
      let shapes =
        [ ("path", words "a path with [`" ^ a_number ^ words "`] vertices", 0);
          ("star", words "a star with one centre and [`" ^ a_number ^ words "`] leaves", 1);
          ("tree", words "a tree with [`" ^ a_number ^ words "`] vertices", 0) ]
      in
      let rec read = function
        | [] -> failwith "the wording is not the expected one"
        | (shape, pattern, more) :: rest -> (
            match numbers_of 2 (how_many pattern) p with
            | [ n; colours ] -> (shape, n, n + more, colours)
            | _ -> failwith "two numbers were expected"
            | exception Failure _ -> read rest)
      in
      let shape, printed, n, colours = read shapes in
      let all = trees n in
      if not (List.mem (path n) all && List.mem (star (n - 1)) all) then
        failwith "the path and the star are not among the trees built";
      let described = match shape with "path" -> [ path n ] | "star" -> [ star printed ] | _ -> all in
      List.iter (fun g -> if not (is_tree g && g.vertices = n) then failwith "not a tree with n vertices") (described @ all);
      let count = colourings (List.hd described) colours in
      if List.exists (fun g -> colourings g colours <> count) all then
        failwith "the trees with n vertices do not all have the same count";
      { what = shape ^ " " ^ numbers [ n; colours ]; want = count; slips = [] }
  | "complete" -> (
      match numbers_of 2 (how_many (words "the complete graph [`K_{" ^ a_number ^ words "}`]")) p with
      | [ n; colours ] ->
          if colours < n then failwith "fewer colours than vertices";
          let g = complete n in
          let count = colourings g colours in
          if count < 1 then failwith "no colouring, with as many colours as vertices";
          let as_path = with_edges_only g (path_on (range 0 (n - 1))) in
          { what = numbers [ n; colours ]; want = count; slips = [ ("only_previous_vertex", colourings as_path colours, false) ] }
      | _ -> failwith "two numbers were expected")
  | "cycle" -> (
      match numbers_of 2 (how_many (words "a cycle with [`" ^ a_number ^ words "`] vertices")) p with
      | [ n; colours ] ->
          let g = cycle n in
          let as_path = with_edges_only g (path_on (range 0 (n - 1))) in
          { what = numbers [ n; colours ];
            want = colourings g colours;
            slips = [ ("only_previous_vertex", colourings as_path colours, colours = 2) ] }
      | _ -> failwith "two numbers were expected")
  | "bipartite" -> (
      match numbers_of 2 (how_many (words "the complete bipartite graph [`K_{2," ^ a_number ^ words "}`]")) p with
      | [ n; colours ] ->
          let g = bipartite 2 n in
          if not (few_assignments g colours) then failwith "too many assignments to go through";
          (* the two vertices of the small side are 0 and 1 *)
          let differing = by_every_assignment g colours (fun colour -> colour.(0) <> colour.(1)) in
          { what = numbers [ n; colours ]; want = colourings g colours; slips = [ ("sides_always_differ", differing, false) ] }
      | _ -> failwith "two numbers were expected")
  | "chromatic_cycle" -> (
      match numbers_of 1 (how_few (words "a cycle with [`" ^ a_number ^ words "`] vertices")) p with
      | [ n ] ->
          let least = chromatic_number (cycle n) in
          if least <> (if n mod 2 = 0 then 2 else 3) then failwith "not 2 for an even cycle and 3 for an odd one";
          { what = numbers [ n ]; want = least; slips = [] }
      | _ -> failwith "a number was expected")
  | "chromatic_wheel" -> (
      match
        numbers_of 1
          (how_few (words "a wheel, a cycle with [`" ^ a_number ^ words "`] vertices and one more vertex joined to all of them,"))
          p
      with
      | [ n ] ->
          let least = chromatic_number (wheel n) in
          if least <> chromatic_number (cycle n) + 1 then failwith "the wheel does not need one colour more than its rim";
          { what = numbers [ n ]; want = least; slips = [] }
      | _ -> failwith "a number was expected")
  | "chromatic_complete_less" -> (
      (* "one of its edges" for one edge; the number from 2 up *)
      let graph_words = words "the complete graph [`K_{" ^ a_number ^ words "}`] with " in
      let n, m =
        match numbers_of 1 (how_few (graph_words ^ words "one of its edges removed")) p with
        | [ n ] -> (n, 1)
        | _ -> failwith "a number was expected"
        | exception Failure _ -> (
            match
              numbers_of 2
                (how_few (graph_words ^ words "[`" ^ a_number ^ words "`] of its edges removed, no two of which share a vertex,"))
                p
            with
            | [ n; m ] -> if m < 2 then failwith "one edge, written as a number" else (n, m)
            | _ -> failwith "two numbers were expected")
      in
      if 2 * m > n then failwith "more edges removed than can be apart";
      (* two ways to take m edges apart: 0-1, 2-3, ..., and the first vertex
         with the last, the second with the last but one, ... *)
      let side_by_side = List.map (fun i -> (2 * i, (2 * i) + 1)) (range 0 (m - 1)) in
      let across = List.map (fun i -> (i, n - 1 - i)) (range 0 (m - 1)) in
      let least = chromatic_number (complete_less n side_by_side) in
      if chromatic_number (complete_less n across) <> least then failwith "the number depends on which edges are removed";
      if least <> n - m then failwith "not one colour fewer for each edge removed";
      { what = numbers [ n; m ]; want = least; slips = [] })
  | "chromatic_joined" -> (
      match
        numbers_of 2
          (how_few
             (words "a graph made of a cycle with [`" ^ a_number ^ words "`] vertices and a cycle with [`" ^ a_number
            ^ words "`] vertices that have exactly one vertex in common"))
          p
      with
      | [ a; b ] ->
          let least = chromatic_number (joined a b 1) in
          if least <> (if a mod 2 = 1 || b mod 2 = 1 then 3 else 2) then
            failwith "not 3 when either cycle is odd and 2 otherwise";
          { what = numbers [ a; b ]; want = least; slips = [] }
      | _ -> failwith "two numbers were expected")
  | "wheel" -> (
      match
        numbers_of 3
          (words "A wheel is a cycle with [`" ^ a_number
          ^ words "`] vertices and one more vertex, the hub, joined to all of them. In how many ways can its [`"
          ^ a_number ^ words "`] vertices be coloured with [`" ^ a_number
          ^ words ("`] colours?" ^ proper))
          p
      with
      | [ n; stated; colours ] ->
          let g = wheel n in
          if stated <> g.vertices then failwith "the number of vertices stated is not that of the wheel";
          let count = colourings g colours in
          if count <> colours * colourings (cycle n) (colours - 1) then
            failwith "not the hub's colours times the rim's count with the others";
          (* the rim as a path; the hub still joined to all of it *)
          let rim_as_path = with_edges_only g (path_on (range 0 (n - 1)) @ spokes n) in
          { what = numbers [ n; colours ];
            want = count;
            slips = [ ("only_previous_vertex", colourings rim_as_path colours, colours = 3) ] }
      | _ -> failwith "three numbers were expected")
  | "joined_at_vertex" | "joined_at_edge" -> (
      let shared = if k = "joined_at_vertex" then 1 else 2 in
      let in_common = if shared = 1 then "one vertex in common" else "one edge and its two ends in common" in
      match
        numbers_of 4
          (words "A graph is made of a cycle with [`" ^ a_number ^ words "`] vertices and a cycle with [`" ^ a_number
          ^ words ("`] vertices that have exactly " ^ in_common ^ ", so that it has [`")
          ^ a_number ^ words "`] vertices. In how many ways can its vertices be coloured with [`" ^ a_number
          ^ words ("`] colours?" ^ proper))
          p
      with
      | [ a; b; stated; colours ] ->
          let g = joined a b shared in
          if stated <> g.vertices then failwith "the number of vertices stated is not that of the graph";
          { what = numbers [ a; b; colours ];
            want = colourings g colours;
            slips = [ ("shared_part_counted_twice", colourings (cycle a) colours * colourings (cycle b) colours, false) ] }
      | _ -> failwith "four numbers were expected")
  | k -> failwith ("unknown kind " ^ k)

(* Each question is worked once. *)
let worked : (string * string, (found, string) result) Hashtbl.t = Hashtbl.create 1024

let expected (q : Rhema_engine.question) =
  let key = (kind q, q.Rhema_engine.prompt) in
  match Hashtbl.find_opt worked key with
  | Some found -> found
  | None ->
      let found = match find_again (fst key) (snd key) with found -> Ok found | exception e -> Error (Printexc.to_string e) in
      Hashtbl.replace worked key found;
      found

(* ---- What each form was asked with ---- *)

let asked : (string * string, unit) Hashtbl.t = Hashtbl.create 1024
let note label what = Hashtbl.replace asked (label, what) ()

(* Every choice the grammar offers, form by form; then the questions that
   have no colouring, and those in which the mistake does no harm. *)
let offered =
  let pairs firsts seconds = List.concat_map (fun a -> List.map (fun b -> numbers [ a; b ]) (seconds a)) firsts in
  let joined =
    List.concat_map (fun a -> List.concat_map (fun b -> List.map (fun k -> numbers [ a; b; k ]) [ 3; 4 ]) (range 3 5)) (range 3 5)
  in
  let singles first last = List.map string_of_int (range first last) in
  let trees = pairs (range 3 6) (fun _ -> range 2 5) in
  [ ("tree", List.concat_map (fun shape -> List.map (fun rest -> shape ^ " " ^ rest) trees) [ "path"; "star"; "tree" ]);
    (* 3 to 5 vertices, and as many colours or one or two more *)
    ("complete", pairs (range 3 5) (fun n -> range n (n + 2)));
    ("cycle", pairs (range 3 7) (fun _ -> range 2 5));
    ("bipartite", pairs (range 2 5) (fun _ -> range 3 5));
    ("chromatic_cycle", singles 3 9);
    ("chromatic_wheel", singles 3 9);
    (* 4 to 8 vertices, and as many edges removed as can be apart *)
    ("chromatic_complete_less", pairs (range 4 8) (fun n -> range 1 (n / 2)));
    ("chromatic_joined", pairs (range 3 8) (fun _ -> range 3 8));
    ("wheel", pairs (range 3 6) (fun _ -> range 3 5));
    ("joined_at_vertex", joined);
    ("joined_at_edge", joined);
    ("cycle: no colouring", [ "3 2"; "5 2"; "7 2" ]);
    ("wheel: no colouring", [ "3 3"; "5 3" ]);
    ("cycle: the mistake does no harm", [ "4 2"; "6 2" ]);
    ("wheel: the mistake does no harm", [ "4 3"; "6 3" ]) ]

let questions_at cost = if cost = 2 then 12000 else 5000

let () =
  let base = load_file "graph_coloring.rhm" in
  let prices =
    [ ("tree", 1); ("complete", 1); ("cycle", 2); ("bipartite", 2); ("chromatic_cycle", 2); ("chromatic_wheel", 2);
      ("chromatic_complete_less", 2); ("chromatic_joined", 2); ("wheel", 3); ("joined_at_vertex", 3); ("joined_at_edge", 3) ]
  in
  (* the description of each mistake, word for word *)
  let described =
    [ ("only_previous_vertex", "makes each vertex differ from the one before it only, so an edge that closes a cycle is forgotten");
      ("sides_always_differ", "takes the two vertices on the small side of the bipartite graph to have different colours always");
      ( "shared_part_counted_twice",
        "multiplies the counts of the two cycles and does not divide by the ways to colour what they share" ) ]
  in
  let seen = Hashtbl.create 16 and made = Hashtbl.create 16 in
  let times k = Option.value (Hashtbl.find_opt seen k) ~default:0 in
  (* a budget below the lowest or above the highest is refused *)
  List.iter
    (fun cost ->
      match Rhema_check.with_initial base "cost" cost with
      | Error _ -> ()
      | Ok spec ->
          for seed = 0 to 19 do
            Random.init seed;
            match Rhema_engine.generate spec with
            | exception Rhema_engine.Generation_error _ -> ()
            | q -> fail (Printf.sprintf "budget %d gave a question: %s" cost q.Rhema_engine.prompt)
          done)
    [ -1; 0; 4; 5; 6; 9 ];
  (* the grammar as it is written, with the budget it sets itself, gives a
     question of price 2 *)
  for seed = 0 to 19 do
    Random.init seed;
    match Rhema_engine.generate base with
    | exception Rhema_engine.Generation_error m -> fail (Printf.sprintf "the grammar's own budget, seed %d: %s" seed m)
    | q ->
        if List.assoc_opt (kind q) prices <> Some 2 || Rhema_engine.consumption q.Rhema_engine.tree "cost" <> 2 then
          fail (Printf.sprintf "the grammar's own budget gave %s, not a question of price 2" (kind q))
  done;
  for cost = 1 to 3 do
    let spec = with_initial base "cost" cost in
    for seed = 0 to questions_at cost - 1 do
      Random.init (seed + (100000 * cost));
      match Rhema_engine.generate spec with
      | exception Rhema_engine.Generation_error m -> fail (Printf.sprintf "cost %d seed %d: %s" cost seed m)
      | q -> (
          let k = kind q and p = q.Rhema_engine.prompt in
          Hashtbl.replace seen k (times k + 1);
          if List.assoc_opt k prices <> Some cost then fail (Printf.sprintf "%s at cost %d" k cost);
          if Rhema_engine.consumption q.Rhema_engine.tree "cost" <> cost then fail (k ^ " did not spend its budget");
          match (whole q.Rhema_engine.answer, q.Rhema_engine.answers) with
          | None, _ | _, ([] | _ :: _ :: _) ->
              fail (Printf.sprintf "%s: one whole number was expected as the answer of %S" k p)
          | Some got, [ _ ] -> (
              match expected q with
              | Error message -> fail (Printf.sprintf "%s: %s for %S" k message p)
              | Ok { what; want; slips } ->
                  note k what;
                  if got <> want then fail (Printf.sprintf "%s: answer %d, recomputed %d, for %S" k got want p);
                  if want < 0 then fail (Printf.sprintf "%s: a negative count for %S" k p);
                  if want = 0 then note (k ^ ": no colouring") what;
                  (* a mistake that must change the answer and does not *)
                  List.iter
                    (fun (name, slip, may_coincide) ->
                      if slip = want then
                        if may_coincide then note (k ^ ": the mistake does no harm") what
                        else fail (Printf.sprintf "%s: %s gives the right answer %d, for %S" k name want p))
                    slips;
                  (* a mistake whose working leaves the answer as it is
                     concerns no question *)
                  let slips = List.filter_map (fun (name, slip, _) -> if slip = want then None else Some (name, slip)) slips in
                  let listed = q.Rhema_engine.mistakes in
                  let names = List.map (fun (m : Rhema_engine.mistaken) -> m.mistake) listed in
                  if names <> List.map fst slips then
                    fail
                      (Printf.sprintf "%s: the mistakes listed are [%s], not [%s], for %S" k (String.concat ", " names)
                         (String.concat ", " (List.map fst slips))
                         p);
                  List.iter
                    (fun (m : Rhema_engine.mistaken) ->
                      Hashtbl.replace made (m.mistake, k) ();
                      (* each mistake is described as itself, not as another *)
                      (match List.assoc_opt m.mistake described with
                      | Some words ->
                          if m.description <> words then
                            fail (Printf.sprintf "%s is described as %S" m.mistake m.description)
                      | None -> fail ("an unknown mistake is listed: " ^ m.mistake));
                      match (m.mistaken_answers, List.assoc_opt m.mistake slips) with
                      | Some [ value ], Some slip -> (
                          match whole value with
                          | Some wrong ->
                              if wrong <> slip then
                                fail (Printf.sprintf "%s: %s gives %d, recomputed %d, for %S" k m.mistake wrong slip p);
                              (* nor may a marker with a tolerance of one part
                                 in a thousand take it for the right answer *)
                              if not (abs got < 100 * abs (wrong - got)) then
                                fail (Printf.sprintf "%s: %s gives %d, within 1%% of the answer %d, for %S" k m.mistake wrong got p)
                          | None -> fail (Printf.sprintf "%s: %s does not give a whole number, for %S" k m.mistake p))
                      | _, None -> ()
                      | _, Some _ -> fail (Printf.sprintf "%s: %s does not give one answer, for %S" k m.mistake p))
                    listed))
    done
  done;
  List.iter (fun (k, _) -> if not (Hashtbl.mem seen k) then fail ("never generated: " ^ k)) prices;
  Hashtbl.iter (fun k _ -> if not (List.mem_assoc k prices) then fail ("a kind the header does not list: " ^ k)) seen;
  (* the four chromatic kinds are about equally likely *)
  let chromatic = List.map times [ "chromatic_cycle"; "chromatic_wheel"; "chromatic_complete_less"; "chromatic_joined" ] in
  let rarest = List.fold_left min max_int chromatic and commonest = List.fold_left max 0 chromatic in
  if 5 * rarest < 4 * commonest then
    fail (Printf.sprintf "the chromatic kinds came up %s times: not equally likely" (numbers chromatic));
  List.iter
    (fun (mistake, k) ->
      if not (Hashtbl.mem made (mistake, k)) then fail (Printf.sprintf "%s never listed on %s" mistake k))
    [ ("only_previous_vertex", "complete"); ("only_previous_vertex", "cycle"); ("sides_always_differ", "bipartite");
      ("only_previous_vertex", "wheel"); ("shared_part_counted_twice", "joined_at_vertex");
      ("shared_part_counted_twice", "joined_at_edge") ];
  (* every choice the grammar offers came up, and nothing else; so for the
     questions without a colouring and those the mistake does no harm in *)
  List.iter
    (fun (label, choices) ->
      List.iter
        (fun what -> if not (Hashtbl.mem asked (label, what)) then fail (label ^ ": never asked with " ^ what))
        choices)
    offered;
  Hashtbl.iter
    (fun (label, what) () ->
      match List.assoc_opt label offered with
      | None -> fail (Printf.sprintf "%s, which is not expected of any question: asked with %s" label what)
      | Some choices -> if not (List.mem what choices) then fail (label ^ ": asked with " ^ what))
    asked;
  if !failures = 0 then print_endline "Rhema graph_coloring tests passed."
  else begin
    prerr_endline (Printf.sprintf "%d graph_coloring test(s) failed." !failures);
    exit 1
  end
