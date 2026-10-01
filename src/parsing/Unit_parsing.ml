open Common
open Fpath_.Operators
module E = Core_error

let t = Testo.create

(*****************************************************************************)
(* Purpose *)
(*****************************************************************************)
(* Unit (and integration) tests exercising the parsers *)

(*****************************************************************************)
(* Constants *)
(*****************************************************************************)

(* ran from the root of the semgrep repository *)
let tests_path = Fpath.v "tests"
let tests_path_parsing = tests_path / "parsing"
let tests_path_parsing_missing = tests_path / "parsing_missing"
let tests_path_parsing_partial = tests_path / "parsing_partial"
let tests_path_parsing_todo = tests_path / "parsing_todo"

(*****************************************************************************)
(* Helpers *)
(*****************************************************************************)

type error_tolerance = Strict | Missing_tokens | Partial_parsing | Todo

(*
   Strict parsing: errors due to missing (inserted) tokens are not tolerated
   in these tests.
*)
let parsing_tests_for_lang ?expected_outcome files lang =
  files
  |> List_.map (fun file ->
         Testo.create ?expected_outcome ~tags:(Test_tags.tags_of_lang lang)
           (Filename.basename file) (fun () ->
             Parse_target.parse_and_resolve_name_strict lang (Fpath.v file)
             |> ignore))

(* Parsing is expected to succeed with only tolerable parsing errors
   (assumed to be "missing token" nodes inserted by tree-sitter) *)
let missing_tokens_tests_for_lang files lang =
  files
  |> List_.map (fun file ->
         Testo.create ~tags:(Test_tags.tags_of_lang lang)
           (Filename.basename file) (fun () ->
             let { Parsing_result2.errors; tolerated_errors; _ } =
               Parse_target.parse_and_resolve_name lang (Fpath.v file)
             in
             (match errors with
             | [] -> ()
             | _ ->
                 Alcotest.fail
                   ("parsing errors: " ^ Parsing_result2.format_errors errors));
             match tolerated_errors with
             | [] -> Alcotest.fail "no 'missing token' errors. Was it fixed?"
             | _ :: _ ->
                 print_endline
                   ("tolerated errors: "
                   ^ Parsing_result2.format_errors tolerated_errors)))

(* Parsing is expected to fail with at least one parsing error. *)
let partial_parsing_tests_for_lang files lang =
  files
  |> List_.map (fun file ->
         Testo.create ~tags:(Test_tags.tags_of_lang lang)
           ~expected_outcome:
             (Should_fail
                "tree-sitter parsing error is expected: skipped tokens or \
                 missing tokens") (Filename.basename file) (fun () ->
             let { Parsing_result2.errors; tolerated_errors; _ } =
               Parse_target.parse_and_resolve_name lang (Fpath.v file)
             in
             let all_errors = errors @ tolerated_errors in
             match all_errors with
             | [] -> ()
             | _ ->
                 Alcotest.fail
                   ("parsing errors: "
                   ^ Parsing_result2.format_errors all_errors)))

let parsing_tests_for_lang error_tolerance files lang =
  match error_tolerance with
  | Strict -> parsing_tests_for_lang files lang
  | Missing_tokens -> missing_tokens_tests_for_lang files lang
  | Partial_parsing -> partial_parsing_tests_for_lang files lang
  | Todo ->
      parsing_tests_for_lang ~expected_outcome:(Should_fail "to do") files lang

(*****************************************************************************)
(* Tests *)
(*****************************************************************************)

let pack_parsing_tests_for_lang ?(error_tolerance = Strict) lang =
  let slang = Lang.show lang in
  let dir = Lang.to_lowercase_alnum lang in
  let exts = Lang.ext_of_lang lang in
  let dir, subcategory =
    match error_tolerance with
    | Strict -> (tests_path_parsing / dir, None)
    | Missing_tokens -> (tests_path_parsing_missing / dir, Some "missing tokens")
    | Partial_parsing ->
        (tests_path_parsing_partial / dir, Some "partial parsing")
    | Todo -> (tests_path_parsing_todo / dir, None)
  in
  let check_ext file =
    if
      not
        (List.exists
           (fun ext ->
             let regex = spf {|.*%s$|} (Str.quote ext) in
             file =~ regex)
           exts)
    then
      failwith (spf "Unrecognized extension for file %s for lang %s" file slang)
  in
  (* Get all files then check extensions *)
  let pattern = spf "%s/**/*" !!dir in
  let files = Common2.glob pattern in
  if files =*= [] then
    (* No test files found; return an empty suite rather than crashing *)
    []
  else begin
    List.iter check_ext files;
    let tests = parsing_tests_for_lang error_tolerance files lang in
    (match subcategory with
    | None -> tests
    | Some cat -> Testo.categorize cat tests)
    |> Testo.categorize slang
  end

