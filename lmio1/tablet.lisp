;;; -*- Mode: LISP;  Package: SYSTEM-INTERNALS;  Base: 8 -*-
;	** (c) Copyright 1980 Massachusetts Institute of Technology **

(DEFVAR TABLET-OLD-BUTTONS 0)
(DEFVAR TABLET-CSR 764040)
(DEFVAR TABLET-X-REG (+ TABLET-CSR 2))
(DEFVAR TABLET-Y-REG (+ TABLET-CSR 4))
(DEFVAR TABLET-X 0)
(DEFVAR TABLET-Y 0)
(DEFVAR TABLET-BUTTONS 0)
(DEFVAR TABLET-PROXIMITY 0)
(DEFVAR TABLET-OLD-X 0)
(DEFVAR TABLET-OLD-Y 0)
(DEFVAR %TABLET-BUSY 200)
(DEFVAR %TABLET-PROXIMITY 20)
(DEFVAR %%TABLET-BUTTONS 1103)
;(DEFVAR %%TABLET-BUTTONS 0601)
(DEFVAR TABLET-MASK 1)
(DEFVAR TABLET-X-SCALE '(1 . 1))
(DEFVAR TABLET-Y-SCALE '(-1 . 1))

(DEFVAR TABLET-MAP-BUTTONS (MAKE-ARRAY NIL ART-4B 8))   ;Tablet buttons read in reflected
(DOTIMES (I 10)
  (AS-1 (DPB I 0201 (+ (LOGAND I 2) (LDB 0201 I)))
	TABLET-MAP-BUTTONS I))

(DEFUNP MOUSE-INPUT-TABLET (&OPTIONAL (WAIT-FLAG T) &AUX CHANGED-BUTTONS DX DY)
  "This function can be used in place of mouse input to make the tablet behave like the
mouse."
  (%UNIBUS-WRITE TABLET-CSR 2)
  (PROCESS-WAIT "Tablet"
		#'(LAMBDA (WAIT-FLAG &AUX CSR)
		    (SETQ CSR (%UNIBUS-READ TABLET-CSR))
		    (SETQ TABLET-BUTTONS (LOGXOR TABLET-MASK
						 (AR-1 TABLET-MAP-BUTTONS
						       (LDB %%TABLET-BUTTONS CSR))))
		    (COND ((ZEROP (LOGAND CSR %TABLET-BUSY))
			   (NOT WAIT-FLAG))
			  (( (LOGAND CSR %TABLET-PROXIMITY) 0)
			   (SETQ TABLET-PROXIMITY 0)	;leaving table.
			   (NOT WAIT-FLAG))
			  (T
			    (SETQ TABLET-X (// (* (CAR TABLET-X-SCALE)
						  (LOGAND 177774 (%UNIBUS-READ TABLET-X-REG)))
					       (CDR TABLET-X-SCALE))
				  TABLET-Y (// (* (CAR TABLET-Y-SCALE)
						  (LOGAND 177774 (%UNIBUS-READ TABLET-Y-REG)))
					       (CDR TABLET-Y-SCALE)))
			    (COND ((ZEROP TABLET-PROXIMITY)
				   (SETQ TABLET-PROXIMITY 1
					 TABLET-OLD-X TABLET-X
					 TABLET-OLD-Y TABLET-Y)	;comming into range
				   (NOT WAIT-FLAG))
				  (T
				    (NOT (AND (= TABLET-X TABLET-OLD-X)
					      (= TABLET-Y TABLET-OLD-Y)
					      (= TABLET-OLD-BUTTONS TABLET-BUTTONS)
					      WAIT-FLAG)))))))
		WAIT-FLAG)
  (WITHOUT-INTERRUPTS
    (SETQ CHANGED-BUTTONS (LOGXOR TABLET-BUTTONS TABLET-OLD-BUTTONS)
	  TABLET-OLD-BUTTONS TABLET-BUTTONS
	  MOUSE-LAST-BUTTONS TABLET-BUTTONS)
    (SETQ DX (- TABLET-X TABLET-OLD-X) DY (- TABLET-Y TABLET-OLD-Y))
    (SETQ TABLET-OLD-X TABLET-X TABLET-OLD-Y TABLET-Y)
    (SETQ MOUSE-LAST-X (+ MOUSE-LAST-X DX)
	  MOUSE-LAST-Y (+ MOUSE-LAST-Y DY)))
  (RETURN DX DY
	  (LOGAND TABLET-BUTTONS CHANGED-BUTTONS)
	  (BOOLE 2 TABLET-BUTTONS CHANGED-BUTTONS)))


(DEFUN INSTALL-TABLET (&OPTIONAL (INSTALL-P T))
  (COND (INSTALL-P 
	  (COND ((NULL (GET 'MOUSE-INPUT 'OLD-DEF))
		 (PUTPROP 'MOUSE-INPUT (FSYMEVAL 'MOUSE-INPUT) 'OLD-DEF)))
	  (FSET 'MOUSE-INPUT 'MOUSE-INPUT-TABLET))
	((GET 'MOUSE-INPUT 'OLD-DEF)
	 (FSET 'MOUSE-INPUT (GET 'MOUSE-INPUT 'OLD-DEF)))))

(DEFVAR TABLET-BITS '(INTR-ENABLE ENABLE TRIG RANGE PROX CLEAR Z-AXIS BUSY
		      POWER-ON FLAG3 FLAG2 FLAG1 UNUSED UNUSED Y-OVF X-OVF))

(DEFUN TABLET-STATUS NIL
  (CADR:CC-PRINT-SET-BITS (%UNIBUS-READ TABLET-CSR) TABLET-BITS))

