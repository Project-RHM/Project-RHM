(* Independent checks for graph_theory.rhm. The numbers are read back from
   the printed question and the answer is found again without the formula
   the grammar uses, by building graphs as lists of edges and counting.

   handshake           every graph on five vertices (all 1024 of them) is
                       searched for those with the printed degrees; there
                       must be one, they must agree on the number of edges,
                       and that number is the answer. The degrees must also
                       pass the Havel-Hakimi test and none may be 0.
   missing_degree      each fifth degree from 0 to 4 is tried against the
                       same 1024 graphs: exactly one may give a graph with
                       the printed number of edges, and it is the answer.
                       The completed list must add up to twice the edges,
                       pass Havel-Hakimi and have no 0.
   complete            the pairs of vertices are listed and counted.
   complete_bipartite  the pairs with one vertex on each side are listed
                       and counted; the smaller side is written first.
   forest              two forests of paths with that many vertices and
                       components are built, one lopsided and one even, and
                       their edges counted; both must have the printed
                       number of components.
   tree_leaves         a tree is built: the vertices of degree 4, 3 and 2
                       on a path, then leaves hung on each until it has its
                       degree. The leaves hung are the answer. The result
                       must be a tree with the printed numbers of vertices
                       of each degree, and the answer must be the only
                       number of leaves for which the degrees add up to
                       twice the edges of a tree.
   walks_two,          the matrix is read from the LaTeX and must be
   walks_three         symmetric, of 0 and 1, with a zero diagonal, at
                       least four edges, no isolated vertex, and connected.
                       The walks are counted by going through every
                       sequence of vertices of the right length. The length
                       printed must be the one the form is named after, and
                       the answer at least 1.
   planar_faces        the graph must be one the header promises (degree 3
                       on an even number of vertices from 6, or degree 4 on
                       6, 8, 10 or 12). The prism or antiprism of that size
                       is built and must be simple, connected and regular
                       of the printed degree; its edges are counted, they
                       must not exceed 3V - 6, the faces follow from
                       V - E + F = 2 and must be the faces of the solid.

   Every answer must be a whole number. *)

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

let answer (q : Rhema_engine.question) =
  match q.Rhema_engine.answer with
  | Rhema_engine.Num n when Rhema_number.is_integer n -> n.Rhema_number.numerator
  | other -> fail ("not a whole number: " ^ Rhema_engine.describe_value other); min_int

let group re text n =
  ignore (Str.search_forward (Str.regexp re) text 0);
  Str.matched_group n text

let whole re text n = int_of_string (group re text n)

(* A list of whole numbers written "2, 3, 1, 2, 2". *)
let numbers text = String.split_on_char ',' text |> List.map (fun s -> int_of_string (String.trim s))

let sum = List.fold_left ( + ) 0

(* ---- Graphs: the vertices 0 .. size - 1 and a list of edges ---- *)

type graph = { size : int; edges : (int * int) list }

let degree g v = List.length (List.filter (fun (a, b) -> a = v || b = v) g.edges)

let degrees g = List.init g.size (degree g)

(* No loop, and no two vertices joined twice. *)
let simple g =
  List.for_all (fun (a, b) -> a <> b && a >= 0 && b >= 0 && a < g.size && b < g.size) g.edges
  && List.length (List.sort_uniq compare (List.map (fun (a, b) -> (min a b, max a b)) g.edges))
     = List.length g.edges

(* The connected components, by walking out from each vertex not reached yet. *)
let components g =
  let reached = Array.make g.size false in
  let rec visit v =
    if not reached.(v) then begin
      reached.(v) <- true;
      List.iter (fun (a, b) -> if a = v then visit b else if b = v then visit a) g.edges
    end
  in
  let count = ref 0 in
  for v = 0 to g.size - 1 do
    if not reached.(v) then begin
      incr count;
      visit v
    end
  done;
  !count

(* The pairs a < b of the vertices 0 .. n - 1. *)
let pairs n = List.concat (List.init n (fun a -> List.init (n - a - 1) (fun k -> (a, a + k + 1))))

(* Every graph on five vertices, as its degrees and its number of edges. *)
let graphs_on_five =
  let places = List.mapi (fun i place -> (i, place)) (pairs 5) in
  List.init 1024 (fun code ->
      (* the edge at place i is taken when bit i of the code is set *)
      let edges = List.filter (fun (i, _) -> code land (1 lsl i) <> 0) places |> List.map snd in
      let g = { size = 5; edges } in
      (degrees g, List.length g.edges))

