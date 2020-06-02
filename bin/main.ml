let redemon path paths extensions delay verbose command args =
  let paths = path @ paths in
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
      Luv.Time.sleep delay;
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
                if verbose then (
                  if List.mem `RENAME events then prerr_string "renamed ";
                  if List.mem `CHANGE events then prerr_string "changed ";
                  prerr_endline file );
                let file_extension = Filename.extension file in
                let is_file_extension e =
                  String.equal ("." ^ e) file_extension in
                if List.exists is_file_extension extensions then
                  stop_program () |> start_program;
                ))
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

let path =
  let doc = "Path to watch, repeatable" in
  Arg.(value & opt_all file [] & info [ "p"; "path" ] ~docv:"PATH" ~doc)

let paths =
  let doc = "Paths to watch" in
  Arg.(value & opt (list file) [] & info [ "paths" ] ~docv:"PATHS" ~doc)

let extensions =
    let doc = "File extensions that should trigger changes" in
    Arg.(value & opt (list string) [] & info ["e"; "extensions"] ~docv:"EXT" ~doc)

let delay =
    let doc = "Time in ms to wait before restarting" in
    Arg.(value & opt int 100 & info ["delay"] ~docv:"DELAY" ~doc)

let verbose =
  let doc = "Verbose logging" in
  Arg.(value & flag & info [ "v"; "verbose" ] ~doc)

let _ =
  let term = Term.(const redemon $ path $ paths $ extensions $ delay $ verbose $ command $ args) in
  let doc = "A filewatcher built with luv" in
  let info = Term.info ~doc "redemon" in
  Term.eval (term, info)
