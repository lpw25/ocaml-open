.\"***********************************************************************
.\"*                                                                     *
.\"*                                OCaml                                *
.\"*                                                                     *
.\"*            Xavier Leroy, projet Cristal, INRIA Rocquencourt         *
.\"*                                                                     *
.\"*  Copyright 1996 Institut National de Recherche en Informatique et   *
.\"*  en Automatique.  All rights reserved.  This file is distributed    *
.\"*  under the terms of the Q Public License version 1.0.               *
.\"*                                                                     *
.\"***********************************************************************
.\"
.\" $Id$
.\"
.TH OCAMLC 1

.SH NAME
ocamlc \- The OCaml bytecode compiler

.SH SYNOPSIS
.B ocamlc
[
.I options
]
.I filename ...

.B ocamlc.opt
[
.I options
]
.I filename ...

.SH DESCRIPTION

The OCaml bytecode compiler
.BR ocamlc (1)
compiles OCaml source files to bytecode object files and links
these object files to produce standalone bytecode executable files.
These executable files are then run by the bytecode interpreter
.BR ocamlrun (1).

The
.BR ocamlc (1)
command has a command-line interface similar to the one of
most C compilers. It accepts several types of arguments and processes them
sequentially:

Arguments ending in .mli are taken to be source files for
compilation unit interfaces. Interfaces specify the names exported by
compilation units: they declare value names with their types, define
public data types, declare abstract data types, and so on. From the
file
.IR x \&.mli,
the
.BR ocamlc (1)
compiler produces a compiled interface
in the file
.IR x \&.cmi.

Arguments ending in .ml are taken to be source files for compilation
unit implementations. Implementations provide definitions for the
names exported by the unit, and also contain expressions to be
evaluated for their side-effects.  From the file
.IR x \&.ml,
the
.BR ocamlc (1)
compiler produces compiled object bytecode in the file
.IR x \&.cmo.

If the interface file
.IR x \&.mli
exists, the implementation
.IR x \&.ml
is checked against the corresponding compiled interface
.IR x \&.cmi,
which is assumed to exist. If no interface
.IR x \&.mli
is provided, the compilation of
.IR x \&.ml
produces a compiled interface file
.IR x \&.cmi
in addition to the compiled object code file
.IR x \&.cmo.
The file
.IR x \&.cmi
produced
corresponds to an interface that exports everything that is defined in
the implementation
.IR x \&.ml.

Arguments ending in .cmo are taken to be compiled object bytecode.  These
files are linked together, along with the object files obtained
by compiling .ml arguments (if any), and the OCaml standard
library, to produce a standalone executable program. The order in
which .cmo and.ml arguments are presented on the command line is
relevant: compilation units are initialized in that order at
run-time, and it is a link-time error to use a component of a unit
before having initialized it. Hence, a given
.IR x \&.cmo
file must come before all .cmo files that refer to the unit
.IR x .

Arguments ending in .cma are taken to be libraries of object bytecode.
A library of object bytecode packs in a single file a set of object
bytecode files (.cmo files). Libraries are built with
.B ocamlc\ \-a
(see the description of the
.B \-a
option below). The object files
contained in the library are linked as regular .cmo files (see above),
in the order specified when the .cma file was built. The only
difference is that if an object file
contained in a library is not referenced anywhere in the program, then
it is not linked in.

Arguments ending in .c are passed to the C compiler, which generates
a .o object file. This object file is linked with the program if the
.B \-custom
flag is set (see the description of
.B \-custom
below).

Arguments ending in .o or .a are assumed to be C object files and
libraries. They are passed to the C linker when linking in
.B \-custom
mode (see the description of
.B \-custom
below).

Arguments ending in .so
are assumed to be C shared libraries (DLLs).  During linking, they are
searched for external C functions referenced from the OCaml code,
and their names are written in the generated bytecode executable.
The run-time system
.BR ocamlrun (1)
then loads them dynamically at program start-up time.