(* The numbers of edges of the graphs on five vertices with these degrees. *)
let edge_counts wanted =
  List.filter (fun (found, _) -> found = wanted) graphs_on_five |> List.map snd |> List.sort_uniq compare

(* Havel-Hakimi: join the vertex of largest degree to the next largest ones
   and go on with what is left. *)
let rec graphical list =
  match List.sort (fun a b -> compare b a) list with
  | [] -> true
  | largest :: rest ->
      largest >= 0
      && largest <= List.length rest
      && graphical (List.mapi (fun i d -> if i < largest then d - 1 else d) rest)

(* What the header promises of a list of degrees. *)
let check_five_degrees p list =
  if List.length list <> 5 then fail ("not five degrees: " ^ p);
  if List.exists (fun d -> d < 1) list then fail ("a vertex of degree 0: " ^ p);
  if not (graphical list) then fail ("no graph has these degrees (Havel-Hakimi): " ^ p);
  if graphical list <> (edge_counts list <> []) then fail ("Havel-Hakimi and the search disagree: " ^ p)

(* Disjoint paths with these numbers of vertices. *)
let paths sizes =
  let size, edges =
    List.fold_left
      (fun (first, edges) vertices ->
        (first + vertices, edges @ List.init (vertices - 1) (fun i -> (first + i, first + i + 1))))
      (0, []) sizes
  in
  { size; edges }

(* The vertices with these degrees, all at least 2, put on a path, and
   leaves hung on each of them until it has its degree. Returns the graph
   and the number of leaves. *)
let caterpillar inner =
  let k = List.length inner in
  let spine = List.init (k - 1) (fun i -> (i, i + 1)) in
  let next = ref k and hung = ref [] in
  List.iteri
    (fun i wanted ->
      let on_spine = (if i > 0 then 1 else 0) + if i < k - 1 then 1 else 0 in
      for _ = 1 to wanted - on_spine do
        hung := (i, !next) :: !hung;
        incr next
      done)
    inner;
  ({ size = !next; edges = spine @ List.rev !hung }, !next - k)

(* Two rings of n vertices, each vertex joined to the one facing it. *)
let prism n =
  let ring first = List.init n (fun i -> (first + i, first + ((i + 1) mod n))) in
  { size = 2 * n; edges = ring 0 @ ring n @ List.init n (fun i -> (i, n + i)) }

(* Two rings of n vertices, each vertex joined to the two facing it. *)
let antiprism n =
  let ring first = List.init n (fun i -> (first + i, first + ((i + 1) mod n))) in
  { size = 2 * n;
    edges = ring 0 @ ring n @ List.init n (fun i -> (i, n + i)) @ List.init n (fun i -> (i, n + ((i + 1) mod n))) }

(* ---- Adjacency matrices ---- *)

(* \begin{pmatrix} 0 & 1 & 1 & 0 \\ 1 & 0 & ... \end{pmatrix} as rows of numbers. *)
let matrix p =
  let body = group "\\\\begin{pmatrix}\\(.*\\)\\\\end{pmatrix}" p 1 in
  Str.split (Str.regexp_string "\\\\") body
  |> List.map (fun row -> String.split_on_char '&' row |> List.map (fun s -> int_of_string (String.trim s)))
  |> List.map Array.of_list |> Array.of_list

let check_matrix p m =
  if Array.length m <> 4 || Array.exists (fun row -> Array.length row <> 4) m then fail ("not 4 by 4: " ^ p)
  else begin
    let edges = ref [] in
    for i = 0 to 3 do
      if m.(i).(i) <> 0 then fail ("a loop on the diagonal: " ^ p);
      for j = 0 to 3 do
        if m.(i).(j) <> 0 && m.(i).(j) <> 1 then fail ("an entry that is not 0 or 1: " ^ p);
        if m.(i).(j) <> m.(j).(i) then fail (Printf.sprintf "not symmetric at %d, %d: %s" (i + 1) (j + 1) p);
        if i < j && m.(i).(j) <> 0 then edges := (i, j) :: !edges
      done;
      if Array.for_all (fun entry -> entry = 0) m.(i) then fail (Printf.sprintf "vertex %d is isolated: %s" (i + 1) p)
    done;
    if List.length !edges < 4 then fail ("fewer than four edges: " ^ p);
    if components { size = 4; edges = !edges } <> 1 then fail ("not connected: " ^ p)
  end

(* Every sequence of `length` vertices out of n. *)
let rec sequences n length =
  if length = 0 then [ [] ]
  else List.concat_map (fun rest -> List.init n (fun v -> v :: rest)) (sequences n (length - 1))

let rec steps_along m = function a :: (b :: _ as rest) -> m.(a).(b) = 1 && steps_along m rest | _ -> true

