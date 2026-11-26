(* Independent checks for financial_maths.rhm. Every question is matched
   against the whole sentence of its form, the numbers are read back from it,
   and every answer is found again by running the account one year (or one
   half year) at a time, with exact fractions, never by the closed formula
   the grammar uses. A year's interest is always the balance times the
   printed rate over 100, and nothing else is known of a rate here: no
   growth factor is raised to a power.

   simple_interest   the same interest, on the printed sum, is added up year
                     by year.
   compound_amount   the balance starts at the printed sum and a year's
                     interest on the balance is added to it, once for every
                     year.
   present_value     the whole number of dollars that grows to the printed
                     amount is searched for by halving an interval, each
                     candidate being run forwards through the years; as a
                     second opinion the printed amount is run backwards, a
                     year at a time, and must come to the same sum.
   effective_rate    100 dollars are run through the two half years, each at
                     half the printed nominal rate; the gain on 100 dollars
                     is the rate in per cent.
   depreciation      the value starts at the printed price and a year's loss,
                     the printed rate on the value, is taken off, once for
                     every year.
   annuity_future    a balance is kept: each year the interest on the balance
                     is added and then the deposit, which comes at the end of
                     the year. As a second opinion every deposit is grown
                     alone for the years that follow it, and the sum taken.
   annuity_present   an amortisation schedule: a loan grows by a year's
                     interest and is then reduced by the payment. The present
                     value is the whole loan that the printed payments bring
                     to exactly 0 after the last one, searched for by halving
                     an interval. As a second opinion every payment is run
                     backwards alone through the years before it, and the sum
                     taken.
   loan_payment      the same schedule, from the printed loan: the whole
                     payment that brings it to exactly 0 after the last year
                     is searched for by halving an interval. As a second
                     opinion the present value of the payments found, by the
                     search of annuity_present, must be the printed loan.

   The mistakes are found again from what each says the student does.
   simple_for_compound takes the rate times the number of years: a compound
   amount is the sum plus the same yearly interest, on the sum, for every
   year; a present value is the amount divided by 1 + n r, and that sum with
   its yearly interest added n times must be the amount again; a
   depreciated value is the price less n times the first year's loss.
   nominal_taken gives the printed nominal rate. interest_ignored adds up
   the deposits or the payments, or shares the loan equally over the
   payments. Simple interest has no mistake. A question must list exactly
   the mistakes of its form, in the order they are declared, with these
   values, each described in the words it was declared with.

   What WeBWorK's grading needs is pinned. It compares with a relative
   tolerance of one part in a thousand, and the engine writes a whole number
   of 1000 or more so that it is compared to within half a unit. So a
   mistake against a whole answer below 1000 must be more than 0.2% away
   (441 against 440 is the nearest), against a whole answer from 1000 on
   more than half a unit away, and against an answer that is not whole (an
   effective rate) more than 1% away: the nominal rates 2 and 4, whose
   effective rates are 2.01 and 4.04, must not be asked, and the nominal
   rates are the even numbers from 6 to 30.

   Every kind must come up at its price and at no other, the budget must be
   spent, a budget outside 1 to 3 must give no question, a budget left alone
   is 2, every question has one answer and it is a number. The numbers each
   form is asked with are pinned: every choice the grammar offers must come
   up, and nothing else (for simple interest by pairs of its three
   numbers). What the header promises is checked as well: every sum of
   money printed and every answer in dollars is a whole number above 0, and
   so is every balance on the way (the interest of each year, the value of
   the machine after each year, what is still owed after each payment), so
   that nothing has to be rounded; with compound interest the rates are 5,
   10, 20 and 25 per cent and the terms 2 and 3 years; the effective rate is
   a decimal of at most two places, above the nominal rate; a loan is still
   owed in part until the last payment; and no answer is a number printed
   in its question. The weights of the forms are not pinned. *)

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

let range first last = List.init (max 0 (last - first + 1)) (fun i -> first + i)

(* ---- Fractions ---- *)

(* Fractions on OCaml integers, in lowest terms with a positive denominator,
   so that two equal fractions are equal as records. Every sum and product
   is checked: a number that does not fit is an error, never a wrong
   number. *)
