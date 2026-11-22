(* Independent checks for graph_algorithms.rhm. Every question is matched
   against the whole sentence of its form; the vertices, the edges and the
   weights are read back from it and a graph is built from them. The answer
   is then found again by algorithms that run on that graph, never by going
   through the paths or the trees the grammar writes out:

   shortest_four,   the listing of weights is read ("AB = 3": an edge and its
   shortest_five    weight) and must be well formed: positive weights, no
                    loop, no edge twice, separated by ", " and a last "and".
                    Dijkstra's algorithm and the Bellman-Ford algorithm are
                    run from the start vertex, and every simple path between
                    the two ends is walked by a depth-first search; the three
                    must agree on the least length. shortest_four must have
                    four vertices and every edge; the edge that joins the two
                    ends must be strictly longer than the answer, and
                    direct_edge must be listed, alone, with the weight printed
                    for that edge. shortest_five must have five vertices and
                    as many edges as the sentence says, and lists no mistake.
                    For each form, every number of edges a path between the
                    ends can have (but the one edge of shortest_four) must at
                    some time be that of the one shortest path.
   spanning_four    the same listing; four vertices and every edge. Kruskal's
                    algorithm with a union-find is run twice, with ties in
                    the other order, and every choice of n - 1 edges is tried
                    and kept when a search finds it connected: the lightest
                    spanning tree found so must weigh what Kruskal found.
                    cheapest_three is the sum of the three smallest weights,
                    found by sorting. It is listed exactly when that sum is
                    not the right answer, with that sum. Ties: every choice
                    of three edges with that sum is one way of breaking the
                    ties. When the sum is less than the tree's weight, each
                    such choice must close a triangle and leave a vertex out;
                    when it is the tree's weight, one such choice is a
                    spanning tree, the slip cannot be told from right working,
                    and the mistake must not be listed, even if another
                    choice closes a triangle. All three cases must come up.
   cycle_tree       the cycle and its weights are read; the graph must be one
                    cycle on five vertices (every degree 2, connected, the
                    edges those of the printed cycle). Kruskal and the search
                    through every choice of four edges, as above.
   euler_edges      the degrees are read; there must be as many as the
                    sentence says, and five. All 1024 graphs on five vertices
                    are searched for a connected one with exactly those
                    degrees in that order; Havel-Hakimi must agree that the
                    list is graphical. The number of odd degrees must be even
                    and at least 2. The answer is found by search: the fewest
                    edges, parallel ones allowed, that make every degree even,
                    trying every multiset of pairs of vertices. It must be
                    half the number of odd vertices, by the argument as well:
                    joining the odd vertices in pairs makes every degree even,
                    and one edge fewer has too few ends. Last, the connected
                    graph found, with those edges added, must have an Euler
                    circuit: one is built by Hierholzer's algorithm and
                    checked to use every edge once and to come back. Every
                    list of degrees of a connected graph on five vertices
                    with an odd vertex must be asked.
   count_trees      the edges are read from the listing, pairs in braces,
                    which must be well formed: pairs of the printed vertices,
                    smaller one first, in order, none twice, separated by
                    ", ". Every choice of three edges is tried and counted
                    when a search finds it connected; the union-find must
                    agree on each choice, and a tree must touch all four
                    vertices. The count must be at least 2. Every graph on
                    four vertices with at least two spanning trees must be
                    asked.

   In every form with weights, each edge must take every whole number from
   its least weight to its greatest, and the edges of a form must agree on
   those two, but the edge of shortest_four that joins the two ends, which
   is kept long and must only be as heavy as the others at its heaviest.

   Every kind must come up at its price and at no other, and none may be
   rare there; the budget must be spent; a budget outside 1 to 3 must give no
   question; every answer must be one whole number; and no form may list a
   mistake but its own. Each mistake must be described as itself. *)

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

let sum = List.fold_left ( + ) 0

let memo f =
  let known = Hashtbl.create 64 in
  fun key ->
    match Hashtbl.find_opt known key with
    | Some value -> value
    | None ->
        let value = f key in
        Hashtbl.add known key value;
        value

(* ---- Reading a question ---- *)

(* The fields of a prompt: the pattern is the whole sentence, with a group
   wherever a name, a number or a listing stands. *)
let words = Str.quote
let a_vertex = "\\([A-Z]\\)"
let some_vertices = "\\([A-Z, ]+\\)"
let some_numbers = "\\([0-9, ]+\\)"
let a_number_word = "\\([a-z]+\\)"
let some_weights = "\\(\\[`.*`\\]\\)"
let some_edges = "\\([^`]*\\)"

let fields count pattern prompt =
  if Str.string_match (Str.regexp pattern) prompt 0 && Str.match_end () = String.length prompt then
    List.init count (fun n -> Str.matched_group (n + 1) prompt)
  else failwith "the wording is not the expected one"

