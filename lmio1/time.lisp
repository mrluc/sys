;;; Date and time routines -*- Mode:LISP; Package:TIME -*-
;;; Note: days and months are kept one-based throughout, as much as possible.
;;; Days of the week are zero-based on Monday.

(DEFUN MICROSECOND-TIME (&AUX (INHIBIT-SCHEDULING-FLAG T))
  (LET ((LOW (%UNIBUS-READ 764120))  ;Hardware synchronizes if you read this one first
	(HIGH (%UNIBUS-READ 764122)))
    (DPB HIGH 2020 LOW)))

(DEFUN FIXNUM-MICROSECOND-TIME (&AUX (INHIBIT-SCHEDULING-FLAG T))
  (LET ((LOW (%UNIBUS-READ 764120))
	(HIGH (%UNIBUS-READ 764122)))
    (DPB HIGH 2007 LOW)))

;;; Conversion routines, universal time is seconds since 1-jan-00 00:00-GMT

(DEFVAR *TIMEZONE* 5)				;EST

;;; Hosts suspected of supporting time servers
(DEFVAR *TIME-SERVER-HOSTS* '("MC" "AI" "XX" "EE"))

;; Returns universal time from host over the net, as a 32-bit number
;; or if it can't get the time, returns a string which is the reason why not.
(DEFUN CHAOS-TIME (&OPTIONAL (HOST *TIME-SERVER-HOSTS*))
  (IF (LISTP HOST)
      (DO ((HOSTS HOST (CDR HOSTS))
	   (TIME))
	  ((NULL HOSTS) TIME)
	(SETQ TIME (CHAOS-TIME (CAR HOSTS)))
	(AND (NUMBERP TIME) (RETURN TIME)))
      (LET ((PKT (CHAOS:SIMPLE HOST "TIME" (* 4. 60.))))
	(IF (STRINGP PKT) PKT
	    (LET ((L16 (AREF PKT 10))
		  (U16 (AREF PKT 11)))
	      (CHAOS:RETURN-PKT PKT)
	      (DPB U16 2020 L16))))))

;;; One-based array of cumulative days per month.
(DEFVAR *CUMULATIVE-MONTH-DAYS-TABLE* (MAKE-ARRAY NIL 'ART-16B 13.))
(FILLARRAY *CUMULATIVE-MONTH-DAYS-TABLE*
	   '(0 0 31. 59. 90. 120. 151. 181. 212. 243. 273. 304. 334.))

;; Takes Univeral Time (seconds since 1/1/1900) as a 32-bit number
;; Algorithm from KLH's TIMRTS.
(DEFUN TIME-BREAK-UNIVERSAL (UNIVERSAL-TIME &OPTIONAL (TIMEZONE *TIMEZONE*)
					    &AUX SECS DAY MONTH YEAR DAY-OF-THE-WEEK DST-P)
  (DECLARE (RETURN-LIST SECS DAY MONTH YEAR DAY-OF-THE-WEEK DAYLIGHT-SAVINGS-P))
  (MULTIPLE-VALUE (SECS DAY MONTH YEAR DAY-OF-THE-WEEK)
    (TIME-BREAK-UNIVERSAL-WITHOUT-DST UNIVERSAL-TIME TIMEZONE))
  (AND (SETQ DST-P (DAYLIGHT-SAVINGS-TIME-P SECS DAY MONTH YEAR))
       ;; See if it's daylight savings time, time-zone number gets smaller if so.
       (MULTIPLE-VALUE (SECS DAY MONTH YEAR DAY-OF-THE-WEEK)
	 (TIME-BREAK-UNIVERSAL-WITHOUT-DST UNIVERSAL-TIME (1- TIMEZONE))))
  (PROG () (RETURN SECS DAY MONTH YEAR DAY-OF-THE-WEEK DST-P)))

(DEFUN TIME-BREAK-UNIVERSAL-WITHOUT-DST (UNIVERSAL-TIME &OPTIONAL (TIMEZONE *TIMEZONE*)
							&AUX X SECS DAY MONTH YEAR)
  (DECLARE (RETURN-LIST SECS DAY MONTH YEAR DAY-OF-THE-WEEK))
  (SETQ UNIVERSAL-TIME (- UNIVERSAL-TIME (* TIMEZONE 3600.)))
  (SETQ SECS (\ UNIVERSAL-TIME 86400.)		;(* 24. 60. 60.)
	X (// UNIVERSAL-TIME 86400.))		;Days since genesis.
  (LET ((B (\ X 365.))
	(A (// X 365.)))
    (COND ((NOT (ZEROP A))
	   (SETQ B (- B (LSH (1- A) -2)))
	   (COND ((< B 0)
		  (SETQ A (1- A))
		  (SETQ B (+ B 365.))
		  (AND (NOT (BIT-TEST A 3))
		       (SETQ B (1+ B)))))))
    (DO ((C 12. (1- C)))
	(( B (AREF *CUMULATIVE-MONTH-DAYS-TABLE* C))
	 (COND ((AND (NOT (BIT-TEST A 3))
		     (> C 2))
		(SETQ B (1- B))
		(AND (< B (AREF *CUMULATIVE-MONTH-DAYS-TABLE* C))
		     (SETQ C (1- C)))
		(AND (= C 2)
		     (SETQ B (1+ B)))))
	 (SETQ B (- B (AREF *CUMULATIVE-MONTH-DAYS-TABLE* C)))
	 (SETQ YEAR A)
	 (SETQ MONTH C)
	 (SETQ DAY (1+ B)))))
  (PROG () (RETURN SECS DAY MONTH YEAR (\ X 7))))

(DEFUN DAYLIGHT-SAVINGS-TIME-P (SECS DAY MONTH YEAR)
  (COND ((OR (< MONTH 4)	;Standard time if before 2 am last Sunday in April
	     (AND (= MONTH 4)
		  (LET ((LSA (LAST-SUNDAY-IN-APRIL YEAR)))
		    (OR (< DAY LSA)
			(AND (= DAY LSA) (< SECS 7200.))))))
	 NIL)
	((OR (> MONTH 10.)	;Standard time if after 1 am last Sunday in October
	     (AND (= MONTH 10.)
		  (LET ((LSO (LAST-SUNDAY-IN-OCTOBER YEAR)))
		    (OR (> DAY LSO)
			(AND (= DAY LSO) ( SECS 3600.))))))
	 NIL)
	(T T)))

;;; Domain-dependent knowledge
(DEFUN LAST-SUNDAY-IN-OCTOBER (YEAR)
  (LET ((LSA (LAST-SUNDAY-IN-APRIL YEAR)))
    ;; Days between April and October = 31+30+31+31+30 = 153  6 mod 7
    ;; Therefore the last Sunday in October is one less than the last Sunday in April
    ;; unless that gives 24. in which case it is 31.
    (IF (= LSA 25.) 31. (1- LSA))))

(DEFUN LAST-SUNDAY-IN-APRIL (YEAR)
  ;; This copied from GDWOBY routine in ITS
  (LET ((DOW-BEG-YEAR
	  (LET ((B (\ (+ YEAR 1899.) 400.)))
	    (\ (- (+ (1+ B) (SETQ B (// B 4))) (// B 25.)) 7)))
	(FEB29 (IF (ZEROP (\ YEAR 4)) 1 0)))	;Good enough for this century, and the next
    (LET ((DOW-APRIL-30 (\ (+ DOW-BEG-YEAR 119. FEB29) 7)))
      (- 30. DOW-APRIL-30))))

;;; Returns universal time, as a 32-bit number of seconds since 1/1/00 00:00-GMT
(DEFUN TIME-UNBREAK-UNIVERSAL (SECONDS DAY MONTH YEAR &OPTIONAL TIMEZONE &AUX TEM)
  (AND (> YEAR 1900.) (SETQ YEAR (- YEAR 1900.)))
  (OR TIMEZONE
      (SETQ TIMEZONE (IF (DAYLIGHT-SAVINGS-TIME-P SECONDS DAY MONTH YEAR)
			 (1- *TIMEZONE*) *TIMEZONE*)))
  (SETQ TEM (+ (1- DAY) (AREF *CUMULATIVE-MONTH-DAYS-TABLE* MONTH)
	       (// (1- YEAR) 4) (* YEAR 365.)))	;Number of days since 1/1/00.
  (AND (> MONTH 2) (ZEROP (\ YEAR 4))
       (SETQ TEM (1+ TEM)))			;After 29-Feb in a leap year.
  (+ SECONDS (* TEM 86400.) (* TIMEZONE 3600.)))	;Return number of seconds.

;;; Maintenance functions

(DEFVAR *LAST-TIME-UPDATE-TIME* NIL)
(DEFVAR *LAST-TIME-SECONDS*)
(DEFVAR *LAST-TIME-MINUTES*)
(DEFVAR *LAST-TIME-HOURS*)
(DEFVAR *LAST-TIME-DAY*)
(DEFVAR *LAST-TIME-MONTH*)
(DEFVAR *LAST-TIME-YEAR*)
(DEFVAR *LAST-TIME-DAY-OF-THE-WEEK*)
(DEFVAR *LAST-TIME-DAYLIGHT-SAVINGS-P*)

(DEFUN INITIALIZE-TIMEBASE (&AUX UT SECS)
  (SETQ UT (CHAOS-TIME))
  (COND ((STRINGP UT)
	 (SETQ *LAST-TIME-UPDATE-TIME* NIL)
	 NIL)
	(T
	 (WITHOUT-INTERRUPTS
	   (SETQ *LAST-TIME-UPDATE-TIME* (TIME))
	   (MULTIPLE-VALUE (SECS *LAST-TIME-DAY* *LAST-TIME-MONTH* *LAST-TIME-YEAR*
				 *LAST-TIME-DAY-OF-THE-WEEK* *LAST-TIME-DAYLIGHT-SAVINGS-P*)
	     (TIME-BREAK-UNIVERSAL UT))
	   (SETQ *LAST-TIME-SECONDS* (\ SECS 60.)
		 SECS (// SECS 60.))
	   (SETQ *LAST-TIME-MINUTES* (\ SECS 60.)
		 *LAST-TIME-HOURS* (// SECS 60.))
	   T))))

;This must not process-wait, since it can be called inside the scheduler via the who-line
(DEFUN UPDATE-TIMEBASE (&AUX TIME TICK)
  (COND ((NOT (NULL *LAST-TIME-UPDATE-TIME*))
	 (WITHOUT-INTERRUPTS
	   (SETQ TIME (TIME)
		 TICK (// (TIME-DIFFERENCE TIME *LAST-TIME-UPDATE-TIME*) 60.)
		 *LAST-TIME-UPDATE-TIME*
		    (LDB 0027 (%24-BIT-PLUS (* 60. TICK) *LAST-TIME-UPDATE-TIME*)))
	   (OR (ZEROP TICK)
	       (< (SETQ *LAST-TIME-SECONDS* (+ *LAST-TIME-SECONDS* TICK)) 60.)
	       (< (PROG1 (SETQ *LAST-TIME-MINUTES* (+ *LAST-TIME-MINUTES*
						      (// *LAST-TIME-SECONDS* 60.)))
			 (SETQ *LAST-TIME-SECONDS* (\ *LAST-TIME-SECONDS* 60.)))
		  60.)
	       (< (PROG1 (SETQ *LAST-TIME-HOURS* (+ *LAST-TIME-HOURS*
						    (// *LAST-TIME-MINUTES* 60.)))
			 (SETQ *LAST-TIME-MINUTES* (\ *LAST-TIME-MINUTES* 60.)))
		  24.)
	       (< (PROG1 (SETQ *LAST-TIME-DAY* (1+ *LAST-TIME-DAY*))
			 (SETQ *LAST-TIME-DAY-OF-THE-WEEK*
			       (\ (1+ *LAST-TIME-DAY-OF-THE-WEEK*) 7))
			 (SETQ *LAST-TIME-HOURS* 0))
		  (MONTH-LENGTH *LAST-TIME-MONTH* *LAST-TIME-YEAR*))
	       (< (SETQ *LAST-TIME-DAY* 1
			*LAST-TIME-MONTH* (1+ *LAST-TIME-MONTH*))
		  12.)
	       (SETQ *LAST-TIME-MONTH* 1
		     *LAST-TIME-YEAR* (1+ *LAST-TIME-YEAR*)))
	   T))
	((NOT (NULL CURRENT-PROCESS))
	 (INITIALIZE-TIMEBASE))
	(T (PROCESS-RUN-FUNCTION "GET TIME" #'INITIALIZE-TIMEBASE)
	   NIL)))	;Time not known yet, but will be soon

;;; One-based lengths of months
(DEFVAR *MONTH-LENGTHS* '(0 31. 28. 31. 30. 31. 30. 31. 31. 30. 31. 30. 31.))

(DEFUN MONTH-LENGTH (MONTH YEAR)
  (IF (= MONTH 2)
      (IF (ZEROP (\ YEAR 4)) 29. 28.)
      (NTH MONTH *MONTH-LENGTHS*)))

(DEFUN DAYLIGHT-SAVINGS-P ()
  (UPDATE-TIMEBASE)
  *LAST-TIME-DAYLIGHT-SAVINGS-P*)

(DEFUN DEFAULT-YEAR ()
  (UPDATE-TIMEBASE)
  *LAST-TIME-YEAR*)

;;; These are the functions the user should call
;;; If they can't find out what time it is, they return NIL
(DEFUN GET-TIME ()
  (DECLARE (RETURN-LIST SECONDS MINUTES HOURS DAY MONTH YEAR DAY-OF-THE-WEEK
			DAYLIGHT-SAVINGS-P))
  (AND (UPDATE-TIMEBASE)
       (PROG () (RETURN *LAST-TIME-SECONDS* *LAST-TIME-MINUTES* *LAST-TIME-HOURS*
			*LAST-TIME-DAY* *LAST-TIME-MONTH* *LAST-TIME-YEAR*
			*LAST-TIME-DAY-OF-THE-WEEK* *LAST-TIME-DAYLIGHT-SAVINGS-P*))))

(DEFUN WHAT-TIME (&OPTIONAL (STREAM STANDARD-OUTPUT))
  (AND (UPDATE-TIMEBASE)
       (MULTIPLE-VALUE-BIND (SECONDS MINUTES HOURS DAY MONTH YEAR)
	   (GET-TIME)
         (AND STREAM (TERPRI STREAM))
         (TIME-PRINT STREAM SECONDS MINUTES HOURS DAY MONTH YEAR))))

(DEFUN TIME-PRINT-UNIVERSAL (UT &OPTIONAL (STREAM STANDARD-OUTPUT) (TIMEZONE *TIMEZONE*))
  (MULTIPLE-VALUE-BIND (SECONDS DAY MONTH YEAR)
      (TIME-BREAK-UNIVERSAL UT TIMEZONE)
    (LET (MINUTES HOURS)
      (SETQ MINUTES (// SECONDS 60.)
	    SECONDS (\ SECONDS 60.))
      (SETQ HOURS (// MINUTES 60.)
	    MINUTES (\ MINUTES 60.))
      (TIME-PRINT STREAM SECONDS MINUTES HOURS DAY MONTH YEAR))))

(DEFUN TIME-PRINT (STREAM SECONDS MINUTES HOURS DAY MONTH YEAR)
  (FORMAT STREAM
	  '( "~D//" (D 2 60) "//" (D 2 60) " " (D 2 60) ":" (D 2 60) ":" (D 2 60) )
	       MONTH DAY           YEAR         HOURS        MINUTES	  SECONDS))

(DEFUN WHAT-DATE (&OPTIONAL (STREAM STANDARD-OUTPUT))
  (AND (UPDATE-TIMEBASE)
       (MULTIPLE-VALUE-BIND (SECONDS MINUTES HOURS DAY MONTH YEAR DAY-OF-THE-WEEK)
	   (GET-TIME)
         (AND STREAM (TERPRI STREAM))
         (DATE-PRINT STREAM SECONDS MINUTES HOURS DAY MONTH YEAR DAY-OF-THE-WEEK))))

(DEFUN DATE-PRINT-UNIVERSAL (UT &OPTIONAL (STREAM STANDARD-OUTPUT) (TIMEZONE *TIMEZONE*))
  (MULTIPLE-VALUE-BIND (SECONDS DAY MONTH YEAR DAY-OF-THE-WEEK)
      (TIME-BREAK-UNIVERSAL UT TIMEZONE)
    (LET (MINUTES HOURS)
      (SETQ MINUTES (// SECONDS 60.)
	    SECONDS (\ SECONDS 60.))
      (SETQ HOURS (// MINUTES 60.)
	    MINUTES (\ MINUTES 60.))
      (DATE-PRINT STREAM SECONDS MINUTES HOURS DAY MONTH YEAR DAY-OF-THE-WEEK))))

(DEFUN DATE-PRINT (STREAM SECONDS MINUTES HOURS DAY MONTH YEAR DAY-OF-THE-WEEK)
  (SETQ MONTH (MONTH-STRING MONTH)
	DAY-OF-THE-WEEK (DAY-OF-THE-WEEK-STRING DAY-OF-THE-WEEK))
  (FORMAT STREAM
	  "~A the ~:R of ~A, 19~D/; ~D:~2,48D:~2,48D ~:[am~;pm~]"
	  DAY-OF-THE-WEEK DAY MONTH YEAR (1+ (\ (+ HOURS 11.) 12.)) MINUTES SECONDS
	  ( HOURS 12.) ))

;;; Date and time in the who-line, continuously updating.

(DEFSTRUCT (NWATCH-WHO-ITEM :LIST (:INCLUDE TV:WHO-LINE-ITEM) (:CONSTRUCTOR NIL))
  NWATCH-WHO-STRING)

;;; Find out the time and start displaying it in the who-line
(DEFUN NWATCH-ON ()
  (NWATCH-OFF)	;Remove obsolete information from the who-line saved state
  (COND ((INITIALIZE-TIMEBASE)
	 (LET ((DEFAULT-CONS-AREA WORKING-STORAGE-AREA))  ;Just in case during compilation
	      (PUSH (LIST 'NWATCH-WHO-FUNCTION NIL 0 210 (STRING-APPEND "MM//DD//YY HH:MM:SS"))
		    TV:WHO-LINE-LIST)
	      (ADD-INITIALIZATION "NWATCH" '(NWATCH-ON) '(:WARM))))))

(DEFUN NWATCH-OFF ()
  (DELETE-INITIALIZATION "NWATCH" '(:WARM))
  (LET ((ITEM (ASSQ 'NWATCH-WHO-FUNCTION TV:WHO-LINE-LIST)))
    (COND (ITEM
	   (SETQ TV:WHO-LINE-LIST (DELQ ITEM TV:WHO-LINE-LIST))
	   (TV:WHO-LINE-PREPARE-FIELD ITEM)))))

(DEFUN NWATCH-LOGIN () (NWATCH-ON) '(NWATCH-OFF))

(DEFUN NWATCH-WHO-FUNCTION (ITEM)
  (LET ((STR (NWATCH-WHO-STRING ITEM))
	YEAR MONTH DAY HOURS MINUTES SECONDS LEFTX)
    (MULTIPLE-VALUE (SECONDS MINUTES HOURS DAY MONTH YEAR)
      (GET-TIME))
    (COND ((NOT (NULL SECONDS))
	   (SETQ LEFTX (MIN (NWATCH-N MONTH STR 0)
			    (NWATCH-N DAY STR 3)
			    (NWATCH-N YEAR STR 6)
			    (NWATCH-N HOURS STR 9)
			    (NWATCH-N MINUTES STR 12.)
			    (NWATCH-N SECONDS STR 15.)))
	   (OR (TV:WHO-LINE-ITEM-STATE ITEM) (SETQ LEFTX 0)) ;was clobbered, redisplay all
	   (LET ((X0 (* LEFTX TV:(SHEET-CHAR-WIDTH WHO-LINE-WINDOW))))
	     ;; Code copied from WHO-LINE-PREPARE-FIELD
	     TV:(%DRAW-RECTANGLE (- (WHO-LINE-ITEM-RIGHT TIME:ITEM) TIME:X0)
				 (SHEET-LINE-HEIGHT WHO-LINE-WINDOW)
				 TIME:X0 0
				 (SHEET-ERASE-ALUF WHO-LINE-WINDOW)
				 WHO-LINE-WINDOW)
	     (TV:SHEET-SET-CURSORPOS TV:WHO-LINE-WINDOW X0 0))
	   (TV:SHEET-STRING-OUT TV:WHO-LINE-WINDOW STR LEFTX)
	   (SETF (TV:WHO-LINE-ITEM-STATE ITEM) T)))))

;Returns first character position changed
(DEFUN NWATCH-N (N STR I)
  (LET ((DIG1 (+ (// N 10.) #/0))
	(DIG2 (+ (\ N 10.) #/0)))
    (PROG1 (COND ((NOT (= (AREF STR I) DIG1)) I)
		 ((NOT (= (AREF STR (1+ I)) DIG2)) (1+ I))
		 (T (ARRAY-LENGTH STR)))
	   (ASET DIG1 STR I)
	   (ASET DIG2 STR (1+ I)))))

;;; Some useful strings and accessing functions
(DEFVAR *DAYS-OF-THE-WEEK* '(("Mon" "Monday")
			     ("Tue" "Tuesday" "Tues")
			     ("Wed" "Wednesday")
			     ("Thu" "Thursday" "Thurs")
			     ("Fri" "Friday")
			     ("Sat" "Saturday")
			     ("Sun" "Sunday")))

(DEFUN DAY-OF-THE-WEEK-STRING (DAY-OF-THE-WEEK &OPTIONAL (MODE ':LONG) &AUX STRINGS)
  (SETQ STRINGS (NTH DAY-OF-THE-WEEK *DAYS-OF-THE-WEEK*))
  (SELECTQ MODE
    (:SHORT (FIRST STRINGS))
    (:LONG (SECOND STRINGS))
    (:MEDIUM (OR (THIRD STRINGS) (FIRST STRINGS)))
    (OTHERWISE (FERROR NIL "~S is not a known mode" MODE))))

(DEFVAR *MONTHS* '(("Jan" "January")
		   ("Feb" "February")
		   ("Mar" "March")
		   ("Apr" "April")
		   ("May" "May")
		   ("Jun" "June")
		   ("Jul" "July")
		   ("Aug" "August")
		   ("Sep" "September")
		   ("Oct" "October")
		   ("Nov" "November")
		   ("Dec" "December")))

(DEFUN MONTH-STRING (MONTH &OPTIONAL (MODE ':LONG) &AUX STRINGS)
  (SETQ STRINGS (NTH (1- MONTH) *MONTHS*))
  (SELECTQ MODE
    (:SHORT (FIRST STRINGS))
    (:LONG (SECOND STRINGS))
    (OTHERWISE (FERROR NIL "~S is not a known mode" MODE))))

;;; minutes offset from gmt, normal name, daylight name, miltary character
(DEFVAR *TIMEZONES* '((0 "GMT" NIL #/Z)			;Greenwich
		      (1 NIL NIL #/A)
		      (2 NIL NIL #/B)
		      (3 NIL "ADT" #/C)
		      (4 "AST" "EDT" #/D)		;Atlantic
		      (5 "EST" "CDT" #/E)		;Eastern
		      (6 "CST" "MDT" #/F)		;Central
		      (7 "MST" "PDT" #/G)		;Mountain
		      (8 "PST" "YDT" #/H)		;Pacific
		      (9 "YST" "HDT" #/I)		;Yukon
		      (10. "HST" "BDT" #/K)		;Hawaiian
		      (11. "BST" NIL #/L)		;Bering
		      (12. NIL NIL #/M)
		      (-1 NIL NIL #/N)
		      (-2 NIL NIL #/O)
		      (-3 NIL NIL #/P)
		      (-4 NIL NIL #/Q)
		      (-5 NIL NIL #/R)
		      (-6 NIL NIL #/S)
		      (-7 NIL NIL #/T)
		      (-8 NIL NIL #/U)
		      (-9 NIL NIL #/V)
		      (-10. NIL NIL #/W)
		      (-11. NIL NIL #/X)
		      (-12. NIL NIL #/Y)
		      (3.5 "NST" NIL -1)		;Newfoundland
		      ))

(DEFUN TIMEZONE-STRING (&OPTIONAL (TIMEZONE *TIMEZONE*)
				  (DAYLIGHT-SAVINGS-P (DAYLIGHT-SAVINGS-P)))
  (IF DAYLIGHT-SAVINGS-P
      (THIRD (NTH (1- TIMEZONE) *TIMEZONES*))
      (SECOND (NTH TIMEZONE *TIMEZONES*))))

;;; Date and time parsing

(DEFMACRO BAD-DATE-OR-TIME (REASON . ARGS)
  `(*THROW 'BAD-DATE-OR-TIME ,(IF (NULL ARGS) REASON `(FORMAT NIL ,REASON . ,ARGS))))

(DEFUN PARSE-DATE-AND-TIME (STRING &OPTIONAL (START 0) END MUST-HAVE-TIME DATE-MUST-HAVE-YEAR
					     TIME-MUST-HAVE-SECONDS (DAY-MUST-BE-VALID T))
  (DECLARE (RETURN-LIST SECONDS TIMEZONE DAY MONTH YEAR DAY-OF-THE-WEEK INDEX ERRMES))
  (OR END (SETQ END (STRING-LENGTH STRING)))
  (PROG ((INDEX START) SECONDS TIMEZONE DAY MONTH YEAR DAY-OF-THE-WEEK ERRMES)
    (SETQ ERRMES (*CATCH 'BAD-DATE-OR-TIME
		   (PROG1 NIL
		     (MULTIPLE-VALUE (DAY MONTH YEAR DAY-OF-THE-WEEK INDEX)
		       (PARSE-DATE-1 STRING INDEX END DATE-MUST-HAVE-YEAR))
		     (AND DAY-MUST-BE-VALID
			  (LET ((ERRMES (VERIFY-DATE DAY MONTH YEAR DAY-OF-THE-WEEK)))
			    (AND ERRMES (BAD-DATE-OR-TIME ERRMES))))
		     (MULTIPLE-VALUE-BIND (NIL TYPE)
			 (PARSE-DATE-OR-TIME-TOKEN STRING INDEX END)
		       (IF (EQ TYPE ':EOF)
			   (IF MUST-HAVE-TIME
			       (BAD-DATE-OR-TIME "No time was supplied")
			       (SETQ SECONDS 0))
			   (MULTIPLE-VALUE (SECONDS TIMEZONE INDEX)
			     (PARSE-TIME-1 STRING INDEX END TIME-MUST-HAVE-SECONDS)))))))
    (RETURN SECONDS TIMEZONE DAY MONTH YEAR DAY-OF-THE-WEEK INDEX ERRMES)))

;;; Returns list of day, month, year, and optionally day of week specified
(DEFUN PARSE-DATE-1 (STRING &OPTIONAL (START 0) END MUST-HAVE-YEAR AMBIGUOUS-ASSUME-DAY-FIRST
			    &AUX DAY MONTH YEAR DAY-OF-WEEK (INDEX START))
  (DECLARE (RETURN-LIST DAY MONTH YEAR DAY-OF-THE-WEEK INDEX))
  (OR END (SETQ END (STRING-LENGTH STRING)))
  (DO ((NINDEX) (TOKEN) (TYPE) (TEM)
       (STATE ':NONE))
      (NIL)
    (MULTIPLE-VALUE (TOKEN TYPE NINDEX)
      (PARSE-DATE-OR-TIME-TOKEN STRING INDEX END))
    (SELECTQ TYPE
      (:EOF
       (SETQ INDEX NINDEX)
       (RETURN T))
      (:DELIMITER
       (SELECTQ STATE
	 (:DAY-OR-MONTH-SEEN
	  (SETQ TEM TOKEN)			;Disallow 1/2-80
	  (SETQ STATE ':AWAITING-SECOND-NUMBER))
	 (:DAY-AND-MONTH-SEEN
	  (AND ( TOKEN TEM)
	       (BAD-DATE-OR-TIME "Mismatched delimiters ~C and ~C" TEM TOKEN))
	  (SETQ STATE ':AWAITING-YEAR))
	 (OTHERWISE
	  (RETURN NIL))))
      (:COMMA
       (SELECTQ STATE
	 (:DAY-OF-WEEK-SEEN
	  (SETQ STATE ':NONE))
	 ((:DAY-AND-MONTH-SEEN :AWAITING-YEAR)
	  (SETQ STATE ':AWAITING-YEAR))
	 (OTHERWISE
	  (RETURN NIL))))
      (:PARENTHESIS
       (BAD-DATE-OR-TIME "Cannot handle parentheses yet"))
      (:NUMBER
       (SELECTQ STATE
	 (:NONE
	  (COND ((> TOKEN 100.)			;many digits
		 (AND (> TOKEN 10000.)
		      (IF (> TOKEN 1000000.)
			  (SETQ YEAR (\ TOKEN 10000.)
				TOKEN (// TOKEN 10000.))
			  (SETQ YEAR (\ TOKEN 100.)
				TOKEN (// TOKEN 100.))))
		 (SETQ MONTH (// TOKEN 100.)
		       DAY (\ TOKEN 100.))
		 (COND (( DAY 12.))
		       ((OR ( MONTH 12.) AMBIGUOUS-ASSUME-DAY-FIRST)
			(PSETQ DAY MONTH MONTH DAY)))
		 (SETQ STATE (IF YEAR ':DONE ':DAY-AND-MONTH-SEEN)))
		(T
		 (IF ( TOKEN 12.)
		     (SETQ DAY TOKEN)
		     (SETQ MONTH TOKEN))
		 (SETQ STATE ':DAY-OR-MONTH-SEEN))))
	 ((:DAY-OR-MONTH-SEEN :AWAITING-SECOND-NUMBER)
	  (IF (NULL DAY)
	      (SETQ DAY TOKEN)
	      (SETQ MONTH TOKEN))
	  (SETQ STATE ':DAY-AND-MONTH-SEEN))
	 ((:DAY-AND-MONTH-SEEN :AWAITING-YEAR)
	  (SETQ YEAR TOKEN
		STATE ':DONE))
	 (OTHERWISE
	  (RETURN NIL))))
      (:DAY-OF-THE-WEEK
       (AND DAY-OF-WEEK
	    (BAD-DATE-OR-TIME "More than one day of the week"))
       (OR (MEMQ STATE '(:NONE :DONE))
	   (BAD-DATE-OR-TIME "~A seen in ~A state" TYPE STATE))
       (SETQ DAY-OF-WEEK TOKEN)
       (AND (EQ STATE ':NONE)
	    (SETQ STATE ':DAY-OF-WEEK-SEEN)))
      (:MONTH
       (AND MONTH
	    (IF (NULL DAY)
		(SETQ DAY MONTH)
		(BAD-DATE-OR-TIME "More than one month")))
       (SETQ MONTH TOKEN
	     STATE (IF DAY ':DAY-AND-MONTH-SEEN ':DAY-OR-MONTH-SEEN)))
      (OTHERWISE
       (BAD-DATE-OR-TIME "~A seen in ~A state" TYPE STATE)))
    (SETQ INDEX NINDEX))
  (OR (AND DAY MONTH) (BAD-DATE-OR-TIME "No date specified"))
  (COND ((NULL YEAR)
	 (AND MUST-HAVE-YEAR (BAD-DATE-OR-TIME "No year specified"))
	 (SETQ YEAR (DEFAULT-YEAR)))
	((< YEAR 1000.)
	 (SETQ YEAR (+ YEAR 1900.))))
  (PROG () (RETURN DAY MONTH YEAR DAY-OF-WEEK INDEX)))

;;; Returns list of seconds after midnight, optionally and offset from GMT
(DEFUN PARSE-TIME-1 (STRING START END TIME-MUST-HAVE-SECONDS)
  (DECLARE (RETURN-LIST SECONDS TIMEZONE INDEX))
  (DO ((INDEX START NINDEX)
       (NINDEX) (HOURS) (MINUTES) (SECONDS) (TIMEZONE)
       (STATE ':NONE) (TOKEN) (TYPE) (NUMLEN))
      (NIL)
    (MULTIPLE-VALUE (TOKEN TYPE NINDEX NUMLEN)
      (PARSE-DATE-OR-TIME-TOKEN STRING INDEX END))
    (SELECTQ TYPE
      (:EOF
       (AND (NULL SECONDS)
	    (IF TIME-MUST-HAVE-SECONDS
		(BAD-DATE-OR-TIME "Time must have seconds")
		(SETQ SECONDS 0)))
       (AND ( HOURS 24.)
	    (BAD-DATE-OR-TIME "Hours out of range"))
       (AND ( MINUTES 60.)
	    (BAD-DATE-OR-TIME "Minutes out of range"))
       (AND ( SECONDS 60.)
	    (BAD-DATE-OR-TIME "Seconds out of range"))
       (RETURN (+ SECONDS (* 60. (+ MINUTES (* 60. HOURS)))) TIMEZONE NINDEX))
      (:COLON
       (SELECTQ STATE
	 (:HOURS-SEEN
	  (SETQ STATE ':AWAITING-MINUTES))
	 (:MINUTES-SEEN
	  (SETQ STATE ':AWAITING-SECONDS))
	 (OTHERWISE
	  (BAD-DATE-OR-TIME "~A seen in ~A state" TYPE STATE))))
      (:DELIMITER
       (OR (MEMQ STATE '(:MINUTES-SEEN :SECONDS-SEEN :AM-PM-SEEN))
	   (BAD-DATE-OR-TIME "~A seen in ~A state" TYPE STATE))
       (SETQ STATE ':AWAITING-ATOM))
      (:TIMEZONE
       (OR (MEMQ STATE '(:MINUTES-SEEN :SECONDS-SEEN :AWAITING-ATOM :AM-PM-SEEN))
	   (BAD-DATE-OR-TIME "~A seen in ~A state" TYPE STATE))
       (SETQ TIMEZONE TOKEN
	     STATE ':DONE))
      ((:AM-PM :NOON-MIDNIGHT)
       (OR (MEMQ STATE '(:MINUTES-SEEN :SECONDS-SEEN :AWAITING-ATOM))
	   (BAD-DATE-OR-TIME "~A seen in ~A state" TYPE STATE))
       (IF (EQ TYPE ':AM-PM)
	   (OR (AND (> HOURS 0) ( HOURS 12.))
	       (BAD-DATE-OR-TIME "Hours out of range"))
	   (OR (AND (ZEROP MINUTES) (= HOURS 12.))
	       (BAD-DATE-OR-TIME "Noon or midnight and not twelve")))
       (IF (= HOURS 12.)
	   (AND (MEMQ TOKEN '(:AM :MIDNIGHT))
		(SETQ HOURS 0))
	   (AND (EQ TOKEN ':PM)
		(SETQ HOURS (+ HOURS 12.))))
       (SETQ STATE ':AM-PM-SEEN))
      (:NUMBER
       (COND ((> NUMLEN 6)
	      (BAD-DATE-OR-TIME "Too many digits for a time"))
	     ((> NUMLEN 4)				;HHMMSS
	      (OR (EQ STATE ':NONE)
		  (BAD-DATE-OR-TIME "Too many digits for a time"))
	      (SETQ SECONDS (\ TOKEN 100.)
		    TOKEN (// TOKEN 100.))
	      (SETQ MINUTES (\ TOKEN 100.)
		    HOURS (// TOKEN 100.))
	      (SETQ STATE ':SECONDS-SEEN))
	     ((> NUMLEN 2)				;HHMM
	      (OR (EQ STATE ':NONE)
		  (BAD-DATE-OR-TIME "Too many digits for a time"))
	      (SETQ MINUTES (\ TOKEN 100.)
		    HOURS (// TOKEN 100.))
	      (SETQ STATE ':MINUTES-SEEN))
	     (T
	      (SELECTQ STATE
		(:NONE
		 (SETQ HOURS TOKEN
		       STATE ':HOURS-SEEN))
		((:HOURS-SEEN :AWAITING-MINUTES)
		 (SETQ MINUTES TOKEN
		       STATE ':MINUTES-SEEN))
		((:MINUTES-SEEN :AWAITING-SECONDS)
		 (SETQ SECONDS TOKEN
		       STATE ':SECONDS-SEEN))
		(OTHERWISE
		  (BAD-DATE-OR-TIME "~A seen in ~A state" TYPE STATE)))))))))

(DEFUN PARSE-DATE-OR-TIME-TOKEN (STRING START END &AUX (INDEX START) TOKEN TYPE)
  (DECLARE (RETURN-LIST TOKEN TYPE INDEX TOKEN-LENGTH))
  (DO-NAMED PARSE-DATE-OR-TIME-TOKEN ((CH)) (NIL)
    (COND (( INDEX END)
	   (SETQ TOKEN NIL TYPE ':EOF)
	   (RETURN NIL)))
    (SETQ CH (CHAR-UPCASE (AREF STRING INDEX))
	  INDEX (1+ INDEX))
    (COND ((MEMQ CH '(#\SP #\TAB))
	   (SETQ START INDEX))
	  ((MEMQ CH '(#/- #//))
	   (SETQ TOKEN CH TYPE ':DELIMITER)
	   (RETURN NIL))
	  ((= CH #/:)
	   (SETQ TOKEN CH TYPE ':COLON)
	   (RETURN NIL))
	  ((= CH #/,)
	   (SETQ TOKEN CH TYPE ':COMMA)
	   (RETURN NIL))
	  ((= CH #/()
	   (DO ((I INDEX)) (NIL)
	     (AND ( I END) (BAD-DATE-OR-TIME "Eof in the middle of parenthesis"))
	     (SETQ CH (AREF STRING I)
		   I (1+ I))
	     (COND ((= CH #/))
		    (SETQ TOKEN (SUBSTRING STRING INDEX I) TYPE ':PARENTHESIS INDEX I)
		    (RETURN-FROM PARSE-DATE-OR-TIME-TOKEN NIL)))))
	  ((AND ( CH #/0) ( CH #/9))
	   (DO ((I INDEX (1+ I))
		(N 0))
	       (NIL)
	     (SETQ N (+ (* N 10.) (- CH #/0)))
	     (COND ((OR ( I END)
			(NOT (AND ( (SETQ CH (AREF STRING I)) #/0)
				  ( CH #/9))))
		    (SETQ TOKEN N TYPE ':NUMBER INDEX I)
		    (RETURN-FROM PARSE-DATE-OR-TIME-TOKEN NIL)))))
	  ((AND ( CH #/A) ( CH #/Z))
	   (DO ((I INDEX (1+ I))) (NIL)
	     (AND (OR ( I END)
		      (NOT (AND ( (SETQ CH (CHAR-UPCASE (AREF STRING I))) #/A)
				( CH #/Z))))
		  (MULTIPLE-VALUE-BIND (TOK TYP)
		      (PARSE-DATE-OR-TIME-ATOM (SUBSTRING STRING (1- INDEX) I))
		    (SETQ TOKEN TOK TYPE TYP INDEX I)
		    (RETURN-FROM PARSE-DATE-OR-TIME-TOKEN NIL)))))
	  (T
	   (BAD-DATE-OR-TIME "Unknown character ~C" CH))))
  (PROG () (RETURN TOKEN TYPE INDEX (- INDEX START))))

(DEFUN PARSE-DATE-OR-TIME-ATOM (STRING)
  (DECLARE (STRING-LIST TOKEN TYPE))
  (PROG PARSE-DATE-OR-TIME-ATOM ()
    ;; First try month
    (DO ((I 1 (1+ I))				;Months are one-based
	 (L *MONTHS* (CDR L)))
	((NULL L))
      (AND (MEMBER STRING (CAR L))
	   (RETURN-FROM PARSE-DATE-OR-TIME-ATOM I ':MONTH)))
    ;; Next try day of week
    (DO ((I 0 (1+ I))
	 (L *DAYS-OF-THE-WEEK*(CDR L)))
	((NULL L))
      (AND (MEMBER STRING (CAR L))
	   (RETURN-FROM PARSE-DATE-OR-TIME-ATOM I ':DAY-OF-THE-WEEK)))
    ;; Time keywords
    (AND (MEMBER STRING '("am" "pm"))
	 (RETURN (IF (EQUAL STRING "am") ':AM ':PM) ':AM-PM))
    (AND (MEMBER STRING '("noon" "midnight" "M" "N"))
	 (RETURN (IF (= (AREF STRING 0) #/M) ':MIDNIGHT ':NOON) ':NOON-MIDNIGHT))
    ;; Word of timezone
    (DO ((L *TIMEZONES* (CDR L))
	 (ONE-CHAR-P (= (STRING-LENGTH STRING) 1)))
	((NULL L))
      (AND (IF ONE-CHAR-P
	       (= (AREF STRING 0) (FOURTH (CAR L)))
	       (OR (EQUAL STRING (CADAR L))
		   (EQUAL STRING (CADDAR L))))
	   (RETURN-FROM PARSE-DATE-OR-TIME-ATOM (CAAR L) ':TIMEZONE)))
    (BAD-DATE-OR-TIME "Unknown atom ~S" STRING)))

;;; Check that a date is ok: day is within month; and day-of-week, if specified, is valid
(DEFUN VERIFY-DATE (DAY MONTH YEAR DAY-OF-THE-WEEK)
  (COND ((> DAY (MONTH-LENGTH MONTH YEAR))
	 (FORMAT NIL "~A only has ~D day~@P" (MONTH-STRING MONTH) (MONTH-LENGTH MONTH YEAR)))
	(DAY-OF-THE-WEEK
	 (LET ((UT (TIME-UNBREAK-UNIVERSAL 0 DAY MONTH YEAR)))
	   (MULTIPLE-VALUE-BIND (NIL NIL NIL NIL CORRECT-DAY-OF-THE-WEEK)
	       (TIME-BREAK-UNIVERSAL UT)
	     (AND ( DAY-OF-THE-WEEK CORRECT-DAY-OF-THE-WEEK)
		  (FORMAT NIL "~A the ~:R ~D is a ~A, not a ~A"
			  (MONTH-STRING MONTH) DAY YEAR
			  (DAY-OF-THE-WEEK-STRING CORRECT-DAY-OF-THE-WEEK)
			  (DAY-OF-THE-WEEK-STRING DAY-OF-THE-WEEK))))))
	(T
	 NIL)))

(DEFUN PARSE-DATE-AND-TIME-UNIVERSAL (STRING &OPTIONAL (START 0) END MUST-HAVE-TIME
						       DATE-MUST-HAVE-YEAR
						       TIME-MUST-HAVE-SECONDS
						       (DAY-MUST-BE-VALID T)
					     &AUX SECONDS TIMEZONE DAY MONTH YEAR INDEX
						  ERRMES UNIVERSAL-TIME)
  (DECLARE (RETURN-LIST UNIVERSAL-TIME INDEX ERRMES))
  (MULTIPLE-VALUE (SECONDS TIMEZONE DAY MONTH YEAR NIL INDEX ERRMES)
    (PARSE-DATE-AND-TIME STRING START END MUST-HAVE-TIME DATE-MUST-HAVE-YEAR
			 TIME-MUST-HAVE-SECONDS DAY-MUST-BE-VALID))
  (OR ERRMES
      (SETQ UNIVERSAL-TIME (TIME-UNBREAK-UNIVERSAL SECONDS DAY MONTH YEAR TIMEZONE)))
  (PROG () (RETURN UNIVERSAL-TIME INDEX ERRMES)))

;Turn on later, when TV package has been loaded
(ADD-INITIALIZATION "NWATCH" '(NWATCH-ON) '(:WARM))

(COMMENT
(DEFUN TEST ()
  (DO ((LINE)) (NIL)
    (TERPRI)
    (SETQ LINE (READLINE))
    (AND (EQUAL LINE "") (RETURN NIL))
    (MULTIPLE-VALUE-BIND (SECONDS NIL DAY MONTH YEAR NIL NIL ERRMES)
	(PARSE-DATE-AND-TIME LINE)
      (IF ERRMES
	  (PRINC ERRMES)
	  (PRINT-DATE-AND-TIME SECONDS DAY MONTH YEAR)))))

(DEFUN PRINT-DATE-AND-TIME (SECONDS DAY MONTH YEAR &AUX MINUTES HOURS)
  (SETQ	MONTH (MONTH-STRING MONTH ':SHORT))
  (SETQ MINUTES (// SECONDS 60.)
	SECONDS (\ SECONDS 60.))
  (SETQ HOURS (// MINUTES 60.)
	MINUTES (\ MINUTES 60.))
  (FORMAT T "~D-~A-~D ~D:~2,48D:~2,48D"
	  DAY MONTH YEAR HOURS MINUTES SECONDS))
)
