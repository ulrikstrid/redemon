let redemon paths verbose command args =
  if verbose then print_endline "Verbose mode enabled";
  let redirect =
    Luv.Process.
      [
        inherit_fd ~fd:stdout ~from_parent_fd:stdout ();
        inherit_fd ~fd:stderr ~from_parent_fd:stderr ();
        inherit_fd ~fd:stdin ~from_parent_fd:stdin ();
      ]
  in
  let child = ref (Error `UNKNOWN) in
  let next_run = ref 0 in
  let start_program () =
    if !next_run = 0 then (
      next_run := 100;
      Luv.Time.sleep 100;
      next_run := 0 );
    if !next_run != 0 then ()
    else child := Luv.Process.spawn ~redirect command (command :: args)
  in
  let stop_program () =
    Result.map (fun child -> Luv.Process.kill child Luv.Signal.sigkill) !child
    |> ignore;
    child := Error `UNKNOWN
  in
  let () =
    List.iter
      (fun path ->
        match Luv.FS_event.init () with
        | Error e ->
            Printf.eprintf "Error starting watcher: %s\n" (Luv.Error.strerror e)
        | Ok watcher ->
            Luv.FS_event.start ~recursive:true ~watch_entry:true watcher path
              (function
              | Error e ->
                  Printf.eprintf "Error watching %s: %s\n" path
                    (Luv.Error.strerror e);
                  ignore (Luv.FS_event.stop watcher);
                  Luv.Handle.close watcher stop_program
              | Ok (file, events) ->
                  print_endline "Stopping and starting the program.";
                  stop_program () |> start_program;
                  if verbose then (
                    if List.mem `RENAME events then prerr_string "renamed ";
                    if List.mem `CHANGE events then prerr_string "changed ";
                    prerr_endline file )))
      paths
  in
  start_program ();
  ignore (Luv.Loop.run () : bool)

open Cmdliner

let command =
  let doc = "Command to run" in
  Arg.(
    required
    & pos ~rev:false 0 (some string) None
    & info [] ~docv:"COMMAND" ~doc)

let args =
  let doc = "args to send to COMMAND" in
  Arg.(value & pos_right ~rev:false 0 string [] & info [] ~docv:"ARGS" ~doc)

let paths =
  let doc = "Paths to watch, repeatable" in
  Arg.(value & opt_all file [] & info [ "p"; "path" ] ~docv:"PATH" ~doc)

let verbose =
  let doc = "Verbose logging" in
  Arg.(value & flag & info [ "v"; "verbose" ] ~doc)

let _ =
  let term = Term.(const redemon $ paths $ verbose $ command $ args) in
  let doc = "A filewatcher built with luv" in
  let info = Term.info ~doc "redemon" in
  Term.eval (term, info)