type fraction = { top : int; bottom : int }

let too_large () = failwith "a number grew too large to be kept exact"

let times a b =
  if a = 0 || b = 0 then 0
  else if a = min_int || b = min_int then too_large ()
  else
    let product = a * b in
    if product / b <> a then too_large () else product

let plus a b =
  let sum = a + b in
  if a >= 0 = (b >= 0) && sum >= 0 <> (a >= 0) then too_large () else sum

let rec gcd a b = if b = 0 then abs a else gcd b (a mod b)

let fraction top bottom =
  if bottom = 0 then failwith "division by zero";
  let top, bottom = if bottom < 0 then (-top, -bottom) else (top, bottom) in
  let divisor = gcd top bottom in
  if divisor = 0 then { top = 0; bottom = 1 } else { top = top / divisor; bottom = bottom / divisor }

let whole n = { top = n; bottom = 1 }
let zero = whole 0
let one = whole 1

let ( +: ) a b =
  let shared = gcd a.bottom b.bottom in
  fraction
    (plus (times a.top (b.bottom / shared)) (times b.top (a.bottom / shared)))
    (times a.bottom (b.bottom / shared))

let ( *: ) a b =
  let left = gcd a.top b.bottom and right = gcd b.top a.bottom in
  let left = max left 1 and right = max right 1 in
  fraction (times (a.top / left) (b.top / right)) (times (a.bottom / right) (b.bottom / left))

let ( -: ) a b = a +: { b with top = -b.top }
let ( /: ) a b = if b.top = 0 then failwith "division by zero" else a *: fraction b.bottom b.top
let absolute a = { a with top = abs a.top }
let less a b = (a -: b).top < 0
let sum fractions = List.fold_left ( +: ) zero fractions
let show a = if a.bottom = 1 then string_of_int a.top else Printf.sprintf "%d/%d" a.top a.bottom

let number = function
  | Rhema_engine.Num n -> Some (fraction n.Rhema_number.numerator n.Rhema_number.denominator)
  | _ -> None

(* ---- Reading a question ---- *)

(* The numbers of a prompt: the pattern is the whole sentence, with a group
   wherever a number stands. Every number printed is a whole number above
   0, written without a sign or a leading 0. *)
let words = Str.quote
let a_number = "\\([1-9][0-9]*\\)"

let fields count pattern prompt =
  if Str.string_match (Str.regexp pattern) prompt 0 && Str.match_end () = String.length prompt then
    List.init count (fun n -> int_of_string (Str.matched_group (n + 1) prompt))
  else failwith "the wording is not the expected one"

(* ---- An account, one year at a time ---- *)

