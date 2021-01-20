let of_string str =
  match String.uppercase_ascii str with
  | "SIGABRT" -> Luv.Signal.sigabrt
  | "SIGFPE" -> Luv.Signal.sigfpe
  | "SIGHUP" -> Luv.Signal.sighup
  | "SIGILL" -> Luv.Signal.sigill
  | "SIGINT" -> Luv.Signal.sigint
  | "SIGKILL" -> Luv.Signal.sigkill
  | "SIGSEGV" -> Luv.Signal.sigsegv
  | "SIGTERM" -> Luv.Signal.sigterm
  | "SIGWINCH" -> Luv.Signal.sigwinch
  | s -> failwith (Printf.sprintf "Unsupported signal supplied: %s" s)
