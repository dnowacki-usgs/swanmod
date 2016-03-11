1) calculation of turning rate improved
    - based on derivatives of phase velocity instead of depth
    - central differences instead of upwind for computing derivatives (structured)
    - Green-Gauss formula instead of upwind for computing derivatives (unstructured)
    - inclusion neighboring sweeps removed
2) cdlim removed
3) in case of ambient current set IQUAD to 3 by default
4) two small bug fixes with netCDF

--- agioncmd.ftn90	2015-02-04 11:52:57.000000000 +0100
+++ agioncmd.ftn90	2015-11-27 11:35:10.996469711 +0100
@@ -160,7 +160,7 @@
             character(len=10)                        :: lunit = 'degrees'
             integer                                  :: pnt_dimid, &
                                                         lon_varid, lat_varid, &
-                                                        npoints = 0, ips_varid, &
+                                                        npoints = 0, ips_varid = 0, &
                                                         xdimlen = 0, ydimlen = 0
         end type pntgrid_type
 
--- Makefile	2015-02-04 11:52:57.000000000 +0100
+++ Makefile	2015-11-27 11:35:10.860469709 +0100
@@ -36,6 +36,7 @@
 SwanCompdata.$(EXTO) \
 SdsBabanin.$(EXTO) \
 $(NCF_OBJS) \
+swan2coh.$(EXTO) \
 swanmain.$(EXTO) \
 swanpre1.$(EXTO) \
 swanpre2.$(EXTO) \
@@ -74,6 +75,7 @@
 SwanTranspX.$(EXTO) \
 SwanDiffPar.$(EXTO) \
 SwanGSECorr.$(EXTO) \
+SwanGradDepthorK.$(EXTO) \
 SwanInterpolatePoint.$(EXTO) \
 SwanInterpolateAc.$(EXTO) \
 SwanInterpolateOutput.$(EXTO) \
@@ -94,6 +96,8 @@
 ocpcre.$(EXTO) \
 ocpmix.$(EXTO)
 
+SWAN_LIB = libswan.so
+
 HCAT_EXE = hcat.exe
 HCAT_OBJS = swanhcat.$(EXTO)
 
@@ -119,6 +123,7 @@
 	@echo "make omp       -- makes the OpenMP $(SWAN_EXE) executable"
 	@echo "make mpi       -- makes the    MPI $(SWAN_EXE) executable"
 	@echo "make punswan   -- makes the parallel un$(SWAN_EXE) executable"
+	@echo "make coh       -- makes the MPI SWAN library for coupling with COHERENS"
 	@echo "make doc       -- makes the SWAN documentation (PDF)"
 	@echo "make clean     -- removes compiled objects and modules"
 	@echo "make clobber   -- removes compiled objects, modules and $(SWAN_EXE)"
@@ -157,6 +162,12 @@
                 OBJS="$(MSG_OBJS) $(SWAN_OBJS)" $(SWAN_EXE)
 	$(MAKE) unhcat
 
+coh:
+	@perl switch.pl $(swch) -coh *.ftn *.ftn90
+	$(MAKE) FOR=$(F90_MPI) FFLAGS="$(FLAGS_OPT) $(FLAGS_MSC) $(FLAGS_MPI) $(FLAGS_DYN)" \
+	        FFLAGS90="$(FLAGS_OPT) $(FLAGS90_MSC) $(FLAGS_MPI) $(FLAGS_DYN)" \
+                INCS="$(INCS_MPI)" LIBS="$(LIBS_MPI)" OBJS="$(SWAN_OBJS)" $(SWAN_LIB)
+
 hcat:
 	@perl switch.pl $(swch) swanhcat.ftn
 	$(MAKE) FOR=$(F90_SER) FFLAGS="$(FLAGS_OPT) $(FLAGS_MSC) $(FLAGS_SER)" \
@@ -183,6 +194,9 @@
 $(SWAN_EXE): $(SWAN_OBJS)
 	$(FOR) $(OBJS) $(FFLAGS) $(OUT)$(SWAN_EXE) $(INCS) $(LIBS)
 
+$(SWAN_LIB): $(SWAN_OBJS)
+	$(FOR) -shared $(OUT)$(SWAN_LIB) $(OBJS) $(FFLAGS) $(INCS) $(LIBS)
+
 .f.o:
 	$(FOR) $< -c $(FFLAGS) $(INCS)
 
@@ -202,10 +216,10 @@
 	$(RM) *.$(EXTO) *.mod
 
 clobber:
-	$(RM) *.$(EXTO) *.mod *.f *.for *.f90 $(SWAN_EXE) $(HCAT_EXE) $(UNHCAT_EXE)
+	$(RM) *.$(EXTO) *.mod *.f *.for *.f90 $(SWAN_EXE) $(HCAT_EXE) $(UNHCAT_EXE) $(SWAN_LIB)
 
 allclean:
-	$(RM) *.$(EXTO) *.mod *.f *.for *.f90 $(SWAN_EXE) $(HCAT_EXE) $(UNHCAT_EXE)
+	$(RM) *.$(EXTO) *.mod *.f *.for *.f90 $(SWAN_EXE) $(HCAT_EXE) $(UNHCAT_EXE) $(SWAN_LIB)
 
 cleandoc:
 	$(MAKE) -f Makefile.latex TARGET=swanuse cleandoc
--- platform.pl	2014-04-18 10:06:53.000000000 +0200
+++ platform.pl	2015-11-27 11:35:10.856469708 +0100
@@ -16,6 +16,7 @@
   print OUTFILE "FLAGS_OPT = -Ofast=IP35 -mips4 -r12000\n";
   print OUTFILE "FLAGS_MSC = -64\n";
   print OUTFILE "FLAGS90_MSC = \$(FLAGS_MSC)\n";
+  print OUTFILE "FLAGS_DYN =\n";
   print OUTFILE "FLAGS_SER =\n";
   print OUTFILE "FLAGS_OMP = -mp\n";
   print OUTFILE "FLAGS_MPI =\n";
@@ -59,6 +60,7 @@
   print OUTFILE "            -qunroll -qalign=4k -qfloat=hsflt\n";
   print OUTFILE "FLAGS_MSC = -w -qfixed -qnosave -q64\n";
   print OUTFILE "FLAGS90_MSC = -w -qfree=f90 -qnosave -q64\n";
+  print OUTFILE "FLAGS_DYN =\n";
   print OUTFILE "FLAGS_SER =\n";
   print OUTFILE "FLAGS_OMP = -qsmp=omp\n";
   print OUTFILE "FLAGS_MPI =\n";
@@ -101,6 +103,7 @@
   print OUTFILE "FLAGS_OPT = -fast\n";
   print OUTFILE "FLAGS_MSC = -w -fixed\n";
   print OUTFILE "FLAGS90_MSC = -w -free\n";
+  print OUTFILE "FLAGS_DYN =\n";
   print OUTFILE "FLAGS_SER =\n";
   print OUTFILE "FLAGS_OMP = -Wp,-C -omp\n";
   print OUTFILE "FLAGS_MPI =\n";
@@ -128,6 +131,7 @@
   print OUTFILE "FLAGS_OPT = -xO3 -xtarget=native -fsimple=1 -depend -libmil -xlibmopt -xlic_lib=sunperf\n";
   print OUTFILE "FLAGS_MSC = -w -silent\n";
   print OUTFILE "FLAGS90_MSC = \$(FLAGS_MSC)\n";
+  print OUTFILE "FLAGS_DYN =\n";
   print OUTFILE "FLAGS_SER =\n";
   print OUTFILE "FLAGS_OMP = -openmp\n";
   print OUTFILE "FLAGS_MPI =\n";
@@ -170,6 +174,7 @@
   print OUTFILE "FLAGS_OPT = +O2 +Onolimit\n";
   print OUTFILE "FLAGS_MSC =\n";
   print OUTFILE "FLAGS90_MSC =\n";
+  print OUTFILE "FLAGS_DYN =\n";
   print OUTFILE "FLAGS_SER = +Onoopenmp\n";
   print OUTFILE "FLAGS_OMP = +Oopenmp\n";
   print OUTFILE "FLAGS_MPI =\n";
@@ -224,6 +229,7 @@
 #    print OUTFILE "FLAGS_MSC = -W0 -assume byterecl -traceback -diag-disable remark\n";
     print OUTFILE "FLAGS_MSC = -W0 -assume byterecl -traceback -diag-disable 8290 -diag-disable 8291 -diag-disable 8293\n";
     print OUTFILE "FLAGS90_MSC = \$(FLAGS_MSC)\n";
+    print OUTFILE "FLAGS_DYN = -fPIC\n";
     print OUTFILE "FLAGS_SER =\n";
     print OUTFILE "FLAGS_OMP = -openmp\n";
     print OUTFILE "FLAGS_MPI =\n";
@@ -268,6 +274,7 @@
     print OUTFILE "FLAGS_OPT = -O2 -tpp7\n";
     print OUTFILE "FLAGS_MSC = -W0 -auto\n";
     print OUTFILE "FLAGS90_MSC = \$(FLAGS_MSC)\n";
+    print OUTFILE "FLAGS_DYN =\n";
     print OUTFILE "FLAGS_SER =\n";
     print OUTFILE "FLAGS_OMP = -openmp\n";
     print OUTFILE "FLAGS_MPI =\n";
@@ -297,6 +304,7 @@
     print OUTFILE "FLAGS_OPT = -O2 -tpp1\n";
     print OUTFILE "FLAGS_MSC = -W0 -auto\n";
     print OUTFILE "FLAGS90_MSC = \$(FLAGS_MSC)\n";
+    print OUTFILE "FLAGS_DYN =\n";
     print OUTFILE "FLAGS_SER =\n";
     print OUTFILE "FLAGS_OMP = -openmp\n";
     print OUTFILE "FLAGS_MPI =\n";
@@ -325,6 +333,7 @@
     print OUTFILE "FLAGS_OPT = -fast\n";
     print OUTFILE "FLAGS_MSC = -Mfixed\n";
     print OUTFILE "FLAGS90_MSC = -Mfree\n";
+    print OUTFILE "FLAGS_DYN =\n";
     print OUTFILE "FLAGS_SER =\n";
     print OUTFILE "FLAGS_OMP = -mp\n";
     print OUTFILE "FLAGS_MPI = -tp barcelona-64\n";
@@ -368,6 +377,7 @@
     print OUTFILE "FLAGS_OPT = -O --tpp\n";
     print OUTFILE "FLAGS_MSC = --staticlink --nwo\n";
     print OUTFILE "FLAGS90_MSC = \$(FLAGS_MSC)\n";
+    print OUTFILE "FLAGS_DYN =\n";
     print OUTFILE "FLAGS_SER =\n";
     print OUTFILE "FLAGS_OMP =\n";
     print OUTFILE "FLAGS_MPI =\n";
@@ -396,6 +406,7 @@
     print OUTFILE "FLAGS_OPT = -O\n";
     print OUTFILE "FLAGS_MSC = -w -fno-second-underscore\n";
     print OUTFILE "FLAGS90_MSC = \$(FLAGS_MSC) -ffree-line-length-none\n";
+    print OUTFILE "FLAGS_DYN =\n";
     print OUTFILE "FLAGS_SER =\n";
     print OUTFILE "FLAGS_OMP = -fopenmp\n";
     print OUTFILE "FLAGS_MPI =\n";
@@ -439,6 +450,7 @@
     print OUTFILE "FLAGS_OPT = -O\n";
     print OUTFILE "FLAGS_MSC = -fno-second-underscore\n";
     print OUTFILE "FLAGS90_MSC = \$(FLAGS_MSC) -ffree-line-length-huge\n";
+    print OUTFILE "FLAGS_DYN =\n";
     print OUTFILE "FLAGS_SER =\n";
     print OUTFILE "FLAGS_OMP =\n";
     print OUTFILE "FLAGS_MPI =\n";
@@ -482,6 +494,7 @@
     print OUTFILE "FLAGS_OPT = -O3 -qstrict -qarch=auto -qtune=auto\n";
     print OUTFILE "FLAGS_MSC = -qfixed -qzerosize -qwarn64\n";
     print OUTFILE "FLAGS90_MSC = -qfree=f90 -qzerosize -qwarn64\n";
+    print OUTFILE "FLAGS_DYN =\n";
     print OUTFILE "FLAGS_SER =\n";
     print OUTFILE "FLAGS_OMP =\n";
     print OUTFILE "FLAGS_MPI =\n";
@@ -533,6 +546,7 @@
 #    print OUTFILE "FLAGS_MSC = /assume:byterecl /traceback /nowarn /nologo /Qdiag-disable:remark\n";
     print OUTFILE "FLAGS_MSC = /assume:byterecl /traceback /nowarn /nologo /Qdiag-disable:8290 /Qdiag-disable:8291 /Qdiag-disable:8293\n";
     print OUTFILE "FLAGS90_MSC = \$(FLAGS_MSC)\n";
+    print OUTFILE "FLAGS_DYN =\n";
     print OUTFILE "FLAGS_SER =\n";
     print OUTFILE "FLAGS_OMP = /Qopenmp /Qopenmp-link:static\n";
     print OUTFILE "FLAGS_MPI =\n";
@@ -577,6 +591,7 @@
     print OUTFILE "FLAGS_OPT = /optimize:2\n";
     print OUTFILE "FLAGS_MSC = /assume:byterecl /traceback /names:lowercase /nowarn /nologo\n";
     print OUTFILE "FLAGS90_MSC = \$(FLAGS_MSC)\n";
+    print OUTFILE "FLAGS_DYN =\n";
     print OUTFILE "FLAGS_SER =\n";
     print OUTFILE "FLAGS_OMP = /Qopenmp /Qopenmp-link:static\n";
     print OUTFILE "FLAGS_MPI =\n";
@@ -624,6 +639,7 @@
   print OUTFILE "FLAGS_OPT = -O3 -qstrict -qtune=auto -qcache=auto -qalign=4k\n";
   print OUTFILE "FLAGS_MSC = -w -qfixed\n";
   print OUTFILE "FLAGS90_MSC = -w -qfree=f90\n";
+  print OUTFILE "FLAGS_DYN =\n";
   print OUTFILE "FLAGS_SER =\n";
   print OUTFILE "FLAGS_OMP =\n";
   print OUTFILE "FLAGS_MPI =\n";
--- swan2coh.ftn90	1970-01-01 01:00:00.000000000 +0100
+++ swan2coh.ftn90	2015-11-27 11:35:12.252469748 +0100
@@ -0,0 +1,2 @@
+!   This file contains a subroutine to compute different wave parameters
+!   to be sent to COHERENS
--- swancom1.ftn	2015-02-04 11:52:57.000000000 +0100
+++ swancom1.ftn	2015-11-27 11:35:18.336469929 +0100
@@ -123,6 +123,7 @@
 !     40.41: Andre van der Westhuysen
 !     40.41: Marcel Zijlema
 !     40.41: Andre van der Westhuysen
+!     40.59: W. Erick Rogers
 !
 !  1. Updates
 !
@@ -182,6 +183,7 @@
 !     40.41, Jun. 04: Implementation of curvature-based convergence check
 !     40.41, Aug. 04: some code optimization
 !     40.41, Oct. 04: common blocks replaced by modules, include files removed
+!     40.59, Aug. 07: stencil modification
 !
 !  2. Purpose
 !
@@ -921,10 +923,10 @@
         ICMAX  = 10                                                       33.08
         LSTCP  = 3                                                        40.31
       ELSE IF (PROPSC.EQ.2) THEN                                          33.10
-        ICMAX  = 5                                                        33.10
+        ICMAX  = 7                                                        40.59 33.10
         LSTCP  = 2                                                        40.31
       ELSE
-        ICMAX  = 3                                                        33.10
+        ICMAX  = 5                                                        40.59 33.10
         LSTCP  = 1                                                        40.31
       ENDIF                                                               33.08
 
@@ -2148,6 +2150,7 @@
 !     40.28: Annette Kieftenburg
 !     40.30: Marcel Zijlema
 !     40.41: Marcel Zijlema
+!     40.59: W. Erick Rogers
 !     40.61: Roop Lalbeharry
 !
 !  1. Updates
@@ -2198,6 +2201,8 @@
 !                     with other subroutines
 !     40.41, Aug. 04: code optimization
 !     40.41, Oct. 04: common blocks replaced by modules, include files removed
+!     40.59, Aug. 07: stencil numbering made consistent, so that if used for
+!                     varied purposes (e.g. SPROSD), if-then not required
 !     40.61, Nov. 06: Hersbach and Janssen (1999) limiter option added
 !
 !  2. Purpose
@@ -2208,56 +2213,99 @@
 !  3. Method
 !
 !
-!    THIS IS THE STENCIL USED WITH THE S&L SCHEME:                  33.08
-!                                                                   33.08
-!      IY+1                      o 4                                33.08
-!                                |                                  33.08
-!                 8    6    2    | 1   5                            33.08
-!      IY         O----O----O----*----O                             33.08
-!                                |                                  33.08
-!                           10   |                                  33.08
-!      IY-1                 O----O 3                                33.08
-!                                |                                  33.08
-!                                |                                  33.08
-!      IY-2                      O 7                                33.08
-!                                |                                  33.08
-!                                |                                  33.08
-!      IY-3                      O 9                                33.08
+!    THIS IS THE STENCIL USED WITH THE S&L SCHEME:                        33.08
+!                                                                         33.08
+!      IY+1                      o 4                                      33.08
+!                                |                                        33.08
+!                 8    6    2    | 1   5                                  33.08
+!      IY         O----O----O----*----O                                   33.08
+!                                |                                        33.08
+!                           10   |                                        33.08
+!      IY-1                 O----O 3                                      33.08
+!                                |                                        33.08
+!                                |                                        33.08
+!      IY-2                      O 7                                      33.08
+!                                |                                        33.08
+!                                |                                        33.08
+!      IY-3                      O 9                                      33.08
 !
 !                 ^    ^    ^    ^    ^
-!                 |    |    |    |    |                             33.08
+!                 |    |    |    |    |                                   33.08
 !               IX-3 IX-2 IX-1  IX  IX+1
 !
