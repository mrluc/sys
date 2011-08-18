;;; -*- Mode: Lisp; Package: User; Base: 8.; Patch-File: T -*-
;;; Patch file for ZMail version 38.4
;;; Reason: More of 38.1
;;; Written 12/18/81 15:02:21 by MMcM,
;;; while running on Lisp Machine Five from band 2
;;; with System 78.21, ZMail 38.3, microcode 836.



; From file PROFIL > ZMAIL; AI:
#8R ZWEI:(COMPILER-LET ((PACKAGE (PKG-FIND-PACKAGE "ZWEI")))


(DEFUN SETUP-ZMAIL-PROFILE (&AUX FILE-ID PATHNAME)
  (SET-ZMAIL-USER)
  (SETQ FILE-ID (BUFFER-FILE-ID *INTERVAL*))
  (IF (NULL FILE-ID)
      (SETQ PATHNAME (ZMAIL-INIT-FILE-PATHNAME))
      (SETQ PATHNAME (BUFFER-PATHNAME *INTERVAL*))
      ;; See if everything is still ok
      (WITH-OPEN-FILE (STREAM PATHNAME '(:PROBE :NOERROR))
	(IF (STRINGP STREAM)
	    (AND (NEQ FILE-ID T)
		 (TYPEIN-LINE "Note: file has been deleted on the file computer"))
	    (AND (NOT (EQUAL FILE-ID (FUNCALL STREAM ':INFO)))
		 (FQUERY '(:SELECT T
			   :BEEP T)
			 "There is a different version of this file on the file computer,~@
			  your version has~:[ not~] been modified.~@
			  Do you want the new version instead? "
			 (BUFFER-MUNGED-P *INTERVAL*))
		 (SETQ FILE-ID NIL)))))
  (COND ((NULL FILE-ID)
	 (DELETE-INTERVAL *INTERVAL*)
	 (WITH-OPEN-FILE (STREAM PATHNAME ':DIRECTION ':INPUT ':CHARACTERS ':DEFAULT)
	   (COND ((STRINGP STREAM)
		  (TYPEIN-LINE "Creating init file ~A" PATHNAME)
		  (FORMAT (INTERVAL-STREAM *INTERVAL*)
			  ";~A's ZMAIL init file -*-Mode:LISP;Package:ZWEI-*-~%"
			  USER-ID)
		  (INSERT-CHANGED-VARIABLES T)
		  (MOVE-BP (WINDOW-POINT *WINDOW*)
			   (INTERVAL-LAST-BP *INTERVAL*))
		  (SETF (BUFFER-FILE-ID *INTERVAL*) T)
		  (SETF (BUFFER-TICK *INTERVAL*) (TICK)))
		 (T
		  (SETQ PATHNAME (RECORD-ZMAIL-PROFILE-SOURCE-PATHNAME STREAM))
		  (COND ((NEQ PATHNAME (FUNCALL STREAM ':PATHNAME))	;I.e. compiled
			 (CLOSE STREAM)
			 (SETQ STREAM (OPEN PATHNAME ':DIRECTION ':INPUT))))
		  (LET ((GENERIC-PATHNAME
			  (FUNCALL *PROFILE-SOURCE-PATHNAME* ':GENERIC-PATHNAME)))
		    (SETF (BUFFER-GENERIC-PATHNAME *INTERVAL*)
			  GENERIC-PATHNAME)
		    (FS:FILE-READ-PROPERTY-LIST GENERIC-PATHNAME STREAM))
		  (TYPEIN-LINE "Reading init file ~A" (FUNCALL STREAM ':TRUENAME))
		  (SETF (BUFFER-TICK *INTERVAL*) (TICK))
		  (SET-BUFFER-FILE-ID *INTERVAL* (FUNCALL STREAM ':INFO))
		  (SECTIONIZE-BUFFER *INTERVAL* STREAM)
		  (DECIDE-IF-SOURCE-MATCHES-QFASL STREAM)))
	   (SETF (BUFFER-NAME *INTERVAL*) (FUNCALL PATHNAME ':STRING-FOR-PRINTING))
	   (SETF (BUFFER-PATHNAME *INTERVAL*) PATHNAME)
	   (LET ((TICK (TICK)))
	     (SETQ *VARIABLE-TICK* TICK)	;Now assumed to be the same
	     (SETQ *EDITOR-VARIABLE-TICK* TICK))
	   (PUSH* *WINDOW* *WINDOW-LIST*)
	   (MUST-REDISPLAY *WINDOW* DIS-TEXT))))
  (BUFFER-NAME *INTERVAL*))

)

; From file PROFIL > ZMAIL; AI:
#8R ZWEI:(COMPILER-LET ((PACKAGE (PKG-FIND-PACKAGE "ZWEI")))


(DEFUN RECORD-ZMAIL-PROFILE-SOURCE-PATHNAME (STREAM &AUX PATHNAME)
  (SETQ PATHNAME (FUNCALL STREAM ':PATHNAME))
  (IF (NOT (FUNCALL STREAM ':CHARACTERS))
      (LET ((PLIST (SI:QFASL-STREAM-PROPERTY-LIST STREAM)))
	(SETQ *PROFILE-QFASL-GENERIC-PATHNAME* 
		(OR (GET (LOCF PLIST) ':SOURCE-FILE-GENERIC-PATHNAME)
		    (FUNCALL PATHNAME ':GENERIC-PATHNAME)))
	(SETQ *PROFILE-SOURCE-PATHNAME*
	      (FUNCALL (GET (LOCF PLIST) ':QFASL-SOURCE-FILE-UNIQUE-ID)
		       ':NEW-VERSION ':NEWEST))
	*PROFILE-SOURCE-PATHNAME*)
      (SETQ *PROFILE-SOURCE-PATHNAME*
	    (FUNCALL PATHNAME ':NEW-VERSION ':NEWEST)
	    *PROFILE-QFASL-GENERIC-PATHNAME* NIL)
      PATHNAME))

)
