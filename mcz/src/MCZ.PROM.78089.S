;************************************************
;*                                              *
;*        MCB MONITOR - 3K VERSION              *
;*                                              *
;*                                              *
;*         COPYRIGHT 1978 BY ZILOG, INC.        *
;*                                              *
;*            REV K 3/6/78                      *
;*                                              *
;************************************************


        GLOBAL CONOBF CONIBF CONOVC CONIVC
        GLOBAL DATE TIME ETIME ERCODE EXTRET MEMTOP MEMBOT INPTR
        GLOBAL OUTPTR NULLCT PROMPT LINDEL CHRDEL BRKFLG BRKRTN
        GLOBAL PCON PDEBUG STACK USRSTK FLOPPY
        GLOBAL DS_BUF INTPNT DSKVSL CURT0 CURTRK BCKPTR FORPTR
        GLOBAL RQSECT PTRS NTRKE NCRCE NSECTE



*INCLUDE MCZEQU



        JR INIT0                ; RST 0  --  SYSTEM RESET

DATCOD: DEFM    '78089N'        ; DATE CODE FOR PROM SET

        ORG 08H
        JP RST1                 ; RST 1
INIT0:  LD (HL_),HL
        JR INIT1

        ORG 10H
        JP RST2                 ; RST 2
INIT1:  LD HL,0
        JR INIT2

        ORG 18H
        JP RST3                 ; RST 3
INIT2:  LD (NSECTE),HL
        JR INIT3

        ORG 20H
        JP RST4                 ; RST 4
INIT3:  LD (NCRCE),HL
        JR INIT4

        ORG 28H
        JP RST5                 ; RST 5
INIT4:  LD (NTRKE),HL
        JR INIT5

        ORG 30H
        JP RST6                 ; RST 6

        ORG 38H
        JP BREAK                ; RST 7  --  SOFTWARE BREAKPOINT


INIT5:  LD (SAVSTK),SP          ; SAVE STACK POINTER
        LD SP,STACK             ; INITIALIZE STACK POINTER
        CALL SAVREG             ;
        IN A,(SWITCH)           ; GET TTY SPEED SETTING
        AND 0FH                 ; GET BOTTOM FOUR BITS
        LD E,A                  ;
        CP 11                   ; GREATER THAN 9.6KB?
HGHSPD: LD A,TIMMOD
        JR C,LOWSPD
        LD A,COUNTER
LOWSPD: OUT (CLK1),A            ; SET CTC MODE
        LD HL,RATTAB            ; ADDRESS OF BAUD RATE TABLE
        LD D,0
        ADD HL,DE
        LD A,(HL)               ; GET CORRECT TIME CONSTANT
        OUT (CLK1),A


        JR LX100
        COND $>66H
        ERROR - ADDRESS DISPLACEMENT
        ENDC
        ORG 66H
        JP MANBRK               ; NON-MASKABLE INTERRUPT
LX100:


; INITIALIZE INTERRUPT MODES

        LD A,DSKVEC.SHR.8       ; SET INTERRUPT REGISTER
        LD I,A
        IM 2                    ; SET INTERRUPT MODE

; INITIALIZE ALL RAM PARAMETERS.

        LD HL,INITPM
        LD DE,PARMS
        LD BC,PARMCT
        LDIR

; ACCOMPLISH PORT OUTPUTS NECSSARY FOR INITIALIZATION.

        LD HL,INIOUT
        LD B,OUTCNT
INITLP: LD C,(HL)
        INC HL
        OUTI
        JR NZ,INITLP



        JR LX150
        COND $>88H
        ERROR - ADDRESS DISPLACEMENT
        ENDC
        ORG 88H
ERROR:  LD SP,STACK             ; RESTORE STACK POINTER
        LD HL,DSKER
        CALL PUTMSG
        JR DEBUG
LX150:



        IN A,(SERDAT)           ; CLEAR SERIAL PORT OF ANY GARBAGE.
        EI
DEBUG:  CALL GET                ; GET INPUT LINE.
        CP ASCICR               ; NULL LINE?
        JR NZ,COMD?
OSBOOT: LD IY,DSKVC             ; SET UP BOOTSTRAP VECTOR
        LD HL,BOOTAD
        LD (DSKVC+2),HL
        LD HL,128
        LD (DSKVC+4),HL
        LD HL,BTLOC             ; DISK ADDRESS
        LD (DSKVC+11),HL
        LD HL,ERROR
        LD (DSKVC+8),HL
        LD (IY+1),RDBIN
        IN A,(DSKSEL)           ; CHECK IS DISK ATTACHED?
        BIT 6,A
        JR NZ,BOOTSR            ; NO.  BOOT FROM SERIAL PORT.
        CALL FLOPY
        JP BOOTAD

BOOTSR: LD HL,BOOTMS
        CALL PUTMSG
        LD IY,DSKVC
        CALL TTY
        JP BOOTAD

DBOOT:  POP HL
        JR OSBOOT
*EJECT
COMD?:  LD HL,DBGRET
        PUSH HL
        LD HL,(INPTR)
        RES 5,A                 ; CONVERT TO UPPER CASE.
        CP 'B'                  ; BREAKPOINT COMMAND?
        JP Z,BRKPNT
        CP 'C'
        JP Z,COMP               ; COMPARE COMMAND?
        CP 'D'
        JP Z,DISPM
        CP 'F'
        JP Z,FILL               ; FILL MEMORY COMMAND
        CP 'G'
        JP Z,GO
        CP 'I'                  ; INTERRUPT STATUS COMMAND?
        JP Z,INTST
        CP 'J'
        JP Z,JUMP               ; JUMP COMMAND
        CP 'L'                  ; LOAD (OS 2.1) ?
        JP Z,DBOOT
        CP 'M'                  ; MOVE COMMAND?
        JP Z,MOVE
        CP 'N'                  ; NEXT COMMAND?
        JP Z,NEXT
        CP 'O'                  ; OS COMMAND?
        JR NZ,R?
        INC HL
        LD A,(HL)
        RES 5,A                 ; UPPER CASE.
        CP 'S'
        JR Z,DBOOT
        JR CMDERR
R?:     CP 'R'                  ; REGISTER DISPLAY?
        JP Z,REG
        CP 'Q'
        JR NZ,S?
        LD HL,BRKFLG
        BIT 5,(HL)
        JR Z,CMDERR
        LD HL,(EXTRET)
        JP (HL)

S?:     CP 'S'                  ; SET MEMORY?
        JP Z,SET
CMDERR: LD SP,STACK             ; COMMAND ERROR
        LD HL,CONOBF-1
        LD (HL),1
        INC HL
        LD (HL),'?'             ; TYPE ?
        DEC HL
        CALL PUTMSG

DBGRET: IN A,(SERCON)           ; WAIT ON TRANSMIT READY
        BIT TXRDY,A
        JR Z,DBGRET
        LD A,37H                ; CLEAR DTR
        OUT (SERCON),A
        LD HL,CONOBF
        LD (OUTPTR),HL
        LD A,'>'
        LD (PROMPT),A
        LD HL,BRKFLG
        BIT 6,(HL)
        RES 6,(HL)
        JR Z,NOEXT
        LD HL,(EXTRET)
        JP (HL)
NOEXT:  CALL GET
        JP COMD?
