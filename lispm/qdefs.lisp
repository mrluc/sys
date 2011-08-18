; -*-LISP-*-

;	** (c) Copyright 1980 Massachusetts Institute of Technology **

;ELEMENTS IN Q-CORRESPONDING-VARIABLE-LIST ARE SYMBOLS WHOSE VALUES IN MACLISP ARE LISTS
;  ALL OF WHOSE MEMBERS ARE SYSTEM CONTANTS.  THESE SYSTEM CONSTANTS HAVE MACLISP VALUES
;  AND ARE MADE TO HAVE THE IDENTICAL VALUES IN LISP MACHINE LISP.
(SETQ Q-CORRESPONDING-VARIABLE-LISTS '(AREA-LIST Q-CDR-CODES Q-DATA-TYPES Q-HEADER-TYPES
   Q-LISP-CONSTANTS
   ;RTB-RTB-BITS RTB-RTS-BITS RTB-RTO-OPS 
   ;RTB-MISC RTM-OPS READTABLE-%%-BITS 
   ARRAY-TYPES HEADER-TYPES HEADER-FIELDS MISC-Q-VARIABLES 
   ARG-DESC-FIELDS NUMERIC-ARG-DESC-FIELDS FEF-NAME-PRESENT FEF-SPECIALNESS
   FEF-ARG-SYNTAX FEF-INIT-OPTION FEFHI-FIELDS FEF-DES-DT FEF-QUOTE-STATUS 
   FEF-FUNCTIONAL 
   ARRAY-FIELDS ARRAY-LEADER-FIELDS ARRAY-MISCS Q-REGION-BITS
   SYSTEM-CONSTANT-LISTS SYSTEM-VARIABLE-LISTS
   SCRATCH-PAD-VARIABLES FASL-GROUP-FIELDS FASL-OPS 
   FASL-TABLE-PARAMETERS FASL-CONSTANTS FASL-CONSTANT-LISTS FEFH-CONSTANTS 
   FEFHI-INDEXES  
   STACK-GROUP-HEAD-LEADER-QS SG-STATES SPECIAL-PDL-LEADER-QS REG-PDL-LEADER-QS 
   SG-STATE-FIELDS SG-INST-DISPATCHES
   SYSTEM-COMMUNICATION-AREA-QS PAGE-HASH-TABLE-FIELDS 
   Q-FIELDS MICRO-STACK-FIELDS M-FLAGS-FIELDS M-ERROR-SUBSTATUS-FIELDS 
   LINEAR-PDL-FIELDS LINEAR-PDL-QS HARDWARE-MEMORY-SIZES 
   DISK-RQ-LEADER-QS DISK-RQ-HWDS DISK-HARDWARE-SYMBOLS UNIBUS-CHANNEL-QS
   CHAOS-BUFFER-LEADER-QS CHAOS-HARDWARE-SYMBOLS INSTANCE-DESCRIPTOR-OFFSETS
   ADI-KINDS ADI-STORING-OPTIONS ADI-FIELDS))

