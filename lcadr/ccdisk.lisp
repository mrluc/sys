; -*- Mode:Lisp; Package:CADR; Base:8 -*-
;DISK HANDLER FOR CC FOR CADR
;	** (c) Copyright 1980 Massachusetts Institute of Technology **

(INCLUDE |LMDOC;.COMPL PRELUD|)

;******************************
; STILL TO BE DONE
; <HAIRIER> FUNCTION TO VERIFY PAGE HASH TABLE, ALSO MAP?
;******************************

(DECLARE (SPECIAL CC-DISK-ADDRESS CC-DISK-RETRY-COUNT
		  CC-DISK-DA-DESC CC-DISK-STATUS-DESC CC-DISK-CMD-DESC
		  CC-DISK-READ-FCN CC-DISK-WRITE-FCN
		  CC-DISK-TRACE-FLAG CC-DISK-LAST-CMD CC-DISK-LAST-CLP
		  %SYS-COM-PAGE-TABLE-PNTR %SYS-COM-PAGE-TABLE-SIZE
		  %%PHT1-VALID-BIT %%PHT1-VIRTUAL-PAGE-NUMBER
		  %%PHT2-PHYSICAL-PAGE-NUMBER
		  %%PHT1-SWAP-STATUS-CODE %PHT-SWAP-STATUS-PDL-BUFFER 
		  %PHT-SWAP-STATUS-WIRED %PHT-SWAP-STATUS-FLUSHABLE
		  %%PHT2-MAP-STATUS-CODE %%PHT2-ACCESS-STATUS-AND-META-BITS
		  %PHT-MAP-STATUS-READ-WRITE %PHT-MAP-STATUS-PDL-BUFFER
		  %PHT-DUMMY-VIRTUAL-ADDRESS
		  MICRO-CODE-SYMBOL-AREA-START MICRO-CODE-SYMBOL-AREA-END
		  PHT-ADDR SIZE-OF-PAGE-TABLE
		  INITIAL-LOD-NAME N-PARTITIONS
		  N-HEADS N-CYLINDERS N-BLOCKS-PER-TRACK
		  BLOCKS-PER-TRACK BLOCKS-PER-CYLINDER CC-DISK-TYPE
		  PARTITION-NAMES PARTITION-START PARTITION-SIZE 
		  CTALK-BARF-AT-WRITE-ERRORS))

(SETQ MICRO-CODE-SYMBOL-AREA-START 3  ;MAGIC
      MICRO-CODE-SYMBOL-AREA-END 7)   ;MORE MAGIC

(SETQ CC-DISK-RETRY-COUNT 5)	;TIMES TO RETRY AT CC-DISK-XFER IF GET ERROR
(SETQ CC-DISK-LAST-CMD 0 CC-DISK-LAST-CLP 777) ;AVOID UNBOUND

(SETQ CC-DISK-TRACE-FLAG NIL)

(DECLARE (FIXNUM (PHYS-MEM-READ FIXNUM)
		 (QF-PAGE-HASH-TABLE-LOOKUP FIXNUM))
	 (NOTYPE (PHYS-MEM-WRITE FIXNUM FIXNUM)
		 (CC-DISK-READ FIXNUM FIXNUM FIXNUM)
		 (CC-DISK-READ-QUEUING FIXNUM FIXNUM FIXNUM)
		 (CC-DISK-WRITE FIXNUM FIXNUM FIXNUM)
		 (CC-DISK-WRITE-QUEUEING FIXNUM FIXNUM FIXNUM)
		 (CC-DISK-XFER FIXNUM FIXNUM FIXNUM FIXNUM)
		 (CC-DISK-XFER-TRACK-HEAD-SECTOR FIXNUM FIXNUM FIXNUM FIXNUM FIXNUM FIXNUM)
		 (CC-CHECK-PAGE-HASH-TABLE-ACCESSIBILITY)
		 ))

(DECLARE (*EXPR QF-PAGE-HASH-TABLE-LOOKUP READ-LABEL Y-OR-N-P
		QF-CLEAR-CACHE SLEEP-JIFFIES PHYS-MEM-WRITE PHYS-MEM-READ CC-TYPE-OUT))