let number_word word =
  match
    List.assoc_opt word
      [ ("one", 1); ("two", 2); ("three", 3); ("four", 4); ("five", 5); ("six", 6); ("seven", 7); ("eight", 8);
        ("nine", 9); ("ten", 10) ]
  with
  | Some n -> n
  | None -> failwith ("not a number in words: " ^ word)

(* Items written "x, y, z", with a comma and a space between them and
   nothing else. *)
let separated text =
  let items = Str.split_delim (Str.regexp_string ", ") text in
  if List.exists (fun item -> item = "" || String.contains item ' ' || String.contains item ',') items then
    failwith ("not a list separated by a comma and a space: " ^ text);
  items

(* The names of the vertices, "A, B, C, D": single letters, none twice. *)
let names text =
  let found = separated text in
  if List.exists (fun name -> String.length name <> 1) found then failwith ("a vertex that is not one letter: " ^ text);
  if List.length (List.sort_uniq compare found) <> List.length found then failwith ("a vertex named twice: " ^ text);
  found

(* The place of a vertex among the names: the graph is built on 0 .. n - 1. *)
let place found name =
  let rec at i = function
    | [] -> failwith ("not a vertex of the graph: " ^ name)
    | first :: rest -> if first = name then i else at (i + 1) rest
  in
  at 0 found

let whole_numbers text = List.map int_of_string (separated text)

(* ---- Graphs: the vertices 0 .. size - 1 and a list of weighted edges ---- *)

type graph = { size : int; edges : (int * int * int) list }

let weight (_, _, w) = w
let total edges = sum (List.map weight edges)
let ends (a, b, _) = (min a b, max a b)

(* Where each edge at a vertex leads, and at what cost. *)
let neighbours g v =
  List.filter_map (fun (a, b, w) -> if a = v then Some (b, w) else if b = v then Some (a, w) else None) g.edges

(* The ends of edges at a vertex. *)
let degree edges v =
  List.length (List.filter (fun (a, _, _) -> a = v) edges) + List.length (List.filter (fun (_, b, _) -> b = v) edges)

(* Whether these edges join all of the vertices 0 .. size - 1, by walking
   out from vertex 0. *)
let connected size edges =
  let reached = Array.make size false in
  let rec visit v =
    if not reached.(v) then begin
      reached.(v) <- true;
      List.iter (fun (a, b, _) -> if a = v then visit b else if b = v then visit a) edges
    end
  in
  visit 0;
  Array.for_all Fun.id reached

(* The vertices that some edge touches. *)
let touched edges = List.sort_uniq compare (List.concat_map (fun (a, b, _) -> [ a; b ]) edges)

(* A listing of weights, "[`AB = 3`], [`AC = 5`] and [`BC = 2`]": the items
   are separated by a comma and a space, the last one by "and". Weights are
   positive, no edge is a loop, and no two vertices are joined twice. *)
let a_weight = Str.regexp "\\[`\\([A-Z]\\)\\([A-Z]\\) = \\([0-9]+\\)`\\]"

let weights vertices text =
  let length = String.length text in
  let starts at part = at + String.length part <= length && String.sub text at (String.length part) = part in
  let rec read from found closing =
    if not (Str.string_match a_weight text from) then failwith ("not a list of weights: " ^ text);
    let next = Str.match_end () in
    let first = Str.matched_group 1 text and second = Str.matched_group 2 text in
    let cost = int_of_string (Str.matched_group 3 text) in
    let found = (place vertices first, place vertices second, cost) :: found in
    if next = length then
      if closing then List.rev found else failwith ("the last weight is not joined by 'and': " ^ text)
    else if closing then failwith ("something follows the last weight: " ^ text)
    else if starts next ", " then read (next + 2) found false
    else if starts next " and " then read (next + 5) found true
    else failwith ("weights not separated by a comma and a space: " ^ text)
  in
  let edges = read 0 [] false in
  if List.exists (fun (a, b, _) -> a = b) edges then failwith ("an edge from a vertex to itself: " ^ text);
  if List.exists (fun edge -> weight edge < 1) edges then failwith ("a weight that is not positive: " ^ text);
  if List.length (List.sort_uniq compare (List.map ends edges)) <> List.length edges then
    failwith ("two vertices joined twice: " ^ text);
  { size = List.length vertices; edges }

(* The pairs a < b of the vertices 0 .. n - 1. *)
let pairs n = List.concat (List.init n (fun a -> List.init (n - a - 1) (fun k -> (a, a + k + 1))))

(* Every two vertices are joined. *)
let complete g = List.sort compare (List.map ends g.edges) = pairs g.size

(* The weights each edge of each form was printed with, and the edges of a
   form that are not drawn like the others. *)