The output of the linking phase is a file containing compiled bytecode
that can be executed by the OCaml bytecode interpreter:
the command
.BR ocamlrun (1).
If
.B caml.out
is the name of the file produced by the linking phase, the command
.B ocamlrun caml.out
.IR arg1 \  \ arg2 \ ... \ argn
executes the compiled code contained in
.BR caml.out ,
passing it as arguments the character strings
.I arg1
to
.IR argn .
(See
.BR ocamlrun (1)
for more details.)

On most systems, the file produced by the linking
phase can be run directly, as in:
.B ./caml.out
.IR arg1 \  \ arg2 \ ... \ argn .
The produced file has the executable bit set, and it manages to launch
the bytecode interpreter by itself.

.B ocamlc.opt
is the same compiler as
.BR ocamlc ,
but compiled with the native-code compiler
.BR ocamlopt (1).
Thus, it behaves exactly like
.BR ocamlc ,
but compiles faster.
.B ocamlc.opt
may not be available in all installations of OCaml.

.SH OPTIONS

The following command-line options are recognized by
.BR ocamlc (1).
.TP
.B \-a
Build a library (.cma file) with the object files (.cmo files) given
on the command line, instead of linking them into an executable
file. The name of the library must be set with the
.B \-o
option.
.IP
If
.BR \-custom , \ \-cclib \ or \ \-ccopt
options are passed on the command
line, these options are stored in the resulting .cma library.  Then,
linking with this library automatically adds back the
.BR \-custom , \ \-cclib \ and \ \-ccopt
options as if they had been provided on the
command line, unless the
.B -noautolink
option is given.
.TP
.B \-annot
Dump detailed information about the compilation (types, bindings,
tail-calls, etc).  The information for file
.IR src .ml
is put into file
.IR src .annot.
In case of a type error, dump all the information inferred by the
type-checker before the error. The
.IR src .annot
file can be used with the emacs commands given in
.B emacs/caml\-types.el
to display types and other annotations interactively.
.TP
.B \-dtypes
Has been deprecated. Please use
.B \-annot
instead.
.TP
.B \-c
Compile only. Suppress the linking phase of the
compilation. Source code files are turned into compiled files, but no
executable file is produced. This option is useful to
compile modules separately.
.TP
.BI \-cc \ ccomp
Use
.I ccomp
as the C linker when linking in "custom runtime" mode (see the
.B \-custom
option) and as the C compiler for compiling .c source files.
.TP
.BI \-cclib\ -l libname
Pass the
.BI \-l libname
option to the C linker when linking in "custom runtime" mode (see the
.B \-custom
option). This causes the given C library to be linked with the program.
.TP
.B \-ccopt
Pass the given option to the C compiler and linker, when linking in
"custom runtime" mode (see the
.B \-custom
option). For instance,
.BI \-ccopt\ \-L dir
causes the C linker to search for C libraries in
directory
.IR dir .
.TP
.B \-config
Print the version number of
.BR ocamlc (1)
and a detailed summary of its configuration, then exit.
.TP
.B \-custom
Link in "custom runtime" mode. In the default linking mode, the
linker produces bytecode that is intended to be executed with the
shared runtime system,
.BR ocamlrun (1).
In the custom runtime mode, the
linker produces an output file that contains both the runtime system
and the bytecode for the program. The resulting file is larger, but it
can be executed directly, even if the
.BR ocamlrun (1)
command is not
installed. Moreover, the "custom runtime" mode enables linking OCaml
code with user-defined C functions.

Never use the
.BR strip (1)
command on executables produced by
.BR ocamlc\ \-custom ,
this would remove the bytecode part of the executable.
.TP
.BI \-dllib\ \-l libname
Arrange for the C shared library
.BI dll libname .so
to be loaded dynamically by the run-time system
.BR ocamlrun (1)
at program start-up time.
.TP
.BI \-dllpath \ dir
Adds the directory
.I dir
to the run-time search path for shared
C libraries.  At link-time, shared libraries are searched in the
standard search path (the one corresponding to the
.B \-I
option).
The
.B \-dllpath
option simply stores
.I dir
in the produced
executable file, where
.BR ocamlrun (1)
can find it and use it.
.TP
.B \-g
Add debugging information while compiling and linking. This option is
required in order to be able to debug the program with
.BR ocamldebug (1)
and to produce stack backtraces when
the program terminates on an uncaught exception.
.TP
.B \-i
Cause the compiler to print all defined names (with their inferred
types or their definitions) when compiling an implementation (.ml
file). No compiled files (.cmo and .cmi files) are produced.
This can be useful to check the types inferred by the
compiler. Also, since the output follows the syntax of interfaces, it
can help in writing an explicit interface (.mli file) for a file: just
redirect the standard output of the compiler to a .mli file, and edit
that file to remove all declarations of unexported names.
.TP
.BI \-I \ directory
Add the given directory to the list of directories searched for
compiled interface files (.cmi), compiled object code files
(.cmo), libraries (.cma), and C libraries specified with
.B \-cclib\ \-l
.IR xxx .
By default, the current directory is searched first, then the
standard library directory. Directories added with
.B -I
are searched
after the current directory, in the order in which they were given on
the command line, but before the standard library directory.