-!     1: IX  , IY                                                   33.10
-!     2: IX-1, IY                                                   33.10
-!     3: IX  , IY-1                                                 33.10
-!     4: IX  , IY+1                                                 33.10
-!     5: IX+1, IY                                                   33.10
-!     6: IX-2, IY                                                   33.10
-!     7: IX  , IY-2                                                 33.10
-!     8: IX-3, IY                                                   33.10
-!     9: IX  , IY-3                                                 33.10
-!    10: IX-1, IY-1                                                 33.10
-!
-!    THIS IS THE STENCIL USED WITH THE SORDUP SCHEME:               33.10
-!                                                                   33.10
-!                      4    2                                       33.10
-!      IY              O----O----* 1                                33.10
-!                                |                                  33.10
-!                                |                                  33.10
-!      IY-1                      O 3                                33.10
-!                                |                                  33.10
-!                                |                                  33.10
-!      IY-2                      O 5                                33.10
-!                                                                   33.10
-!                      ^    ^    ^                                  33.10
-!                      |    |    |                                  33.10
-!                    IX-2 IX-1  IX                                  33.10
-!     1: IX  , IY                                                   33.10
-!     2: IX-1, IY                                                   33.10
-!     3: IX  , IY-1                                                 33.10
-!     4: IX-2, IY                                                   33.10
-!     5: IX  , IY-2                                                 33.10
+!     1: IX  , IY                                                         33.10
+!     2: IX-1, IY                                                         33.10
+!     3: IX  , IY-1                                                       33.10
+!     4: IX  , IY+1                                                       33.10
+!     5: IX+1, IY                                                         33.10
+!     6: IX-2, IY                                                         33.10
+!     7: IX  , IY-2                                                       33.10
+!     8: IX-3, IY                                                         33.10
+!     9: IX  , IY-3                                                       33.10
+!    10: IX-1, IY-1                                                       33.10
+!
+!    THIS IS THE STENCIL USED WITH THE *OLD* SORDUP SCHEME:               40.59
+!                                                                         33.10
+!                      4    2                                             33.10
+!      IY              O----O----* 1                                      33.10
+!                                |                                        33.10
+!                                |                                        33.10
+!      IY-1                      O 3                                      33.10
+!                                |                                        33.10
+!                                |                                        33.10
+!      IY-2                      O 5                                      33.10
+!                                                                         33.10
+!                      ^    ^    ^                                        33.10
+!                      |    |    |                                        33.10
+!                    IX-2 IX-1  IX                                        33.10
+!     1: IX  , IY                                                         33.10
+!     2: IX-1, IY                                                         33.10
+!     3: IX  , IY-1                                                       33.10
+!     4: IX-2, IY                                                         33.10
+!     5: IX  , IY-2                                                       33.10
+!
+!    THIS IS THE STENCIL USED WITH THE *NEW* SORDUP SCHEME:               40.59
+!    (NUMBERING HAS CHANGED)                                              40.59
+!                                                                         40.59
+!                                O 4(7)                                   40.59
+!                                |                                        40.59
+!                                |                                        40.59
+!                  6(4)   2(2)   | 1(1) 5(6)                              40.59
+!      IY          O------O------*------O                                 40.59
+!                                |                                        40.59
+!                                |                                        40.59
+!                                |                                        40.59
+!      IY-1                      O 3(3)                                   40.59
+!                                |                                        40.59
+!                                |                                        40.59
+!                                |                                        40.59
+!      IY-2                      O 7(5)                                   40.59
+!                                                                         40.59
+!                      ^    ^    ^                                        40.59
+!                      |    |    |                                        40.59
+!                    IX-2 IX-1  IX                                        40.59
+!     1: IX  , IY                                                         40.59
+!     2: IX-1, IY                                                         40.59
+!     3: IX  , IY-1                                                       40.59
+!     4: IX  , IY+1        7==>4                                          40.59
+!     5: IX+1, IY          6==>5                                          40.59
+!     6: IX-2, IY          4==>6                                          40.59
+!     7: IX  , IY-2        5==>7                                          40.59
+!                                                                         40.59
+!  AND THE BSBT SCHEME:                                                   40.59
+!                                                                         40.59
+!                          O 4                                            40.59
+!                          |                                              40.59
+!                   2      | 1     5                                      40.59
+!                   O------*------O                                       40.59
+!                          |                                              40.59
+!                          |                                              40.59
+!                        3 O                                              40.59
+!     1: IX  , IY                                                         40.59
+!     2: IX-1, IY                                                         40.59
+!     3: IX  , IY-1                                                       40.59
+!     4: IX  , IY+1                                                       40.59
+!     5: IX+1, IY                                                         40.59
 !
 !  4. Argument variables
 !
@@ -2515,37 +2563,45 @@
         IYCGRD(2) = IY                                                    40.00
         IXCGRD(3) = IX                                                    40.00
         IYCGRD(3) = IY+KSY                                                40.00
+        IXCGRD(4) = IX                                                    40.59
+        IYCGRD(4) = IY-KSY                                                40.59
+        IXCGRD(5) = IX-KSX                                                40.59
+        IYCGRD(5) = IY                                                    40.59
         PROPSL = PROPSC                                                   33.09
         IF (PROPSC.EQ.1) THEN                                             33.09
-          ICMAX = 3
-        ELSE IF (PROPSC.EQ.2) THEN          ! SORDUP scheme               33.10
-!         add more points for higher order scheme                         33.10
-          ICMAX = 5                                                       33.10
-          IXCGRD(4) = IX+2*KSX                                            33.10
-          IYCGRD(4) = IY                                                  33.10
-          IXCGRD(5) = IX                                                  33.10
-          IYCGRD(5) = IY+2*KSY                                            33.10
-        ELSE IF (PROPSC.EQ.3) THEN          ! S&L scheme                  33.09
-!         add more points for higher order schemes here
+          ICMAX = 5                                                       40.59
+        ELSE
+!         add more points for higher order schemes                        33.10
+          ICMAX = 7                                                       40.59 33.10
+          IXCGRD(6) = IX+2*KSX                                            40.59 33.10
+          IYCGRD(6) = IY                                                  40.59 33.10
+          IXCGRD(7) = IX                                                  40.59 33.10
+          IYCGRD(7) = IY+2*KSY                                            40.59 33.10
+        ENDIF
+        IF (PROPSC.EQ.3) THEN
+!         add more points for S&L scheme
           ICMAX = 10                                                      33.09
-          IXCGRD(4) = IX                                                  33.09
-          IYCGRD(4) = IY-KSY                                              33.09
-          IXCGRD(5) = IX-KSX                                              33.09
-          IYCGRD(5) = IY                                                  33.09
-          IXCGRD(6) = IX+2*KSX                                            33.09
-          IYCGRD(6) = IY                                                  33.09
-          IXCGRD(7) = IX                                                  33.09
-          IYCGRD(7) = IY+2*KSY                                            33.09
-          IXCGRD(8) = IX+3*KSX                                            33.09
-          IYCGRD(8) = IY                                                  33.09
-          IXCGRD(9) = IX                                                  33.09
-          IYCGRD(9) = IY+3*KSY                                            33.09
+          IXCGRD(8)  = IX+3*KSX                                           33.09
+          IYCGRD(8)  = IY                                                 33.09
+          IXCGRD(9)  = IX                                                 33.09
+          IYCGRD(9)  = IY+3*KSY                                           33.09
           IXCGRD(10) = IX+KSX                                             33.09
           IYCGRD(10) = IY+KSY                                             33.09
         ENDIF
         DO IC = 2, ICMAX                                                  40.00
 !         if one of the points of a stencil is outside the computational  33.09
 !         domain, fall back to first order scheme                         33.09
+
+! Note that stencil of first order scheme has been increased to 5           40.59
+! Also note that points 4 and 5 are used only for SPROSD.                   40.59
+! In cases where user has chosen the first order scheme (PROPSC=1) , and    40.59
+! points 4 and/or 5 fall outside the grid, we do not want to set PROPSL=0.  40.59
+! However, we do want to set INSIDE=FALSE, so that KCGRD(IC) = 1, so that   40.59
+! SPROSD will know that the point is not available. As the code is written  40.59
+! now, no change is required. But also be aware that refraction will no     40.59
+! longer be calculated at the last grid point (i.e. SPROSD is not coded to  40.59
+! fall back to the first order scheme, it just set C_theta=0).              40.59
+
           INSIDE = .TRUE.                                                 33.09
           IF (IXCGRD(IC).LT.1) THEN                                       33.09
             IF (KREPTX.GT.0) THEN                                         33.09
@@ -2599,7 +2655,7 @@
         IF (PROPSL.EQ.0) THEN                                             33.09
           ICMAX = 1                                                       33.09
         ELSEIF (PROPSL.EQ.1) THEN                                         33.09
-          ICMAX = 3                                                       33.09
+          ICMAX = 5                                                       40.59 33.09
         ENDIF                                                             33.09
       ELSE
         PROPSL = 0                                                        40.13
@@ -2668,18 +2724,18 @@
             ELSE IF (SWPDIR .EQ. 2) THEN                                  33.10
                LINK(1)  = CROSS(1,KCGRD(2))                               33.10
                LINK(2)  = CROSS(2,KCGRD(1))                               33.10
-               LINK(3)  = CROSS(1,KCGRD(4))                               33.10
+               LINK(3)  = CROSS(1,KCGRD(6))                               40.59 33.10
                LINK(4)  = CROSS(2,KCGRD(3))                               33.10
             ELSE IF (SWPDIR .EQ. 3) THEN                                  33.10
                LINK(1)  = CROSS(1,KCGRD(2))                               33.10
                LINK(2)  = CROSS(2,KCGRD(3))                               33.10
-               LINK(3)  = CROSS(1,KCGRD(4))                               33.10
-               LINK(4)  = CROSS(2,KCGRD(5))                               33.10
+               LINK(3)  = CROSS(1,KCGRD(6))                               40.59 33.10
+               LINK(4)  = CROSS(2,KCGRD(7))                               40.59 33.10
             ELSE IF (SWPDIR .EQ. 4) THEN                                  33.10
                LINK(1)  = CROSS(1,KCGRD(1))                               33.10
                LINK(2)  = CROSS(2,KCGRD(3))                               33.10
                LINK(3)  = CROSS(1,KCGRD(2))                               33.10
-               LINK(4)  = CROSS(2,KCGRD(5))                               33.10
+               LINK(4)  = CROSS(2,KCGRD(7))                               40.59 33.10
             ENDIF                                                         33.10
          ENDIF                                                            33.10
          IF (PROPSL.GT.1) THEN                                            33.10
@@ -2834,36 +2890,18 @@
 !TIMG      CALL SWTSTO(112)                                                    40.23
 
 !     *** compute the propagation velocities CAS and CAD   ***
-!     *** for the central gridpoint only and only for the  ***
-!     *** directional domain : IDCMIN-1 until IDCMAX+1     ***
 
 !TIMG      CALL SWTSTA(113)                                                    40.23
-      IF ( IMUD.NE.1 .AND. INT(PNUMS(32)).NE.1 ) THEN
         CALL SPROSD (SPCSIG         ,KWAVE          ,CAS            ,     40.03
      &               CAD            ,CGO            ,                     30.80
      &               COMPDA(1,JDP2) ,COMPDA(1,JDP1) ,SPCDIR(1,2)    ,
      &               SPCDIR(1,3)    ,COMPDA(1,JVX2) ,COMPDA(1,JVY2) ,
-     &               SWPDIR         ,IDCMIN         ,IDCMAX         ,
-     &               SPCDIR(1,4)    ,SPCDIR(1,6)    ,SPCDIR(1,5)    ,     30.80
-     &               RDX            ,RDY            ,                     30.80
-     &               CAX            ,CAY            ,LSWMAT(1,1,JABIN),   40.02
-     &               KGRPNT         ,XCGRID         ,YCGRID         ,     40.03
-     &               IDDLOW         ,IDDTOP                               40.61
-     &                                                            )
-      ELSE
-!       this routine used @C/@x rather than @h/@x and will be called
-!       if either command MUD or command NUM ... DIR WNUM is applied
-        CALL SPROSDM(SPCSIG         ,KWAVE          ,CAS            ,     40.03
-     &               CAD            ,CGO            ,                     30.80
-     &               COMPDA(1,JDP2) ,COMPDA(1,JDP1) ,SPCDIR(1,2)    ,
-     &               SPCDIR(1,3)    ,COMPDA(1,JVX2) ,COMPDA(1,JVY2) ,
      &               SPCDIR(1,4)    ,SPCDIR(1,6)    ,SPCDIR(1,5)    ,     30.80
      &               RDX            ,RDY            ,                     30.80
      &               CAX            ,CAY            ,                     40.02
      &               XCGRID         ,YCGRID         ,                     40.03
      &               IDDLOW         ,IDDTOP                               40.61
      &                                                            )
-      ENDIF
 !TIMG      CALL SWTSTO(113)                                                    40.23
 
 !TIMG      CALL SWTSTA(114)                                                    40.23
@@ -3387,10 +3425,10 @@
         ICMX = 10                                                         40.41
       ELSEIF (PROPSC.EQ.2) THEN                                           40.41
         WRITE(PRINTF,8511) 'SORDUP'                                       40.41
-        ICMX = 5                                                          40.41
+        ICMX = 7                                                          40.59 40.41
       ELSE                                                                40.41
         WRITE(PRINTF,8511) 'BSBT  '                                       40.41
-        ICMX = 3                                                          40.41
+        ICMX = 5                                                          40.59 40.41
       ENDIF                                                               40.41
  8511 FORMAT(' Scheme for geographic propagation is ',A6)                 40.41
       IF (OPTG.NE.5) WRITE(PRINTF,8512) PROPSC, ICMX                      40.80 40.41
--- swancom5.ftn	2015-02-04 11:52:57.000000000 +0100
+++ swancom5.ftn	2015-11-27 11:35:18.348469930 +0100
@@ -1133,837 +1133,6 @@
      &                   CAD        ,CGO        ,                         30.80
      &                   DEP2       ,DEP1       ,ECOS       ,
      &                   ESIN       ,UX2        ,UY2        ,