;ELEMENTS IN SYSTEM-CONSTANT-LISTS ARE SYMBOLS WHOSE MACLISP AND LISP MACHINE
;VALUES ARE LISTS OF SYMBOLS WHICH SHOULD GET SYSTEM-CONSTANT PROPERTY FOR THE COMPILER.
;NORMALLY SHOULD BE VERY CLOSE TO Q-CORRESPONDING-VARIABLES-LISTS
(SETQ SYSTEM-CONSTANT-LISTS '(AREA-LIST Q-CDR-CODES Q-DATA-TYPES Q-HEADER-TYPES
   Q-LISP-CONSTANTS
   ;RTB-RTB-BITS RTB-RTS-BITS RTB-RTO-OPS
   ;RTB-MISC RTM-OPS READTABLE-%%-BITS
   ARRAY-TYPES HEADER-FIELDS ;NOT HEADER-TYPES
   ARG-DESC-FIELDS NUMERIC-ARG-DESC-FIELDS FEF-NAME-PRESENT FEF-SPECIALNESS
   FEF-ARG-SYNTAX FEF-INIT-OPTION FEFHI-FIELDS FEF-DES-DT FEF-QUOTE-STATUS 
   FEF-FUNCTIONAL 
   ARRAY-FIELDS ARRAY-LEADER-FIELDS Q-REGION-BITS
   ARRAY-MISCS ;ARRAY-MISCS SHOULD BE FLUSHED SOMEDAY
   SYSTEM-CONSTANT-LISTS SYSTEM-VARIABLE-LISTS ;SOME THINGS LOOK AT SUBLISTS OF THESE
   ;NOT SCRATCH-PAD-VARIABLES
   ;NOT SCRATCH-PAD-POINTERS SCRATCH-PAD-PARAMETERS SCRATCH-PAD-TEMPS 
   FASL-GROUP-FIELDS FASL-OPS
   FASL-TABLE-PARAMETERS FASL-CONSTANTS FASL-CONSTANT-LISTS FEFH-CONSTANTS
   FEFHI-INDEXES 
   STACK-GROUP-HEAD-LEADER-QS SG-STATES SPECIAL-PDL-LEADER-QS REG-PDL-LEADER-QS 
   SG-STATE-FIELDS SG-INST-DISPATCHES
   SYSTEM-COMMUNICATION-AREA-QS PAGE-HASH-TABLE-FIELDS
   Q-FIELDS MICRO-STACK-FIELDS M-FLAGS-FIELDS M-ERROR-SUBSTATUS-FIELDS 
   LINEAR-PDL-FIELDS LINEAR-PDL-QS HARDWARE-MEMORY-SIZES 
   DISK-RQ-LEADER-QS DISK-RQ-HWDS DISK-HARDWARE-SYMBOLS UNIBUS-CHANNEL-QS
   CHAOS-BUFFER-LEADER-QS CHAOS-HARDWARE-SYMBOLS INSTANCE-DESCRIPTOR-OFFSETS
   ADI-KINDS ADI-STORING-OPTIONS ADI-FIELDS))

;LIKE ABOVE BUT GET DECLARED SPECIAL RATHER THAN SYSTEM-CONSTANT
(SETQ SYSTEM-VARIABLE-LISTS '(
	A-MEMORY-LOCATION-NAMES M-MEMORY-LOCATION-NAMES 
	TV-VARIABLES IO-STREAM-NAMES LISP-VARIABLES MISC-Q-VARIABLES
))

(SETQ TV-VARIABLES '( 
	TV-BLINKER-LIST TV-ROVING-BLINKER-LIST TV-PC-PPR-LIST TV-FONT-LIST
	TV-CONTROL-REGISTER-ADDR TV-CONTROL-REGISTER-2-ADDR
	TV-CONTROL-REGISTER-PLANE-SELECT TV-CONTROL-REGISTER-WHITE-ON-BLACK
	TV-CONTROL-REGISTER-VIDEO-SWITCH TV-LOGICAL-PLANE-NUM
	TV-BUFFER TV-BUFFER-PIXELS TV-BUFFER-WORDS TV-DEFAULT-SCREEN
	TV-ALU-IOR TV-ALU-XOR TV-ALU-ANDCA TV-ALU-SETA
	TV-BEEP-DURATION TV-BEEP-WAVELENGTH TV-BEEP
	TV-MORE-PROCESSING-GLOBAL-ENABLE TV-ALL-PLANES-MASK 
	TV-SCREEN-HEIGHT TV-SCREEN-WIDTH TV-ROVING-BLINKER-LIST TV-PC-PPR
))

(SETQ IO-STREAM-NAMES '(
	STANDARD-INPUT STANDARD-OUTPUT ERROR-OUTPUT QUERY-IO TERMINAL-IO TRACE-OUTPUT
))

;These get declared special, and get their Maclisp values shipped over
(SETQ MISC-Q-VARIABLES '(SYSTEM-CONSTANT-LISTS SYSTEM-VARIABLE-LISTS
			 PRIN1 FOR-CADR COLD-INITIALIZATION-LIST WARM-INITIALIZATION-LIST
                         ONCE-ONLY-INITIALIZATION-LIST SYSTEM-INITIALIZATION-LIST))