*H SET BREAKPOINT COMMAND
; ROUTINE TO SET BREAK POINT FROM KEYBOARD INFO
; *INPUTS: KEYBOARD INFO.
; *OUTPUT: BREAKPOINT MODIFIED ACCORDINGLY
; *REGISTERS DESTROYED:
; *CALLS: FNDBRK,CLRBRK,SETBRK
BRKPNT: CALL GETNUM             ; GET BREAKPOINT ADDRESS.
        JP Z,CLRBRK             ; IF NONE, GO TO CLEAR
        CALL CLRBRK             ; CLEAR THE OLD BREAK
        LD A,(HL)               ; BEFORE SETTING A NEW ONE.
        LD (INS),A              ; SAVE THE BREAKPOINTED INSTRUCTION
        LD (HL),0FFH
        LD (BRKADR),HL
        LD A,1
        LD (N_),A               ; SET N TO 1
        CALL GETNUM             ; GET AN N FACTOR
        RET Z
        LD (N_),A
        RET
*H COMPARE MEMORY COMMAND.
; SUBROUTINE TO COMPARE BLOCKS OF
; MEMORY AND TYPE OUT DISCREPANCIES.
COMP:   CALL GETNUM             ; GET FIRST ADDRESS.
        PUSH HL
        CALL GETNUM             ; GET SECOND ADDRESS.
        PUSH HL
        CALL GETNUM             ; GET COUNT.
        JP Z,CMDERR
        LD B,H
        LD C,L
        POP DE                  ; GET BACK ADDRESSES.
        POP HL
CPLOOP: LD A,(DE)               ; GET MEMORY.
        CP (HL)                 ; COMPARE IT.
        CALL NZ,ERR
GOOD:   INC DE                  ; ADVANCE FIRST POINTER.
        CPI                     ; ADVANCE SECOND POINTER AND IMPLEMENT
        JP PE,CPLOOP            ; DOUBLE REGISTER DJNZ.
        RET

ERR:    PUSH DE                 ; SAVE ADDRESS.
        PUSH AF
        LD A,(HL)
        CALL PUTCMP             ; PRINT THE ERRONEOUS ADDRESS.
        POP AF
        EX (SP),HL              ; GET THE OTHER ADDRESS.
        CALL PUTCMP
        CALL PUT
        EX DE,HL
        POP HL
        RET

PUTCMP: PUSH HL                 ; SAVE ADDRESS.
        PUSH AF
        CALL PUTHL
        LD HL,(OUTPTR)
        DEC HL
        LD (HL),'='
        POP AF
        CALL PUTA
        POP HL
        RET
*H DISPLAY MEMORY COMMAND
; DISPLAY MEMORY.
DISPM:  CALL GETNUM             ; GET STARTING ADDRESS
        PUSH HL
        CALL GETNUM             ; GET RANGE
        JR Z,SUBMEM
        LD B,L
        LD C,H
        LD A,B
        AND A                   ; ADJUST COUNTERS.
        JR Z,NOADJ
        INC C
NOADJ:  POP HL                  ; STARTING ADDRESS.
        EXX
LINELP: LD HL,CONOBF
        LD DE,CONOBF+1
        LD BC,73
        LD (HL),' '             ; CLEAR OUT LINE BUFFER.
        LDIR
        LD B,16                 ; SIXTEEN PER LINE.
        LD HL,CONOBF+53         ; START OF ASCII DUMP.
        LD (HL),'*'
        INC HL
        EXX
        CALL PUTHL
PUTLP:  LD A,(HL)
        EXX                     ; GET ASCII DISPLAY CONTROL BANK.
        LD (HL),A
        CP ' '                  ; LESS THAN SPACE?
        JR C,NOPRNT
        CP 7FH
        JR C,PRNT
NOPRNT: LD (HL),'.'
PRNT:   INC HL
        LD (HL),'*'
        EXX
        CALL PUTA
        INC HL
        DJNZ NOTFIN
        DEC C
        JR NZ,NOTFIN
        EXX
        INC HL
        LD (OUTPTR),HL
        JP PUT

NOTFIN: EXX                     ; GET LINE COUNTER
        DJNZ CONTLN             ; CONTINUE LINE
        INC HL
        LD (OUTPTR),HL
        CALL PUT
        JR LINELP

CONTLN: EXX
        JR PUTLP

SUBMEM: LD A,' '                ; SET PROMPT TO A BLANK.
        LD (PROMPT),A
        POP HL
SMMLP:  PUSH HL
        CALL PUTHL
        LD A,(HL)
        CALL PUTA
        CALL PUTDIS
        CALL GETSET
        JR Z,NOSUBM
        POP HL
        LD (HL),A
        PUSH HL
        CALL GETCHR
NOSUBM: POP HL
        RES 5,A
        CP 'Q'
        RET Z           ; IF QUIT COMMAND, TERMINATAE.
        INC HL
        JR SMMLP
*H FILL MEMORY COMMAND
FILL:   CALL GETNUM
        JP Z,CMDERR
        PUSH HL                 ; GET STARTING ADDRESS
        CALL GETNUM
        JP Z,CMDERR
        PUSH HL                 ; GET ENDING ADDRESS
        CALL GETNUM             ; GET FILL BYTE
        LD A,L
        AND A
        POP HL                  ; GET ENDING ADDRESS
        POP DE                  ; GET STARTING ADDRESS
        LD (DE),A
        SBC HL,DE               ; GET LENGTH
        RET Z
        LD B,H                  ; GET LENGTH INTO BC
        LD C,L
        LD H,D                  ; GET STARTING ADDRESS INTO HL
        LD L,E
        INC DE
        LDIR
        RET
*H INTERRUPT STATUS COMMAND
INTST:  LD A,' '                ; SET PROMPT TO BLANK
        LD (PROMPT),A
        LD A,(INT)              ; GET INTERRUPT STATUS
        CALL PUTA               ; DISPLAY IT
        CALL PUTDIS
        CALL GETSET             ; GET A CHANGE FOR IT
        RET Z
        LD (INT),A
        RET
*H JUMP COMMAND
JUMP:   CALL GETNUM             ; GET JUMP ADDRESS
        JP Z,CMDERR
        LD (PC_),HL
        JR GO2

GO:     INC HL
        LD A,(HL)
        RES 5,A
        CP 'E'                  ; IS THIS A 'GET' COMMAND
        JP Z,DBOOT
GO2:    LD A,(I_)               ; RESTORE I REGISTER
        LD I,A
        LD DE,(PC_)             ; IS PC BREAK LOCATION?
        LD HL,(BRKADR)
        AND A
        SBC HL,DE
        JP Z,GOBRK              ; TREAT AS MULTIPLE BREAK.
;*TRANSFERS CONTROL TO USER PROGRAM
GO_:    LD HL,(INT)
        LD A,H
        LD I,A
        DI
        BIT 0,L                 ; IS INTERRUPT ENABLED?
        JR Z,GO01
        EI
GO01:   CALL RESTOR             ; RESTORE REGISTERS
        LD HL,(PC_)             ; GET USER PC
        PUSH HL                 ; PUSH IT FOR RET
        LD HL,(HL_)             ; RESTORE USER HL
        RET
*H NEXT COMMAND
NEXT:   CALL PUTHDR             ; PUT OUT CPU HEADER.
        CALL GETNUM             ; GET THE NMBNER OF INSTRUCTIONS.
        JR NZ,NXT1
        LD A,1                  ; IF NO NUMBER, SET TO 1.
NXT1:   LD (N_),A
        LD HL,TRCINT            ; SET TO COME TO TRACE ROUTINE ON INT.
        LD (BRKJMP),HL
        LD HL,(INT)             ; SAVE INTERRUPT STATUS
        LD (TINT),HL
        LD HL,(PC_)
        PUSH HL
        LD DE,(BRKADR)          ; AT BREAKPOINT?
        AND A
        SBC HL,DE
        POP HL
        JP Z,GONXT
        JP SFTINT               ; FORCE SOFTWARE INTERRUPT.