(* Note that here we also use tree-sitter to parse; certain files were not
 * parsing with pfff but parses here
 *)
let lang_parsing_tests langs_with_error_tolerance : Testo.t list =
  langs_with_error_tolerance
  |> List_.map (fun (lang, error_tolerance) ->
         pack_parsing_tests_for_lang ~error_tolerance lang)
  |> Testo.categorize_suites "lang parsing"

(* It's important that our parsers generate classic parsing errors
 * exns (e.g., Parsing_error, Lexical_error), otherwise semgrep
 * will report some "Fatal error" and abort.
 *)
let parsing_error_tests () =
  let dir = tests_path / "parsing_errors" in
  let tags_of_file file =
    match Fpath.to_string file with
    (* For some reason, we can get a `Parsing_error.Syntax_error
       from this test in JS, despite the fact that the `try` makes this
       blatantly impossible.
       I suspect a `jsoo` bug.
    *)
    | file when file =~ ".*/foo.c" -> [ Test_tags.todo_js ]
    | _ -> []
  in
  Testo.categorize "Parsing error detection"
    (let tests = Common2.glob (spf "%s/*" !!dir) in
     tests |> Fpath_.of_strings
     |> List_.map (fun file ->
            t ~tags:(tags_of_file file) (Fpath.basename file) (fun () ->
                try
                  let lang = Lang.lang_of_filename_exn file in
                  let res = Parse_target.just_parse_with_lang lang file in
                  if res.skipped_tokens =*= [] then
                    Alcotest.fail
                      "it should raise a standard parsing error exn or return \
                       partial errors "
                with
                | Parsing_error.Lexical_error _
                | Parsing_error.Syntax_error _ ->
                    ())))

let parsing_rules_tests () =
  let dir = tests_path / "rule_formats" in
  Testo.categorize "Parsing rules"
    (let tests =
       Common2.glob (spf "%s/*.yaml" !!dir)
       @ Common2.glob (spf "%s/*.json" !!dir)
       (* skipped for now to avoid adding jsonnet as a dependency in our
        * CI: Common2.glob (spf "%s/*.jsonnet" dir)
        *)
     in
     tests |> Fpath_.of_strings
     |> List_.map (fun file ->
            t (Fpath.basename file) (fun () ->
                let res = Parse_rule.parse file in
                match res with
                | Ok _ -> ()
                | Error err ->
                    failwith
                      (spf "error %s while parsing %s" (Rule_error.show err)
                         !!file))))

let parsing_rules_with_atd_tests () =
  let dir = tests_path / "rules_v2" in
  let tests1 =
    Common2.glob (spf "%s/*.yaml" !!dir) @ Common2.glob (spf "%s/*.json" !!dir)
  in
  let dir = tests_path / "syntax_v2" in
  let tests2 =
    Common2.glob (spf "%s/*.yaml" !!dir) @ Common2.glob (spf "%s/*.json" !!dir)
  in
  Testo.categorize "Parsing rules with rule_schema_v2.atd"
    (tests1 @ tests2 |> Fpath_.of_strings
    |> List_.map (fun file ->
           t !!file (fun () ->
               Parse_rules_with_atd.parse_rules_v2 file |> ignore)))

(*****************************************************************************)
(* Tests *)
(*****************************************************************************)

let yaml_unicode_tests () =
  [
    t ~tags:(Test_tags.tags_of_lang Lang.Yaml)
      "YAML preserves Unicode values and byte locations" (fun () ->
        let value = "tøkęn_śęçrėt_ẃïth_ŭñïçődė_123456" in
        let check bom newline =
          let first = bom ^ "é: \"" ^ value ^ "\"" ^ newline in
          let text = first ^ "other: \"😀\"" ^ newline in
          let expected =
            [
              ("é", "é", String.length bom, 1, String.length bom);
              ( value,
                "\"" ^ value ^ "\"",
                String.length bom + 4,
                1,
                String.length bom + 4 );
              ("other", "other", String.length first, 2, 0);
              ("😀", "\"😀\"", String.length first + 7, 2, 7);
            ]
          in
          let check_ast ast =
            let actual = ref [] in
            let visitor =
              object
                inherit [_] AST_generic.iter_no_id_info as super

                method! visit_literal () literal =
                  (match literal with
                  | AST_generic.String (_, (value, tok), _) ->
                      let { Tok.str; pos } = Tok.unsafe_loc_of_tok tok in
                      actual :=
                        (value, str, pos.bytepos, pos.line, pos.column)
                        :: !actual
                  | _ -> ());
                  super#visit_literal () literal
              end
            in
            visitor#visit_any () ast;
            let actual = List.rev !actual in
            Alcotest.(check int)
              "scalar count" (List.length expected) (List.length actual);
            List.iter2
              (fun (value, raw, offset, line, column)
                   ( actual_value,
                     actual_raw,
                     actual_offset,
                     actual_line,
                     actual_column ) ->
                Alcotest.(check string) "scalar value" value actual_value;
                Alcotest.(check string) "token source" raw actual_raw;
                Alcotest.(check int) "byte offset" offset actual_offset;
                Alcotest.(check int) "line" line actual_line;
                Alcotest.(check int) "byte column" column actual_column)
              expected actual
          in
          UTmp.with_temp_file ~contents:text ~suffix:".yaml" (fun file ->
              check_ast (AST_generic.Pr (Yaml_to_generic.program file));
              check_ast
                (AST_generic.Pr
                   (Yaml_to_generic.parse_yaml_file ~is_target:false file text)));
          check_ast (Yaml_to_generic.any text)
        in
        List.iter
          (fun bom -> List.iter (check bom) [ "\n"; "\r\n" ])
          [ ""; "\239\187\191" ]);
  ]

let make_tests langs_with_tolerance =
  List_.flatten
    [
      lang_parsing_tests langs_with_tolerance;
      parsing_error_tests ();
      parsing_rules_tests ();
      parsing_rules_with_atd_tests ();
      yaml_unicode_tests ();
    ]

let langs_with_error_tolerance =
  [
    (* languages with only a tree-sitter parser *)
    (Lang.Apex, Strict);
    (Lang.Bash, Strict);
    (Lang.Elixir, Strict);
    (Lang.Csharp, Strict);
    (Lang.Crystal, Strict);
    (Lang.Dockerfile, Strict);
    (Lang.Lua, Strict);
    (Lang.Lua, Todo);
    (Lang.Move_on_aptos, Strict);
    (Lang.Circom, Strict);
    (Lang.Rust, Strict);
    (Lang.Cairo, Strict);
    (Lang.Swift, Strict);
    (Lang.Kotlin, Strict);
    (Lang.Hack, Strict);
    (Lang.Html, Strict);
    (Lang.Xml, Strict);
    (Lang.R, Strict);
    (Lang.Solidity, Strict);
    (Lang.Julia, Strict);
    (Lang.Jsonnet, Strict);
    (Lang.Dart, Strict);
    (Lang.Json, Strict);
    (Lang.Yaml, Strict);
    (* TODO: Move_on_sui has non-.move files in its test dir (TODO/) *)
    (* (Lang.Move_on_sui, Strict); *)
    (Lang.Ql, Strict);
    (* here we have both a Pfff and tree-sitter parser *)
    (Lang.Java, Strict);
    (Lang.Go, Strict);
    (Lang.Ruby, Strict);
    (Lang.Js, Strict);
    (Lang.Ts, Partial_parsing);
    (Lang.Python, Strict);
    (Lang.C, Strict);
    (Lang.Cpp, Strict);
    (Lang.Php, Strict);
    (Lang.Ocaml, Strict);
    (* recursive descent parser *)
    (Lang.Scala, Strict);
    (Lang.Clojure, Strict);
    (Lang.Protobuf, Strict);
    (Lang.Protobuf, Todo);
    (Lang.Promql, Strict);
    (Lang.Terraform, Strict);
    (* a few parsing tests where we expect some partials
     * See cpp/parsing_partial/
     *)
    (Lang.Cpp, Partial_parsing);
    (* a few parsing tests where we rely on "missing tokens" being
       inserted by tree-sitter.
       See cpp/parsing_missing/
    *)
    (Lang.C, Missing_tokens);
    (Lang.Cpp, Missing_tokens);
  ]

let tests () = make_tests langs_with_error_tolerance