let weights_seen : (string * (int * int) * int, unit) Hashtbl.t = Hashtbl.create 512
let set_apart : (string * (int * int), unit) Hashtbl.t = Hashtbl.create 4
let note_weights form g = List.iter (fun edge -> Hashtbl.replace weights_seen (form, ends edge, weight edge) ()) g.edges

(* Every way of choosing k of the items. *)
let rec choose k items =
  if k = 0 then [ [] ]
  else
    match items with
    | [] -> []
    | first :: rest -> List.map (fun chosen -> first :: chosen) (choose (k - 1) rest) @ choose k rest

(* ---- Shortest paths ---- *)

let far = max_int

(* Dijkstra's algorithm: the vertex nearest to the source that is not settled
   yet is settled, and the edges out of it are relaxed. Gives the distance
   of every vertex, `far` for one that cannot be reached. *)
let dijkstra g source =
  let distance = Array.make g.size far and settled = Array.make g.size false in
  distance.(source) <- 0;
  let rec settle () =
    let nearest = ref (-1) in
    for v = 0 to g.size - 1 do
      if (not settled.(v)) && distance.(v) < far && (!nearest < 0 || distance.(v) < distance.(!nearest)) then
        nearest := v
    done;
    if !nearest >= 0 then begin
      let u = !nearest in
      settled.(u) <- true;
      List.iter (fun (v, w) -> if distance.(u) + w < distance.(v) then distance.(v) <- distance.(u) + w) (neighbours g u);
      settle ()
    end
  in
  settle ();
  distance

(* The Bellman-Ford algorithm: every edge is relaxed, both ways, once for
   each vertex but one. *)
let bellman_ford g source =
  let distance = Array.make g.size far in
  distance.(source) <- 0;
  let relax a b w = if distance.(a) < far && distance.(a) + w < distance.(b) then distance.(b) <- distance.(a) + w in
  for _ = 2 to g.size do
    List.iter (fun (a, b, w) -> relax a b w; relax b a w) g.edges
  done;
  distance

(* Every simple path from one vertex to another, by a depth-first search:
   its length and its number of edges. *)
let simple_paths g source target =
  let rec from v visited length steps =
    if v = target then [ (length, steps) ]
    else
      List.concat_map
        (fun (next, w) -> if List.mem next visited then [] else from next (next :: visited) (length + w) (steps + 1))
        (neighbours g v)
  in
  from source [ source ] 0 0

(* What the paths of each form were like: (form, "possible", s) when some
   path between the ends has s edges, (form, "won", s) when the one
   shortest path of a question had s edges. *)
let paths_seen : (string * string * int, unit) Hashtbl.t = Hashtbl.create 16

(* The least length from one vertex to another, on which the two algorithms
   and the search must agree. *)
let shortest form g source target =
  if source = target then failwith "the path is asked from a vertex to itself";
  let paths = simple_paths g source target in
  if paths = [] then failwith "the two ends are not joined by any path";
  let least = List.fold_left (fun best (length, _) -> min best length) far paths in
  let by_dijkstra = (dijkstra g source).(target) and by_bellman_ford = (bellman_ford g source).(target) in
  if by_dijkstra <> least || by_bellman_ford <> least then
    failwith
      (Printf.sprintf "Dijkstra gives %d, Bellman-Ford %d and the search through every path %d" by_dijkstra
         by_bellman_ford least);
  if (dijkstra g target).(source) <> least then failwith "the distance is not the same the other way";
  List.iter (fun (_, steps) -> Hashtbl.replace paths_seen (form, "possible", steps) ()) paths;
  (match List.filter (fun (length, _) -> length = least) paths with
  | [ (_, steps) ] -> Hashtbl.replace paths_seen (form, "won", steps) ()
  | _ -> ());
  least

(* ---- Spanning trees ---- *)

(* Kruskal's algorithm: the edges are taken from the cheapest on, each one
   kept when its ends are not joined yet, which a union-find tells. Gives
   the weight of the tree, or nothing when the graph is not connected. *)
let kruskal size sorted =
  let parent = Array.init size Fun.id in
  let rec find v =
    if parent.(v) = v then v
    else begin
      let root = find parent.(v) in
      parent.(v) <- root;
      root
    end
  in
  let kept, cost =
    List.fold_left
      (fun (kept, cost) (a, b, w) ->
        let ra = find a and rb = find b in
        if ra = rb then (kept, cost)
        else begin
          parent.(ra) <- rb;
          (kept + 1, cost + w)
        end)
      (0, 0) sorted
  in
  if kept = size - 1 then Some cost else None

let by_weight = List.stable_sort (fun a b -> compare (weight a) (weight b))

(* Every spanning tree: the choices of n - 1 edges that join all the
   vertices. *)