If the given directory starts with
.BR + ,
it is taken relative to the
standard library directory. For instance,
.B \-I\ +labltk
adds the subdirectory
.B labltk
of the standard library to the search path.
.TP
.BI \-impl \ filename
Compile the file
.I filename
as an implementation file, even if its extension is not .ml.
.TP
.BI \-intf \ filename
Compile the file
.I filename
as an interface file, even if its extension is not .mli.
.TP
.BI \-intf\-suffix \ string
Recognize file names ending with
.I string
as interface files (instead of the default .mli).
.TP
.B \-labels
Labels are not ignored in types, labels may be used in applications,
and labelled parameters can be given in any order.  This is the default.
.TP
.B \-linkall
Force all modules contained in libraries to be linked in. If this
flag is not given, unreferenced modules are not linked in. When
building a library (option
.BR \-a ),
setting the
.B \-linkall
option forces all subsequent links of programs involving that library
to link all the modules contained in the library.
.TP
.B \-make\-runtime
Build a custom runtime system (in the file specified by option
.BR \-o )
incorporating the C object files and libraries given on the command
line.  This custom runtime system can be used later to execute
bytecode executables produced with the option
.B ocamlc\ \-use\-runtime
.IR runtime-name .
.TP
.B \-noassert
Do not compile assertion checks.  Note that the special form
.B assert\ false
is always compiled because it is typed specially.
This flag has no effect when linking already-compiled files.
.TP
.B \-noautolink
When linking .cma libraries, ignore
.BR \-custom , \ \-cclib \ and \ \-ccopt
options potentially contained in the libraries (if these options were
given when building the libraries).  This can be useful if a library
contains incorrect specifications of C libraries or C options; in this
case, during linking, set
.B \-noautolink
and pass the correct C libraries and options on the command line.
.TP
.B \-nolabels
Ignore non-optional labels in types. Labels cannot be used in
applications, and parameter order becomes strict.
.TP
.BI \-o \ exec\-file
Specify the name of the output file produced by the linker. The
default output name is
.BR a.out ,
in keeping with the Unix tradition. If the
.B \-a
option is given, specify the name of the library
produced.  If the
.B \-pack
option is given, specify the name of the
packed object file produced.  If the
.B \-output\-obj
option is given,
specify the name of the output file produced.
.TP
.B \-output\-obj
Cause the linker to produce a C object file instead of a bytecode
executable file. This is useful to wrap OCaml code as a C library,
callable from any C program. The name of the output object file 
must be set with the
.B \-o
option. This
option can also be used to produce a C source file (.c extension) or
a compiled shared/dynamic library (.so extension).
.TP
.B \-pack
Build a bytecode object file (.cmo file) and its associated compiled
interface (.cmi) that combines the object
files given on the command line, making them appear as sub-modules of
the output .cmo file.  The name of the output .cmo file must be
given with the
.B \-o
option.  For instance,
.B ocamlc\ \-pack\ \-o\ p.cmo\ a.cmo\ b.cmo\ c.cmo
generates compiled files p.cmo and p.cmi describing a compilation
unit having three sub-modules A, B and C, corresponding to the
contents of the object files a.cmo, b.cmo and c.cmo.  These
contents can be referenced as P.A, P.B and P.C in the remainder
of the program.
.TP
.BI \-pp \ command
Cause the compiler to call the given
.I command
as a preprocessor for each source file. The output of
.I command
is redirected to
an intermediate file, which is compiled. If there are no compilation
errors, the intermediate file is deleted afterwards. The name of this
file is built from the basename of the source file with the
extension .ppi for an interface (.mli) file and .ppo for an
implementation (.ml) file.
.TP
.BI \-ppx \ command
Pipe abstract syntax tree through preprocessor
.IR command .
.TP
.B \-principal
Check information path during type-checking, to make sure that all
types are derived in a principal way.  When using labelled arguments
and/or polymorphic methods, this flag is required to ensure future
versions of the compiler will be able to infer types correctly, even
if internal algorithms change.
All programs accepted in
.B \-principal
mode are also accepted in the
default mode with equivalent types, but different binary signatures,
and this may slow down type checking; yet it is a good idea to
use it once before publishing source code.
.TP
.B \-rectypes
Allow arbitrary recursive types during type-checking.  By default,
only recursive types where the recursion goes through an object type
are supported. Note that once you have created an interface using this
flag, you must use it again for all dependencies.
.TP
.BI \-runtime\-variant \ suffix
Add
.I suffix
to the name of the runtime library that will be used by the program.
If OCaml was configured with option
.BR \-with\-debug\-runtime ,
then the
.B d
suffix is supported and gives a debug version of the runtime.
.TP
.B \-strict\-sequence
The left-hand part of a sequence must have type unit.
.TP
.B \-thread
Compile or link multithreaded programs, in combination with the
system "threads" library described in
.IR The\ OCaml\ user's\ manual .
.TP
.B \-unsafe
Turn bound checking off for array and string accesses (the
.BR v.(i) and s.[i]
constructs). Programs compiled with
.B \-unsafe
are therefore
slightly faster, but unsafe: anything can happen if the program
accesses an array or string outside of its bounds.
.TP
.BI \-use\-runtime \ runtime\-name
Generate a bytecode executable file that can be executed on the custom
runtime system
.IR runtime\-name ,
built earlier with
.B ocamlc\ \-make\-runtime
.IR runtime\-name .
.TP
.B \-v
Print the version number of the compiler and the location of the
standard library directory, then exit.
.TP
.B \-verbose
Print all external commands before they are executed, in particular
invocations of the C compiler and linker in
.B \-custom
mode.  Useful to debug C library problems.
.TP
.BR \-vnum \ or\  \-version
Print the version number of the compiler in short form (e.g. "3.11.0"),
then exit.
.TP
.B \-vmthread
Compile or link multithreaded programs, in combination with the
VM-level threads library described in
.IR The\ OCaml\ user's\ manual .
.TP
.BI \-w \ warning\-list
Enable, disable, or mark as errors the warnings specified by the argument
.IR warning\-list .