TRCINT: LD (HL_),HL             ; SAVE REGISTER HL.
        POP HL                  ; GET PC.
        LD (SAVSTK),SP
        LD SP,STACK
        CALL SAVREG
        LD HL,(EIADDR)          ; RESTORE ENABLE INTERRUPT INSTR.
        LD A,(EIINST)
        LD (HL),A
        LD A,REST               ; RESET CLOCK
        OUT (BRKPRT),A
        LD HL,TRCRET
        PUSH HL
        RETI

TRCRET: LD HL,(TINT)            ; RESTORE INTERRUPT STATUS
        LD (INT),HL
        CALL PUTREG
        LD HL,(BRKADR)
        LD (HL),0FFH            ; RESET BREAKPOINT.
        LD A,(N_)
        DEC A                   ; MORE INSTRUCTIONS?
        JR NZ,NXT1
        CALL GET                ; GET NEXT LINE.
        CP ASCICR               ; IF CARRIAGE RETURN, STEP AGAIN.
        JP NZ,COMD?
        LD A,1
        JR NXT1
*H  MOVE COMMAND
MOVE:   CALL GETNUM             ; GET DESTINATION ADDDRESS.
        PUSH HL
        CALL GETNUM             ; GET SOURCE ADDRESS.
        PUSH HL
        CALL GETNUM             ; GET LENGTH.
        JP Z,CMDERR             ; NO NUMBER.
        LD B,H
        LD C,L
        POP HL
        POP DE
        PUSH HL                 ; SAVE REGISTER
        AND A
        SBC HL,DE               ; WHICH IS GREATER.
        POP HL
        JP C,MOVUP              ; DESTINATION IS GREATER.
        LDIR
        RET

; USE LDDR TO MOVE FROM TOP OF BLOCK.

MOVUP:  ADD HL,BC
        DEC HL
        EX DE,HL
        ADD HL,BC
        DEC HL
        EX DE,HL
        LDDR
        RET
*HEADING REGISTER COMMAND
REG:    CALL GETCHR             ; GET THE REGISTER NAME
        LD A,ASCICR
        LD D,(HL)
        CP D                    ; NO NAME?
        JR Z,DCPU
        INC HL                  ; SECOND CHARACTER
        LD E,(HL)
        CP E
        JR NZ,REG01
        LD E,' '                ; SUBSTITUTE A BLANK
REG01:  CALL LOOKUP
        DEC HL
        DEC HL
        JP NZ,CMDERR            ; ILLEGAL NAME
        LD A,' '
        LD (PROMPT),A           ; SUPPRESS PROMPT
DISREG: LD DE,CONOBF            ; MOVE REGISTER NAME TO
        LDI                     ; OUTPUT BUFFER
        LDI
        PUSH HL                 ; SAVE ADDRESS OF NEXT REGISTER
        EX DE,HL
        LD (HL),' '             ; OUTPUT BLANK
        INC HL
        LD (OUTPTR),HL
        LD E,(IX)               ; GET REGISTER ADDRESS
        LD D,STATUS.SHR.8
        LD A,IX_-1&0FFH         ;DOUBLE REGISTER?
        SUB E
        JR C,DISDBL
        LD A,(DE)               ; GET REGISTER CONTENTS
        CALL PUTA
        CALL PUTDIS             ; OUTPUT WITHOUT A CARRIAGE RETURN
        CALL GETSET
        JR Z,NOSET
        LD (DE),A
        CALL GETCHR             ; CHECK FOR A 'Q'
NOSET:  RES 5,A
        CP 'Q'
        POP HL
        RET Z
        INC IX                  ; ADVANCE REGISTER POINTERS
        LD A,REGTAB-1&0FFH      ; MORE REGISTERS?
        SUB L
        JR NC,DISREG
        RET

DISDBL: LD A,(DE)
        LD L,A
        INC DE
        LD A,(DE)
        LD H,A
        PUSH DE
        CALL PUTHL
        CALL PUTDIS
        CALL GETSET
        POP DE
        JR Z,NOSET
        EX DE,HL
        LD (HL),D
        DEC HL
        LD (HL),E
        CALL GETCHR
        JR NOSET

DCPU:   CALL PUTHDR
        CALL PUTREG
        RET

PUTHDR: LD DE,CONOBF            ; OUTPUT BUFFER
        LD HL,RGSTRS            ; MOVE REGISTER NAMES.
        LD B,17                 ; 17 SINGLE REGISTERS
        LD A,' '

DLOOP1: LD C,0FFH
        LDI
        LDI
        LD (DE),A               ; PLACE SPACE.
        INC DE
        DJNZ DLOOP1

        LD B,4

DLOOP2: LD C,0FFH
        LD (DE),A               ; INSERT SPACE
        INC DE
        LDI
        LDI
        LD (DE),A
        INC DE
        LD (DE),A
        INC DE
        DJNZ DLOOP2

        LD (OUTPTR),DE
        CALL PUT
        RET



        COND $>410H
        ERROR - ADDRESS DISPLACEMENT
        ENDC
        ORG 410H
        JR PUTHL



PUTREG: LD B,17                 ; OUTPUT THE SINGLE REGISTERS.
        LD IX,REGTAB            ; TABLE OF REGISTER ADDRESSES.
        LD D,STATUS.SHR.8

        JR LX190
        COND $>420H
        ERROR - ADDRESS DISPLACEMENT
        ENDC
        ORG 420H
        JR PUTA
LX190:


DLOOP3: LD E,(IX)
        LD A,(DE)
        CALL PUTA
        INC IX
        DJNZ DLOOP3
        LD B,4                  ; OUTPUT THE DOUBLE REGISTERS.
DLOOP4: LD E,(IX)
        EX DE,HL
        LD E,(HL)
        INC HL
        LD D,(HL)
        EX DE,HL
        CALL PUTHL
        INC IX
        DJNZ DLOOP4
        CALL PUT
        RET
*HEADING SET MEMORY COMMAND
SET:    INC HL
        LD A,(HL)
        RES 5,A
        CP 'A'
        JP Z,OSBOOT
        CALL GETNUM
SETLP:  PUSH HL
        CALL GETNUM
        POP HL
        RET Z
        LD (HL),A
        INC HL
        JR SETLP

*H SUBROUTINES
GET:    LD IY,CONIVC            ; CONIN VECTOR
        LD HL,CONIBF            ; CONIN BUFFER
        LD (CONIVC+2),HL
        LD (INPTR),HL
        LD HL,255
        LD (CONIVC+4),HL
        LD (IY+1),RDASC
        CALL TTY
        LD A,(CONIBF)           ; GET FIRST CHARACTER.
        RET

PUTHL:                          ; PUTS CONTENTS OF HL ON THE TTY IN HEX
        PUSH DE                 ; SAVE DE REGISTER
        LD A,H
        CALL PUTA
        LD DE,(OUTPTR)
        DEC DE
        LD (OUTPTR),DE
        POP DE
        LD A,L
PUTA:   PUSH HL
        LD HL,(OUTPTR)
        CALL BTOHEX
        INC HL
        LD (HL),' '
        INC HL
        LD (OUTPTR),HL
        POP HL
        RET
GETCHR:                         ; ROUTINE TO GET THE FIRST
                                ; CHARACTER OF THE NEXT BLANK DELIMITED
                                ; FIELD.
        LD HL,(INPTR)           ; GET INPUT POINTER.