let spanning_trees g = List.filter (connected g.size) (choose (g.size - 1) g.edges)

(* The weight of a minimum spanning tree, on which Kruskal's algorithm, with
   ties taken in either order, and the search through every tree must agree. *)
let lightest_tree g =
  let least = List.fold_left (fun best tree -> min best (total tree)) far (spanning_trees g) in
  match (kruskal g.size (by_weight g.edges), kruskal g.size (by_weight (List.rev g.edges))) with
  | Some one, Some other ->
      if one <> other then failwith "Kruskal's algorithm depends on the order of equal weights";
      if one <> least then
        failwith (Printf.sprintf "Kruskal gives %d and the search through every spanning tree %d" one least);
      one
  | _ -> failwith "the graph is not connected"

(* How the three cheapest edges of spanning_four stood to the tree. *)
let cheapest_seen : (string, unit) Hashtbl.t = Hashtbl.create 4

(* ---- Degrees and Euler circuits ---- *)

(* Every graph on five vertices: its edges, with weight 1. *)
let graphs_on_five =
  let places = List.mapi (fun i place -> (i, place)) (pairs 5) in
  List.init 1024 (fun code ->
      (* the edge at place i is taken when bit i of the code is set *)
      List.filter (fun (i, _) -> code land (1 lsl i) <> 0) places |> List.map (fun (_, (a, b)) -> (a, b, 1)))

let degrees size edges = List.init size (degree edges)

(* A connected graph on five vertices with exactly these degrees, in this
   order, if there is one. *)
let connected_with =
  memo (fun wanted -> List.find_opt (fun edges -> connected 5 edges && degrees 5 edges = wanted) graphs_on_five)

(* Havel-Hakimi: join the vertex of largest degree to the next largest ones
   and go on with what is left. *)
let rec graphical list =
  match List.sort (fun a b -> compare b a) list with
  | [] -> true
  | largest :: rest ->
      largest >= 0
      && largest <= List.length rest
      && graphical (List.mapi (fun i d -> if i < largest then d - 1 else d) rest)

let all_even = List.for_all (fun d -> d mod 2 = 0)

(* The degrees after an edge between a and b is added. *)
let joined list (a, b) = List.mapi (fun v d -> if v = a || v = b then d + 1 else d) list

(* Some `count` edges, parallel ones allowed, that make every degree even:
   every multiset of pairs of vertices is tried, from the pair `from` on. *)
let rec evened list count from =
  if count = 0 then if all_even list then Some [] else None
  else
    let rec try_from = function
      | [] -> None
      | pair :: later as here -> (
          match evened (joined list pair) (count - 1) here with
          | Some more -> Some (pair :: more)
          | None -> try_from later)
    in
    try_from from

(* The fewest added edges that make every degree even, and such edges. *)
let fewest_added =
  memo (fun list ->
      let places = pairs (List.length list) in
      let rec search count =
        if count > 3 then failwith "more than three edges would have to be added"
        else match evened list count places with Some added -> (count, added) | None -> search (count + 1)
      in
      search 0)

(* Hierholzer's algorithm: walk along unused edges until stuck, and write
   the vertices down on the way back. Gives the vertices in the order of a
   circuit when the graph has one. *)
let hierholzer edges start =
  let edges = Array.of_list edges in
  let used = Array.make (Array.length edges) false and circuit = ref [] in
  let rec walk v =
    Array.iteri
      (fun i (a, b, _) ->
        if (not used.(i)) && (a = v || b = v) then begin
          used.(i) <- true;
          walk (if a = v then b else a)
        end)
      edges;
    circuit := v :: !circuit
  in
  walk start;
  !circuit

(* A closed walk that uses every one of these edges exactly once. *)
let is_euler_circuit edges walk =
  let rec steps = function a :: (b :: _ as rest) -> (min a b, max a b) :: steps rest | _ -> [] in
  match walk with
  | [] -> false
  | first :: _ ->
      List.nth walk (List.length walk - 1) = first
      && List.sort compare (steps walk) = List.sort compare (List.map ends edges)

(* The lists of degrees that euler_edges was asked with. *)
let degrees_asked : (int list, unit) Hashtbl.t = Hashtbl.create 512

(* ---- Graphs without weights, from a listing of edges ---- *)

(* A listing of edges, each a pair in braces behind backslashes: pairs of the printed
   vertices, the smaller one first, in order (by first vertex, then by
   second), none twice, separated by a comma and a space. *)
let an_edge = Str.regexp "\\\\{\\([0-9]+\\), \\([0-9]+\\)\\\\}"

