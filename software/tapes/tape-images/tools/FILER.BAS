$COM 4096
SCREEN 0,1,0,0

	 REM **************************************************************
         REM *                                                            *
         REM * This program is owned by Carroll E. Waddell                *
         REM * This program is written to run on an MS/DOS system using   *
         REM * TURBO BASIC COMPILER.                                      *
         REM * This program may not be legally copied.                    *
         REM *                                                            *
         REM * This routine should be the first used in a Basic program.  *
         REM * This routine can be used with TURBO BASIC or POWER BASIC.  *
         REM **************************************************************

         REM SET INITIAL VALUES

         DEFINT I
         DEFSNG S,E
         DEFDBL D
         DEFLNG L
	 DEFSTR A-C
	 DEFSTR F-H
	 DEFSTR J-K
	 DEFSTR M-R
	 DEFSTR T-Z
         WIDTH "LPT1:",32000
         WIDTH "LPT2:",32000
         SCREEN 0
         PRINT "THIS IS A TURBO BASIC PROGRAM"
         CLS

         REM MAKE ALL ARRAYS DYNAMIC
         $DYNAMIC

         REM DEFINE SOME SPECIAL SYMBOLS
	 AESC = CHR$(27)
	 Q = CHR$(34)
	 CR = CHR$(13)
	 BS = CHR$(8)
	 FF = CHR$(12)

	 ZCOMMAND = COMMAND$

         REM SET UP ERROR TRAPPING
         ON ERROR GOTO ERRORTRAP

         REM GO TO BEGINNING OF PROGRAM
	 GOTO BEGIN1





CLS24:
TBCLXS:
         LOCATE 1,1,1,7,7
         FOR IX = 1 TO 24
         PRINT STRING$(80," ");
         NEXT IX
         LOCATE 1,1,1,7,7
         RETURN

ERR24:
      REM THIS IS A PRINTER OFF LINE ERROR
      BEEP
      DELAY 1
      BEEP
      DELAY 1
      RESUME

ERR27:
     REM THIS IS A PRINTER OUT OF PAPER ERROR
     BEEP
     DELAY 1
     BEEP
     DELAY 1
     BEEP
     DELAY 1
     BEEP
     BEEP
     RESUME

         REM THIS IS NOW THE ERROR TRAPPING LOCATION
ERRORTRAP:
         IF ERR = 24 THEN GOTO ERR24
         IF ERR = 57 THEN GOTO ERR24
         IF ERR = 27 THEN GOTO ERR27

REM ***********
REM ***ERROR ROUTINES MUST BE PUT AT THIS POINT, FOLLOWED BY
REM ****ON ERROR GOTO 0
      PRINT "ERROR NUMBER IS ";ERR
      LINE INPUT W

       ON ERROR GOTO 0









BEGIN1:
     CLS
     SCREEN ,,0,0

     LT1 = -1
     LT2 = -1

     OPEN "COM2:1200,N,8,2,RS,CS0,DS0" AS #2

      PRINT "Enter the name of the read tape volume to be mounted."
      PRINT "Use standard DOS 8.3 name."

      LINE INPUT ZTAPENAME
      ZTAPENAME = UCASE$(ZTAPENAME)
      ZTAPENAME = "C:\H8TAPES\" + ZTAPENAME
      OPEN "B", #7, ZTAPENAME
      IREADTAPEOPEN = 1
      ZREADTAPENAME = ZTAPENAME
	REM SET NUMBER OF BYTES AVAILABLE FROM THIS TAPE
	LReadLength = LOF(7)
	PRINT "Tape file is opened"
	PRINT "Number of bytes is ";LReadLength

READTAPELOOP1:

       GET$ #7,1,TDAT
       PRINT VAL(TDAT)

       PRINT #2, TDAT;
       LREADNOTAPE = 0
       DECR LReadLength
       IF LReadLength = 0 THEN GOTO CloseReadTape

       GOTO READTAPELOOP1


CloseReadTape:
      CLOSE #7
      IREADTAPEOPEN = 0
      ZREADTAPENAME = ""




END.OF.PROGRAM:

   close #2
   CLS
   END


rem ----------------- end of transfer ---------------

END