NXT:    LD A,(HL)
        CP ' '
        JR NZ,CRTEST
PEEL:   INC HL                  ; PEEL OF  BLANKS.
        LD A,(HL)
        CP ' '
        JR Z,PEEL
GOT:    LD (INPTR),HL
        RET
CRTEST: CP ASCICR
        JR Z,GOT
        INC HL
        JR NXT

GETNUM:                         ; SUBROUTINE TO GET FREE-FORM NUMBER.

        LD HL,0
        PUSH HL                 ; CLEAR WORK AREA
        ADD HL,SP               ; GET STACK POINTER.
FIRST:  EX DE,HL
        CALL GETCHR
        EX DE,HL
        CP '0'
        JR NC,DIG?
        CP ASCICR               ; IS IT A CARRIAGE RETURN?
        JP NZ,CMDERR
        POP HL
        LD A,L
        RET

DIG?:   CP 40H                  ; LOWEST CHARACTER
        JR C,DIGLP
        RES 5,A                 ; SET LOWER TO UPPER CASE.
DIGLP:  CALL CONV               ; CONVERT THE CHARACTER.
        RLD
        INC HL
        RLD
        DEC HL
        INC DE
        LD A,(DE)
        CP '0'                  ; IS IT A DIGIT?
        JR NC,DIG?              ; SHOULD TERMINATE WITH SPACE OR CR.
        POP HL
        LD A,L
        RET




        COND $>4DFH
        ERROR - ADDRESS DISPLACEMENT
        ENDC
        ORG 4DFH
        JR PUT


CONV:   CP '9'+1
        JR C,NOSUB
        CP 'A'                  ; GUARD AGAINST SPECIAL CHARACTERS.
        JP C,CMDERR
        CP 'F'+1
        JP NC,CMDERR            ; GUARD AGAINST OTHER CHARACTERS.
        SUB ADJUST
NOSUB:  AND 0FH
        RET
ADJUST  EQU     7               ; ADJUSTMENT FOR HEX DIGITS > 9

                                ; SUBROUTINE TO CONVERT BINARY DATA
                                ; IN A TO HEX CODE FOR OUTPUT.  HL CONTAINS
                                ; ADDRESS TO STORE RESULT.
BTOHEX: PUSH AF                 ; SAVE DATA
        RRA                     ; GET UPPER HALF
        RRA
        RRA
        RRA
        CALL HBTHEX             ; INVERSE  CONVERSION.
        INC HL                  ; ADVANCE POINTER
        POP AF
        CALL HBTHEX
        RET

;       SUBROUTINE TO CONVERT THE BOTTOM
;       FOUR BITS OF A TO A HEX CHARACTER
;       REPRESENTATION AND STORE IN (HL)
HBTHEX: AND MASK0F
        CP 10
        JR C,INV01
        ADD A,ADJUST
INV01:  ADD A,'0'
        LD (HL),A
        RET
MASK0F: EQU     0FH

LOOKUP: LD IX,REGTAB
        RES 5,D
        LD A,D
        LD BC,42
        LD HL,RGSTRS
LOOK:   CPI
        JR Z,FRSTGD
        CPI                     ; ADVANCE POINTERS OVER SECOND CHARACTR
BAD2ND: RET PO
        INC IX
        JR LOOK
FRSTGD: LD A,E                  ; GET SECOND CHARACTER
        CP '0'-1
        JR C,BLK                ; SPECIAL CHARACTER?
        RES 5,A
BLK:    CPI
        RET Z
        LD A,D
        JR BAD2ND
GETSET: CALL GET                ; GET INPUT
        RES 5,A
        CP 'Q'
        RET Z
        LD HL,CONIBF-1
        LD (HL),' '
        LD (INPTR),HL
        PUSH DE
        CALL GETNUM             ; GET NUMBER
        POP DE
        RET
*EJECT
; ROUTINE TO OUTPUT THE OUTPUT BUFFER
PUT:    PUSH HL
        LD HL,(OUTPTR)          ; STORE A CARRIAGE RETURN.
        LD (HL),ASCICR
        LD HL,CONOBF            ; STARTING POINT OF LINE.
        LD (OUTPTR),HL
        DEC HL
        LD (HL),133             ; MAXIMUM OF ANY LINE.
        CALL PUTMSG
        POP HL
        RET
; ROUTINE TO PUT MESSAGES.  ENTER
; WITH ADDRESS OF MESSAGE IN HL AND LENGTH
; IN BC.
PUTMSG: LD IY,CONOVC            ; CONOUT VECTOR.
        LD A,(HL)
        INC HL
        LD (CONOVC+2),HL
        LD (IY+4),A
        LD (IY+5),0
        LD (IY+1),WRTASC
        CALL TTY
        RET

; OUTPUT THE OUTPUT BUFFER WITHOUT A CARRIAGE
; RETURN
PUTDIS: PUSH HL
        PUSH DE
        LD HL,(OUTPTR)
        LD DE,CONOBF
        LD (OUTPTR),DE          ; RESET OUTPUT PTR
        AND A
        SBC HL,DE
        EX DE,HL
        DEC HL
        LD (HL),E
        CALL PUTMSG
        POP DE
        POP HL
        RET
; SAVES CPU REGISTERS IN STATUS AREA.  SHOULD BE
; ENTERED WITH HL AND SP ALREADY SAVED, AND THE
; USER PC IN HL.  THE RETURN ADDRESS SHOULD BE AT
; STACK-2 AND STACK-1.
;*INPUTS: ALL CPU REGISTERS
;*OUTPUT: STATUS VECTOR
;*REGISTERS DESTROYED: A,SP
;*CALLS: NOTHING
SAVREG: LD SP,SAVSTK            ; SET SP TO TOP OF STATUS VECTOR
        PUSH HL                 ; SAVE USER PC
        PUSH IY
        PUSH IX
        EXX                     ; GET ALTERNATE BANK
        PUSH HL
        PUSH DE
        PUSH BC
        EX AF,AF'               ; GET ALTERNATE ACCUMULATOR
        PUSH AF
        EXX
        EX AF,AF'
        PUSH DE
        PUSH BC
        PUSH AF
        LD A,I
        PUSH AF                 ; SAVE I AND INTERRUPT STATUS
        LD A,(INT)
        RRA                     ; ROTATE PARITY BIT INTO BIT 0
        RRA
        AND 1
        LD (INT),A
        LD A,13H                ; SET INTERRUPT REGISTER
        LD I,A
        IM 2
        EI
        LD SP,STACK-2           ; RESTORE STACK POINTER
        RET

; ROUTINE TO RESTORE REGISTERS
; RETURNS WITH ALL REGISTERS EXCEPT HL AND PC RESTORED.
; *INPUTS: STATUS VECTOR
; *OUTPUT: RESTORED REGISTERS
; *REGISTERS DESTROYED: ALL
; *CALLS: NOTHING.
RESTOR: POP HL                  ; GET RETURN ADDRESS
        LD SP,AF_
        POP AF
        POP BC
        POP DE
        EX AF,AF'               ; GET ALTERNATE REGISTERS
        EXX
        POP AF
        POP BC
        POP DE
        POP HL
        POP IX
        POP IY
        EXX
        EX AF,AF'
        LD SP,(SAVSTK)
        JP (HL)
*E
;**** SET BREAK ROUTINES
; CLRBRK    ---   CLEAR A BREAKPOINT
;*INPUTS: NONE
;*OUTPUT:  BREAKPOINT CLEARED
;*REGISTERS DESTROYED: DE,A
;*CALLS: NOTHING
CLRBRK: PUSH HL
        LD HL,(BRKADR)
        LD A,(INS)
        LD (HL),A
        LD HL,0
        LD (BRKADR),HL
        POP HL
        RET

