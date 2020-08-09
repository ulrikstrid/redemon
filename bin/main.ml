let init_logger verbose =
  let () = Fmt_tty.setup_std_outputs () in
  let () =
    if verbose then Logs.set_level ~all:true (Some Logs.Info)
    else Logs.set_level ~all:true (Some Logs.Error)
  in
  Logs.set_reporter (Logs_fmt.reporter ())

let redirect =
  Luv.Process.
    [
      inherit_fd ~fd:stdout ~from_parent_fd:stdout ();
      inherit_fd ~fd:stderr ~from_parent_fd:stderr ();
      inherit_fd ~fd:stdin ~from_parent_fd:stdin ();
    ]

let timer : Luv.Timer.t option ref = ref None

let rec listen_for_rs restart_program =
  let open Luv.File in
  let buf = Luv.Buffer.create 2 in
  read stdin [ buf ] (function
    | Error e ->
        Logs.err (fun m -> m "Error reading stdin %s" (Luv.Error.strerror e));
        ()
    | Ok _a ->
        let s = Luv.Buffer.to_string buf in
        let () =
          if s = "rs" then (
            Logs.info (fun m -> m {|Got "rs" from stdin, restarting|});
            restart_program () )
          else ()
        in
        listen_for_rs restart_program)

let debounce delay fn =
  match !timer with
  | Some _ -> Logs.info (fun m -> m "Waiting... next run in %ims" 250)
  | None -> (
      let ti : Luv.Timer.t = Result.get_ok (Luv.Timer.init ()) in
      timer := Some ti;
      match
        Luv.Timer.start ti delay (fun () ->
            timer := None;
            fn ())
      with
      | Ok () -> Logs.info (fun m -> m "Started timer, running in %ims" delay)
      | Error _ -> Logs.err (fun m -> m "Error in timer") )

let redemon path paths extensions delay verbose command args =
  let () = init_logger verbose in
  let extensions_provided = List.length extensions <> 0 in
  let paths = path @ paths in
  Logs.info (fun m -> m "Verbose mode enabled");
  let child = ref (Error `UNKNOWN) in
  let start_program () =
    child := Luv.Process.spawn ~redirect command (command :: args)
  in
  let stop_program () =
    Result.map (fun child -> Luv.Process.kill child Luv.Signal.sigkill) !child
    |> ignore;
    child := Error `UNKNOWN
  in
  let restart_program () =
    debounce delay (fun () -> stop_program () |> start_program)
  in
  let restart_now () = stop_program () |> start_program in
  let () = listen_for_rs restart_now in
  let () =
    List.iter
      (fun path ->
        match Luv.FS_event.init () with
        | Error e ->
            Logs.err (fun m ->
                m "Error starting watcher: %s" (Luv.Error.strerror e))
        | Ok watcher ->
            Luv.FS_event.start ~recursive:true ~watch_entry:true watcher path
              (function
              | Error e ->
                  Logs.err (fun m ->
                      m "Error watching %s: %s" path (Luv.Error.strerror e));
                  ignore (Luv.FS_event.stop watcher);
                  Luv.Handle.close watcher stop_program
              | Ok (file, events) ->
                  if List.mem `RENAME events then
                    Logs.info (fun m -> m "Renamed %s" file);
                  if List.mem `CHANGE events then
                    Logs.info (fun m -> m "Changed %s" file);

                  if extensions_provided then (
                    let file_extension = Filename.extension file in
                    let is_file_extension e =
                      String.equal ("." ^ e) file_extension
                    in
                    if List.exists is_file_extension extensions then
                      restart_program () )
                  else if not extensions_provided then restart_program ()))
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
  let doc = "Paths to watch as comma separated list" in
  Arg.(value & opt (list file) [] & info [ "paths" ] ~docv:"PATHS" ~doc)

let extensions =
  let doc = "File extensions that should trigger changes" in
  Arg.(
    value & opt (list string) [] & info [ "e"; "extensions" ] ~docv:"EXT" ~doc)

let delay =
  let doc = "Time in ms to wait before restarting" in
  Arg.(value & opt int 100 & info [ "delay" ] ~docv:"DELAY" ~doc)

let verbose =
  let doc = "Verbose logging" in
  Arg.(value & flag & info [ "v"; "verbose" ] ~doc)

let _ =
  let term =
    Term.(
      const redemon $ path $ paths $ extensions $ delay $ verbose $ command
      $ args)
  in
  let doc = "A filewatcher built with luv" in
  let info = Term.info ~doc "redemon" in
  Term.eval (term, info)