Each warning can be
.IR enabled \ or\  disabled ,
and each warning can be
.I marked
(as error) or
.IR unmarked .
If a warning is disabled, it isn't displayed and doesn't affect
compilation in any way (even if it is marked).  If a warning is enabled,
it is displayed normally by the compiler whenever the source code
triggers it.  If it is enabled and marked, the compiler will stop with
an error after displaying the warnings if the source code triggers it.

The
.I warning\-list
argument is a sequence of warning specifiers, with no separators
between them.  A warning specifier is one of the following:

.BI + num
\ \ Enable warning number
.IR num .

.BI \- num
\ \ Disable warning number
.IR num .

.BI @ num
\ \ Enable and mark warning number
.IR num .

.BI + num1 .. num2
\ \ Enable all warnings between
.I num1
and
.I num2
(inclusive).

.BI \- num1 .. num2
\ \ Disable all warnings between
.I num1
and
.I num2
(inclusive).

.BI @ num1 .. num2
\ \ Enable and mark all warnings between
.I num1
and
.I num2
(inclusive).

.BI + letter
\ \ Enable the set of warnings corresponding to
.IR letter .
The letter may be uppercase or lowercase.

.BI \- letter
\ \ Disable the set of warnings corresponding to
.IR letter .
The letter may be uppercase or lowercase.

.BI @ letter
\ \ Enable and mark the set of warnings corresponding to
.IR letter .
The letter may be uppercase or lowercase.