let edge_listing vertices text =
  let length = String.length text in
  let rec read from found =
    if not (Str.string_match an_edge text from) then failwith ("not a list of edges: " ^ text);
    let next = Str.match_end () in
    let pair = (int_of_string (Str.matched_group 1 text), int_of_string (Str.matched_group 2 text)) in
    if next = length then List.rev (pair :: found)
    else if next + 2 <= length && String.sub text next 2 = ", " then read (next + 2) (pair :: found)
    else failwith ("edges not separated by a comma and a space: " ^ text)
  in
  let found = read 0 [] in
  let rec in_order = function a :: (b :: _ as rest) -> compare a b < 0 && in_order rest | _ -> true in
  if List.exists (fun (a, b) -> not (List.mem a vertices && List.mem b vertices)) found then
    failwith ("an edge to a vertex the graph does not have: " ^ text);
  if List.exists (fun (a, b) -> a >= b) found then failwith ("an edge not written smaller vertex first: " ^ text);
  if not (in_order found) then failwith ("edges out of order, or one twice: " ^ text);
  found

(* The spanning trees of a graph, counted: the choices of n - 1 edges that
   a search finds connected. The union-find must agree on each choice (it
   keeps all the edges when none of them closes a cycle), and a tree must
   touch every vertex. *)
let count_spanning_trees g =
  let chosen = choose (g.size - 1) g.edges in
  let trees = List.filter (connected g.size) chosen in
  if List.exists (fun some -> connected g.size some <> (kruskal g.size some <> None)) chosen then
    failwith "the search and the union-find disagree on what a spanning tree is";
  if List.exists (fun tree -> List.length (touched tree) <> g.size) trees then
    failwith "a tree found by the search leaves a vertex out";
  List.length trees

(* The graphs that count_trees was asked with, as their edges in a row. *)
let graphs_asked : ((int * int) list, unit) Hashtbl.t = Hashtbl.create 64

(* ---- The answer of each form, found again ---- *)

let complete_graph = "`] and an edge between every two of them, with the weights "
let path_asked = words ". Find the length of a shortest path from [`" ^ a_vertex ^ words "`] to [`" ^ a_vertex ^ words "`]."
let tree_asked = ". Find the total weight of a minimum spanning tree."

(* The right answer of a question, and the answer of each mistake that it
   must list, all found again from the prompt. *)