;These get declared special, but don't get sent over.  They get initialized
; some other way, e.g. from a load-time-setq in some compile list, or from special
; code in COLD, or by LISP-REINITIALIZE when the machine is first started.
(SETQ LISP-VARIABLES '(BASE IBASE PRINLENGTH PRINLEVEL *NOPOINT *RSET FASLOAD DEFUN
		       EVALHOOK PACKAGE READTABLE + - * ;*INITIAL-OBARRAY OBARRAY
		       USER-ID LISP-CRASH-LIST SCHEDULER-STACK-GROUP
		       RUBOUT-HANDLER LOCAL-DECLARATIONS STREAM-INPUT-OPERATIONS
		       STREAM-OUTPUT-OPERATIONS %INITIALLY-DISABLE-TRAPPING))

;These get declared SYSTEM-CONSTANT (which is similar to SPECIAL) and get their
; Maclisp values shipped over.
(SETQ Q-LISP-CONSTANTS '(PAGE-SIZE SIZE-OF-OB-TBL SIZE-OF-PAGE-TABLE AREA-LIST Q-DATA-TYPES
			  SIZE-OF-AREA-ARRAYS LENGTH-OF-ATOM-HEAD 
			  ARRAY-ELEMENTS-PER-Q ARRAY-BITS-PER-ELEMENT %FEF-HEADER-LENGTH
			  LAMBDA-LIST-KEYWORDS %LP-CALL-BLOCK-LENGTH 
			  %LP-INITIAL-LOCAL-BLOCK-OFFSET
                          A-MEMORY-VIRTUAL-ADDRESS IO-SPACE-VIRTUAL-ADDRESS
                          UNIBUS-VIRTUAL-ADDRESS A-MEMORY-COUNTER-BLOCK-NAMES))

(SETQ HARDWARE-MEMORY-SIZES '(
	SIZE-OF-HARDWARE-CONTROL-MEMORY SIZE-OF-HARDWARE-DISPATCH-MEMORY 
	SIZE-OF-HARDWARE-A-MEMORY SIZE-OF-HARDWARE-M-MEMORY 
	SIZE-OF-HARDWARE-PDL-BUFFER SIZE-OF-HARDWARE-MICRO-STACK 
	SIZE-OF-HARDWARE-LEVEL-1-MAP SIZE-OF-HARDWARE-LEVEL-2-MAP 
	SIZE-OF-HARDWARE-UNIBUS-MAP ))

(SETQ LAMBDA-LIST-KEYWORDS '(&OPTIONAL &REST &AUX
			     &SPECIAL &LOCAL
			     &FUNCTIONAL
			     &EVAL &QUOTE &QUOTE-DONTCARE 
			     &DT-DONTCARE &DT-NUMBER &DT-FIXNUM &DT-SYMBOL &DT-ATOM 
			     &DT-LIST &DT-FRAME
			     &FUNCTION-CELL))

;Don't put FUNCTION around the symbols in here -- that means if you
;redefine the function the microcode does not get the new definition,
;which is not what you normally want.  Saying FUNCTION makes it a couple
;microseconds faster to call it.  Not all of these data are actually
;used; check the microcode if you want to know.
(SETQ SUPPORT-VECTOR-CONTENTS '((QUOTE PRINT) (QUOTE FEXPR) (QUOTE EXPR) 
				(QUOTE APPLY-LAMBDA) (QUOTE EQUAL) (QUOTE PACKAGE)
				(QUOTE EXPT-HARD)))

(SETQ CONSTANTS-PAGE '(NIL T 0 1 2))		;CONTENTS OF CONSTANTS PAGE

(SETQ SCRATCH-PAD-VARIABLES '(SCRATCH-PAD-POINTERS SCRATCH-PAD-PARAMETER-OFFSET 
  SCRATCH-PAD-PARAMETERS SCRATCH-PAD-TEMP-OFFSET SCRATCH-PAD-TEMPS))