; BREAKPOINT ENTRANCE BY NMI
MANBRK: LD (HL_),HL
        LD HL,BREAK1
        EX (SP),HL
        RETN
; BREAKPOINT ROUTINE. ENTERED VIA RST 38 ('FF')
BREAK:  LD (HL_),HL             ; SAVE HL
        POP HL
        DEC HL                  ; GET PROG PC
BREAK1: LD (SAVSTK),SP          ; SAVE STACK POINTER
        LD SP,STACK
        CALL SAVREG
        LD A,(BRKFLG)           ; IS EXTERNAL DEBUG LOADED?
        BIT 7,A
        JR Z,BREAK2
        CALL RESTOR
        LD HL,(BRKRTN)
        PUSH HL
        LD HL,(HL_)
        RET
BREAK2: LD DE,(PC_)             ; COMPARE PC TO BREAKPOINT LOCS
        LD HL,(BRKADR)
        AND A
        SBC HL,DE
        JR NZ,NBRK
GDBRK:  LD A,(N_)
        DEC A                   ; IS N RUN OUT?
        JR NZ,NXTBRK            ; NOT YET.  SET TO TRY IT AGAIN.
NBRK:   LD HL,BRKMSG
        CALL PUTMSG
        EX DE,HL
        CALL PUTHL
        CALL PUT
        JP DBGRET

NXTBRK: LD (N_),A
GOBRK:  LD HL,BRKINT            ; SET TO GO TO BREAKPOINT ROUTINE
        LD (BRKJMP),HL
        EX DE,HL                ; GET PC IN HL
GONXT:  LD A,(INS)              ; GET INSTRUCTION
        LD (HL),A               ; STORE IT IN HL, WHICH CONTAINS
                                ; BREAKPOINT LOCATION.

; FORCE A SOFTWARE INTERRUPT

SFTINT: DEC HL                  ; BACK UP.
        LD (EIADDR),HL          ; SAVE ADDRESS OF EI.
        LD A,(HL)
        LD (EIINST),A
        LD (HL),EI              ; ENABLE INTERRUPT INSTRUCTION.
        DI                      ; DISABLE INTERRUPTS.
        LD A,DSKVEC.SHR.8
        LD I,A
        LD A,BRKJMP&0F8H
        OUT (CLK0),A
        IM 2                    ; SET UP INTERRUPTS.
        LD A,TIMMOD+80H         ; SET CTC TO FORCE INTERRUPT
        OUT (BRKPRT),A
        LD A,1
        OUT (BRKPRT),A          ; FORCE PENDING INTERUPT.
        LD (PC_),HL             ; STORE MODIFIED PC
        JP GO01

; INTERRUPT ONE CYCLE AFTER RETURN
; WILL TRANSFER HERE.

BRKINT: PUSH HL         ; SAVE HL REGISTER
        LD HL,(EIADDR)
        PUSH AF
        LD A,REST               ; RESET CTC
        OUT (BRKPRT),A
        LD A,(EIINST)
        LD (HL),A
        INC HL
        LD (HL),0FFH            ; RESTORE BREAKPOINT
        LD A,(I_)
        LD I,A
        LD A,(INT)
        BIT 0,A
        JR Z,BRKI01
        EI
BRKI01: POP AF
        POP HL
        RETI
EI      EQU     0FBH            ; ENABLE INTERRUPT INSTRUCTION.
*H TERMINAL HANDLER
                                ; PROM VERSION OF TTY DRIVER

TTY:    PUSH DE
        PUSH BC
        LD A,(IY+1)             ; CHECK REQUEST CODE FOR A NULL
                                ; OPERATION.
        RES 0,A
        CP RDBIN                ; ANYTHING < RDBIN IS NULL
        JR NC,NONNUL

NULLOP: LD (IY+10),OPCOMP       ; SIGNAL OPERATION COMPLETE

FINTTY: POP BC
        POP DE
        BIT 6,(IY+10)
        JP NZ,ERRTN

IORET:  BIT 0,(IY+1)            ; CHECK WHICH RETURN
        RET Z
        LD H,(IY+7)             ; RETURN TO COMPLETION ADDRESS
        LD L,(IY+6)
        JP (HL)

NONNUL:
        CP WRTASC+1             ; VALID OPERATION?
        JR C,GDOP               ; YES
        LD (IY+10), INV_OP      ; SET ERROR CODE
        JR FINTTY

GDOP:   LD H,A                  ; SAVE REQUEST
        LD A,(IY+4)             ; CHECK FOR ZERO LENGTH REQUEST
        OR (IY+5)
        JR Z,NULLOP

        LD A,H
        LD H,(IY+3)             ; GET DATA ADDRESS
        LD L,(IY+2)
        LD B,(IY+5)             ; GET LENGTH
        LD C,(IY+4)

        CP WRTBIN               ; READ OR WRITE?
        JR C,RD

WRITE:  JR Z,BINWRT


WRTLP:  LD A,(HL)
        CALL TTYWR              ; TRANSMIT CHARACTER
        INC HL
        DEC BC
        CP ASCICR
        JR Z,FINLIN             ; END OF LINE
        LD A,C                  ; COUNT = ZERO?
        OR B
        JR NZ,WRTLP

TTYDON: LD H,(IY+5)             ; GET ORIGINAL LENGTH
        LD L,(IY+4)             ; SPECIFICATION
        SBC HL,BC               ; SUBTRACT NUMBER REMAINING
        LD (IY+5),H
        LD (IY+4),L
        JR NULLOP

FINLIN: PUSH BC                 ; SAVE CHARACTER COUNT
        LD A,ASCILF             ; WRITE LINE FEED
        CALL TTYWR
        LD A,(NULLCT)           ; FIND NUMBER OF NULLS
        AND A                   ; ZERO?
        JR Z,NONULL
        LD B,A
        SUB A                   ; SET A TO NULL CHARACTER

NULLP:  CALL TTYWR              ; WRITE PROPER NUMBER OF
        DJNZ NULLP              ; NULLS

NONULL: POP BC                  ; RECOVER CHARACTER COUNT
        JR TTYDON

BINWRT: LD A,(HL)
        CALL TTYWR
        CPI                     ; ADVANCE POINTER AND DECREMENT COUNT
        JP PE,BINWRT
        JR TTYDON

RD:     CP RDBIN                ; BINARY OR ASCII
        JR NZ,TTY0Z

TTY01:  CALL TTYIN
        LD (HL),A
        CPI                     ; ADVANCE POINTER, DECREMENT COUNT
        JP PE,TTY01
        JR TTYDON

TTY0Z:  LD A,(PROMPT)
        CALL TTYWR
        PUSH HL                 ; SAVE STARTING LINE ADDRESS

RDLOOP: CALL TTYRD
        LD (HL),A               ; STORE CHARACTER
        PUSH HL                 ; SAVE ADDRESS
        LD H,A
        LD A,(CHRDEL)           ; CHECK FOR DELETE CHARACTERS
        CP H
        JR NZ,LD?
        POP HL                  ; RECOVER ADDRESS
        DEC HL                  ; BACK UP POINTER AND
        INC BC                  ; COUNTER
        POP DE                  ; GET STARTING ADDRESS
        PUSH HL
        SBC HL,DE               ; COMPARE TO STARTING ADDRESS
        POP HL
        PUSH DE
        JR NC,RDLOOP            ; POINTER STILL OKAY.   CONTINUE
        JR DELLIN               ; POINTER BACKED UP PAST
