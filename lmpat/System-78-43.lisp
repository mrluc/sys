;;; -*- Mode: Lisp; Package: User; Base: 8.; Patch-File: T -*-
;;; Patch file for System version 78.43
;;; Reason: Fix UNMONITOR-VARIABLE.
;;; Written 1/05/82 10:05:56 by dlw,
;;; while running on Beagle from band 2
;;; with System 78.42, ZMail 38.5, Symbolics 8.7, Tape 6.5, LMFS 21.28, Canon 9.11, microcode 841.



; From file QMISC.LISP >LISPM POINTER:
#8R SYSTEM-INTERNALS:(COMPILER-LET ((PACKAGE (PKG-FIND-PACKAGE "SYSTEM-INTERNALS")))

(LOCAL-DECLARE ((SPECIAL SYM VARIABLES-BEING-MONITORED))

(DEFUN UNMONITOR-VARIABLE (&OPTIONAL SYM)
  (COND ((NULL SYM)
	 (MAPC #'UNMONITOR-VARIABLE VARIABLES-BEING-MONITORED))
	((MEMQ SYM VARIABLES-BEING-MONITORED)
	 (SETQ VARIABLES-BEING-MONITORED (DELQ SYM VARIABLES-BEING-MONITORED))
	 (%P-DPB-OFFSET DTP-FIX 3005 SYM 1)  ;SMASH FORWARDING PNTR
	 (%P-STORE-CONTENTS (VALUE-CELL-LOCATION SYM)
			    (COND ((BOUNDP SYM)
				   (SYMEVAL SYM)))))))
)

)
