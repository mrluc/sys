;; New error handler routines.		DLW 1/6/78 -*-Mode:LISP; Package:EH-*-

;;;; Conventions for the error handler routines:  how to add new ones.

;; Each microcode error has associated with it a call to the ERROR-TABLE "pseudo-op"
;; of CONSLP.  The form in CONSLP looks like:
;;    (ERROR-TABLE ARGTYP FIXNUM M-T 0)
;; (for example).  The CDR of this list is the ETE.  So, the FIRST element
;; is the name of the error, and the SECOND is the first "argument" to that
;; error's associated routines.
;;
;; A Lisp routine calling the error handler can make up any ETE it wants.
;;
;; All ETEs should be a list whose car is a symbol.  That symbol
;; must have an INFORM property, and may optionally have other
;; properties.  The INFORM property should be a function which can 
;; be applied to the SG and the ETE, and print out an error message.
;;
;; The only other property defined is PROCEED, which is used to proceed
;; after getting the error (i.e. the c-C command of the error handler).
;; It too should be a function to be applied to the SG and ETE,
;; and what it should do is to fix up the SAVED stack group state
;; appropriately, and return; the stack group will be started up in
;; SG-RESUMABLE state.
;;
;; Things that have PROCEED or BASH-AND-PROCEED properties should also have
;; HELP-MESSAGE properties to tell the user about the extra commands made
;; available (C and/or C).  This property is either a string or a function
;; of SG and ETE.
;;
;; Look at a few of these to get the idea of what they should look like.
;;
;; For errors signalled by macrocode (not microcode), the ETE looks like
;;	(CERROR proceedable-flag restartable-flag condition format-string . args)