(SETQ SCRATCH-PAD-POINTERS '(INITIAL-TOP-LEVEL-FUNCTION ERROR-HANDLER-STACK-GROUP 
	CURRENT-STACK-GROUP INITIAL-STACK-GROUP	LAST-ARRAY-ELEMENT-ACCESSED))

(SETQ SCRATCH-PAD-PARAMETER-OFFSET 20)

(COND ((> (LENGTH SCRATCH-PAD-POINTERS) SCRATCH-PAD-PARAMETER-OFFSET) 
	(BARF 'BARF 'SCRACH-PAD-PARAMETER-OFFSET 'BARF)))

(SETQ SCRATCH-PAD-PARAMETERS '(ERROR-TRAP-IN-PROGRESS DEFAULT-CONS-AREA 
	BIND-CONS-AREA LAST-ARRAY-ACCESSED-TYPE LAST-ARRAY-ACCESSED-INDEX 
	INVOKE-MODE INVISIBLE-MODE 
	CDR-ATOM-MODE CAR-ATOM-MODE ACTIVE-MICRO-CODE-ENTRIES))

(SETQ SCRATCH-PAD-TEMP-OFFSET 20)

(COND ((> (LENGTH SCRATCH-PAD-PARAMETERS) SCRATCH-PAD-TEMP-OFFSET)
	(BARF 'BARF 'SCRATCH-PAD-TEMP-OFFSET 'BARF)))

(SETQ SCRATCH-PAD-TEMPS '(LAST-INSTRUCTION TEMP-TRAP-CODE LOCAL-BLOCK-OFFSET 
	SCRATCH-/#-ARGS-LOADED TEMP-PC SPECIALS-IN-LAST-BLOCK-SLOW-ENTERED))


(DEFUN TTYPRINT (X)
  (PROG (^R ^W)
	(PRINT X)))

;FUNCTIONS FOR HAND-TESTING THINGS
;(DEFUN TML NIL (MSLAP 'MESA-CODE-AREA MS-PROG 'COLD))

(DEFUN TUL NIL (ULAP 'MICRO-COMPILED-PROGRAM MC-PROG 'COLD))

(DEFUN TL (MODE) (COND ((EQ MODE 'QFASL)
			(FASD-INITIALIZE)
			(SETQ LAP-DEBUG NIL)))
		 (QLAPP QCMP-OUTPUT MODE))

#M (COND ((NULL (GETL 'SPECIAL '(FEXPR FSUBR)))
(DEFUN SPECIAL FEXPR (L) 
       (MAPCAR (FUNCTION (LAMBDA (X) (PUTPROP X T 'SPECIAL)))
	       L))
))

(DEFUN SPECIAL-LIST (X) (EVAL (CONS 'SPECIAL (SYMEVAL X))))

;; No initial initializations
(SETQ COLD-INITIALIZATION-LIST NIL  WARM-INITIALIZATION-LIST NIL
      ONCE-ONLY-INITIALIZATION-LIST NIL SYSTEM-INITIALIZATION-LIST NIL)

;--Q--
;Q FCTN SPECIALS
(DEFUN LOADUP-FINALIZE NIL
   (MAPC (FUNCTION SPECIAL-LIST) SYSTEM-CONSTANT-LISTS)
   (MAPC (FUNCTION SPECIAL-LIST) SYSTEM-VARIABLE-LISTS))

;;; The documentation that used to be here has been moved to LMDOC;FASLD >

(SPECIAL FASL-TABLE FASL-GROUP-LENGTH FASL-GROUP-FLAG FASL-RETURN-FLAG)

(SETQ FASL-GROUP-FIELD-VALUES '(%FASL-GROUP-CHECK 100000 
   %FASL-GROUP-FLAG 40000 %FASL-GROUP-LENGTH 37700 
   FASL-GROUP-LENGTH-SHIFT -6 %FASL-GROUP-TYPE 77 
  %%FASL-GROUP-CHECK 2001 %%FASL-GROUP-FLAG 1701 %%FASL-GROUP-LENGTH 0610 
  %%FASL-GROUP-TYPE 0006))

(SETQ FASL-GROUP-FIELDS (GET-ALTERNATE FASL-GROUP-FIELD-VALUES))
(ASSIGN-ALTERNATE FASL-GROUP-FIELD-VALUES)

(SETQ FASL-OPS '(FASL-OP-ERR FASL-OP-NOOP FASL-OP-INDEX FASL-OP-SYMBOL FASL-OP-LIST 
  FASL-OP-TEMP-LIST FASL-OP-FIXED FASL-OP-FLOAT 
  FASL-OP-ARRAY FASL-OP-EVAL FASL-OP-MOVE 
  FASL-OP-FRAME FASL-OP-UNUSED7 FASL-OP-ARRAY-PUSH FASL-OP-STOREIN-SYMBOL-VALUE 
  FASL-OP-STOREIN-FUNCTION-CELL FASL-OP-STOREIN-PROPERTY-CELL 
  FASL-OP-FETCH-SYMBOL-VALUE FASL-OP-FETCH-FUNCTION-CELL 
  FASL-OP-FETCH-PROPERTY-CELL FASL-OP-APPLY FASL-OP-END-OF-WHACK 
  FASL-OP-END-OF-FILE FASL-OP-SOAK FASL-OP-FUNCTION-HEADER FASL-OP-FUNCTION-END 
  FASL-OP-MAKE-MICRO-CODE-ENTRY FASL-OP-SAVE-ENTRY-POINT FASL-OP-MICRO-CODE-SYMBOL 
  FASL-OP-MICRO-TO-MICRO-LINK FASL-OP-MISC-ENTRY FASL-OP-QUOTE-POINTER FASL-OP-S-V-CELL 
  FASL-OP-FUNCELL FASL-OP-CONST-PAGE FASL-OP-SET-PARAMETER FASL-OP-INITIALIZE-ARRAY 
  FASL-OP-UNUSED FASL-OP-UNUSED1 FASL-OP-UNUSED2 
  FASL-OP-UNUSED3 FASL-OP-UNUSED4 FASL-OP-UNUSED5  
  FASL-OP-UNUSED6 FASL-OP-STRING FASL-OP-STOREIN-ARRAY-LEADER 
  FASL-OP-INITIALIZE-NUMERIC-ARRAY FASL-OP-REMOTE-VARIABLE FASL-OP-PACKAGE-SYMBOL
  FASL-OP-EVAL1 FASL-OP-FILE-PROPERTY-LIST FASL-OP-REL-FILE
))
(ASSIGN-VALUES FASL-OPS 0)

(SETQ FASL-TABLE-PARAMETERS '(FASL-NIL FASL-EVALED-VALUE FASL-TEM1 FASL-TEM2 FASL-TEM3 
    FASL-SYMBOL-HEAD-AREA 
    FASL-SYMBOL-STRING-AREA FASL-OBARRAY-POINTER FASL-ARRAY-AREA 
    FASL-FRAME-AREA FASL-LIST-AREA FASL-TEMP-LIST-AREA 
    FASL-UNUSED FASL-UNUSED2 FASL-UNUSED3 
    FASL-MICRO-CODE-EXIT-AREA FASL-UNUSED4 FASL-UNUSED5))
(ASSIGN-VALUES FASL-TABLE-PARAMETERS 0)

(SETQ FASL-CONSTANTS '(LENGTH-OF-FASL-TABLE FASL-TABLE-WORKING-OFFSET))

(SETQ FASL-CONSTANT-LISTS '(FASL-GROUP-FIELDS FASL-OPS FASL-TABLE-PARAMETERS 
    FASL-CONSTANTS))

(SETQ FASL-TABLE-WORKING-OFFSET 40)

(COND ((> (LENGTH FASL-TABLE-PARAMETERS) FASL-TABLE-WORKING-OFFSET)
	(IOC V)
	(PRINT 'FASL-TABLE-PARAMETER-OVERFLOW)))

;PEOPLE CALL THIS YOU KNOW, DON'T GO RANDOMLY DELETING IT!
(DEFUN FASL-ASSIGN-VARIABLE-VALUES NIL 
 ())  ;I GUESS WHAT THIS USED TO DO IS DONE AT TOP LEVEL IN THIS FILE