-     &                   SWPDIR     ,IDCMIN     ,IDCMAX     ,
-     &                   COSCOS     ,SINSIN     ,SINCOS     ,             30.80
-     &                   RDX        ,RDY        ,                         30.80
-     &                   CAX        ,CAY        ,ANYBIN     ,             30.80
-     &                   KGRPNT     ,XCGRID     ,YCGRID     ,             30.80
-     &                   IDDLOW     ,IDDTOP                               40.61
-     &                                                      )
-!
-!****************************************************************
-!
-      USE SWCOMM2                                                         40.41
-      USE SWCOMM3                                                         40.41
-      USE SWCOMM4                                                         40.41
-      USE TIMECOMM                                                        40.41
-      USE OCPCOMM4                                                        40.41
-      USE M_PARALL                                                        40.31
-      USE M_DIFFR                                                         40.21
-!
-      IMPLICIT NONE
-!
-!
-!
-!   --|-----------------------------------------------------------|--
-!     | Delft University of Technology                            |
-!     | Faculty of Civil Engineering                              |
-!     | Environmental Fluid Mechanics Section                     |
-!     | P.O. Box 5048, 2600 GA  Delft, The Netherlands            |
-!     |                                                           |
-!     | Programmers: The SWAN team                                |
-!   --|-----------------------------------------------------------|--
-!
-!
-!     SWAN (Simulating WAves Nearshore); a third generation wave model
-!     Copyright (C) 1993-2015  Delft University of Technology
-!
-!     This program is free software; you can redistribute it and/or
-!     modify it under the terms of the GNU General Public License as
-!     published by the Free Software Foundation; either version 2 of
-!     the License, or (at your option) any later version.
-!
-!     This program is distributed in the hope that it will be useful,
-!     but WITHOUT ANY WARRANTY; without even the implied warranty of
-!     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
-!     GNU General Public License for more details.
-!
-!     A copy of the GNU General Public License is available at
-!     http://www.gnu.org/copyleft/gpl.html#SEC3
-!     or by writing to the Free Software Foundation, Inc.,
-!     59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
-!
-!
-!  0. Authors
-!
-!     30.72: IJsbrand Haagsma
-!     30.80: Nico Booij
-!     40.03: Nico Booij
-!     40.02: IJsbrand Haagsma
-!     40.14: Annette Kieftenburg
-!     40.21: Agnieszka Herman
-!     40.30: Marcel Zijlema
-!     40.41: Marcel Zijlema
-!     40.61: John Warner
-!     41.06: Gerbrant van Vledder
-!     41.35: Casey Dietrich
-!
-!  1. Updates
-!
-!     30.72, Feb. 98: Introduced generic names XCGRID, YCGRID and SPCSIG for SWAN
-!     30.80, Nov. 98: Provision for limitation on Ctheta (refraction)
-!     30.80, Aug. 99: SWCOMM3.INC included
-!     30.80, Sep. 99: SWCOMM2.INC included, limitation modified
-!     40.03, Dec. 99: for directions outside the current sweep the depth and
-!                     current gradients are computed using the gradient at the
-!                     proper side of the grid point.
-!                     argument KGRPNT added.
-!                     argument IC removed (is always 1)
-!                     argument DT removed, TIMECOMM.INC included
-!                     code completely revised
-!     40.02, Jan. 00: Introduction limiter dependent on Cx, Cy, Dx and Dy
-!     40.02, Sep. 00: Corrected order of handling sweeps
-!     40.02, Sep. 00: Limiter on refraction only activated when IREFR=-1
-!     40.14, Nov. 00: Land points excluded (bug fix)
-!     40.21, Aug. 01: adaption of velocities in case of diffraction
-!     40.30, Mar. 03: correcting indices of test point with offsets MXF, MYF
-!     40.41, Oct. 04: common blocks replaced by modules, include files removed
-!     40.61, Dec. 06: correction DO loop 60 (IDCMIN, IDCMAX -> IDDLOW,IDDTOP)
-!     41.06, Mar. 09: add option of limitation of velocity in theta-direction
-!     41.35, Mar. 12: add option of limitation on csigma and ctheta
-!
-!  2. Purpose
-!
-!     computes the propagation velocities of energy in S- and
-!     D-space, i.e., CAS, CAD, in the presence or absence of
-!     currents, for the action balance equation.
-!
-!  3. Method
-!
-!     The next equation are solved numerically
-!
-!           @S   @S   @D   _     @D   @D          _   @U
-!     CAS = -- = -- [ -- + U . ( -- + --) ] - CGO K . --
-!           @T   @D   @T         @X   @Y              @s
-!
-!           with:   @S       KS
-!                   -- =  ---------
-!                   @D    sinh(2KD)
-!
-!           @D      S      @D         @D           @Ux   @Uy
-!     CAD = -- = ------- [ --sin(D) - --cos(D)] + [--- - ---] *
-!           @T  sinh(2KD)  @X         @Y            @X   @Y
-!
-!                        @Uy               @Ux
-!     * sin(D)cos(D) +   ---sin(D)sin(D) - ---cos(D)cos(D)
-!                        @X                @Y
-!
-!     @D/@x appr by:   RDX(1) * (DEP(KCGRD(1)) - DEP(KCGRD(2)))
-!                    + RDX(2) * (DEP(KCGRD(1)) - DEP(KCGRD(3)))
-!     @D/@y appr by:   RDY(1) * (DEP(KCGRD(1)) - DEP(KCGRD(2)))
-!                    + RDY(2) * (DEP(KCGRD(1)) - DEP(KCGRD(3)))
-!     etc.
-!
-!     the limitation procedure is described in the system documentation.
-!
-!  4. Argument variables
-!
-!     IDCMAX: upper theta-boundary of current sweep
-!     IDCMIN: lower theta-boundary of current sweep (function of Sigma)
-!     IDDLOW: minimum direction that is propagated within a sweep         40.61
-!     IDDTOP: maximum direction that is propagated within a sweep         40.61
-!     KGRPNT: grid point addresses                                        40.03
-!     SWPDIR: current sweep direction
-!
-      INTEGER, INTENT(IN) :: IDCMIN(MSC), IDCMAX(MSC)
-      INTEGER, INTENT(IN) :: KGRPNT(MXC,MYC)                              40.03
-      INTEGER, INTENT(IN) :: SWPDIR, IDDLOW, IDDTOP                       40.61
-!
-!     CAS   : Wave transport velocity in S-direction, function of (ID,IS,IC)
-!     CAD   : Wave transport velocity in D-dirctiion, function of (ID,IS,IC)
-!     CAX   : Wave transport velocity in X-direction, function of (ID,IS,IC)
-!     CAY   : Wave transport velocity in Y-direction, function of (ID,IS,IC)
-!     CGO   : Group velocity as function of X and Y and sigma in the
-!             direction of wave propagation in absence of currents
-!     DEP1  : Depth as function of X and Y at time T
-!     DEP2  : (Nonstationary case) depth as function of X and Y at time T+1
-!     ECOS  : Represent the values of cos(d) of each spectral direction
-!     ESIN  : Represent the values of sin(d) of each spectral direction
-!     KWAVE : wavenumber as function of the relative frequency sigma
-!     SPCSIG: Relative frequencies in computational domain in sigma-space
-!     UX2   : X-component of current velocity of X and Y at time T+1
-!     UY2   : Y-component of current velocity of X and Y at time T+1
-!     XCGRID: x-coordinate of comput. grid points
-!     YCGRID: y-coordinate of comput. grid points
-!
-      REAL  :: SPCSIG(MSC)                                                30.72
-      REAL  :: XCGRID(MXC,MYC), YCGRID(MXC,MYC)                           30.80
-!     Changed ICMAX to MICMAX, since MICMAX doesn't vary over gridpoint   40.22
-      REAL  :: CAS(MDC,MSC,MICMAX)                                        40.22
-      REAL  :: CAD(MDC,MSC,MICMAX)                                        40.22
-      REAL  :: CAX(MDC,MSC,MICMAX)                                        30.80 40.22
-      REAL  :: CAY(MDC,MSC,MICMAX)                                        30.80 40.22
-      REAL  :: CGO(MSC,MICMAX)                                            40.22
-      REAL  :: DEP2(MCGRD)                 ,
-     &         DEP1(MCGRD)                 ,
-     &         ECOS(MDC)                   ,
-     &         ESIN(MDC)                   ,
-     &         COSCOS(MDC)                 ,
-     &         SINSIN(MDC)                 ,
-     &         SINCOS(MDC)
-!     Changed ICMAX to MICMAX, since MICMAX doesn't vary over gridpoint   40.22
-      REAL  :: KWAVE(MSC,MICMAX)                                          40.22
-      REAL  :: UX2(MCGRD)                  ,
-     &         UY2(MCGRD)                  ,
-     &         RDX(MICMAX)                 ,                              40.08
-     &         RDY(MICMAX)                                                40.08
-!
-!        logical:
-!
-!        ANYBIN    i  if True component (ID,IS) is updated                30.80
-!
-      LOGICAL ANYBIN(MDC,MSC)                                             30.80
-!
-!
-!     variables from common
-!
-!        ICUR    Indicator for current
-!        ICMAX   Maximum array size for the points of the molecule
-!        NSTATC  Indicator if computation is stationary or not
-!        MXC     Maximum counter of gridppoints in x-direction
-!        MYC     Maximum counter of gridppoints in y-direction
-!        MSC     Maximum counter of relative frequency
-!        MDC     Maximum counter of spectral directions
-!
-!        DYNDEP  if True depths vary with time
-!
-!        DT      Time step
-!        RDTIM   1/DT                                                     30.80
-!        PNUMS   array of numerical coefficients; used here:              30.80
-!                PNUMS(17), coeff. for limitation of Ctheta               30.80
-!
-!     local variables
-!
-!        IX1,IX2,IX3   Counter of gridpoints in x-direction
-!        IY1,IY2,IY3   Counter of gridpoints in y-direction
-!        IS            Counter of relative frequency band
-!        ID, ID1, ID2  Counter of directions
-!        IDDUM         aux. counter of directions
-!        II            counter
-!        ISWEEP        sweep index: 2=current sweep, 1 and 3=neighbouring sweeps
-!        ISWP          counter for sweeps                                 40.02
-!        KCG1          grid address of the active grid point
-!        KCG2, KCG3    grid addresses of two neighbouring grid points
-!        SWPNGB        neighbouring sweep direction
-!
-      INTEGER  IENT  ,IS    ,ID    ,II    ,                               30.80
-     &         SWPNGB,IDDUM ,ID1   ,ID2   ,                               30.80
-     &         KCG1  ,KCG2  ,KCG3  ,ISWEEP                                30.80
-      INTEGER  IX1, IY1, IX2, IY2, IX3, IY3                               40.03
-      INTEGER :: ISWP                                                     40.02
-!
-!     logical local variables
-!
-!        VALSWP        if true this sweep is valid (all corner points exist)
-!
-      LOGICAL    VALSWP                                                   40.03
-!
-!     real local variables
-!
-!        ALPHA         upper limit of CFL restriction
-!        KD1           wavenumber * depth
-!        COEF          aux. quantity
-!        VLSINH        sinh of KD1
-!        RDXL, RDYL    interpolation factors (see RDX and RDY in common)
-!        CAST..        aux. quantities to compute Csigma
-!        CADT..        aux. quantities to compute Ctheta
-!        DPDX, DPDY    depth gradient
-!        DUXDX,DUXDY,DUYDX,DUYDY  current velocity gradients
-!        FAC           a factor
-!        FAC2          another factor
-!        FRLIM         frequency range in which limit on Ctheta is applied
-!        PP            power of the frequency dependent limiter on refraction
-!
-      REAL     VLSINH ,KD1   ,COEF
-      REAL     RDXL(2),RDYL(2),XC1   ,YC1    ,DET    ,
-     &         DX2    ,DY2    ,DX3   ,DY3
-      REAL     DPDX   ,DPDY   ,DUXDX ,DUXDY ,DUYDX ,DUYDY
-      REAL     CAST1    ,CAST2    ,CAST3(3) ,CAST4(3) ,                   40.03
-     &         CAST5    ,CAST6(3) ,CAST7(3) ,CAST8(3) ,CAST9(3) ,
-     &         CADT1    ,CADT2(3) ,CADT3(3) ,
-     &         CADT4(3) ,CADT5(3) ,CADT6(3) ,CADT7(3)
-      REAL  :: DLOC1, DLOC2, DLOC3
-      REAL  :: FAC, FRLIM, PP                                             41.06
-      REAL  :: ALPHA, FAC2                                                41.35
-!     local depths corrected in view of stability                         40.02
-!
-!  5. Parameter variables
-!
-!     SWP_ARRAY: Array containing the order of sweep handling
-!
-      INTEGER, PARAMETER :: SWP_ARRAY(1:3) = (/2,1,3/)
-!
-!  8. Remarks
-!
-!       propagation velocity in sigma-direction:
-!
-!                              K(IS,IC)S            DEP2(IX,IY)-DEP1(IX,IY)
-!       CAS(ID,IS,IC) = ------------------------- [ ----------------------- +
-!                       sinh 2K(IS,IC)DEP2(IX,IY)            DT
-!
-!                           (DEP2(IX,IY) - DEP2(IX+KSX,IY)
-!              + UX2(IX,IY) ------------------------------ +
-!                                        DDX
-!
-!                           (DEP2(IX,IY) - DEP2(IX,IY+KSY)
-!              + UY2(IX,IY) ------------------------------ ] - CGO(IS,IC) *
-!                                        DDY
-!
-!                          UX2(IX,IY)-UX2(IX+KSX,IY)
-!         *  [   K(IS,IC) --------------------------- cos**2(D) +
-!                                    DDX
-!
-!                          UX2(IX,IY)-UX2(IX,IY+KSY)
-!              + K(IS,IC) -------------------------- cos(D)sin(D) +
-!                                    DDY
-!
-!                          UY2(IX,IY)-UY2(IX+KSX,IY)
-!              + K(IS,IC) -------------------------- sin(D)cos(D) +
-!                                    DDX
-!
-!                          UY2(IX,IY)-UY2(IX,IY+KSY)
-!              + K(IS,IC) -------------------------- sin**2(D)        ]
-!                                    DDY
-!
-!       -----------------------------------------------------
-!       propagation velocity in theta-direction:
-!
-!       CAD(ID,IS,IC) =
-!
-!                     S                   DEP2(IX,IY)-DEP2(IX+KSX,IY)
-!           ------------------------- * [ --------------------------sin(D) -
-!           sinh 2K(IS,IC)DEP2(IX,IY)               DDX
-!
-!            (DEP2(IX,IY) - DEP2(IX,IY+KSY)
-!           ------------------------------- cos(D) ]  +
-!                        DDY
-!
-!        UX2(IX,IY)-UX2(IX+KSX,IY)   UY2(IX,IY)-UY2(IX,IY+KSY)
-!    [  -------------------------- - ------------------------- ] sin(D)cos(D)+
-!                 DDX                         DDY
-!
-!          UY2(IX,IY)-UY2(IX+KSX,IY)
-!       + --------------------------- sin**2(D) -
-!                   DDX
-!
-!          UX2(IX,IY)-UX2(IX,IY+KSY)
-!         --------------------------- cos**2(D)
-!                   DDY
-!
-!
-!
-!     9. STRUCTURE
-!
-!   ------------------------------------------------------------
-!   For current sweep and two adjacent sweeps do
-!       determine interpolation factors RDXL and RDYL
-!       determine depth and current gradients
-!   ------------------------------------------------------------
-!   For each frequency do
-!       determine auxiliary quantities depending on sigma
-!       For each direction in the sweep and two neighbouring
-!           directions do
-!           If IREFR=-1
-!           Then compute reduction factor for contribution due
-!                to depth gradient
-!           ----------------------------------------------------
-!           determine sweep in which this direction is located
-!           using gradients of the proper sweep determine
-!           Csigma (CAS) and Ctheta (CAD)
-!   ------------------------------------------------------------
-!   If ITFRE=0
-!   Then make values of CAS=0
-!   ------------------------------------------------------------
-!   If IREFR=0
-!   Then make values of CAD=0
-!   ------------------------------------------------------------
-!
-!     10. SOURCE
-!
-!************************************************************************
-!
-      SAVE IENT
-      DATA IENT/0/
-      IF (LTRACE) CALL STRACE (IENT,'SPROSD')
-!
-      CAST1 = 0.
-      CAST2 = 0.
-      CAST5 = 0.
-      CADT1 = 0.
-      IX1   = IXCGRD(1)
-      IY1   = IYCGRD(1)
-      KCG1  = KCGRD(1)
-      XC1   = XCGRID(IX1,IY1)
-      YC1   = YCGRID(IX1,IY1)
-      DLOC1 = DEP2(KCG1)
-!
-!     *** test output ***
-!
-      IF (TESTFL .AND. ITEST .GE. 100 ) THEN
-        WRITE(PRINTF, 211) IX1+MXF-2, IY1+MYF-2, XC1+XOFFS, YC1+YOFFS,    40.30
-     &                     DLOC1                                          40.30
- 211    FORMAT(' test SPROSD, location:',2I5,2e12.4,', depth:',F9.2)
-      ENDIF
-!
-      DO ISWP = 1, 3                                                      40.02
-        ISWEEP = SWP_ARRAY(ISWP)                                          40.02
-!
-!       *** prepare depth and current gradient for current sweep and ***
-!       *** two adjacent sweeps                                      ***
-!
-        CAST3(ISWEEP)  = 0.
-        CAST4(ISWEEP)  = 0.
-        CAST6(ISWEEP)  = 0.
-        CAST7(ISWEEP)  = 0.
-        CAST8(ISWEEP)  = 0.
-        CAST9(ISWEEP)  = 0.
-!
-!       *** set the propagation dummy terms CADT 0 ***
-!
-        CADT2(ISWEEP) = 0.
-        CADT3(ISWEEP) = 0.
-        CADT4(ISWEEP) = 0.
-        CADT5(ISWEEP) = 0.
-        CADT6(ISWEEP) = 0.
-        CADT7(ISWEEP) = 0.
-        VALSWP = .TRUE.
-!
-        IF (ISWEEP.EQ.2) THEN
-          KCG2 = KCGRD(2)
-          KCG3 = KCGRD(3)
-          IX2  = IXCGRD(2)
-          IY2  = IYCGRD(2)
-          IX3  = IXCGRD(3)
-          IY3  = IYCGRD(3)
-          SWPNGB = SWPDIR
-          DO II = 1, 2
-            RDXL(II) = RDX(II)
-            RDYL(II) = RDY(II)
-          ENDDO
-!         Refraction and frequency shift are not defined for points
-!         neighbouring to landpoints
-          IF ( (KCG1.EQ.1).OR.(DEP2(KCG1).LE.DEPMIN).OR.                  30.82
-     &         (KCG2.EQ.1).OR.(DEP2(KCG2).LE.DEPMIN).OR.                  30.82
-     &         (KCG3.EQ.1).OR.(DEP2(KCG3).LE.DEPMIN) ) THEN               30.82
-            DO IS = 1, MSC
-              DO ID = 1, MDC
-                CAS(ID,IS,1) = 0.
-                CAD(ID,IS,1) = 0.
-              ENDDO
-            ENDDO
-            GOTO 900
-          ENDIF
-        ELSE
-!         determine neighbouring sweep
-          IF (ISWEEP.EQ.1) THEN
-            SWPNGB = SWPDIR-1
-            IF (SWPNGB.EQ.0) SWPNGB = 4
-          ELSE
-            SWPNGB = SWPDIR+1
-            IF (SWPNGB.EQ.5) SWPNGB = 1
-          ENDIF
-!
-!         determine neighbouring grid points according to sweep
-!
-          IF (SWPNGB.EQ.1) THEN
-            IF (KREPTX.EQ.0) THEN                                         33.09
-              IF (IX1.EQ.1) VALSWP = .FALSE.
-            ENDIF                                                         33.09
-            IF (.NOT.ONED .AND. IY1.EQ.1) VALSWP = .FALSE.
-            IX2 = IX1 - 1
-            IY2 = IY1
-            IX3 = IX1
-            IY3 = IY1 - 1
-          ELSE IF (SWPNGB.EQ.2) THEN
-            IF (KREPTX.EQ.0) THEN                                         33.09
-              IF (IX1.EQ.MXC) VALSWP = .FALSE.
-            ENDIF                                                         33.09
-            IF (.NOT.ONED .AND. IY1.EQ.1) VALSWP = .FALSE.
-            IX2 = IX1 + 1
-            IY2 = IY1
-            IX3 = IX1
-            IY3 = IY1 - 1
-          ELSE IF (SWPNGB.EQ.3) THEN
-            IF (KREPTX.EQ.0) THEN                                         33.09
-              IF (IX1.EQ.MXC) VALSWP = .FALSE.
-            ENDIF                                                         33.09
-            IF (.NOT.ONED .AND. IY1.EQ.MYC) VALSWP = .FALSE.
-            IX2 = IX1 + 1
-            IY2 = IY1
-            IX3 = IX1
-            IY3 = IY1 + 1
-          ELSE IF (SWPNGB.EQ.4) THEN
-            IF (KREPTX.EQ.0) THEN                                         33.09
-              IF (IX1.EQ.1) VALSWP = .FALSE.
-            ENDIF                                                         33.09
-            IF (.NOT.ONED .AND. IY1.EQ.MYC) VALSWP = .FALSE.
-            IX2 = IX1 - 1
-            IY2 = IY1
-            IX3 = IX1
-            IY3 = IY1 + 1
-          ENDIF
-          IF (KREPTX.GT.0) THEN                                           33.09
-            IF (IX2.LE.0)   IX2 = IX2 + MXC                               33.09
-            IF (IX2.GT.MXC) IX2 = IX2 - MXC                               33.09
-          ENDIF
-!
-!         determine interpolation coeffcients (RDXL, RDYL)
-!
-          IF (VALSWP) THEN
-            KCG2 = KGRPNT(IX2,IY2)
-            IF (KCG2.LE.1 .OR. DEP2(KCG2).LE.DEPMIN) VALSWP = .FALSE.     40.14
-            IF (KREPTX.GT.0) THEN                                         33.09
-              DX2 = DX * COSPC                                            33.09
-              DY2 = -DX * SINPC                                           33.09
-            ELSE
-              DX2 = XC1 - XCGRID(IX2,IY2)
-              DY2 = YC1 - YCGRID(IX2,IY2)
-            ENDIF
-            IF (KSPHER.GT.0) THEN
-              DX2 = DX2 * LENDEG * COSLAT(1)
-              DY2 = DY2 * LENDEG
-            ENDIF
-            IF (ONED) THEN
-              KCG3 = KCG1
-              DET     =  DX2**2 + DY2**2
-              RDXL(1) =  DX2/DET
-              RDYL(1) =  DY2/DET
-              RDXL(2) =  0.
-              RDYL(2) =  0.
-            ELSE
-              KCG3 = KGRPNT(IX3,IY3)
-              IF (KCG3.LE.1 .OR. DEP2(KCG3).LE.DEPMIN) VALSWP = .FALSE.   40.14
-              DX3 = XC1 - XCGRID(IX3,IY3)
-              DY3 = YC1 - YCGRID(IX3,IY3)
-              IF (KSPHER.GT.0) THEN
-                DX3 = DX3 * LENDEG * COSLAT(1)
-                DY3 = DY3 * LENDEG
-              ENDIF
-              DET     =  DY3*DX2 - DY2*DX3
-              RDXL(1) =  DY3/DET
-              RDYL(1) = -DX3/DET
-              RDXL(2) = -DY2/DET
-              RDYL(2) =  DX2/DET
-            ENDIF
-          ENDIF
-        ENDIF
-!
-!       *** compute the derivatives of the depth and the current velocity ***
-!
-        IF (VALSWP) THEN
-
-          IF (IREFR.EQ.-1) THEN                                           40.02
-
-!           limitation of depths in neighbouring grid points
-
-            DLOC2 = MIN (DEP2(KCG2), PNUMS(17)*DLOC1)
-            DLOC3 = MIN (DEP2(KCG3), PNUMS(17)*DLOC1)
-          ELSE                                                            40.02
-
-!           no limitation                                                 40.02
-
-            DLOC2 = DEP2(KCG2)                                            40.02
-            DLOC3 = DEP2(KCG3)                                            40.02
-          END IF                                                          40.02
-
-!         *** @D/@X ***
-          DPDX = RDXL(1) * (DLOC1-DLOC2) + RDXL(2) * (DLOC1-DLOC3)
-
-!         *** @D/@Y ***
-          DPDY = RDYL(1) * (DLOC1-DLOC2) + RDYL(2) * (DLOC1-DLOC3)
-!
-          CADT2(ISWEEP) = DPDX                                            30.21
-          CADT3(ISWEEP) = DPDY                                            30.21
-!
-          IF ( ICUR .EQ. 1 ) THEN
-!           *** current is on ***
-!
-!           *** @Ux/@X ***
-            DUXDX =  RDXL(1) * (UX2(KCG1) - UX2(KCG2))
-     &             + RDXL(2) * (UX2(KCG1) - UX2(KCG3))
-!
-!           *** @Ux/@Y ***
-            DUXDY =  RDYL(1) * (UX2(KCG1) - UX2(KCG2))
-     &             + RDYL(2) * (UX2(KCG1) - UX2(KCG3))
-!
-!           *** @Uy/@X ***
-            DUYDX =  RDXL(1) * (UY2(KCG1) - UY2(KCG2))
-     &             + RDXL(2) * (UY2(KCG1) - UY2(KCG3))
-!
-!           *** @Uy/@Y ***
-            DUYDY =  RDYL(1) * (UY2(KCG1) - UY2(KCG2))
-     &             + RDYL(2) * (UY2(KCG1) - UY2(KCG3))
-
-            CAST3(ISWEEP) = UX2(KCG1) * DPDX
-            CAST4(ISWEEP) = UY2(KCG1) * DPDY
-          ELSE
-            DUXDX = 0.
-            DUXDY = 0.
-            DUYDX = 0.
-            DUYDY = 0.
-            CAST3(ISWEEP) = 0.
-            CAST4(ISWEEP) = 0.
-          ENDIF
-!
-          CAST6(ISWEEP) = DUXDX
-          CAST7(ISWEEP) = DUXDY
-          CAST8(ISWEEP) = DUYDX
-          CAST9(ISWEEP) = DUYDY
-!
-!         *** coefficients for CAD -> function of IX and IY only ***
-!
-          CADT2(ISWEEP) = DPDX
-          CADT3(ISWEEP) = DPDY
-          CADT4(ISWEEP) = DUXDX
-          CADT5(ISWEEP) = DUYDY
-          CADT6(ISWEEP) = DUYDX
-          CADT7(ISWEEP) = DUXDY
-!
-        ELSE
-!         if gradients cannot be determined because one grid point is missing,
-!         use gradient computed for the central sweep
-          CAST3(ISWEEP) = CAST3(2)
-          CAST4(ISWEEP) = CAST4(2)
-          CAST6(ISWEEP) = CAST6(2)
-          CAST7(ISWEEP) = CAST7(2)
-          CAST8(ISWEEP) = CAST8(2)
-          CAST9(ISWEEP) = CAST9(2)
-          CADT2(ISWEEP) = CADT2(2)
-          CADT3(ISWEEP) = CADT3(2)
-          CADT4(ISWEEP) = CADT4(2)
-          CADT5(ISWEEP) = CADT5(2)
-          CADT6(ISWEEP) = CADT6(2)
-          CADT7(ISWEEP) = CADT7(2)
-        ENDIF
-!
-!       *** test output ***
-!
-        IF (TESTFL .AND. ITEST .GE. 100 ) THEN
-          WRITE(PRINTF, 411) SWPNGB, IX2+MXF-2, IY2+MYF-2, DLOC2,
-     &                               IX3+MXF-2, IY3+MYF-2, DLOC3
- 411      FORMAT(' sweep, depths:', I2, 2(I6,I4,F9.2))
-          IF (ICUR .EQ. 1) THEN
-            WRITE(PRINTF, 412) UX2(KCG1),UX2(KCG2),UX2(KCG3),
-     &                         UY2(KCG1),UY2(KCG2),UY2(KCG3)
- 412        FORMAT(10X, 'UX:',3(1X,F8.3),/, 10X, 'UY:',3(1X,F8.3))
-          ENDIF
-          WRITE(PRINTF, 413) RDXL(1),RDXL(2),RDYL(1),RDYL(2)
- 413      FORMAT(10X, 'RDX etc.:',4(1X,E12.4))
-          WRITE(PRINTF, 414) DPDX,  DPDY
- 414      FORMAT(10x, 'DPDX,DPDY:',2(1X,E12.4))
-        ENDIF
-      ENDDO
-!
-!     *** coefficients for CAS -> function of IX and IY only ***
-!
-      IF ( NSTATC.EQ.0 .OR. .NOT.DYNDEP) THEN                             40.00
-!       *** stationary calculation ***
-        CAST2 = 0.
-      ELSE
-!       nonstationary depth, CAST2 is @D/@t
-        CAST2 = ( DLOC1 - DEP1(KCG1) ) * RDTIM
-      END IF
-!
-      DO 70 IS = 1, MSC
-        KD1 = KWAVE(IS,1) * DLOC1
-        IF ( KD1 .GT. 30.0 ) KD1 = 30.
-        VLSINH = SINH (2.* KD1 )
-        COEF   = SPCSIG(IS) / VLSINH                                      30.72
-!
-!       *** coefficients for CAS -> function of IS only ***
-!
-        CAST1 = KWAVE(IS,1) * COEF
-        CAST5 = CGO(IS,1) * KWAVE(IS,1)
-!
-!       *** coefficients for CAD -> function of IS only ***
-!
-        CADT1 =  COEF
-!
-!       loop over spectral directions
-!
-        DO 60 IDDUM = IDDLOW-1, IDDTOP+1                                  40.61 40.03
-          ID = MOD ( IDDUM - 1 + MDC , MDC ) + 1
-          IF (IDDUM.EQ.IDCMIN(IS)-1) THEN
-!           direction is in the lower adjacent sweep
-            ISWEEP = 1
-          ELSE IF (IDDUM.EQ.IDCMAX(IS)+1) THEN
-!           direction is in the upper adjacent sweep
-            ISWEEP = 3
-          ELSE
-!           direction is in the current sweep
-            ISWEEP = 2
-          ENDIF
-!
-!         *** computation of CAS and CAD ***
-!
-          IF (ICUR .EQ. 0) THEN
-            CAS(ID,IS,1) = CAST1 * CAST2
-!
-            CAD(ID,IS,1) = CADT1 * ( ESIN(ID) * CADT2(ISWEEP) -
-     &                               ECOS(ID) * CADT3(ISWEEP) )
-
-!           --- adapt the velocity in case of diffraction                 40.21
-            IF (IDIFFR.EQ.1) THEN                                         40.21
-               CAD(ID,IS,1) = DIFPARAM(KCG1)*CAD(ID,IS,1)
-     &                      - DIFPARDX(KCG1)*CGO(IS,1)*ESIN(ID)           40.21
-     &                      + DIFPARDY(KCG1)*CGO(IS,1)*ECOS(ID)           40.21
-            END IF
-
-          ELSE
-            IF (IDIFFR.EQ.0) THEN                                         40.21
-               CAS(ID,IS,1)= CAST1 *
-     &              (CAST2 + CAST3(ISWEEP) + CAST4(ISWEEP)) -
-     &               CAST5 *
-     &              (COSCOS(ID) * CAST6(ISWEEP) +
-     &               SINCOS(ID) * (CAST7(ISWEEP) + CAST8(ISWEEP)) +
-     &               SINSIN(ID) * CAST9(ISWEEP) )
-
-               CAD(ID,IS,1) =
-     &             CADT1 * (ESIN(ID) * CADT2(ISWEEP) -
-     &                      ECOS(ID) * CADT3(ISWEEP)) +
-     &             SINCOS(ID) * (CADT4(ISWEEP) - CADT5(ISWEEP)) +
-     &             SINSIN(ID) *  CADT6(ISWEEP) -
-     &             COSCOS(ID) *  CADT7(ISWEEP)
-            ELSE IF (IDIFFR.EQ.1) THEN                                    40.21
-               CAS(ID,IS,1)= CAST1 *                                      40.21
-     &              (CAST2 + CAST3(ISWEEP) + CAST4(ISWEEP)) -             40.21
-     &               DIFPARAM(KCG1)*CAST5 *                               40.21
-     &              (COSCOS(ID) * CAST6(ISWEEP) +                         40.21
-     &               SINCOS(ID) * (CAST7(ISWEEP) + CAST8(ISWEEP)) +       40.21
-     &               SINSIN(ID) * CAST9(ISWEEP) )                         40.21
-
-               CAD(ID,IS,1) = DIFPARAM(KCG1)*                             40.21
-     &             CADT1 * (ESIN(ID) * CADT2(ISWEEP) -                    40.21
-     &                      ECOS(ID) * CADT3(ISWEEP))                     40.21
-     &                      - DIFPARDX(KCG1)*CGO(IS,1)*ESIN(ID)           40.21
-     &                      + DIFPARDY(KCG1)*CGO(IS,1)*ECOS(ID) +         40.21
-     &             SINCOS(ID) * (CADT4(ISWEEP) - CADT5(ISWEEP)) +         40.21
-     &             SINSIN(ID) *  CADT6(ISWEEP) -                          40.21
-     &             COSCOS(ID) *  CADT7(ISWEEP)                            40.21
-            END IF                                                        40.21
-          ENDIF
-!
- 60     CONTINUE
- 70   CONTINUE
-!
-!     *** for most cases CAS and CAD will be activated. Therefore ***
-!     *** for IREFR is set 0 (no refraction) or ITFRE = 0 (no     ***
-!     *** frequency shift) we have put the IF statement outside   ***
-!     *** the internal loop above                                 ***
-!
- 10   IF (ITFRE .EQ. 0) THEN
-        DO IS = 1, MSC
-          DO ID = 1, MDC
-            CAS(ID,IS,1) = 0.0
-          ENDDO
-        ENDDO
-      ENDIF
-!
-      IF (IREFR .EQ. 0) THEN
-        DO IS = 1, MSC
-          DO ID = 1, MDC
-            CAD(ID,IS,1) = 0.0
-          ENDDO
-        ENDDO
-      ENDIF
-!
-!     --- limit Ctheta in some frequency range if requested
-!
-      IF ( INT(PNUMS(29)).EQ.1 ) THEN
-         FRLIM = PI2*PNUMS(26)
-         PP    =     PNUMS(27)
-         DO IS = 1, MSC
-            FAC = MIN(1.,(SPCSIG(IS)/FRLIM)**PP)
-            DO ID = 1, MDC
-               CAD(ID,IS,1) = FAC*CAD(ID,IS,1)
-            ENDDO
-         ENDDO
-      ENDIF
-!
-!     --- limit Csigma using Courant number
-!
-      IF ( INT(PNUMS(33)).EQ.1 ) THEN
-         !
-         ALPHA = PNUMS(34)
-         !
-         DO IS = 1, MSC
-            !
-            FAC2 = ALPHA * FRINTF * SPCSIG(IS)
-            !
-            DO IDDUM = IDCMIN(IS), IDCMAX(IS)
-               ID = MOD ( IDDUM - 1 + MDC , MDC ) + 1
-               !
-               FAC = FAC2 * ( ABS((RDX(1)+RDX(2))*CAX(ID,IS,1)) +
-     &                        ABS((RDY(1)+RDY(2))*CAY(ID,IS,1)) )
-               !
-               IF ( ABS(CAS(ID,IS,1)) > FAC ) THEN
-                  CAS(ID,IS,1) = CAS(ID,IS,1) * FAC / ABS(CAS(ID,IS,1))
-               ENDIF
-               !
-            ENDDO
-            !
-         ENDDO
-         !
-      ENDIF
-!
-!     --- limit Ctheta using Courant number
-!
-      IF ( INT(PNUMS(35)) == 1 ) THEN
-         !
-         ALPHA = PNUMS(36)
-         !
-         FAC2 = ALPHA * DDIR
-         !
-         DO IS = 1, MSC
-            !
-            DO IDDUM = IDCMIN(IS)-1, IDCMAX(IS)+1
-               ID = MOD ( IDDUM - 1 + MDC , MDC ) + 1
-               !
-               FAC = FAC2 * ( ABS((RDX(1)+RDX(2))*CAX(ID,IS,1)) +
-     &                        ABS((RDY(1)+RDY(2))*CAY(ID,IS,1)) )
-               !
-               IF ( ABS(CAD(ID,IS,1)) > FAC ) THEN
-                  CAD(ID,IS,1) = CAD(ID,IS,1) * FAC / ABS(CAD(ID,IS,1))
-               ENDIF
-               !
-            ENDDO
-            !
-         ENDDO
-         !
-      ENDIF
-!
-!     *** test output ***
-!
-      IF (TESTFL .AND. ITEST.GE.140) THEN                                 40.00
-        IF (DYNDEP .OR. ICUR.GT.0) THEN
-          WRITE(PRINTF, *) ' IS ID1 ID2        values of CAS'             40.00
-          DO 602 IS = 1, MSC
-            ID1 = IDCMIN(IS)-1
-            ID2 = IDCMAX(IS)+1
-            WRITE(PRINTF, 619) IS, ID1, ID2,                              40.00
-     &            (CAS(MOD(IDDUM-1+MDC,MDC)+1, IS, 1), IDDUM=ID1,ID2)     40.00
- 619        FORMAT(3I4, 2X, 600E12.4)                                     40.00
- 602      CONTINUE
-        ENDIF
-        WRITE(PRINTF, *) ' IS ID1 ID2        values of CAD'               40.00
-        DO 604 IS = 1, MSC
-          ID1 = IDCMIN(IS)-1
-          ID2 = IDCMAX(IS)+1
-          WRITE(PRINTF,619) IS, ID1, ID2,                                 40.00
-     &          (CAD(MOD(IDDUM-1+MDC,MDC)+1, IS, 1), IDDUM=ID1,ID2)       40.00
- 604   CONTINUE
-      ENDIF                                                               40.00
-!
-!     end of the subroutine SPROSD
- 900  RETURN
-      END
-!
-!****************************************************************
-!
-      SUBROUTINE SPROSDM(SPCSIG     ,KWAVE      ,CAS        ,             40.03
-     &                   CAD        ,CGO        ,                         30.80
-     &                   DEP2       ,DEP1       ,ECOS       ,
-     &                   ESIN       ,UX2        ,UY2        ,
      &                   COSCOS     ,SINSIN     ,SINCOS     ,             30.80
      &                   RDX        ,RDY        ,                         30.80
      &                   CAX        ,CAY        ,                         30.80
@@ -2236,7 +1405,7 @@
 
       SAVE IENT
       DATA IENT/0/
-      IF (LTRACE) CALL STRACE (IENT,'SPROSDM')
+      IF (LTRACE) CALL STRACE (IENT,'SPROSD')
 
       CAST1 = 0.
       CAST2 = 0.
@@ -2301,7 +1470,7 @@
         WRITE(PRINTF, 211) IX1+MXF-2, IY1+MYF-2,                          40.30
      &                     XCGRID(IX1,IY1)+XOFFS, YCGRID(IX1,IY1)+YOFFS,
      &                     DLOC1                                          40.30
- 211    FORMAT(' test SPROSDM, location:',2I5,2e12.4,', depth:',F9.2)
+ 211    FORMAT(' test SPROSD, location:',2I5,2e12.4,', depth:',F9.2)
       ENDIF
 !
 !     *** set some terms = 0 ***
@@ -2319,34 +1488,34 @@
 !                      2DY USING P4-P3
 
 !     *** @D/@X ***
-      DHDX = 1.0*RDX(1) * (DLOC1-DLOC2) + 1.0*RDX(2) * (DLOC1-DLOC3) ! upwind scheme
-!      DHDX = 0.5*RDX(1) * (DLOC5-DLOC2) + 0.5*RDX(2) * (DLOC4-DLOC3) ! centered scheme       40.59
+!      DHDX = 1.0*RDX(1) * (DLOC1-DLOC2) + 1.0*RDX(2) * (DLOC1-DLOC3) ! upwind scheme
+      DHDX = 0.5*RDX(1) * (DLOC5-DLOC2) + 0.5*RDX(2) * (DLOC4-DLOC3) ! centered scheme       40.59
 !     *** @D/@Y ***
-      DHDY = 1.0*RDY(1) * (DLOC1-DLOC2) + 1.0*RDY(2) * (DLOC1-DLOC3) ! upwind scheme
-!      DHDY = 0.5*RDY(1) * (DLOC5-DLOC2) + 0.5*RDY(2) * (DLOC4-DLOC3) ! centered scheme       40.59
+!      DHDY = 1.0*RDY(1) * (DLOC1-DLOC2) + 1.0*RDY(2) * (DLOC1-DLOC3) ! upwind scheme
+      DHDY = 0.5*RDY(1) * (DLOC5-DLOC2) + 0.5*RDY(2) * (DLOC4-DLOC3) ! centered scheme       40.59
 
       IF ( ICUR .EQ. 1 ) THEN  !           *** current is on ***
 !
 !     *** @Ux/@X ***
-         DUXDX = 1.0*RDX(1) * (UXLOC1 - UXLOC2) +
-     &           1.0*RDX(2) * (UXLOC1 - UXLOC3)
-!         DUXDX = 0.5*RDX(1) * (UXLOC5 - UXLOC2) +
-!     &           0.5*RDX(2) * (UXLOC4 - UXLOC3)                            40.59
+!         DUXDX = 1.0*RDX(1) * (UXLOC1 - UXLOC2) +
+!     &           1.0*RDX(2) * (UXLOC1 - UXLOC3)
+         DUXDX = 0.5*RDX(1) * (UXLOC5 - UXLOC2) +
+     &           0.5*RDX(2) * (UXLOC4 - UXLOC3)                           40.59
 !     *** @Ux/@Y ***
-         DUXDY = 1.0*RDY(1) * (UXLOC1 - UXLOC2) +
-     &           1.0*RDY(2) * (UXLOC1 - UXLOC3)
-!         DUXDY = 0.5*RDY(1) * (UXLOC5 - UXLOC2) +
-!     &           0.5*RDY(2) * (UXLOC4 - UXLOC3)                            40.59
+!         DUXDY = 1.0*RDY(1) * (UXLOC1 - UXLOC2) +
+!     &           1.0*RDY(2) * (UXLOC1 - UXLOC3)
+         DUXDY = 0.5*RDY(1) * (UXLOC5 - UXLOC2) +
+     &           0.5*RDY(2) * (UXLOC4 - UXLOC3)                           40.59
 !     *** @Uy/@X ***
-         DUYDX = 1.0*RDX(1) * (UYLOC1 - UYLOC2) +
-     &           1.0*RDX(2) * (UYLOC1 - UYLOC3)
-!         DUYDX = 0.5*RDX(1) * (UYLOC5 - UYLOC2) +
-!     &           0.5*RDX(2) * (UYLOC4 - UYLOC3)                            40.59
+!         DUYDX = 1.0*RDX(1) * (UYLOC1 - UYLOC2) +
+!     &           1.0*RDX(2) * (UYLOC1 - UYLOC3)
+         DUYDX = 0.5*RDX(1) * (UYLOC5 - UYLOC2) +
+     &           0.5*RDX(2) * (UYLOC4 - UYLOC3)                           40.59
 !     *** @Uy/@Y ***
-         DUYDY = 1.0*RDY(1) * (UYLOC1 - UYLOC2) +
-     &           1.0*RDY(2) * (UYLOC1 - UYLOC3)
-!         DUYDY = 0.5*RDY(1) * (UYLOC5 - UYLOC2) +
-!     &           0.5*RDY(2) * (UYLOC4 - UYLOC3)                            40.59
+!         DUYDY = 1.0*RDY(1) * (UYLOC1 - UYLOC2) +
+!     &           1.0*RDY(2) * (UYLOC1 - UYLOC3)
+         DUYDY = 0.5*RDY(1) * (UYLOC5 - UYLOC2) +
+     &           0.5*RDY(2) * (UYLOC4 - UYLOC3)                           40.59
 
        CAST3 = UXLOC1 * DHDX
        CAST4 = UYLOC1 * DHDY
@@ -2402,12 +1571,11 @@
         CLOC5=SPCSIG(IS)/KLOC5
 
 !       upwind scheme
-        DCDX = 1.0*RDX(1) * (CLOC1-CLOC2) + 1.0*RDX(2) * (CLOC1-CLOC3)    40.59
-        DCDY = 1.0*RDY(1) * (CLOC1-CLOC2) + 1.0*RDY(2) * (CLOC1-CLOC3)    40.59
-
+!        DCDX = 1.0*RDX(1) * (CLOC1-CLOC2) + 1.0*RDX(2) * (CLOC1-CLOC3)    40.59
+!        DCDY = 1.0*RDY(1) * (CLOC1-CLOC2) + 1.0*RDY(2) * (CLOC1-CLOC3)    40.59
 !       centered scheme
-!        DCDX = 0.5*RDX(1) * (CLOC5-CLOC2) + 0.5*RDX(2) * (CLOC4-CLOC3)    40.59
-!        DCDY = 0.5*RDY(1) * (CLOC5-CLOC2) + 0.5*RDY(2) * (CLOC4-CLOC3)    40.59
+        DCDX = 0.5*RDX(1) * (CLOC5-CLOC2) + 0.5*RDX(2) * (CLOC4-CLOC3)    40.59
+        DCDY = 0.5*RDY(1) * (CLOC5-CLOC2) + 0.5*RDY(2) * (CLOC4-CLOC3)    40.59
 
 !       *** coefficients for CAS -> function of IS only ***
 
@@ -2425,10 +1593,12 @@
 
 !          *** computation of CAS and CAD ***
 
-          ! @h/@x method is given here, in case someone would later wish to implement it as an option
-!         CAD_TMP=COEF*(ESIN(ID)*DHDX-ECOS(ID)*DHDY) ! @h/@x method, currents not included , Christoffersen, Tolman, Ris, Won et al.
-          CAD_TMP=(CGLOC1/CLOC1)*(ESIN(ID)*DCDX-ECOS(ID)*DCDY) ! @C/@x method, currents not included, Young method (1999, p. 45)
-!         CAD_TMP=(CGLOC1/KLOC1)*(-1.0)*(ESIN(ID)*DKDX-ECOS(ID)*DKDY)   ! @k/@x method, differs only very slightly from @C/dx
+          IF ( INT(PNUMS(32)).EQ.0 ) THEN
+             CAD_TMP=COEF*(ESIN(ID)*DHDX-ECOS(ID)*DHDY) ! @h/@x method, currents not included , Christoffersen, Tolman, Ris, Won et al.
+          ELSE IF ( INT(PNUMS(32)).EQ.1 ) THEN
+             CAD_TMP=(CGLOC1/CLOC1)*(ESIN(ID)*DCDX-ECOS(ID)*DCDY) ! @C/@x method, currents not included, Young method (1999, p. 45)
+!             CAD_TMP=(CGLOC1/KLOC1)*(-1.0)*(ESIN(ID)*DKDX-ECOS(ID)*DKDY)   ! @k/@x method, differs only very slightly from @C/dx
+          ENDIF
 
 !         Intuitively, one may expect that variable currents could be included via @C/@x. However, this is not the case.
 !         C is determined from sigma and k (and the latter is determined from sigma).
@@ -2585,9 +1755,9 @@
         ENDDO
       ENDIF                                                               40.00
 !
-!     end of the subroutine SPROSDM
+!     end of the subroutine SPROSD
 900   RETURN
-      END subroutine SPROSDM
+      END subroutine SPROSD
 !****************************************************************
 !
       SUBROUTINE DSPHER (CAD, CAX, CAY, ANYBIN, YCGRID, ECOS, ESIN)       40.41 33.09 NB!
@@ -3118,6 +2288,7 @@
 !        33.09: Nico Booij (changes related to spherical coordinates)
 !        40.08: Erick Rogers
 !        40.41: Marcel Zijlema
+!        40.59: W. Erick Rogers
 !        40.85: Marcel Zijlema
 !        40.98: Marcel Zijlema
 !
@@ -3133,6 +2304,7 @@
 !                          Remove option for controllable 1st order diffusion ("XYMU",
 !                          "THETAK", etc.)
 !        40.41, Oct. 04: common blocks replaced by modules, include files removed
+!        40.59, Aug. 07: stencil modification
 !        40.85, Aug. 08: store xy-propagation for output purposes
 !        40.98, Feb. 09: SORDUP scheme is made consistent
 !
@@ -3159,8 +2331,8 @@
 !        KCGRD(1) :   IX  ,IY
 !        KCGRD(2) :   IX-1,IY
 !        KCGRD(3) :   IX  ,IY-1
-!        KCGRD(4) :   IX-2,IY
-!        KCGRD(5) :   IX  ,IY-2
+!        KCGRD(6) :   IX-2,IY                                             40.59
+!        KCGRD(7) :   IX  ,IY-2                                           40.59
 !
 !        The scheme is:
 !
@@ -3169,20 +2341,20 @@
 !            @x
 !
 !        [1.5*CAX(ID,IS,1)*AC2(ID,IS,KCGRD(1))-2.0*CAX(ID,IS,2)*AC2(ID,IS,KCGRD(2))
-!        +0.5*CAX(ID,IS,4)*AC2(ID,IS,KCGRD(4))]/DX
+!        +0.5*CAX(ID,IS,6)*AC2(ID,IS,KCGRD(6))]/DX
 !
 !        @[CAY AC2]
 !        --------- =
 !            @y
 !
 !        [1.5*CAY(ID,IS,1)*AC2(ID,IS,KCGRD(1))-2.0*CAY(ID,IS,3)*AC2(ID,IS,KCGRD(3))
-!        +0.5*CAY(ID,IS,5)*AC2(ID,IS,KCGRD(5))]/DY
+!        +0.5*CAY(ID,IS,7)*AC2(ID,IS,KCGRD(7))]/DY
 !
 !        ADD TO DIAGONAL:
 !        +1.5*CAX(ID,IS,1)/DX+1.5*CAY(ID,IS,1)/DY
 !        ADD TO RHS:
-!        +[2.0*CAX(ID,IS,2)*AC2(ID,IS,KCGRD(2)-0.5*CAX(ID,IS,4)*AC2(ID,IS,KCGRD(4)]/DX
-!        +[2.0*CAY(ID,IS,3)*AC2(ID,IS,KCGRD(3)-0.5*CAY(ID,IS,5)*AC2(ID,IS,KCGRD(5)]/DY
+!        +[2.0*CAX(ID,IS,2)*AC2(ID,IS,KCGRD(2)-0.5*CAX(ID,IS,6)*AC2(ID,IS,KCGRD(6)]/DX
+!        +[2.0*CAY(ID,IS,3)*AC2(ID,IS,KCGRD(3)-0.5*CAY(ID,IS,7)*AC2(ID,IS,KCGRD(7)]/DY
 !
 !     4. PARAMETERLIST
 !
@@ -3232,7 +2404,7 @@
 !   ------------------------------------------------------------
 !
       INTEGER  IS,ID,IDDUM,ISSTOP                                         33.10
-     &         ,IND2,IND3,IND4,IND5                                       33.10
+     &         ,IND2,IND3,IND6,IND7                                       40.59 33.10
 !
       REAL  :: FXY1 ,FXY2
 !
@@ -3241,7 +2413,7 @@
       REAL  :: CAX(MDC,MSC,MICMAX) ,CAY(MDC,MSC,MICMAX)                   40.22
       REAL  :: IMATRA(MDC,MSC)    ,IMATDA(MDC,MSC)            ,
      &         RDX(MICMAX)        ,RDY(MICMAX)                ,           40.08
-     &         XMU(5)             ,YMU(5)                                 40.08 33.10
+     &         XMU(7)             ,YMU(7)                                 40.59 40.08 33.10
       REAL  :: TRAC0(MDC,MSC,MTRNP)                                       40.85
       REAL  :: TRAC1(MDC,MSC,MTRNP)                                       40.85
 
@@ -3271,17 +2443,21 @@
       DO 200 IS = 1, ISSTOP
         IND2 = KCGRD(2)
         IND3 = KCGRD(3)
-        IND4 = KCGRD(4)                                                   33.10
-        IND5 = KCGRD(5)                                                   33.10
+        IND6 = KCGRD(6)                                                   40.59 33.10
+        IND7 = KCGRD(7)                                                   40.59 33.10
         DO 100 IDDUM = IDCMIN(IS), IDCMAX(IS)
           ID = MOD ( IDDUM - 1 + MDC , MDC ) + 1
 !         find Courant number values: XMU, YMU                            40.08
 !         depending on relative size of XMU and YMU, XNUM is true or      40.08
 !         false because of RDX and RDY, XMU and YMU are always positive   40.08
-          DO IXY=1,5                                                      40.08
+          DO IXY=1,3                                                      40.59 40.08
              XMU(IXY) = RDX(1)*CAX(ID,IS,IXY) + RDY(1)*CAY(ID,IS,IXY)     40.08
              YMU(IXY) = RDX(2)*CAX(ID,IS,IXY) + RDY(2)*CAY(ID,IS,IXY)     40.08
           END DO                                                          40.08
+          DO IXY=6,7                                                      40.59
+             XMU(IXY) = RDX(1)*CAX(ID,IS,IXY) + RDY(1)*CAY(ID,IS,IXY)     40.59
+             YMU(IXY) = RDX(2)*CAX(ID,IS,IXY) + RDY(2)*CAY(ID,IS,IXY)     40.59
+          END DO                                                          40.59
           IF(YMU(1).GT.XMU(1))THEN                                        33.10
 !            propagation mainly from grid point 3
              XNUM=.TRUE.                                                  33.10
@@ -3302,9 +2478,9 @@
 
 !             the known, rhs part FXY2                                    33.08
               FXY2 = AC2(ID,IS,IND2) * 2.0*XMU(2)                         40.08 33.10
-     &              -AC2(ID,IS,IND4) * 0.5*XMU(4)                         40.08 33.10
+     &              -AC2(ID,IS,IND6) * 0.5*XMU(6)                         40.59 40.08 33.10
      &              +AC2(ID,IS,IND3) * 2.0*YMU(3)                         40.08 33.10
-     &              -AC2(ID,IS,IND5) * 0.5*YMU(5)                         40.08 33.10
+     &              -AC2(ID,IS,IND7) * 0.5*YMU(7)                         40.59 40.08 33.10
 
             ELSE                                                          33.10
 !             Spherical coordinates
@@ -3313,17 +2489,17 @@
 
               FXY2 =
      &        AC2(ID,IS,IND2) * CAX(ID,IS,2) * RDX(1) * 2.0               40.08 33.10
-     &       -AC2(ID,IS,IND4) * CAX(ID,IS,4) * RDX(1) * 0.5               40.98 40.08 33.10
+     &       -AC2(ID,IS,IND6) * CAX(ID,IS,6) * RDX(1) * 0.5               40.98 40.59 40.08 33.10
      &       +AC2(ID,IS,IND3) * CAX(ID,IS,3) * RDX(2) * 2.0               40.08 33.10
-     &       -AC2(ID,IS,IND5) * CAX(ID,IS,5) * RDX(2) * 0.5               40.98 40.08 33.10
+     &       -AC2(ID,IS,IND7) * CAX(ID,IS,7) * RDX(2) * 0.5               40.98 40.59 40.08 33.10
      &      +(AC2(ID,IS,IND2) * CAY(ID,IS,2) * RDY(1) * COSLAT(2) * 2.0   40.08 33.10
-     &       -AC2(ID,IS,IND4) * CAY(ID,IS,4) * RDY(1) * COSLAT(4) * 0.5   40.98 40.08 33.10
+     &       -AC2(ID,IS,IND6) * CAY(ID,IS,6) * RDY(1) * COSLAT(6) * 0.5   40.98 40.59 40.08 33.10
      &       +AC2(ID,IS,IND3) * CAY(ID,IS,3) * RDY(2) * COSLAT(3) * 2.0   40.08 33.10
-     &       -AC2(ID,IS,IND5) * CAY(ID,IS,5) * RDY(2) * COSLAT(5) * 0.5   40.98 40.08 33.10
+     &       -AC2(ID,IS,IND7) * CAY(ID,IS,7) * RDY(2) * COSLAT(7) * 0.5   40.98 40.59 40.08 33.10
      &        ) / COSLAT(1) !33.10
             ENDIF
 
-          ELSE      ! switch 2<==>3, 4<==>5 and YMU<==>XMU                33.10
+          ELSE      ! switch 2<==>3, 6<==>7 and YMU<==>XMU                40.59 33.10
 
 ! The diag part FXY1
             FXY1 = 1.5*YMU(1)+ 1.5*XMU(1)                                 40.98 40.08 33.10
@@ -3333,9 +2509,9 @@
 
 !             the known, rhs part  FXY2                                   33.08
               FXY2 = AC2(ID,IS,IND3) * 2.0*YMU(3)                         40.08 33.10
-     &              -AC2(ID,IS,IND5) * 0.5*YMU(5)                         40.08 33.10
+     &              -AC2(ID,IS,IND7) * 0.5*YMU(7)                         40.59 40.08 33.10
      &              +AC2(ID,IS,IND2) * 2.0*XMU(2)                         40.08 33.10
-     &              -AC2(ID,IS,IND4) * 0.5*XMU(4)                         40.08 33.10
+     &              -AC2(ID,IS,IND6) * 0.5*XMU(6)                         40.59 40.08 33.10
 
             ELSE
 !             Spherical coordinates
@@ -3343,13 +2519,13 @@
 !             the known, rhs part  FXY2                                   33.08
               FXY2 =
      &        AC2(ID,IS,IND2) * CAX(ID,IS,2) * RDX(1) * 2.0               40.08 33.10
-     &       -AC2(ID,IS,IND4) * CAX(ID,IS,4) * RDX(1) * 0.5               40.98 40.08 33.10
+     &       -AC2(ID,IS,IND6) * CAX(ID,IS,6) * RDX(1) * 0.5               40.98 40.59 40.08 33.10
      &       +AC2(ID,IS,IND3) * CAX(ID,IS,3) * RDX(2) * 2.0               40.08 33.10
-     &       -AC2(ID,IS,IND5) * CAX(ID,IS,5) * RDX(2) * 0.5               40.98 40.08 33.10
+     &       -AC2(ID,IS,IND7) * CAX(ID,IS,7) * RDX(2) * 0.5               40.98 40.59 40.08 33.10
      &      +(AC2(ID,IS,IND2) * CAY(ID,IS,2) * RDY(1) * COSLAT(2) * 2.0   40.08 33.10
-     &       -AC2(ID,IS,IND4) * CAY(ID,IS,4) * RDY(1) * COSLAT(4) * 0.5   40.98 40.08 33.10
+     &       -AC2(ID,IS,IND6) * CAY(ID,IS,6) * RDY(1) * COSLAT(6) * 0.5   40.98 40.59 40.08 33.10
      &       +AC2(ID,IS,IND3) * CAY(ID,IS,3) * RDY(2) * COSLAT(3) * 2.0   40.08 33.10
-     &       -AC2(ID,IS,IND5) * CAY(ID,IS,5) * RDY(2) * COSLAT(5) * 0.5   40.98 40.08 33.10
+     &       -AC2(ID,IS,IND7) * CAY(ID,IS,7) * RDY(2) * COSLAT(7) * 0.5   40.98 40.59 40.08 33.10
      &        )/ COSLAT(1)
             ENDIF
           END IF
--- SwanCompUnstruc.ftn90	2015-02-04 11:52:57.000000000 +0100
+++ SwanCompUnstruc.ftn90	2015-11-27 11:35:18.388469931 +0100
@@ -38,6 +38,7 @@
 !   41.07: Marcel Zijlema
 !   41.10: Marcel Zijlema
 !   41.20: Casey Dietrich
+!   41.60: Marcel Zijlema
 !
 !   Updates
 !
@@ -48,6 +49,7 @@
 !   41.07,   August 2009: bug fix: never-ending sweep is prevented
 !   41.10,   August 2009: parallelization using OpenMP directives
 !   41.20,     June 2010: extension to tightly coupled ADCIRC+SWAN model
+!   41.60,     July 2015: more accurate computation of gradients of depth or wave number for turning rate
 !
 !   Purpose
 !
@@ -173,6 +175,8 @@
     real                                  :: dal1      ! a coefficent for the 4 wave-wave interactions
     real                                  :: dal2      ! another coefficent for the 4 wave-wave interactions
     real                                  :: dal3      ! just another coefficent for the 4 wave-wave interactions
+    real                                  :: dhdx      ! derivative of depth in x-direction
+    real                                  :: dhdy      ! derivative of depth in y-direction
 !PUN    real(SZ), dimension(1)                :: dum1      ! a dummy real meant for UPDATER
 !PUN    real(SZ), dimension(1)                :: dum2      ! a dummy real meant for UPDATER
     real                                  :: dummy     ! dummy variable (to be used in existing SWAN routine call)
@@ -220,6 +224,8 @@
     real, dimension(:,:), allocatable     :: da2p      ! implicit interaction contribution of second quadruplet, current bin +1 (unfolded space)
     real, dimension(:,:,:), allocatable   :: disc0     ! explicit part of dissipation in present vertex for output purposes
     real, dimension(:,:,:), allocatable   :: disc1     ! implicit part of dissipation in present vertex for output purposes
+    real, dimension(:), allocatable       :: dkdx      ! derivative of wave number in x-direction
+    real, dimension(:), allocatable       :: dkdy      ! derivative of wave number in y-direction
     real, dimension(:,:), allocatable     :: dmw       ! mud dissipation rate
     real, dimension(:,:), allocatable     :: dsnl      ! total interaction contribution of quadruplets to the main diagonal matrix
     real, dimension(:,:,:), allocatable   :: genc0     ! explicit part of generation in present vertex for output purposes
@@ -354,6 +360,7 @@
     !$omp private(ivert, nupdv, jc, k, j, icell, v, vu, l, swpnr, rdx, rdy, lpredt, vb, ve, iface, link, inocnt) &
     !$omp private(iddlow, iddtop, idtot, isslow, isstop, istot) &
     !$omp private(abrbot, kmespc, idwmin, idwmax, hs, etot, qbloc, ufric, fpm, thetaw, hm, wind10, smebrk) &
+    !$omp private(dhdx, dhdy, dkdx, dkdy) &
     !$omp copyin(ICMAX, COSLAT, IPTST, TESTFL)
     !
     ! print number of threads set by environment
@@ -406,6 +413,9 @@
     allocate( trac1(MDC,MSC,MTRNP))
     allocate(leakcf(MDC,MSC      ))
     !
+    allocate(dkdx(MSC))
+    allocate(dkdy(MSC))
+    !
     ! calculate ranges of spectral space for arrays related to 4 wave-wave interactions
     !
     !$omp single
@@ -684,6 +694,10 @@
                   enddo
                endif
                !
+               ! compute gradients of depth or wave number in present vertex meant for computing turning rate
+               !
+               call SwanGradDepthorK ( compda(1,JDP2), compda(1,JMUDL2), spcsig, dhdx, dhdy, dkdx, dkdy, ivert )
+               !
                nupdv = 0
                !
                celloop: do jc = 1, vert(ivert)%noc
@@ -785,10 +799,10 @@
 !TIMG                     call SWTSTA(113)
                      call SwanPropvelS ( cad             , cas           , compda(1,JVX2), compda(1,JVY2), &
                                          compda(1,JDP1)  , compda(1,JDP2), cax           , cay           , &
-                                         kwave           , cgo           , spcsig        , idcmin        , &
-                                         idcmax          , spcdir(1,2)   , spcdir(1,3)   , spcdir(1,4)   , &
+                                         kwave           , cgo           , spcsig        , iddlow        , &
+                                         iddtop          , spcdir(1,2)   , spcdir(1,3)   , spcdir(1,4)   , &
                                          spcdir(1,5)     , spcdir(1,6)   , rdx           , rdy           , &
-                                         compda(1,JMUDL2), jc            )
+                                         dhdx            , dhdy          , dkdx          , dkdy          )
 !TIMG                     call SWTSTO(113)
                      !
                      ! estimate action density in case of first iteration at cold start in stationary mode
@@ -1303,6 +1317,9 @@
     deallocate( trac1)
     deallocate(leakcf)
     !
+    deallocate(dkdx)
+    deallocate(dkdy)
+    !
     deallocate(  ue)
     deallocate( sa1)
     deallocate( sa2)
--- swan.edt	2015-02-04 11:52:57.000000000 +0100
+++ swan.edt	2015-11-27 11:35:10.864469710 +0100
@@ -174,7 +174,7 @@
 !                   <                            >  [limiter]   )           &
 !                    | NONSTat  [mxitns]        |
 !
-!           ( DIRimpl [cdd] [cdlim]  WNUMber                    )           &
+!           ( DIRimpl [cdd]  DEP|WNUM                           )           &
 !
 !           ( REFRLim [frlim] [power]                           )           &
 !
--- SwanGradDepthorK.ftn90	1970-01-01 01:00:00.000000000 +0100
+++ SwanGradDepthorK.ftn90	2015-11-27 11:35:14.132469803 +0100
@@ -0,0 +1,365 @@
+subroutine SwanGradDepthorK ( dep2, mudl2, spcsig, dhdx, dhdy, dkdx, dkdy, ivert )
+!
+!   --|-----------------------------------------------------------|--
+!     | Delft University of Technology                            |
+!     | Faculty of Civil Engineering and Geosciences              |
+!     | Environmental Fluid Mechanics Section                     |
+!     | P.O. Box 5048, 2600 GA  Delft, The Netherlands            |
+!     |                                                           |
+!     | Programmer: Marcel Zijlema                                |
+!   --|-----------------------------------------------------------|--
+!
+!
+!     SWAN (Simulating WAves Nearshore); a third generation wave model
+!     Copyright (C) 1993-2015  Delft University of Technology
+!
+!     This program is free software; you can redistribute it and/or
+!     modify it under the terms of the GNU General Public License as
+!     published by the Free Software Foundation; either version 2 of
+!     the License, or (at your option) any later version.
+!
+!     This program is distributed in the hope that it will be useful,
+!     but WITHOUT ANY WARRANTY; without even the implied warranty of
+!     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
+!     GNU General Public License for more details.
+!
+!     A copy of the GNU General Public License is available at
+!     http://www.gnu.org/copyleft/gpl.html#SEC3
+!     or by writing to the Free Software Foundation, Inc.,
+!     59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
+!
+!
+!   Authors
+!
+!   41.60: Marcel Zijlema
+!
+!   Updates
+!
+!   41.60, July 2015: New subroutine
+!
+!   Purpose
+!
+!   Computes gradients of depth or wave number in vertex
+!   meant for computing turning rate
+!
+!   Method
+!
+!   Application of the Green-Gauss theorem with the assumption of
+!   a constant gradient over the controle volume (centroid dual)
+!
+!   Modules used
+!
+    use ocpcomm4
+    use swcomm2
+    use swcomm3
+    use swcomm4
+    use SwanGriddata
+    use SwanGridobjects
+!
+    implicit none
+!
+!   Argument variables
+!
+    integer                , intent(in)   :: ivert  ! counter corresponding to current vertex
+    !
+    real, dimension(nverts), intent(in)   :: dep2   ! water depth at current time level
+    real                   , intent(out)  :: dhdx   ! derivative of depth in x-direction
+    real                   , intent(out)  :: dhdy   ! derivative of depth in y-direction
+    real, dimension(MSC)   , intent(out)  :: dkdx   ! derivative of wave number in x-direction
+    real, dimension(MSC)   , intent(out)  :: dkdy   ! derivative of wave number in y-direction
+    real, dimension(nverts), intent(in)   :: mudl2  ! mud layer at current time level
+    real, dimension(MSC)   , intent(in)   :: spcsig ! relative frequency bins
+!
+!   Local variables
+!
+    integer                               :: icell    ! index of present cell
+    integer, save                         :: ient = 0 ! number of entries in this subroutine
+    integer                               :: jc       ! loop counter
+    integer                               :: jcell    ! index of next cell
+    !
+    integer, dimension(3)                 :: v        ! vertices in present cell
+    !
+    double precision                      :: area     ! twices the area of centroid dual around present vertex
+    real, dimension(MSC)                  :: arr      ! auxiliary array
+    real                                  :: cslat    ! cosine of latitude
+    real, dimension(3)                    :: dloc     ! local depth at vertices
+    real, dimension(3)                    :: dm       ! local mud layer at vertices
+    real                                  :: h0       ! depth in centroid of present cell
+    real                                  :: h1       ! depth in centroid of next cell
+    real, dimension(MSC)                  :: k0       ! wave number in centroid of present cell
+    real, dimension(MSC)                  :: k1       ! wave number in centroid of next cell
+    real, dimension(MSC,3)                :: kloc     ! local wave number at vertices
+    double precision                      :: x0       ! x-coordinate of the centroid of present cell
+    double precision                      :: x1       ! x-coordinate of the centroid of next cell
+    double precision                      :: y0       ! y-coordinate of the centroid of present cell
+    double precision                      :: y1       ! y-coordinate of the centroid of next cell
+    !
+    character(80)                         :: msgstr   ! string to pass message
+    !
+    type(celltype), dimension(:), pointer :: cell     ! datastructure for cells with their attributes
+    type(verttype), dimension(:), pointer :: vert     ! datastructure for vertices with their attributes
+!
+!   Structure
+!
+!   Description of the pseudo code
+!
+!   Source text
+!
+    if (ltrace) call strace (ient,'SwanGradDepthorK')
+    !
+    dhdx = 0.
+    dhdy = 0.
+    !
+    dkdx = 0.
+    dkdy = 0.
+    !
+    ! if no frequency shift and no refraction, return
+    !
+    if ( (ITFRE == 0 .or. ICUR == 0) .and. IREFR == 0 ) return
+    !
+    ! point to vertex and cell objects
+    !
+    vert => gridobject%vert_grid
+    cell => gridobject%cell_grid
+    !
+    if ( (IREFR /= 0 .and. int(PNUMS(32)) == 0) .or. (ITFRE /= 0 .and. ICUR /= 0) ) then
+       !
+       if ( vert(ivert)%atti(VMARKER) == 1 ) return    ! boundary vertex
+       !
+       area = 0d0
+       !
+       ! loop over cells around considered vertex
+       !
+       do jc = 1, vert(ivert)%noc
+          !
+          ! get present cell and its vertices
+          !
+          icell = vert(ivert)%cell(jc)%atti(CELLID)
+          !
+          v(1) = cell(icell)%atti(CELLV1)
+          v(2) = cell(icell)%atti(CELLV2)
+          v(3) = cell(icell)%atti(CELLV3)
+          !
+          dloc(1) = dep2(v(1))
+          dloc(2) = dep2(v(2))
+          dloc(3) = dep2(v(3))
+          !
+          if ( dloc(1) <= DEPMIN .or. dloc(2) <= DEPMIN .or. dloc(3) <= DEPMIN ) goto 10
+          !
+          ! determine centroid of present cell
+          !
+          x0 = cell(icell)%attr(CELLCX)
+          y0 = cell(icell)%attr(CELLCY)
+          !
+          ! determine depth in centroid in present cell
+          !
+          h0 = ( dloc(1) + dloc(2) + dloc(3) )/ 3.
+          !
+          ! get next cell in counterclockwise direction
+          !
+          jcell = vert(ivert)%cell(jc)%atti(NEXTCELL)
+          !
+          v(1) = cell(jcell)%atti(CELLV1)
+          v(2) = cell(jcell)%atti(CELLV2)
+          v(3) = cell(jcell)%atti(CELLV3)
+          !
+          dloc(1) = dep2(v(1))
+          dloc(2) = dep2(v(2))
+          dloc(3) = dep2(v(3))
+          !
+          if ( dloc(1) <= DEPMIN .or. dloc(2) <= DEPMIN .or. dloc(3) <= DEPMIN ) goto 10
+          !
+          ! determine centroid of next cell
+          !
+          x1 = cell(jcell)%attr(CELLCX)
+          y1 = cell(jcell)%attr(CELLCY)
+          !
+          ! determine depth in centroid of next cell
+          !
+          h1 = ( dloc(1) + dloc(2) + dloc(3) )/ 3.
+          !
+          ! compute contribution to area of centroid dual
+          !
+          area = area + x0*y1 - x1*y0
+          !
+          ! compute contribution to x-gradient of depth
+          !
+          dhdx = dhdx + ( h0 + h1 ) * real( y1 - y0 )
+          !
+          ! compute contribution to y-gradient of depth
+          !
+          dhdy = dhdy + ( h0 + h1 ) * real( x1 - x0 )
+          !
+       enddo
+       !
+       ! if area is non-positive, give error and go to next vertex
+       !
+       if ( .not. area > 0d0 ) then
+          write (msgstr, '(a,i5)') ' Area of centroid dual is negative or zero in vertex ', ivert
+          call msgerr( 2, trim(msgstr) )
+          return
+       endif
+       !
+       dhdx =  dhdx/real(area)
+       dhdy = -dhdy/real(area)
+       !
+       ! in case of spherical coordinates, transform back to Cartesian coordinates
+       !
+       if ( KSPHER > 0 ) then
+          !
+          cslat = cos(DEGRAD*(vert(ivert)%attr(VERTY) + YOFFS))
+          !
+          dhdx = dhdx/(cslat * LENDEG)
+          dhdy = dhdy/LENDEG
+          !
+       endif
+       !
+       return
+ 10    dhdx = 0.
+       dhdy = 0.
+       !
+    endif
+    !
+    if ( IREFR /= 0 .and. int(PNUMS(32)) == 1 ) then
+       !
+       if ( vert(ivert)%atti(VMARKER) == 1 ) return    ! boundary vertex
+       !
+       area = 0d0
+       !
+       ! loop over cells around considered vertex
+       !
+       do jc = 1, vert(ivert)%noc
+          !
+          ! get present cell and its vertices
+          !
+          icell = vert(ivert)%cell(jc)%atti(CELLID)
+          !
+          v(1) = cell(icell)%atti(CELLV1)
+          v(2) = cell(icell)%atti(CELLV2)
+          v(3) = cell(icell)%atti(CELLV3)
+          !
+          dloc(1) = dep2(v(1))
+          dloc(2) = dep2(v(2))
+          dloc(3) = dep2(v(3))
+          !
+          if ( dloc(1) <= DEPMIN .or. dloc(2) <= DEPMIN .or. dloc(3) <= DEPMIN ) goto 20
+          !
+          ! determine centroid of present cell
+          !
+          x0 = cell(icell)%attr(CELLCX)
+          y0 = cell(icell)%attr(CELLCY)
+          !
+          ! compute wave numbers for all frequencies
+          !
+          call KSCIP1 (MSC, spcsig, dloc(1), kloc(1,1), arr, arr, arr)
+          call KSCIP1 (MSC, spcsig, dloc(2), kloc(1,2), arr, arr, arr)
+          call KSCIP1 (MSC, spcsig, dloc(3), kloc(1,3), arr, arr, arr)
+          !
+          if ( IMUD == 1 ) then
+             !
+             if (VARMUD) then
+                dm(1) = mudl2(v(1))
+                dm(2) = mudl2(v(2))
+                dm(3) = mudl2(v(3))
+             else
+                dm(1) = PMUD(1)
+                dm(2) = PMUD(1)
+                dm(3) = PMUD(1)
+             endif
+             !
+             call KSCIP2 (MSC, spcsig, dloc(1), kloc(1,1), arr, arr, arr, arr, dm(1))
+             call KSCIP2 (MSC, spcsig, dloc(2), kloc(1,2), arr, arr, arr, arr, dm(2))
+             call KSCIP2 (MSC, spcsig, dloc(3), kloc(1,3), arr, arr, arr, arr, dm(3))
+             !
+          endif
+          !
+          ! determine wave number in centroid in present cell
+          !
+          k0(:) = ( kloc(:,1) + kloc(:,2) + kloc(:,3) )/ 3.
+          !
+          ! get next cell in counterclockwise direction
+          !
+          jcell = vert(ivert)%cell(jc)%atti(NEXTCELL)
+          !
+          v(1) = cell(jcell)%atti(CELLV1)
+          v(2) = cell(jcell)%atti(CELLV2)
+          v(3) = cell(jcell)%atti(CELLV3)
+          !
+          dloc(1) = dep2(v(1))
+          dloc(2) = dep2(v(2))
+          dloc(3) = dep2(v(3))
+          !
+          if ( dloc(1) <= DEPMIN .or. dloc(2) <= DEPMIN .or. dloc(3) <= DEPMIN ) goto 20
+          !
+          ! determine centroid of next cell
+          !
+          x1 = cell(jcell)%attr(CELLCX)
+          y1 = cell(jcell)%attr(CELLCY)
+          !
+          ! compute wave numbers for all frequencies
+          !
+          call KSCIP1 (MSC, spcsig, dloc(1), kloc(1,1), arr, arr, arr)
+          call KSCIP1 (MSC, spcsig, dloc(2), kloc(1,2), arr, arr, arr)
+          call KSCIP1 (MSC, spcsig, dloc(3), kloc(1,3), arr, arr, arr)
+          !
+          if ( IMUD == 1 ) then
+             !
+             if (VARMUD) then
+                dm(1) = mudl2(v(1))
+                dm(2) = mudl2(v(2))
+                dm(3) = mudl2(v(3))
+             endif
+             !
+             call KSCIP2 (MSC, spcsig, dloc(1), kloc(1,1), arr, arr, arr, arr, dm(1))
+             call KSCIP2 (MSC, spcsig, dloc(2), kloc(1,2), arr, arr, arr, arr, dm(2))
+             call KSCIP2 (MSC, spcsig, dloc(3), kloc(1,3), arr, arr, arr, arr, dm(3))
+             !
+          endif
+          !
+          ! determine wave number in centroid of next cell
+          !
+          k1(:) = ( kloc(:,1) + kloc(:,2) + kloc(:,3) )/ 3.
+          !
+          ! compute contribution to area of centroid dual
+          !
+          area = area + x0*y1 - x1*y0
+          !
+          ! compute contribution to x-gradient of wave number
+          !
+          dkdx(:) = dkdx(:) + ( k0(:) + k1(:) ) * real( y1 - y0 )
+          !
+          ! compute contribution to y-gradient of wave number
+          !
+          dkdy(:) = dkdy(:) + ( k0(:) + k1(:) ) * real( x1 - x0 )
+          !
+       enddo
+       !
+       ! if area is non-positive, give error and go to next vertex
+       !
+       if ( .not. area > 0d0 ) then
+          write (msgstr, '(a,i5)') ' Area of centroid dual is negative or zero in vertex ', ivert
+          call msgerr( 2, trim(msgstr) )
+          return
+       endif
+       !
+       dkdx(:) =  dkdx(:)/real(area)
+       dkdy(:) = -dkdy(:)/real(area)
+       !
+       ! in case of spherical coordinates, transform back to Cartesian coordinates
+       !
+       if ( KSPHER > 0 ) then
+          !
+          cslat = cos(DEGRAD*(vert(ivert)%attr(VERTY) + YOFFS))
+          !
+          dkdx(:) = dkdx(:)/(cslat * LENDEG)
+          dkdy(:) = dkdy(:)/LENDEG
+          !
+       endif
+       !
+       return
+ 20    dkdx = 0.
+       dkdy = 0.
+       !
+    endif
+    !
+end subroutine SwanGradDepthorK
--- swanmain.ftn	2015-02-04 11:52:57.000000000 +0100
+++ swanmain.ftn	2015-11-27 11:35:18.356469930 +0100
@@ -26,7 +26,7 @@
 !
 !***********************************************************************
 !                                                                      *
-!NADC      PROGRAM SWAN
+!NADC!NCOH      PROGRAM SWAN
 !ADC      SUBROUTINE SWAN
 !                                                                      *
 !***********************************************************************
@@ -949,6 +949,7 @@
       VERNUM = 41.01
       WRITE (VERTXT, '(F5.2)') VERNUM                                     40.03
       CALL BUGFIX ('A')
+      CALL BUGFIX ('B')
 !
       CALL OCPINI ('swaninit', .TRUE.,INERR)                              34.01
       IF (INERR.GT.0) RETURN                                              34.01
@@ -1059,7 +1060,7 @@
       asort  = -999.                                                      41.48
       CCURV  = .FALSE.                                                    41.53
 !     number of points needed in computational stencil:
-      ICMAX  = 3
+      ICMAX  = 5
 !     ***** numerical scheme *****
       NCOR   = 1
       NSTATM = -1                                                         40.00
@@ -1282,7 +1283,7 @@
 !
 !     --- computation of Ctheta based on wave number
 !
-      PNUMS(32) = 0.                                                      41.07
+      PNUMS(32) = 1.                                                      41.07
 !
 !     --- parameters for limiting Csigma and Ctheta
 !
@@ -4845,6 +4846,13 @@
 !     used in the CGRID command. This error should be corrected
 !     in the future
 !
+      IF (ICUR.NE.0 .AND. (IQUAD.EQ.1 .OR. IQUAD.EQ.2)) THEN              41.55
+         CALL MSGERR(1,'Quadruplets will be updated per iteration')       41.55
+         CALL MSGERR(1,'instead of per sweep. This will increase')        41.55
+         CALL MSGERR(1,'amount of internal memory with a factor 2')       41.55
+         IQUAD = 3                                                        41.55
+      ENDIF                                                               41.55
+!
       IF (IWIND.EQ.3 .OR. IWIND.EQ.4
      &                              ) THEN                                30.60
         IF (IQUAD .EQ. 0) THEN
@@ -7276,6 +7284,7 @@
 !****************************************************************
 !
       USE M_WCAP
+      USE M_SNL4
       USE M_GENARR
       USE M_PARALL
       USE M_DIFFR
@@ -7339,6 +7348,9 @@
 ! 13. Source text
 !
       IF (ALLOCATED(SIGPOW))   DEALLOCATE(SIGPOW)
+      IF (ALLOCATED(CNL4_1))   DEALLOCATE(CNL4_1)
+      IF (ALLOCATED(CNL4_2))   DEALLOCATE(CNL4_2)
+      IF (ALLOCATED(LAMBDA))   DEALLOCATE(LAMBDA)
       IF (ALLOCATED(KGRPNT))   DEALLOCATE(KGRPNT)
       IF (ALLOCATED(KGRBND))   DEALLOCATE(KGRBND)
       IF (ALLOCATED(XYTST ))   DEALLOCATE(XYTST )
--- swanout1.ftn	2015-02-04 11:52:57.000000000 +0100
+++ swanout1.ftn	2015-11-27 11:35:18.360469930 +0100
@@ -356,6 +356,7 @@
         CALL SWOEXD (OQPROC, MIP, VOQ(1+2*MIP),                           40.31 30.90
      &               VOQ(1+3*MIP), VOQR, VOQ(1),                          40.31 30.90
      &               COMPDA, KGRPNT, FORCE, CROSS, IONOD                  40.86 40.80 40.31
+!NPUN!ADC     &               ,IRQ                                                 41.36
 !PUN     &               ,IRQ                                                 41.36
      &              )
 !PUN        IF (STPNOW()) RETURN
@@ -1389,6 +1390,7 @@
 !                                                                      *
       SUBROUTINE SWOEXD (OQPROC, MIP, XC, YC, VOQR, VOQ, COMPDA ,KGRPNT,  30.21
      &                   FORCE, CROSS, IONOD                              40.86 40.80 40.31
+!NPUN!ADC     &                   ,IRQ                                             41.36
 !PUN     &                   ,IRQ                                             41.36
      &                  )
 !                                                                      *
@@ -1515,6 +1517,7 @@
       REAL       FORCE(nverts,2)                                          40.80
       INTEGER    VOQR(*), KGRPNT(MXC,MYC)
       INTEGER    IONOD(*)                                                 40.31
+!NPUN!ADC      INTEGER    IRQ                                                      41.36
 !PUN      INTEGER    IRQ                                                      41.36
 !PUN      INTEGER    IVERTP, NOWNV
 !PUN      INTEGER    NREF, IOSTAT
--- swanout2.ftn	2015-02-04 11:52:57.000000000 +0100
+++ swanout2.ftn	2015-11-27 11:35:18.364469930 +0100
@@ -260,7 +260,7 @@
      &                    VOQ(1,VOQR(IVTYPE)), NREF, IREC(IRQ),           40.51
      &                    IDLA, OVEXCV(IVTYPE) )
 !NCF          ELSE IF (NCF) THEN                                              41.40
-!NCF             IF ( IVTYPE.GT.3 ) THEN
+!NCF             IF (IVTYPE.GT.2.AND.IVTYPE.NE.40) THEN
 !NCF                CALL swn_outnc_appendblock(MYK, MXK, IVTYPE, OQI(1),
 !NCF     &                                     IRQ, VOQ(1,VOQR(IVTYPE)),
 !NCF     &                                     OVEXCV(IVTYPE), 1)
@@ -1067,7 +1067,7 @@
 !NCF      IF (RTYPE.EQ.'TABC') THEN
 !NCF        DO JVAR = 1, NVAR
 !NCF          IVTYPE = IVTYP(JVAR)
-!NCF          IF (RTYPE.EQ.'TABC') THEN
+!NCF          IF (IVTYPE.GT.3.AND.IVTYPE.NE.40) THEN
 !NCF            CALL swn_outnc_appendblock(1, MIP, IVTYPE, OQI(1),
 !NCF     &                                 OQI(2), VOQ(1,VOQR(IVTYPE)),
 !NCF     &                                 OVEXCV(IVTYPE), 1)
--- swanparll.ftn	2015-02-04 11:52:57.000000000 +0100
+++ swanparll.ftn	2015-11-27 11:35:18.368469930 +0100
@@ -137,7 +137,7 @@
 
 !MPI!     --- enroll in MPI
 !MPI
-!MPI      CALL MPI_INIT ( IERR )
+!MPI!NCOH      CALL MPI_INIT ( IERR )
 !MPI      IF ( IERR.NE.MPI_SUCCESS ) THEN
 !MPI         CHARS(1) = INTSTR(IERR)
 !MPI         CALL TXPBLA(CHARS(1),IF1,IL1)
@@ -154,7 +154,7 @@
 
 !MPI!     --- get node number INODE
 !MPI
-!MPI      CALL MPI_COMM_RANK ( MPI_COMM_WORLD, INODE, IERR )
+!MPI!NCOH      CALL MPI_COMM_RANK ( MPI_COMM_WORLD, INODE, IERR )
       INODE = INODE + 1
 !MPI      IF ( IERR.NE.MPI_SUCCESS ) THEN
 !MPI         CHARS(1) = INTSTR(IERR)
@@ -170,7 +170,7 @@
 !MPI
 !MPI!     --- determine total number of processes
 !MPI
-!MPI      CALL MPI_COMM_SIZE ( MPI_COMM_WORLD, NPROC, IERR )
+!MPI!NCOH      CALL MPI_COMM_SIZE ( MPI_COMM_WORLD, NPROC, IERR )
 !MPI      IF ( IERR.NE.MPI_SUCCESS ) THEN
 !MPI         CHARS(1) = INTSTR(IERR)
 !MPI         CALL TXPBLA(CHARS(1),IF1,IL1)
@@ -305,19 +305,19 @@
 !MPI      CALL MPI_INITIALIZED ( PARALMPI, IERR )
 !MPI      IF ( PARALMPI ) THEN
 !MPI
-!MPI         CALL MPI_BARRIER ( MPI_COMM_WORLD, IERR )
+!MPI!NCOH         CALL MPI_BARRIER ( MPI_COMM_WORLD, IERR )
 !MPI
 !MPI         IF ( LEVERR.GE.4 ) THEN
 !MPI
 !MPI!        --- in case of a severe error abort all MPI processes
 !MPI
-!MPI            CALL MPI_ABORT ( MPI_COMM_WORLD, LEVERR, IERR )
+!MPI!NCOH            CALL MPI_ABORT ( MPI_COMM_WORLD, LEVERR, IERR )
 !MPI
 !MPI         ELSE
 !MPI
 !MPI!        --- otherwise stop MPI operations on this computer
 !MPI
-!MPI            CALL MPI_FINALIZE ( IERR )
+!MPI!NCOH            CALL MPI_FINALIZE ( IERR )
 !MPI
 !MPI         END IF
 !MPI
@@ -437,7 +437,7 @@
 
 !MPI!     --- blocks until all nodes have called this routine
 !MPI
-!MPI      CALL MPI_BARRIER ( MPI_COMM_WORLD, IERR )
+!MPI!NCOH      CALL MPI_BARRIER ( MPI_COMM_WORLD, IERR )
 !MPI      IF ( IERR.NE.MPI_SUCCESS ) THEN
 !MPI         CHARS(1) = INTSTR(IERR)
 !MPI         CALL TXPBLA(CHARS(1),IF1,IL1)
@@ -571,8 +571,8 @@
 !     --- if not parallel, return
       IF (.NOT.PARLL) RETURN
 
-!MPI      CALL MPI_SEND ( IPTR, ILEN, ITYPE, IDEST-1,
-!MPI     &                ITAG, MPI_COMM_WORLD, IERR )
+!MPI!NCOH      CALL MPI_SEND ( IPTR, ILEN, ITYPE, IDEST-1,
+!MPI!NCOH     &                ITAG, MPI_COMM_WORLD, IERR )
 !MPI      IF ( IERR.NE.MPI_SUCCESS ) THEN
 !MPI         CHARS(1) = INTSTR(IERR)
 !MPI         CALL TXPBLA(CHARS(1),IF1,IL1)
@@ -712,8 +712,8 @@
 !     --- if not parallel, return
       IF (.NOT.PARLL) RETURN
 
-!MPI      CALL MPI_RECV ( IPTR, ILEN, ITYPE, ISOURCE-1, ITAG,
-!MPI     &                MPI_COMM_WORLD, ISTAT, IERR )
+!MPI!NCOH      CALL MPI_RECV ( IPTR, ILEN, ITYPE, ISOURCE-1, ITAG,
+!MPI!NCOH     &                MPI_COMM_WORLD, ISTAT, IERR )
 !MPI      IF ( IERR.NE.MPI_SUCCESS ) THEN
 !MPI         CHARS(1) = INTSTR(IERR)
 !MPI         CALL TXPBLA(CHARS(1),IF1,IL1)
@@ -848,8 +848,8 @@
       IF (.NOT.PARLL) RETURN
 
 !TIMG      CALL SWTSTA(201)
-!MPI      CALL MPI_BCAST ( IPTR, ILEN, ITYPE, MASTER-1,
-!MPI     &                 MPI_COMM_WORLD, IERR )
+!MPI!NCOH      CALL MPI_BCAST ( IPTR, ILEN, ITYPE, MASTER-1,
+!MPI!NCOH     &                 MPI_COMM_WORLD, IERR )
 !MPI      IF ( IERR.NE.MPI_SUCCESS ) THEN
 !MPI         CHARS = INTSTR(IERR)
 !MPI         CALL TXPBLA(CHARS,IF,IL)
@@ -1004,8 +1004,8 @@
 
 !MPI!     --- gather the array sizes to the master
 !MPI
-!MPI      CALL MPI_GATHER( IILEN, 1, SWINT, ICOUNT, 1, SWINT,
-!MPI     &                 MASTER-1, MPI_COMM_WORLD, IERR )
+!MPI!NCOH      CALL MPI_GATHER( IILEN, 1, SWINT, ICOUNT, 1, SWINT,
+!MPI!NCOH     &                 MASTER-1, MPI_COMM_WORLD, IERR )
 !MPI      IF ( IERR.NE.MPI_SUCCESS ) THEN
 !MPI         CHARS = INTSTR(IERR)
 !MPI         CALL TXPBLA(CHARS,IF,IL)
@@ -1039,8 +1039,8 @@
 !MPI!     --- gather different amounts of data from each processor
 !MPI!         to the master
 !MPI
-!MPI      CALL MPI_GATHERV( IIPTR, IILEN, ITYPE, IOPTR, ICOUNT, IDSPLC,
-!MPI     &                  ITYPE, MASTER-1, MPI_COMM_WORLD, IERR )
+!MPI!NCOH      CALL MPI_GATHERV( IIPTR, IILEN, ITYPE, IOPTR, ICOUNT, IDSPLC,
+!MPI!NCOH     &                  ITYPE, MASTER-1, MPI_COMM_WORLD, IERR )
 !MPI      IF ( IERR.NE.MPI_SUCCESS ) THEN
 !MPI         CHARS = INTSTR(IERR)
 !MPI         CALL TXPBLA(CHARS,IF,IL)
@@ -1291,8 +1291,8 @@
       ALLOCATE(ITEMP(ILEN))
 
 !TIMG      CALL SWTSTA(202)
-!MPI      CALL MPI_ALLREDUCE ( IARR, ITEMP, ILEN, SWINT,
-!MPI     &                     ITYPRD, MPI_COMM_WORLD, IERR )
+!MPI!NCOH      CALL MPI_ALLREDUCE ( IARR, ITEMP, ILEN, SWINT,
+!MPI!NCOH     &                     ITYPRD, MPI_COMM_WORLD, IERR )
 !MPI      IF ( IERR.NE.MPI_SUCCESS ) THEN
 !MPI         CHARS = INTSTR(IERR)
 !MPI         CALL TXPBLA(CHARS,IF,IL)
@@ -1429,8 +1429,8 @@
       ALLOCATE(TEMP(ILEN))
 
 !TIMG      CALL SWTSTA(202)
-!MPI      CALL MPI_ALLREDUCE ( ARR, TEMP, ILEN, SWREAL,
-!MPI     &                     ITYPRD, MPI_COMM_WORLD, IERR )
+!MPI!NCOH      CALL MPI_ALLREDUCE ( ARR, TEMP, ILEN, SWREAL,
+!MPI!NCOH     &                     ITYPRD, MPI_COMM_WORLD, IERR )
 !MPI      IF ( IERR.NE.MPI_SUCCESS ) THEN
 !MPI         CHARS = INTSTR(IERR)
 !MPI         CALL TXPBLA(CHARS,IF,IL)
@@ -4664,7 +4664,7 @@
                CALL SWRMAT( MYK, MXK, NAMVAR, VOQ(1,1), NREF,
      &                      IREC(IRQ), IDLA, OVEXCV(IVTYPE) )             40.51
 !NCF            ELSE IF (NCF) THEN                                            41.40
-!NCF               IF ( IVTYPE.GT.3 ) THEN
+!NCF               IF ( IVTYPE.GT.2.AND.IVTYPE.NE.40 ) THEN
 !NCF                  CALL swn_outnc_appendblock(MYK, MXK, IVTYPE, OQI(1),
 !NCF     &                                       IRQ, VOQ(1,1),
 !NCF     &                                       OVEXCV(IVTYPE), 1)
--- swanpre1.ftn	2015-02-04 11:52:57.000000000 +0100
+++ swanpre1.ftn	2015-11-27 11:35:18.372469929 +0100
@@ -750,7 +750,7 @@
 !
       IF (KEYWIS ('PROP')) THEN                                           40.02
         CALL INKEYW ('STA','    ')                                        40.02
-        IF (KEYWIS ('BSBT')) THEN                                         40.02
+        IF (KEYWIS ('BSBT') .OR. KEYWIS ('BTBS')) THEN                    40.02
           PROPSN = 1                                                      40.02
           PROPSS = 1                                                      40.02
         ELSE IF (KEYWIS ('GSE')) THEN                                     40.02
@@ -1659,7 +1659,7 @@
 !                   <                            >  [limiter]   )     &   40.03
 !                    | NONSTat  [mxitns]        |
 !
-!           ( DIRimpl [cdd] [cdlim]  WNUMber                       )  &
+!           ( DIRimpl [cdd] [cdlim]  DEP|WNUM                      )  &
 !
 !           ( REFRLim [frlim] [power]          (NOT documented)    )  &   41.06
 !
@@ -1728,13 +1728,16 @@
           CALL INREAL ('CDD'    , PNUMS(6) , 'UNC', 0.)
           CALL INREAL ('CDLIM'  , PNUMS(17), 'UNC', 0.)                   30.80
           IF (PNUMS(17).LT.0.) IREFR = 1                                  30.80
-          IF (PNUMS(17).GT.0.) IREFR = -1                                 40.02
           IF (EQREAL(PNUMS(17),0.)) THEN                                  30.80
             IREFR = 0                                                     30.80
             CALL MSGERR(0, 'Refraction deactivated')                      40.02
           ENDIF
-          CALL INKEYW ('STA','    ')                                      41.07
-          IF (KEYWIS ('WNUM')) PNUMS(32) = 1.                             41.07
+          CALL INKEYW ('STA', 'WNUM')                                     41.56
+          IF (KEYWIS('DEP')) THEN
+             PNUMS(32) = 0.                                               41.56
+          ELSE IF (KEYWIS('WNUM')) THEN
+             PNUMS(32) = 1.                                               41.07
+          ENDIF
         ENDIF
 !
 !       limit Ctheta if user want so                                      41.06
--- swanpre2.ftn	2015-02-04 11:52:57.000000000 +0100
+++ swanpre2.ftn	2015-11-27 11:35:18.376469930 +0100
@@ -1469,10 +1469,10 @@
         IF (IVTYPE .NE. 99) THEN
 !NCF           IF ( INDEX(FILENM,'.NC').NE.0  .OR.                            41.52
 !NCF     &          INDEX(FILENM,'.nc').NE.0 ) THEN                           41.52
-!NCF              IF ( IVTYPE.GT.2 ) THEN                                     41.52
+!NCF              IF ( IVTYPE.GT.2.AND.IVTYPE.NE.40 ) THEN                    41.52
 !NCF                 call stnames_init()                                      41.52
 !NCF                 IF ( STNAMES(IVTYPE,1).EQ. ' ' ) CALL MSGERR (2,         41.52
-!NCF     &                   'netCDF output not allowed for '//TRIM(FILENM))  41.52
+!NCF     &                 'netCDF table does not support '//OVKEYW(IVTYPE))  41.52
 !NCF              ENDIF                                                       41.52
 !NCF           ENDIF                                                          41.52
           IF (OVSVTY(IVTYPE).EQ.5) THEN
--- SwanPropvelS.ftn90	2015-02-04 11:52:57.000000000 +0100
+++ SwanPropvelS.ftn90	2015-11-27 11:35:16.348469870 +0100
@@ -1,9 +1,9 @@
 subroutine SwanPropvelS ( cad   , cas   , ux2   , uy2   , &
                           dep1  , dep2  , cax   , cay   , &
-                          kwave , cgo   , spcsig, idcmin, &
-                          idcmax, ecos  , esin  , coscos, &
+                          kwave , cgo   , spcsig, iddlow, &
+                          iddtop, ecos  , esin  , coscos, &
                           sincos, sinsin, rdx   , rdy   , &
-                          mudl2 , jc    )
+                          dhdx  , dhdy  , dkdx  , dkdy  )
 !
 !   --|-----------------------------------------------------------|--
 !     | Delft University of Technology                            |
@@ -42,6 +42,7 @@
 !   41.06: Gerbrant van Vledder
 !   41.07: Marcel Zijlema
 !   41.35: Casey Dietrich
+!   41.60: Marcel Zijlema
 !
 !   Updates
 !
@@ -54,6 +55,7 @@
 !                         (x,y)-derivatives of the wave number
 !                         (see Holthuijsen (2007), page 210, footnote 4)
 !   41.35,    March 2012: add option of limitation on csigma and ctheta
+!   41.60,     July 2015: more accurate computation of gradients of depth or wave number for turning rate
 !
 !   Purpose
 !
@@ -74,10 +76,8 @@
 !
 !   Argument variables
 !
-    integer, intent(in)                        :: jc     ! counter corresponding to current cell
-    !
-    integer, dimension(MSC), intent(in)        :: idcmax ! maximum frequency-dependent counter in directional space
-    integer, dimension(MSC), intent(in)        :: idcmin ! minimum frequency-dependent counter in directional space
+    integer, intent(in)                        :: iddlow ! minimum direction bin that is propagated within a sweep
+    integer, intent(in)                        :: iddtop ! maximum direction bin that is propagated within a sweep
     !
     real, dimension(MDC,MSC), intent(out)      :: cad    ! wave transport velocity in theta-direction
     real, dimension(MDC,MSC), intent(out)      :: cas    ! wave transport velocity in sigma-direction
@@ -87,10 +87,13 @@
     real, dimension(MDC), intent(in)           :: coscos ! help array containing cosine to power 2 of spectral directions
     real, dimension(nverts), intent(in)        :: dep1   ! water depth at previous time level
     real, dimension(nverts), intent(in)        :: dep2   ! water depth at current time level
+    real, intent(in)                           :: dhdx   ! derivative of depth in x-direction
+    real, intent(in)                           :: dhdy   ! derivative of depth in y-direction
+    real, dimension(MSC), intent(in)           :: dkdx   ! derivative of wave number in x-direction
+    real, dimension(MSC), intent(in)           :: dkdy   ! derivative of wave number in y-direction
     real, dimension(MDC), intent(in)           :: ecos   ! help array containing cosine of spectral directions
     real, dimension(MDC), intent(in)           :: esin   ! help array containing sine of spectral directions
     real, dimension(MSC,ICMAX), intent(in)     :: kwave  ! wave number
-    real, dimension(nverts), intent(in)        :: mudl2  ! mud layer at current time level
     real, dimension(MDC), intent(in)           :: sincos ! help array containing sine * cosine of spectral directions
     real, dimension(MDC), intent(in)           :: sinsin ! help array containing sine to power 2 of spectral directions
     real, dimension(nverts), intent(in)        :: ux2    ! ambient velocity in x-direction at current time level
@@ -103,56 +106,26 @@
 !
     integer                               :: icell    ! cell index
     integer                               :: id       ! loop counter over direction bins
-    integer                               :: iddum    ! counter in directional space for considered sweep
+    integer                               :: iddum    ! counter in directional space
     integer, save                         :: ient = 0 ! number of entries in this subroutine
     integer                               :: is       ! loop counter over frequency bins
     integer                               :: iv1      ! first index in computational stencil
     integer                               :: iv2      ! second index in computational stencil
     integer                               :: iv3      ! third index in computational stencil
-    integer                               :: jm       ! counter corresponding to cell below considered sweep
-    integer                               :: jp       ! counter corresponding to cell above considered sweep
-    integer                               :: k        ! loop counter
-    integer, dimension(3)                 :: v        ! vertices in considered cell
     !
     real                                  :: alpha    ! upper limit of CFL restriction
     real, dimension(3)                    :: cd       ! coefficients for computing cad
     real, dimension(10)                   :: cs       ! coefficients for computing cas
-    real                                  :: dhdx     ! derivative of dep2 to x in considered sweep
-    real                                  :: dhdxm    ! derivative of dep2 to x in sweep below considered sweep
-    real                                  :: dhdxp    ! derivative of dep2 to x in sweep above considered sweep
-    real                                  :: dhdy     ! derivative of dep2 to y in considered sweep
-    real                                  :: dhdym    ! derivative of dep2 to y in sweep below considered sweep
-    real                                  :: dhdyp    ! derivative of dep2 to y in sweep above considered sweep
     real, dimension(3)                    :: dloc     ! local depth at vertices
-    real, dimension(3)                    :: dm       ! local mud layer at vertices
-    real                                  :: duxdx    ! derivative of ux2 to x in considered sweep
-    real                                  :: duxdxm   ! derivative of ux2 to x in sweep below considered sweep
-    real                                  :: duxdxp   ! derivative of ux2 to x in sweep above considered sweep
-    real                                  :: duxdy    ! derivative of ux2 to y in considered sweep
-    real                                  :: duxdym   ! derivative of ux2 to y in sweep below considered sweep
-    real                                  :: duxdyp   ! derivative of ux2 to y in sweep above considered sweep
-    real                                  :: duydx    ! derivative of uy2 to x in considered sweep
-    real                                  :: duydxm   ! derivative of uy2 to x in sweep below considered sweep
-    real                                  :: duydxp   ! derivative of uy2 to x in sweep above considered sweep
-    real                                  :: duydy    ! derivative of uy2 to y in considered sweep
-    real                                  :: duydym   ! derivative of uy2 to y in sweep below considered sweep
-    real                                  :: duydyp   ! derivative of uy2 to y in sweep above considered sweep
+    real                                  :: duxdx    ! derivative of ux2 to x
+    real                                  :: duxdy    ! derivative of ux2 to y
+    real                                  :: duydx    ! derivative of uy2 to x
+    real                                  :: duydy    ! derivative of uy2 to y
     real                                  :: fac      ! a factor
     real                                  :: fac2     ! another factor
     real                                  :: frlim    ! frequency range in which limit on velocity in theta-direction is applied
     real                                  :: kd       ! help variable, wave number times water depth
     real                                  :: pp       ! power of the frequency dependent limiter on refraction
-    real, dimension(2)                    :: rdxl     ! first component of local contravariant base vector rdx(b) = a^(b)_1
-    real, dimension(2)                    :: rdyl     ! second component of local contravariant base vector rdy(b) = a^(b)_2
-    !
-    real, dimension(MSC)                  :: arr      ! auxiliary array
-    real, dimension(MSC)                  :: dkdx     ! derivative of wave number to x in considered sweep
-    real, dimension(MSC)                  :: dkdxm    ! derivative of wave number to x in sweep below considered sweep
-    real, dimension(MSC)                  :: dkdxp    ! derivative of wave number to x in sweep above considered sweep
-    real, dimension(MSC)                  :: dkdy     ! derivative of wave number to y in considered sweep
-    real, dimension(MSC)                  :: dkdym    ! derivative of wave number to y in sweep below considered sweep
-    real, dimension(MSC)                  :: dkdyp    ! derivative of wave number to y in sweep above considered sweep
-    real, dimension(MSC,3)                :: kloc     ! local wave number
     !
     type(celltype), dimension(:), pointer :: cell     ! datastructure for cells with their attributes
     type(verttype), dimension(:), pointer :: vert     ! datastructure for vertices with their attributes
@@ -196,25 +169,7 @@
     !
     if ( dloc(1) <= DEPMIN .or. dloc(2) <= DEPMIN .or. dloc(3) <= DEPMIN ) return
     !
-    ! compute the derivatives of the depth for the considered sweep
-    !
-    if ( IREFR /= 0 .or. ICUR /= 0 ) then
-       !
-       if ( IREFR == -1 ) then
-          !
-          ! limitation of depths in upwave vertices
-          !
-          dloc(2) = min( dep2(iv2), PNUMS(17)*dloc(1) )
-          dloc(3) = min( dep2(iv3), PNUMS(17)*dloc(1) )
-          !
-       endif
-       !
-       dhdx = rdx(1) * (dloc(1)-dloc(2)) + rdx(2) * (dloc(1)-dloc(3))
-       dhdy = rdy(1) * (dloc(1)-dloc(2)) + rdy(2) * (dloc(1)-dloc(3))
-       !
-    endif
-    !
-    ! compute the derivatives of the ambient current for the considered sweep
+    ! compute the derivatives of the ambient current
     !
     if ( ICUR /= 0 ) then
        !
@@ -225,268 +180,6 @@
        !
     endif
     !
-    ! compute the derivatives of the wave number for the considered sweep
-    !
-    if ( int(PNUMS(32)) == 1 ) then
-       !
-       ! compute wave numbers for all frequencies
-       !
-       call KSCIP1 (MSC, spcsig, dloc(1), kloc(1,1), arr, arr, arr)
-       call KSCIP1 (MSC, spcsig, dloc(2), kloc(1,2), arr, arr, arr)
-       call KSCIP1 (MSC, spcsig, dloc(3), kloc(1,3), arr, arr, arr)
-       !
-       if ( IMUD == 1 ) then
-          !
-          if (VARMUD) then
-             dm(1) = mudl2(iv1)
-             dm(2) = mudl2(iv2)
-             dm(3) = mudl2(iv3)
-          else
-             dm(1) = PMUD(1)
-             dm(2) = PMUD(1)
-             dm(3) = PMUD(1)
-          endif
-          !
-          call KSCIP2 (MSC, spcsig, dloc(1), kloc(1,1), arr, arr, arr, arr, dm(1))
-          call KSCIP2 (MSC, spcsig, dloc(2), kloc(1,2), arr, arr, arr, arr, dm(2))
-          call KSCIP2 (MSC, spcsig, dloc(3), kloc(1,3), arr, arr, arr, arr, dm(3))
-          !
-       endif
-       !
-       dkdx(:) = rdx(1) * (kloc(:,1)-kloc(:,2)) + rdx(2) * (kloc(:,1)-kloc(:,3))
-       dkdy(:) = rdy(1) * (kloc(:,1)-kloc(:,2)) + rdy(2) * (kloc(:,1)-kloc(:,3))
-       !
-    endif
-    !
-    ! compute extra derivatives of depth, wave number and current belonging to neighbouring sweeps meant for refraction
-    !
-    if ( IREFR /= 0 ) then
-       !
-       if ( int(PNUMS(32)) == 0 ) then
-          !
-          dhdxm = dhdx
-          dhdym = dhdy
-          dhdxp = dhdx
-          dhdyp = dhdy
-          !
-       else
-          !
-          dkdxm = dkdx
-          dkdym = dkdy
-          dkdxp = dkdx
-          dkdyp = dkdy
-          !
-       endif
-       !
-       if ( ICUR /= 0 ) then
-          !
-          duxdxm = duxdx
-          duxdym = duxdy
-          duydxm = duydx
-          duydym = duydy
-          duxdxp = duxdx
-          duxdyp = duxdy
-          duydxp = duydx
-          duydyp = duydy
-          !
-       endif
-       !
-       jm=vert(iv1)%noc-mod(vert(iv1)%noc+1-jc,vert(iv1)%noc)        ! cell below considered sweep
-       !
-       icell = vert(iv1)%cell(jm)%atti(CELLID)
-       !
-       v(1) = cell(icell)%atti(CELLV1)
-       v(2) = cell(icell)%atti(CELLV2)
-       v(3) = cell(icell)%atti(CELLV3)
-       !
-       ! compute local contravariant base vectors at present vertex in cell below considered sweep
-       !
-       do k = 1, 3
-          if ( v(k) == iv1 ) then
-             !
-             rdxl(1) = cell(icell)%geom(k)%rdx1
-             rdxl(2) = cell(icell)%geom(k)%rdx2
-             rdyl(1) = cell(icell)%geom(k)%rdy1
-             rdyl(2) = cell(icell)%geom(k)%rdy2
-             !
-             iv2 = v(mod(k  ,3)+1)
-             iv3 = v(mod(k+1,3)+1)
-             !
-             exit
-          endif
-       enddo
-       !
-       if ( KSPHER > 0 ) then
-          do k = 1, 2
-             rdxl(k) = rdxl(k) / (COSLAT(1) * LENDEG)
-             rdyl(k) = rdyl(k) / LENDEG
-          enddo
-       endif
-       !
-       dloc(2) = dep2(iv2)
-       dloc(3) = dep2(iv3)
-       !
-       ! if at least one vertex is dry, skip and go to other cell
-       !
-       if ( dloc(2) <= DEPMIN .or. dloc(3) <= DEPMIN ) goto 10
-       !
-       if ( IREFR == -1 ) then
-          !
-          ! limitation of depths in upwave vertices
-          !
-          dloc(2) = min( dep2(iv2), PNUMS(17)*dloc(1) )
-          dloc(3) = min( dep2(iv3), PNUMS(17)*dloc(1) )
-          !
-       endif
-       !
-       if ( int(PNUMS(32)) == 0 ) then
-          !
-          ! compute the derivatives of the depth in cell below considered sweep
-          !
-          dhdxm = rdxl(1) * (dloc(1)-dloc(2)) + rdxl(2) * (dloc(1)-dloc(3))
-          dhdym = rdyl(1) * (dloc(1)-dloc(2)) + rdyl(2) * (dloc(1)-dloc(3))
-          !
-       else
-          !
-          ! compute wave numbers for all frequencies
-          !
-          call KSCIP1 (MSC, spcsig, dloc(2), kloc(1,2), arr, arr, arr)
-          call KSCIP1 (MSC, spcsig, dloc(3), kloc(1,3), arr, arr, arr)
-          !
-          if ( IMUD == 1 ) then
-             !
-             if (VARMUD) then
-                dm(2) = mudl2(iv2)
-                dm(3) = mudl2(iv3)
-             else
-                dm(2) = PMUD(1)
-                dm(3) = PMUD(1)
-             endif
-             !
-             call KSCIP2 (MSC, spcsig, dloc(2), kloc(1,2), arr, arr, arr, arr, dm(2))
-             call KSCIP2 (MSC, spcsig, dloc(3), kloc(1,3), arr, arr, arr, arr, dm(3))
-             !
-          endif
-          !
-          ! compute the derivatives of the wave number in cell below considered sweep
-          !
-          dkdxm(:) = rdxl(1) * (kloc(:,1)-kloc(:,2)) + rdxl(2) * (kloc(:,1)-kloc(:,3))
-          dkdym(:) = rdyl(1) * (kloc(:,1)-kloc(:,2)) + rdyl(2) * (kloc(:,1)-kloc(:,3))
-          !
-       endif
-       !
-       ! compute the derivatives of the ambient current in cell below considered sweep
-       !
-       if ( ICUR /= 0 ) then
-          !
-          duxdxm = rdxl(1) * (ux2(iv1) - ux2(iv2)) + rdxl(2) * (ux2(iv1) - ux2(iv3))
-          duxdym = rdyl(1) * (ux2(iv1) - ux2(iv2)) + rdyl(2) * (ux2(iv1) - ux2(iv3))
-          duydxm = rdxl(1) * (uy2(iv1) - uy2(iv2)) + rdxl(2) * (uy2(iv1) - uy2(iv3))
-          duydym = rdyl(1) * (uy2(iv1) - uy2(iv2)) + rdyl(2) * (uy2(iv1) - uy2(iv3))
-          !
-       endif
-       !
-  10   continue
-       !
-       jp = mod(jc,vert(iv1)%noc)+1                                  ! cell above considered sweep
-       !
-       icell = vert(iv1)%cell(jp)%atti(CELLID)
-       !
-       v(1) = cell(icell)%atti(CELLV1)
-       v(2) = cell(icell)%atti(CELLV2)
-       v(3) = cell(icell)%atti(CELLV3)
-       !
-       ! compute local contravariant base vectors at present vertex in cell above considered sweep
-       !
-       do k = 1, 3
-          if ( v(k) == iv1 ) then
-             !
-             rdxl(1) = cell(icell)%geom(k)%rdx1
-             rdxl(2) = cell(icell)%geom(k)%rdx2
-             rdyl(1) = cell(icell)%geom(k)%rdy1
-             rdyl(2) = cell(icell)%geom(k)%rdy2
-             !
-             iv2 = v(mod(k  ,3)+1)
-             iv3 = v(mod(k+1,3)+1)
-             !
-             exit
-          endif
-       enddo
-       !
-       if ( KSPHER > 0 ) then
-          do k = 1, 2
-             rdxl(k) = rdxl(k) / (COSLAT(1) * LENDEG)
-             rdyl(k) = rdyl(k) / LENDEG
-          enddo
-       endif
-       !
-       dloc(2) = dep2(iv2)
-       dloc(3) = dep2(iv3)
-       !
-       ! if at least one vertex is dry, skip
-       !
-       if ( dloc(2) <= DEPMIN .or. dloc(3) <= DEPMIN ) goto 20
-       !
-       if ( IREFR == -1 ) then
-          !
-          ! limitation of depths in upwave vertices
-          !
-          dloc(2) = min( dep2(iv2), PNUMS(17)*dloc(1) )
-          dloc(3) = min( dep2(iv3), PNUMS(17)*dloc(1) )
-          !
-       endif
-       !
-       if ( int(PNUMS(32)) == 0 ) then
-          !
-          ! compute the derivatives of the depth in cell above considered sweep
-          !
-          dhdxp = rdxl(1) * (dloc(1)-dloc(2)) + rdxl(2) * (dloc(1)-dloc(3))
-          dhdyp = rdyl(1) * (dloc(1)-dloc(2)) + rdyl(2) * (dloc(1)-dloc(3))
-          !
-       else
-          !
-          ! compute wave numbers for all frequencies
-          !
-          call KSCIP1 (MSC, spcsig, dloc(2), kloc(1,2), arr, arr, arr)
-          call KSCIP1 (MSC, spcsig, dloc(3), kloc(1,3), arr, arr, arr)
-          !
-          if ( IMUD == 1 ) then
-             !
-             if (VARMUD) then
-                dm(2) = mudl2(iv2)
-                dm(3) = mudl2(iv3)
-             else
-                dm(2) = PMUD(1)
-                dm(3) = PMUD(1)
-             endif
-             !
-             call KSCIP2 (MSC, spcsig, dloc(2), kloc(1,2), arr, arr, arr, arr, dm(2))
-             call KSCIP2 (MSC, spcsig, dloc(3), kloc(1,3), arr, arr, arr, arr, dm(3))
-             !
-          endif
-          !
-          ! compute the derivatives of the wave number in cell above considered sweep
-          !
-          dkdxp(:) = rdxl(1) * (kloc(:,1)-kloc(:,2)) + rdxl(2) * (kloc(:,1)-kloc(:,3))
-          dkdyp(:) = rdyl(1) * (kloc(:,1)-kloc(:,2)) + rdyl(2) * (kloc(:,1)-kloc(:,3))
-          !
-       endif
-       !
-       ! compute the derivatives of the ambient current in cell above considered sweep
-       !
-       if ( ICUR /= 0 ) then
-          !
-          duxdxp = rdxl(1) * (ux2(iv1) - ux2(iv2)) + rdxl(2) * (ux2(iv1) - ux2(iv3))
-          duxdyp = rdyl(1) * (ux2(iv1) - ux2(iv2)) + rdyl(2) * (ux2(iv1) - ux2(iv3))
-          duydxp = rdxl(1) * (uy2(iv1) - uy2(iv2)) + rdxl(2) * (uy2(iv1) - uy2(iv3))
-          duydyp = rdyl(1) * (uy2(iv1) - uy2(iv2)) + rdyl(2) * (uy2(iv1) - uy2(iv3))
-          !
-       endif
-       !
-  20   continue
-       !
-    endif
-    !
     ! compute wave transport velocity in sigma-direction
     !
     if ( ITFRE /= 0 .and. (DYNDEP .or. ICUR /= 0) ) then
@@ -520,7 +213,7 @@
           cs( 9) = cs(5) * (duxdy+duydx)
           cs(10) = cs(5) * duydy
           !
-          do iddum = idcmin(is), idcmax(is)
+          do iddum = iddlow-1, iddtop+1
              id = mod ( iddum - 1 + MDC , MDC ) + 1
              !
              cas(id,is) = cs(6)
@@ -539,7 +232,7 @@
              !
              fac2 = alpha * FRINTF * spcsig(is)
              !
-             do iddum = idcmin(is), idcmax(is)
+             do iddum = iddlow-1, iddtop+1
                 id = mod ( iddum - 1 + MDC , MDC ) + 1
                 !
                 fac = fac2 * ( abs((rdx(1)+rdx(2))*cax(id,is,1)) + abs((rdy(1)+rdy(2))*cay(id,is,1)) )
@@ -580,7 +273,7 @@
              !
           endif
           !
-          do iddum = idcmin(is), idcmax(is)
+          do iddum = iddlow-1, iddtop+1
              id = mod ( iddum - 1 + MDC , MDC ) + 1
              !
              cad(id,is) = esin(id)*cd(2) - ecos(id)*cd(3)
@@ -589,42 +282,6 @@
              !
           enddo
           !
-          if ( int(PNUMS(32)) == 0 ) then
-             !
-             cd(2) = cd(1) * dhdxm
-             cd(3) = cd(1) * dhdym
-             !
-          else
-             !
-             cd(2) = cd(1) * dkdxm(is)
-             cd(3) = cd(1) * dkdym(is)
-             !
-          endif
-          !
-          id = mod ( idcmin(is) - 2 + MDC , MDC ) + 1  ! this direction belongs to sweep below considered sweep
-          !
-          cad(id,is) = esin(id)*cd(2) - ecos(id)*cd(3)
-          if ( IDIFFR /= 0 ) cad(id,is) = cad(id,is)*DIFPARAM(iv1) - DIFPARDX(iv1)*cgo(is,1)*esin(id) + DIFPARDY(iv1)*cgo(is,1)*ecos(id)
-          if ( ICUR   /= 0 ) cad(id,is) = cad(id,is) + sincos(id)*(duxdxm-duydym) + sinsin(id)*duydxm - coscos(id)*duxdym
-          !
-          if ( int(PNUMS(32)) == 0 ) then
-             !
-             cd(2) = cd(1) * dhdxp
-             cd(3) = cd(1) * dhdyp
-             !
-          else
-             !
-             cd(2) = cd(1) * dkdxp(is)
-             cd(3) = cd(1) * dkdyp(is)
-             !
-          endif
-          !
-          id = mod ( idcmax(is) + MDC , MDC ) + 1      ! this direction belongs to sweep above considered sweep
-          !
-          cad(id,is) = esin(id)*cd(2) - ecos(id)*cd(3)
-          if ( IDIFFR /= 0 ) cad(id,is) = cad(id,is)*DIFPARAM(iv1) - DIFPARDX(iv1)*cgo(is,1)*esin(id) + DIFPARDY(iv1)*cgo(is,1)*ecos(id)
-          if ( ICUR   /= 0 ) cad(id,is) = cad(id,is) + sincos(id)*(duxdxp-duydyp) + sinsin(id)*duydxp - coscos(id)*duxdyp
-          !
        enddo
        !
        ! adapt velocity in case of spherical coordinates
@@ -670,7 +327,7 @@
           !
           do is = 1, MSC
              !
-             do iddum = idcmin(is)-1, idcmax(is)+1
+             do iddum = iddlow-1, iddtop+1
                 id = mod ( iddum - 1 + MDC , MDC ) + 1
                 !
                 fac = fac2 * ( abs((rdx(1)+rdx(2))*cax(id,is,1)) + abs((rdy(1)+rdy(2))*cay(id,is,1)) )
--- switch.pl	2014-04-18 10:06:53.000000000 +0200
+++ switch.pl	2015-11-27 11:35:10.856469708 +0100
@@ -11,6 +11,7 @@
 $imp = "FALSE";
 $cvi = "FALSE";
 $adc = "FALSE";
+$coh = "FALSE";
 $ncf = "FALSE";
 $mv4 = "FALSE";
 while ( $ARGV[0]=~/-.*/ )
@@ -27,6 +28,7 @@
    if ($ARGV[0]=~/-impi/) {$imp="TRUE";shift;}
    if ($ARGV[0]=~/-cvis/) {$cvi="TRUE";shift;}
    if ($ARGV[0]=~/-adcirc/) {$adc="TRUE";shift;}
+   if ($ARGV[0]=~/-coh/) {$coh="TRUE";shift;}
    if ($ARGV[0]=~/-netcdf/) {$ncf="TRUE";shift;}
    if ($ARGV[0]=~/-matl4/) {$mv4="TRUE";shift;}
    }
@@ -67,6 +69,7 @@
       else               {$newline=~s/^!!ESMF//;} #second "!" is negation
       if ($tim=~/TRUE/) {$newline=~s/^!TIMG//;}
       if ($mpi=~/TRUE/) {$newline=~s/^!MPI//;}
+      if ($coh=~/TRUE/) {$newline=~s/^!MPI//;}
       if ($pun=~/TRUE/) {$newline=~s/^!PUN//;}
       if ($pun=~/FALSE/) {$newline=~s/^!NPUN//;}
       if ($f95=~/TRUE/) {$newline=~s/^!F95//;}
@@ -78,6 +81,8 @@
       if ($cvi=~/TRUE/) {$newline=~s/^!CVIS//;}
       if ($adc=~/TRUE/) {$newline=~s/^!ADC//;}
       if ($adc=~/FALSE/) {$newline=~s/^!NADC//;}
+      if ($coh=~/TRUE/) {$newline=~s/^!COH//;}
+      if ($coh=~/FALSE/){$newline=~s/^!NCOH//;}
       if ($ncf=~/TRUE/) {$newline=~s/^!NCF//;}
       if ($ncf=~/FALSE/){$newline=~s/^!NNCF//;}
       if ($mv4=~/TRUE/) {$newline=~s/^!MatL4//;}
--- swn_outnc.ftn90	2015-02-04 11:52:57.000000000 +0100
+++ swn_outnc.ftn90	2015-11-27 11:35:17.676469910 +0100
@@ -1382,6 +1382,7 @@
                                                  xpctime, ilpos, ncid
         integer, save                         :: IENT=0
         if (LTRACE) call STRACE (IENT,'swn_outnc_appendblock')
+        if ( ivtype == 40 ) return
 
         ncid = nref + ncoffset(irq)
 
