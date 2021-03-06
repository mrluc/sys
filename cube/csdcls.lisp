;;;
;;;  Macros and declarations for Hungarian Cube Solver, BSG 3/30/80
;;;  Isolated to facilitate separate compilation of new phases/hacks.
;;;

(multicsp (%include cube-dcls))
(itsp (includef '|bsg;cube dcls|))
(declare (*lexpr cube-trace))

;;; Special declarations.

(declare (special save-interesting-cube-for-later-analysis tracing-cube
                  cube-face-lambda-level
                  cube-pending-rot-stack cube-dont-stack-rots))

;;;   Essentially "manifest constants" for coordinate pairs (row col)
;;;   and row and column designations.
;;;

(declare (special LEFT-COL RIGHT-COL CENTER-COL TOP-ROW MIDDLE-ROW BOTTOM-ROW))
(declare (special UPPER-LEFT UPPER-RIGHT LOWER-LEFT LOWER-RIGHT
                  LEFT-MIDDLE RIGHT-MIDDLE TOP-CENTER BOTTOM-CENTER CENTER))

;;;
;;;   This macro is used by the tracer.  It encloses some forms.
;;;   Within the scope of this macro, TOP BOTTOM ... etc. (called the
;;;   "orientation vars") are bound to the way they are at zero lambda level,
;;;   i.e., the way the displayer/user should see them, i.e., transparent
;;;   to all stacked frame-cubes/with-front-and-tops.

(defmacro 0-level-cube-context forms
          `(let ((TOP TOP-0)(BACK BACK-0)(FRONT FRONT-0)
                            (BOTTOM BOTTOM-0)(LHS LHS-0)(RHS RHS-0)
                            (cube-face-lambda-level '0lcc))
                (reprocess-cube-rot-stack cube-pending-rot-stack nil)
                . ,forms))

;;;
;;;  This macro lambda-binds the orientation vars to their current value.
;;;  Thus, all reorientation of the cube done within its lexical scope
;;;  will not be reflected outside of it.  This permits "viewing" of the
;;;  cube in different coordinate frames by rotating it within one of these.

(defmacro frame-cube forms
          `(let ((TOP TOP)(RHS RHS)(LHS LHS)(FRONT FRONT)(BACK BACK)(BOTTOM BOTTOM)
                          (cube-face-lambda-level 'frame-cube))
                . ,forms))

;;;
;;;  This is the most important macro of the cube-solving system.
;;;  It contains ",forms", lexically, and executes these forms
;;;  in a context where the cube orieentation vars are so set up that
;;;  ,front is the front, and ,top is the top. ,pairs is a list of
;;;  (row col) coordinate pairs (possibly empty), which are to be
;;;  transformed (within the scope of the macro) to the explicit
;;;  coordinate system induced on ,front by considering ,top its top.
;;;  All rotations upon the cube performed by calling turn-cube-***
;;;  WILL be reflected outside the macro.  Those performed by calling
;;;  primitives directly will not.

(defmacro with-front-and-top ((front top . pairs) . forms)
          `(let ((old-cube-pending-rot-stack cube-pending-rot-stack)
                 (wfat-realtop ,top))
                (prog2 0
                       (frame-cube
                         ,@ (and (not (eq front 'FRONT)) `((make-face-front ,front)))
                         (make-face-top-hold-front wfat-realtop)
                         . ,(cond ((null pairs) forms)
                                  (t `((let ,(mapcar
                                               '(lambda (pair)
                                                        (let ((x (car pair))
                                                              (y (cadr pair)))
                                                             `((,x ,y)
                                                               (cube-xy-transform FRONT TOP ,x ,y))))
                                               pairs)
                                            . ,forms)))))
                       (reprocess-cube-rot-stack cube-pending-rot-stack old-cube-pending-rot-stack))))

;;;  These next two macros are syntactic sugars for with-front-and-top.
;;;  normal-view takes a ",front", and coordinate pairs, and "assumes"
;;;  the top as the canonical (display) top.
;;;  normal-front-top sugars that one further, assumes FRONT as front and
;;;  TOP as top.

(defmacro normal-view (face pairs . forms)
          (once-only (face)
                     `(with-front-and-top (,face
                                            (cube-display-top-choice ,face)
                                            . ,pairs)
                                          .,forms)))

(defmacro normal-front-top (lists . forms)
          `(with-front-and-top (FRONT TOP . ,lists) .,forms))

;;;
;;;   This macro says "keep doing the forms contained in me until
;;;   somebody evaluates a "(placed)".  20 times and the game is up.
;;;   (Would indicate a broken algorithm or program.)
;;;

(defmacro hack-until-placed forms
          `(catch
             (1to 20. hack-count
                  (and (= hack-count 20.)(error '|hack count too large| 19. 'fail-act))
                  . ,forms)
             CUBIE-PLACED))

(defmacro placed nil `(throw nil CUBIE-PLACED))

;;;
;;;  This macro expresses the notion of doing something after some
;;;  other thing has been done, and then undoing the latter thing.
;;;  ,transforms is a list of cube transforms, which will be
;;;  performed in inverse retrograde after the lexically contained forms.

(defmacro under-conjugated-transform
          (transforms . code)
          `(progn
             ,@ transforms
             ,@ code
             ,@ (mapcar 'invert-cube-transform (nreverse transforms))))


(defun invert-cube-transform (x)
       (case (length x)
             (1 (let ((inv (cdr (assq (car x)
                                      '((turn-lhs-up . turn-lhs-down)(turn-rhs-up . turn-rhs-down)
                                                                     (turn-center-belt-up . turn-center-belt-down)
                                                                     (turn-center-belt-down . turn-center-belt-up)
                                                                     (turn-rhs-down . turn-rhs-up)(turn-lhs-down . turn-lhs-up)
                                                                     (right-hand-cube-hammer . undo-right-hand-hammer)
                                                                     (left-hand-cube-hammer . undo-left-hand-hammer)
                                                                     )))))
                     (cond (inv (list inv))
                           (t (error '|unknown inverse of transform: | x 'fail-act)))))
             (3 (list
                  (car x)
                  (cadr x)
                  (cdr (assoc (caddr x)
                              '(('right . 'left)('left . 'right)(180. . 180.)('cw . 'ccw)('ccw . 'cw))))))))


;;;
;;;  Miscellaneous sugarings to save the cube-solving reader
;;;  from MacLisp.
;;;

(defmacro do-for-items (itemn iteml . stuff)
          `(do-list ,itemn (list . ,iteml) . ,stuff))

(defmacro do-list (var list . stuff)
          (let ((gensym (gensym)))
               `(do ,gensym ,list (cdr ,gensym)(null ,gensym)
                    (let ((,var (car ,gensym)))
                         . ,stuff))))

(defmacro push (stuff list)`(setq ,list (cons ,stuff ,list)))

(defmacro add-one-to (x)`(setq ,x (+ ,x 1)))