(* The walks with `length` edges from one vertex to another: the sequences
   of length + 1 vertices that start and end there and go along edges. *)
let walks m length first last =
  sequences 4 (length + 1)
  |> List.filter (fun walk -> List.hd walk = first && List.nth walk length = last && steps_along m walk)
  |> List.length

(* ---- The answer of each form, found again ---- *)

let expected (q : Rhema_engine.question) got =
  let p = q.Rhema_engine.prompt in
  let walk_count length =
    let m = matrix p in
    check_matrix p m;
    if whole "walks of length \\[`\\([0-9]+\\)`\\]" p 1 <> length then fail ("the wrong length is asked: " ^ p);
    let first = whole "from vertex \\[`\\([0-9]+\\)`\\]" p 1 and last = whole "to vertex \\[`\\([0-9]+\\)`\\]" p 1 in
    if first < 1 || first > 4 || last < 1 || last > 4 then fail ("not a vertex of the graph: " ^ p);
    if got < 1 then fail ("no walk at all: " ^ p);
    walks m length (first - 1) (last - 1)
  in
  match kind q with
  | "handshake" -> (
      let list = numbers (group "of degrees \\[`\\([0-9, ]+\\)`\\]" p 1) in
      check_five_degrees p list;
      match edge_counts list with
      | [ edges ] -> edges
      | _ -> fail ("the degrees do not settle the edges: " ^ p); min_int)
  | "missing_degree" -> (
      let edges = whole "vertices and \\[`\\([0-9]+\\)`\\] edges" p 1 in
      let known = numbers (group "the degrees \\[`\\([0-9, ]+\\)`\\]" p 1) in
      if List.length known <> 4 then fail ("not four known degrees: " ^ p);
      match List.filter (fun fifth -> List.mem edges (edge_counts (known @ [ fifth ]))) [ 0; 1; 2; 3; 4 ] with
      | [ fifth ] ->
          check_five_degrees p (known @ [ fifth ]);
          if sum known + fifth <> 2 * edges then fail ("the degrees do not add up to twice the edges: " ^ p);
          fifth
      | found ->
          fail (Printf.sprintf "%d possible fifth degrees: %s" (List.length found) p);
          min_int)
  | "complete" ->
      let n = whole "K_{\\([0-9]+\\)}" p 1 in
      let g = { size = n; edges = pairs n } in
      if not (simple g && List.for_all (fun d -> d = n - 1) (degrees g)) then fail ("the test's complete graph is wrong: " ^ p);
      List.length g.edges
  | "complete_bipartite" ->
      let left = whole "K_{\\([0-9]+\\),\\([0-9]+\\)}" p 1 and right = whole "K_{\\([0-9]+\\),\\([0-9]+\\)}" p 2 in
      if left < 1 || left > right then fail ("the smaller side is not written first: " ^ p);
      let edges = List.concat (List.init left (fun a -> List.init right (fun b -> (a, left + b)))) in
      let g = { size = left + right; edges } in
      if not (simple g) then fail ("the test's bipartite graph is wrong: " ^ p);
      List.length edges
  | "forest" ->
      let vertices = whole "has \\[`\\([0-9]+\\)`\\] vertices" p 1 in
      let parts = whole "and \\[`\\([0-9]+\\)`\\] connected components" p 1 in
      if parts < 1 || parts > vertices then begin
        fail ("more components than vertices: " ^ p);
        min_int
      end
      else begin
        (* one long path and lone vertices, or paths as equal as they can be *)
        let lopsided = paths (List.init parts (fun i -> if i = 0 then vertices - parts + 1 else 1)) in
        let even = paths (List.init parts (fun i -> (vertices / parts) + if i < vertices mod parts then 1 else 0)) in
        List.iter
          (fun g ->
            if g.size <> vertices || components g <> parts || not (simple g) then fail ("the test's forest is wrong: " ^ p))
          [ lopsided; even ];
        if List.length lopsided.edges <> List.length even.edges then fail ("two forests with different edges: " ^ p);
        List.length even.edges
      end
  | "tree_leaves" ->
      let re =
        "has \\[`\\([0-9]+\\)`\\] vertices of degree \\[`4`\\], \\[`\\([0-9]+\\)`\\] vertices of degree \\[`3`\\]"
        ^ " and \\[`\\([0-9]+\\)`\\] vertices of degree \\[`2`\\]"
      in
      let a = whole re p 1 and b = whole re p 2 and c = whole re p 3 in
      let tree, leaves = caterpillar (List.init a (fun _ -> 4) @ List.init b (fun _ -> 3) @ List.init c (fun _ -> 2)) in
      let with_degree d = List.length (List.filter (fun found -> found = d) (degrees tree)) in
      if
        not
          (simple tree && components tree = 1
          && List.length tree.edges = tree.size - 1
          && with_degree 4 = a && with_degree 3 = b && with_degree 2 = c
          && with_degree 1 = leaves
          && a + b + c + leaves = tree.size)
      then fail ("the test's tree is wrong: " ^ p);
      (* the only number of leaves for which the degrees add up to 2 (n - 1) *)
      let fits l = (4 * a) + (3 * b) + (2 * c) + l = 2 * (a + b + c + l - 1) in
      if List.filter fits (List.init 500 Fun.id) <> [ got ] then fail ("the degree sum does not single out the answer: " ^ p);
      leaves
  | "walks_two" -> walk_count 2
  | "walks_three" -> walk_count 3
  | "planar_faces" ->
      let vertices = whole "has \\[`\\([0-9]+\\)`\\] vertices, each of degree \\[`\\([0-9]+\\)`\\]" p 1 in
      let each = whole "has \\[`\\([0-9]+\\)`\\] vertices, each of degree \\[`\\([0-9]+\\)`\\]" p 2 in
      let promised =
        vertices mod 2 = 0 && vertices >= 6 && (each = 3 || (each = 4 && vertices <= 12))
      in
      if vertices * each mod 2 <> 0 then fail ("an odd sum of degrees: " ^ p);
      if not promised then begin
        fail ("not a graph the header promises: " ^ p);
        2 - vertices + (vertices * each / 2)
      end
      else begin
        let n = vertices / 2 in
        let solid = if each = 3 then prism n else antiprism n in
        let edges = List.length solid.edges in
        if
          not
            (simple solid && components solid = 1 && solid.size = vertices
            && List.for_all (fun d -> d = each) (degrees solid))
        then fail ("the test's solid is wrong: " ^ p);
        if 2 * edges <> vertices * each then fail ("the solid's edges are not V d / 2: " ^ p);
        if edges > (3 * vertices) - 6 then fail ("too many edges for a planar graph: " ^ p);
        let faces = 2 - vertices + edges in
        (* a prism has two n-gons and n squares, an antiprism two n-gons and 2n triangles *)
        if faces <> if each = 3 then n + 2 else (2 * n) + 2 then fail ("not the faces of the solid: " ^ p);
        if vertices - edges + got <> 2 then fail ("Euler's formula fails: " ^ p);
        faces
      end
  | k -> fail ("unknown kind " ^ k); min_int

