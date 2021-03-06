;;; -*- mode: lisp; package: cube  -*-
;;; BSG 3/30/80 - his first ITS lisp program    -*-LISP-*-
;;; BSG also made me for the LISPM, still during his Multics days, too.
;;; BSG brought me up to LISPM window/menu sys, Jan. 1981
;;; Process - 11 Sept 1981 - Symbolics, Inc.

(array screeni t  24. 80.) ;yes folks this will work in general. - for prty baloney
(declare (special cube-lineno cube-xpos have-slain cube-curface))
(declare (special overstrike-availablep))
(defvar solve-halt)
(defvar known-cube-transforms nil)
(defvar bw-mother-cube-window)
(defvar cube-menu)
(defvar bw-window)
(defvar color-window)
(defvar auxiliary-cube-menu)

(declare (special cphi ctheta known-cubes))	;in qcolor--

(defmacro solve-setup-mac stuff
  `(progn (set-for-solve)
	  ,@ stuff
	  (cube-legending-info)))


(defflavor cubesys ()
	   (tv:process-mixin
	    tv:bordered-constraint-frame-with-shared-io-buffer))

(defmethod (cubesys :name-for-selection) () tv:name)    ;cubesys-1 etc.

(defmethod (cubesys :before :init) (&rest ignore)
  (or tv:process (setq tv:process '(cube-process-fcn))))

(defflavor cube-interaction-mixin () (tv:any-tyi-mixin))

(defmethod (cube-interaction-mixin :after :refresh) (&rest ignore)
  (funcall-self ':cube-legending))

(defmethod (cube-interaction-mixin :cube-legending) ()
  (let ((terminal-io self))
    (cube-legending-info)))


(defflavor cube-graphics-pane () (cube-graphics-mixin tv:pane-mixin tv:window))

(defflavor bw-cube-graphics-pane ()
	   (cube-interaction-mixin tv:dont-select-with-mouse-mixin cube-graphics-pane))


(defflavor cube-color-window ()
	   (cube-graphics-mixin tv:dont-select-with-mouse-mixin tv:window))

(defmethod (cube-graphics-mixin :who-line-documentation-string) ()
  (multiple-value-bind (x-offset y-offset)
      (tv:sheet-calculate-offsets self tv:mouse-sheet)
    (setq x-offset (- tv:mouse-x x-offset)
	  y-offset (- tv:mouse-y y-offset))
    (let ((facep (funcall-self ':coordinates-in-face-p x-offset y-offset)))
      (selectq facep
	(FRONT
	 "L: Turn front face L (CCW) M: Rotate cube 180 degrees around front R: Turn front face R (CW)")
	(TOP
	 "L: Turn top face L (CCW) M: Rotate cube 180 degrees around top   R: Turn top face R (CW)")
	(SIDE
	 "L: Turn RHS face L (CCW) M: Rotate cube 180 degrees around sides   R: Turn RHS face R (CW)")
	(t "M: Move mouse to other screen")))))
						
(compile-flavor-methods cube-interaction-mixin
			cube-graphics-pane
			bw-cube-graphics-pane
			cube-color-window
			cubesys)




(defconst *cube-menu-choices*
  '(("Initialize Cube" :eval (init-cube)
     :documentation "Initialize the cube to a solved configuration")
    ("Rotate Cube 180" :eval (rotate-cube cube-curface 180.)
     :documentation "Rotate the cube 180 degrees about the selected face")
    ("Rotate Cube clockwise" :eval (rotate-cube cube-curface 'right)
     :documentation "Rotate the cube 90 degrees clockwise about the selected face")
    ("Rotate Cube Ccw" :eval (rotate-cube cube-curface 'left)
     :documentation "Rotate the cube 90 degrees counterclockwise about the selected face")
    ("Select cube face" :eval (menu-select-cube-face)
     :documentation "Select a new cube face from a menu")
    ("Solve cube" :eval (solve-setup-mac (solve-cube))
     :documentation "Solve the cube as it stands, step by step")
    ("Transforms" :eval (menu-cube-transforms)
     :documentation "Put up a menu of all known cube transforms")
    ("Rotate face Clockwise" :eval (rotate-face cube-curface 'right)
     :documentation "Rotate the selected face 90 degrees clockwise")
    ("Rotate face Ccw"	:eval (rotate-face cube-curface 'left)
     :documentation "Rotate the selected face 90 degrees counterclockwise")
    ("Rotate face 180" :eval (rotate-face cube-curface 180.)
     :documentation "Rotate the selected face 180 degrees")
    ("Randomize Cube" :eval (randomize-cube)
     :documentation "Randomize the cube by doing 10 random twists at once")
    ("Quit Cubesys" :kbd #/q
     :documentation "Exit Cubesys")
    ("Other" :menu auxiliary-cube-menu
     :documentation "Menu of more esoteric operations")
    ("HELP" :eval (cube-help)
     :documentation "General help information about Cubesys")
    ("Input Cube" :eval (cube-input)
     :documentation "Input the state of a cube from a file, more help will be given")))

(defconst *auxiliary-cube-menu-choices*
  '(("Re-solve Cube" :eval (solve-setup-mac (re-solve-cube))
     :documentation "Solve the last cube solved again")
    ("Set Display Angles" :eval (set-cube-angles)
     :documentation "Set the angles of rotation of the cube display")
    ("Toggle B & W display" :eval (toggle-bw-display)
     :documentation "Toggle the black and white display on and off")
    ("Toggle Color Display" :eval (toggle-color-display)
     :documentation "Toggle the color display on and off")
    ("Redisplay" :eval (funcall bw-window ':refresh)
     "Refresh the cube display")
    ("Printing Display" :eval (invoke-printing-display-cube)
     :documentation "Display the state of the cube in printout"))) ;in gut cubesys

;;;
;;; Lispm Cube toplevel  -- user:cube calls this directly
;;;

(defun run-cube ()
  (or (boundp 'color-window)
      (not colorp)
      (setq color-window (tv:make-window
			  'cube-color-window
			   ':label "  CUBESYS//Lispm"
			   ':borders nil
			   ':superior color:color-screen
			   ':blinker-p nil)))
  (if (not (boundp 'bw-mother-cube-window)) (create-mother-cube-window))

  (if colorp (progn				;share i/io buffers so color-window
	       (funcall color-window ':expose)	;sends mouse droppings to bw-window
	       (funcall color-window ':set-io-buffer (funcall bw-window ':io-buffer))))
  (setq overstrike-availablep t)		;for prty display cruft
  (setq cube-curface 1)				;the current face is 1
  (funcall bw-mother-cube-window ':select)
  t)

(defun cube-process-fcn (window)		;bw-win
  (let ((terminal-io bw-window))
       (do ()(nil)
	 (*catch
	   'sys:command-level			;abort catch
	   (do ()(nil)
	     (redisplay-cube)
	     (cursorpos 49. 0)			;goto input area
	     (cursorpos 'l) 
	     (let ((gotten (funcall bw-window ':any-tyi)))
		  (cond ((listp gotten)
			 (selectq (first gotten)
			   (:menu         (funcall cube-menu ':execute (second gotten)))
			   (:mouse-button (apply 'vermin-interpreter (cdr gotten)))))
			((fixp gotten)
			 (if (char-equal gotten #/q)
			     (progn
			       (funcall window ':bury)
			       (process-wait "Await Exposure"
					     #'(lambda (x) (eq (funcall x ':status)
							       ':selected))
					     bw-window))
			     (selectq gotten
			       (#\HELP (cube-help))
			       (#\CLEAR-SCREEN (funcall window ':refresh))
			       (#^L (funcall window ':refresh))
			       (t (tv:beep)))))))))
	 (cube-legending-info))))



(defun uncube ()				;for debugging only
  (funcall bw-mother-cube-window ':deactivate)
  (and (boundp 'color-window)(funcall color-window ':deactivate))
  (makunbound 'bw-mother-cube-window)
  (makunbound 'color-window)
  (setq known-cubes nil))

(defun create-mother-cube-window ()
  (setq bw-mother-cube-window
	(tv:make-window
	  'cubesys
	  ':panes
	     `((bw-cube-graphics bw-cube-graphics-pane)
	       (cube-menu tv:command-menu-pane :item-list ,*cube-menu-choices*
			  :label "Cube command"))
          ':selected-pane 'bw-cube-graphics
	  ':constraints
	     '((cube-mother-config .		;configuration
		((bw-cube-graphics cube-menu)	;ordering list
		 ((cube-menu :ask :pane-size))
		 ((bw-cube-graphics :limit (54. nil :lines) :even)))))))
  (setq bw-window (funcall bw-mother-cube-window ':get-pane 'bw-cube-graphics))
  (setq cube-menu (funcall bw-mother-cube-window ':get-pane 'cube-menu))
  (setq auxiliary-cube-menu
	(tv:make-window
	  'tv:momentary-menu
	  ':superior bw-mother-cube-window
	  ':label "Auxiliary command"
	  ':item-list *auxiliary-cube-menu-choices*)))

(defun redisplay-cube ()
       (setq cube-lineno 28. cube-xpos 0 have-slain nil)
       (color-cube))


(defun display-cube-repertoire ()
       (cursorpos 45. 0)
       (cursorpos 'l)
       (princ '|Selected: |)
       (terpri)
       (princ "Mouse at selected cube command with left button.  Rotates select")
       (terpri)
       (princ "face selected with /"Select Cube Face./". /"Other/" for more commands.")
       (terpri)
       (princ "Type the HELP Key at the extreme right for more help.")
       (terpri))

(defun display-face-choice ()
       (cursorpos 45. 10.)
       (cursorpos 'l)
       (princ cube-curface)
       (princ '| (|)
       (do i 1 (1+ i)(> i 6)
	   (and (= cube-curface (symeval (face-names i)))(return (princ (face-names i)))))
       (princ '|)|))


(defun toggle-color-display ()
  (cond ((color:color-exists-p)(setq colorp (not colorp))) ;t = toggle color
	(t (print "you do not have color")))
  (if colorp (funcall color-window ':update-thyself)))

(defun toggle-bw-display ()
  (setq bwp (not bwp))
  (if bwp (funcall bw-window ':update-thyself)))

(defun menu-select-cube-face ()
  (let ((item (tv:menu-choose
		'(("Top" TOP) ("Right Hand Side" RHS) ("Left Hand Side" LHS)
		  ("Bottom" BOTTOM) ("Front" FRONT) ("Back" BACK))
		"Cube face")))
    (cond ((not (null item))
	   (setq cube-curface (symeval item))
	   (display-face-choice)))))


(defun menu-cube-transforms ()
  (cond (known-cube-transforms
	 (multiple-value-bind (nil element)
	     (tv:menu-choose known-cube-transforms "Transform")
	   (and element
		(let ((package package))
		  (pkg-goto 'cube)
		  (run-xform element)))))
	(t (print "no known transforms"))))


(defun cube-legending-info ()
       (cursorpos 45. 0)
       (cursorpos 'e) ;erase line 45. and below
       (cursorpos 't)
       (fillarray 'screeni '(nil))
       (display-cube-repertoire)
       (display-face-choice))

(defun cube-trace n
       (redisplay-cube)
       (cursorpos 50. 5.)
       (cursorpos 'l)
       (mapc 'princ (listify n))
       (cond ((kbd-char-available)(setq solve-halt t)))
       (cond (solve-halt
	       (let ((command (tyi)))
		 (cond ((char-equal command #/p) (setq solve-halt nil)))))
	     (t (global:process-sleep 20))))

(setq tracing-cube t)

(defun set-for-solve ()
       (cursorpos 45. 0)(cursorpos 'l)
       (dotimes (i 4)(terpri))
       (princ '|Solution in progress: P to proceed, type SPACE for each step, ABORT to stop solving.|)
       (setq solve-halt t))


(defun set-cube-angles ()
  (let ((theta (set-cube-angles-prompt "vertical"))
	(phi (set-cube-angles-prompt "horizontal")))
    (setq cphi phi ctheta theta))		;delay until read successfully.
  (redimension-all-cubes))

(defun set-cube-angles-prompt (prompt)
  (let ((ibase 10.)(*nopoint t))
    (do nil (nil)
      (cursorpos 50. 10.)
      (cursorpos 'l)
      (format t "Input rotation angle around ~A, 0 to 90 degrees: " prompt)
      (let ((ang (read)))
	(cond ((and (fixp ang)(> ang -1)(< ang 91.))
	       (return (setq cphi ang))))
	(tv:beep)))))

;;;
;;;    Pseudo-obsolete printing-terminal display left over from other implementations
;;;

(defun invoke-printing-display-cube ()
  (display-cube)				;in gut cubesys
  (terpri)
  (princ "   ***   Hit  CLEAR SCREEN to flush   ***   "))

(defun cube-displaypos (x)
       (setq cube-xpos x))

(defun cube-terpri ()
       (setq cube-xpos 0)
       (setq cube-lineno (+ 1 cube-lineno)))

(defun cube-princ (s)
       (let ((there (screeni cube-lineno cube-xpos)))
	    (cond ((and (not have-slain)(eq s there)))
		  (t (store (screeni cube-lineno cube-xpos) s)
		     (cursorpos cube-lineno cube-xpos)
		     (redisplay-princ cube-xpos s there)))
	    (setq cube-xpos (+ (flatc s) cube-xpos))))


(defun redisplay-princ (pos new old)
       (let ((oldl (cond ((null old) 0)(t (flatc old))))
	     (newl (flatc new)))
	    (cond (overstrike-availablep
		   (do i 1 (1+ i) (> i oldl)
		       (cursorpos 'k)
		       (cursorpos 'f))
		   (cursorpos cube-lineno pos)))
	    (princ new)
	    (cond ((not overstrike-availablep)
		   (and (> oldl newl)
			(do i newl (1+ i)(= i oldl)(tyo 40)))))))
		     

;;;
;;;   Mouse hit interpreter

(defun vermin-interpreter (click window x y)
  (let ((facep (funcall window ':coordinates-in-face-p x y))
	(button (ldb %%kbd-mouse-button click)))
    (cond ((null facep)
	   (cond ((and (= button 1) colorp)
		  (tv:mouse-set-sheet
		    (tv:sheet-get-screen
		      (cond ((eq window color-window) bw-window)
			    (t color-window)))))
		 (t (tv:beep))))
	  (t (let ((face (symeval (cdr (assq facep '((FRONT . FRONT)
						     (TOP . TOP)
						     (SIDE . RHS))))))
		   )
	       (setq cube-curface face)
	       (display-face-choice)
	       (cond ((= button 1)		;middle
		      (rotate-cube cube-curface 180.))
		     (t (rotate-face cube-curface
				     (cond ((= button 0) 'left)
					   (t 'right))))))))))

(defconst *cube-help*
 "   You are using the Lisp Machine implementation of /"Cubesys/", a Rubik's
cube modeling system by Bernard Greenberg.  David Christman co-authored the graphics
hacking.
   The system can rotate faces on the displayed cube, or rotate the cube itself. It
can run predefined transforms, or solve the cube (algorithmically, not by /"remembering
what you did to it/") step-by step.
   The basic technique for issuing requests to Cubesys is to move the mouse
to the lower window on the main display screen, and click any mouse button.  One face
of the cube is always known as the /"selected face/": its identity is displayed on
the main screen after the word /"Selected/".  There are menu items to rotate the
selected face right (clockwise), left (counterclockwise), or 180 degrees, or rotate
the cube about the selected face.  To select some other face than the current one,
choose the /"Select cube face/" menu item, and then choose (via a menu that will
pop up at that time) the new face.  You may then rotate this face or rotate
the cube about this face.
   Another technique for rotating the faces and the cube is to mouse at the
actual display (selecting screens if necessary).  If, while mousing at a cube
face, you click the right button, you will turn that face right, left button
will turn it left, and the middle button will rotate the cube 180 degrees
about an axis through that face (so that you may see other sides).
   The /"Randomize cube/" menu item will permute the cube randomly (yet solvably)
so you may watch Cubesys solve it.
   The /"Other/" menu item selects other commands that may be of interest, such
as toggling the black and white and color displays on and off (you will get
only a color display on a color Lisp Machine by default, and a black-and-white
display on a non-color Lisp machine).
   If you have multiple screens, mousing the display off the cube with the
middle button will select the other screen.
   You may exit Cubesys by selecting the /"Quit Cubesys/" menu item, or by
typing a /"q/".  ABORT may be used to re-enter Cubesys from a breakpoint.

   To enter Cubesys, (load /"ai:bsg;cubpkg >/") and wait about a minute and a
half for things to load.  Thenceforth type (cube) to use it... the first time
it will be slow, and all subsequent times fast.  Cubesys also runs on ITS
(:CUBE) and on Multics (as an Emacs mode).


  Type a space (or mouse any button) to flush: ")

(defun cube-help ()
  (let ((terminal-io bw-window))
    (funcall terminal-io ':set-cursorpos 0 0)
    (funcall terminal-io ':clear-eof)
    (funcall terminal-io ':string-out *cube-help*)
    (funcall terminal-io ':any-tyi))
  (funcall bw-window ':refresh))

(format t "~&This version of Cubesys runs in its own process. (cube) is still
the right way, but now mouse selection and TERMINAL-S will work too.")