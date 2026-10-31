let render doc =
  let cst = match Parser.Settle.main (Describe.describe_document doc) with
    | Some cst -> cst
    | None -> failwith "vector document did not settle"
  in
  let buffer = Buffer.create 1024 in
  PPrint.ToBuffer.pretty 1.0 80 buffer (Print_pprint.to_doc cst);
  Buffer.contents buffer

let parse source =
  let buffer = Lexing.from_string source in
  try Parser.main Lexer.read buffer with Parser.Error ->
    let pos = Lexing.lexeme_start buffer in
    failwith (Printf.sprintf "parse error at %d near %S" pos
      (String.sub source (max 0 (pos - 40)) (min 80 (String.length source - max 0 (pos - 40)))))

let source ~scoped =
  let a, b, norm, unit = if scoped then
    let a = {|Vector(Parser::Context->getCopy("Vector"),1,2,3)|} in
    a, {|Vector(Parser::Context->getCopy("Vector"),4,5,6)|}, a ^ "->norm()", a ^ "->unit()"
  else
    {|Compute("<1,2,3>")|}, {|Compute("<4,5,6>")|},
    {|norm(Compute("<1,2,3>"))|}, {|unit(Compute("<1,2,3>"))|}
  in
  Printf.sprintf {|DOCUMENT();
loadMacros("PGstandard.pl", "MathObjects.pl", "PGML.pl");
Context("Numeric");

Context("Interval");

Context("Vector");

BEGIN_PGML
Suppose the vectors:
- [` \vec{a} = \langle 1,2,3 \rangle `]
- [` \vec{b} = \langle 4,5,6 \rangle `]

Compute:
- [` \vec{a} \cdot \vec{b} = `] [_____]{%s . %s}
- [` \vec{a} \times \vec{b} = `] [_____]{%s x %s}
- [` \left\| \vec{a} \right\| = `] [_____]{%s}
- Enter a unit vector in the direction of [` \vec{a} `]. [_____]{%s}
- Enter a vector parallel to [` \vec{a} `]. [_____]{%s->cmp(parallel=>1)}
- Enter a vector in the same direction as [` \vec{a} `]. [_____]{%s->cmp(parallel=>1,sameDirection=>1)}

END_PGML
ENDDOCUMENT();|} a b a b norm unit a a

let () =
  let legacy = parse (source ~scoped:false) in
  let scoped = parse (source ~scoped:true) in
  Semantic.validate legacy;
  Semantic.validate scoped;
  assert (scoped = legacy);
  assert (render scoped = render legacy);
  print_endline "Classic vectors: six legacy/scoped forms parse to the same AST and print identically."