let () =
  let base = load_file "graph_theory.rhm" in
  let prices =
    [ ("handshake", 1); ("complete", 1); ("complete_bipartite", 1); ("forest", 1); ("missing_degree", 2);
      ("tree_leaves", 2); ("walks_two", 2); ("planar_faces", 3); ("walks_three", 3) ]
  in
  let seen = Hashtbl.create 9 and regular = Hashtbl.create 2 in
  for cost = 1 to 3 do
    let spec = with_initial base "cost" cost in
    for seed = 0 to 149 do
      Random.init (seed + (1000 * cost));
      match Rhema_engine.generate spec with
      | exception Rhema_engine.Generation_error m -> fail (Printf.sprintf "cost %d seed %d: %s" cost seed m)
      | q ->
          let k = kind q and p = q.Rhema_engine.prompt in
          Hashtbl.replace seen k ();
          if List.assoc_opt k prices <> Some cost then fail (Printf.sprintf "%s at cost %d" k cost);
          if Rhema_engine.consumption q.Rhema_engine.tree "cost" <> cost then fail (k ^ " did not spend its budget");
          let got = answer q in
          let want = (try expected q got with e -> fail (Printf.sprintf "%s: %s for %S" k (Printexc.to_string e) p); min_int) in
          if got <> want then fail (Printf.sprintf "%s: answer %d, recomputed %d, for %S" k got want p);
          (* both degrees of a regular planar graph are asked *)
          if k = "planar_faces" then
            Hashtbl.replace regular (group "each of degree \\[`\\([0-9]+\\)`\\]" p 1) ()
    done
  done;
  List.iter (fun (k, _) -> if not (Hashtbl.mem seen k) then fail ("never generated: " ^ k)) prices;
  List.iter (fun d -> if not (Hashtbl.mem regular d) then fail ("no planar graph of degree " ^ d)) [ "3"; "4" ];
  if !failures = 0 then print_endline "Rhema graph theory tests passed."
  else begin
    prerr_endline (Printf.sprintf "%d graph theory test(s) failed." !failures);
    exit 1
  end