; BEGINNING OF LINE.  TREAT AS DELETED LINE

LD?:    LD A,(LINDEL)
        CP H
        JR NZ,NODEL             ; NO DELETE CHARACTER
        POP HL

DELLIN: POP HL                  ; GET STARTING ADDRESS
        PUSH HL                 ; SAVE IT AGAIN
        LD B,(IY+5)             ; SET BC TO INITIAL CHARACTER
        LD C,(IY+4)             ; COUNT.
        JR RDLOOP

NODEL:  LD A,H          ; GET BACK CHARACTER
        POP HL
        INC HL
        DEC BC
        POP DE                  ; BALANCE STACK IN CASE OF END OF LINE
        CP ASCICR
        JR Z,FINLIN
        LD A,C                  ; ZERO CHARACTER COUNT?
        OR B
        JR Z,TTYDON
        PUSH DE                 ; NOT DONE.   SAVE INITIAL ADDRESS
        JR RDLOOP

TTYIN:  IN A,(SERCON)           ; WAIT FOR FLAG
        BIT RXRDY,A
        JR Z,TTYIN              ; NOT READY YET.
        IN A,(SERDAT)
        RET

TTYRD:  CALL TTYIN              ; READ CHARACTER
        CALL TTYWR              ; ECHO IT.
        RES 7,A                 ; CLEAR PARITY
        RET

TTYWR:  PUSH AF                 ; SAVE CHARACTER TO BE WRITTEN

TTYBSY: IN A,(SERCON)           ; CHECK FOR BUSY STATUS.
        BIT TXRDY,A
        JR Z,TTYBSY
        POP AF                  ; RECOVER CHARACTER
        OUT (SERDAT),A
        RET

TXRDY   EQU 0
RXRDY   EQU 1

ERRTN:  LD H,(IY+9)
        LD L,(IY+8)
        LD A,H
        OR L
        JP Z,IORET
        JP (HL)
*H FLOPPY DISK ROUTINE
FLOPY:  LD HL,(DSKVSL)          ; IS THERE A REQUEST ACTIVE?
                                ; IS NOT ZERO
        LD A,H
        OR L
        JR NZ,FLOPY             ; WAIT FOR IT TO GO INACTIVE.
        LD (DSKVSL),IY          ; STORE NEW VECTOR
        BIT 0,(IY+1)            ; TEST TYPE OF RETURN.
        JR NZ,FLP
        CALL FLP                ; RETURN ON COMPLETION IS SPECIFIED,
                                ; SO SET IT UP, THEN WAIT FOR COMPLETION
        CALL WAIT
        RET
FLP:                            ; THE ACTUAL DEVICE DRIVER
        LD H,(IY+3)             ; GET DATA TRANSFER ADDRESS
        LD L,(IY+2)
        LD (BFFADD),HL          ; STORE IT.
        LD H,(IY+5)
        LD L,(IY+4)             ; GET DATA LENGTH
        LD (BFFLEN),HL
        LD H,(IY+12)            ; GET DISK ADDRESS
        LD A,(IY+11)
        AND 1FH                 ; MASK TO SECTOR ADDRESS.
        OR 80H                  ; SET LEAD BIT.
        LD L,A
        LD (DS_BUF),HL          ; STORE IN DISK BUFFER
        LD A,H
        CP 78                   ; VALID TRACK ?
        JR C,TRQOK
        LD (IY+10),TRKERR
        JR FLERR
TRQOK:  LD (RQTRK),A            ; STORE TRACK AS THE REQUESTED.
        LD A,10                 ; SET CRC RETRY COUNTER.
        LD (CRCCTR),A
        LD A,2
        LD (WSCTR),A            ; SET WRONG SECTOR AND WRONG
        LD (WTCTR),A            ; TRACK
        LD (IY+10),0
        LD A,(IY+1)             ; GET REQUEST CODE.
        RES 0,A
        CP WRTBIN               ; BINARY WRITE?
        JR Z,CHKSEL
        CP RDBIN                ; BINARY READ
        JR Z,CHKSEL
        LD (IY+10),INV_OP       ; INVALID OPERATION
FLERR:  LD HL,0                 ; CLEAR  VSL
        LD (DSKVSL),HL
        JR ERRTN

CHKSEL: LD A,REST               ; RESET CLOCK TO PREVENT INTERRUPT
        OUT (CLK0),A
        IN A,(DSKSEL)           ; IS DISK SELECTED?
        AND 0FH
        LD L,A
        RES 3,L
        BIT 3,A                 ; ANY DISK SELECTED?
        LD A,(IY+11)            ; GET REQUESTED UNIT FOR COMPARISON
        RLCA
        RLCA
        RLCA
        JR Z,SELEC
        AND 07
        CP L                    ; COMPARE TO SELECTED UNIT.
        JP Z,CHKHD              ; THE SAME.  CHECK HEAD POSITION.
        PUSH AF                 ; SAVE REQUESTED UNIT.
        CALL UNSEL              ; DESELECT THE CURRENT UNIT.
        POP AF
SELEC:  AND 07
        LD HL,CURT0
        LD E,A
        LD D,0
        ADD HL,DE               ; FORM INDEX INTO TRACK VECTOR
        LD A,(HL)
        LD (CURTRK),A
        LD A,E          ; SELECT THE REQUESTED DISK.
        SET 3,A
        OUT (DSKSEL),A
        IN A, (DSSTAT)          ; CHECK AND MAKE SURE THE
        BIT READY,A             ; SELECTED DISK IS READY.
        JR Z,FLP01
        LD (IY+10),NOTRDY       ; SET NOT READY ERROR
        CALL PRMERR
        JP ERRTN

FLP01:  LD A,(CURTRK)
        CP 78                   ; CHECK HEAD POSITION ON THIS DISK.
        JR C,HDOKAY
        XOR A                   ; HEAD NOT POSITIONED.
        LD (RQTRK),A            ; FORCE SEEK TO TRACK 0 TO
        JP HDMOV                ;  POSITION.

HDOKAY: LD B,A
        LD A,(RQTRK)            ; IS THE CURRENT TRACK OF THE NEWLY
        SUB B                   ; SELECTED DISK THE SAME AS THE RE-
        JR Z,TIME35             ; REQUESTED TRACK?  IF SO, TIME OUT
                                ; HEAD SETTLE TIME
        DEC A                   ; IF ONLY ONE TRACK DIFFERENCE,
        JR Z,TIME7              ; TIME PART OF IT AND LET HEAD
                                ; MOVEMENT TAKE CARE OF REST
        ADD A,2
        JR Z,TIME7
        JP HDMOV

TIME35: LD A,CTRMOD             ; SET UP TO COUNT OF 8 SECTOR
        OUT (CLK0),A            ; HOLES TO GUARANTEE 35 MSEC.
        LD A,8
        OUT (CLK0),A
        LD HL,PREPRE
        JR LAB101

TIME7:  LD A,STCLK0
        OUT (CLK0),A            ; TIME OUT 7 MSEC.
        LD A,TIM7
        OUT (CLK0),A
        LD HL,HDMOV             ; STORE INTERRUPT ADDRESS.
LAB101: LD (INTPNT),HL
        RET