let expected (q : Rhema_engine.question) =
  let p = q.Rhema_engine.prompt in
  match kind q with
  | "cycle_tree" -> (
      match
        fields 3
          (words "A weighted graph is the single cycle [`" ^ some_vertices ^ words "`] and back to [`" ^ a_vertex
          ^ words "`], with the weights " ^ some_weights ^ words tree_asked)
          p
      with
      | [ round; back; listed ] ->
          let vertices = names round in
          let g = weights vertices listed in
          note_weights "cycle_tree" g;
          if g.size <> 5 then failwith "the cycle is not on five vertices";
          if place vertices back <> 0 then failwith "the cycle does not come back to where it started";
          (* one cycle: as many edges as vertices, two at each, in one piece *)
          if List.length g.edges <> g.size then failwith "a cycle has as many edges as vertices";
          if List.exists (fun d -> d <> 2) (degrees g.size g.edges) then failwith "a vertex of the cycle is not of degree 2";
          if not (connected g.size g.edges) then failwith "more than one cycle";
          (* and the cycle is the printed one: each vertex joined to the next *)
          let along = List.init g.size (fun v -> (min v ((v + 1) mod g.size), max v ((v + 1) mod g.size))) in
          if List.sort compare (List.map ends g.edges) <> List.sort compare along then
            failwith "the edges are not those of the printed cycle";
          let want = lightest_tree g in
          (* a cycle has as many spanning trees as edges: one edge is left out *)
          if List.length (spanning_trees g) <> g.size then failwith "a cycle has one spanning tree for each edge";
          (want, [])
      | _ -> failwith "three fields were expected")
  | "euler_edges" -> (
      match
        fields 2
          (words "A connected graph has " ^ a_number_word ^ words " vertices, of degrees [`" ^ some_numbers
          ^ words
              "`]. What is the smallest number of edges that must be added for it to have an Euler circuit? An added edge may join two vertices that are joined already."
          )
          p
      with
      | [ said; listed ] ->
          let list = whole_numbers listed in
          if List.length list <> number_word said then failwith "not as many degrees as vertices";
          if List.length list <> 5 then failwith "not five vertices";
          Hashtbl.replace degrees_asked list ();
          let odd = List.filter_map (fun (v, d) -> if d mod 2 = 1 then Some v else None) (List.mapi (fun v d -> (v, d)) list) in
          let odds = List.length odd in
          if odds mod 2 <> 0 then failwith "an odd number of odd degrees";
          if odds < 2 then failwith "every degree is even: the graph has an Euler circuit already";
          if not (graphical list) then failwith "no graph has these degrees (Havel-Hakimi)";
          let realised =
            match connected_with list with Some edges -> edges | None -> failwith "no connected graph has these degrees"
          in
          let fewest, added = fewest_added list in
          (* the argument: the odd vertices joined in pairs, in order, make
             every degree even; one edge fewer has fewer ends than there are
             odd vertices *)
          let rec in_pairs = function a :: b :: rest -> (a, b) :: in_pairs rest | _ -> [] in
          let paired = in_pairs odd in
          if not (all_even (List.fold_left joined list paired)) then failwith "pairing the odd vertices leaves an odd degree";
          if List.length paired <> fewest || 2 * (fewest - 1) >= odds || 2 * fewest <> odds then
            failwith (Printf.sprintf "the search adds %d edges, for %d odd vertices" fewest odds);
          (* with either set of edges the connected graph has an Euler circuit *)
          List.iter
            (fun extra ->
              let all = realised @ List.map (fun (a, b) -> (a, b, 1)) extra in
              if not (all_even (degrees 5 all) && connected 5 all) then failwith "the graph with the added edges is not Eulerian";
              if not (is_euler_circuit all (hierholzer all 0)) then failwith "no Euler circuit was found with the added edges")
            [ added; paired ];
          (* and without them it has none *)
          if is_euler_circuit realised (hierholzer realised 0) then failwith "the graph has an Euler circuit already";
          (fewest, [])
      | _ -> failwith "two fields were expected")
  | "shortest_four" -> (
      match fields 4 (words "A weighted graph has the vertices [`" ^ some_vertices ^ words complete_graph ^ some_weights ^ path_asked) p with
      | [ named; listed; first; last ] ->
          let vertices = names named in
          let g = weights vertices listed in
          if g.size <> 4 then failwith "not four vertices";
          if not (complete g) then failwith "not an edge between every two vertices";
          let source = place vertices first and target = place vertices last in
          note_weights "shortest_four" g;
          Hashtbl.replace set_apart ("shortest_four", (min source target, max source target)) ();
          let want = shortest "shortest_four" g source target in
          (* the edge that joins the two ends, as the listing prints it *)
          let direct =
            match List.filter (fun edge -> ends edge = (min source target, max source target)) g.edges with
            | [ edge ] -> weight edge
            | _ -> failwith "no one edge joins the two ends"
          in
          if direct <= want then failwith "the edge that joins the two ends is a shortest path";
          (want, [ ("direct_edge", direct) ])
      | _ -> failwith "four fields were expected")
  | "spanning_four" -> (
      match
        fields 2 (words "A weighted graph has the vertices [`" ^ some_vertices ^ words complete_graph ^ some_weights ^ words tree_asked) p
      with
      | [ named; listed ] ->
          let vertices = names named in
          let g = weights vertices listed in
          if g.size <> 4 then failwith "not four vertices";
          if not (complete g) then failwith "not an edge between every two vertices";
          note_weights "spanning_four" g;
          let want = lightest_tree g in
          (* the three cheapest edges, whatever they form *)
          let cheapest =
            match by_weight g.edges with a :: b :: c :: _ -> total [ a; b; c ] | _ -> failwith "fewer than three edges"
          in
          (* every way of breaking ties: the choices of three edges that weigh
             as little *)
          let choices = List.filter (fun three -> total three = cheapest) (choose 3 g.edges) in
          let is_tree three = connected g.size three in
          let is_triangle three = List.length (touched three) = 3 in
          if List.exists (fun three -> is_tree three = is_triangle three) choices then
            failwith "three edges that are neither a spanning tree nor a triangle";
          if cheapest > want then failwith "the three cheapest edges weigh more than a spanning tree"
          else if cheapest < want then begin
            if List.exists is_tree choices then failwith "a spanning tree lighter than the lightest";
            Hashtbl.replace cheapest_seen "a triangle, whatever the ties" ();
            (want, [ ("cheapest_three", cheapest) ])
          end
          else begin
            if not (List.exists is_tree choices) then failwith "no spanning tree among the three cheapest edges";
            Hashtbl.replace cheapest_seen
              (if List.exists is_triangle choices then "a tree or a triangle, by the ties" else "a tree, whatever the ties")
              ();
            (want, [])
          end
      | _ -> failwith "two fields were expected")
  | "shortest_five" -> (
      match
        fields 5
          (words "A weighted graph has the vertices [`" ^ some_vertices ^ words "`] and " ^ a_number_word
          ^ words " edges, with the weights " ^ some_weights ^ path_asked)
          p
      with
      | [ named; said; listed; first; last ] ->
          let vertices = names named in
          let g = weights vertices listed in
          if g.size <> 5 then failwith "not five vertices";
          if List.length g.edges <> number_word said then failwith "not as many edges as the question says";
          if not (connected g.size g.edges) then failwith "the graph is not connected";
          note_weights "shortest_five" g;
          (shortest "shortest_five" g (place vertices first) (place vertices last), [])
      | _ -> failwith "five fields were expected")
  | "count_trees" -> (
      match
        fields 2
          (words "A graph on the vertices [`" ^ some_numbers ^ words "`] has the edges [`" ^ some_edges
          ^ words "`]. How many spanning trees does it have?")
          p
      with
      | [ named; listed ] ->
          let vertices = whole_numbers named in
          if vertices <> [ 1; 2; 3; 4 ] then failwith "the vertices are not 1, 2, 3, 4";
          let found = edge_listing vertices listed in
          Hashtbl.replace graphs_asked found ();
          let g = { size = List.length vertices; edges = List.map (fun (a, b) -> (a - 1, b - 1, 1)) found } in
          let trees = count_spanning_trees g in
          if trees < 2 then failwith "fewer than two spanning trees";
          (* Kruskal's algorithm finds one of them, with its three edges *)
          if kruskal g.size g.edges <> Some (g.size - 1) then failwith "Kruskal's algorithm finds no spanning tree";
          (trees, [])
      | _ -> failwith "two fields were expected")
  | k -> failwith ("unknown kind " ^ k)

let per_budget = 20000

let () =
  let base = load_file "graph_algorithms.rhm" in
  let prices =
    [ ("cycle_tree", 1); ("euler_edges", 1); ("shortest_four", 2); ("spanning_four", 2); ("shortest_five", 3);
      ("count_trees", 3) ]
  in
  let described = [ ("direct_edge", "the edge that joins the two ends"); ("cheapest_three", "the three cheapest edges") ] in
  let seen = Hashtbl.create 16 and made = Hashtbl.create 2 in
  let times k = Option.value (Hashtbl.find_opt seen k) ~default:0 in
  (* a budget below the lowest or above the highest is refused *)
  List.iter
    (fun cost ->
      match Rhema_check.with_initial base "cost" cost with
      | Error _ -> ()
      | Ok spec -> (
          Random.init 1;
          match Rhema_engine.generate spec with
          | exception Rhema_engine.Generation_error _ -> ()
          | q -> fail (Printf.sprintf "budget %d gave a question: %s" cost q.Rhema_engine.prompt)))
    [ 0; 4; 5; 9 ];
  for cost = 1 to 3 do
    let spec = with_initial base "cost" cost in
    for seed = 0 to per_budget - 1 do
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
              | exception e -> fail (Printf.sprintf "%s: %s for %S" k (Printexc.to_string e) p)
              | want, slips ->
                  if got <> want then fail (Printf.sprintf "%s: answer %d, recomputed %d, for %S" k got want p);
                  (* a mistake that comes to the right number is not to be
                     listed: wrong working would be marked right *)
                  List.iter
                    (fun (name, slip) ->
                      if slip = want then fail (Printf.sprintf "%s: %s gives the right answer %d, for %S" k name want p))
                    slips;
                  let listed = q.Rhema_engine.mistakes in
                  let mistake_names = List.map (fun (m : Rhema_engine.mistaken) -> m.mistake) listed in
                  if mistake_names <> List.map fst slips then
                    fail
                      (Printf.sprintf "%s: the mistakes listed are [%s], not [%s], for %S" k
                         (String.concat ", " mistake_names)
                         (String.concat ", " (List.map fst slips))
                         p);
                  List.iter
                    (fun (m : Rhema_engine.mistaken) ->
                      Hashtbl.replace made m.mistake ();
                      (* each mistake is described as itself, not as the other *)
                      (match List.assoc_opt m.mistake described with
                      | Some part -> (
                          match Str.search_forward (Str.regexp_string part) m.description 0 with
                          | _ -> ()
                          | exception Not_found -> fail (Printf.sprintf "%s is described as %S" m.mistake m.description))
                      | None -> fail ("a mistake the grammar is not known to declare: " ^ m.mistake));
                      match (m.mistaken_answers, List.assoc_opt m.mistake slips) with
                      | Some [ value ], Some slip -> (
                          match whole value with
                          | Some wrong ->
                              if wrong <> slip then
                                fail (Printf.sprintf "%s: %s gives %d, recomputed %d, for %S" k m.mistake wrong slip p);
                              if wrong = got then fail (Printf.sprintf "%s: %s gives the right answer, for %S" k m.mistake p)
                          | None -> fail (Printf.sprintf "%s: %s does not give a whole number, for %S" k m.mistake p))
                      | _, None -> ()
                      | _, Some _ -> fail (Printf.sprintf "%s: %s does not give one answer, for %S" k m.mistake p))
                    listed))
    done
  done;
  List.iter (fun (k, _) -> if not (Hashtbl.mem seen k) then fail ("never generated: " ^ k)) prices;
  (* no form is rare at its price *)
  List.iter
    (fun (k, _) ->
      if 5 * times k < per_budget then fail (Printf.sprintf "%s came up %d times in %d questions" k (times k) per_budget))
    prices;
  List.iter (fun (mistake, _) -> if not (Hashtbl.mem made mistake) then fail ("never listed: " ^ mistake)) described;
  (* the shortest path is not always the one with the fewest edges: every
     number of edges a path can have was that of the one shortest path, but
     the single edge of shortest_four, which never is *)
  List.iter
    (fun form ->
      let possible = List.filter (fun steps -> Hashtbl.mem paths_seen (form, "possible", steps)) [ 1; 2; 3; 4; 5 ] in
      if List.length possible < 2 then fail (form ^ ": every path has the same number of edges");
      List.iter
        (fun steps ->
          let won = Hashtbl.mem paths_seen (form, "won", steps) in
          if form = "shortest_four" && steps = 1 then begin
            if won then fail "shortest_four: the edge that joins the two ends was the one shortest path"
          end
          else if not won then fail (Printf.sprintf "%s: a path of %d edges was never the one shortest path" form steps))
        possible)
    [ "shortest_four"; "shortest_five" ];
  (* the weights of a form are drawn alike: each edge takes every whole
     number from its least to its greatest, and all edges have the same least
     and greatest, but the edge of shortest_four that joins the two ends,
     which is kept long: it is as heavy as any at its heaviest *)
  let noted = Hashtbl.fold (fun key () all -> key :: all) weights_seen [] in
  let name (a, b) = Printf.sprintf "%c%c" (Char.chr (65 + a)) (Char.chr (65 + b)) in
  List.iter
    (fun (form, _) ->
      let edges = List.sort_uniq compare (List.filter_map (fun (f, edge, _) -> if f = form then Some edge else None) noted) in
      let span edge =
        let found = List.filter_map (fun (f, e, w) -> if f = form && e = edge then Some w else None) noted in
        let least = List.fold_left min max_int found and greatest = List.fold_left max min_int found in
        if List.length found <> greatest - least + 1 then
          fail (Printf.sprintf "%s: the edge %s takes some weights from %d to %d but not all" form (name edge) least greatest);
        if greatest = least then fail (Printf.sprintf "%s: the edge %s always weighs %d" form (name edge) least);
        (least, greatest)
      in
      let apart, alike = List.partition (fun edge -> Hashtbl.mem set_apart (form, edge)) edges in
      match List.map (fun edge -> (edge, span edge)) alike with
      | [] -> ()
      | (first, (least, greatest)) :: others ->
          List.iter
            (fun (edge, (low, high)) ->
              if low <> least || high <> greatest then
                fail
                  (Printf.sprintf "%s: the edge %s weighs %d to %d and the edge %s %d to %d" form (name first) least
                     greatest (name edge) low high))
            others;
          List.iter
            (fun edge ->
              let low, high = span edge in
              if high <> greatest || low < least then
                fail
                  (Printf.sprintf "%s: the edge %s weighs %d to %d and the edge %s %d to %d" form (name first) least
                     greatest (name edge) low high))
            apart)
    prices;
  (* the three cheapest edges close a triangle, or do not, or do by the ties *)
  List.iter
    (fun case -> if not (Hashtbl.mem cheapest_seen case) then fail ("spanning_four: the three cheapest edges were never " ^ case))
    [ "a triangle, whatever the ties"; "a tree, whatever the ties"; "a tree or a triangle, by the ties" ];
  (* every list of degrees of a connected graph with an odd vertex is asked *)
  List.iter
    (fun edges ->
      let list = degrees 5 edges in
      if connected 5 edges && (not (all_even list)) && not (Hashtbl.mem degrees_asked list) then
        fail ("euler_edges: never asked with the degrees " ^ String.concat ", " (List.map string_of_int list)))
    graphs_on_five;
  (* every graph on four vertices with at least two spanning trees is asked *)
  List.iter
    (fun chosen ->
      let g = { size = 4; edges = List.map (fun (a, b) -> (a, b, 1)) chosen } in
      let listing = List.map (fun (a, b) -> (a + 1, b + 1)) chosen in
      if count_spanning_trees g >= 2 && not (Hashtbl.mem graphs_asked listing) then
        fail
          ("count_trees: never asked with the edges "
          ^ String.concat ", " (List.map (fun (a, b) -> Printf.sprintf "{%d, %d}" a b) listing)))
    (List.concat_map (fun k -> choose k (pairs 4)) [ 0; 1; 2; 3; 4; 5; 6 ]);
  if !failures = 0 then print_endline "Rhema graph algorithms tests passed."
  else begin
    prerr_endline (Printf.sprintf "%d graph algorithms test(s) failed." !failures);
    exit 1
  end