(* A year's interest on a balance, at a rate in per cent a year. With half
   the rate it is a half year's. *)
let interest_on rate balance = balance *: rate /: whole 100

(* The balances after each of a number of years, the first year first: a
   step takes the balance at the start of a year to the balance at its
   end. *)
let rec years count step balance =
  if count <= 0 then []
  else
    let next = step balance in
    next :: years (count - 1) step next

(* The balance after the last of them. *)
let after count step balance = List.fold_left (fun _ later -> later) balance (years count step balance)

(* A year of compound interest: the interest on the balance is added to it. *)
let with_interest rate balance = balance +: interest_on rate balance

(* A year of depreciation: the loss on the value is taken off it. *)
let with_loss rate value = value -: interest_on rate value

(* A year of a loan: it grows by the interest, and the payment made at the
   end of the year is taken off. *)
let with_payment rate payment owed = with_interest rate owed -: payment

(* A year of saving: the balance earns its interest, and the deposit made at
   the end of the year is added. *)
let with_deposit rate deposit balance = with_interest rate balance +: deposit

(* The sum that a year of interest brings to a balance: the year run
   backwards. *)
let before_interest rate balance = balance /: (one +: (rate /: whole 100))

(* A sum of money that must be a whole number of dollars above 0. *)
let dollars what amount =
  if amount.bottom <> 1 then failwith (Printf.sprintf "%s is %s, not a whole number of dollars" what (show amount));
  if amount.top <= 0 then failwith (Printf.sprintf "%s is %s, not above 0" what (show amount))

(* The whole number from low to high at which a function that increases is
   exactly 0, found by halving the interval. *)
let whole_zero what value low high =
  let sign n = compare (value n).top 0 in
  if sign low > 0 || sign high < 0 then failwith (what ^ " does not lie between the bounds of the search");
  let rec search low high =
    (* value low <= 0 <= value high *)
    if high - low <= 1 then
      if sign low = 0 then low
      else if sign high = 0 then high
      else failwith (what ^ " is not a whole number of dollars")
    else
      let middle = low + ((high - low) / 2) in
      if sign middle <= 0 then search middle high else search low middle
  in
  search low high

(* The sum that grows to an amount in a number of years of compound
   interest. *)
let sum_growing_to rate count amount =
  whole_zero "the sum invested" (fun s -> after count (with_interest rate) (whole s) -: whole amount) 0 amount

(* The loan that a number of equal yearly payments repay exactly: more than
   nothing, and less than the payments added up. *)
let loan_repaid_by rate count payment =
  whole_zero "the present value" (fun loan -> after count (with_payment rate (whole payment)) (whole loan)) 0
    (count * payment)

(* The yearly payment that repays a loan exactly in a number of years: what
   is owed at the end falls as the payment rises. A payment of the loan with
   a year's interest, rounded up, repays it within the first year. *)
let payment_repaying rate count loan =
  let first = with_interest rate (whole loan) in
  whole_zero "the payment"
    (fun payment -> zero -: after count (with_payment rate (whole payment)) (whole loan))
    0
    ((first.top / first.bottom) + 1)

(* ---- What each form was asked with ---- *)

let asked : (string, int list) Hashtbl.t = Hashtbl.create 1024
let note label numbers = Hashtbl.add asked label numbers

(* The rates and the terms of compound interest. *)
let compound_rates = [ 5; 10; 20; 25 ]
let terms = [ 2; 3 ]

(* The denominator of a year's growth factor, 1 + rate / 100, in lowest
   terms: 20, 10, 5 and 4 for the four rates. *)
let denominator rate = (one +: fraction rate 100).bottom

(* The unit of money of a rate: 25 dollars where the denominator is small. *)
let unit_of rate = if denominator rate < 10 then 25 else 1

let rec power base exponent = if exponent <= 0 then 1 else times base (power base (exponent - 1))

(* Every choice the grammar offers, form by form: every tuple of numbers it
   may ask a form with, handed to a function one by one, and the views of
   those tuples (lists of positions) that must come up in full. With
   compound interest a tuple is the rate, the term and the sum of money
   printed, which is m units times a power of the denominator of the rate,
   for m from 1 to 6, or what that sum becomes: the sums are made here by
   running the account, as the answers are. *)
let offered =
  let compound sum_printed emit =
    List.iter
      (fun rate ->
        List.iter
          (fun n -> List.iter (fun m -> emit [ rate; n; sum_printed rate n (m * unit_of rate) ]) (range 1 6))
          terms)
      compound_rates
  in
  let grown rate n start =
    let amount = after n (with_interest (whole rate)) (whole start) in
    dollars "a sum that is offered" amount;
    amount.top
  in
  let all = [ [ 0; 1; 2 ] ] in
  [ (* the hundreds of dollars, the rate and the years *)
    ( "simple_interest",
      (fun emit ->
        List.iter
          (fun a -> List.iter (fun r -> List.iter (fun n -> emit [ a; r; n ]) (range 2 6)) (range 2 12))
          (range 2 50)),
      [ [ 0; 1 ]; [ 0; 2 ]; [ 1; 2 ] ] );
    ("compound_amount", compound (fun rate n units -> units * power (denominator rate) n), all);
    ("present_value", compound (fun rate n units -> grown rate n (units * power (denominator rate) n)), all);
    (* the nominal rate: twice 3 to 15 *)
    ("effective_rate", (fun emit -> List.iter (fun j -> emit [ 2 * j ]) (range 3 15)), [ [ 0 ] ]);
    ("depreciation", compound (fun rate n units -> units * power (denominator rate) n), all);
    ("annuity_future", compound (fun rate n units -> units * power (denominator rate) (n - 1)), all);
    ("annuity_present", compound (fun rate n units -> grown rate n (units * power (denominator rate) n)), all);
    ( "loan_payment",
      compound (fun rate n units ->
          loan_repaid_by (whole rate) n (grown rate n (units * power (denominator rate) n))),
      all ) ]

(* ---- The answer of each form, found again ---- *)

(* The right answer of a question, the answer of each mistake its form is
   open to, and the numbers printed in it, all found again from the
   prompt. *)
let expected (q : Rhema_engine.question) =
  let p = q.Rhema_engine.prompt in
  let k = kind q in
  (* every balance on the way is a whole number of dollars above 0 *)
  let each_whole what balances =
    List.iteri (fun i balance -> dollars (Printf.sprintf "%s %d" what (i + 1)) balance) balances
  in
  let last start balances = List.fold_left (fun _ later -> later) start balances in
  match k with
  | "simple_interest" -> (
      match
        fields 3
          (words "A sum of [`" ^ a_number ^ words "`] dollars earns simple interest at [`" ^ a_number
         ^ words "`] per cent a year. Find the interest, in dollars, earned in [`" ^ a_number ^ words "`] years.")
          p
      with
      | [ principal; rate; n ] as printed ->
          if principal mod 100 <> 0 then failwith "the sum is not a whole number of hundreds of dollars";
          note k [ principal / 100; rate; n ];
          (* the same interest every year, on the sum itself *)
          let each_year = List.map (fun _ -> interest_on (whole rate) (whole principal)) (range 1 n) in
          each_whole "the interest of year" each_year;
          (sum each_year, [], printed)
      | _ -> failwith "three numbers were expected")
  | "compound_amount" -> (
      match
        fields 3
          (words "A sum of [`" ^ a_number ^ words "`] dollars is invested at [`" ^ a_number
         ^ words "`] per cent a year, compounded yearly. Find its value, in dollars, after [`" ^ a_number
         ^ words "`] years.")
          p
      with
      | [ principal; rate; n ] as printed ->
          note k [ rate; n; principal ];
          let rate = whole rate and start = whole principal in
          let balances = years n (with_interest rate) start in
          each_whole "the value after year" balances;
          (* simple interest: the first year's interest, on the sum, every year *)
          let simple = start +: sum (List.map (fun _ -> interest_on rate start) (range 1 n)) in
          (last start balances, [ ("simple_for_compound", simple) ], printed)
      | _ -> failwith "three numbers were expected")
  | "present_value" -> (
      match
        fields 3
          (words "What sum, in dollars, invested now at [`" ^ a_number
         ^ words "`] per cent a year, compounded yearly, grows to [`" ^ a_number ^ words "`] dollars in [`" ^ a_number
         ^ words "`] years?")
          p
      with
      | [ rate; amount; n ] as printed ->
          note k [ rate; n; amount ];
          let rate = whole rate in
          let invested = sum_growing_to rate n amount in
          let balances = years n (with_interest rate) (whole invested) in
          each_whole "the value after year" balances;
          if last zero balances <> whole amount then failwith "the sum found does not grow to the amount";
          (* the amount run backwards through the years *)
          if after n (before_interest rate) (whole amount) <> whole invested then
            failwith "the amount run backwards does not come to the sum found";
          (* simple interest: the amount is the sum times 1 + n r *)
          let simple = whole amount /: (one +: (whole n *: rate /: whole 100)) in
          if simple +: sum (List.map (fun _ -> interest_on rate simple) (range 1 n)) <> whole amount then
            failwith "the sum of the mistake does not come to the amount under simple interest";
          (whole invested, [ ("simple_for_compound", simple) ], printed)
      | _ -> failwith "three numbers were expected")
  | "effective_rate" -> (
      match
        fields 1
          (words "A nominal rate of [`" ^ a_number
         ^ words "`] per cent a year is compounded twice a year. Find the effective rate per year, in per cent.")
          p
      with
      | [ nominal ] as printed ->
          note k [ nominal ];
          (* 100 dollars through the two half years, each at half the rate *)
          let half = fraction nominal 2 in
          let hundred = whole 100 in
          let gain = after 2 (with_interest half) hundred -: hundred in
          if 100 mod gain.bottom <> 0 then failwith "the effective rate is not a decimal of two places";
          if not (less (whole nominal) gain) then failwith "the effective rate is not above the nominal rate";
          (gain, [ ("nominal_taken", whole nominal) ], printed)
      | _ -> failwith "one number was expected")
  | "depreciation" -> (
      match
        fields 3
          (words "A machine bought for [`" ^ a_number ^ words "`] dollars loses [`" ^ a_number
         ^ words "`] per cent of its value each year. Find its value, in dollars, after [`" ^ a_number
         ^ words "`] years.")
          p
      with
      | [ price; rate; n ] as printed ->
          note k [ rate; n; price ];
          let rate = whole rate and start = whole price in
          let values = years n (with_loss rate) start in
          each_whole "the value after year" values;
          (* the first year's loss, on the price, every year *)
          let simple = start -: sum (List.map (fun _ -> interest_on rate start) (range 1 n)) in
          (last start values, [ ("simple_for_compound", simple) ], printed)
      | _ -> failwith "three numbers were expected")
  | "annuity_future" -> (
      match
        fields 3
          (words "[`" ^ a_number ^ words "`] dollars are paid into an account at the end of each year for [`" ^ a_number
         ^ words "`] years. The account pays [`" ^ a_number
         ^ words
             "`] per cent a year, compounded yearly. Find the amount, in dollars, in the account just after the last payment."
          )
          p
      with
      | [ deposit; n; rate ] as printed ->
          note k [ rate; n; deposit ];
          let rate = whole rate in
          let balances = years n (with_deposit rate (whole deposit)) zero in
          each_whole "the balance after year" balances;
          let amount = last zero balances in
          (* each deposit alone, grown for the years that follow it *)
          let apart = sum (List.map (fun year -> after (n - year) (with_interest rate) (whole deposit)) (range 1 n)) in
          if apart <> amount then failwith "the deposits grown one by one do not add up to the balance";
          (amount, [ ("interest_ignored", whole (n * deposit)) ], printed)
      | _ -> failwith "three numbers were expected")
  | "annuity_present" -> (
      match
        fields 3
          (words "Find the present value, in dollars, of [`" ^ a_number ^ words "`] payments of [`" ^ a_number
         ^ words "`] dollars, one at the end of each year, at [`" ^ a_number
         ^ words "`] per cent a year, compounded yearly.")
          p
      with
      | [ n; payment; rate ] as printed ->
          note k [ rate; n; payment ];
          let rate = whole rate in
          let loan = loan_repaid_by rate n payment in
          let owed = years n (with_payment rate (whole payment)) (whole loan) in
          if last one owed <> zero then failwith "the payments do not bring the present value to exactly 0";
          each_whole "what is owed after year" (List.filteri (fun i _ -> i < n - 1) owed);
          (* each payment alone, run backwards through the years before it *)
          let apart = sum (List.map (fun year -> after year (before_interest rate) (whole payment)) (range 1 n)) in
          if apart <> whole loan then failwith "the payments run backwards one by one do not add up to the present value";
          (whole loan, [ ("interest_ignored", whole (n * payment)) ], printed)
      | _ -> failwith "three numbers were expected")
  | "loan_payment" -> (
      match
        fields 3
          (words "A loan of [`" ^ a_number ^ words "`] dollars at [`" ^ a_number
         ^ words "`] per cent a year, compounded yearly, is repaid by [`" ^ a_number
         ^ words "`] equal payments, one at the end of each year. Find the payment, in dollars.")
          p
      with
      | [ loan; rate; n ] as printed ->
          note k [ rate; n; loan ];
          let rate = whole rate in
          let payment = payment_repaying rate n loan in
          let owed = years n (with_payment rate (whole payment)) (whole loan) in
          if last one owed <> zero then failwith "the payment does not bring the loan to exactly 0";
          each_whole "what is owed after year" (List.filteri (fun i _ -> i < n - 1) owed);
          if loan_repaid_by rate n payment <> loan then failwith "the present value of the payments is not the loan";
          (whole payment, [ ("interest_ignored", fraction loan n) ], printed)
      | _ -> failwith "three numbers were expected")
  | k -> failwith ("unknown kind " ^ k)

(* Whether a mistaken answer is near enough to the right one to be doubted.
   A right answer that is a whole number is written so that no other whole
   number passes: below 1000 WeBWorK's own tolerance of one part in a
   thousand does it, and the mistake must be more than 0.2% away; from 1000
   on it is compared to within half a unit. Any other right answer needs
   the mistake more than 1% away. *)
let too_near right wrong =
  let gap = absolute (wrong -: right) and size = absolute right in
  if right.bottom = 1 then
    if less size (whole 1000) then not (less size (whole 500 *: gap)) else not (less (fraction 1 2) gap)
  else not (less size (whole 100 *: gap))

(* How many questions are made at each budget. *)
let questions_at _cost = 20000

(* Added to every seed: the suite must pass whatever it is. *)
let seed_offset = 0

let () =
  let base = load_file "financial_maths.rhm" in
  let prices =
    [ ("simple_interest", 1); ("compound_amount", 1); ("present_value", 2); ("effective_rate", 2); ("depreciation", 2);
      ("annuity_future", 3); ("annuity_present", 3); ("loan_payment", 3) ]
  in
  (* how each mistake is described *)
  let described =
    [ ( "simple_for_compound",
        "uses simple interest, the rate times the number of years, where the interest is compounded" );
      ("nominal_taken", "gives the nominal rate itself for the effective rate");
      ("interest_ignored", "leaves interest out and only adds up, or shares out, the payments") ]
  in
  let seen = Hashtbl.create 16 and made = Hashtbl.create 8 in
  (* a budget below the lowest or above the highest is refused *)
  List.iter
    (fun cost ->
      match Rhema_check.with_initial base "cost" cost with
      | Error _ -> ()
      | Ok spec -> (
          Random.init (1 + seed_offset);
          match Rhema_engine.generate spec with
          | exception Rhema_engine.Generation_error _ -> ()
          | q -> fail (Printf.sprintf "budget %d gave a question: %s" cost q.Rhema_engine.prompt)))
    [ -1; 0; 4; 5; 6; 9 ];
  (* left alone, the budget is 2 *)
  for seed = 0 to 199 do
    Random.init (seed + seed_offset);
    match Rhema_engine.generate base with
    | exception Rhema_engine.Generation_error m -> fail (Printf.sprintf "no budget set, seed %d: %s" seed m)
    | q ->
        if List.assoc_opt (kind q) prices <> Some 2 then
          fail ("with no budget set, a question that does not cost 2: " ^ kind q)
  done;
  for cost = 1 to 3 do
    let spec = with_initial base "cost" cost in
    for seed = 0 to questions_at cost - 1 do
      Random.init (seed + (100000 * cost) + seed_offset);
      match Rhema_engine.generate spec with
      | exception Rhema_engine.Generation_error m -> fail (Printf.sprintf "cost %d seed %d: %s" cost seed m)
      | q -> (
          let k = kind q and p = q.Rhema_engine.prompt in
          Hashtbl.replace seen k ();
          if List.assoc_opt k prices <> Some cost then fail (Printf.sprintf "%s at cost %d" k cost);
          if Rhema_engine.consumption q.Rhema_engine.tree "cost" <> cost then fail (k ^ " did not spend its budget");
          if q.Rhema_engine.context <> "Numeric" then fail (Printf.sprintf "%s in context %s" k q.Rhema_engine.context);
          match List.map number q.Rhema_engine.answers with
          | [ Some got ] when number q.Rhema_engine.answer = Some got -> (
              match expected q with
              | exception e -> fail (Printf.sprintf "%s: %s for %S" k (Printexc.to_string e) p)
              | want, slips, printed ->
                  if got <> want then fail (Printf.sprintf "%s: answer %s, recomputed %s, for %S" k (show got) (show want) p);
                  (* a sum of money is a whole number of dollars above 0 *)
                  if k <> "effective_rate" then (
                    try dollars "the answer" got with Failure m -> fail (Printf.sprintf "%s: %s, for %S" k m p));
                  (* the answer is not to be read off the question *)
                  if List.exists (fun n -> whole n = want) printed then
                    fail (Printf.sprintf "%s: the answer %s is printed in the question %S" k (show want) p);
                  (* a question in which the mistake comes to the right
                     answer, or near enough to be taken for it, is not to be
                     asked *)
                  List.iter
                    (fun (name, slip) ->
                      if slip = want then fail (Printf.sprintf "%s: %s gives the right answer, for %S" k name p)
                      else if too_near want slip then
                        fail
                          (Printf.sprintf "%s: %s gives %s, too near the answer %s, for %S" k name (show slip) (show want) p);
                      if slip.top <= 0 then fail (Printf.sprintf "%s: %s gives %s, not above 0, for %S" k name (show slip) p))
                    slips;
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
                      (* each mistake is described in its own words *)
                      (match List.assoc_opt m.mistake described with
                      | Some text ->
                          if m.description <> text then fail (Printf.sprintf "%s is described as %S" m.mistake m.description)
                      | None -> fail ("an unknown mistake is listed: " ^ m.mistake));
                      match (m.mistaken_answers, List.assoc_opt m.mistake slips) with
                      | Some [ value ], Some slip -> (
                          match number value with
                          | None -> fail (Printf.sprintf "%s: %s does not give a number, for %S" k m.mistake p)
                          | Some wrong ->
                              if wrong <> slip then
                                fail
                                  (Printf.sprintf "%s: %s gives %s, recomputed %s, for %S" k m.mistake (show wrong) (show slip) p);
                              if wrong = got then fail (Printf.sprintf "%s: %s gives the right answer, for %S" k m.mistake p))
                      | Some _, Some _ -> fail (Printf.sprintf "%s: %s does not give one answer, for %S" k m.mistake p)
                      | None, Some _ -> fail (Printf.sprintf "%s: %s gives no answer, for %S" k m.mistake p)
                      | _, None -> ())
                    listed)
          | _ -> fail (Printf.sprintf "%s: one number was expected as the answer of %S" k p))
    done
  done;
  List.iter (fun (k, _) -> if not (Hashtbl.mem seen k) then fail ("never generated: " ^ k)) prices;
  Hashtbl.iter (fun k _ -> if not (List.mem_assoc k prices) then fail ("a kind the header does not list: " ^ k)) seen;
  List.iter
    (fun (mistake, k) ->
      if not (Hashtbl.mem made (mistake, k)) then fail (Printf.sprintf "%s never listed on %s" mistake k))
    [ ("simple_for_compound", "compound_amount"); ("simple_for_compound", "present_value");
      ("simple_for_compound", "depreciation"); ("nominal_taken", "effective_rate");
      ("interest_ignored", "annuity_future"); ("interest_ignored", "annuity_present");
      ("interest_ignored", "loan_payment") ];
  (* every choice the grammar offers came up, and nothing else, in each view *)
  let print numbers = "(" ^ String.concat ", " (List.map string_of_int numbers) ^ ")" in
  let project view numbers = List.map (fun i -> List.nth numbers i) view in
  List.iter
    (fun (label, choices, views) ->
      let wanted = List.map (fun view -> (view, Hashtbl.create 64)) views in
      choices (fun numbers -> List.iter (fun (view, table) -> Hashtbl.replace table (project view numbers) ()) wanted);
      let found = Hashtbl.find_all asked label in
      List.iter
        (fun (view, table) ->
          let met = Hashtbl.create 64 in
          List.iter
            (fun numbers ->
              let part = project view numbers in
              if not (Hashtbl.mem met part) then begin
                Hashtbl.replace met part ();
                if not (Hashtbl.mem table part) then
                  fail (Printf.sprintf "%s: asked with %s at %s" label (print part) (print view))
              end)
            found;
          Hashtbl.iter
            (fun part () ->
              if not (Hashtbl.mem met part) then fail (Printf.sprintf "%s: never asked with %s at %s" label (print part) (print view)))
            table)
        wanted)
    offered;
  Hashtbl.iter
    (fun label _ ->
      if not (List.exists (fun (l, _, _) -> l = label) offered) then fail ("nothing is known of what is offered for " ^ label))
    asked;
  if !failures = 0 then print_endline "Rhema financial_maths tests passed."
  else begin
    prerr_endline (Printf.sprintf "%d financial_maths test(s) failed." !failures);
    exit 1
  end
