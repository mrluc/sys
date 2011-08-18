;;; -*- Mode: Lisp; Package: System-Internals -*-

;;; Miniature Chaosnet program.  Only good for reading ascii and binary files.
;;; The following magic number is in this program:  1200
;;; It also knows the format of a packet and the Chaosnet opcodes non-symbolically

(DECLARE (SPECIAL MINI-PKT MINI-PKT-STRING MINI-FILE-ID MINI-OPEN-P MINI-CH-IDX MINI-UNRCHF
		  MINI-LOCAL-INDEX MINI-LOCAL-HOST MINI-REMOTE-INDEX MINI-REMOTE-HOST
		  MINI-IN-PKT-NUMBER MINI-OUT-PKT-NUMBER MINI-EOF-SEEN
		  MINI-DESTINATION-ADDRESS MINI-ROUTING-ADDRESS))

;;; Compile time chaosnet address lookup and routing.
(DEFMACRO GET-INTERESTING-CHAOSNET-ADDRESSES (HOST-TO-USE)
  (LET ((ADDRESS (CHAOS:ADDRESS-PARSE HOST-TO-USE)))
    `(SETQ MINI-DESTINATION-ADDRESS ,ADDRESS
	   MINI-ROUTING-ADDRESS ,(AREF CHAOS:ROUTING-TABLE (LDB 1010 ADDRESS)))))

;(GET-INTERESTING-CHAOSNET-ADDRESSES #+MIT "AI" #+SYM "SCRC")
(GET-INTERESTING-CHAOSNET-ADDRESSES "server")

;;; Contact name<space>user<space>password
(DEFVAR MINI-CONTACT-NAME "MINI LISPM ")

;;; Initialization, usually only called once.
(DEFUN MINI-INIT ()
  ;; Init lists microcode looks at
  (STORE (SYSTEM-COMMUNICATION-AREA %SYS-COM-CHAOS-FREE-LIST) NIL)
  (STORE (SYSTEM-COMMUNICATION-AREA %SYS-COM-CHAOS-RECEIVE-LIST) NIL)
  (STORE (SYSTEM-COMMUNICATION-AREA %SYS-COM-CHAOS-TRANSMIT-LIST) NIL)
  ;; Fake up a packet buffer for the microcode, locations 1200-x through 1377
  ;; I.e. in the unused portions of SCRATCH-PAD-INIT-AREA
  (%P-STORE-TAG-AND-POINTER 1177 DTP-ARRAY-HEADER
			    (DPB 1 %%ARRAY-NUMBER-DIMENSIONS
				 (DPB 400 %%ARRAY-INDEX-LENGTH-IF-SHORT
				      (DPB 1 %%ARRAY-LEADER-BIT
					   ART-16B))))
  (%P-STORE-TAG-AND-POINTER 1176 DTP-FIX (LENGTH CHAOS-BUFFER-LEADER-QS))
  (%P-STORE-TAG-AND-POINTER (- 1176 1 (LENGTH CHAOS-BUFFER-LEADER-QS))
			    DTP-HEADER
			    (DPB %HEADER-TYPE-ARRAY-LEADER %%HEADER-TYPE-FIELD
				 (+ 2 (LENGTH CHAOS-BUFFER-LEADER-QS))))
  (SETQ MINI-PKT (%MAKE-POINTER DTP-ARRAY-POINTER 1177))
  (SETQ MINI-PKT-STRING (MAKE-ARRAY 760
				    ':TYPE 'ART-STRING
				    ':DISPLACED-TO 1204)) ;Just the data part of the packet
  (OR (BOUNDP 'MINI-LOCAL-INDEX)
      (SETQ MINI-LOCAL-INDEX 0))
  (SETQ MINI-OPEN-P NIL))

;;; Get a connection to a file server
(DEFUN MINI-OPEN-CONNECTION (HOST CONTACT-NAME)
  (OR (BOUNDP 'MINI-PKT) (MINI-INIT))
  (SETQ MINI-LOCAL-HOST (%UNIBUS-READ 764142)
	MINI-REMOTE-HOST HOST
	MINI-OUT-PKT-NUMBER 1)
  (SETQ MINI-LOCAL-INDEX (1+ MINI-LOCAL-INDEX))
  (AND (= MINI-LOCAL-INDEX 200000) (SETQ MINI-LOCAL-INDEX 1))
  (SETQ MINI-REMOTE-INDEX 0
	MINI-IN-PKT-NUMBER 0)
  (DO ((RETRY-COUNT 10. (1- RETRY-COUNT)))
      ((ZEROP RETRY-COUNT) (MINI-BARF "RFC fail"))
    ;; Store contact name into packet
    (COPY-ARRAY-CONTENTS CONTACT-NAME MINI-PKT-STRING)
    (MINI-SEND-PKT 1 (ARRAY-LENGTH CONTACT-NAME))  ;Send RFC
    (COND ((EQ (MINI-NEXT-PKT NIL) 2)	;Look for a response of OPN
	   (SETQ MINI-REMOTE-INDEX (AREF MINI-PKT 5)
		 MINI-IN-PKT-NUMBER (AREF MINI-PKT 6))
	   (SETQ MINI-OUT-PKT-NUMBER (1+ MINI-OUT-PKT-NUMBER))
	   (MINI-SEND-STS)
	   (SETQ MINI-OPEN-P T)
	   (RETURN T)))))	;and exit.  Otherwise, try RFC again.

;;; Send a STS
(DEFUN MINI-SEND-STS ()
  (ASET MINI-IN-PKT-NUMBER MINI-PKT 10) ;Receipt
  (ASET 1 MINI-PKT 11) ;Window size
  (MINI-SEND-PKT 7 4)) ;STS

;;; Open a file for read
(DEFUN MINI-OPEN-FILE (FILENAME BINARY-P)
  (SETQ MINI-CH-IDX 1000 MINI-UNRCHF NIL MINI-EOF-SEEN NIL)
  (OR MINI-OPEN-P
      (MINI-OPEN-CONNECTION MINI-DESTINATION-ADDRESS MINI-CONTACT-NAME))
  (DO ((OP)) ;Retransmission loop
      (NIL)
    ;; Send opcode 200 (ascii open) or 201 (binary open) with file name
    (COPY-ARRAY-CONTENTS FILENAME MINI-PKT-STRING)
    (MINI-SEND-PKT (IF BINARY-P 201 200) (ARRAY-ACTIVE-LENGTH FILENAME))
    ;; Get back opcode 202 (win) or 203 (lose) or OPN if old STS lost
    (SETQ OP (MINI-NEXT-PKT NIL))
    (COND ((NULL OP))		;no response, retransmit
	  ((= OP 2)		;OPN
	   (MINI-SEND-STS))	;send STS and then retransmit
	  ((OR (= OP 202) (= OP 203)) ;Win or Lose
	   (SETQ MINI-IN-PKT-NUMBER (LOGAND 177777 (1+ MINI-IN-PKT-NUMBER))
		 MINI-OUT-PKT-NUMBER (LOGAND 177777 (1+ MINI-OUT-PKT-NUMBER)))
	   (LET* ((LENGTH (LOGAND 7777 (AREF MINI-PKT 1)))
		  (CR (STRING-SEARCH-CHAR #\CR MINI-PKT-STRING 0 LENGTH)))
	     ;; Before pathnames and time parsing is loaded, things are stored as strings.
	     (SETQ MINI-FILE-ID (CONS (SUBSTRING MINI-PKT-STRING 0 CR)
				      (SUBSTRING MINI-PKT-STRING (1+ CR) LENGTH))))
	   (MINI-SEND-STS)	;Acknowledge packet just received
	   (COND ((= OP 202)
		  (RETURN T))
		 (T ;Lose
		  (MINI-BARF MINI-FILE-ID FILENAME))))))
  (IF BINARY-P #'MINI-BINARY-STREAM #'MINI-ASCII-STREAM))

;; Doesn't use symbols for packet fields since not loaded yet
;; This sends a packet and doesn't return until it has cleared microcode.
;; You fill in the data part before calling, this fills in the header.
(DEFUN MINI-SEND-PKT (OPCODE N-BYTES)
  (ASET (LSH OPCODE 8) MINI-PKT 0)
  (ASET N-BYTES MINI-PKT 1)
  (ASET MINI-REMOTE-HOST MINI-PKT 2)
  (ASET MINI-REMOTE-INDEX MINI-PKT 3)
  (ASET MINI-LOCAL-HOST MINI-PKT 4)
  (ASET MINI-LOCAL-INDEX MINI-PKT 5)
  (ASET MINI-OUT-PKT-NUMBER MINI-PKT 6) ;PKT#
  (ASET MINI-IN-PKT-NUMBER MINI-PKT 7)  ;ACK#
  (LET ((WC (+ 8 (// (1+ N-BYTES) 2) 1))) ;Word count including header and hardware dest word
    (STORE-ARRAY-LEADER WC MINI-PKT %CHAOS-LEADER-WORD-COUNT)
    (ASET MINI-ROUTING-ADDRESS MINI-PKT (1- WC))) ;Store hardware destination
  (STORE-ARRAY-LEADER NIL MINI-PKT %CHAOS-LEADER-THREAD)
  (STORE (SYSTEM-COMMUNICATION-AREA %SYS-COM-CHAOS-TRANSMIT-LIST) MINI-PKT)
  (%CHAOS-WAKEUP)
  (DO ()	;Await completion of transmission
      ((NULL (SYSTEM-COMMUNICATION-AREA %SYS-COM-CHAOS-TRANSMIT-LIST))))
  ;; Disallow use of the packet by the receive side, flush any received packet that snuck in
  (STORE (SYSTEM-COMMUNICATION-AREA %SYS-COM-CHAOS-FREE-LIST) NIL)
  (STORE (SYSTEM-COMMUNICATION-AREA %SYS-COM-CHAOS-RECEIVE-LIST) NIL)
  (COPY-ARRAY-CONTENTS "" MINI-PKT))		;Fill with zero

;; Return opcode of next packet other than those that are no good.
;; If the arg is NIL, can return NIL if no packet arrives after a while.
;; If T, waits forever.  Return value is the opcode of the packet in MINI-PKT.
(DEFUN MINI-NEXT-PKT (MUST-RETURN-A-PACKET &AUX OP)
  (DO ((TIMEOUT 20. (1- TIMEOUT)))	;A couple seconds
      ((AND (ZEROP TIMEOUT) (NOT MUST-RETURN-A-PACKET)) NIL)
    ;; Enable microcode to receive a packet
    (STORE (SYSTEM-COMMUNICATION-AREA %SYS-COM-CHAOS-FREE-LIST) NIL)
    (STORE (SYSTEM-COMMUNICATION-AREA %SYS-COM-CHAOS-RECEIVE-LIST) NIL)
    (STORE-ARRAY-LEADER NIL MINI-PKT %CHAOS-LEADER-THREAD)
    (COPY-ARRAY-CONTENTS "" MINI-PKT)		;Fill with zero
    (STORE (SYSTEM-COMMUNICATION-AREA %SYS-COM-CHAOS-FREE-LIST) MINI-PKT)
    (%CHAOS-WAKEUP)
    (DO ((N 2000. (1- N)))	;Give it time
	((OR (ZEROP N) (SYSTEM-COMMUNICATION-AREA %SYS-COM-CHAOS-RECEIVE-LIST))))
    (COND ((SYSTEM-COMMUNICATION-AREA %SYS-COM-CHAOS-RECEIVE-LIST)
	   (SETQ OP (LSH (AREF MINI-PKT 0) -8))
	   (COND ((AND (NOT (LDB-TEST %%CHAOS-CSR-CRC-ERROR
				       (ARRAY-LEADER MINI-PKT %CHAOS-LEADER-CSR-1)))
		       (NOT (LDB-TEST %%CHAOS-CSR-CRC-ERROR
				       (ARRAY-LEADER MINI-PKT %CHAOS-LEADER-CSR-2)))
		       (= (LDB 0004 (ARRAY-LEADER MINI-PKT %CHAOS-LEADER-BIT-COUNT)) 0)
		       (>= (ARRAY-LEADER MINI-PKT %CHAOS-LEADER-BIT-COUNT) 48.)
		       (ZEROP (LOGAND 377 (AREF MINI-PKT 0)))	;Header version 0
		       (= (// (ARRAY-LEADER MINI-PKT %CHAOS-LEADER-BIT-COUNT)
			      20)
			  (+ 10	;FIRST-DATA-WORD-IN-PKT
			     (LSH (1+ (LDB 14 (AREF MINI-PKT 1))) -1)  ;PKT-NWORDS
			     3))	;HEADER
		       (= (AREF MINI-PKT 2) MINI-LOCAL-HOST)
		       (= (AREF MINI-PKT 3) MINI-LOCAL-INDEX)
		       (OR (AND (MEMQ OP '(14 202 203 200 300))  ;EOF, win, lose, data
				(= (AREF MINI-PKT 6) (LOGAND 177777 (1+ MINI-IN-PKT-NUMBER))))
			   (MEMQ OP '(2 3 11))))  ;OPN, CLS, LOS
		  ;; This packet not to be ignored, return to caller
		  (COND ((MEMQ OP '(3 11))  ;CLS, LOS
			 (LET ((MSG (MAKE-ARRAY (LOGAND 7777 (AREF MINI-PKT 1))
						':TYPE 'ART-STRING)))
			   (COPY-ARRAY-CONTENTS MINI-PKT-STRING MSG)
			   (MINI-BARF "Connection broken" MSG))))
		  (RETURN OP)))
	   ;; This packet to be ignored, get another
	   (AND MINI-OPEN-P		;Could be getting a retransmission of
		(MINI-SEND-STS))	; an old pkt due to lost STS
	   ))))

;Stream which does only 16-bit TYI
(DEFUN MINI-BINARY-STREAM (OP &OPTIONAL ARG1)
  (SELECTQ OP
    (:WHICH-OPERATIONS '(:TYI))
    (:TYI (COND (MINI-UNRCHF
		 (PROG1 MINI-UNRCHF (SETQ MINI-UNRCHF NIL)))
		((< MINI-CH-IDX (// (LOGAND 7777 (AREF MINI-PKT 1)) 2))
		 (PROG1 (AREF MINI-PKT (+ 10 MINI-CH-IDX))
			(SETQ MINI-CH-IDX (1+ MINI-CH-IDX))))
		(T ;Get another packet
		 (MINI-SEND-STS)  ;Acknowledge packet just processed
		 (SETQ OP (MINI-NEXT-PKT T))
		 (SETQ MINI-IN-PKT-NUMBER (LOGAND 177777 (1+ MINI-IN-PKT-NUMBER)))
		 (COND ((= OP 14) ;EOF
			(MINI-SEND-STS) ;Acknowledge the EOF
			(SETQ MINI-EOF-SEEN T)
			NIL)		;and tell caller
		       ((= OP 300) ;Data
			(SETQ MINI-CH-IDX 0)
			(MINI-BINARY-STREAM ':TYI))
		       (T (MINI-BARF "Bad opcode received" OP))))))
    (:UNTYI (SETQ MINI-UNRCHF ARG1))
    (OTHERWISE (MINI-BARF "Unknown stream operation" OP))))

(DEFUN MINI-ASCII-STREAM (OP &OPTIONAL ARG1)
  (SELECTQ OP
    (:WHICH-OPERATIONS '(:TYI :UNTYI))
    (:TYI (COND (MINI-UNRCHF
		 (PROG1 MINI-UNRCHF (SETQ MINI-UNRCHF NIL)))
		((< MINI-CH-IDX (LOGAND 7777 (AREF MINI-PKT 1)))
		 (PROG1 (AREF MINI-PKT-STRING MINI-CH-IDX)
			(SETQ MINI-CH-IDX (1+ MINI-CH-IDX))))
		(T ;Get another packet
		 (MINI-SEND-STS)  ;Acknowledge packet just processed
		 (SETQ OP (MINI-NEXT-PKT T))
		 (SETQ MINI-IN-PKT-NUMBER (LOGAND 177777 (1+ MINI-IN-PKT-NUMBER)))
		 (COND ((= OP 14) ;EOF
			(MINI-SEND-STS) ;Acknowledge the EOF
			(SETQ MINI-EOF-SEEN T)
			(AND ARG1 (ERROR ARG1))
			NIL)		;and tell caller
		       ((= OP 200) ;Data
			(SETQ MINI-CH-IDX 0)
			(MINI-ASCII-STREAM ':TYI))
		       (T (MINI-BARF "Bad opcode received" OP))))))
    (:UNTYI (SETQ MINI-UNRCHF ARG1))
    (OTHERWISE (MINI-BARF "Unknown stream operation" OP))))

(DEFUN MINI-BARF (&REST ARGS)
  (SETQ MINI-OPEN-P NIL) ;Force re-open of connection
  ;; If inside the cold load, this will be FERROR-COLD-LOAD, else make debugging easier
  (LEXPR-FUNCALL #'FERROR 'MINI-BARF ARGS))

;;; Higher-level stuff

;;; Load a file alist as setup by the cold load generator
(DEFUN MINI-LOAD-FILE-ALIST (ALIST)
  (LOOP FOR (FILE PACK QFASLP) IN ALIST
	DO (FUNCALL (IF QFASLP #'MINI-FASLOAD #'MINI-READFILE) FILE PACK)))

(DECLARE (SPECIAL FASL-STREAM FASLOAD-FILE-PROPERTY-LIST-FLAG FASL-GROUP-DISPATCH
                  FASL-OPS FDEFINE-FILE-PATHNAME FASL-GENERIC-PATHNAME-PLIST
		  FASL-STREAM-BYPASS-P))

(DECLARE (SPECIAL ACCUMULATE-FASL-FORMS))

(DECLARE (SPECIAL *COLD-LOADED-FILE-PROPERTY-LISTS*))

(DEFUN MINI-FASLOAD (FILE-NAME PKG
		     &AUX FASL-STREAM W1 W2 TEM
			  (FDEFINE-FILE-PATHNAME FILE-NAME) FASL-GENERIC-PATHNAME-PLIST
			  FASLOAD-FILE-PROPERTY-LIST-FLAG
			  (FASL-TABLE NIL) (FASL-STREAM-BYPASS-P NIL))
  
  ;; Set it up so that file properties get remembered for when there are pathnames
  (OR (SETQ TEM (ASSOC FILE-NAME *COLD-LOADED-FILE-PROPERTY-LISTS*))
      (PUSH (SETQ TEM (LIST FILE-NAME NIL NIL)) *COLD-LOADED-FILE-PROPERTY-LISTS*))
  (SETQ FASL-GENERIC-PATHNAME-PLIST (LOCF (THIRD TEM)))
  
  (FASL-START)
  
  ;;Open the input stream in binary mode, and start by making sure
  ;;the file type in the first word is really SIXBIT/QFASL/.
  (SETQ FASL-STREAM (MINI-OPEN-FILE FILE-NAME T))
  (SETQ W1 (FUNCALL FASL-STREAM ':TYI)
	W2 (FUNCALL FASL-STREAM ':TYI))
  (COND ((AND (= W1 143150) (= W2 71660))	;If magic ID checks,
	 (LET ((PACKAGE (IF (FBOUNDP 'INTERN-LOCAL)	;If packages exist now 
			    (PKG-FIND-PACKAGE PKG)
			    NIL)))
	   ;; Read in the file property list in the wrong package list fasload does
	   (AND PACKAGE
		(= (LOGAND (FASL-NIBBLE-PEEK) %FASL-GROUP-TYPE) FASL-OP-FILE-PROPERTY-LIST)
		(FASL-FILE-PROPERTY-LIST))
	   ;; Call fasload to load it
	   (FASL-TOP-LEVEL)			;load it.
	   ;; Doesn't really read to EOF, must read rest to avoid getting out of phase
	   (DO () (MINI-EOF-SEEN)
	     (FUNCALL FASL-STREAM ':TYI))
	   ;; If package is NIL, will be fixed later
	   (SET-FILE-LOADED-ID (LOCF (SECOND TEM)) MINI-FILE-ID PACKAGE)))
	((FERROR NIL "~A is not a QFASL file" FILE-NAME)))	;Otherwise, barf out.
  FILE-NAME)

(DEFUN MINI-READFILE (FILE-NAME PKG &AUX (FDEFINE-FILE-PATHNAME FILE-NAME) TEM)
  (LET ((EOF '(()))
	(STANDARD-INPUT (MINI-OPEN-FILE FILE-NAME NIL))
	(PACKAGE (PKG-FIND-PACKAGE PKG)))
    (DO FORM (READ STANDARD-INPUT EOF) (READ STANDARD-INPUT EOF) (EQ FORM EOF)
	(EVAL FORM))
    (OR (SETQ TEM (ASSOC FILE-NAME *COLD-LOADED-FILE-PROPERTY-LISTS*))
	(PUSH (SETQ TEM (LIST FILE-NAME NIL NIL)) *COLD-LOADED-FILE-PROPERTY-LISTS*))
    (SET-FILE-LOADED-ID (LOCF (SECOND TEM)) MINI-FILE-ID PACKAGE)))

(ADD-INITIALIZATION "MINI" '(SETQ MINI-OPEN-P NIL) '(WARM FIRST))