; LOCATE  --   FIND OUT WHAT SECTOR IS UNDER HEAD
LOCATE: LD A,(RQSECT)           ; GET THE REQUESTED SECTOR.
        ADD A,33                ; PREPARE TO FORM MOD 33 DIFFERENCE WITH
                                ; CURRENT SECTOR.
        LD H,A                  ; SAVE IT.
        LD C,DSKDAT             ; PORT NUMBER FOR INPUT.
        LD A,RD_DAT             ; PREPARE TO READ.
        LD B,TM256A
        DJNZ $                  ; TIME OUT 256 USEC BEFORE READING.
        OUT (DSKCOM),A          ; TURN ON READ CIRCUITRY.
        LD A,H
        IN H,(C)                ; READ SECTOR ADDRESS
        SUB H                   ; FORM DIFFERENCE.
        IN H,(C)                ; READ TRACK NUMBER.
        LD C,DSKCOM             ; GET COMMAND PORT IN C
        OUT (C),B               ; TURN OFF READ.
        CP 34
        JR C,SAVE               ; IF > 34, SUBTRACT 33.
        SUB 33
SAVE:   CP 34           ; IF IT'S STILL GREATER THAN 33, THERE
                        ; WAS AN ERROR IN THE SECTOR ADDRESS.
        JP NC,WRNGSC
        LD C,CLK0               ; OUTPUT DIFERENCE TO CLOCK.
        LD L,CTRMOD
        OUT (C),L
        OUT (C),A
        LD A,(DS_BUF+1)         ; GET REQUESTED TRACK NUMBER.
        CP H                    ; COMPARE READ TRACK.
        JP NZ,WRNGTK            ; IF WRONG, TRY RESEEK.
        LD A,(IY+1)
        RES 0,A
        LD HL,WRTSEC            ; SET FOR WRITE.
        CP WRTBIN               ; WRITE REQUEST?
WRTSET: LD (INTPNT),HL
        RET Z
        LD HL,RDSECT            ; SET FOR READ
        CP A                    ; SET ZERO FLAG
        JR WRTSET



WRTSEC: LD A,WRDAT              ; TURN ON WRITE ELECTRONICS.
        OUT (DSKCOM),A
        IN A,(DSKSEL)           ; CHECK WRITE PROTECT STATUS.
        BIT WRTPTC,A
        JR NZ,WRTOK
        XOR A                   ; TURN OFF WRITE AMP.
        OUT (DSKCOM),A
        LD (IY+10),PROTEC       ; SET PROTECT ERROR
        JP PRMERR


PREPAR: LD A,CTRMOD             ; INTERRUPT AT NEXT SECTOR.
        OUT (CLK0),A
        LD A,1
        OUT (CLK0),A
        LD HL,LOCATE            ; ON NEXT INTERRUPT, GO TO LOCATE.
        LD (INTPNT),HL
        RET



        COND $>8DBH
        ERROR - ADDRESS DISPLACEMENT
        ENDC
        ORG 8DBH
        JP UNSEL


DSELEC: CALL UNSEL
        POP HL
        POP BC
        JP NOCMP


WRTOK:  LD BC,8200H+DSKDAT
        LD HL,(BFFADD)          ; GET USER DATA ADDRESS.
        PUSH HL
        LD HL,DS_BUF            ; ADDRESS OF SECTOR ADDRESS.
        LD A,TIM512             ; TIME OUT 512 USECS. FOR PREAMBLE.

; 229 T-STATES FROM INTERRUPT

        DEC A
        JR NZ,$-1

; 568 USECS FROM INTERRUPT

        OUTI
        OUTI
        POP HL                  ; GET BACK DATA ADDRESS.
WRITIT: OUTI                    ; OUTPUT THE DATA.
        NOP                     ; INCREASE REFRESH RATE
        NOP
        NOP
        JR NZ,WRITIT
        LD HL,PTRS              ; LOAD ADDRESS OF POINTERS.
        OUTI
        OUTI
        OUTI
        LD A, WRCRC             ; WRITE CRC ENABLE
        OUTI                    ; OUTPUT LAST POINTER
        OUT (DSKCOM),A          ; ENABLE CRC
        OUT (DSKDAT),A          ; OUTPUT TWO CRC WORDS.
        OUT (DSKDAT),A
        XOR A                   ; CLEAR A
        OUT (DSKDAT),A
        OUT (DSKDAT),A
        OUT (DSKCOM),A
        JR FINOP



CHKHD:  LD A,(CURTRK)           ; CHECK HEAD POSITION BEFORE
        LD HL,DS_BUF+1          ; MOVING HEAD
        CP (HL)
        JP NZ,HDMOV
        CALL PREPRE             ;START LOCATE SEQUENCE
        BIT CMP,(IY+10)
        RET Z
        BIT 6,(IY+10)
        JP NZ,ERRTN
        JP IORET



RDSECT: LD HL,(BFFADD)          ; GET USER DATA AREA.
        PUSH HL
        LD HL,DS_BUF            ; ADDRESS OF SECTOR ADDRESS.
        LD A,RD_DAT             ; PREPARE TO TURN ON READ AMP.
        LD B,TIM256

;       175 T-STATES FROM INTERRUPT

        DJNZ $                  ; TIME OUT
        OUT (DSKCOM),A
        LD BC,8000H+DSKDAT

; 400 USECS FROM INTERRUPT

        IN A,(DSKDAT)           ; INPUT SECTOR ADDRESS.
        CP (HL)                 ; COMPARE IT.
        POP HL                  ; GET DATA ADDRESS.
        IN A,(DSKDAT)           ; INPUT TRACK ADDRESS.
        JP NZ,WRNGSC
READIT: INI
        NOP                     ; INCREASE REFRESH RATE
        NOP
        NOP
        JR NZ,READIT
        LD HL,PTRS              ; INPUT THE POINTERS.
        INI
        LD B,5
        INIR
        IN A,(DSSTAT)           ; CHECK FOR CRC ERROR.
        BIT CRC,A
        LD A,B                  ; SET A TO ZERO TO
        OUT (DSKCOM),A          ; TURN OFF READ.
        JR NZ,BADCRC
FINOP:  LD HL,(BFFLEN)
        LD BC,BLKSIZ            ; MORE BYTES?
        AND A
        SBC HL,BC
        LD (BFFLEN),HL
        JR Z,OPCMP
        JR C,OPCMP
        LD HL,(BFFADD)
        ADD HL,BC
        LD (BFFADD),HL
        LD A,10                 ; RESET RETRY COUNTERS.
        LD (CRCCTR),A
        LD A,2
        LD (WSCTR),A
        LD HL,DS_BUF            ; INCREMENT SECTOR NUMBER.
        INC (HL)
        LD A,CTRMOD             ; SET TO INTERRUPT NEXT SECTIOR
        OUT (CLK0),A
        LD A,1
        OUT (CLK0),A
        RET

OPCMP:  LD (IY+10),OPCOMP
        LD A,CTRMOD             ; OPERATION COMPLETED.  SET
        OUT (CLK0),A            ; FOR INTERRUPT IN HALF REVOLUTION.
        LD A,16
        OUT (CLK0),A            ; IF NO OTHER REQUEST BY THEN,
        LD HL,DSELEC            ; DESELECT.
        LD (INTPNT),HL
OPFIN:  LD HL,0
        LD (DSKVSL),HL
        LD H,(IY+5)
        LD L,(IY+4)
        LD BC,(BFFLEN)
        AND A
        SBC HL,BC               ; FIND NUMBER OF BYTES TRANSFERRED
        LD (IY+5),H
        LD (IY+4),L
        RET

