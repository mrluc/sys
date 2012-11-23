;;; -*- Mode: Lisp; Package: User; Base: 8.; Patch-File: T -*-
;;; Patch file for System version 78.29
;;; Reason: Do not uppercase user names in QFILE
;;; Written 12/23/81 18:52:40 by MMcM,
;;; while running on Lisp Machine Six from band 5
;;; with System 78.25, ZMail 38.4, microcode 836, CStacy special.



; From file QFILE > LMIO; AI:
#8R FILE-SYSTEM:(COMPILER-LET ((PACKAGE (PKG-FIND-PACKAGE "FILE-SYSTEM")))

(DEFUN LOGIN-HOST-UNIT (UNIT LOGIN-P UNAME-HOST &AUX HOST CONN)
  (SETQ HOST (HOST-UNIT-HOST UNIT)
	CONN (HOST-UNIT-CONTROL-CONNECTION UNIT))
  (AND CONN (EQ (CHAOS:STATE CONN) 'CHAOS:OPEN-STATE)
       (DO ((PKT (CHAOS:GET-PKT))
	    (ID (FILE-MAKE-TRANSACTION-ID))
	    (PASSWORD "")
	    (ACCOUNT "")
	    (NEED-PASSWORD NIL)
	    (SUCCESS NIL)
	    NEW-USER-ID)
	   (SUCCESS)
	 (SETQ PKT (CHAOS:GET-PKT)
	       ID (FILE-MAKE-TRANSACTION-ID))
	 (COND ((AND LOGIN-P			;If really login
		     (OR NEED-PASSWORD
			 (NULL (SETQ NEW-USER-ID (CDR (ASSQ UNAME-HOST USER-UNAMES))))))
		(COND ((EQ UNAME-HOST 'ITS)
		       ;; We don't know about USER-ID for this host, so must ask
		       (FORMAT QUERY-IO "~&ITS uname (default ~A): " USER-ID)
		       (LET ((NID (READLINE QUERY-IO)))
			 (SETQ NEW-USER-ID (IF (EQUAL NID "") USER-ID NID))))
		      (T
		       (MULTIPLE-VALUE (NEW-USER-ID PASSWORD)
			 (FILE-GET-PASSWORD USER-ID UNAME-HOST))))
		(FILE-HOST-USER-ID NEW-USER-ID HOST)))
	 (CHAOS:SET-PKT-STRING PKT ID "  LOGIN " (OR NEW-USER-ID "") " " PASSWORD " " ACCOUNT)
	 (CHAOS:SEND-PKT CONN PKT)
	 (SETQ PKT (FILE-WAIT-FOR-TRANSACTION ID CONN "Login"))
	 (IF LOGIN-P
	     (LET ((STR (CHAOS:PKT-STRING PKT))
		   IDX HSNAME-PATHNAME ITEM)
	       (SETQ STR (NSUBSTRING STR (1+ (STRING-SEARCH-CHAR #\SP STR))))
	       (SETQ IDX (FILE-CHECK-COMMAND "LOGIN" STR T))
	       (COND (IDX
		      (OR (STRING-EQUAL NEW-USER-ID STR 0 IDX NIL
					(SETQ IDX (STRING-SEARCH-CHAR #\SP STR IDX)))
			  (FERROR NIL "File job claims to have logged in as someone else."))
		      (MULTIPLE-VALUE (HSNAME-PATHNAME USER-PERSONAL-NAME
				       USER-GROUP-AFFILIATION
				       USER-PERSONAL-NAME-FIRST-NAME-FIRST)
			(FUNCALL HOST ':HSNAME-INFORMATION UNIT STR IDX))
		      (SETQ CHAOS:GIVE-FINGER-SAVED-USER-ID T)	;Clear cache
		      (IF (SETQ ITEM (ASSQ HOST USER-HOMEDIRS))
			  (RPLACD ITEM HSNAME-PATHNAME)
			  (PUSH (CONS HOST HSNAME-PATHNAME) USER-HOMEDIRS))
		      (SETQ SUCCESS T))
		     ;; If user or password is invalid, force getting it (again).
		     ((MEMBER (FILE-PROCESS-ERROR STR NIL T T) '("IP?" "PI?" "UNK"))
		      (SETQ NEED-PASSWORD T))
		     (T
		      (CHAOS:CLOSE CONN "Login failed")
		      (FILE-PROCESS-ERROR STR NIL T)
		      (FUNCALL HOST ':VALIDATE-CONTROL-CONNECTION UNIT))))
	     (SETQ SUCCESS T))
	 (CHAOS:RETURN-PKT PKT)))
  T)

)

; From file PATHNM > LMIO; AI:
#8R FILE-SYSTEM:(COMPILER-LET ((PACKAGE (PKG-FIND-PACKAGE "FILE-SYSTEM")))

(DEFMETHOD (MEANINGFUL-ROOT-MIXIN :PARSE-STRUCTURED-DIRECTORY-SPEC)
	   PATHNAME-PASS-THROUGH-SPEC)

)