(IF-FOR-MACLISP
(DECLARE (SETQ FOR-CADR T)
	 (LOAD '((LISPM) UTIL FASL))  ;NEEDED FOR QCOM TO WIN
	 (VALRET '|:SL/
/P|)
	 (LOAD '((LISPM) UTIL1 FASL)) ;ALSO ...
	 (LOAD '((LISPM)QCOM >)))  ;GET DEFINITIONS FOR PHT1,2 ETC NEEDED AT COMPILE-TIME
)

(IF-FOR-MACLISP
(DEFUN QF-POINTER MACRO (X)
  (CONS 'BOOLE (CONS '1 (CONS '77777777 (CDR X))))) )

(SETQ CC-DISK-ADDRESS 17377774
      CC-DISK-READ-FCN 0
      CC-DISK-WRITE-FCN 11)

(SETQ CC-DISK-DA-DESC '(
	(TYPE-FIELD UNIT 3403 NIL)
	(TYPE-FIELD CYLINDER 2014 NIL)
	(TYPE-FIELD HEAD 0808 NIL)
	(TYPE-FIELD SECTOR 0008 NIL)))

(SETQ CC-DISK-STATUS-DESC '(
	(SELECT-FIELD INTERNAL-PARITY-ERROR 2701 (NIL INTERNAL-PARITY-ERROR))
	(SELECT-FIELD READ-COMPARE-DIFFERENCE 2601 (NIL READ-COMPARE-DIFFERENCE))
	(SELECT-FIELD CCW-CYCLE 2501 (NIL CCW-CYCLE))
	(SELECT-FIELD NXM 2401 (NIL NXM))
	(SELECT-FIELD PAR 2301 (NIL PAR))
	(SELECT-FIELD HEADER-COMPARE-ERR 2201 (NIL HEADER-COMPARE-ERR))
	(SELECT-FIELD HEADER-ECC-ERR 2101 (NIL HEADER-ECC-ERR))
	(SELECT-FIELD ECC-HARD 2001 (NIL ECC-HARD))
	(SELECT-FIELD ECC-SOFT 1701 (NIL ECC-SOFT))
	(SELECT-FIELD OVERRUN 1601 (NIL OVERRUN))
	(SELECT-FIELD TRANSFER-ABORTED 1501 (NIL TRANSFER-ABORTED))
	(SELECT-FIELD START-OF-BLOCK-ERR 1401 (NIL START-OF-BLOCK-ERR))
	(SELECT-FIELD TIMEOUT 1301 (NIL TIMEOUT))
	(SELECT-FIELD SEEK-ERR 1201 (NIL SEEK-ERR))
	(SELECT-FIELD OFF-LINE 1101 (NIL OFF-LINE))
	(SELECT-FIELD OFF-CYL 1001 (NIL OFF-CYL))
	(SELECT-FIELD READ-ONLY 0701 (NIL READ-ONLY))
	(SELECT-FIELD FAULT 0601 (NIL FAULT))
	(SELECT-FIELD NO-SELECT 0501 (NIL NO-SELECT))
	(SELECT-FIELD MULTIPLE-SELECT 0401 (NIL MULTIPLE-SELECT))
	(SELECT-FIELD INTERRUPT 0301 (NIL INTERRUPT))
	(SELECT-FIELD ATTENTION 0201 (NIL ATTENTION))
	(SELECT-FIELD ANY-ATTENTION 0101 (NIL ANY-ATTENTION))
	(SELECT-FIELD IDLE 0001 (BUSY IDLE)) ))

(SETQ CC-DISK-CMD-DESC '(
	(SELECT-FIELD COMMAND 0004 (READ CMD1? READ-ALL CMD3?
				    SEEK AT-EASE-AND-MISC OFFSET-CLEAR CMD7?
				    READ-COMPARE WRITE CMD12? WRITE-ALL
				    CMD14? CMD15? RESET-CONTROLLER CMD17?))
	(SELECT-FIELD SERVO-OFFSET 0402 (NIL BIT4? REVERSE FORWARD))
	(SELECT-FIELD DATA-STROBE 0602 (NIL EARLY LATE EARLY-AND-LATE?))
	(SELECT-FIELD FAULT-CLEAR 1001 (NIL FAULT-CLEAR))
	(SELECT-FIELD RECALIBRATE 1101 (NIL RECALIBRATE))
	(SELECT-FIELD ATTN-INT-ENB 1201 (NIL ATTN-INT-ENB))
	(SELECT-FIELD DONE-INT-ENB 1301 (NIL DONE-INT-ENB)) ))

(DEFUN CC-DISK-ANALYZE ()
    (PRINT 'DISK-CONTROL-STATUS)
    (CC-TYPE-OUT (PHYS-MEM-READ CC-DISK-ADDRESS) CC-DISK-STATUS-DESC T T)
    (TERPRI)
    (PRINC '|ECC ERROR PATTERN BITS |)
    (PRIN1 (LOGLDB 2020 (PHYS-MEM-READ (+ CC-DISK-ADDRESS 3))))
    (TERPRI)
    (PRINC '|ECC ERROR BIT POSITION |)
    (PRIN1 (LOGLDB 0020 (PHYS-MEM-READ (+ CC-DISK-ADDRESS 3))))
    (PRINT 'SAVED-COMMAND)
    (CC-TYPE-OUT CC-DISK-LAST-CMD CC-DISK-CMD-DESC T T)
    (PRINT 'DISK-ADDRESS)
    (CC-TYPE-OUT (PHYS-MEM-READ (+ CC-DISK-ADDRESS 2)) CC-DISK-DA-DESC T T)
    (PRINT 'MEMORY-ADDRESS)
    (PRIN1 (LOGLDB 0026 (PHYS-MEM-READ (+ CC-DISK-ADDRESS 1))))
    (PRINT 'SAVED-COMMAND-LIST-POINTER)
    (PRIN1 CC-DISK-LAST-CLP)
    (PRINT 'COMMAND-LIST)
    (DO ((I CC-DISK-LAST-CLP (1+ I))
	 (TEM))
	(NIL)
      (DECLARE (FIXNUM I TEM))
      (PRINT I)
      (PRIN1 (SETQ TEM (PHYS-MEM-READ I)))
      (AND (ZEROP (LOGLDB 0001 TEM)) (RETURN NIL)))
    (TERPRI)
)

;Look at the disk error log of the machine on the other end of the debug interface
(DEFUN CC-PRINT-DISK-ERROR-LOG ()
  (DO I 600 (+ I 4) (= I 640)
    (LET ((CLP-CMD (PHYS-MEM-READ I))
	  (DA (PHYS-MEM-READ (1+ I)))
	  (STS (PHYS-MEM-READ (+ I 2)))
	  (MA (PHYS-MEM-READ (+ I 3))))
      (COND ((NOT (ZEROP CLP-CMD))
	     (FORMAT T "~%Command ~O ~@[(~A) ~]"
		       (LOGLDB 0020 CLP-CMD)
		       (CDR (ASSQ (LOGLDB 0004 CLP-CMD) '((0 . "Read")
							  (10 . "Read-Compare")
							  (11 . "Write")))))
	     (AND (BIT-TEST %DISK-COMMAND-DATA-STROBE-EARLY CLP-CMD)
		  (PRINC "Data-Strobe-Early "))
	     (AND (BIT-TEST %DISK-COMMAND-DATA-STROBE-LATE CLP-CMD)
		  (PRINC "Data-Strobe-Late "))
	     (AND (BIT-TEST %DISK-COMMAND-SERVO-OFFSET CLP-CMD)
		  (PRINC "Servo-offset "))
	     (AND (BIT-TEST %DISK-COMMAND-SERVO-OFFSET-FORWARD CLP-CMD)
		  (PRINC "S-O-Forward "))
	     (TERPRI)
	     (FORMAT T "CCW-list pointer ~O (low 16 bits)~%" (LOGLDB 2020 CLP-CMD))
	     (FORMAT T "Disk address: unit ~O, cylinder ~O, head ~O, block ~O (~4:*~D ~D ~D ~D decimal)~%"
		       (LOGLDB 3404 DA) (LOGLDB 2014 DA) (LOGLDB 1010 DA) (LOGLDB 0010 DA))
	     (FORMAT T "Memory address: ~O (type bits ~O)~%"
		       (LOGLDB 0026 MA) (LOGLDB 2602 MA))
	     (FORMAT T "Status: ~O" STS)
	     (DO ((PPSS 2701 (- PPSS 100))
		  (L '("Internal-parity" "Read-compare" "CCW-cycle" "NXM" "Mem-parity"
		       "Header-Compare" "Header-ECC" "ECC-Hard" "ECC-Soft"
		       "Overrun" "Transfer-Aborted (or wr. ovr.)" "Start-Block-Error"
		       "Timeout" "Seek-Error" "Off-Line" "Off-Cylinder"
		       "Read-Only" "Fault" "No-Select" "Multiple-Select"
		       "Interrupt" "Sel-Unit-Attention" "Any-Unit-Attention" "Idle")
		     (CDR L)))
		 ((MINUSP PPSS) (TERPRI))
	       (AND (LDB-TEST PPSS STS) (FORMAT T "~<~%~8X~:;  ~A~>" (CAR L)))))))))


;Try harder routine.
;Get CYL, Head, Sector from disk, or from &OPTIONAL args.
;Try xfer again, with all flavors of offsets, and report.
;Then try recalibrate, all offsets again.

(IF-FOR-LISPM
(defun cc-try-harder (&OPTIONAL CYL head sector
		      &aux (unit 0) disk-adr)
   (cond ((null cyl)					;default from last xfer
	  (setq disk-adr (phys-mem-read (+ cc-disk-address 2)))
	  (setq cyl (ldb 2014 disk-adr)
		head (ldb 0808 disk-adr)
		sector (ldb 0008 disk-adr)
		unit (ldb 3403 disk-adr))))
   (do recal 0 (1+ recal) (= recal 2)
       (do ((fcn-bits '(0 40 60 100 200 140 240 160 260) (cdr fcn-bits))
	    (fcn-name '("Normal" "Servo Reverse" "Servo Forward"
				 "Strobe Early" "Strobe Late"
				 "Servo Reverse -- Strobe Early"  ;NO COMMAS INSIDE STRINGS
				 "Servo Reverse -- Strobe Late"   : IN MACLISP
				 "Servo Forward -- Strobe Early"
				 "Servo Forward -- Strobe Late")
		      (cdr fcn-name))
            (cc-disk-retry-count 1))              ;for cc-disk-xfer-...
	   ((null fcn-bits))
	   (format t "~%Trying with ~A ---" (car fcn-name))
	   ;; Read that block into core page 3

           (phys-mem-write 1400 525252777)      ;change data
           (cc-disk-seek 0 800. 4 1) ;random seek of cylinder
	   (cc-disk-xfer-track-head-sector (car fcn-bits) cyl head sector 3 1)
           (cc-disk-op 6)           ;Clear servo offset
;           (compare)
       )
       (cond ((= recal 0)
	      (format t "~%[Recalibrating]")
	      (cc-disk-op 1005)     ;Recalibrate
              (cc-disk-wait-idle 4) ;wait Sel Unit Attention - recal done
))))
); If-for-lispm

(if-for-lispm 
(defun cc-disk-clobber (&optional (data 5252525252) cyl head sector
                        &aux disk-adr)
  (cond ((null cyl)					;default from last xfer
         (setq disk-adr (phys-mem-read (+ cc-disk-address 2)))
         (setq cyl (ldb 2014 disk-adr)
               head (ldb 0808 disk-adr)
               sector (ldb 0008 disk-adr))))
  (do ((cc-disk-retry-count 1))
      ((kbd-tyi-no-hang))
      (do i 1400 (1+ i) ( i 2000)
          (phys-mem-write i data))
      ;;Write good data
      (format t "~%Writing ---")	;NO PERIODS IN STRINGS IN MACLISP
      (cc-disk-xfer-track-head-sector 11 cyl head sector 3 1)       ;write it
      (format t "~%Reading ---")
      (cc-disk-xfer-track-head-sector 0 cyl head sector 3 1)        ;read it
      ))
); If-for-lispm

(if-for-lispm
(defun compare (&optional (adr1 1400) ( adr2 2000))
    (do ((adr1 adr1 (1+ adr1))
         (adr2 adr2 (1+ adr2))
         (i 0 (1+ i))
         (dat1)
         (dat2))
        ((= i 400))
        (cond (( (setq dat1 (phys-mem-read adr1)) (setq dat2 (phys-mem-read adr2)))
               (format t "~%~o   ~O--  ~O" adr1 dat1 dat2)))))
); If-for-lispm

(defun cc-disk-seek (fcn-bits cyl head sector)
   (cc-disk-wait-idle 1)
   (phys-mem-write (+ cc-disk-address 2)
                   (+ (lsh head 8)
                      sector
                      (cc-shift cyl 20)))    ;Set seek adr
   (cc-disk-op (+ 4 fcn-bits))      ;Seek op
   (cc-disk-wait-idle 4))           ;wait for selected unit atention

(defun cc-disk-op (fcn)
   (phys-mem-write cc-disk-address fcn)
   (phys-mem-write (+ cc-disk-address 3) 0)		;start operation
   (cc-disk-wait-idle 1))

(defun cc-disk-wait-idle (bit) 		;(&optional (bit 1))
   (do () ((not (zerop (LOGAND bit (phys-mem-read cc-disk-address)))))
       #M (SLEEP-JIFFIES 2)
       #Q (PROCESS-SLEEP 2)
       ))

(defun cc-disk-recalibrate nil 
  (cond 
	(t 
	  (cc-disk-op 1005)     ;Recalibrate
	  (cc-disk-wait-idle 4))) ;wait Sel Unit Attention - recal done
)

;;; THESE ARE REALLY ONLY USED FOR READING THE LABEL
;;; DEFAULT TO T-80'S
(SETQ BLOCKS-PER-TRACK 17. BLOCKS-PER-CYLINDER (* 17. 5) CC-DISK-TYPE NIL)

;;; INITIALIZES DISK PARAMETERS
(DEFUN CC-DISK-INIT ()
;  (setq marksman-p (= 1 (ldb (bits 2 22.)
;			     (phys-mem-read (+ cc-disk-address 1)))))
  (LET ((CC-DISK-TYPE T))
    (READ-LABEL))
  (SETQ BLOCKS-PER-CYLINDER (* N-HEADS N-BLOCKS-PER-TRACK))
  (SETQ BLOCKS-PER-TRACK N-BLOCKS-PER-TRACK)
  (SETQ CC-DISK-TYPE T))

;returns t if wins
(DEFUN CC-DISK-XFER (FCN DISK-BLOCK-NUM CORE-PAGE-NUM N-BLOCKS)
  (PROG (TRACK HEAD SECTOR DUSH ERRCNT STATUS)
     (DECLARE (FIXNUM TRACK HEAD SECTOR DUSH ERRCNT STATUS))
     (COND ((NOT CC-DISK-TYPE)(CC-DISK-INIT)))
     (SETQ ERRCNT CC-DISK-RETRY-COUNT)
     (SETQ TRACK (// DISK-BLOCK-NUM BLOCKS-PER-CYLINDER))
     (SETQ SECTOR (\ DISK-BLOCK-NUM BLOCKS-PER-CYLINDER))
     (SETQ HEAD (// SECTOR BLOCKS-PER-TRACK)
	   SECTOR (\ SECTOR BLOCKS-PER-TRACK))
     (SETQ DUSH (+ (CC-SHIFT TRACK 16.) (LSH HEAD 8) SECTOR))
     (AND (> N-BLOCKS 366) ;We only want to use 1 page for the command list
	  (ERROR N-BLOCKS 'TOO-MANY-BLOCKS-FOR-CMD-LIST 'FAIL-ACT))
 LP  ;;Set up the command list, starting at location 12, a bit of a kludge
     (DO ((I 12 (1+ I))
	  (A CORE-PAGE-NUM (1+ A))
	  (N N-BLOCKS (1- N)))
	 ((= N 0))
       (PHYS-MEM-WRITE I (+ (CC-SHIFT A 8) (COND ((= N 1) 0) (T 1)))))
     (LET ((CTALK-BARF-AT-WRITE-ERRORS NIL))  ;THESE MIGHT NOT READ BACK EXACTLY THE SAME...
      (PROG NIL 
       (PHYS-MEM-WRITE (+ CC-DISK-ADDRESS 0) FCN) ;Store command, does reset
       (PHYS-MEM-WRITE (+ CC-DISK-ADDRESS 1) 12)  ;Store CLP
       (SETQ CC-DISK-LAST-CMD FCN CC-DISK-LAST-CLP 12)
       (PHYS-MEM-WRITE (+ CC-DISK-ADDRESS 2) DUSH)  ;Store disk address
       (PHYS-MEM-WRITE (+ CC-DISK-ADDRESS 0) FCN) ;Store command, does reset
       (PHYS-MEM-WRITE (+ CC-DISK-ADDRESS 3) 0)   ;Start transfer
  WAIT ;;This loop awaits completion
       (AND (ZEROP (LOGAND 1 (SETQ STATUS (PHYS-MEM-READ CC-DISK-ADDRESS))))
	    (GO WAIT))))
     (COND ((NOT (ZEROP (LOGAND STATUS 47777560)))
		; ERROR BITS: INTERNAL PARITY, NXM, MEM PAR, HEADER COMPARE,
		; HEADER ECC, ECC HARD, ECC SOFT, OVERRUN, TRANSFER ABORTED,
		; START-BLOCK ERR, TIMEOUT, SEEK ERR, OFF LINE, OFF CYL, FAULT,
                ;    NO SEL, MUL SEL
	    (CC-DISK-ANALYZE)
	    (AND (ZEROP (SETQ ERRCNT (1- ERRCNT)))
		 (RETURN NIL))	       ;lost
	    (PRINT 'RETRYING)
	    (TERPRI)
	    (GO LP)))
     (RETURN T)		;won
     ))

;SAME AS CC-DISK-XFER, BUT TAKES ARGS IN TRACK, HEAD, SECTOR FORM.
; MAINLY GOOD FOR RETRYING TRANSFERS THAT LOSE, ETC.
(DEFUN CC-DISK-XFER-TRACK-HEAD-SECTOR (FCN TRACK HEAD SECTOR CORE-PAGE-NUM N-BLOCKS)
  (DECLARE (FIXNUM TRACK HEAD SECTOR DUSH ERRCNT STATUS))
  (PROG (DUSH ERRCNT STATUS)
     (SETQ ERRCNT CC-DISK-RETRY-COUNT)
     (SETQ DUSH (+ (CC-SHIFT TRACK 16.) (LSH HEAD 8) SECTOR))
     (AND (> N-BLOCKS 366) ;We only want to use 1 page for the command list
	  (ERROR N-BLOCKS 'TOO-MANY-BLOCKS-FOR-CMD-LIST 'FAIL-ACT))
 LP  ;;Set up the command list, starting at location 12, a bit of a kludge
     (DO ((I 12 (1+ I))
	  (A CORE-PAGE-NUM (1+ A))
	  (N N-BLOCKS (1- N)))
	 ((= N 0))
       (PHYS-MEM-WRITE I (+ (CC-SHIFT A 8) (COND ((= N 1) 0) (T 1)))))
     (LET ((CTALK-BARF-AT-WRITE-ERRORS NIL))  ;THESE MIGHT NOT READ BACK EXACTLY THE SAME...
      (PROG NIL 
       (PHYS-MEM-WRITE (+ CC-DISK-ADDRESS 0) FCN) ;Store command, does reset
       (PHYS-MEM-WRITE (+ CC-DISK-ADDRESS 1) 12)  ;Store CLP
       (SETQ CC-DISK-LAST-CMD FCN CC-DISK-LAST-CLP 12)
       (PHYS-MEM-WRITE (+ CC-DISK-ADDRESS 2) DUSH)  ;Store disk address
       (PHYS-MEM-WRITE (+ CC-DISK-ADDRESS 3) 0)   ;Start transfer
  WAIT ;;This loop awaits completion
       #M (SLEEP-JIFFIES 2)
       #Q (PROCESS-SLEEP 2)
       (AND (ZEROP (LOGAND 1 (SETQ STATUS (PHYS-MEM-READ CC-DISK-ADDRESS))))
	    (GO WAIT))))
     (COND ((NOT (ZEROP (LOGAND STATUS 47777560)))
		; ERROR BITS: INTERNAL PARITY, NXM, MEM PAR, HEADER COMPARE,
		; HEADER ECC, ECC HARD, ECC SOFT, OVERRUN, TRANSFER ABORTED,
		; START-BLOCK ERR, TIMEOUT, SEEK ERR, OFF LINE, OFF CYL, FAULT,
		;    NO SEL, MUL SEL
	    (CC-DISK-ANALYZE)
	    (AND (ZEROP (SETQ ERRCNT (1- ERRCNT)))
		 (RETURN NIL))
	    (PRINT 'RETRYING)
	    (TERPRI)
	    (GO LP)))
     ))


;THE QUEUEING/NON-QUEUEING DISTINCTION IS TEMPORARILY NOT PRESENT
(DEFUN CC-DISK-READ (DISK-BLOCK-NUM CORE-PAGE-NUM N-BLOCKS)
  (CC-DISK-READ-QUEUEING DISK-BLOCK-NUM CORE-PAGE-NUM N-BLOCKS))

(DEFUN CC-DISK-READ-QUEUEING (DISK-BLOCK-NUM CORE-PAGE-NUM N-BLOCKS)
  (AND CC-DISK-TRACE-FLAG (PRINT (LIST 'CC-DISK-READ DISK-BLOCK-NUM CORE-PAGE-NUM N-BLOCKS)))
  (CC-DISK-XFER CC-DISK-READ-FCN DISK-BLOCK-NUM CORE-PAGE-NUM N-BLOCKS))

(DEFUN CC-DISK-WRITE (DISK-BLOCK-NUM CORE-PAGE-NUM N-BLOCKS)
  (CC-DISK-WRITE-QUEUEING DISK-BLOCK-NUM CORE-PAGE-NUM N-BLOCKS))

(DEFUN CC-DISK-WRITE-QUEUEING (DISK-BLOCK-NUM CORE-PAGE-NUM N-BLOCKS)
  (AND CC-DISK-TRACE-FLAG (PRINT (LIST 'CC-DISK-WRITE DISK-BLOCK-NUM CORE-PAGE-NUM N-BLOCKS)))
  (CC-DISK-XFER CC-DISK-WRITE-FCN DISK-BLOCK-NUM CORE-PAGE-NUM N-BLOCKS))

;WRITE OUT ALL PAGES WHETHER OR NOT MODIFIED, SINCE WHEN THIS IS
;CALLED THEY OFTEN HAVEN'T GOTTEN TO DISK YET.
(DEFUN CC-DISK-WRITE-OUT-CORE (PARTITION-NAME)
  (LET ((X (GET-PARTITION-START-AND-SIZE PARTITION-NAME)))
    (LET ((PARTITION-START (CAR X)) (PARTITION-SIZE (CDR X)))
      (DO ((PHT-LOC (QF-POINTER (PHYS-MEM-READ (+ 400 %SYS-COM-PAGE-TABLE-PNTR)))
                    (+ 2 PHT-LOC))
	   (PHT-COUNT (// (QF-POINTER (PHYS-MEM-READ (+ 400 %SYS-COM-PAGE-TABLE-SIZE))) 2)
		      (1- PHT-COUNT))
	   (PHT1)
	   (PHT2))
	  ((= 0 PHT-COUNT))
	(DECLARE (FIXNUM PHT-LOC PHT-COUNT PHT1 PHT2))
	(AND (NOT (ZEROP (LOGLDB %%PHT1-VALID-BIT
				  (SETQ PHT1 (PHYS-MEM-READ PHT-LOC)))))	;IF PAGE EXISTS
	     (NOT (= (LOGLDB %%PHT1-VIRTUAL-PAGE-NUMBER PHT1)
		     %PHT-DUMMY-VIRTUAL-ADDRESS))		;AND ISN'T A DUMMY
	     (PROGN					;THEN WRITE IT OUT
	       (SETQ PHT2 (PHYS-MEM-READ (1+ PHT-LOC)))
	       (OR (< (LOGLDB %%PHT1-VIRTUAL-PAGE-NUMBER PHT1) PARTITION-SIZE)
		   (ERROR '|Core doesn't fit in the partition; partition has been clobbered.|
			  (LOGLDB %%PHT1-VIRTUAL-PAGE-NUMBER PHT1) 'FAIL-ACT))
	       (CC-DISK-WRITE-QUEUEING
			      (+ PARTITION-START
				 (LOGLDB %%PHT1-VIRTUAL-PAGE-NUMBER PHT1))
			      (LOGLDB %%PHT2-PHYSICAL-PAGE-NUMBER PHT2)
			      1)
	       (OR (= (LOGLDB %%PHT1-SWAP-STATUS-CODE PHT1) %PHT-SWAP-STATUS-WIRED)
		   (PROGN					;IF NOT WIRED, REMOVE FROM CORE AND
		     (PHYS-MEM-WRITE PHT-LOC
				     (LOGDPB %PHT-DUMMY-VIRTUAL-ADDRESS	;STORE BACK DUMMY ENTRY
					      %%PHT1-VIRTUAL-PAGE-NUMBER
					      (LOGDPB %PHT-SWAP-STATUS-FLUSHABLE
						       %%PHT1-SWAP-STATUS-CODE
						       PHT1)))
		     (PHYS-MEM-WRITE (1+ PHT-LOC)
			     (LOGDPB 200 ;READ-ONLY
				     %%PHT2-ACCESS-STATUS-AND-META-BITS PHT2)))))))
      ;NOW WRITE OUT THE PAGE HASH TABLE AGAIN SINCE IT'S BEEN MODIFIED
      ;1P AT A TIME SINCE MIGHT BE BIGGER THAN THE MAP OR SOMETHING
      ((LAMBDA (PHT-FIRST-PAGE PHT-N-PAGES)
         (DECLARE (FIXNUM PHT-FIRST-PAGE PHT-N-PAGES))
	 (DO ((DA (+ PARTITION-START PHT-FIRST-PAGE) (1+ DA))
	      (PG PHT-FIRST-PAGE (1+ PG))
	      (N PHT-N-PAGES (1- N)))
	     ((= N 0))
	   (DECLARE (FIXNUM DA PG N))
	   (CC-DISK-WRITE-QUEUEING DA PG 1)))
       (// (QF-POINTER (PHYS-MEM-READ (+ 400 %SYS-COM-PAGE-TABLE-PNTR))) 400)
       (// (QF-POINTER (PHYS-MEM-READ (+ 400 %SYS-COM-PAGE-TABLE-SIZE))) 400)))
  )) ;DONE, NO NEED TO FLUSH QUEUE SINCE NOT USING QUEUEING NOW

(DEFUN CC-DISK-READ-IN-CORE (PARTITION-NAME)
  (LET ((X (GET-PARTITION-START-AND-SIZE PARTITION-NAME)))
    (LET ((PARTITION-START (CAR X)))
      (QF-CLEAR-CACHE T)			;INVALIDATING CONTENTS OF CORE
      (CC-DISK-READ-QUEUEING (1+ (CAR X)) 1 1)	;GET SYSTEM-COMMUNICATION-AREA
      (DO ((PHT-LOC (QF-POINTER (PHYS-MEM-READ (+ 400 %SYS-COM-PAGE-TABLE-PNTR))))
	   (PHT-COUNT (// (+ 377 (QF-POINTER
                                  (PHYS-MEM-READ (+ 400 %SYS-COM-PAGE-TABLE-SIZE))))
			  400))
	   )
	  NIL
	(DECLARE (FIXNUM PHT-LOC PHT-COUNT))
	(DO J 0 (+ J 1) (NOT (< J PHT-COUNT))		;GET PAGE-TABLE-AREA, 1P AT A TIME
	    (CC-DISK-READ-QUEUEING
			  (+ PARTITION-START (// PHT-LOC 400) J)
			  (+ (// PHT-LOC 400) J)
			  1)))				;NOW READ IN ALL THE PAGES
      (DO ((PHT-LOC (PHYS-MEM-READ (+ 400 %SYS-COM-PAGE-TABLE-PNTR)) (+ 2 PHT-LOC))
	   (PHT-COUNT (// (QF-POINTER (PHYS-MEM-READ (+ 400 %SYS-COM-PAGE-TABLE-SIZE))) 2)
		      (1- PHT-COUNT))
	   (PHT1) 
	   (PG))
	  ((= 0 PHT-COUNT))
	(DECLARE (FIXNUM PHT-LOC PHT-COUNT PHT1 PG))
	(AND (NOT (ZEROP (LOGLDB %%PHT1-VALID-BIT (SETQ PHT1 (PHYS-MEM-READ PHT-LOC)))))
	     (NOT (= (SETQ PG (LOGLDB %%PHT1-VIRTUAL-PAGE-NUMBER PHT1))
		     %PHT-DUMMY-VIRTUAL-ADDRESS))		;NOT DUMMY
	     ;; Don't read in the MICRO-CODE-SYMBOL-AREA, it's part of the ucode logically.
	     (OR (< PG MICRO-CODE-SYMBOL-AREA-START) (NOT (< PG MICRO-CODE-SYMBOL-AREA-END)))
	     (CC-DISK-READ-QUEUEING
			   (+ PARTITION-START PG)
			   (LOGLDB %%PHT2-PHYSICAL-PAGE-NUMBER (PHYS-MEM-READ (1+ PHT-LOC)))
			   1)))
  ))) ;NO NEED TO EMPTY QUEUE SINCE NOT CURRENTLY USING QUEUEING
(DECLARE (SPECIAL CC-DISK-LOWCORE CC-DISK-HIGHCORE))
(SETQ CC-DISK-LOWCORE 10 CC-DISK-HIGHCORE 300)

(DEFUN CC-DISK-COPY-PARTITION (FROM-PARTITION TO-PARTITION)
  (LET ((FROM-DESC (GET-PARTITION-START-AND-SIZE FROM-PARTITION))
	(TO-DESC (GET-PARTITION-START-AND-SIZE TO-PARTITION)))
    (LET ((FROM-START (CAR FROM-DESC))
	  (FROM-SIZE (CDR FROM-DESC))
	  (TO-START (CAR TO-DESC))
	  (TO-SIZE (CDR TO-DESC)))
      (COND ((NOT (= FROM-SIZE TO-SIZE))
	     (PRINT (LIST FROM-SIZE TO-SIZE))
	     (PRINC '|partition sizes differ.  |)
	     (OR (Y-OR-N-P '|Continue anyway?|) (^G))))
      ;ALL NUMBERS WITHIN THIS DO ARE IN PAGES, NOT WORDS.
      (DO ((LOWCORE CC-DISK-LOWCORE)    ;DON'T SMASH BOTTOM 2K WITH SYSTEM-COMMUNICATION, ETC.
	   (HIGHCORE CC-DISK-HIGHCORE)  ;ONLY RELY ON 48K BEING PRESENT 
	   (RELADR 0 (+ RELADR (- HIGHCORE LOWCORE)))) ;THIS IS RELATIVE LOC WITHIN PARTITION
	  ((NOT (< RELADR (MIN FROM-SIZE TO-SIZE))))
	(DECLARE (FIXNUM LOWCORE HIGHCORE MAP-SIZE RELADR COREADD TOGO))
	(CC-DISK-READ-QUEUEING
			(+ FROM-START RELADR)
			LOWCORE
			(MIN (- FROM-SIZE RELADR) (- HIGHCORE LOWCORE)))
	(CC-DISK-WRITE-QUEUEING
			(+ TO-START RELADR)
			LOWCORE
			(MIN (- TO-SIZE RELADR) (- HIGHCORE LOWCORE)))
	))))	;DONE, NO NEED TO EMPTY QUEUE IN THIS VERSION
    
(DEFUN CC-DISK-SAVE (PARTITION)
  (COND	((NUMBERP PARTITION)
	 (SETQ PARTITION (IMPLODE (APPEND '(L O D) (LIST (+ 60 PARTITION)))))))
  (GET-PARTITION-START-AND-SIZE PARTITION) ;CAUSE AN ERROR IF NOT A KNOWN PARTITION
  (CC-DISK-WRITE-OUT-CORE 'PAGE)
  (CC-DISK-COPY-PARTITION 'PAGE PARTITION)
  (CC-DISK-READ-IN-CORE 'PAGE))

(DEFUN CC-DISK-RESTORE NARGS
  (LET ((PARTITION (AND (= NARGS 1) (ARG 1))))
    (COND ((NULL PARTITION)
	   (AND (> NARGS 1) (ERROR '|TOO MANY ARGS - CC-DISK-RESTORE| NARGS))
	   (CC-DISK-INIT)  ;Use pack editor to find out what is current default load
	   (SETQ PARTITION INITIAL-LOD-NAME))
	  ((NUMBERP PARTITION)
	   (SETQ PARTITION (IMPLODE (APPEND '(L O D) (LIST (+ 60 PARTITION)))))))
    (GET-PARTITION-START-AND-SIZE PARTITION) ;CAUSE AN ERROR IF NOT A KNOWN PARTITION
    (CC-DISK-COPY-PARTITION PARTITION 'PAGE)
    (CC-DISK-READ-IN-CORE 'PAGE)))

(DEFUN CC-CHECK-PAGE-HASH-TABLE-ACCESSIBILITY NIL 
  (DO ((TABLE-ADR PHT-ADDR (+ TABLE-ADR 2))
       (HASH-ADR)
       (PHT1)
       (COUNT (LSH SIZE-OF-PAGE-TABLE -1) (1- COUNT))
       (NUMBER-ERRORS 0))
      ((= COUNT 0) NUMBER-ERRORS)
   (DECLARE (FIXNUM TABLE-ADR HASH-ADR COUNT))
   (SETQ PHT1 (PHYS-MEM-READ TABLE-ADR))
   (COND ((= 0 (LOGLDB %%PHT1-VALID-BIT PHT1)))
	 ((= %PHT-DUMMY-VIRTUAL-ADDRESS (LOGLDB %%PHT1-VIRTUAL-PAGE-NUMBER PHT1))) ;DUMMY
         ((NOT (= TABLE-ADR 
		  (SETQ HASH-ADR (QF-PAGE-HASH-TABLE-LOOKUP (LOGAND PHT1 77777400)))))
	   (PRINT (LIST '(HASH TABLE PAIR AT PHYS MEM ADR) TABLE-ADR '(NOT ACCESSIBLE)))
	   (PRINT (LIST '(HASH LOOKUP RETURNS) HASH-ADR))
	   (SETQ NUMBER-ERRORS (1+ NUMBER-ERRORS)) ))))

(DEFUN GET-PARTITION-START-AND-SIZE (PARTITION-NAME)
  (CC-DISK-INIT)
  (DO ((I 0 (1+ I)))
      ((NOT (< I N-PARTITIONS))
       (ERROR '|No such partition| PARTITION-NAME))
   (COND ((EQ (ARRAYCALL T PARTITION-NAMES I) PARTITION-NAME)
	  (RETURN (CONS (ARRAYCALL FIXNUM PARTITION-START I)
			(ARRAYCALL FIXNUM PARTITION-SIZE I)))))))

#M
(DECLARE (SPECIAL LOWCORE))

;To be called by the user.
#M ;this has no chance of working in the Lisp machine.  Use SI:LOAD-MCR-FILE
(DEFUN STUFF-MCR-FILE (FILENAME PARTITION-NAME)
  (CC-DISK-INIT)
  (LET ((FILE (OPEN FILENAME '(IN FIXNUM BLOCK)))
	(PART (GET-PARTITION-START-AND-SIZE PARTITION-NAME)))
    (AND (> (LENGTHF FILE) (* 400 (CDR PART)))
	 (ERROR '|File is too big to fit in partition|))
    ;Bash main memory page LOWCORE, READ-LABEL saved it so we'll read it back again afterwards
    (DO ((DISK-ADDRESS (CAR PART) (1+ DISK-ADDRESS))
	 (COUNT (// (LENGTHF FILE) 400) (1- COUNT)))
	((ZEROP COUNT))
      (DECLARE (FIXNUM DISK-ADDRESS COUNT))
      (DO ((ADR (* LOWCORE 400) (1+ ADR))
	   (COUNT 400 (1- COUNT)))
	  ((ZEROP COUNT))
	(DECLARE (FIXNUM ADR COUNT))
	(PHYS-MEM-WRITE ADR (LSH (IN FILE) -4)))
      (CC-DISK-WRITE DISK-ADDRESS LOWCORE 1))
    (CC-DISK-READ 1 LOWCORE 1)))

;Called on startup (analogous to the PDUMP function on the 10)
(IF-FOR-LISPM
(DEFUN CC-INITIALIZE-ON-STARTUP ()
  (SETQ CC-FULL-SAVE-VALID NIL)
  (SETQ CC-PASSIVE-SAVE-VALID NIL)
  (SETQ CC-DISK-TYPE NIL)))

(IF-FOR-LISPM (ADD-INITIALIZATION "CADR" '(CC-INITIALIZE-ON-STARTUP) '(BEFORE-COLD)))
