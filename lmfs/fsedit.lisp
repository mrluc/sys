;;;-*- Mode:LISP; Package:TV -*-

;;; Tree scroll an invention of MMcM. Hierarchy edit by BSG.

(DEFFLAVOR BASIC-TREE-SCROLL
	((CURRENT-TREE NIL))
	(SCROLL-MOUSE-MIXIN SCROLL-WINDOW-WITH-TYPEOUT)
  :GETTABLE-INSTANCE-VARIABLES)

(DEFMETHOD (BASIC-TREE-SCROLL :SET-TREE) (TREE)
  (SETQ CURRENT-TREE TREE)
  (FUNCALL-SELF ':SET-DISPLAY-ITEM (FUNCALL TREE ':SCROLL-ITEM)))

(DEFFLAVOR TREE
	(OBJECT
	 PRINT-STRING
	 INDENTATION
	 (INFERIORS NIL)
	 (SUPERIOR NIL)
	 (INFERIORS-VISIBLE NIL))
	()
  :GETTABLE-INSTANCE-VARIABLES
  :INITABLE-INSTANCE-VARIABLES
  (:SETTABLE-INSTANCE-VARIABLES INFERIORS-VISIBLE OBJECT))

(DEFMETHOD (TREE :SCROLL-ITEM) (&OPTIONAL (INDENT 0))
  (SETQ INDENTATION INDENT)
  (FUNCALL-SELF ':LINE-REDISPLAY)
  (LIST ()
	(SCROLL-PARSE-ITEM
	  ':MOUSE `(TREE-MOUSE ,SELF)
	  `(:FUNCTION ,SELF (:PRINT-STRING)))
	(SCROLL-MAINTAIN-LIST `(LAMBDA () (FUNCALL ',SELF ':VISIBLE-INFERIORS))
			      `(LAMBDA (TREE)
				 (FUNCALL TREE ':SCROLL-ITEM ,(1+ INDENT))))))

(DEFMETHOD (TREE :LINE-REDISPLAY) ()
  (SETQ PRINT-STRING
	(LET ((STRING (WITH-OUTPUT-TO-STRING (STREAM)
			(DOTIMES (I INDENTATION)
			  (FUNCALL STREAM ':TYO #\SP))
			(FUNCALL-SELF ':DISPLAY-OBJECT STREAM))))
	  (STRING-TRIM '(#\CR) STRING))))

(DEFMETHOD (TREE :DISPLAY-OBJECT) (STREAM)
  (PRIN1 OBJECT STREAM))

(DEFMETHOD (TREE :VISIBLE-INFERIORS) ()
  (AND INFERIORS-VISIBLE INFERIORS))

(DEFMETHOD (TREE :OPEN-OBJECT) ()
  (FUNCALL-SELF ':SET-INFERIORS-VISIBLE T))

(DEFMETHOD (TREE :CLOSE-OBJECT) ()
   (FUNCALL-SELF ':SET-INFERIORS-VISIBLE NIL))


(DEFFLAVOR MOUSABLE-TREE-SCROLL-MIXIN () ()
  (:INCLUDED-FLAVORS BASIC-TREE-SCROLL))

(DEFMETHOD (MOUSABLE-TREE-SCROLL-MIXIN :TREE-INTERPRET-CHAR) (CH)
  (COND ((CHAR-EQUAL CH #/Q)
	 (FUNCALL-SELF ':BURY))
	((CHAR-EQUAL CH #\CLEAR-SCREEN)
	 (FUNCALL-SELF ':REDISPLAY T))
	(T (TV:BEEP))))



(DEFMETHOD (MOUSABLE-TREE-SCROLL-MIXIN :TREE-INTERPRET-BLIP) (BLIP)
  (SELECTQ (FIRST BLIP)
    (TREE-MOUSE
     (LET ((TREE (SECOND (SECOND BLIP))))
	 (SELECTQ (FOURTH BLIP)
	   (#\MOUSE-1-1 (FUNCALL TREE ':OPEN-OBJECT))
	   (#\MOUSE-2-1 (LET ((PARENT (FUNCALL TREE ':SUPERIOR)))
			  (IF PARENT
			      (FUNCALL PARENT ':CLOSE-OBJECT)
			      (TV:BEEP))))
	   (#\MOUSE-3-1 (FUNCALL-SELF ':EDIT-OBJECT TREE)))))))

(DEFMETHOD (MOUSABLE-TREE-SCROLL-MIXIN :WHO-LINE-DOCUMENTATION-STRING) ()
  "L: Open object.  M: Close containing object. R: Edit object.")

(DEFFLAVOR TREE-SCROLL-WINDOW () (TV:PROCESS-MIXIN MOUSABLE-TREE-SCROLL-MIXIN
				  BASIC-TREE-SCROLL))

(DEFMETHOD (TREE-SCROLL-WINDOW :BEFORE :INIT) (&REST IGNORE)
  (OR TV:PROCESS
      (SETQ TV:PROCESS '(TREE-TOP-LEVEL :SPECIAL-PDL-SIZE 4000
					:REGULAR-PDL-SIZE 10000))))

(DEFUN TREE-TOP-LEVEL (WINDOW)
  (DO ((CH)
       (TERMINAL-IO (FUNCALL WINDOW ':TYPEOUT-WINDOW)))
      (NIL)
    (*CATCH 'SYS:COMMAND-LEVEL
      (SETQ CH (FUNCALL WINDOW ':TYI))
      (IF (ATOM CH)	
	  (FUNCALL WINDOW ':TREE-INTERPRET-CHAR CH)
	  (FUNCALL WINDOW ':TREE-INTERPRET-BLIP CH)))
    (FUNCALL WINDOW ':REDISPLAY)))

(COMPILE-FLAVOR-METHODS BASIC-TREE-SCROLL MOUSABLE-TREE-SCROLL-MIXIN TREE TREE-SCROLL-WINDOW)

;;;--------------------------------------------------------------------------------

;; I dont think anybody uses list-trees.

(DEFFLAVOR LIST-TREE () (TREE))

(DEFMETHOD (LIST-TREE :AFTER :INIT) (IGNORE)
  (AND (LISTP OBJECT)
       (SETQ INFERIORS (LOOP FOR X IN OBJECT
			     COLLECT (MAKE-INSTANCE 'LIST-TREE ':OBJECT X ':SUPERIOR SELF)))))

(DEFUN MAKE-TREE-FROM-LIST (LIST)
  (MAKE-INSTANCE 'LIST-TREE ':OBJECT LIST))

(COMPILE-FLAVOR-METHODS LIST-TREE)
;;;--------------------------------------------------------------------------------

(DEFFLAVOR FILE-TREE ()
	   (TREE)
  )

(DEFMETHOD (FILE-TREE :DISPLAY-OBJECT) (STREAM)
  (ZWEI:DEFAULT-LIST-ONE-FILE OBJECT STREAM))

(DEFMETHOD (FILE-TREE :EDIT) (WINDOW)
  (TREE-EDIT-FILE SELF WINDOW))

(DEFFLAVOR DIRECTORY-TREE ((DIR-IN-DIR-FORM)
			   (INFERIORS-PATHNAME NIL)
			   (MATCH-PATHNAME NIL))
	   (TREE)
  (:INITABLE-INSTANCE-VARIABLES DIR-IN-DIR-FORM)
  (:GETTABLE-INSTANCE-VARIABLES DIR-IN-DIR-FORM)
  (:SETTABLE-INSTANCE-VARIABLES MATCH-PATHNAME))


(DEFMETHOD (DIRECTORY-TREE :DECACHE-INFERIORS) ()
  (SETQ INFERIORS-PATHNAME NIL))

(DEFMETHOD (DIRECTORY-TREE :BEFORE :VISIBLE-INFERIORS) ()
  (IF (NULL MATCH-PATHNAME)
      (FUNCALL-SELF ':DEFAULT-MATCH-PATHNAME))	;take this out, window sys problems occur
						;when you try to abort the chaos error.
  (OR (NOT INFERIORS-VISIBLE)
      INFERIORS-PATHNAME
      (SETQ INFERIORS-PATHNAME MATCH-PATHNAME
	    INFERIORS (FUNCALL-SELF ':GENERATE-INFERIORS-LIST))))

(DEFMETHOD (DIRECTORY-TREE :GENERATE-INFERIORS-LIST) ()
  (LOOP FOR FILE IN (SORT (CDR
			    (FUNCALL MATCH-PATHNAME ':LIST-DIR-NO-SUBDIR-INFO ':DELETED))
			  #'TREE-EDIT-SORT)
	COLLECT
	(OR (DOLIST (OLD-INF INFERIORS)
	      ;; EQ pathnamery depended upon here!
	      (COND ((EQ (CAR (FUNCALL OLD-INF ':OBJECT)) (CAR FILE))
		     (SETQ INFERIORS (DELQ OLD-INF INFERIORS))
		     (FUNCALL OLD-INF ':SET-OBJECT FILE)
		     (RETURN OLD-INF))))
	    (MAKE-INSTANCE
	      (IF (GET FILE ':DIRECTORY)
		  'DIRECTORY-TREE
		  'FILE-TREE)
	      ':OBJECT FILE ':SUPERIOR SELF))))


(DEFMETHOD (DIRECTORY-TREE :AFTER :INIT) (IGNORE)
  (IF (NULL DIR-IN-DIR-FORM)
      (AND (BOUNDP 'OBJECT)			;could be root-topnode ---
						;which, believe it or not, should be
						;a subflavor of this flavor...
	   (SETQ DIR-IN-DIR-FORM (FUNCALL (CAR OBJECT) ':PATHNAME-AS-DIRECTORY))))
  (IF (NULL MATCH-PATHNAME)
      (FUNCALL-SELF ':DEFAULT-MATCH-PATHNAME)))

(DEFMETHOD (DIRECTORY-TREE :BEFORE :OPEN-OBJECT) ()
  (FUNCALL-SELF ':DEFAULT-MATCH-PATHNAME))

(DEFMETHOD (DIRECTORY-TREE :EDIT) (WINDOW)
  (TREE-EDIT-DIRECTORY SELF WINDOW))

(DEFUN WILDIFY-PATHNAME (PATHNAME)
  (FUNCALL PATHNAME ':NEW-PATHNAME ':NAME ':WILD ':TYPE ':WILD ':VERSION ':WILD))


(DEFMETHOD (DIRECTORY-TREE :DEFAULT-MATCH-PATHNAME) ()
  (FUNCALL-SELF ':SET-MATCH-PATHNAME (WILDIFY-PATHNAME DIR-IN-DIR-FORM)))

(DEFMETHOD (DIRECTORY-TREE :AFTER :SET-MATCH-PATHNAME) (IGNORE)
  (IF (NULL (FUNCALL MATCH-PATHNAME ':VERSION))	;dont let fs:directory-list default it.Mike?
      (SETQ MATCH-PATHNAME (FUNCALL MATCH-PATHNAME ':NEW-VERSION ':UNSPECIFIC)))
  (SETQ INFERIORS-PATHNAME NIL))		;cause re-listing

(DEFUN TREE-EDIT-SORT (F1 F2)
  (LET ((PN1 (CAR F1))
	(PN2 (CAR F2))
	(1DIR (NOT (NULL (GET F1 ':DIRECTORY))))
	(2DIR (NOT (NULL (GET F2 ':DIRECTORY)))))
    (IF (EQ 1DIR 2DIR)
	(FS:PATHNAME-LESSP PN1 PN2) 
	1DIR)))	

(DEFMETHOD (DIRECTORY-TREE :AFTER :SET-INFERIORS-VISIBLE) (IGNORE)
  (FUNCALL-SELF ':LINE-REDISPLAY))

(DEFMETHOD (DIRECTORY-TREE :DISPLAY-OBJECT) (STREAM)
  (IF (NOT (ZEROP INDENTATION))
      (FORMAT STREAM "~A     " (IF (GET OBJECT ':DELETED) "D" " ")))
  (IF INFERIORS-VISIBLE
      (PROGN
	(IF (NULL INFERIORS-PATHNAME)
	    (FUNCALL-SELF ':VISIBLE-INFERIORS))
	(FORMAT STREAM "~A" MATCH-PATHNAME))
      (FORMAT STREAM "~A" (FUNCALL DIR-IN-DIR-FORM ':STRING-FOR-DIRECTORY))))

(DEFFLAVOR TREE-LIST-TOPNODE ()
	   (DIRECTORY-TREE)
  (:DEFAULT-INIT-PLIST :INDENTATION 0 :INFERIORS-VISIBLE T))

(DEFMETHOD (TREE-LIST-TOPNODE :AFTER :INIT) (&REST IGNORE)
  (FUNCALL-SELF ':VISIBLE-INFERIORS))

(DEFFLAVOR TREE-LIST-ROOT-TOPNODE (SAMPLE-PATH PRINREP OPEN-PRINREP ROOT-MEANINGFUL-P)
	   (TREE-LIST-TOPNODE)
  (:INITABLE-INSTANCE-VARIABLES SAMPLE-PATH PRINREP)
  (:DEFAULT-INIT-PLIST :PRINREP "All Directories"))

(DEFMETHOD (TREE-LIST-ROOT-TOPNODE :BEFORE :INIT) (&REST IGNORE)
  (SETQ ROOT-MEANINGFUL-P
	(NOT (NULL (MEMQ ':DIRECTORY-PATHNAME-AS-FILE
			 (FUNCALL SAMPLE-PATH ':WHICH-OPERATIONS))))))

(DEFMETHOD (TREE-LIST-ROOT-TOPNODE :AFTER :INIT) (&REST IGNORE)
  (IF ROOT-MEANINGFUL-P
      (SETQ DIR-IN-DIR-FORM (FUNCALL SAMPLE-PATH ':NEW-DIRECTORY ':ROOT)
	    PRINREP (FUNCALL DIR-IN-DIR-FORM ':STRING-FOR-DIRECTORY))
      (SETQ PRINREP (STRING-APPEND "All Directories - "
				   (FUNCALL (FUNCALL SAMPLE-PATH ':HOST)
					    ':STRING-FOR-PRINTING))))
  (IF (NULL OPEN-PRINREP) (SETQ OPEN-PRINREP PRINREP)))

(DEFMETHOD (TREE-LIST-ROOT-TOPNODE :DISPLAY-OBJECT) (STREAM)
  (IF INFERIORS-VISIBLE
      (PRINC OPEN-PRINREP STREAM)
      (PRINC PRINREP STREAM)))

(DEFMETHOD (TREE-LIST-ROOT-TOPNODE :DEFAULT-MATCH-PATHNAME) (&REST IGNORE)
  (SETQ MATCH-PATHNAME
	(FUNCALL SAMPLE-PATH ':NEW-PATHNAME ':DIRECTORY ':ROOT
		 ':NAME ':WILD ':TYPE ':WILD ':VERSION ':WILD )
	OBJECT (LIST MATCH-PATHNAME ':DIRECTORY ':SORT-OF))
  (IF ROOT-MEANINGFUL-P
      (SETQ OPEN-PRINREP (FUNCALL MATCH-PATHNAME ':STRING-FOR-PRINTING))))

(DEFMETHOD (TREE-LIST-ROOT-TOPNODE :EDIT) (WINDOW)
  (IF ROOT-MEANINGFUL-P
      (TREE-EDIT-DIRECTORY SELF WINDOW)
      (TREE-EDIT-ILLEGAL SELF WINDOW)))
	
(DEFMETHOD (TREE-LIST-ROOT-TOPNODE :GENERATE-INFERIORS-LIST) ()
  (LOOP FOR FILE IN (SORT (FUNCALL SAMPLE-PATH ':LIST-ROOT) #'TREE-EDIT-SORT)
	COLLECT
	(OR (DOLIST (OLD-INF INFERIORS)
	      ;; EQ pathnamery depended upon here!
	      (COND ((EQ (CAR (FUNCALL OLD-INF ':OBJECT)) (CAR FILE))
		     (SETQ INFERIORS (DELQ OLD-INF INFERIORS))
		     (FUNCALL OLD-INF ':SET-OBJECT FILE)
		     (RETURN OLD-INF))))
	    (IF (GET FILE ':DIRECTORY)
		(MAKE-INSTANCE 'DIRECTORY-TREE ':DIR-IN-DIR-FORM (CAR FILE)
			       ':SUPERIOR SELF
			       ':Object FILE)	;shouldn't use but for above compare
	        (MAKE-INSTANCE 'FILE-TREE ':OBJECT FILE ':SUPERIOR SELF)))))

(COMPILE-FLAVOR-METHODS FILE-TREE DIRECTORY-TREE TREE-LIST-TOPNODE TREE-LIST-ROOT-TOPNODE)

;;;----------------------------------------------------------------------


(DEFFLAVOR HIERARCHY-EDITOR () (TREE-SCROLL-WINDOW)
  (:DEFAULT-INIT-PLIST :SAVE-BITS ':DELAYED))

(DEFMETHOD (HIERARCHY-EDITOR :WHO-LINE-DOCUMENTATION-STRING) ()
  "L: Open directory.      M: Close containing directory.    R: Menu")

(DEFMETHOD (HIERARCHY-EDITOR :BEFORE :INIT) (IGNORE)
  (OR TV:PROCESS
      (SETQ TV:PROCESS '(HIERARCHY-TOP-LEVEL :SPECIAL-PDL-SIZE 4000
					     :REGULAR-PDL-SIZE 10000))))

(DEFUN HIERARCHY-TOP-LEVEL (WINDOW)
  (LET ((TERMINAL-IO (FUNCALL WINDOW ':TYPEOUT-WINDOW)))
    (OR (FUNCALL WINDOW ':CURRENT-TREE)
	(FUNCALL WINDOW ':SET-TREE (MAKE-INSTANCE 'ROOT-DIRECTORY)))
    (TREE-TOP-LEVEL WINDOW)))


(DEFMETHOD (HIERARCHY-EDITOR :EDIT-OBJECT) (TREE)
  (FUNCALL TREE ':EDIT SELF))

(COMPILE-FLAVOR-METHODS HIERARCHY-EDITOR)


(DEFUN TREE-EDIT-DIRECTORY (TREE WINDOW)
  (LET* ((OBJECT (FUNCALL TREE ':OBJECT))
	 (PATHNAME (CAR OBJECT))
	 (DIRPATH (FUNCALL TREE ':DIR-IN-DIR-FORM))
	 (CHOICE (MENU-CHOOSE
		   `(,(IF (GET OBJECT ':DELETED)
			  '("Undelete" :VALUE :UNDELETE
			    :DOCUMENTATION "Undelete this directory.")
			  '("Delete" :VALUE :DELETE
			    :DOCUMENTATION "Mark this directory as deleted."))
		     ,@(IF (FUNCALL TREE ':INFERIORS-VISIBLE)
			   (LIST '("Close" :VALUE :CLOSE
				   :DOCUMENTATION
				   "Remove listing of inferiors from display.")
				 '("Decache" :VALUE :DECACHE
				 :DOCUMENTATION
				 "Recompute display of this directory from latest data"))
			   (LIST '("Open" :VALUE :OPEN
				   :DOCUMENTATION "List inferiors to this display.")
				 '("Selective open" :VALUE :SEL-OPEN
				   :DOCUMENTATION
				   "Open to selected files in this directory.")))
		     ("Expunge" :VALUE :EXPUNGE :DOCUMENTATION
		      "Remove all deleted files in this directory")
		     ("Create Inferior Directory" :VALUE :CRDIR :DOCUMENTATION
		      "Create a new directory inferior to this directory")
		     ("View Properties" :VALUE :VIEW-PROPERTIES
		      :DOCUMENTATION "View all available information about this directory.")
		     ("Edit Properties" :VALUE :EDIT-PROPERTIES
		      :DOCUMENTATION "Edit properties of directory")
		     ("New Property" :VALUE :PUTPROP
		      :DOCUMENTATION
		      "Add or remove a user-defined file property from this directory")
		     ("Create link" :VALUE :LINK
		      :DOCUMENTATION "Create a file system link.")
		     ("Rename" :VALUE :RENAME :DOCUMENTATION "Rename this directory.")
		     ("Link Transparencies" :VALUE :LINK-XPAR
		      :DOCUMENTATION "Edit default link transparency attributes.")
		     ("Dump" :VALUE :DUMP :DOCUMENTATION
		      "Invoke the backup dumper on this directory and all its inferiors."))
		   (STRING-APPEND "Directory operations: " (FUNCALL DIRPATH
								    ':STRING-FOR-DIRECTORY))
		   '(:MOUSE) NIL WINDOW)))
    (SELECTQ CHOICE
      (:LINK-XPAR
               (LET ((CHANGE-RESULT
		       (TREE-EDIT-TRANSPARENCIES
			 (FORMAT NIL "Default link transparencies for ~A"
				 (FUNCALL DIRPATH ':STRING-FOR-DIRECTORY))
			 (TREE-EDIT-ATTRIBUTE-UPDATE OBJECT ':DEFAULT-LINK-TRANSPARENCIES))))
		 (IF CHANGE-RESULT
		     (FS:CHANGE-FILE-PROPERTIES PATHNAME T ':DEFAULT-LINK-TRANSPARENCIES
						CHANGE-RESULT))))
      (:LINK     (LET ((FILEPATH
			 (TREE-EDIT-READ-LOCAL-PATH DIRPATH
						    "File name of the link itself? ")))
		   (COND ((NULL FILEPATH))	;punt
			 ((FUNCALL FILEPATH ':DIRECTORY)
			  (FORMAT T "You may not specify a directory here."))
			 (T
			  (LET ((TARGET
				  (TREE-EDIT-READ-LOCAL-PATH
				    FILEPATH "Path to link to? (target) ")))
			    (IF TARGET
				(LET ((RESULT
					(FUNCALL
					  (FUNCALL FILEPATH ':NEW-DIRECTORY
						   (FUNCALL DIRPATH ':DIRECTORY))
					  ':CREATE-LINK TARGET)))
				  (IF (EQ RESULT T)
				      (FUNCALL TREE ':DECACHE-INFERIORS)
				      (FORMAT T "~&~A" RESULT)))))))
		   (TREE-EDIT-END-TYPEOUT)))
      (:EXPUNGE
		(MULTIPLE-VALUE-BIND
		  (RECORDS ERRORS)
		    (FUNCALL (FUNCALL TREE ':MATCH-PATHNAME) ':EXPUNGE)
		  (FORMAT T "~&~D record~:P reclaimed." RECORDS)
		  (IF (AND ERRORS (LISTP ERRORS))
		      (PROGN
			(FORMAT T "~&There were errors encountered:")
			(MAPC 'PRINT ERRORS))
		      (FORMAT T "~&There were no errors encountered.")))
		(FUNCALL TREE ':DECACHE-INFERIORS)
		(TREE-EDIT-END-TYPEOUT))
      (:CRDIR (IF (EQ (TREE-EDIT-CREATE-DIR DIRPATH) T)
		  (FUNCALL TREE ':DECACHE-INFERIORS))
	      (TREE-EDIT-END-TYPEOUT))
      (:DECACHE  (FUNCALL TREE ':DECACHE-INFERIORS))
      (:OPEN (FUNCALL TREE ':DEFAULT-MATCH-PATHNAME)
	     (FUNCALL TREE ':SET-INFERIORS-VISIBLE T))
      (:SEL-OPEN
             (DO () (())
	       (LET ((STARPATH (TREE-EDIT-READ-LOCAL-PATH DIRPATH
				 "File name to match as starname:")))
		 (IF STARPATH
		     (IF (FUNCALL STARPATH ':DIRECTORY)
			 (TV:NOTIFY NIL "Don't specify a directory, please")
			 (PROGN
			   (FUNCALL TREE
				    ':SET-MATCH-PATHNAME
				    (FUNCALL STARPATH ':NEW-PATHNAME
					     ':DIRECTORY (FUNCALL DIRPATH ':DIRECTORY)
					     ':DEVICE (FUNCALL DIRPATH ':DEVICE)))
			   (FUNCALL TREE ':SET-INFERIORS-VISIBLE T)
			   (RETURN)))))))
      (:CLOSE (FUNCALL TREE ':SET-INFERIORS-VISIBLE NIL))
      (:DUMP  (LMFS:BACKUP-DUMPER ':DUMP-TYPE ':COMPLETE
				  ':START-PATH (WILDIFY-PATHNAME DIRPATH))
	      (TREE-EDIT-END-TYPEOUT))
      (T      (COND ((MEMQ ':DIRECTORY-PATHNAME-AS-FILE (FUNCALL DIRPATH ':WHICH-OPERATIONS))
		     (TREE-EDIT-COMMON CHOICE OBJECT
				       (FUNCALL DIRPATH ':DIRECTORY-PATHNAME-AS-FILE) TREE))
		    (T
		     (FORMAT T "~&Directory attribute operations are not supported on this file system.")
		     (TREE-EDIT-END-TYPEOUT))))))) 

(DEFUN TREE-EDIT-FILE (TREE WINDOW)
  (LET* ((OBJECT (FUNCALL TREE ':OBJECT))
	 (PATHNAME (CAR OBJECT))
	 (CHOICE (MENU-CHOOSE
		   `(,(IF (GET OBJECT ':DELETED)
			  '("Undelete" :VALUE :UNDELETE
			    :DOCUMENTATION "Undelete this file.")
			  '("Delete" :VALUE :DELETE :DOCUMENTATION "Delete this file"))
		     ,@ (IF (GET OBJECT ':LINK-TO)
			    (LIST '("Edit Link Transparencies"
				    :VALUE :EDIT-LINK-TRANSPARENCIES
				    :DOCUMENTATION "Edit link transparency properties")))
		     ("View" :VALUE :VIEW :DOCUMENTATION
		      "Print out the contents of this file.")
		     ("Rename":VALUE :RENAME :DOCUMENTATION "Rename this file.")
		     ("View Properties" :VALUE :VIEW-PROPERTIES
		      :DOCUMENTATION "View all known information about this file")
		     ("Edit Properties" :VALUE :EDIT-PROPERTIES
		      :DOCUMENTATAION "Edit properties of file")
		     ("New Property" :VALUE :PUTPROP
		      :DOCUMENTATION
		      "Add or remove a user-defined file property from this file")
		     ("Hardcopy" :VALUE :HARDCOPY
		      "Print this file on the local hardcopy device")
		     ("Dump" :VALUE :DUMP :DOCUMENTATION "Dump this file to tape."))
		   (STRING-APPEND "File operations: " (STRING PATHNAME))
		   '(:MOUSE) NIL WINDOW)))
    (SELECTQ CHOICE
      (:EDIT-LINK-TRANSPARENCIES
               (LET ((CHANGE-RESULT
		       (TREE-EDIT-TRANSPARENCIES
			 (FORMAT NIL "Link transparency attributes for ~A" PATHNAME)
			 (TREE-EDIT-ATTRIBUTE-UPDATE OBJECT ':LINK-TRANSPARENCIES))))
		 (IF CHANGE-RESULT
		     (FS:CHANGE-FILE-PROPERTIES PATHNAME T
						':LINK-TRANSPARENCIES CHANGE-RESULT))))
      (:HARDCOPY  (PROCESS-RUN-FUNCTION "FSEdit Hardcopy" 'PRESS:HARDCOPY-VIA-MENUS PATHNAME))
      (:VIEW   (WITH-OPEN-FILE
		  (STREAM PATHNAME ':PRESERVE-DATES T ':DELETED T)
		 (STREAM-COPY-UNTIL-EOF STREAM TERMINAL-IO))
	       (TREE-EDIT-END-TYPEOUT))
      (:DUMP (LMFS:BACKUP-DUMPER ':DUMP-TYPE ':COMPLETE ':START-PATH PATHNAME)
	     (TREE-EDIT-END-TYPEOUT))
      (T     (TREE-EDIT-COMMON CHOICE OBJECT PATHNAME TREE)))))

(DEFUN TREE-EDIT-ILLEGAL (IGNORE IGNORE)
  (FORMAT T "~&Editing operations are not available at this level.")
  (TREE-EDIT-END-TYPEOUT))

(DEFUN TREE-EDIT-COMMON (CHOICE OBJECT PATHNAME TREE)
  (SELECTQ CHOICE
    (:EDIT-PROPERTIES (ZWEI:CHANGE-FILE-PROPERTIES PATHNAME))
    (:RENAME      (LET* ((NEWNAME (TREE-EDIT-READ-LOCAL-PATH
				    PATHNAME "~&New name for ~A" PATHNAME)))
		    (COND ((NULL NEWNAME))	;punted or erred
			  ((GET OBJECT ':DIRECTORY)
			   (IF (OR (FUNCALL NEWNAME ':DIRECTORY)
				   (FUNCALL NEWNAME ':TYPE)
				   (FUNCALL NEWNAME ':VERSION))
			       (PROGN
				 (FORMAT T "~&New directory name may not have directory, type, or version.")
				 (SETQ NEWNAME NIL))
			       (SETQ NEWNAME (FUNCALL NEWNAME ':NEW-PATHNAME
						      ':TYPE ':DIRECTORY ':VERSION 1))))
			  ((NULL (FUNCALL NEWNAME ':DIRECTORY))
			   (SETQ NEWNAME (FUNCALL NEWNAME ':NEW-DIRECTORY
						  (FUNCALL PATHNAME ':DIRECTORY)))))
		    (IF NEWNAME			;hasnt erred out yet..
			(LET ((RESULT (RENAMEF PATHNAME NEWNAME)))
			  (IF (EQ RESULT T)
			      (FUNCALL (FUNCALL TREE ':SUPERIOR) ':DECACHE-INFERIORS)
			      (FORMAT T "~&~A" RESULT))))))
    (:DELETE      (LET ((RESULT (FUNCALL PATHNAME ':DELETE)))
		    (IF (EQ RESULT T)
			(PROGN
			  (PUTPROP OBJECT T ':DELETED)
			  (FUNCALL TREE ':LINE-REDISPLAY))
			(FORMAT T "~&Can't delete ~A:~%~A" PATHNAME RESULT))))
    (:UNDELETE    (LET ((RESULT (FUNCALL PATHNAME ':CHANGE-PROPERTIES NIL ':DELETED NIL)))
		    (IF (EQ RESULT T)
			(PROGN
			  (PUTPROP OBJECT NIL ':DELETED)
			  (FUNCALL TREE ':LINE-REDISPLAY))
			(FORMAT T "~&Can't undelete ~A:~%~A" PATHNAME RESULT))))
    (:VIEW-PROPERTIES
		  (LET ((ATTR (FS:FILE-PROPERTIES PATHNAME NIL)))
		    (IF (STRINGP ATTR)
			(FORMAT T "Error ~A for ~A" ATTR PATHNAME)
			(PROGN
			  (FORMAT T "Properties for ~A~2%" PATHNAME)
			  (LOOP FOR (IND PROP) ON (CDR ATTR) BY 'CDDR
				DO
				(FORMAT T "~&~A~30T" (ZWEI:PRETTY-COMMAND-NAME
						       (STRING-APPEND IND)))	;he CLOBBERS!
				(FUNCALL (LOOP FOR ITEM IN FS:*KNOWN-DIRECTORY-PROPERTIES*
					       FINALLY (RETURN #'PRINC)
					       DO
					       (IF (DOLIST (NAME (CDR ITEM))
						     (IF (STRING-EQUAL IND NAME)
							 (RETURN T)))
						   (RETURN (OR (CADAR ITEM) 'PRINC))))
					 PROP STANDARD-OUTPUT))))))
    (:PUTPROP    (LET ((PROP (ZWEI:TYPEIN-LINE-READLINE-NEAR-WINDOW
				 ':MOUSE "Name of Property for ~A" PATHNAME)))
		   (IF (NOT (EQ PROP T))
		       (LET ((VAL (ZWEI:TYPEIN-LINE-READLINE-NEAR-WINDOW
				    ':MOUSE
				    "String value of ~A for ~A (Null string REMPROPs)"
				    (SETQ PROP (INTERN (STRING-UPCASE PROP) "")) PATHNAME)))
			 (IF (EQUAL VAL "") (SETQ VAL NIL))
			 (COND ((EQ VAL T))
			       ((FS:CHANGE-FILE-PROPERTIES PATHNAME T PROP VAL)))))))
    )						;end SELECTQ
    (TREE-EDIT-END-TYPEOUT)
    )


;;; I would fix PEEK to do this if I could maintain that source...
(DEFUN TREE-EDIT-END-TYPEOUT ()
  (COND ((FUNCALL TERMINAL-IO ':INCOMPLETE-P)
	 (FORMAT T "~&Type any character to flush:")
	 (LET ((CHAR (FUNCALL TERMINAL-IO ':TYI)))
	   (FUNCALL TERMINAL-IO ':MAKE-COMPLETE)
	   ;; The change of substance is EQUAL here to make mouse blips not blow out
	   (OR (EQUAL CHAR #\SPACE) (FUNCALL TERMINAL-IO ':UNTYI CHAR)))))
  (FUNCALL (FUNCALL TERMINAL-IO ':SUPERIOR) ':REDISPLAY))

(DEFUN TREE-EDIT-CREATE-DIR (PARCOND)		;in typeout window now
  (IF (AND (MEMQ ':DIRECTORY-PATHNAME-AS-FILE (FUNCALL PARCOND ':WHICH-OPERATIONS))
	   (GET (FUNCALL (FUNCALL PARCOND ':DIRECTORY-PATHNAME-AS-FILE) ':PROPERTIES)
		':DELETED))
      (FORMAT T "~&~A has been deleted" (FUNCALL PARCOND ':STRING-FOR-DIRECTORY))
      (LET ((PARSED (TREE-EDIT-READ-LOCAL-PATH
		      PARCOND
		      "~&Please type file name for new directory, a son of ~A:~%"
		      (FUNCALL PARCOND ':STRING-FOR-DIRECTORY))))
	(COND ((NULL PARSED)
	       (FORMAT T "~&Invalid file name."))
	      ((OR (FUNCALL PARSED ':DIRECTORY)
		   (FUNCALL PARSED ':TYPE)
		   (FUNCALL PARSED ':VERSION))
	       (FORMAT T "~&A file name only, please."))
	      (T
	       (LET ((RESULT (OPEN (FUNCALL PARCOND ':NEW-NAME (FUNCALL PARSED ':NAME))
				   ':FLAVOR ':DIRECTORY)))
		 (OR (EQ RESULT T)
		     (FORMAT T "~&~A" RESULT))))))))

(DEFVAR *TREE-EDIT-READ-LOCAL-PATH-DEFAULT* NIL)

(DEFUN TREE-EDIT-READ-LOCAL-PATH (DEFAULT-PATH &REST FORMAT-ARGS)
  (OR *TREE-EDIT-READ-LOCAL-PATH-DEFAULT*
      (SETQ *TREE-EDIT-READ-LOCAL-PATH-DEFAULT* (FS:PARSE-PATHNAME "local:>")))
  (LET ((TYPEIN (LEXPR-FUNCALL #'ZWEI:TYPEIN-LINE-READLINE-NEAR-WINDOW ':MOUSE FORMAT-ARGS)))
    (IF (EQ TYPEIN T)				;he punted
	NIL
	(LET ((ANSWER
		(CAR (ERRSET
		       (FS:PARSE-PATHNAME
			 (STRING-TRIM " " TYPEIN)
			 NIL
			 (OR DEFAULT-PATH *TREE-EDIT-READ-LOCAL-PATH-DEFAULT*)) T))))
	  (IF (NULL ANSWER) (TREE-EDIT-END-TYPEOUT))
	  ANSWER))))

(DEFVAR *LINK-TRANSPARENCY-WINDOW* NIL)

(DEFFLAVOR LINK-ATTRIBUTE-KEYWORD-MENU ()
	   (ZWEI:POP-UP-ZMAIL-MULTIPLE-MENU)
  (:DEFAULT-INIT-PLIST :COLUMNS 5
    		       :SPECIAL-CHOICES '(("Abort" :VALUE :ABORT
						   :DOCUMENTATION "Abort this command.")
					  ("Do It" :VALUE :DO-IT
					   :DOCUMENTATION "Use highlighted items."))))

(DEFUN TREE-EDIT-TRANSPARENCIES (LABEL CURRENT)
  (IF (NULL *LINK-TRANSPARENCY-WINDOW*)
      (SETQ *LINK-TRANSPARENCY-WINDOW*
	    (TV:MAKE-WINDOW 'LINK-ATTRIBUTE-KEYWORD-MENU ':SUPERIOR SELECTED-WINDOW)))
  (FUNCALL *LINK-TRANSPARENCY-WINDOW* ':SET-LABEL LABEL)
  (MULTIPLE-VALUE-BIND (IGNORE NEW-TRANSPARENCIES)
      (FUNCALL *LINK-TRANSPARENCY-WINDOW*
	       ':MULTIPLE-CHOOSE
	       '(("Read" :VALUE :READ
		  :DOCUMENTATION "Link is transparent to openings for reading.")
		 ("Write" :VALUE :WRITE
		  :DOCUMENTATION "Link is transparent to openings for appending")
		 ("Create" :VALUE :CREATE
		  :DOCUMENTATION "Files will be created through the link")
		 ("Delete" :VALUE :DELETE
		  :DOCUMENTATION "Deletion will occur through the link")
		 ("Rename" :VALUE :RENAME
		  :DOCUMENTATION "Object described by link will be renamed"))
	       CURRENT)
    (IF (EQUAL NEW-TRANSPARENCIES CURRENT)	;nothing, ignore it, maybe guy aborted
	NIL
	(LIST
	  ':READ (NOT (NULL (MEMQ ':READ NEW-TRANSPARENCIES)))
	  ':WRITE (NOT (NULL (MEMQ ':WRITE NEW-TRANSPARENCIES)))
	  ':CREATE (NOT (NULL (MEMQ ':CREATE NEW-TRANSPARENCIES)))
	  ':DELETE (NOT (NULL (MEMQ ':DELETE NEW-TRANSPARENCIES)))
	  ':RENAME (NOT (NULL (MEMQ ':RENAME NEW-TRANSPARENCIES)))))))


(DEFUN TREE-EDIT-ATTRIBUTE-UPDATE (OBJECT IND)
  (LET ((PATHNAME (CAR OBJECT)))
    (LET ((PROPS (CDR (FS:FILE-PROPERTIES PATHNAME))))	;blow out if loses
      (AND PROPS (RPLACD OBJECT PROPS))		;beat those ^R typers...
      (IF IND					;could be random-update..
	  (OR (MEMQ IND (CDR OBJECT))		;cd really be nil..
	      (FERROR NIL "Can't get ~A for ~A" (ZWEI:PRETTY-COMMAND-NAME
						  (STRING-APPEND IND))
		      PATHNAME)))
      (AND IND (GET OBJECT IND)))))


(DEFMETHOD (FS:PATHNAME :LIST-DIR-NO-SUBDIR-INFO) (&REST ARGS)
  (FUNCALL-SELF ':DIRECTORY-LIST ARGS))

(DEFMETHOD (FS:PATHNAME :LIST-ROOT) (&OPTIONAL OPTIONS)
  (LOOP FOR L IN
	(FUNCALL (FUNCALL-SELF ':NEW-DIRECTORY ':WILD) ':ALL-DIRECTORIES OPTIONS)
	COLLECT
	(LIST (CAR L) ':DIRECTORY T)))

(DEFMETHOD (FS:MEANINGFUL-ROOT-MIXIN :LIST-ROOT) (&REST IGNORE)
  (LET ((WILDROOT (FUNCALL-SELF ':NEW-PATHNAME ':DIRECTORY ':ROOT
				':NAME ':WILD ':TYPE ':WILD ':VERSION ':WILD)))
    (LOOP FOR FILE IN (FUNCALL WILDROOT ':LIST-DIR-NO-SUBDIR-INFO)
	  COLLECT (CONS (AND (GET FILE ':DIRECTORY)
			     (FUNCALL (CAR FILE) ':PATHNAME-AS-DIRECTORY))
			(CDR FILE)))))

