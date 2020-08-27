(lang dune 1.11)

(name redemon)

(version 0.3.2)

(maintainers "Ulrik Strid")

(authors "Ulrik Strid")

(source
 (github ulrikstrid/redemon))

(homepage https://github.com/ulrikstrid/redemon)

(documentation https://github.com/ulrikstrid/redemon)

(generate_opam_files true)

(using fmt 1.2)

(package
 (name "redemon")
 (synopsis "filewatcher built with luv")
 (description "A filewatcher leveraging the libuv bindings luv.")
 (depends
  (ocaml
   (>= 4.06.1))
  (dune
   (>= 1.11))
  cmdliner
  luv))