BADCRC: LD HL,(NCRCE)           ; COUNT CRC ERROR TOTAL
        INC HL
        LD (NCRCE),HL
        LD HL,CRCCTR            ; ADDRESS OF CRC RETRY COUNTER.
        DEC (HL)
        JR NZ,PREPRE            ; GO AND TRY AGAIN.
        LD (IY+10),CRCERR
        JR PRMERR

WRNGSC: XOR A                   ; TURN OFF READ AMP
        OUT (DSKCOM),A
        LD HL,(NSECTE)          ; COUNT SECTOR ERRORS
        INC HL
        LD (NSECTE),HL
        LD HL,WSCTR             ; WRONG SECTOR RETRY COUNTER.
        DEC (HL)
        JR NZ,PREPRE            ; GO BACK AND TRY TO RELOCATE SECTOR.
        LD (IY+10),SECTER
PRMERR: CALL UNSEL              ; DESELECT DISK
        JP OPFIN

UNSEL:  LD A,RSTCLK
        OUT (CLK0),A
        IN A,(DSKSEL)           ; FIND OUT WHICH DISK IS SELECTED.
        BIT 3,A                 ; SEE IF ANY DISK IS SELECTED.
        RET Z
        AND 07H
        OUT (DSKSEL),A          ; DESELECT IT.
        LD C,A
        LD B,0
        LD HL,CURT0
        ADD HL,BC
        LD A,(CURTRK)
        LD (HL),A               ; STORE CURRENT TRACK INTO CURT FOR CORRECT DISK.
        RET

PREPRE: LD A,(IY+4)             ; CHECK FOR ZERO LENGTH
        OR (IY+5)
        JP Z,OPCMP
        LD A,TRIG0              ; PREPARE TO PREPARE TO LOCATE
        OUT (CLK0),A            ; THE CORRECT SECTOR.
        LD A,SECT/2+2           ; TIME OUT 1/2 SETCTOR+ A LITTLE.
        OUT (CLK0),A
        LD HL,PREPAR            ; ON INTERRUPT GO TO PREPARE.
        LD (INTPNT),HL
        RET

WRNGTK: LD HL,(NTRKE)           ; COUNT SEEK ERRORS
        INC HL
        LD (NTRKE),HL
        LD HL,WTCTR             ; WRONG TRACK RETRY COUNTER.
        DEC (HL)                ; SEE IF THERE HAVE BEEN TOO MANY TRIES.
        JR NZ,LAB102
        LD (IY+10),TRKERR
        JR PRMERR

LAB102: XOR A                   ; CLEAR A.
        LD (RQTRK),A            ; FORCE SEEK TO TRACK 0.
        CALL HDMOV
        RET

HDMOV:  XOR A
        LD B,A                  ; CLEAR INSTRUCTION WORD.
        LD C,DSKCOM
        LD A,(RQTRK)            ; GET REQUESTED TRACK TO SEE IF WE'RE THERE.
        AND A                   ; IS IT ZERO?
        JR Z,STRK0              ; USE DIFFERENT POSITION CRITERIA
                                ; FOR TRACK 0.
SK:     LD HL,CURTRK            ; ADDRESS OF CURRENT TRACK COUNTER.
        CP (HL)
        JR Z,POS                ; IF EQUAL, THE HEAD IS POSITIONED.
        JR C,BIGGER             ; IF CURRENT TRACK IS BIGGER THAN
                                ; REQUESTED TRACK, MOVE OUTWARD.
        INC (HL)                ; INCREMENT CURRENT TRACK.
        SET DIRECT,B            ; SET TO STEP IN.
        JR BIGG01
BIGGER: DEC (HL)                ; DECREMENT CURRENT TRACK
BIGG01: OUT (C),B
        SET HDSTEP,B
        OUT (C),B               ; OUTPUT THE STEP PULSE.
BIGG03:
        EX (SP),HL              ; DELAY
        EX (SP),HL
        RES HDSTEP,B            ; OUTPUT STEP TRAILING EDGE.
        OUT (C),B
        LD A,STCLK0
        OUT (CLK0),A            ; TIME OUT 8 MSEC TO MOVE HEAD AGAAIN.
        LD A,MS08
        OUT (CLK0),A
        LD HL,HDMOV
        LD (INTPNT),HL          ; STORE INTERRUPT ADDRESS.
        RET

STRK0:  IN A,(DSSTAT)           ; CHECK THE TRACK 0 LINE.
        BIT T0,A                ; IS IT THERE?
        JR Z, POS0
        SET HDSTEP,B
        OUT (C),B               ; OUTPUT THE STEP COMMAND
        JR BIGG03

POS0:   XOR A                   ; CLEAR CURRENT TRACK COUNTER.
        LD (CURTRK),A
POS:    LD A,(CURTRK)           ; GET CURRENT TRACK.
        LD B,A                  ; SAVE IT.
        LD A,(DS_BUF+1)         ; GET TRACK NUMBER OF DISK ADDRESS.
        LD (RQTRK),A
        CP B                    ; RIGHT?
        JR NZ,HDMOV
        LD A,STCLK0
        OUT (CLK0),A            ; START TIMEOUT 18 MSEC.
        LD A,MS18
        OUT (CLK0),A
        LD HL,PREPRE            ; IF READ OR WRITE, GO TO PREPRE
        LD (INTPNT),HL
        RET
; INTERRUPT ENTRY POINT

RTC0:   PUSH HL
        PUSH AF
        PUSH IY
        LD IY,(DSKVSL)
        PUSH BC
        LD HL,RTNPNT            ; PUSH RETURN POINT FOR RETURN.
        PUSH HL
        LD HL,(INTPNT)
        JP (HL)                 ; GO TO APPROPRIATE ROUTINE.

; 124 T-STATES FROM INTERRUPT

RTNPNT: POP BC
        BIT CMP,(IY+10)         ; IS OPERATION COMPLETE?
        JR NZ,CMPRET
NOCMP:  POP IY
        POP AF
        POP HL
        EI                      ; ENABLE INTERRUPTS.
        RETI

CMPRET: BIT 6,(IY+10)           ; OPERATION IS COMPLETE.
        JR Z,NOER               ; ERROR ?
        LD H,(IY+9)
        LD L,(IY+8)
        LD A,H                  ; CHECK FOR A ZERO ADDRESS.
        OR L
        JR NZ,FRET
NOER:   BIT 0,(IY+1)
        JR Z,NOCMP
        LD H,(IY+7)             ; GET COMPLETION RETURN ADDRESS
        LD L,(IY+6)
FRET:   POP IY
        POP AF
        EX (SP),HL              ; RESTORE HL AND PUT CRA ON STACK.
        EI
        RETI


WAIT:                           ; I/O WAIT ROUTINE
        BIT CMP,(IY+10)
        JR Z,WAIT
        RET




;       ERROR CODES
SECTER  EQU     0C4H
TRKERR  EQU     0C5H
CRCERR  EQU     0C6H

;       CONTROL WORDS
REST    EQU     03
STCLK0  EQU     10110111B
CTRMOD  EQU     11010111B
TRIG0   EQU     10101111B
RSTCLK  EQU     00001011B
RD_DAT  EQU     04H
WRDAT   EQU     08H
WRCRC   EQU     18H
HDSTEP  EQU     1
DIRECT  EQU     0
READY   EQU     5
T0      EQU     6
CMP     EQU     7
CRC     EQU     7
WRTPTC  EQU     7
;       TIMING CONTSTNS
TIM7    EQU     67
SECT    EQU     50
MS08    EQU     77
MS18    EQU     172
TIM256  EQU     61
TM256A  EQU     61
TIM512  EQU     73

*I MCZTAB

*I MCZRAM

        END
		