;; This is like SG-CONTENTS, but always returns a fixnum with the
;; pointer part of the contents.  Useful if contents might be a small
;; untyped integer.
;; As a special kludge, if the tag is a number, the result is simply that
;; number.  The ARRAY-NUMBER-DIMENSIONS error, for example, is one.
(DEFUN SG-FIXNUM-CONTENTS (SG LOC)
  (COND ((NUMBERP LOC) LOC)			;Constant
	((EQ LOC 'M-1) (DPB (LDB 1010 (SG-VMA-M1-M2-TAGS SG)) 3010 (SG-AC-1 SG)))
	((EQ LOC 'M-2) (DPB (LDB 2010 (SG-VMA-M1-M2-TAGS SG)) 3010 (SG-AC-2 SG)))
	(T (%P-LDB %%Q-POINTER (SG-LOCATE SG LOC)))))

(DEFUN SG-FIXNUM-STORE (X SG LOC)
  (%P-DPB X %%Q-POINTER (SG-LOCATE SG LOC)))

;;;; This class can happen from within the compilations of Lisp functions.
;;;; They are the kind for which ERRING-FUNCTION is useful.

;; ARGTYP.
;; First arg is what it should have been (or a list of such).
;; Second arg is where offender is.
;; Third arg is which argument is was (zero based) (T = one and only, NIL = ?)
;; Fourth arg (optional) is RESTART address.  If it is NIL or missing,
;; then there is no way to recover.
;; Fifth arg (optional) is name of sub-function (typically CAR or CDR)
;; to which the value was an argument.  Just to make error messages nicer.

(DEFUN (ARGTYP INFORM) (SG ETE &AUX FCN)
  (LET ((ARGNUM (FOURTH ETE)))
    (FORMAT T "~:[Some~*~*~;The~:[ ~:R~;~*~]~] argument to ~S, "
	    ARGNUM (EQ ARGNUM T) (AND (NUMBERP ARGNUM) (1+ ARGNUM))
	    (SETQ FCN (OR (SIXTH ETE) (SG-ERRING-FUNCTION SG)))))
  (P-PRIN1-CAREFUL (SG-LOCATE SG (THIRD ETE)))
  (FORMAT T (IF (ARRAYP FCN) ", was an invalid array subscript.~%Use "      
		", was of the wrong type.~%The function expected "))
  (LET ((TYPE (SECOND ETE)))
    (COND ((SYMBOLP TYPE)
	   (PRINC-TYPE-NAME TYPE))
	  ((LISTP TYPE)
	   (IF (< (LENGTH TYPE) 2)
	       (PRINC-TYPE-NAME (CAR TYPE))
	       (DO TL TYPE (CDR TL) (NULL TL)
		   (PRINC-TYPE-NAME (CAR TL))
		   (PRINC (COND ((NULL (CDR TL)) "")
				((NULL (CDDR TL)) " or ")
				(T ", "))))))
	  (T (BAD-HACKER TYPE " is not a type."))))
  (FORMAT T ".~%"))

(DEFUN PRINC-TYPE-NAME (TYPE)
  (PRINC (OR (CADR (ASSQ TYPE DATA-TYPE-NAMES)) TYPE)))

(DEFVAR DATA-TYPE-NAMES
      '((FIXNUM "a fixnum")
	(NUMBER "a number")
	(BIGNUM "a bignum")
	(INTEGER "a fixnum or a bignum")
	(POSITIVE-FIXNUM "a fixnum  zero")
	(FIXNUM-GREATER-THAN-1 "a fixnum > 1")
	(PLUSP "a number > zero")
	(SYMBOL "a symbol")
	(CONS "a cons")
	(LIST "a list")
	(NIL "the symbol NIL")
	(NON-NIL "something other than NIL")
	(LOCATIVE "a locative")
	(CLOSURE "a closure")
	(INSTANCE "an instance")
	(STACK-GROUP "a stack group")
	(ARRAY "an array")
	(ART-Q-LIST-ARRAY "an ART-Q-LIST array")
	(Q-ARRAY "an array of Lisp objects")
	(BYTE-ARRAY "an array of numbers")
	(ART-4B-ARRAY "an array of 4-bit bytes")
	(NON-DISPLACED-ARRAY "a non-displaced array")
	(ART-Q-ARRAY "an array of type ART-Q")
	(NUMERIC-ARRAY "an array of numeric type")
	(REASONABLE-SIZE-ARRAY "an array of reasonable size")
	(AREA "an area number, NIL (default), or a symbol whose value is one")
	(FIXNUM-FIELD "a byte pointer to a field that fits in a fixnum")))

(DEFUN (ARGTYP SIGNAL) (SG ETE)
  `(:WRONG-TYPE-ARGUMENT ,(SECOND ETE) ,(SG-CONTENTS SG (THIRD ETE))))

(DEFUN (ARGTYP PROCEED) (SG ETE)
  (COND ((NULL (FIFTH ETE))
	 (FORMAT T "You cannot recover from this error.~%")
	 (*THROW 'QUIT NIL)))
  (SG-STORE (READ-OBJECT "Form to evaluate and use as replacement argument:")
	    SG (THIRD ETE))
  (SG-PROCEED-MICRO-PC SG (FIFTH ETE)))

(DEFUN (ARGTYP HELP-MESSAGE) (IGNORE ETE)
  (AND (FIFTH ETE)
       (FORMAT T "C asks for a replacement argument and continues.")))

;; This routine should be called by the PROCEED routines for
;; microcode (non-FERROR) errors.  A restart micro pc is pushed onto
;; the saved micro-stack.  If TAG is NIL, this is the trap pc plus one,
;; continuing from the point of the trap.  Else look up the numerical
;; value of TAG, set by the RESTART-PC pseudo-op in the microcode.
;; If an PROCEED routine doesn't call SG-PROCEED-MICRO-PC, then
;; control will be returned from the micro-routine that got the error.
(DEFUN SG-PROCEED-MICRO-PC (SG TAG)
  (LET ((PC (IF TAG (CDR (ASSQ TAG RESTART-LIST)) (1+ (SG-TRAP-MICRO-PC SG)))))
    (COND ((NULL PC)
	   (BAD-HACKER TAG " no such restart!")
	   (*THROW 'QUIT NIL)))
    ;; Since the micro stack is saved backwards, the top of the stack is buried
    ;; where it is hard to get at.
    (LET ((RP (SG-REGULAR-PDL SG))
	  (SP (SG-SPECIAL-PDL SG))
	  (SPP (SG-SPECIAL-PDL-POINTER SG))
	  (FRAME (SG-AP SG)))
      (OR (ZEROP (RP-MICRO-STACK-SAVED RP FRAME))	;Shuffle up stack to make room
	  (DO ((FLAG 0)) ((NOT (ZEROP FLAG)))
	    (ASET (AREF SP SPP) SP (1+ SPP))
	    (%P-STORE-FLAG-BIT (ALOC SP (1+ SPP)) 0)
	    (SETQ FLAG (%P-FLAG-BIT (ALOC SP SPP)))
	    (SETQ SPP (1- SPP))))
      (ASET PC SP (SETQ SPP (1+ SPP)))
      (%P-STORE-FLAG-BIT (ALOC SP SPP) 1)
      (SETF (SG-SPECIAL-PDL-POINTER SG) (1+ (SG-SPECIAL-PDL-POINTER SG)))
      (SETF (RP-MICRO-STACK-SAVED RP FRAME) 1))))

;; FIXNUM-OVERFLOW
;; First arg is M-T to show that that is where the value should
;;   get stored.  Maybe it will someday be other things, too.
;; Second is either PUSH or NOPUSH.
;; Recover by storing a new value in the place where the
;;   value would have been stored if it hadn't overflowed.
;;   This is M-T, and also the regpdl if the second arg is PUSH.
;;   Force return from the microroutine executing at the time.

(DEFUN (FIXNUM-OVERFLOW INFORM) (SG IGNORE)
  (FORMAT T "~S got a fixnum overflow.~%" (SG-ERRING-FUNCTION SG)))

(DEFUN (FIXNUM-OVERFLOW PROCEED) (SG ETE &AUX NUM)
  (OR (MEMQ (THIRD ETE) '(PUSH NOPUSH))
      (BAD-HACKER ETE "Bad ETE, must be PUSH or NOPUSH."))
  (SETQ NUM (READ-OBJECT "Fixnum to return instead:"))
  (CHECK-ARG NUM FIXP "a fixnum")
  (SG-FIXNUM-STORE NUM SG (SECOND ETE))
  (AND (EQ (THIRD ETE) 'PUSH)
       (SG-REGPDL-PUSH SG NUM)))

(DEFPROP FIXNUM-OVERFLOW "C asks for a fixnum to use as the result." HELP-MESSAGE)
(DEFPROP FIXNUM-OVERFLOW :FIXNUM-OVERFLOW CONDITION)
(DEFPROP FIXNUM-OVERFLOW SIGNAL-WITH-CONTENTS SIGNAL)

;; FLOATING-EXPONENT-UNDERFLOW
;; Arg is SFL or FLO

(DEFUN (FLOATING-EXPONENT-UNDERFLOW INFORM) (SG ETE)
  (FORMAT T "~S produced a result too small in magnitude to be
representable as a ~:[~;small~] flonum.~%"
	  (SG-ERRING-FUNCTION SG)
	  (EQ (SECOND ETE) 'SFL)))

(DEFPROP FLOATING-EXPONENT-UNDERFLOW :FLOATING-EXPONENT-UNDERFLOW CONDITION)
(DEFPROP FLOATING-EXPONENT-UNDERFLOW FLOATING-EXPONENT-UNDERFLOW-SIGNAL SIGNAL)
(DEFUN FLOATING-EXPONENT-UNDERFLOW-SIGNAL (IGNORE ETE)
  (LIST (GET (CAR ETE) 'CONDITION)))

(DEFUN (FLOATING-EXPONENT-UNDERFLOW PROCEED) (SG ETE)
  (OR (FQUERY '(:LIST-CHOICES NIL :FRESH-LINE NIL)
	      "Proceed using 0.0~:[s0~] as the value instead? "
	      (EQ (SECOND ETE) 'FLO))
      (*THROW 'QUIT NIL))
  (SG-PROCEED-MICRO-PC SG NIL))

(DEFPROP FLOATING-EXPONENT-UNDERFLOW "C proceeds using 0.0 as the result." HELP-MESSAGE)

;; FLOATING-EXPONENT-OVERFLOW
;; Result is to be placed in M-T and pushed on the pdl.
;; Arg is SFL or FLO
;; In the case of SFL the pdl has already been pushed.

(DEFUN (FLOATING-EXPONENT-OVERFLOW INFORM) (SG ETE)
  (FORMAT T "~S produced a result too large in magnitude to be
representable as a ~:[~;small~] flonum.~%"
	  (SG-ERRING-FUNCTION SG)
	  (EQ (SECOND ETE) 'SFL)))

(DEFPROP FLOATING-EXPONENT-OVERFLOW :FLOATING-EXPONENT-OVERFLOW CONDITION)
(DEFPROP FLOATING-EXPONENT-OVERFLOW FLOATING-EXPONENT-UNDERFLOW-SIGNAL SIGNAL)

(DEFUN (FLOATING-EXPONENT-OVERFLOW PROCEED) (SG ETE &AUX NUM)
  (DO () (())
    (SETQ NUM (READ-OBJECT (IF (EQ (SECOND ETE) 'SFL) "Small-flonum to return instead:"
						      "Flonum to return instead:")))
    (COND ((AND (EQ (SECOND ETE) 'SFL)
		(SMALL-FLOATP NUM))
	   (RETURN NIL))
	  ((FLOATP NUM)
	   (RETURN NIL)))
    (FORMAT T "Please use a ~:[~;small~] flonum.~%" (EQ (SECOND ETE) 'SFL)))
  (SG-STORE NUM SG 'M-T)
  (AND (EQ (FIRST ETE) 'FLOATING-EXPONENT-OVERFLOW)
       (EQ (SECOND ETE) 'SFL)
       (SG-REGPDL-POP SG))
  (SG-REGPDL-PUSH NUM SG))

(DEFPROP FLOATING-EXPONENT-OVERFLOW "C asks for a flonum to use as the result." HELP-MESSAGE)

;; DIVIDE-BY-ZERO
;; You cannot recover.

(DEFPROP DIVIDE-BY-ZERO DIVIDE-BY-ZERO-INFORM INFORM)
(DEFUN DIVIDE-BY-ZERO-INFORM (SG IGNORE)
  (FORMAT T "There was an attempt to divide a number by zero in ~S.~%"
	  (SG-ERRING-FUNCTION SG)))

;; ARRAY-NUMBER-DIMENSIONS
;; First arg is how many we gave.
;; Second arg is how many is right.
;; Third arg is the array
;; You cannot recover.

(DEFUN (ARRAY-NUMBER-DIMENSIONS INFORM) (SG ETE)
  ;; Was this array applied or aref'ed?
  (LET ((CURRENT-UPC (SG-TRAP-MICRO-PC SG)))
    (IF (AND ( BEGIN-QARYR CURRENT-UPC) (< CURRENT-UPC END-QARYR))
	(FORMAT T "The ~D-dimensional array ~S was erroneously applied to ~D argument~:P.~%"
		(SG-FIXNUM-CONTENTS SG (SECOND ETE))		
		(SG-CONTENTS SG (FOURTH ETE))
		(SG-FIXNUM-CONTENTS SG (THIRD ETE)))
	(FORMAT T
		"~S was given ~S, a ~S-dimensional array; it expected a ~S-dimensional one.~%"
		(SG-ERRING-FUNCTION SG)
		(SG-CONTENTS SG (FOURTH ETE))
		(SG-FIXNUM-CONTENTS SG (SECOND ETE))
		(SG-FIXNUM-CONTENTS SG (THIRD ETE))))))

;; IALLB-TOO-SMALL
;; First arg is how many we asked for.

(DEFUN (IALLB-TOO-SMALL INFORM) (SG ETE)
  (FORMAT T "There was a request to allocate ~S cells.~%"
	  (SG-FIXNUM-CONTENTS SG (SECOND ETE))))

(DEFUN (CONS-ZERO-SIZE INFORM) (SG IGNORE)
  (FORMAT T "There was an attempt to allocate zero storage by ~S.~%"
	  (SG-ERRING-FUNCTION SG)))

;; NUMBER-ARRAY-NOT-ALLOWED
;; First arg is where to find the array.
;; You cannot recover.

(DEFUN (NUMBER-ARRAY-NOT-ALLOWED INFORM) (SG ETE)
  (FORMAT T "The array ~S, which was given to ~S, is not allowed to be a number array.~%"
	  (SG-CONTENTS SG (SECOND ETE))
	  (SG-ERRING-FUNCTION SG)))

;; SUBSCRIPT-OOB
;; First arg is how many we gave.
;; Second is the legal limit.
;; Third optional arg is a restart tag.

(DEFUN (SUBSCRIPT-OOB INFORM) (SG ETE)
  (LET ((USED (SG-FIXNUM-CONTENTS SG (SECOND ETE)))
	(IN (SG-ERRING-FUNCTION SG)))
    (COND ((< USED 0)
	   (FORMAT T "The subscript, ~S, was negative in ~S~%"
		   USED IN))
	  (T 
	   (FORMAT T "The subscript, ~S, was beyond the length, ~S, in ~S~%"
		   USED
		   (SG-FIXNUM-CONTENTS SG (THIRD ETE))
		   IN)))))

(DEFUN (SUBSCRIPT-OOB PROCEED) (SG ETE &AUX NUM)
  (COND ((NULL (FOURTH ETE))
	 (FORMAT T "You cannot recover from this error.~%")
	 (*THROW 'QUIT NIL)))
  (DO () (())
    (SETQ NUM (READ-OBJECT "Subscript to use instead:"))
    (AND (FIXP NUM) (RETURN))
    (FORMAT T "Please use a fixnum.~%"))
  (SG-FIXNUM-STORE NUM SG (SECOND ETE))
  (SG-PROCEED-MICRO-PC SG (FOURTH ETE)))

(DEFUN (SUBSCRIPT-OOB HELP-MESSAGE) (IGNORE ETE)
  (IF (FOURTH ETE)
      (FORMAT T "C asks for a replacement subscript and proceeds.")))

;; BAD-ARRAY-TYPE
;; First arg is where array header is. Note that it may well have a data type of DTP-TRAP.
;; You cannot recover.

(DEFUN (BAD-ARRAY-TYPE INFORM) (SG ETE)
  (FORMAT T "The array type, ~S, was invalid in ~S.~%"
	  (LDB %%ARRAY-TYPE-FIELD (%P-POINTER (SG-LOCATE SG (SECOND ETE))))
	  (SG-ERRING-FUNCTION SG)))

;; ARRAY-HAS-NO-LEADER
;; Arg is where array pointer is.
;; Recover from this by simply returning something else, by putting it in
;; M-T and discarding the return addr and restarting.

(DEFUN (ARRAY-HAS-NO-LEADER INFORM) (SG ETE)
  (FORMAT T "The array given to ~S, ~S, has no leader.~%"
	  (SG-ERRING-FUNCTION SG)
	  (SG-CONTENTS SG (SECOND ETE))))

(DEFPROP ARRAY-HAS-NO-LEADER :ARRAY-HAS-NO-LEADER CONDITION)
(DEFPROP ARRAY-HAS-NO-LEADER SIGNAL-WITH-CONTENTS SIGNAL)

(DEFUN SIGNAL-WITH-CONTENTS (SG ETE)
  (LIST (GET (CAR ETE) 'CONDITION)
	(SG-CONTENTS SG (SECOND ETE))))

(DEFUN (ARRAY-HAS-NO-LEADER PROCEED) (SG IGNORE)
  (SG-STORE (READ-OBJECT "Form to evaluate and return instead:") SG 'M-T))

(DEFPROP ARRAY-HAS-NO-LEADER "C asks for a value to use as the result and proceeds."
	 HELP-MESSAGE)

;; FILL-POINTER-NOT-FIXNUM
;; Arg is where array pointer is.
;; Recover by returning an arbitrary frob, just flush spurious return addr and restart.

(DEFUN (FILL-POINTER-NOT-FIXNUM INFORM) (SG ETE)
  (FORMAT T "The fill-pointer of the array given to ~S, ~S, is not a fixnum.~%"
	  (SG-ERRING-FUNCTION SG)
	  (SG-CONTENTS SG (SECOND ETE))))

(DEFPROP FILL-POINTER-NOT-FIXNUM :FILL-POINTER-NOT-FIXNUM CONDITION)
(DEFPROP FILL-POINTER-NOT-FIXNUM SIGNAL-WITH-CONTENTS SIGNAL)

(DEFUN (FILL-POINTER-NOT-FIXNUM PROCEED) (SG IGNORE)
  (SG-STORE (READ-OBJECT "Form to evaluate and return instead:") SG 'M-T))

(DEFPROP FILL-POINTER-NOT-FIXNUM "C asks for a value to use as the result and proceeds."
	 HELP-MESSAGE)

;; More random losses.

;arg is number which was called.
(DEFUN (NUMBER-CALLED-AS-FUNCTION INFORM) (SG ETE)
  (FORMAT T "The number, ~S, was called as a function~%"
	  (SG-CONTENTS SG (SECOND ETE))))

(DEFPROP NUMBER-CALLED-AS-FUNCTION :INVALID-FUNCTION CONDITION)
(DEFPROP NUMBER-CALLED-AS-FUNCTION SIGNAL-WITH-CONTENTS SIGNAL)

;; FLONUM-NO-GOOD.  The argument has been lost at this point,
;; so can't use ARGTYP error, and cannot recover.
(DEFUN (FLONUM-NO-GOOD INFORM) (SG IGNORE)
  (FORMAT T "~S does not accept floating-point arguments"
	  (SG-ERRING-FUNCTION SG)))

;; WRONG-SG-STATE
;; Arg is where sg is.
;; You cannot recover.

(DEFUN (WRONG-SG-STATE INFORM) (SG ETE)
  (FORMAT T "The state of the stack group, ~S, given to ~S, was invalid.~%"
	  (SG-CONTENTS SG (SECOND ETE))
	  (SG-ERRING-FUNCTION SG)))

(DEFPROP WRONG-SG-STATE :INVALID-SG-STATE CONDITION)
(DEFPROP WRONG-SG-STATE SIGNAL-WITH-CONTENTS SIGNAL)

;; SG-RETURN-UNSAFE
;; No args, since the frob is in the previous-stack-group of the current one.
;; You cannot recover.

(DEFUN (SG-RETURN-UNSAFE INFORM) (IGNORE IGNORE)
  (FORMAT T "An /"unsafe/" stack group attempted to STACK-GROUP-RETURN.~%"))

;; TV-ERASE-OFF-SCREEN
;; No arg.

(DEFUN (TV-ERASE-OFF-SCREEN INFORM) (IGNORE IGNORE)
  (FORMAT T "The %DRAW-RECTANGLE function attempted to erase past the end of the screen.~%"))

;; THROW-TAG-NOT-SEEN
;; The tag has been moved to M-A for the EH to find it!
;; The value being thrown is in M-T, the *UNWIND-STACK count and action are in M-B and M-C.

(DEFUN (THROW-TAG-NOT-SEEN INFORM) (SG IGNORE)
  (FORMAT T "There was no pending *CATCH for the tag ~S.~%"
	  (SG-AC-A SG))
  (FORMAT T "The value being thrown was ~S~%" (SG-AC-T SG))
  (AND (SG-AC-B SG)
       (FORMAT T "While in a *UNWIND-STACK with remaining count of ~D.~%" (SG-AC-B SG)))
  (AND (SG-AC-C SG)
       (FORMAT T "While in a *UNWIND-STACK with action ~S.~%" (SG-AC-C SG))))

(DEFUN (THROW-TAG-NOT-SEEN SIGNAL) (SG IGNORE)
  `(:UNDEFINED-CATCH-TAG ,(SG-AC-A SG) ,(SG-AC-T SG) ,(SG-AC-B SG) ,(SG-AC-C SG)))

;; MVR-BAD-NUMBER
;; Where the # is.

(DEFUN (MVR-BAD-NUMBER INFORM) (SG ETE)
  (FORMAT T "The function attempted to return ~D. values.~%"
	  (SG-FIXNUM-CONTENTS SG (SECOND ETE))))

(DEFUN (ZERO-ARGS-TO-SELECT-METHOD INFORM) (SG ETE)
  (FORMAT T "~S was applied to no arguments.~%"
	  (SG-CONTENTS SG (SECOND ETE))))

(DEFUN (SELECTED-METHOD-NOT-FOUND INFORM) (SG ETE)
  (FORMAT T "No method for message ~S was found in a call to ~S.~%"
	  (SG-CONTENTS SG (THIRD ETE))
	  (SG-CONTENTS SG (SECOND ETE))))

(DEFUN (SELECT-METHOD-GARBAGE-IN-SELECT-METHOD-LIST INFORM) (SG ETE)
  (FORMAT T "The weird object ~S was found in a select-method alist.~%"
	  (SG-CONTENTS SG (SECOND ETE))))

(DEFUN (SELECT-METHOD-BAD-SUBROUTINE-CALL INFORM) (SG ETE)
  (FORMAT T "A bad /"subroutine call/" was found inside ~S.~%"
	  (SG-CONTENTS SG (SECOND ETE))))

(DEFUN (MICRO-CODE-ENTRY-OUT-OF-RANGE INFORM) (SG ETE)
  (FORMAT T "MISC-instruction ~S is not an implemented instruction."
	  (SG-FIXNUM-CONTENTS SG (SECOND ETE))))

(DEFUN (BIGNUM-NOT-BIG-ENOUGH-DPB INFORM) (IGNORE IGNORE)
  (FORMAT T "There is an internal error in bignums; please report this bug."))

(DEFUN (BAD-INTERNAL-MEMORY-SELECTOR-ARG INFORM) (SG ETE)
  (FORMAT T "~S is not valid as the first argument to %WRITE-INTERNAL-PROCESSOR-MEMORIES."
	  (SG-CONTENTS SG (SECOND ETE))))

(DEFUN (BITBLT-DESTINATION-TOO-SMALL INFORM) (IGNORE IGNORE)
  (FORMAT T "The destination of a BITBLT was too small."))

(DEFUN (WRITE-IN-READ-ONLY INFORM) (SG ETE)
  (FORMAT T "There was an attempt to write into ~S, which is a read-only address."
	  (SG-CONTENTS SG (SECOND ETE))))


;;;; General Machine Lossages.

;; PDL-OVERFLOW
;; Arg is either SPECIAL or REGULAR

;; NOTE: If you make PDL-OVERFLOW signal a condition, there is going to be problem
;; since the call to SIGNAL will expand the pdl which will type out when the streams
;; haven't really been set up yet.
(DEFUN (PDL-OVERFLOW INFORM) (IGNORE ETE)
  (FORMAT T "The ~A push-down list has overflown.  Type control-C to allocate more.~%"
	  (CADR (ASSQ (SECOND ETE) '((REGULAR "regular") (SPECIAL "special"))))))

(DEFUN (PDL-OVERFLOW PROCEED) (SG IGNORE)
  (FORMAT T "Continuing with more pdl.~%")
  (SG-MAYBE-GROW-PDLS SG)		;Make very sure that there is enough room
  (SG-PROCEED-MICRO-PC SG NIL))		;Then continue after microcode check for room

(DEFPROP PDL-OVERFLOW "C grows the pdl and proceeds." HELP-MESSAGE)


;; ILLEGAL-INSTRUCTION
;; No args.

(DEFUN (ILLEGAL-INSTRUCTION INFORM) (SG IGNORE)
  (FORMAT T "There was an attempt to execute an invalid instruction: ~O"
	  (LET ((FRAME (SG-PREVIOUS-ACTIVE SG (SG-AP SG))))
	    (FEF-INSTRUCTION (AREF (SG-REGULAR-PDL SG) FRAME)
			     (RP-EXIT-PC (SG-REGULAR-PDL SG) FRAME)))))

;; BAD-CDR-CODE
;; Arg is where loser is.
(DEFUN (BAD-CDR-CODE INFORM) (SG ETE)
  (FORMAT T "A bad cdr-code was found in memory (at address ~O)~%"
	  (SG-FIXNUM-CONTENTS SG (SECOND ETE))))  ;Can't use Lisp print since will err again

;; DATA-TYPE-SCREWUP
;; This happens when some internal data structure contains wrong data type.  arg is name.
;; As it happens, all the names either start with a vowel or do if pronounced as letters
;; Not continuable
(DEFUN (DATA-TYPE-SCREWUP INFORM) (IGNORE ETE)
  (FORMAT T "A bad data-type was found in the internal guts of an ~A~%" (SECOND ETE)))

;; STACK-FRAME-TOO-LARGE
(DEFUN (STACK-FRAME-TOO-LARGE INFORM) (IGNORE IGNORE)
  (FORMAT T "Attempt to make a stack frame larger than 256. words"))

;; AREA-OVERFLOW
;; arg is register containing area#
(DEFUN (AREA-OVERFLOW INFORM) (SG ETE)
  (LET ((AREA-NUMBER (SG-FIXNUM-CONTENTS SG (SECOND ETE))))
    (FORMAT T "Allocation in the /"~A/" area exceeded the maximum of ~D. words.~%"
	    (AREA-NAME AREA-NUMBER)
	    (AREA-MAXIMUM-SIZE AREA-NUMBER))))

;; VIRTUAL-MEMORY-OVERFLOW
(DEFUN (VIRTUAL-MEMORY-OVERFLOW INFORM) (IGNORE IGNORE)
  (FORMAT T "You've used up all available virtual memory!~%"))

;; RCONS-FIXED
(DEFUN (RCONS-FIXED INFORM) (IGNORE IGNORE)
  (FORMAT T "There was an attempt to allocate storage in a fixed area.~%"))

;; REGION-TABLE-OVERFLOW
(DEFUN (REGION-TABLE-OVERFLOW INFORM) (IGNORE IGNORE)
  (FORMAT T "Unable to create a new region because the region tables are full.~%"))

;; RPLACD-WRONG-REPRESENTATION-TYPE
;; arg is first argument to RPLACD
(DEFUN (RPLACD-WRONG-REPRESENTATION-TYPE INFORM) (SG ETE)
  (FORMAT T "Attempt to RPLACD a list which is embedded in a structure and therefore
cannot be RPLACD'ed.  The list is ~S~%"
	  (SG-CONTENTS SG (SECOND ETE))))

;;;; Special cases.

;; MAR-BREAK
;; This code won't work if write-data is a DTP-NULL because of trap out of MAKUNBOUND

(DEFUN (MAR-BREAK INFORM) (SG ETE)
  (FORMAT T "The MAR has gone off because of an attempt to ~[read~;write~].~%"
	  (SG-FLAGS-PGF-WRITE SG))
  (AND (EQ (SECOND ETE) 'WRITE)
       (FORMAT T "Value being written is ~S~%" (SG-CONTENTS SG 'PP))))

(DEFPROP MAR-BREAK MAR-BREAK-PROCEED PROCEED)
;By simply returning without calling SG-PROCEED-MICRO-PC, the PGF-R will return
(DEFUN MAR-BREAK-PROCEED (SG ETE)
  (COND ((NULL (SECOND ETE))
	 (FORMAT T "Old microcode, MAR break not proceedable")
	 (*THROW 'QUIT NIL))
	((NOT (Y-OR-N-P "Proceed from MAR break? "))
	 (*THROW 'QUIT NIL))
	((EQ (SECOND ETE) 'WRITE)		;Simulate the write
	 (AND (Y-OR-N-P "Allow the write to take place? ")
	      (SG-FUNCALL SG #'(LAMBDA (VMA MD)
				 (LET ((%MAR-HIGH -2) (%MAR-LOW -1))	;Disable MAR
				   (RPLACA VMA MD)))
			     (SG-SAVED-VMA SG) (SG-REGPDL-POP SG))))))

(DEFPROP MAR-BREAK "C proceeds." HELP-MESSAGE)


;; TRANS-TRAP

;Given an address which contains a dtp-null, find who it belongs to and which
;of his cells it is.  Can also return NIL if it can't figure it out.
(DEFUN DECODE-NULL-POINTER (VMA)
  (DECLARE (RETURN-LIST NAME CELL-TYPE))
  (AND (= (%P-DATA-TYPE VMA) DTP-NULL)
       (LET ((SYMBOL (%FIND-STRUCTURE-HEADER (%P-CONTENTS-AS-LOCATIVE VMA))))
	 (COND ((SYMBOLP SYMBOL)
		(VALUES SYMBOL
			(SELECTQ (%POINTER-DIFFERENCE VMA SYMBOL)
			  (1 'VALUE)
			  (2 'FUNCTION)
			  (OTHERWISE 'CLOSURE))))	;Jumping to conclusions a bit
	       ((LISTP SYMBOL)
		(VALUES (SI:METH-FUNCTION-SPEC SYMBOL) 'FUNCTION))))))


(DEFUN (TRANS-TRAP INFORM) (SG IGNORE)
  (PROG ((VMA (SG-SAVED-VMA SG))  ;I need to use a RETURN
	 PROP)
    (COND ((= (%P-DATA-TYPE VMA) DTP-NULL)
	   (MULTIPLE-VALUE-BIND (SYMBOL CELL-TYPE) (DECODE-NULL-POINTER VMA)
	     (SELECTQ CELL-TYPE
	       (VALUE (RETURN (FORMAT T "The variable ~S is unbound.~%" SYMBOL)))
	       (FUNCTION
		 (FORMAT T "The function ~S is undefined.~%" SYMBOL)
		 (AND (SYMBOLP SYMBOL)
		      (SETQ PROP (GETL SYMBOL '(EXPR FEXPR MACRO SUBR FSUBR LSUBR AUTOLOAD)))
		      (FORMAT T
	"Note: the symbol has a ~S property, this may be a Maclisp compatibility problem.~%"
			      (CAR PROP)))
		 (RETURN NIL))
	       (CLOSURE
		 (RETURN (FORMAT T "The variable ~S is unbound (in a closure value-cell).~%"
				   SYMBOL)))))))
    ;; If it gets here, it's not a special case
    (FORMAT T "The word #<~S ~S> was read from location ~O ~@[(in ~A)~].~%"
	    (Q-DATA-TYPES (%P-DATA-TYPE VMA)) (%P-POINTER VMA) (%POINTER VMA)
	    (LET ((AREA (%AREA-NUMBER (%POINTER VMA))))
	      (AND AREA (AREA-NAME AREA))))))


(DEFUN (TRANS-TRAP SIGNAL) (SG IGNORE)
  (MULTIPLE-VALUE-BIND (SYMBOL CELL-TYPE) (DECODE-NULL-POINTER (SG-SAVED-VMA SG))
    (SELECTQ CELL-TYPE
      ((VALUE CLOSURE) `(:UNDEFINED-VARIABLE ,SYMBOL))
      (FUNCTION `(:UNDEFINED-FUNCTION ,SYMBOL)))))

;Some people would rather not spend the time for this feature, so let them turn it off
(DEFVAR ENABLE-TRANS-TRAP-DWIM T)

;;; If problem is symbol in wrong package, offer some dwimoid assistance.
(DEFUN (TRANS-TRAP OFFER-SPECIAL-COMMANDS) (SG IGNORE &AUX VMA SYM CELL NEW-VAL)
  (COND ((AND ENABLE-TRANS-TRAP-DWIM
	      (= (%P-DATA-TYPE (SETQ VMA (SG-SAVED-VMA SG))) DTP-NULL)
	      (SYMBOLP (MULTIPLE-VALUE (SYM CELL) (DECODE-NULL-POINTER VMA)))
	      (SETQ CELL (ASSQ CELL '((VALUE BOUNDP SYMEVAL "value" 1)
				      (FUNCTION FBOUNDP FSYMEVAL "definition" 2))))
	      (CAR (SETQ NEW-VAL (SG-FUNCALL SG #'TRANS-TRAP-DWIMIFY SYM CELL))))
	 ;Special handling requested, don't enter regular error handler
	 ;use TRANS-TRAP-RESTART in any case.  Even if indirecting permanently, just
	 ; proceeding doesn't win because VMA points to ONE-Q-FORWARD, which manages
	 ; not to get followed by just continuing.
	 (SG-REGPDL-PUSH (CADR NEW-VAL) SG)
	 (SG-PROCEED-MICRO-PC SG 'TRANS-TRAP-RESTART)
	 (SETF (SG-CURRENT-STATE SG) SG-STATE-RESUMABLE)
	 (PROCEED-SG SG))))

(DEFUN TRANS-TRAP-DWIMIFY (SYM CELL)
  (MULTIPLE-VALUE-BIND (NEW-SYM DWIM-P)
    (*CATCH 'TRANS-TRAP-DWIMIFY
      (MAP-OVER-LOOKALIKE-SYMBOLS (GET-PNAME SYM) PKG-GLOBAL-PACKAGE
	 #'(LAMBDA (NEW-SYM ORIGINAL-SYM CELL &AUX ANS)
	     (COND ((AND (NEQ NEW-SYM ORIGINAL-SYM)
			 (FUNCALL (SECOND CELL) NEW-SYM)
			 (SETQ ANS (FQUERY '(:CHOICES
					      (((T "Yes.") #/Y #/T #\SP #\HAND-UP)
					       ((NIL "No.") #/N #\RUBOUT #/Z #\HAND-DOWN)
					       ((P "Permanently link ") #/P)
					       ((G "Go to package ") #/G))
					      :HELP-FUNCTION TRANS-TRAP-SPECIAL-COMMANDS-HELP)
					   "Use the ~A of ~S? " (FOURTH CELL) NEW-SYM)))
		    (COND ((EQ ANS 'P)
			   (FORMAT QUERY-IO "~S to ~S." ORIGINAL-SYM NEW-SYM)
			   (%P-STORE-TAG-AND-POINTER
			     (%MAKE-POINTER-OFFSET DTP-LOCATIVE ORIGINAL-SYM (FIFTH CELL))
			     DTP-ONE-Q-FORWARD
			     (%MAKE-POINTER-OFFSET DTP-LOCATIVE NEW-SYM (FIFTH CELL))))
			  ((EQ ANS 'G)
			   (LET ((PKG (SYMBOL-PACKAGE NEW-SYM)))
			     (FORMAT QUERY-IO "~A." (PKG-NAME PKG))
			     (PKG-GOTO PKG))))
		    (*THROW 'TRANS-TRAP-DWIMIFY NEW-SYM))))
	 SYM CELL))
    (AND DWIM-P (VALUES T (FUNCALL (THIRD CELL) NEW-SYM)))))

(DEFUN TRANS-TRAP-SPECIAL-COMMANDS-HELP (S IGNORE IGNORE)
  (FORMAT S "~&Y to use it this time.
P to use it every time (permanently link the two symbols).
G to use it this time and do a pkg-goto.
N to do nothing special and enter the normal error handler.
"))

(DEFUN MAP-OVER-LOOKALIKE-SYMBOLS (PNAME PKG FUNCTION &REST ADDITIONAL-ARGS &AUX SYM)
  (IF (SETQ SYM (INTERN-LOCAL-SOFT PNAME PKG))
      (LEXPR-FUNCALL FUNCTION SYM ADDITIONAL-ARGS))
  (DOLIST (P (SI:PKG-SUBPACKAGES PKG))
    (LEXPR-FUNCALL #'MAP-OVER-LOOKALIKE-SYMBOLS PNAME P FUNCTION ADDITIONAL-ARGS)))

(DEFUN (TRANS-TRAP PROCEED) (SG IGNORE)
  (LET ((VMA (SG-SAVED-VMA SG))
	(PROMPT "Form to evaluate and use instead of cell's contents:")
	SYMBOL CELL-TYPE)
    (COND ((NOT (MEMQ (Q-DATA-TYPES (%P-DATA-TYPE VMA)) GOOD-DATA-TYPES))
	   ;Location still contains garbage, get a replacement value.
	   ;Try to make a prompt that isn't confusing.
	   (AND (= (%P-DATA-TYPE VMA) DTP-NULL)
		(MULTIPLE-VALUE (SYMBOL CELL-TYPE) (DECODE-NULL-POINTER VMA))
		(SYMBOLP SYMBOL)
		(SELECTQ CELL-TYPE
		  (VALUE (SETQ PROMPT
			   (FORMAT NIL "Form to evaluate and use instead of ~S's value:"
				       SYMBOL)))
		  (FUNCTION (SETQ PROMPT
			      (FORMAT NIL
			       "Form to evaluate and use instead of ~S's function definition:"
			       SYMBOL)))))
	   (SG-REGPDL-PUSH (READ-OBJECT PROMPT) SG)
	   (SG-PROCEED-MICRO-PC SG 'TRANS-TRAP-RESTART)) ;Use replacement data on stack
	  (T (SG-PROCEED-MICRO-PC SG NIL)))))	;Drop through, will do transport again


(DEFUN (TRANS-TRAP BASH-AND-PROCEED) (SG IGNORE)
  (COND ((NOT (MEMQ (Q-DATA-TYPES (%P-DATA-TYPE (SG-SAVED-VMA SG))) GOOD-DATA-TYPES))
	 (SG-STORE (READ-OBJECT
		     (MULTIPLE-VALUE-BIND (SYMBOL CELL-TYPE)
			 (DECODE-NULL-POINTER (SG-SAVED-VMA SG))
		       (OR (AND (SYMBOLP SYMBOL)
				(SELECTQ CELL-TYPE
				  (VALUE
				    (FORMAT NIL "Form to evaluate and SETQ ~S to?" SYMBOL))
				  (FUNCTION
				    (FORMAT NIL "Form to evaluate and FSET' ~S to?" SYMBOL))))
			   "Form to evaluate and store back?")))
		   SG 'RMD)))
  (SG-PROCEED-MICRO-PC SG NIL)) ;Drop through, will do transport again

(DEFUN (TRANS-TRAP HELP-MESSAGE) (SG IGNORE)
  (FORMAT T "C continues, using a specified value instead of the undefined ~A.~@
	    C defines the ~:*~A to a specified value, then continues."
	  (MULTIPLE-VALUE-BIND (SYMBOL CELL-TYPE) (DECODE-NULL-POINTER (SG-SAVED-VMA SG))
	    (OR (AND (SYMBOLP SYMBOL)
		     (SELECTQ CELL-TYPE
		       (VALUE "variable")
		       (FUNCTION "function")))
		"memory cell"))))

;; FUNCTION-ENTRY
;; Special case.
;; The ucode kindly leaves the M-ERROR-SUBSTATUS pushed onto the
;; regular pdl so that we can find it.
;; The meanings of %%M-ESUBS-BAD-QUOTED-ARG, %%M-ESUBS-BAD-EVALED-ARG
;; and %%M-ESUBS-BAD-QUOTE-STATUS are not clear, as they are not used
;; by the microcode.

(DEFUN FUNCTION-ENTRY-ERROR (SG)
  (LOOP WITH ERROR-CODE = (AREF (SG-REGULAR-PDL SG) (SG-REGULAR-PDL-POINTER SG))
	FOR SYMBOL IN '(%%M-ESUBS-TOO-FEW-ARGS %%M-ESUBS-TOO-MANY-ARGS %%M-ESUBS-BAD-DT)
	FOR FLAG IN '(< > )
	WHEN (LDB-TEST (SYMEVAL SYMBOL) ERROR-CODE)
	  RETURN FLAG))

(DEFUN (FUNCTION-ENTRY INFORM) (SG IGNORE)
  (FORMAT T "The function ~S was called with ~A.~%"
	    (FUNCTION-NAME (AREF (SG-REGULAR-PDL SG) (SG-AP SG)))
	    (CDR (ASSQ (FUNCTION-ENTRY-ERROR SG)
		       '((< . "too few arguments")
			 (> . "too many arguments")
			 ( . "an argument of bad data type"))))))

(DEFUN (FUNCTION-ENTRY SIGNAL) (SG IGNORE)
  (IF (MEMQ (FUNCTION-ENTRY-ERROR SG) '(< >))
      `(:WRONG-NUMBER-OF-ARGUMENTS
	  ,(- (SG-REGULAR-PDL-POINTER SG) (SG-AP SG))
	  ,(ALOC (SG-REGULAR-PDL SG) (1+ (SG-AP SG))))))

(DEFUN (FUNCTION-ENTRY PROCEED) (SG IGNORE)
  (LET* ((RP (SG-REGULAR-PDL SG))
	 (FRAME (SG-AP SG))
	 (FORM (GET-FRAME-FUNCTION-AND-ARGS SG FRAME))
	 (ARGS-INFO (ARGS-INFO (CAR FORM)))
	 (ARGS-SUPPLIED (RP-NUMBER-ARGS-SUPPLIED RP FRAME))
	 ARGS-WANTED)
    ;; Function may have been redefined to take the supplied number of arguments
    ;; so don't look at the original error, but check everything again.
    (COND ((< ARGS-SUPPLIED (SETQ ARGS-WANTED (LDB %%ARG-DESC-MIN-ARGS ARGS-INFO)))
	   (LOOP FOR I FROM ARGS-SUPPLIED BELOW ARGS-WANTED
		 DO (SETQ FORM
			  (NCONC FORM (NCONS (READ-OBJECT (FORMAT NIL "Arg ~D: " I) NIL))))))
	  ((OR ( ARGS-SUPPLIED (SETQ ARGS-WANTED (LDB %%ARG-DESC-MAX-ARGS ARGS-INFO)))
	       (LDB-TEST %%ARG-DESC-ANY-REST ARGS-INFO))
	   (OR (FQUERY () "Try ~S again? " FORM)
	       (*THROW 'QUIT NIL)))
	  ((FQUERY () "Call again with the last ~[~1;~:;~:*~D ~]argument~:P dropped? "
		      (- ARGS-SUPPLIED ARGS-WANTED))
	   (RPLACD (NTHCDR ARGS-WANTED FORM) NIL))
	  ((*THROW 'QUIT NIL)))
    ;; If we haven't quit before getting here, he wants to proceed and FORM is set up
    (SG-UNWIND-TO-FRAME-AND-REINVOKE SG FRAME FORM)
    (LEAVING-ERROR-HANDLER)
    (WITHOUT-INTERRUPTS
      (AND ERROR-HANDLER-RUNNING
	   (FREE-SECOND-LEVEL-ERROR-HANDLER-SG %CURRENT-STACK-GROUP))
      (STACK-GROUP-RESUME SG NIL))))

(DEFUN (FUNCTION-ENTRY HELP-MESSAGE) (SG IGNORE)
  (FORMAT T "C offers to try again")
  (SELECTQ (FUNCTION-ENTRY-ERROR SG)
    (< (FORMAT T ", asking you for additional arguments."))
    (> (FORMAT T ", dropping the extra arguments."))))

(DEFUN (BREAKPOINT INFORM) (IGNORE IGNORE)
  (FORMAT T "Breakpoint~%"))

(DEFUN (STEP-BREAK INFORM) (SG IGNORE)
  (FORMAT T "Step break~%")
  (SETF (SG-INST-DISP SG) 0))

(DEFUN (CALL-TRAP INFORM) (SG IGNORE)
  (SETQ INNERMOST-FRAME-IS-INTERESTING T)
  (SETF (SG-FLAGS-TRAP-ON-CALL SG) 0)		;Prevent following traps.
  (SETF INNERMOST-VISIBLE-FRAME (SG-IPMARK SG))	;Make frame being entered visible.
  (SETQ CURRENT-FRAME INNERMOST-VISIBLE-FRAME)  ;Select it.
  (SETF (RP-TRAP-ON-EXIT (SG-REGULAR-PDL SG) INNERMOST-VISIBLE-FRAME) 1)
  (SETF (RP-NUMBER-ARGS-SUPPLIED (SG-REGULAR-PDL SG) INNERMOST-VISIBLE-FRAME)
	(- (SG-REGULAR-PDL-POINTER SG) INNERMOST-VISIBLE-FRAME))
  (FORMAT T "Break on entry to function ~S~%"
	  (FUNCTION-NAME (RP-FUNCTION-WORD (SG-REGULAR-PDL SG) (SG-IPMARK SG)))))

(DEFUN (EXIT-TRAP INFORM) (SG IGNORE)
  ;; If exiting from *EVAL, we do want to see its frame.
  (SETQ INNERMOST-FRAME-IS-INTERESTING T)
  ;; Make sure we are looking at that frame.
  ;; Because it may not have been "interesting" until now,
  ;; current-frame may have been set to something else.
  (SETQ CURRENT-FRAME INNERMOST-VISIBLE-FRAME)
  ;; Don't catch this trap again if user tries to return, etc.
  (SETF (RP-TRAP-ON-EXIT (SG-REGULAR-PDL SG) CURRENT-FRAME) 0)
  (FORMAT T "Break on exit from marked frame; ")
  (FORMAT T "value is ~S" (SG-AC-T SG)))

(DEFUN (THROW-EXIT-TRAP INFORM) (SG IGNORE)
  (SETQ CURRENT-FRAME (- (%POINTER-DIFFERENCE (%P-CONTENTS-AS-LOCATIVE (LOCF (SG-AC-D SG)))
					      (SG-REGULAR-PDL SG))
			 2))
  (FORMAT T "Break on throw through marked frame~%")
  (SETQ INNERMOST-FRAME-IS-INTERESTING T)
  (DO ((FRAME CURRENT-FRAME (SG-PREVIOUS-ACTIVE SG FRAME)))
      ((NULL FRAME))
    (SETF (RP-TRAP-ON-EXIT (SG-REGULAR-PDL SG) FRAME) 0)))

(DEFPROP CALL-TRAP MICRO-BREAK-PROCEED PROCEED)
(DEFPROP EXIT-TRAP MICRO-BREAK-PROCEED PROCEED)
(DEFPROP THROW-EXIT-TRAP MICRO-BREAK-PROCEED PROCEED)
(DEFUN MICRO-BREAK-PROCEED (SG IGNORE)
  (SG-PROCEED-MICRO-PC SG NIL)
  (FORMAT T "Continue from break.~%"))

(DEFPROP :BREAK BREAK-PROCEED PROCEED)
(DEFUN BREAK-PROCEED (IGNORE IGNORE)
  (FORMAT T "Continue from break.~%"))

(DEFPROP :BREAK "C proceeds." HELP-MESSAGE)
(DEFPROP CALL-TRAP "C proceeds." HELP-MESSAGE)
(DEFPROP EXIT-TRAP "C proceeds." HELP-MESSAGE)
(DEFPROP THROW-EXIT-TRAP "C proceeds." HELP-MESSAGE)

(DEFUN (:WRONG-TYPE-ARGUMENT PROCEED) (IGNORE ETE)
  (READ-OBJECT
    (FORMAT NIL "Form to be evaluated and used as replacement value for ~A" (NTH 7 ETE))))

(DEFPROP :WRONG-TYPE-ARGUMENT "C asks for a replacement argument and proceeds." HELP-MESSAGE)

(DEFUN (TURD-ALERT INFORM) (SG ETE)
  (FORMAT T "There was an attempt to draw on the sheet ~S without preparing it first.~%"
	    (SG-CONTENTS SG (SECOND ETE))))

(DEFUN (TURD-ALERT PROCEED) (SG IGNORE)	;Might as well allow loser to proceed
  (SG-PROCEED-MICRO-PC SG NIL))

(DEFPROP TURD-ALERT "C proceeds, perhaps writing garbage on the screen." HELP-MESSAGE)

;;; List problems with currently-loaded error table
(DEFUN LIST-PROBLEMS ()
  (LET ((ERRORS-WITH-NO-ERROR-MESSAGES NIL)
	(MISSING-RESTART-TAGS NIL)
	(ARGTYP-UNKNOWN-TYPES NIL)
	(TEM))
    (DOLIST (ETE ERROR-TABLE)
      (OR (GET (SETQ TEM (SECOND ETE)) 'INFORM)
	  (MEMQ TEM ERRORS-WITH-NO-ERROR-MESSAGES)
	  (PUSH TEM ERRORS-WITH-NO-ERROR-MESSAGES))
      (IF (EQ TEM 'ARGTYP)
	  (LET ((TYPE (THIRD ETE)))
	    (IF (SYMBOLP TYPE)
		(SETQ TYPE (NCONS TYPE)))
	    (DOLIST (TYPE TYPE)
	      (IF (AND (NULL (ASSQ TYPE DATA-TYPE-NAMES))
		       (NOT (MEMQ (THIRD ETE) ARGTYP-UNKNOWN-TYPES)))
		  (PUSH (THIRD ETE) ARGTYP-UNKNOWN-TYPES)))))
      (AND (SETQ TEM (ASSQ TEM		;Anything that calls SG-PROCEED-MICRO-PC
			   '((ARGTYP . 5) (SUBSCRIPT-OOB . 4))))
	   (SETQ TEM (NTH (CDR TEM) ETE))
	   (NOT (ASSQ TEM RESTART-LIST))
	   (NOT (MEMQ TEM MISSING-RESTART-TAGS))
	   (PUSH TEM MISSING-RESTART-TAGS)))
    (AND ERRORS-WITH-NO-ERROR-MESSAGES
	 (FORMAT T "~&Errors with no error messages: ~S" ERRORS-WITH-NO-ERROR-MESSAGES))
    (AND ARGTYP-UNKNOWN-TYPES
	 (FORMAT T "~&ARGTYP types not on DATA-TYPE-NAMES: ~S" ARGTYP-UNKNOWN-TYPES))
    (AND MISSING-RESTART-TAGS
	 (FORMAT T "~&Missing RESTART tags: ~S" MISSING-RESTART-TAGS))))

;;;; Not errors at all.

;; RESTART
;; This is not an error!
;; Arg is name of frob which you restart here.

;; CALLS-SUB
;; Arg is name of Lisp function which did the call, or something.


;;; Macro-code errors work by funcalling the error handler stack group
;;; with a list that looks like
;;; (FERROR proceedable-flag restartable-flag condition
;;;         format-control-string arg1 arg2 ...)

;;; (ERROR <message> &optional <object> <interrupt>)
;;; is for Maclisp compatibility.  It makes the error message
;;; out of <message> and <object>, and the condition out of <interrupt>'s
;;; CONDITION-NAME property.  The error is proceedable if
;;; <interrupt> is given.
(DEFPROP ERROR T :ERROR-REPORTER)
(DEFUN ERROR (MESSAGE &OPTIONAL OBJECT INTERRUPT)
  (SIGNAL-ERROR (NOT (NULL INTERRUPT)) NIL
		(OR (GET INTERRUPT 'CONDITION-NAME)
		    INTERRUPT)
		(COND ((NULL OBJECT) "~*~A")
		      (T "~S ~A"))
		(LIST OBJECT MESSAGE)))

;;; (CERROR <proceed> <restart>
;;;         <condition> <format-control-string> <format-arg1> <format-arg2> ...)
;;; is the general way to report an error.  <format-control-string>
;;; and the args that follow it are arguments to FORMAT, for printing a message.
;;; <condition> together with <format-arg1> and following are the condition-list
;;; for signaling the condition.  <proceed> if non-NIL says that it is legal
;;; to proceed from the error.  If <proceed> is T, the value returned
;;; by the CERROR will be used instead of some bad value.  In this case,
;;; the error handler asks the user for a value to return.
;;; If <restart> is non-NIL, it is legal for the user or a condition handler
;;; to ask to restart.  Restarting works by throwing to ERROR-RESTART.
;;; See the definition of the ERROR-RESTART macro.
(DEFPROP CERROR T :ERROR-REPORTER)
(DEFUN CERROR (PROCEEDABLE-FLAG RESTARTABLE-FLAG CONDITION FORMAT &REST ARGS)
  (SIGNAL-ERROR PROCEEDABLE-FLAG RESTARTABLE-FLAG CONDITION FORMAT ARGS))

;;; (FERROR <condition> <format-control-string> <format-arg1> <format-arg2> ...)
;;; indicates an uncorrectable error.  <error-type> is the keyword
;;; to be used in signalling the error, together with <format-arg1>, ...
(DEFPROP FERROR T :ERROR-REPORTER)
(DEFUN FERROR (CONDITION FORMAT &REST ARGS)
  (SIGNAL-ERROR NIL NIL CONDITION FORMAT ARGS))

(DEFUN (FERROR INFORM) (IGNORE ETE)
  (IF (OR (< (LENGTH ETE) 5)
	  (NOT (OR (STRINGP (FIFTH ETE))
		   (SYMBOLP (FIFTH ETE))
		   (LISTP (FIFTH ETE))))) ;Maclisp...
      (FORMAT T "Uh-oh, bad arguments to ~S: ~S~%" (CAR ETE) (CDR ETE))
      (LEXPR-FUNCALL 'FORMAT T (CDDDDR ETE))))

(DEFPROP SIGNAL-ERROR T :ERROR-REPORTER)
(DEFUN SIGNAL-ERROR (PROCEEDABLE-FLAG RESTARTABLE-FLAG CONDITION FORMAT ARGS &AUX TEM1 TEM2)
  (MULTIPLE-VALUE (TEM1 TEM2) (LEXPR-FUNCALL 'SIGNAL CONDITION FORMAT ARGS))
  (COND ((EQ TEM1 'RETURN)
	 (IF PROCEEDABLE-FLAG TEM2
	     (FERROR NIL "Condition-handler attempted to proceed when that wasn't possible")))
	((EQ TEM1 'RETURN-VALUE)
	 TEM2)
	((EQ TEM1 'ERROR-RESTART)
	 (AND RESTARTABLE-FLAG (*THROW 'ERROR-RESTART TEM2))
	 (FERROR NIL "Condition-handler attempted to restart when that wasn't possible"))
	((NULL TEM1)
	 ;; SIGNAL did not find any handler willing to take the buck.
	 (FUNCALL %ERROR-HANDLER-STACK-GROUP
		  `(FERROR ,PROCEEDABLE-FLAG ,RESTARTABLE-FLAG
			   ,CONDITION ,FORMAT . ,ARGS))
	 NIL)					;This NIL is here for a reason!
	(T
	 (FERROR NIL
		 "Condition-handler said it handled an error but returned ~S" TEM1))))

;CONDITION-HANDLERS is a list of handling specs, each of which
;contains first either a condition name, a list of such names, or
;NIL meaning all condition names, and second
;a function to call to handle the condition.
;When you signal a condition with (SIGNAL condition-name info info info...)
;condition-handlers is searched for an element that applies to this
;condition name, and that element's function is called
;with the same arguments that signal was given (however many there were).
;If the function's first value is NIL, this means that the condition
;has not been handled, and the remaining handlers on the list should
;be given the chance to look at it.  Otherwise, the function's one
;or two values are returned by SIGNAL.

(DEFVAR CONDITION-HANDLERS NIL)

(DEFUN SIGNAL (&REST ARGS)
  (SIGNAL-1 CONDITION-HANDLERS ARGS))

(DEFUN SIGNAL-1 (HANDLER-LIST CONDITION-LIST &AUX (CNAME (CAR CONDITION-LIST)) TEM1 TEM2)
  (DO ((HANDLER-LIST HANDLER-LIST (CDR HANDLER-LIST))
       (H))
      ((NULL HANDLER-LIST) NIL)
    (SETQ H (CAR HANDLER-LIST))
    (COND ((COND ((NULL (CAR H)) T)
		 ((NLISTP (CAR H))
		  (EQ (CAR H) CNAME))
		 (T (MEMQ CNAME (CAR H))))
	   (MULTIPLE-VALUE (TEM1 TEM2)
	     (APPLY (CADR H) CONDITION-LIST))
	   (AND TEM1 (RETURN TEM1 TEM2))))))

(DEFMACRO-DISPLACE CONDITION-BIND (HANDLERS &BODY BODY)
  `(LET ((CONDITION-HANDLERS
	   (APPEND
	     (LIST . ,(MAPCAR #'(LAMBDA (CLAUSE)
				  `(LIST ',(FIRST CLAUSE) ,(SECOND CLAUSE)))
			      HANDLERS))
	     CONDITION-HANDLERS)))
     . ,BODY))

;; Does a stack group have anything that could try to handle this condition?
(DEFUN SG-CONDITION-HANDLED-P (SG CONDITION)
  (DOLIST (H (SYMEVAL-IN-STACK-GROUP 'CONDITION-HANDLERS SG))
    (AND (COND ((NULL (CAR H)) T)
	       ((NLISTP (CAR H)) (EQ (CAR H) CONDITION))
	       (T (MEMQ CONDITION (CAR H))))
	 (RETURN T))))

(DEFVAR ALLOW-PDL-GROW-MESSAGE T)

;; Make a stack-group's pdls larger if necessary
;; Note that these ROOM numbers need to be large enough to avoid getting into
;; a recursive trap situation, which turns out to be mighty big because footholds
;; are large and because the microcode is very conservative.
(DEFUN SG-MAYBE-GROW-PDLS (SG &OPTIONAL (MESSAGE-P ALLOW-PDL-GROW-MESSAGE)
					(REGULAR-ROOM 2000) (SPECIAL-ROOM 400)
			   &AUX (RPP (SG-REGULAR-PDL-POINTER SG))
				(RPL (SG-REGULAR-PDL-LIMIT SG))
				(SPP (SG-SPECIAL-PDL-POINTER SG))
				(SPL (SG-SPECIAL-PDL-LIMIT SG)) TEM)
  (COND ((> (SETQ TEM (+ RPP REGULAR-ROOM)) RPL)
	 (AND MESSAGE-P (FORMAT ERROR-OUTPUT "~&[Growing regular pdl of ~S from ~S to ~S]~%"
					     SG RPL TEM))
	 (SETF (SG-REGULAR-PDL SG) (SG-GROW-PDL (SG-REGULAR-PDL SG) RPP TEM))
	 (SETF (SG-REGULAR-PDL-LIMIT SG) TEM)))
  (COND ((> (SETQ TEM (+ SPP SPECIAL-ROOM)) SPL)
	 (AND MESSAGE-P (FORMAT ERROR-OUTPUT "~&[Growing special pdl of ~S from ~S to ~S]~%"
					     SG SPL TEM))
	 (SETF (SG-SPECIAL-PDL SG) (SG-GROW-PDL (SG-SPECIAL-PDL SG) SPP TEM))
	 (SETF (SG-SPECIAL-PDL-LIMIT SG) TEM))))

;; Make a new array, copy the contents, store forwarding pointers, and return the new
;; array.  Also we have to relocate the contents of the array as we move it because the
;; microcode does not always check for forwarding pointers (e.g. in MKWRIT when
;; returning multiple values).
(DEFUN SG-GROW-PDL (PDL PDL-PTR NEW-LIMIT
		    &AUX (NEW-SIZE (MAX (// (* (ARRAY-LENGTH PDL) 4) 3) (+ NEW-LIMIT 100)))
			 NEW-PDL TEM TEM1 AREA)
  (SETQ PDL (FOLLOW-STRUCTURE-FORWARDING PDL))
  (COND (( (+ NEW-LIMIT 100) (ARRAY-LENGTH PDL)) PDL)	;Big enough, just adjust limit
	(T (COND ((= (SETQ AREA (%AREA-NUMBER PDL)) LINEAR-PDL-AREA)	;Stupid crock
		  (SETQ AREA PDL-AREA))			; with non-extendible areas
		 ((= AREA LINEAR-BIND-PDL-AREA)
		  (SETQ AREA WORKING-STORAGE-AREA)))
	   (SETQ NEW-PDL (MAKE-ARRAY AREA (ARRAY-TYPE PDL) NEW-SIZE
				     NIL (ARRAY-LEADER-LENGTH PDL)))
	   (DOTIMES (I (ARRAY-LEADER-LENGTH PDL))
	     (STORE-ARRAY-LEADER (ARRAY-LEADER PDL I) NEW-PDL I))
	   ;Can't do next line because of funny-looking data types and because
	   ;we must preserve the flag bits and cdr codes.
	   ;(COPY-ARRAY-PORTION PDL 0 (1+ PDL-PTR) NEW-PDL 0 (1+ PDL-PTR))
	   (DO ((N PDL-PTR (1- N))
		(FROM-P (ALOC-CAREFUL PDL 0) (%MAKE-POINTER-OFFSET DTP-LOCATIVE FROM-P 1))
		(TO-P (ALOC NEW-PDL 0) (%MAKE-POINTER-OFFSET DTP-LOCATIVE TO-P 1))
		(BASE (ALOC-CAREFUL PDL 0)))
	       ((MINUSP N))
	     (SELECT (%P-DATA-TYPE FROM-P)
	       ((DTP-FIX DTP-SMALL-FLONUM DTP-U-ENTRY)	;The only inum types we should see
		(%P-STORE-TAG-AND-POINTER TO-P (%P-LDB %%Q-ALL-BUT-POINTER FROM-P)
					       (%P-LDB %%Q-POINTER FROM-P)))
	       ((DTP-HEADER-FORWARD DTP-BODY-FORWARD)
		(FERROR NIL "Already forwarded? -- get help"))
	       (OTHERWISE
		(SETQ TEM (%P-CONTENTS-AS-LOCATIVE FROM-P)
		      TEM1 (%POINTER-DIFFERENCE TEM BASE))
		(AND (NOT (MINUSP TEM1)) ( TEM1 PDL-PTR)
		     (SETQ TEM (ALOC-CAREFUL NEW-PDL TEM1)))
		(%P-STORE-TAG-AND-POINTER TO-P (%P-LDB %%Q-ALL-BUT-POINTER FROM-P)
					       TEM))))
	   (STRUCTURE-FORWARD PDL NEW-PDL)
	   NEW-PDL)))