.I uppercase\-letter
\ \ Enable the set of warnings corresponding to
.IR uppercase\-letter .

.I lowercase\-letter
\ \ Disable the set of warnings corresponding to
.IR lowercase\-letter .

The warning numbers are as follows.

1
\ \ \ Suspicious-looking start-of-comment mark.

2
\ \ \ Suspicious-looking end-of-comment mark.

3
\ \ \ Deprecated syntax.

4
\ \ \ Fragile pattern matching: matching that will remain
complete even if additional constructors are added to one of the
variant types matched.

5
\ \ \ Partially applied function: expression whose result has
function type and is ignored.

6
\ \ \ Label omitted in function application.

7
\ \ \ Method overridden without using the "method!" keyword

8
\ \ \ Partial match: missing cases in pattern-matching.

9
\ \ \ Missing fields in a record pattern.

10
\ \ Expression on the left-hand side of a sequence that doesn't
have type
.B unit
(and that is not a function, see warning number 5).

11
\ \ Redundant case in a pattern matching (unused match case).

12
\ \ Redundant sub-pattern in a pattern-matching.

13
\ \ Override of an instance variable.

14
\ \ Illegal backslash escape in a string constant.

15
\ \ Private method made public implicitly.

16
\ \ Unerasable optional argument.

17
\ \ Undeclared virtual method.

18
\ \ Non-principal type.

19
\ \ Type without principality.

20
\ \ Unused function argument.

21
\ \ Non-returning statement.

22
\ \ Camlp4 warning.

23
\ \ Useless record
.B with
clause.

24
\ \ Bad module name: the source file name is not a valid OCaml module name.

25
\ \ Pattern-matching with all clauses guarded.

26
\ \ Suspicious unused variable: unused variable that is bound with
.BR let \ or \ as ,
and doesn't start with an underscore (_) character.

27
\ \ Innocuous unused variable: unused variable that is not bound with
.BR let \ nor \ as ,
and doesn't start with an underscore (_) character.

28
\ \ A pattern contains a constant constructor applied to the underscore (_)
pattern.

29
\ \ A non-escaped end-of-line was found in a string constant.  This may
cause portability problems between Unix and Windows.

The letters stand for the following sets of warnings.  Any letter not
mentioned here corresponds to the empty set.

.B A
\ all warnings

.B C
\ 1, 2

.B D
\ 3

.B E
\ 4

.B F
\ 5

.B K
\ 32, 33, 34, 35, 36, 37, 38, 39, 40

.B L
\ 6

.B M
\ 7

.B P
\ 8

.B R
\ 9

.B S
\ 10

.B U
\ 11, 12

.B V
\ 13

.B X
\ 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 30

.B Y
\ 26

.B Z
\ 27

.IP
The default setting is
.BR \-w\ +a\-4\-6\-9\-27\-29\-32..40 .
Note that warnings
.BR 5 \ and \ 10
are not always triggered, depending on the internals of the type checker.
.TP
.BI \-warn\-error \ warning\-list
Mark as errors the warnings specified in the argument
.IR warning\-list .
The compiler will stop with an error when one of these
warnings is emitted.  The
.I warning\-list
has the same meaning as for
the
.B \-w
option: a
.B +
sign (or an uppercase letter) turns the corresponding warnings into errors, a
.B \-
sign (or a lowercase letter) turns them back into warnings, and a
.B @
sign both enables and marks the corresponding warnings.

Note: it is not recommended to use the
.B \-warn\-error
option in production code, because it will almost certainly prevent
compiling your program with later versions of OCaml when they add new
warnings.

The default setting is
.B \-warn\-error\ -a
(none of the warnings is treated as an error).
.TP
.B \-where
Print the location of the standard library, then exit.
.TP
.BI \- \ file
Process
.I file
as a file name, even if it starts with a dash (-) character.
.TP
.BR \-help \ or \ \-\-help
Display a short usage summary and exit.

.SH SEE ALSO
.BR ocamlopt (1), \ ocamlrun (1), \ ocaml (1).
.br
.IR "The OCaml user's manual" ,
chapter "Batch compilation".
