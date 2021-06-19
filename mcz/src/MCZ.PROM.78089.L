                              MCZ.PROM.78089                    PAGE   1
 LOC   OBJ CODE M STMT SOURCE STATEMENT                          ASM 5.8

                     1  ;************************************************
                     2  ;*                                              *
                     3  ;*        MCB MONITOR - 3K VERSION              *
                     4  ;*                                              *
                     5  ;*                                              *
                     6  ;*         COPYRIGHT 1978 BY ZILOG, INC.        *
                     7  ;*                                              *
                     8  ;*            REV K 3/6/78                      *
                     9  ;*                                              *
                    10  ;************************************************
                    11
                    12
                    13          GLOBAL CONOBF CONIBF CONOVC CONIVC
                    14          GLOBAL DATE TIME ETIME ERCODE EXTRET MEMTOP MEMBOT INPTR
                    15          GLOBAL OUTPTR NULLCT PROMPT LINDEL CHRDEL BRKFLG BRKRTN
                    16          GLOBAL PCON PDEBUG STACK USRSTK FLOPPY
                    17          GLOBAL DS_BUF INTPNT DSKVSL CURT0 CURTRK BCKPTR FORPTR
                    18          GLOBAL RQSECT PTRS NTRKE NCRCE NSECTE
                    19
                    20
                    21
                    22  *INCLUDE MCZEQU
                    62  *LIST ON
                    63
                    64
                    65
0000   1809         66          JR INIT0                ; RST 0  --  SYSTEM RESET
                    67
0002   37383038     68  DATCOD: DEFM    '78089N'        ; DATE CODE FOR PROM SET
                    69
0008                70          ORG 08H
0008   C39713       71          JP RST1                 ; RST 1
000B   22BF12       72  INIT0:  LD (HL_),HL
000E   1803         73          JR INIT1
                    74
0010                75          ORG 10H
0010   C39A13       76          JP RST2                 ; RST 2
0013   210000       77  INIT1:  LD HL,0
0016   1803         78          JR INIT2
                    79
0018                80          ORG 18H
0018   C39D13       81          JP RST3                 ; RST 3
001B   229513       82  INIT2:  LD (NSECTE),HL
001E   1803         83          JR INIT3
                    84
0020                85          ORG 20H
0020   C3A013       86          JP RST4                 ; RST 4
0023   229313       87  INIT3:  LD (NCRCE),HL
0026   1803         88          JR INIT4
                    89
0028                90          ORG 28H
0028   C3A313       91          JP RST5                 ; RST 5
002B   229113       92  INIT4:  LD (NTRKE),HL
002E   180B         93          JR INIT5
                    94
0030                95          ORG 30H
0030   C3A613       96          JP RST6                 ; RST 6
                    97


                              MCZ.PROM.78089                    PAGE   2
 LOC   OBJ CODE M STMT SOURCE STATEMENT                          ASM 5.8

0038                98          ORG 38H
0038   C3E905       99          JP BREAK                ; RST 7  --  SOFTWARE BREAKPOINT
                   100
                   101
003B   ED73D712    102  INIT5:  LD (SAVSTK),SP          ; SAVE STACK POINTER
003F   310011      103          LD SP,STACK             ; INITIALIZE STACK POINTER
0042   CD8D05      104          CALL SAVREG             ;
0045   DBDD        105          IN A,(SWITCH)           ; GET TTY SPEED SETTING
0047   E60F        106          AND 0FH                 ; GET BOTTOM FOUR BITS
0049   5F          107          LD E,A                  ;
004A   FE0B        108          CP 11                   ; GREATER THAN 9.6KB?
004C   3E07        109  HGHSPD: LD A,TIMMOD
004E   3802        110          JR C,LOWSPD
0050   3E47        111          LD A,COUNTER
0052   D3D5        112  LOWSPD: OUT (CLK1),A            ; SET CTC MODE
0054   215D0B      113          LD HL,RATTAB            ; ADDRESS OF BAUD RATE TABLE
0057   1600        114          LD D,0
0059   19          115          ADD HL,DE
005A   7E          116          LD A,(HL)               ; GET CORRECT TIME CONSTANT
005B   D3D5        117          OUT (CLK1),A
                   118
                   119
005D   180A        120          JR LX100
                   121          COND $>66H
                   122          ERROR - ADDRESS DISPLACEMENT
                   123          ENDC
0066               124          ORG 66H
0066   C3E005      125          JP MANBRK               ; NON-MASKABLE INTERRUPT
                   126  LX100:
                   127
                   128
                   129  ; INITIALIZE INTERRUPT MODES
                   130
0069   3E13        131          LD A,DSKVEC.SHR.8       ; SET INTERRUPT REGISTER
006B   ED47        132          LD I,A
006D   ED5E        133          IM 2                    ; SET INTERRUPT MODE
                   134
                   135  ; INITIALIZE ALL RAM PARAMETERS.
                   136
006F   216B0B      137          LD HL,INITPM
0072   11C613      138          LD DE,PARMS
0075   011C00      139          LD BC,PARMCT
0078   EDB0        140          LDIR
                   141
                   142  ; ACCOMPLISH PORT OUTPUTS NECSSARY FOR INITIALIZATION.
                   143
007A   21C60B      144          LD HL,INIOUT
007D   060B        145          LD B,OUTCNT
007F   4E          146  INITLP: LD C,(HL)
0080   23          147          INC HL
0081   EDA3        148          OUTI
0083   20FA        149          JR NZ,INITLP
                   150
                   151
                   152
0085   180C        153          JR LX150
                   154          COND $>88H
                   155          ERROR - ADDRESS DISPLACEMENT


                              MCZ.PROM.78089                    PAGE   3
 LOC   OBJ CODE M STMT SOURCE STATEMENT                          ASM 5.8

                   156          ENDC
0088               157          ORG 88H
0088   310011      158  ERROR:  LD SP,STACK             ; RESTORE STACK POINTER
008B   21510B      159          LD HL,DSKER
008E   CD5D05      160          CALL PUTMSG
0091   1803        161          JR DEBUG
                   162  LX150:
                   163
                   164
                   165
0093   DBDE        166          IN A,(SERDAT)           ; CLEAR SERIAL PORT OF ANY GARBAGE.
0095   FB          167          EI
0096   CD5804      168  DEBUG:  CALL GET                ; GET INPUT LINE.
0099   FE0D        169          CP ASCICR               ; NULL LINE?
009B   203F        170          JR NZ,COMD?
009D   FD219E12    171  OSBOOT: LD IY,DSKVC             ; SET UP BOOTSTRAP VECTOR
00A1   210010      172          LD HL,BOOTAD
00A4   22A012      173          LD (DSKVC+2),HL
00A7   218000      174          LD HL,128
00AA   22A212      175          LD (DSKVC+4),HL
00AD   210317      176          LD HL,BTLOC             ; DISK ADDRESS
00B0   22A912      177          LD (DSKVC+11),HL
00B3   218800      178          LD HL,ERROR
00B6   22A612      179          LD (DSKVC+8),HL
00B9   FD36010A    180          LD (IY+1),RDBIN
00BD   DBD1        181          IN A,(DSKSEL)           ; CHECK IS DISK ATTACHED?
00BF   CB77        182          BIT 6,A
00C1   2006        183          JR NZ,BOOTSR            ; NO.  BOOT FROM SERIAL PORT.
00C3   CD8007      184          CALL FLOPY
00C6   C30010      185          JP BOOTAD
                   186
00C9   21340B      187  BOOTSR: LD HL,BOOTMS
00CC   CD5D05      188          CALL PUTMSG
00CF   FD219E12    189          LD IY,DSKVC
00D3   CD7E06      190          CALL TTY
00D6   C30010      191          JP BOOTAD
                   192
00D9   E1          193  DBOOT:  POP HL
00DA   18C1        194          JR OSBOOT


                              MCZ.PROM.78089                    PAGE   4
 LOC   OBJ CODE M STMT SOURCE STATEMENT                          ASM 5.8

                   195  *EJECT
00DC   214D01      196  COMD?:  LD HL,DBGRET
00DF   E5          197          PUSH HL
00E0   2AC413      198          LD HL,(INPTR)
00E3   CBAF        199          RES 5,A                 ; CONVERT TO UPPER CASE.
00E5   FE42        200          CP 'B'                  ; BREAKPOINT COMMAND?
00E7   CA7501      201          JP Z,BRKPNT
00EA   FE43        202          CP 'C'
00EC   CA9401      203          JP Z,COMP               ; COMPARE COMMAND?
00EF   FE44        204          CP 'D'
00F1   CAD401      205          JP Z,DISPM
00F4   FE46        206          CP 'F'
00F6   CA5502      207          JP Z,FILL               ; FILL MEMORY COMMAND
00F9   FE47        208          CP 'G'
00FB   CA9702      209          JP Z,GO
00FE   FE49        210          CP 'I'                  ; INTERRUPT STATUS COMMAND?
0100   CA7602      211          JP Z,INTST
0103   FE4A        212          CP 'J'
0105   CA8C02      213          JP Z,JUMP               ; JUMP COMMAND
0108   FE4C        214          CP 'L'                  ; LOAD (OS 2.1) ?
010A   CAD900      215          JP Z,DBOOT
010D   FE4D        216          CP 'M'                  ; MOVE COMMAND?
010F   CA3303      217          JP Z,MOVE
0112   FE4E        218          CP 'N'                  ; NEXT COMMAND?
0114   CAC902      219          JP Z,NEXT
0117   FE4F        220          CP 'O'                  ; OS COMMAND?
0119   200A        221          JR NZ,R?
011B   23          222          INC HL
011C   7E          223          LD A,(HL)
011D   CBAF        224          RES 5,A                 ; UPPER CASE.
011F   FE53        225          CP 'S'
0121   28B6        226          JR Z,DBOOT
0123   1819        227          JR CMDERR
0125   FE52        228  R?:     CP 'R'                  ; REGISTER DISPLAY?
0127   CA5903      229          JP Z,REG
012A   FE51        230          CP 'Q'
012C   200B        231          JR NZ,S?
012E   21CD13      232          LD HL,BRKFLG
0131   CB6E        233          BIT 5,(HL)
0133   2809        234          JR Z,CMDERR
0135   2ABE13      235          LD HL,(EXTRET)
0138   E9          236          JP (HL)
                   237
0139   FE53        238  S?:     CP 'S'                  ; SET MEMORY?
013B   CA4204      239          JP Z,SET
013E   310011      240  CMDERR: LD SP,STACK             ; COMMAND ERROR
0141   210211      241          LD HL,CONOBF-1
0144   3601        242          LD (HL),1
0146   23          243          INC HL
0147   363F        244          LD (HL),'?'             ; TYPE ?
0149   2B          245          DEC HL
014A   CD5D05      246          CALL PUTMSG
                   247
014D   DBDF        248  DBGRET: IN A,(SERCON)           ; WAIT ON TRANSMIT READY
014F   CB47        249          BIT TXRDY,A
0151   28FA        250          JR Z,DBGRET
0153   3E37        251          LD A,37H                ; CLEAR DTR
0155   D3DF        252          OUT (SERCON),A


                              MCZ.PROM.78089                    PAGE   5
 LOC   OBJ CODE M STMT SOURCE STATEMENT                          ASM 5.8

0157   210311      253          LD HL,CONOBF
015A   22C613      254          LD (OUTPTR),HL
015D   3E3E        255          LD A,'>'
015F   32CA13      256          LD (PROMPT),A
0162   21CD13      257          LD HL,BRKFLG
0165   CB76        258          BIT 6,(HL)
0167   CBB6        259          RES 6,(HL)
0169   2804        260          JR Z,NOEXT
016B   2ABE13      261          LD HL,(EXTRET)
016E   E9          262          JP (HL)
016F   CD5804      263  NOEXT:  CALL GET
0172   C3DC00      264          JP COMD?


SET BREAKPOINT COMMAND        MCZ.PROM.78089                    PAGE   6
 LOC   OBJ CODE M STMT SOURCE STATEMENT                          ASM 5.8

                   265  *H SET BREAKPOINT COMMAND
                   266  ; ROUTINE TO SET BREAK POINT FROM KEYBOARD INFO
                   267  ; *INPUTS: KEYBOARD INFO.
                   268  ; *OUTPUT: BREAKPOINT MODIFIED ACCORDINGLY
                   269  ; *REGISTERS DESTROYED:
                   270  ; *CALLS: FNDBRK,CLRBRK,SETBRK
0175   CDAF04      271  BRKPNT: CALL GETNUM             ; GET BREAKPOINT ADDRESS.
0178   CAD005      272          JP Z,CLRBRK             ; IF NONE, GO TO CLEAR
017B   CDD005      273          CALL CLRBRK             ; CLEAR THE OLD BREAK
017E   7E          274          LD A,(HL)               ; BEFORE SETTING A NEW ONE.
017F   32BA12      275          LD (INS),A              ; SAVE THE BREAKPOINTED INSTRUCTION
0182   36FF        276          LD (HL),0FFH
0184   22D213      277          LD (BRKADR),HL
0187   3E01        278          LD A,1
0189   32BB12      279          LD (N_),A               ; SET N TO 1
018C   CDAF04      280          CALL GETNUM             ; GET AN N FACTOR
018F   C8          281          RET Z
0190   32BB12      282          LD (N_),A
0193   C9          283          RET


COMPARE MEMORY COMMAND.       MCZ.PROM.78089                    PAGE   7
 LOC   OBJ CODE M STMT SOURCE STATEMENT                          ASM 5.8

                   284  *H COMPARE MEMORY COMMAND.
                   285  ; SUBROUTINE TO COMPARE BLOCKS OF
                   286  ; MEMORY AND TYPE OUT DISCREPANCIES.
0194   CDAF04      287  COMP:   CALL GETNUM             ; GET FIRST ADDRESS.
0197   E5          288          PUSH HL
0198   CDAF04      289          CALL GETNUM             ; GET SECOND ADDRESS.
019B   E5          290          PUSH HL
019C   CDAF04      291          CALL GETNUM             ; GET COUNT.
019F   CA3E01      292          JP Z,CMDERR
01A2   44          293          LD B,H
01A3   4D          294          LD C,L
01A4   D1          295          POP DE                  ; GET BACK ADDRESSES.
01A5   E1          296          POP HL
01A6   1A          297  CPLOOP: LD A,(DE)               ; GET MEMORY.
01A7   BE          298          CP (HL)                 ; COMPARE IT.
01A8   C4B201      299          CALL NZ,ERR
01AB   13          300  GOOD:   INC DE                  ; ADVANCE FIRST POINTER.
01AC   EDA1        301          CPI                     ; ADVANCE SECOND POINTER AND IMPLEMENT
01AE   EAA601      302          JP PE,CPLOOP            ; DOUBLE REGISTER DJNZ.
01B1   C9          303          RET
                   304
01B2   D5          305  ERR:    PUSH DE                 ; SAVE ADDRESS.
01B3   F5          306          PUSH AF
01B4   7E          307          LD A,(HL)
01B5   CDC301      308          CALL PUTCMP             ; PRINT THE ERRONEOUS ADDRESS.
01B8   F1          309          POP AF
01B9   E3          310          EX (SP),HL              ; GET THE OTHER ADDRESS.
01BA   CDC301      311          CALL PUTCMP
01BD   CD4905      312          CALL PUT
01C0   EB          313          EX DE,HL
01C1   E1          314          POP HL
01C2   C9          315          RET
                   316
01C3   E5          317  PUTCMP: PUSH HL                 ; SAVE ADDRESS.
01C4   F5          318          PUSH AF
01C5   CD7604      319          CALL PUTHL
01C8   2AC613      320          LD HL,(OUTPTR)
01CB   2B          321          DEC HL
01CC   363D        322          LD (HL),'='
01CE   F1          323          POP AF
01CF   CD8604      324          CALL PUTA
01D2   E1          325          POP HL
01D3   C9          326          RET


DISPLAY MEMORY COMMAND        MCZ.PROM.78089                    PAGE   8
 LOC   OBJ CODE M STMT SOURCE STATEMENT                          ASM 5.8

                   327  *H DISPLAY MEMORY COMMAND
                   328  ; DISPLAY MEMORY.
01D4   CDAF04      329  DISPM:  CALL GETNUM             ; GET STARTING ADDRESS
01D7   E5          330          PUSH HL
01D8   CDAF04      331          CALL GETNUM             ; GET RANGE
01DB   2853        332          JR Z,SUBMEM
01DD   45          333          LD B,L
01DE   4C          334          LD C,H
01DF   78          335          LD A,B
01E0   A7          336          AND A                   ; ADJUST COUNTERS.
01E1   2801        337          JR Z,NOADJ
01E3   0C          338          INC C
01E4   E1          339  NOADJ:  POP HL                  ; STARTING ADDRESS.
01E5   D9          340          EXX
01E6   210311      341  LINELP: LD HL,CONOBF
01E9   110411      342          LD DE,CONOBF+1
01EC   014900      343          LD BC,73
01EF   3620        344          LD (HL),' '             ; CLEAR OUT LINE BUFFER.
01F1   EDB0        345          LDIR
01F3   0610        346          LD B,16                 ; SIXTEEN PER LINE.
01F5   213811      347          LD HL,CONOBF+53         ; START OF ASCII DUMP.
01F8   362A        348          LD (HL),'*'
01FA   23          349          INC HL
01FB   D9          350          EXX
01FC   CD7604      351          CALL PUTHL
01FF   7E          352  PUTLP:  LD A,(HL)
0200   D9          353          EXX                     ; GET ASCII DISPLAY CONTROL BANK.
0201   77          354          LD (HL),A
0202   FE20        355          CP ' '                  ; LESS THAN SPACE?
0204   3804        356          JR C,NOPRNT
0206   FE7F        357          CP 7FH
0208   3802        358          JR C,PRNT
020A   362E        359  NOPRNT: LD (HL),'.'
020C   23          360  PRNT:   INC HL
020D   362A        361          LD (HL),'*'
020F   D9          362          EXX
0210   CD8604      363          CALL PUTA
0213   23          364          INC HL
0214   100B        365          DJNZ NOTFIN
0216   0D          366          DEC C
0217   2008        367          JR NZ,NOTFIN
0219   D9          368          EXX
021A   23          369          INC HL
021B   22C613      370          LD (OUTPTR),HL
021E   C34905      371          JP PUT
                   372
0221   D9          373  NOTFIN: EXX                     ; GET LINE COUNTER
0222   1009        374          DJNZ CONTLN             ; CONTINUE LINE
0224   23          375          INC HL
0225   22C613      376          LD (OUTPTR),HL
0228   CD4905      377          CALL PUT
022B   18B9        378          JR LINELP
                   379
022D   D9          380  CONTLN: EXX
022E   18CF        381          JR PUTLP
                   382
0230   3E20        383  SUBMEM: LD A,' '                ; SET PROMPT TO A BLANK.
0232   32CA13      384          LD (PROMPT),A


DISPLAY MEMORY COMMAND        MCZ.PROM.78089                    PAGE   9
 LOC   OBJ CODE M STMT SOURCE STATEMENT                          ASM 5.8

0235   E1          385          POP HL
0236   E5          386  SMMLP:  PUSH HL
0237   CD7604      387          CALL PUTHL
023A   7E          388          LD A,(HL)
023B   CD8604      389          CALL PUTA
023E   CD7505      390          CALL PUTDIS
0241   CD3305      391          CALL GETSET
0244   2806        392          JR Z,NOSUBM
0246   E1          393          POP HL
0247   77          394          LD (HL),A
0248   E5          395          PUSH HL
0249   CD9604      396          CALL GETCHR
024C   E1          397  NOSUBM: POP HL
024D   CBAF        398          RES 5,A
024F   FE51        399          CP 'Q'
0251   C8          400          RET Z           ; IF QUIT COMMAND, TERMINATAE.
0252   23          401          INC HL
0253   18E1        402          JR SMMLP


FILL MEMORY COMMAND           MCZ.PROM.78089                    PAGE  10
 LOC   OBJ CODE M STMT SOURCE STATEMENT                          ASM 5.8

                   403  *H FILL MEMORY COMMAND
0255   CDAF04      404  FILL:   CALL GETNUM
0258   CA3E01      405          JP Z,CMDERR
025B   E5          406          PUSH HL                 ; GET STARTING ADDRESS
025C   CDAF04      407          CALL GETNUM
025F   CA3E01      408          JP Z,CMDERR
0262   E5          409          PUSH HL                 ; GET ENDING ADDRESS
0263   CDAF04      410          CALL GETNUM             ; GET FILL BYTE
0266   7D          411          LD A,L
0267   A7          412          AND A
0268   E1          413          POP HL                  ; GET ENDING ADDRESS
0269   D1          414          POP DE                  ; GET STARTING ADDRESS
026A   12          415          LD (DE),A
026B   ED52        416          SBC HL,DE               ; GET LENGTH
026D   C8          417          RET Z
026E   44          418          LD B,H                  ; GET LENGTH INTO BC
026F   4D          419          LD C,L
0270   62          420          LD H,D                  ; GET STARTING ADDRESS INTO HL
0271   6B          421          LD L,E
0272   13          422          INC DE
0273   EDB0        423          LDIR
0275   C9          424          RET


INTERRUPT STATUS COMMAND      MCZ.PROM.78089                    PAGE  11
 LOC   OBJ CODE M STMT SOURCE STATEMENT                          ASM 5.8

                   425  *H INTERRUPT STATUS COMMAND
0276   3E20        426  INTST:  LD A,' '                ; SET PROMPT TO BLANK
0278   32CA13      427          LD (PROMPT),A
027B   3AC112      428          LD A,(INT)              ; GET INTERRUPT STATUS
027E   CD8604      429          CALL PUTA               ; DISPLAY IT
0281   CD7505      430          CALL PUTDIS
0284   CD3305      431          CALL GETSET             ; GET A CHANGE FOR IT
0287   C8          432          RET Z
0288   32C112      433          LD (INT),A
028B   C9          434          RET


JUMP COMMAND                  MCZ.PROM.78089                    PAGE  12
 LOC   OBJ CODE M STMT SOURCE STATEMENT                          ASM 5.8

                   435  *H JUMP COMMAND
028C   CDAF04      436  JUMP:   CALL GETNUM             ; GET JUMP ADDRESS
028F   CA3E01      437          JP Z,CMDERR
0292   22D512      438          LD (PC_),HL
0295   1809        439          JR GO2
                   440
0297   23          441  GO:     INC HL
0298   7E          442          LD A,(HL)
0299   CBAF        443          RES 5,A
029B   FE45        444          CP 'E'                  ; IS THIS A 'GET' COMMAND
029D   CAD900      445          JP Z,DBOOT
02A0   3AC212      446  GO2:    LD A,(I_)               ; RESTORE I REGISTER
02A3   ED47        447          LD I,A
02A5   ED5BD512    448          LD DE,(PC_)             ; IS PC BREAK LOCATION?
02A9   2AD213      449          LD HL,(BRKADR)
02AC   A7          450          AND A
02AD   ED52        451          SBC HL,DE
02AF   CA2F06      452          JP Z,GOBRK              ; TREAT AS MULTIPLE BREAK.
                   453  ;*TRANSFERS CONTROL TO USER PROGRAM
02B2   2AC112      454  GO_:    LD HL,(INT)
02B5   7C          455          LD A,H
02B6   ED47        456          LD I,A
02B8   F3          457          DI
02B9   CB45        458          BIT 0,L                 ; IS INTERRUPT ENABLED?
02BB   2801        459          JR Z,GO01
02BD   FB          460          EI
02BE   CDB805      461  GO01:   CALL RESTOR             ; RESTORE REGISTERS
02C1   2AD512      462          LD HL,(PC_)             ; GET USER PC
02C4   E5          463          PUSH HL                 ; PUSH IT FOR RET
02C5   2ABF12      464          LD HL,(HL_)             ; RESTORE USER HL
02C8   C9          465          RET


NEXT COMMAND                  MCZ.PROM.78089                    PAGE  13
 LOC   OBJ CODE M STMT SOURCE STATEMENT                          ASM 5.8

                   466  *H NEXT COMMAND
02C9   CDCF03      467  NEXT:   CALL PUTHDR             ; PUT OUT CPU HEADER.
02CC   CDAF04      468          CALL GETNUM             ; GET THE NMBNER OF INSTRUCTIONS.
02CF   2002        469          JR NZ,NXT1
02D1   3E01        470          LD A,1                  ; IF NO NUMBER, SET TO 1.
02D3   32BB12      471  NXT1:   LD (N_),A
02D6   21F402      472          LD HL,TRCINT            ; SET TO COME TO TRACE ROUTINE ON INT.
02D9   22E613      473          LD (BRKJMP),HL
02DC   2AC112      474          LD HL,(INT)             ; SAVE INTERRUPT STATUS
02DF   22D912      475          LD (TINT),HL
02E2   2AD512      476          LD HL,(PC_)
02E5   E5          477          PUSH HL
02E6   ED5BD213    478          LD DE,(BRKADR)          ; AT BREAKPOINT?
02EA   A7          479          AND A
02EB   ED52        480          SBC HL,DE
02ED   E1          481          POP HL
02EE   CA3606      482          JP Z,GONXT
02F1   C33A06      483          JP SFTINT               ; FORCE SOFTWARE INTERRUPT.
                   484
02F4   22BF12      485  TRCINT: LD (HL_),HL             ; SAVE REGISTER HL.
02F7   E1          486          POP HL                  ; GET PC.
02F8   ED73D712    487          LD (SAVSTK),SP
02FC   310011      488          LD SP,STACK
02FF   CD8D05      489          CALL SAVREG
0302   2ABC12      490          LD HL,(EIADDR)          ; RESTORE ENABLE INTERRUPT INSTR.
0305   3ABE12      491          LD A,(EIINST)
0308   77          492          LD (HL),A
0309   3E03        493          LD A,REST               ; RESET CLOCK
030B   D3D7        494          OUT (BRKPRT),A
030D   211303      495          LD HL,TRCRET
0310   E5          496          PUSH HL
0311   ED4D        497          RETI
                   498
0313   2AD912      499  TRCRET: LD HL,(TINT)            ; RESTORE INTERRUPT STATUS
0316   22C112      500          LD (INT),HL
0319   CD1204      501          CALL PUTREG
031C   2AD213      502          LD HL,(BRKADR)
031F   36FF        503          LD (HL),0FFH            ; RESET BREAKPOINT.
0321   3ABB12      504          LD A,(N_)
0324   3D          505          DEC A                   ; MORE INSTRUCTIONS?
0325   20AC        506          JR NZ,NXT1
0327   CD5804      507          CALL GET                ; GET NEXT LINE.
032A   FE0D        508          CP ASCICR               ; IF CARRIAGE RETURN, STEP AGAIN.
032C   C2DC00      509          JP NZ,COMD?
032F   3E01        510          LD A,1
0331   18A0        511          JR NXT1


MOVE COMMAND                  MCZ.PROM.78089                    PAGE  14
 LOC   OBJ CODE M STMT SOURCE STATEMENT                          ASM 5.8

                   512  *H  MOVE COMMAND
0333   CDAF04      513  MOVE:   CALL GETNUM             ; GET DESTINATION ADDDRESS.
0336   E5          514          PUSH HL
0337   CDAF04      515          CALL GETNUM             ; GET SOURCE ADDRESS.
033A   E5          516          PUSH HL
033B   CDAF04      517          CALL GETNUM             ; GET LENGTH.
033E   CA3E01      518          JP Z,CMDERR             ; NO NUMBER.
0341   44          519          LD B,H
0342   4D          520          LD C,L
0343   E1          521          POP HL
0344   D1          522          POP DE
0345   E5          523          PUSH HL                 ; SAVE REGISTER
0346   A7          524          AND A
0347   ED52        525          SBC HL,DE               ; WHICH IS GREATER.
0349   E1          526          POP HL
034A   DA5003      527          JP C,MOVUP              ; DESTINATION IS GREATER.
034D   EDB0        528          LDIR
034F   C9          529          RET
                   530
                   531  ; USE LDDR TO MOVE FROM TOP OF BLOCK.
                   532
0350   09          533  MOVUP:  ADD HL,BC
0351   2B          534          DEC HL
0352   EB          535          EX DE,HL
0353   09          536          ADD HL,BC
0354   2B          537          DEC HL
0355   EB          538          EX DE,HL
0356   EDB8        539          LDDR
0358   C9          540          RET


REGISTER COMMAND              MCZ.PROM.78089                    PAGE  15
 LOC   OBJ CODE M STMT SOURCE STATEMENT                          ASM 5.8

                   541  *HEADING REGISTER COMMAND
0359   CD9604      542  REG:    CALL GETCHR             ; GET THE REGISTER NAME
035C   3E0D        543          LD A,ASCICR
035E   56          544          LD D,(HL)
035F   BA          545          CP D                    ; NO NAME?
0360   2866        546          JR Z,DCPU
0362   23          547          INC HL                  ; SECOND CHARACTER
0363   5E          548          LD E,(HL)
0364   BB          549          CP E
0365   2002        550          JR NZ,REG01
0367   1E20        551          LD E,' '                ; SUBSTITUTE A BLANK
0369   CD0E05      552  REG01:  CALL LOOKUP
036C   2B          553          DEC HL
036D   2B          554          DEC HL
036E   C23E01      555          JP NZ,CMDERR            ; ILLEGAL NAME
0371   3E20        556          LD A,' '
0373   32CA13      557          LD (PROMPT),A           ; SUPPRESS PROMPT
0376   110311      558  DISREG: LD DE,CONOBF            ; MOVE REGISTER NAME TO
0379   EDA0        559          LDI                     ; OUTPUT BUFFER
037B   EDA0        560          LDI
037D   E5          561          PUSH HL                 ; SAVE ADDRESS OF NEXT REGISTER
037E   EB          562          EX DE,HL
037F   3620        563          LD (HL),' '             ; OUTPUT BLANK
0381   23          564          INC HL
0382   22C613      565          LD (OUTPTR),HL
0385   DD5E00      566          LD E,(IX)               ; GET REGISTER ADDRESS
0388   1612        567          LD D,STATUS.SHR.8
038A   3ED0        568          LD A,IX_-1&0FFH         ;DOUBLE REGISTER?
038C   93          569          SUB E
038D   381E        570          JR C,DISDBL
038F   1A          571          LD A,(DE)               ; GET REGISTER CONTENTS
0390   CD8604      572          CALL PUTA
0393   CD7505      573          CALL PUTDIS             ; OUTPUT WITHOUT A CARRIAGE RETURN
0396   CD3305      574          CALL GETSET
0399   2804        575          JR Z,NOSET
039B   12          576          LD (DE),A
039C   CD9604      577          CALL GETCHR             ; CHECK FOR A 'Q'
039F   CBAF        578  NOSET:  RES 5,A
03A1   FE51        579          CP 'Q'
03A3   E1          580          POP HL
03A4   C8          581          RET Z
03A5   DD23        582          INC IX                  ; ADVANCE REGISTER POINTERS
03A7   3EB0        583          LD A,REGTAB-1&0FFH      ; MORE REGISTERS?
03A9   95          584          SUB L
03AA   30CA        585          JR NC,DISREG
03AC   C9          586          RET
                   587
03AD   1A          588  DISDBL: LD A,(DE)
03AE   6F          589          LD L,A
03AF   13          590          INC DE
03B0   1A          591          LD A,(DE)
03B1   67          592          LD H,A
03B2   D5          593          PUSH DE
03B3   CD7604      594          CALL PUTHL
03B6   CD7505      595          CALL PUTDIS
03B9   CD3305      596          CALL GETSET
03BC   D1          597          POP DE
03BD   28E0        598          JR Z,NOSET


REGISTER COMMAND              MCZ.PROM.78089                    PAGE  16
 LOC   OBJ CODE M STMT SOURCE STATEMENT                          ASM 5.8

03BF   EB          599          EX DE,HL
03C0   72          600          LD (HL),D
03C1   2B          601          DEC HL
03C2   73          602          LD (HL),E
03C3   CD9604      603          CALL GETCHR
03C6   18D7        604          JR NOSET
                   605
03C8   CDCF03      606  DCPU:   CALL PUTHDR
03CB   CD1204      607          CALL PUTREG
03CE   C9          608          RET
                   609
03CF   110311      610  PUTHDR: LD DE,CONOBF            ; OUTPUT BUFFER
03D2   21870B      611          LD HL,RGSTRS            ; MOVE REGISTER NAMES.
03D5   0611        612          LD B,17                 ; 17 SINGLE REGISTERS
03D7   3E20        613          LD A,' '
                   614
03D9   0EFF        615  DLOOP1: LD C,0FFH
03DB   EDA0        616          LDI
03DD   EDA0        617          LDI
03DF   12          618          LD (DE),A               ; PLACE SPACE.
03E0   13          619          INC DE
03E1   10F6        620          DJNZ DLOOP1
                   621
03E3   0604        622          LD B,4
                   623
03E5   0EFF        624  DLOOP2: LD C,0FFH
03E7   12          625          LD (DE),A               ; INSERT SPACE
03E8   13          626          INC DE
03E9   EDA0        627          LDI
03EB   EDA0        628          LDI
03ED   12          629          LD (DE),A
03EE   13          630          INC DE
03EF   12          631          LD (DE),A
03F0   13          632          INC DE
03F1   10F2        633          DJNZ DLOOP2
                   634
03F3   ED53C613    635          LD (OUTPTR),DE
03F7   CD4905      636          CALL PUT
03FA   C9          637          RET
                   638
                   639
                   640
                   641          COND $>410H
                   642          ERROR - ADDRESS DISPLACEMENT
                   643          ENDC
0410               644          ORG 410H
0410   1864        645          JR PUTHL
                   646
                   647
                   648
0412   0611        649  PUTREG: LD B,17                 ; OUTPUT THE SINGLE REGISTERS.
0414   DD21B10B    650          LD IX,REGTAB            ; TABLE OF REGISTER ADDRESSES.
0418   1612        651          LD D,STATUS.SHR.8
                   652
041A   1806        653          JR LX190
                   654          COND $>420H
                   655          ERROR - ADDRESS DISPLACEMENT
                   656          ENDC


REGISTER COMMAND              MCZ.PROM.78089                    PAGE  17
 LOC   OBJ CODE M STMT SOURCE STATEMENT                          ASM 5.8

0420               657          ORG 420H
0420   1864        658          JR PUTA
                   659  LX190:
                   660
                   661
0422   DD5E00      662  DLOOP3: LD E,(IX)
0425   1A          663          LD A,(DE)
0426   CD8604      664          CALL PUTA
0429   DD23        665          INC IX
042B   10F5        666          DJNZ DLOOP3
042D   0604        667          LD B,4                  ; OUTPUT THE DOUBLE REGISTERS.
042F   DD5E00      668  DLOOP4: LD E,(IX)
0432   EB          669          EX DE,HL
0433   5E          670          LD E,(HL)
0434   23          671          INC HL
0435   56          672          LD D,(HL)
0436   EB          673          EX DE,HL
0437   CD7604      674          CALL PUTHL
043A   DD23        675          INC IX
043C   10F1        676          DJNZ DLOOP4
043E   CD4905      677          CALL PUT
0441   C9          678          RET


SET MEMORY COMMAND            MCZ.PROM.78089                    PAGE  18
 LOC   OBJ CODE M STMT SOURCE STATEMENT                          ASM 5.8

                   679  *HEADING SET MEMORY COMMAND
0442   23          680  SET:    INC HL
0443   7E          681          LD A,(HL)
0444   CBAF        682          RES 5,A
0446   FE41        683          CP 'A'
0448   CA9D00      684          JP Z,OSBOOT
044B   CDAF04      685          CALL GETNUM
044E   E5          686  SETLP:  PUSH HL
044F   CDAF04      687          CALL GETNUM
0452   E1          688          POP HL
0453   C8          689          RET Z
0454   77          690          LD (HL),A
0455   23          691          INC HL
0456   18F6        692          JR SETLP
                   693


SUBROUTINES                   MCZ.PROM.78089                    PAGE  19
 LOC   OBJ CODE M STMT SOURCE STATEMENT                          ASM 5.8

                   694  *H SUBROUTINES
0458   FD219312    695  GET:    LD IY,CONIVC            ; CONIN VECTOR
045C   218911      696          LD HL,CONIBF            ; CONIN BUFFER
045F   229512      697          LD (CONIVC+2),HL
0462   22C413      698          LD (INPTR),HL
0465   21FF00      699          LD HL,255
0468   229712      700          LD (CONIVC+4),HL
046B   FD36010C    701          LD (IY+1),RDASC
046F   CD7E06      702          CALL TTY
0472   3A8911      703          LD A,(CONIBF)           ; GET FIRST CHARACTER.
0475   C9          704          RET
                   705
                   706  PUTHL:                          ; PUTS CONTENTS OF HL ON THE TTY IN HEX
0476   D5          707          PUSH DE                 ; SAVE DE REGISTER
0477   7C          708          LD A,H
0478   CD8604      709          CALL PUTA
047B   ED5BC613    710          LD DE,(OUTPTR)
047F   1B          711          DEC DE
0480   ED53C613    712          LD (OUTPTR),DE
0484   D1          713          POP DE
0485   7D          714          LD A,L
0486   E5          715  PUTA:   PUSH HL
0487   2AC613      716          LD HL,(OUTPTR)
048A   CDF404      717          CALL BTOHEX
048D   23          718          INC HL
048E   3620        719          LD (HL),' '
0490   23          720          INC HL
0491   22C613      721          LD (OUTPTR),HL
0494   E1          722          POP HL
0495   C9          723          RET
                   724  GETCHR:                         ; ROUTINE TO GET THE FIRST
                   725                                  ; CHARACTER OF THE NEXT BLANK DELIMITED
                   726                                  ; FIELD.
0496   2AC413      727          LD HL,(INPTR)           ; GET INPUT POINTER.
0499   7E          728  NXT:    LD A,(HL)
049A   FE20        729          CP ' '
049C   200A        730          JR NZ,CRTEST
049E   23          731  PEEL:   INC HL                  ; PEEL OF  BLANKS.
049F   7E          732          LD A,(HL)
04A0   FE20        733          CP ' '
04A2   28FA        734          JR Z,PEEL
04A4   22C413      735  GOT:    LD (INPTR),HL
04A7   C9          736          RET
04A8   FE0D        737  CRTEST: CP ASCICR
04AA   28F8        738          JR Z,GOT
04AC   23          739          INC HL
04AD   18EA        740          JR NXT
                   741
                   742  GETNUM:                         ; SUBROUTINE TO GET FREE-FORM NUMBER.
                   743
04AF   210000      744          LD HL,0
04B2   E5          745          PUSH HL                 ; CLEAR WORK AREA
04B3   39          746          ADD HL,SP               ; GET STACK POINTER.
04B4   EB          747  FIRST:  EX DE,HL
04B5   CD9604      748          CALL GETCHR
04B8   EB          749          EX DE,HL
04B9   FE30        750          CP '0'
04BB   3008        751          JR NC,DIG?


SUBROUTINES                   MCZ.PROM.78089                    PAGE  20
 LOC   OBJ CODE M STMT SOURCE STATEMENT                          ASM 5.8

04BD   FE0D        752          CP ASCICR               ; IS IT A CARRIAGE RETURN?
04BF   C23E01      753          JP NZ,CMDERR
04C2   E1          754          POP HL
04C3   7D          755          LD A,L
04C4   C9          756          RET
                   757
04C5   FE40        758  DIG?:   CP 40H                  ; LOWEST CHARACTER
04C7   3802        759          JR C,DIGLP
04C9   CBAF        760          RES 5,A                 ; SET LOWER TO UPPER CASE.
04CB   CDE104      761  DIGLP:  CALL CONV               ; CONVERT THE CHARACTER.
04CE   ED6F        762          RLD
04D0   23          763          INC HL
04D1   ED6F        764          RLD
04D3   2B          765          DEC HL
04D4   13          766          INC DE
04D5   1A          767          LD A,(DE)
04D6   FE30        768          CP '0'                  ; IS IT A DIGIT?
04D8   30EB        769          JR NC,DIG?              ; SHOULD TERMINATE WITH SPACE OR CR.
04DA   E1          770          POP HL
04DB   7D          771          LD A,L
04DC   C9          772          RET
                   773
                   774
                   775
                   776
                   777          COND $>4DFH
                   778          ERROR - ADDRESS DISPLACEMENT
                   779          ENDC
04DF               780          ORG 4DFH
04DF   1868        781          JR PUT
                   782
                   783
04E1   FE3A        784  CONV:   CP '9'+1
04E3   380C        785          JR C,NOSUB
04E5   FE41        786          CP 'A'                  ; GUARD AGAINST SPECIAL CHARACTERS.
04E7   DA3E01      787          JP C,CMDERR
04EA   FE47        788          CP 'F'+1
04EC   D23E01      789          JP NC,CMDERR            ; GUARD AGAINST OTHER CHARACTERS.
04EF   D607        790          SUB ADJUST
04F1   E60F        791  NOSUB:  AND 0FH
04F3   C9          792          RET
                   793  ADJUST  EQU     7               ; ADJUSTMENT FOR HEX DIGITS > 9
                   794
                   795                                  ; SUBROUTINE TO CONVERT BINARY DATA
                   796                                  ; IN A TO HEX CODE FOR OUTPUT.  HL CONTAINS
                   797                                  ; ADDRESS TO STORE RESULT.
04F4   F5          798  BTOHEX: PUSH AF                 ; SAVE DATA
04F5   1F          799          RRA                     ; GET UPPER HALF
04F6   1F          800          RRA
04F7   1F          801          RRA
04F8   1F          802          RRA
04F9   CD0205      803          CALL HBTHEX             ; INVERSE  CONVERSION.
04FC   23          804          INC HL                  ; ADVANCE POINTER
04FD   F1          805          POP AF
04FE   CD0205      806          CALL HBTHEX
0501   C9          807          RET
                   808
                   809  ;       SUBROUTINE TO CONVERT THE BOTTOM


SUBROUTINES                   MCZ.PROM.78089                    PAGE  21
 LOC   OBJ CODE M STMT SOURCE STATEMENT                          ASM 5.8

                   810  ;       FOUR BITS OF A TO A HEX CHARACTER
                   811  ;       REPRESENTATION AND STORE IN (HL)
0502   E60F        812  HBTHEX: AND MASK0F
0504   FE0A        813          CP 10
0506   3802        814          JR C,INV01
0508   C607        815          ADD A,ADJUST
050A   C630        816  INV01:  ADD A,'0'
050C   77          817          LD (HL),A
050D   C9          818          RET
                   819  MASK0F: EQU     0FH
                   820
050E   DD21B10B    821  LOOKUP: LD IX,REGTAB
0512   CBAA        822          RES 5,D
0514   7A          823          LD A,D
0515   012A00      824          LD BC,42
0518   21870B      825          LD HL,RGSTRS
051B   EDA1        826  LOOK:   CPI
051D   2807        827          JR Z,FRSTGD
051F   EDA1        828          CPI                     ; ADVANCE POINTERS OVER SECOND CHARACTR
0521   E0          829  BAD2ND: RET PO
0522   DD23        830          INC IX
0524   18F5        831          JR LOOK
0526   7B          832  FRSTGD: LD A,E                  ; GET SECOND CHARACTER
0527   FE2F        833          CP '0'-1
0529   3802        834          JR C,BLK                ; SPECIAL CHARACTER?
052B   CBAF        835          RES 5,A
052D   EDA1        836  BLK:    CPI
052F   C8          837          RET Z
0530   7A          838          LD A,D
0531   18EE        839          JR BAD2ND
0533   CD5804      840  GETSET: CALL GET                ; GET INPUT
0536   CBAF        841          RES 5,A
0538   FE51        842          CP 'Q'
053A   C8          843          RET Z
053B   218811      844          LD HL,CONIBF-1
053E   3620        845          LD (HL),' '
0540   22C413      846          LD (INPTR),HL
0543   D5          847          PUSH DE
0544   CDAF04      848          CALL GETNUM             ; GET NUMBER
0547   D1          849          POP DE
0548   C9          850          RET


SUBROUTINES                   MCZ.PROM.78089                    PAGE  22
 LOC   OBJ CODE M STMT SOURCE STATEMENT                          ASM 5.8

                   851  *EJECT
                   852  ; ROUTINE TO OUTPUT THE OUTPUT BUFFER
0549   E5          853  PUT:    PUSH HL
054A   2AC613      854          LD HL,(OUTPTR)          ; STORE A CARRIAGE RETURN.
054D   360D        855          LD (HL),ASCICR
054F   210311      856          LD HL,CONOBF            ; STARTING POINT OF LINE.
0552   22C613      857          LD (OUTPTR),HL
0555   2B          858          DEC HL
0556   3685        859          LD (HL),133             ; MAXIMUM OF ANY LINE.
0558   CD5D05      860          CALL PUTMSG
055B   E1          861          POP HL
055C   C9          862          RET
                   863  ; ROUTINE TO PUT MESSAGES.  ENTER
                   864  ; WITH ADDRESS OF MESSAGE IN HL AND LENGTH
                   865  ; IN BC.
055D   FD218812    866  PUTMSG: LD IY,CONOVC            ; CONOUT VECTOR.
0561   7E          867          LD A,(HL)
0562   23          868          INC HL
0563   228A12      869          LD (CONOVC+2),HL
0566   FD7704      870          LD (IY+4),A
0569   FD360500    871          LD (IY+5),0
056D   FD360110    872          LD (IY+1),WRTASC
0571   CD7E06      873          CALL TTY
0574   C9          874          RET
                   875
                   876  ; OUTPUT THE OUTPUT BUFFER WITHOUT A CARRIAGE
                   877  ; RETURN
0575   E5          878  PUTDIS: PUSH HL
0576   D5          879          PUSH DE
0577   2AC613      880          LD HL,(OUTPTR)
057A   110311      881          LD DE,CONOBF
057D   ED53C613    882          LD (OUTPTR),DE          ; RESET OUTPUT PTR
0581   A7          883          AND A
0582   ED52        884          SBC HL,DE
0584   EB          885          EX DE,HL
0585   2B          886          DEC HL
0586   73          887          LD (HL),E
0587   CD5D05      888          CALL PUTMSG
058A   D1          889          POP DE
058B   E1          890          POP HL
058C   C9          891          RET
                   892  ; SAVES CPU REGISTERS IN STATUS AREA.  SHOULD BE
                   893  ; ENTERED WITH HL AND SP ALREADY SAVED, AND THE
                   894  ; USER PC IN HL.  THE RETURN ADDRESS SHOULD BE AT
                   895  ; STACK-2 AND STACK-1.
                   896  ;*INPUTS: ALL CPU REGISTERS
                   897  ;*OUTPUT: STATUS VECTOR
                   898  ;*REGISTERS DESTROYED: A,SP
                   899  ;*CALLS: NOTHING
058D   31D712      900  SAVREG: LD SP,SAVSTK            ; SET SP TO TOP OF STATUS VECTOR
0590   E5          901          PUSH HL                 ; SAVE USER PC
0591   FDE5        902          PUSH IY
0593   DDE5        903          PUSH IX
0595   D9          904          EXX                     ; GET ALTERNATE BANK
0596   E5          905          PUSH HL
0597   D5          906          PUSH DE
0598   C5          907          PUSH BC
0599   08          908          EX AF,AF'               ; GET ALTERNATE ACCUMULATOR


SUBROUTINES                   MCZ.PROM.78089                    PAGE  23
 LOC   OBJ CODE M STMT SOURCE STATEMENT                          ASM 5.8

059A   F5          909          PUSH AF
059B   D9          910          EXX
059C   08          911          EX AF,AF'
059D   D5          912          PUSH DE
059E   C5          913          PUSH BC
059F   F5          914          PUSH AF
05A0   ED57        915          LD A,I
05A2   F5          916          PUSH AF                 ; SAVE I AND INTERRUPT STATUS
05A3   3AC112      917          LD A,(INT)
05A6   1F          918          RRA                     ; ROTATE PARITY BIT INTO BIT 0
05A7   1F          919          RRA
05A8   E601        920          AND 1
05AA   32C112      921          LD (INT),A
05AD   3E13        922          LD A,13H                ; SET INTERRUPT REGISTER
05AF   ED47        923          LD I,A
05B1   ED5E        924          IM 2
05B3   FB          925          EI
05B4   31FE10      926          LD SP,STACK-2           ; RESTORE STACK POINTER
05B7   C9          927          RET
                   928
                   929  ; ROUTINE TO RESTORE REGISTERS
                   930  ; RETURNS WITH ALL REGISTERS EXCEPT HL AND PC RESTORED.
                   931  ; *INPUTS: STATUS VECTOR
                   932  ; *OUTPUT: RESTORED REGISTERS
                   933  ; *REGISTERS DESTROYED: ALL
                   934  ; *CALLS: NOTHING.
05B8   E1          935  RESTOR: POP HL                  ; GET RETURN ADDRESS
05B9   31C312      936          LD SP,AF_
05BC   F1          937          POP AF
05BD   C1          938          POP BC
05BE   D1          939          POP DE
05BF   08          940          EX AF,AF'               ; GET ALTERNATE REGISTERS
05C0   D9          941          EXX
05C1   F1          942          POP AF
05C2   C1          943          POP BC
05C3   D1          944          POP DE
05C4   E1          945          POP HL
05C5   DDE1        946          POP IX
05C7   FDE1        947          POP IY
05C9   D9          948          EXX
05CA   08          949          EX AF,AF'
05CB   ED7BD712    950          LD SP,(SAVSTK)
05CF   E9          951          JP (HL)


SUBROUTINES                   MCZ.PROM.78089                    PAGE  24
 LOC   OBJ CODE M STMT SOURCE STATEMENT                          ASM 5.8

                   952  *E
                   953  ;**** SET BREAK ROUTINES
                   954  ; CLRBRK    ---   CLEAR A BREAKPOINT
                   955  ;*INPUTS: NONE
                   956  ;*OUTPUT:  BREAKPOINT CLEARED
                   957  ;*REGISTERS DESTROYED: DE,A
                   958  ;*CALLS: NOTHING
05D0   E5          959  CLRBRK: PUSH HL
05D1   2AD213      960          LD HL,(BRKADR)
05D4   3ABA12      961          LD A,(INS)
05D7   77          962          LD (HL),A
05D8   210000      963          LD HL,0
05DB   22D213      964          LD (BRKADR),HL
05DE   E1          965          POP HL
05DF   C9          966          RET
                   967
                   968  ; BREAKPOINT ENTRANCE BY NMI
05E0   22BF12      969  MANBRK: LD (HL_),HL
05E3   21EE05      970          LD HL,BREAK1
05E6   E3          971          EX (SP),HL
05E7   ED45        972          RETN
                   973  ; BREAKPOINT ROUTINE. ENTERED VIA RST 38 ('FF')
05E9   22BF12      974  BREAK:  LD (HL_),HL             ; SAVE HL
05EC   E1          975          POP HL
05ED   2B          976          DEC HL                  ; GET PROG PC
05EE   ED73D712    977  BREAK1: LD (SAVSTK),SP          ; SAVE STACK POINTER
05F2   310011      978          LD SP,STACK
05F5   CD8D05      979          CALL SAVREG
05F8   3ACD13      980          LD A,(BRKFLG)           ; IS EXTERNAL DEBUG LOADED?
05FB   CB7F        981          BIT 7,A
05FD   280B        982          JR Z,BREAK2
05FF   CDB805      983          CALL RESTOR
0602   2ACE13      984          LD HL,(BRKRTN)
0605   E5          985          PUSH HL
0606   2ABF12      986          LD HL,(HL_)
0609   C9          987          RET
060A   ED5BD512    988  BREAK2: LD DE,(PC_)             ; COMPARE PC TO BREAKPOINT LOCS
060E   2AD213      989          LD HL,(BRKADR)
0611   A7          990          AND A
0612   ED52        991          SBC HL,DE
0614   2006        992          JR NZ,NBRK
0616   3ABB12      993  GDBRK:  LD A,(N_)
0619   3D          994          DEC A                   ; IS N RUN OUT?
061A   2010        995          JR NZ,NXTBRK            ; NOT YET.  SET TO TRY IT AGAIN.
061C   21470B      996  NBRK:   LD HL,BRKMSG
061F   CD5D05      997          CALL PUTMSG
0622   EB          998          EX DE,HL
0623   CD7604      999          CALL PUTHL
0626   CD4905     1000          CALL PUT
0629   C34D01     1001          JP DBGRET
                  1002
062C   32BB12     1003  NXTBRK: LD (N_),A
062F   215D06     1004  GOBRK:  LD HL,BRKINT            ; SET TO GO TO BREAKPOINT ROUTINE
0632   22E613     1005          LD (BRKJMP),HL
0635   EB         1006          EX DE,HL                ; GET PC IN HL
0636   3ABA12     1007  GONXT:  LD A,(INS)              ; GET INSTRUCTION
0639   77         1008          LD (HL),A               ; STORE IT IN HL, WHICH CONTAINS
                  1009                                  ; BREAKPOINT LOCATION.


SUBROUTINES                   MCZ.PROM.78089                    PAGE  25
 LOC   OBJ CODE M STMT SOURCE STATEMENT                          ASM 5.8

                  1010
                  1011  ; FORCE A SOFTWARE INTERRUPT
                  1012
063A   2B         1013  SFTINT: DEC HL                  ; BACK UP.
063B   22BC12     1014          LD (EIADDR),HL          ; SAVE ADDRESS OF EI.
063E   7E         1015          LD A,(HL)
063F   32BE12     1016          LD (EIINST),A
0642   36FB       1017          LD (HL),EI              ; ENABLE INTERRUPT INSTRUCTION.
0644   F3         1018          DI                      ; DISABLE INTERRUPTS.
0645   3E13       1019          LD A,DSKVEC.SHR.8
0647   ED47       1020          LD I,A
0649   3EE0       1021          LD A,BRKJMP&0F8H
064B   D3D4       1022          OUT (CLK0),A
064D   ED5E       1023          IM 2                    ; SET UP INTERRUPTS.
064F   3E87       1024          LD A,TIMMOD+80H         ; SET CTC TO FORCE INTERRUPT
0651   D3D7       1025          OUT (BRKPRT),A
0653   3E01       1026          LD A,1
0655   D3D7       1027          OUT (BRKPRT),A          ; FORCE PENDING INTERUPT.
0657   22D512     1028          LD (PC_),HL             ; STORE MODIFIED PC
065A   C3BE02     1029          JP GO01
                  1030
                  1031  ; INTERRUPT ONE CYCLE AFTER RETURN
                  1032  ; WILL TRANSFER HERE.
                  1033
065D   E5         1034  BRKINT: PUSH HL         ; SAVE HL REGISTER
065E   2ABC12     1035          LD HL,(EIADDR)
0661   F5         1036          PUSH AF
0662   3E03       1037          LD A,REST               ; RESET CTC
0664   D3D7       1038          OUT (BRKPRT),A
0666   3ABE12     1039          LD A,(EIINST)
0669   77         1040          LD (HL),A
066A   23         1041          INC HL
066B   36FF       1042          LD (HL),0FFH            ; RESTORE BREAKPOINT
066D   3AC212     1043          LD A,(I_)
0670   ED47       1044          LD I,A
0672   3AC112     1045          LD A,(INT)
0675   CB47       1046          BIT 0,A
0677   2801       1047          JR Z,BRKI01
0679   FB         1048          EI
067A   F1         1049  BRKI01: POP AF
067B   E1         1050          POP HL
067C   ED4D       1051          RETI
                  1052  EI      EQU     0FBH            ; ENABLE INTERRUPT INSTRUCTION.


TERMINAL HANDLER              MCZ.PROM.78089                    PAGE  26
 LOC   OBJ CODE M STMT SOURCE STATEMENT                          ASM 5.8

                  1053  *H TERMINAL HANDLER
                  1054                                  ; PROM VERSION OF TTY DRIVER
                  1055
067E   D5         1056  TTY:    PUSH DE
067F   C5         1057          PUSH BC
0680   FD7E01     1058          LD A,(IY+1)             ; CHECK REQUEST CODE FOR A NULL
                  1059                                  ; OPERATION.
0683   CB87       1060          RES 0,A
0685   FE0A       1061          CP RDBIN                ; ANYTHING < RDBIN IS NULL
0687   3019       1062          JR NC,NONNUL
                  1063
0689   FD360A80   1064  NULLOP: LD (IY+10),OPCOMP       ; SIGNAL OPERATION COMPLETE
                  1065
068D   C1         1066  FINTTY: POP BC
068E   D1         1067          POP DE
068F   FDCB0A76   1068          BIT 6,(IY+10)
0693   C27407     1069          JP NZ,ERRTN
                  1070
0696   FDCB0146   1071  IORET:  BIT 0,(IY+1)            ; CHECK WHICH RETURN
069A   C8         1072          RET Z
069B   FD6607     1073          LD H,(IY+7)             ; RETURN TO COMPLETION ADDRESS
069E   FD6E06     1074          LD L,(IY+6)
06A1   E9         1075          JP (HL)
                  1076
                  1077  NONNUL:
06A2   FE11       1078          CP WRTASC+1             ; VALID OPERATION?
06A4   3806       1079          JR C,GDOP               ; YES
06A6   FD360AC1   1080          LD (IY+10), INV_OP      ; SET ERROR CODE
06AA   18E1       1081          JR FINTTY
                  1082
06AC   67         1083  GDOP:   LD H,A                  ; SAVE REQUEST
06AD   FD7E04     1084          LD A,(IY+4)             ; CHECK FOR ZERO LENGTH REQUEST
06B0   FDB605     1085          OR (IY+5)
06B3   28D4       1086          JR Z,NULLOP
                  1087
06B5   7C         1088          LD A,H
06B6   FD6603     1089          LD H,(IY+3)             ; GET DATA ADDRESS
06B9   FD6E02     1090          LD L,(IY+2)
06BC   FD4605     1091          LD B,(IY+5)             ; GET LENGTH
06BF   FD4E04     1092          LD C,(IY+4)
                  1093
06C2   FE0E       1094          CP WRTBIN               ; READ OR WRITE?
06C4   3841       1095          JR C,RD
                  1096
06C6   2834       1097  WRITE:  JR Z,BINWRT
                  1098
                  1099
06C8   7E         1100  WRTLP:  LD A,(HL)
06C9   CD6907     1101          CALL TTYWR              ; TRANSMIT CHARACTER
06CC   23         1102          INC HL
06CD   0B         1103          DEC BC
06CE   FE0D       1104          CP ASCICR
06D0   2814       1105          JR Z,FINLIN             ; END OF LINE
06D2   79         1106          LD A,C                  ; COUNT = ZERO?
06D3   B0         1107          OR B
06D4   20F2       1108          JR NZ,WRTLP
                  1109
06D6   FD6605     1110  TTYDON: LD H,(IY+5)             ; GET ORIGINAL LENGTH


TERMINAL HANDLER              MCZ.PROM.78089                    PAGE  27
 LOC   OBJ CODE M STMT SOURCE STATEMENT                          ASM 5.8

06D9   FD6E04     1111          LD L,(IY+4)             ; SPECIFICATION
06DC   ED42       1112          SBC HL,BC               ; SUBTRACT NUMBER REMAINING
06DE   FD7405     1113          LD (IY+5),H
06E1   FD7504     1114          LD (IY+4),L
06E4   18A3       1115          JR NULLOP
                  1116
06E6   C5         1117  FINLIN: PUSH BC                 ; SAVE CHARACTER COUNT
06E7   3E0A       1118          LD A,ASCILF             ; WRITE LINE FEED
06E9   CD6907     1119          CALL TTYWR
06EC   3AC813     1120          LD A,(NULLCT)           ; FIND NUMBER OF NULLS
06EF   A7         1121          AND A                   ; ZERO?
06F0   2807       1122          JR Z,NONULL
06F2   47         1123          LD B,A
06F3   97         1124          SUB A                   ; SET A TO NULL CHARACTER
                  1125
06F4   CD6907     1126  NULLP:  CALL TTYWR              ; WRITE PROPER NUMBER OF
06F7   10FB       1127          DJNZ NULLP              ; NULLS
                  1128
06F9   C1         1129  NONULL: POP BC                  ; RECOVER CHARACTER COUNT
06FA   18DA       1130          JR TTYDON
                  1131
06FC   7E         1132  BINWRT: LD A,(HL)
06FD   CD6907     1133          CALL TTYWR
0700   EDA1       1134          CPI                     ; ADVANCE POINTER AND DECREMENT COUNT
0702   EAFC06     1135          JP PE,BINWRT
0705   18CF       1136          JR TTYDON
                  1137
0707   FE0A       1138  RD:     CP RDBIN                ; BINARY OR ASCII
0709   200B       1139          JR NZ,TTY0Z
                  1140
070B   CD5707     1141  TTY01:  CALL TTYIN
070E   77         1142          LD (HL),A
070F   EDA1       1143          CPI                     ; ADVANCE POINTER, DECREMENT COUNT
0711   EA0B07     1144          JP PE,TTY01
0714   18C0       1145          JR TTYDON
                  1146
0716   3ACA13     1147  TTY0Z:  LD A,(PROMPT)
0719   CD6907     1148          CALL TTYWR
071C   E5         1149          PUSH HL                 ; SAVE STARTING LINE ADDRESS
                  1150
071D   CD6007     1151  RDLOOP: CALL TTYRD
0720   77         1152          LD (HL),A               ; STORE CHARACTER
0721   E5         1153          PUSH HL                 ; SAVE ADDRESS
0722   67         1154          LD H,A
0723   3ACC13     1155          LD A,(CHRDEL)           ; CHECK FOR DELETE CHARACTERS
0726   BC         1156          CP H
0727   200D       1157          JR NZ,LD?
0729   E1         1158          POP HL                  ; RECOVER ADDRESS
072A   2B         1159          DEC HL                  ; BACK UP POINTER AND
072B   03         1160          INC BC                  ; COUNTER
072C   D1         1161          POP DE                  ; GET STARTING ADDRESS
072D   E5         1162          PUSH HL
072E   ED52       1163          SBC HL,DE               ; COMPARE TO STARTING ADDRESS
0730   E1         1164          POP HL
0731   D5         1165          PUSH DE
0732   30E9       1166          JR NC,RDLOOP            ; POINTER STILL OKAY.   CONTINUE
0734   1807       1167          JR DELLIN               ; POINTER BACKED UP PAST
                  1168  ; BEGINNING OF LINE.  TREAT AS DELETED LINE


TERMINAL HANDLER              MCZ.PROM.78089                    PAGE  28
 LOC   OBJ CODE M STMT SOURCE STATEMENT                          ASM 5.8

                  1169
0736   3ACB13     1170  LD?:    LD A,(LINDEL)
0739   BC         1171          CP H
073A   200B       1172          JR NZ,NODEL             ; NO DELETE CHARACTER
073C   E1         1173          POP HL
                  1174
073D   E1         1175  DELLIN: POP HL                  ; GET STARTING ADDRESS
073E   E5         1176          PUSH HL                 ; SAVE IT AGAIN
073F   FD4605     1177          LD B,(IY+5)             ; SET BC TO INITIAL CHARACTER
0742   FD4E04     1178          LD C,(IY+4)             ; COUNT.
0745   18D6       1179          JR RDLOOP
                  1180
0747   7C         1181  NODEL:  LD A,H          ; GET BACK CHARACTER
0748   E1         1182          POP HL
0749   23         1183          INC HL
074A   0B         1184          DEC BC
074B   D1         1185          POP DE                  ; BALANCE STACK IN CASE OF END OF LINE
074C   FE0D       1186          CP ASCICR
074E   2896       1187          JR Z,FINLIN
0750   79         1188          LD A,C                  ; ZERO CHARACTER COUNT?
0751   B0         1189          OR B
0752   2882       1190          JR Z,TTYDON
0754   D5         1191          PUSH DE                 ; NOT DONE.   SAVE INITIAL ADDRESS
0755   18C6       1192          JR RDLOOP
                  1193
0757   DBDF       1194  TTYIN:  IN A,(SERCON)           ; WAIT FOR FLAG
0759   CB4F       1195          BIT RXRDY,A
075B   28FA       1196          JR Z,TTYIN              ; NOT READY YET.
075D   DBDE       1197          IN A,(SERDAT)
075F   C9         1198          RET
                  1199
0760   CD5707     1200  TTYRD:  CALL TTYIN              ; READ CHARACTER
0763   CD6907     1201          CALL TTYWR              ; ECHO IT.
0766   CBBF       1202          RES 7,A                 ; CLEAR PARITY
0768   C9         1203          RET
                  1204
0769   F5         1205  TTYWR:  PUSH AF                 ; SAVE CHARACTER TO BE WRITTEN
                  1206
076A   DBDF       1207  TTYBSY: IN A,(SERCON)           ; CHECK FOR BUSY STATUS.
076C   CB47       1208          BIT TXRDY,A
076E   28FA       1209          JR Z,TTYBSY
0770   F1         1210          POP AF                  ; RECOVER CHARACTER
0771   D3DE       1211          OUT (SERDAT),A
0773   C9         1212          RET
                  1213
                  1214  TXRDY   EQU 0
                  1215  RXRDY   EQU 1
                  1216
0774   FD6609     1217  ERRTN:  LD H,(IY+9)
0777   FD6E08     1218          LD L,(IY+8)
077A   7C         1219          LD A,H
077B   B5         1220          OR L
077C   CA9606     1221          JP Z,IORET
077F   E9         1222          JP (HL)


FLOPPY DISK ROUTINE           MCZ.PROM.78089                    PAGE  29
 LOC   OBJ CODE M STMT SOURCE STATEMENT                          ASM 5.8

                  1223  *H FLOPPY DISK ROUTINE
0780   2AD013     1224  FLOPY:  LD HL,(DSKVSL)          ; IS THERE A REQUEST ACTIVE?
                  1225                                  ; IS NOT ZERO
0783   7C         1226          LD A,H
0784   B5         1227          OR L
0785   20F9       1228          JR NZ,FLOPY             ; WAIT FOR IT TO GO INACTIVE.
0787   FD22D013   1229          LD (DSKVSL),IY          ; STORE NEW VECTOR
078B   FDCB0146   1230          BIT 0,(IY+1)            ; TEST TYPE OF RETURN.
078F   2007       1231          JR NZ,FLP
0791   CD9807     1232          CALL FLP                ; RETURN ON COMPLETION IS SPECIFIED,
                  1233                                  ; SO SET IT UP, THEN WAIT FOR COMPLETION
0794   CDE10A     1234          CALL WAIT
0797   C9         1235          RET
                  1236  FLP:                            ; THE ACTUAL DEVICE DRIVER
0798   FD6603     1237          LD H,(IY+3)             ; GET DATA TRANSFER ADDRESS
079B   FD6E02     1238          LD L,(IY+2)
079E   22AB12     1239          LD (BFFADD),HL          ; STORE IT.
07A1   FD6605     1240          LD H,(IY+5)
07A4   FD6E04     1241          LD L,(IY+4)             ; GET DATA LENGTH
07A7   22AD12     1242          LD (BFFLEN),HL
07AA   FD660C     1243          LD H,(IY+12)            ; GET DISK ADDRESS
07AD   FD7E0B     1244          LD A,(IY+11)
07B0   E61F       1245          AND 1FH                 ; MASK TO SECTOR ADDRESS.
07B2   F680       1246          OR 80H                  ; SET LEAD BIT.
07B4   6F         1247          LD L,A
07B5   22B212     1248          LD (DS_BUF),HL          ; STORE IN DISK BUFFER
07B8   7C         1249          LD A,H
07B9   FE4E       1250          CP 78                   ; VALID TRACK ?
07BB   3806       1251          JR C,TRQOK
07BD   FD360AC5   1252          LD (IY+10),TRKERR
07C1   1825       1253          JR FLERR
07C3   32B112     1254  TRQOK:  LD (RQTRK),A            ; STORE TRACK AS THE REQUESTED.
07C6   3E0A       1255          LD A,10                 ; SET CRC RETRY COUNTER.
07C8   32D413     1256          LD (CRCCTR),A
07CB   3E02       1257          LD A,2
07CD   32D513     1258          LD (WSCTR),A            ; SET WRONG SECTOR AND WRONG
07D0   32D613     1259          LD (WTCTR),A            ; TRACK
07D3   FD360A00   1260          LD (IY+10),0
07D7   FD7E01     1261          LD A,(IY+1)             ; GET REQUEST CODE.
07DA   CB87       1262          RES 0,A
07DC   FE0E       1263          CP WRTBIN               ; BINARY WRITE?
07DE   2810       1264          JR Z,CHKSEL
07E0   FE0A       1265          CP RDBIN                ; BINARY READ
07E2   280C       1266          JR Z,CHKSEL
07E4   FD360AC1   1267          LD (IY+10),INV_OP       ; INVALID OPERATION
07E8   210000     1268  FLERR:  LD HL,0                 ; CLEAR  VSL
07EB   22D013     1269          LD (DSKVSL),HL
07EE   1884       1270          JR ERRTN
                  1271
07F0   3E03       1272  CHKSEL: LD A,REST               ; RESET CLOCK TO PREVENT INTERRUPT
07F2   D3D4       1273          OUT (CLK0),A
07F4   DBD1       1274          IN A,(DSKSEL)           ; IS DISK SELECTED?
07F6   E60F       1275          AND 0FH
07F8   6F         1276          LD L,A
07F9   CB9D       1277          RES 3,L
07FB   CB5F       1278          BIT 3,A                 ; ANY DISK SELECTED?
07FD   FD7E0B     1279          LD A,(IY+11)            ; GET REQUESTED UNIT FOR COMPARISON
0800   07         1280          RLCA


FLOPPY DISK ROUTINE           MCZ.PROM.78089                    PAGE  30
 LOC   OBJ CODE M STMT SOURCE STATEMENT                          ASM 5.8

0801   07         1281          RLCA
0802   07         1282          RLCA
0803   280B       1283          JR Z,SELEC
0805   E607       1284          AND 07
0807   BD         1285          CP L                    ; COMPARE TO SELECTED UNIT.
0808   CA1D09     1286          JP Z,CHKHD              ; THE SAME.  CHECK HEAD POSITION.
080B   F5         1287          PUSH AF                 ; SAVE REQUESTED UNIT.
080C   CDF409     1288          CALL UNSEL              ; DESELECT THE CURRENT UNIT.
080F   F1         1289          POP AF
0810   E607       1290  SELEC:  AND 07
0812   21D713     1291          LD HL,CURT0
0815   5F         1292          LD E,A
0816   1600       1293          LD D,0
0818   19         1294          ADD HL,DE               ; FORM INDEX INTO TRACK VECTOR
0819   7E         1295          LD A,(HL)
081A   32DF13     1296          LD (CURTRK),A
081D   7B         1297          LD A,E          ; SELECT THE REQUESTED DISK.
081E   CBDF       1298          SET 3,A
0820   D3D1       1299          OUT (DSKSEL),A
0822   DBD0       1300          IN A, (DSSTAT)          ; CHECK AND MAKE SURE THE
0824   CB6F       1301          BIT READY,A             ; SELECTED DISK IS READY.
0826   280A       1302          JR Z,FLP01
0828   FD360AC2   1303          LD (IY+10),NOTRDY       ; SET NOT READY ERROR
082C   CDEE09     1304          CALL PRMERR
082F   C37407     1305          JP ERRTN
                  1306
0832   3ADF13     1307  FLP01:  LD A,(CURTRK)
0835   FE4E       1308          CP 78                   ; CHECK HEAD POSITION ON THIS DISK.
0837   3807       1309          JR C,HDOKAY
0839   AF         1310          XOR A                   ; HEAD NOT POSITIONED.
083A   32B112     1311          LD (RQTRK),A            ; FORCE SEEK TO TRACK 0 TO
083D   C3400A     1312          JP HDMOV                ;  POSITION.
                  1313
0840   47         1314  HDOKAY: LD B,A
0841   3AB112     1315          LD A,(RQTRK)            ; IS THE CURRENT TRACK OF THE NEWLY
0844   90         1316          SUB B                   ; SELECTED DISK THE SAME AS THE RE-
0845   280A       1317          JR Z,TIME35             ; REQUESTED TRACK?  IF SO, TIME OUT
                  1318                                  ; HEAD SETTLE TIME
0847   3D         1319          DEC A                   ; IF ONLY ONE TRACK DIFFERENCE,
0848   2814       1320          JR Z,TIME7              ; TIME PART OF IT AND LET HEAD
                  1321                                  ; MOVEMENT TAKE CARE OF REST
084A   C602       1322          ADD A,2
084C   2810       1323          JR Z,TIME7
084E   C3400A     1324          JP HDMOV
                  1325
0851   3ED7       1326  TIME35: LD A,CTRMOD             ; SET UP TO COUNT OF 8 SECTOR
0853   D3D4       1327          OUT (CLK0),A            ; HOLES TO GUARANTEE 35 MSEC.
0855   3E08       1328          LD A,8
0857   D3D4       1329          OUT (CLK0),A
0859   210D0A     1330          LD HL,PREPRE
085C   180B       1331          JR LAB101
                  1332
085E   3EB7       1333  TIME7:  LD A,STCLK0
0860   D3D4       1334          OUT (CLK0),A            ; TIME OUT 7 MSEC.
0862   3E43       1335          LD A,TIM7
0864   D3D4       1336          OUT (CLK0),A
0866   21400A     1337          LD HL,HDMOV             ; STORE INTERRUPT ADDRESS.
0869   22AF12     1338  LAB101: LD (INTPNT),HL


FLOPPY DISK ROUTINE           MCZ.PROM.78089                    PAGE  31
 LOC   OBJ CODE M STMT SOURCE STATEMENT                          ASM 5.8

086C   C9         1339          RET
                  1340
                  1341  ; LOCATE  --   FIND OUT WHAT SECTOR IS UNDER HEAD
086D   3AB212     1342  LOCATE: LD A,(RQSECT)           ; GET THE REQUESTED SECTOR.
0870   C621       1343          ADD A,33                ; PREPARE TO FORM MOD 33 DIFFERENCE WITH
                  1344                                  ; CURRENT SECTOR.
0872   67         1345          LD H,A                  ; SAVE IT.
0873   0ECF       1346          LD C,DSKDAT             ; PORT NUMBER FOR INPUT.
0875   3E04       1347          LD A,RD_DAT             ; PREPARE TO READ.
0877   063D       1348          LD B,TM256A
0879   10FE       1349          DJNZ $                  ; TIME OUT 256 USEC BEFORE READING.
087B   D3D0       1350          OUT (DSKCOM),A          ; TURN ON READ CIRCUITRY.
087D   7C         1351          LD A,H
087E   ED60       1352          IN H,(C)                ; READ SECTOR ADDRESS
0880   94         1353          SUB H                   ; FORM DIFFERENCE.
0881   ED60       1354          IN H,(C)                ; READ TRACK NUMBER.
0883   0ED0       1355          LD C,DSKCOM             ; GET COMMAND PORT IN C
0885   ED41       1356          OUT (C),B               ; TURN OFF READ.
0887   FE22       1357          CP 34
0889   3802       1358          JR C,SAVE               ; IF > 34, SUBTRACT 33.
088B   D621       1359          SUB 33
088D   FE22       1360  SAVE:   CP 34           ; IF IT'S STILL GREATER THAN 33, THERE
                  1361                          ; WAS AN ERROR IN THE SECTOR ADDRESS.
088F   D2DA09     1362          JP NC,WRNGSC
0892   0ED4       1363          LD C,CLK0               ; OUTPUT DIFERENCE TO CLOCK.
0894   2ED7       1364          LD L,CTRMOD
0896   ED69       1365          OUT (C),L
0898   ED79       1366          OUT (C),A
089A   3AB312     1367          LD A,(DS_BUF+1)         ; GET REQUESTED TRACK NUMBER.
089D   BC         1368          CP H                    ; COMPARE READ TRACK.
089E   C2250A     1369          JP NZ,WRNGTK            ; IF WRONG, TRY RESEEK.
08A1   FD7E01     1370          LD A,(IY+1)
08A4   CB87       1371          RES 0,A
08A6   21B508     1372          LD HL,WRTSEC            ; SET FOR WRITE.
08A9   FE0E       1373          CP WRTBIN               ; WRITE REQUEST?
08AB   22AF12     1374  WRTSET: LD (INTPNT),HL
08AE   C8         1375          RET Z
08AF   213909     1376          LD HL,RDSECT            ; SET FOR READ
08B2   BF         1377          CP A                    ; SET ZERO FLAG
08B3   18F6       1378          JR WRTSET
                  1379
                  1380
                  1381
08B5   3E08       1382  WRTSEC: LD A,WRDAT              ; TURN ON WRITE ELECTRONICS.
08B7   D3D0       1383          OUT (DSKCOM),A
08B9   DBD1       1384          IN A,(DSKSEL)           ; CHECK WRITE PROTECT STATUS.
08BB   CB7F       1385          BIT WRTPTC,A
08BD   2027       1386          JR NZ,WRTOK
08BF   AF         1387          XOR A                   ; TURN OFF WRITE AMP.
08C0   D3D0       1388          OUT (DSKCOM),A
08C2   FD360AC3   1389          LD (IY+10),PROTEC       ; SET PROTECT ERROR
08C6   C3EE09     1390          JP PRMERR
                  1391
                  1392
08C9   3ED7       1393  PREPAR: LD A,CTRMOD             ; INTERRUPT AT NEXT SECTOR.
08CB   D3D4       1394          OUT (CLK0),A
08CD   3E01       1395          LD A,1
08CF   D3D4       1396          OUT (CLK0),A


FLOPPY DISK ROUTINE           MCZ.PROM.78089                    PAGE  32
 LOC   OBJ CODE M STMT SOURCE STATEMENT                          ASM 5.8

08D1   216D08     1397          LD HL,LOCATE            ; ON NEXT INTERRUPT, GO TO LOCATE.
08D4   22AF12     1398          LD (INTPNT),HL
08D7   C9         1399          RET
                  1400
                  1401
                  1402
                  1403          COND $>8DBH
                  1404          ERROR - ADDRESS DISPLACEMENT
                  1405          ENDC
08DB              1406          ORG 8DBH
08DB   C3F409     1407          JP UNSEL
                  1408
                  1409
08DE   CDF409     1410  DSELEC: CALL UNSEL
08E1   E1         1411          POP HL
08E2   C1         1412          POP BC
08E3   C3B70A     1413          JP NOCMP
                  1414
                  1415
08E6   01CF82     1416  WRTOK:  LD BC,8200H+DSKDAT
08E9   2AAB12     1417          LD HL,(BFFADD)          ; GET USER DATA ADDRESS.
08EC   E5         1418          PUSH HL
08ED   21B212     1419          LD HL,DS_BUF            ; ADDRESS OF SECTOR ADDRESS.
08F0   3E49       1420          LD A,TIM512             ; TIME OUT 512 USECS. FOR PREAMBLE.
                  1421
                  1422  ; 229 T-STATES FROM INTERRUPT
                  1423
08F2   3D         1424          DEC A
08F3   20FD       1425          JR NZ,$-1
                  1426
                  1427  ; 568 USECS FROM INTERRUPT
                  1428
08F5   EDA3       1429          OUTI
08F7   EDA3       1430          OUTI
08F9   E1         1431          POP HL                  ; GET BACK DATA ADDRESS.
08FA   EDA3       1432  WRITIT: OUTI                    ; OUTPUT THE DATA.
08FC   00         1433          NOP                     ; INCREASE REFRESH RATE
08FD   00         1434          NOP
08FE   00         1435          NOP
08FF   20F9       1436          JR NZ,WRITIT
0901   21B412     1437          LD HL,PTRS              ; LOAD ADDRESS OF POINTERS.
0904   EDA3       1438          OUTI
0906   EDA3       1439          OUTI
0908   EDA3       1440          OUTI
090A   3E18       1441          LD A, WRCRC             ; WRITE CRC ENABLE
090C   EDA3       1442          OUTI                    ; OUTPUT LAST POINTER
090E   D3D0       1443          OUT (DSKCOM),A          ; ENABLE CRC
0910   D3CF       1444          OUT (DSKDAT),A          ; OUTPUT TWO CRC WORDS.
0912   D3CF       1445          OUT (DSKDAT),A
0914   AF         1446          XOR A                   ; CLEAR A
0915   D3CF       1447          OUT (DSKDAT),A
0917   D3CF       1448          OUT (DSKDAT),A
0919   D3D0       1449          OUT (DSKCOM),A
091B   1850       1450          JR FINOP
                  1451
                  1452
                  1453
091D   3ADF13     1454  CHKHD:  LD A,(CURTRK)           ; CHECK HEAD POSITION BEFORE


FLOPPY DISK ROUTINE           MCZ.PROM.78089                    PAGE  33
 LOC   OBJ CODE M STMT SOURCE STATEMENT                          ASM 5.8

0920   21B312     1455          LD HL,DS_BUF+1          ; MOVING HEAD
0923   BE         1456          CP (HL)
0924   C2400A     1457          JP NZ,HDMOV
0927   CD0D0A     1458          CALL PREPRE             ;START LOCATE SEQUENCE
092A   FDCB0A7E   1459          BIT CMP,(IY+10)
092E   C8         1460          RET Z
092F   FDCB0A76   1461          BIT 6,(IY+10)
0933   C27407     1462          JP NZ,ERRTN
0936   C39606     1463          JP IORET
                  1464
                  1465
                  1466
0939   2AAB12     1467  RDSECT: LD HL,(BFFADD)          ; GET USER DATA AREA.
093C   E5         1468          PUSH HL
093D   21B212     1469          LD HL,DS_BUF            ; ADDRESS OF SECTOR ADDRESS.
0940   3E04       1470          LD A,RD_DAT             ; PREPARE TO TURN ON READ AMP.
0942   063D       1471          LD B,TIM256
                  1472
                  1473  ;       175 T-STATES FROM INTERRUPT
                  1474
0944   10FE       1475          DJNZ $                  ; TIME OUT
0946   D3D0       1476          OUT (DSKCOM),A
0948   01CF80     1477          LD BC,8000H+DSKDAT
                  1478
                  1479  ; 400 USECS FROM INTERRUPT
                  1480
094B   DBCF       1481          IN A,(DSKDAT)           ; INPUT SECTOR ADDRESS.
094D   BE         1482          CP (HL)                 ; COMPARE IT.
094E   E1         1483          POP HL                  ; GET DATA ADDRESS.
094F   DBCF       1484          IN A,(DSKDAT)           ; INPUT TRACK ADDRESS.
0951   C2DA09     1485          JP NZ,WRNGSC
0954   EDA2       1486  READIT: INI
0956   00         1487          NOP                     ; INCREASE REFRESH RATE
0957   00         1488          NOP
0958   00         1489          NOP
0959   20F9       1490          JR NZ,READIT
095B   21B412     1491          LD HL,PTRS              ; INPUT THE POINTERS.
095E   EDA2       1492          INI
0960   0605       1493          LD B,5
0962   EDB2       1494          INIR
0964   DBD0       1495          IN A,(DSSTAT)           ; CHECK FOR CRC ERROR.
0966   CB7F       1496          BIT CRC,A
0968   78         1497          LD A,B                  ; SET A TO ZERO TO
0969   D3D0       1498          OUT (DSKCOM),A          ; TURN OFF READ.
096B   205A       1499          JR NZ,BADCRC
096D   2AAD12     1500  FINOP:  LD HL,(BFFLEN)
0970   018000     1501          LD BC,BLKSIZ            ; MORE BYTES?
0973   A7         1502          AND A
0974   ED42       1503          SBC HL,BC
0976   22AD12     1504          LD (BFFLEN),HL
0979   2820       1505          JR Z,OPCMP
097B   381E       1506          JR C,OPCMP
097D   2AAB12     1507          LD HL,(BFFADD)
0980   09         1508          ADD HL,BC
0981   22AB12     1509          LD (BFFADD),HL
0984   3E0A       1510          LD A,10                 ; RESET RETRY COUNTERS.
0986   32D413     1511          LD (CRCCTR),A
0989   3E02       1512          LD A,2


FLOPPY DISK ROUTINE           MCZ.PROM.78089                    PAGE  34
 LOC   OBJ CODE M STMT SOURCE STATEMENT                          ASM 5.8

098B   32D513     1513          LD (WSCTR),A
098E   21B212     1514          LD HL,DS_BUF            ; INCREMENT SECTOR NUMBER.
0991   34         1515          INC (HL)
0992   3ED7       1516          LD A,CTRMOD             ; SET TO INTERRUPT NEXT SECTIOR
0994   D3D4       1517          OUT (CLK0),A
0996   3E01       1518          LD A,1
0998   D3D4       1519          OUT (CLK0),A
099A   C9         1520          RET
                  1521
099B   FD360A80   1522  OPCMP:  LD (IY+10),OPCOMP
099F   3ED7       1523          LD A,CTRMOD             ; OPERATION COMPLETED.  SET
09A1   D3D4       1524          OUT (CLK0),A            ; FOR INTERRUPT IN HALF REVOLUTION.
09A3   3E10       1525          LD A,16
09A5   D3D4       1526          OUT (CLK0),A            ; IF NO OTHER REQUEST BY THEN,
09A7   21DE08     1527          LD HL,DSELEC            ; DESELECT.
09AA   22AF12     1528          LD (INTPNT),HL
09AD   210000     1529  OPFIN:  LD HL,0
09B0   22D013     1530          LD (DSKVSL),HL
09B3   FD6605     1531          LD H,(IY+5)
09B6   FD6E04     1532          LD L,(IY+4)
09B9   ED4BAD12   1533          LD BC,(BFFLEN)
09BD   A7         1534          AND A
09BE   ED42       1535          SBC HL,BC               ; FIND NUMBER OF BYTES TRANSFERRED
09C0   FD7405     1536          LD (IY+5),H
09C3   FD7504     1537          LD (IY+4),L
09C6   C9         1538          RET
                  1539
09C7   2A9313     1540  BADCRC: LD HL,(NCRCE)           ; COUNT CRC ERROR TOTAL
09CA   23         1541          INC HL
09CB   229313     1542          LD (NCRCE),HL
09CE   21D413     1543          LD HL,CRCCTR            ; ADDRESS OF CRC RETRY COUNTER.
09D1   35         1544          DEC (HL)
09D2   2039       1545          JR NZ,PREPRE            ; GO AND TRY AGAIN.
09D4   FD360AC6   1546          LD (IY+10),CRCERR
09D8   1814       1547          JR PRMERR
                  1548
09DA   AF         1549  WRNGSC: XOR A                   ; TURN OFF READ AMP
09DB   D3D0       1550          OUT (DSKCOM),A
09DD   2A9513     1551          LD HL,(NSECTE)          ; COUNT SECTOR ERRORS
09E0   23         1552          INC HL
09E1   229513     1553          LD (NSECTE),HL
09E4   21D513     1554          LD HL,WSCTR             ; WRONG SECTOR RETRY COUNTER.
09E7   35         1555          DEC (HL)
09E8   2023       1556          JR NZ,PREPRE            ; GO BACK AND TRY TO RELOCATE SECTOR.
09EA   FD360AC4   1557          LD (IY+10),SECTER
09EE   CDF409     1558  PRMERR: CALL UNSEL              ; DESELECT DISK
09F1   C3AD09     1559          JP OPFIN
                  1560
09F4   3E0B       1561  UNSEL:  LD A,RSTCLK
09F6   D3D4       1562          OUT (CLK0),A
09F8   DBD1       1563          IN A,(DSKSEL)           ; FIND OUT WHICH DISK IS SELECTED.
09FA   CB5F       1564          BIT 3,A                 ; SEE IF ANY DISK IS SELECTED.
09FC   C8         1565          RET Z
09FD   E607       1566          AND 07H
09FF   D3D1       1567          OUT (DSKSEL),A          ; DESELECT IT.
0A01   4F         1568          LD C,A
0A02   0600       1569          LD B,0
0A04   21D713     1570          LD HL,CURT0


FLOPPY DISK ROUTINE           MCZ.PROM.78089                    PAGE  35
 LOC   OBJ CODE M STMT SOURCE STATEMENT                          ASM 5.8

0A07   09         1571          ADD HL,BC
0A08   3ADF13     1572          LD A,(CURTRK)
0A0B   77         1573          LD (HL),A               ; STORE CURRENT TRACK INTO CURT FOR CORRECT DISK.
0A0C   C9         1574          RET
                  1575
0A0D   FD7E04     1576  PREPRE: LD A,(IY+4)             ; CHECK FOR ZERO LENGTH
0A10   FDB605     1577          OR (IY+5)
0A13   CA9B09     1578          JP Z,OPCMP
0A16   3EAF       1579          LD A,TRIG0              ; PREPARE TO PREPARE TO LOCATE
0A18   D3D4       1580          OUT (CLK0),A            ; THE CORRECT SECTOR.
0A1A   3E1B       1581          LD A,SECT/2+2           ; TIME OUT 1/2 SETCTOR+ A LITTLE.
0A1C   D3D4       1582          OUT (CLK0),A
0A1E   21C908     1583          LD HL,PREPAR            ; ON INTERRUPT GO TO PREPARE.
0A21   22AF12     1584          LD (INTPNT),HL
0A24   C9         1585          RET
                  1586
0A25   2A9113     1587  WRNGTK: LD HL,(NTRKE)           ; COUNT SEEK ERRORS
0A28   23         1588          INC HL
0A29   229113     1589          LD (NTRKE),HL
0A2C   21D613     1590          LD HL,WTCTR             ; WRONG TRACK RETRY COUNTER.
0A2F   35         1591          DEC (HL)                ; SEE IF THERE HAVE BEEN TOO MANY TRIES.
0A30   2006       1592          JR NZ,LAB102
0A32   FD360AC5   1593          LD (IY+10),TRKERR
0A36   18B6       1594          JR PRMERR
                  1595
0A38   AF         1596  LAB102: XOR A                   ; CLEAR A.
0A39   32B112     1597          LD (RQTRK),A            ; FORCE SEEK TO TRACK 0.
0A3C   CD400A     1598          CALL HDMOV
0A3F   C9         1599          RET
                  1600
0A40   AF         1601  HDMOV:  XOR A
0A41   47         1602          LD B,A                  ; CLEAR INSTRUCTION WORD.
0A42   0ED0       1603          LD C,DSKCOM
0A44   3AB112     1604          LD A,(RQTRK)            ; GET REQUESTED TRACK TO SEE IF WE'RE THERE.
0A47   A7         1605          AND A                   ; IS IT ZERO?
0A48   2829       1606          JR Z,STRK0              ; USE DIFFERENT POSITION CRITERIA
                  1607                                  ; FOR TRACK 0.
0A4A   21DF13     1608  SK:     LD HL,CURTRK            ; ADDRESS OF CURRENT TRACK COUNTER.
0A4D   BE         1609          CP (HL)
0A4E   2833       1610          JR Z,POS                ; IF EQUAL, THE HEAD IS POSITIONED.
0A50   3805       1611          JR C,BIGGER             ; IF CURRENT TRACK IS BIGGER THAN
                  1612                                  ; REQUESTED TRACK, MOVE OUTWARD.
0A52   34         1613          INC (HL)                ; INCREMENT CURRENT TRACK.
0A53   CBC0       1614          SET DIRECT,B            ; SET TO STEP IN.
0A55   1801       1615          JR BIGG01
0A57   35         1616  BIGGER: DEC (HL)                ; DECREMENT CURRENT TRACK
0A58   ED41       1617  BIGG01: OUT (C),B
0A5A   CBC8       1618          SET HDSTEP,B
0A5C   ED41       1619          OUT (C),B               ; OUTPUT THE STEP PULSE.
                  1620  BIGG03:
0A5E   E3         1621          EX (SP),HL              ; DELAY
0A5F   E3         1622          EX (SP),HL
0A60   CB88       1623          RES HDSTEP,B            ; OUTPUT STEP TRAILING EDGE.
0A62   ED41       1624          OUT (C),B
0A64   3EB7       1625          LD A,STCLK0
0A66   D3D4       1626          OUT (CLK0),A            ; TIME OUT 8 MSEC TO MOVE HEAD AGAAIN.
0A68   3E4D       1627          LD A,MS08
0A6A   D3D4       1628          OUT (CLK0),A


FLOPPY DISK ROUTINE           MCZ.PROM.78089                    PAGE  36
 LOC   OBJ CODE M STMT SOURCE STATEMENT                          ASM 5.8

0A6C   21400A     1629          LD HL,HDMOV
0A6F   22AF12     1630          LD (INTPNT),HL          ; STORE INTERRUPT ADDRESS.
0A72   C9         1631          RET
                  1632
0A73   DBD0       1633  STRK0:  IN A,(DSSTAT)           ; CHECK THE TRACK 0 LINE.
0A75   CB77       1634          BIT T0,A                ; IS IT THERE?
0A77   2806       1635          JR Z, POS0
0A79   CBC8       1636          SET HDSTEP,B
0A7B   ED41       1637          OUT (C),B               ; OUTPUT THE STEP COMMAND
0A7D   18DF       1638          JR BIGG03
                  1639
0A7F   AF         1640  POS0:   XOR A                   ; CLEAR CURRENT TRACK COUNTER.
0A80   32DF13     1641          LD (CURTRK),A
0A83   3ADF13     1642  POS:    LD A,(CURTRK)           ; GET CURRENT TRACK.
0A86   47         1643          LD B,A                  ; SAVE IT.
0A87   3AB312     1644          LD A,(DS_BUF+1)         ; GET TRACK NUMBER OF DISK ADDRESS.
0A8A   32B112     1645          LD (RQTRK),A
0A8D   B8         1646          CP B                    ; RIGHT?
0A8E   20B0       1647          JR NZ,HDMOV
0A90   3EB7       1648          LD A,STCLK0
0A92   D3D4       1649          OUT (CLK0),A            ; START TIMEOUT 18 MSEC.
0A94   3EAC       1650          LD A,MS18
0A96   D3D4       1651          OUT (CLK0),A
0A98   210D0A     1652          LD HL,PREPRE            ; IF READ OR WRITE, GO TO PREPRE
0A9B   22AF12     1653          LD (INTPNT),HL
0A9E   C9         1654          RET
                  1655  ; INTERRUPT ENTRY POINT
                  1656
0A9F   E5         1657  RTC0:   PUSH HL
0AA0   F5         1658          PUSH AF
0AA1   FDE5       1659          PUSH IY
0AA3   FD2AD013   1660          LD IY,(DSKVSL)
0AA7   C5         1661          PUSH BC
0AA8   21B00A     1662          LD HL,RTNPNT            ; PUSH RETURN POINT FOR RETURN.
0AAB   E5         1663          PUSH HL
0AAC   2AAF12     1664          LD HL,(INTPNT)
0AAF   E9         1665          JP (HL)                 ; GO TO APPROPRIATE ROUTINE.
                  1666
                  1667  ; 124 T-STATES FROM INTERRUPT
                  1668
0AB0   C1         1669  RTNPNT: POP BC
0AB1   FDCB0A7E   1670          BIT CMP,(IY+10)         ; IS OPERATION COMPLETE?
0AB5   2007       1671          JR NZ,CMPRET
0AB7   FDE1       1672  NOCMP:  POP IY
0AB9   F1         1673          POP AF
0ABA   E1         1674          POP HL
0ABB   FB         1675          EI                      ; ENABLE INTERRUPTS.
0ABC   ED4D       1676          RETI
                  1677
0ABE   FDCB0A76   1678  CMPRET: BIT 6,(IY+10)           ; OPERATION IS COMPLETE.
0AC2   280A       1679          JR Z,NOER               ; ERROR ?
0AC4   FD6609     1680          LD H,(IY+9)
0AC7   FD6E08     1681          LD L,(IY+8)
0ACA   7C         1682          LD A,H                  ; CHECK FOR A ZERO ADDRESS.
0ACB   B5         1683          OR L
0ACC   200C       1684          JR NZ,FRET
0ACE   FDCB0146   1685  NOER:   BIT 0,(IY+1)
0AD2   28E3       1686          JR Z,NOCMP


FLOPPY DISK ROUTINE           MCZ.PROM.78089                    PAGE  37
 LOC   OBJ CODE M STMT SOURCE STATEMENT                          ASM 5.8

0AD4   FD6607     1687          LD H,(IY+7)             ; GET COMPLETION RETURN ADDRESS
0AD7   FD6E06     1688          LD L,(IY+6)
0ADA   FDE1       1689  FRET:   POP IY
0ADC   F1         1690          POP AF
0ADD   E3         1691          EX (SP),HL              ; RESTORE HL AND PUT CRA ON STACK.
0ADE   FB         1692          EI
0ADF   ED4D       1693          RETI
                  1694
                  1695
                  1696  WAIT:                           ; I/O WAIT ROUTINE
0AE1   FDCB0A7E   1697          BIT CMP,(IY+10)
0AE5   28FA       1698          JR Z,WAIT
0AE7   C9         1699          RET
                  1700
                  1701
                  1702
                  1703
                  1704  ;       ERROR CODES
                  1705  SECTER  EQU     0C4H
                  1706  TRKERR  EQU     0C5H
                  1707  CRCERR  EQU     0C6H
                  1708
                  1709  ;       CONTROL WORDS
                  1710  REST    EQU     03
                  1711  STCLK0  EQU     10110111B
                  1712  CTRMOD  EQU     11010111B
                  1713  TRIG0   EQU     10101111B
                  1714  RSTCLK  EQU     00001011B
                  1715  RD_DAT  EQU     04H
                  1716  WRDAT   EQU     08H
                  1717  WRCRC   EQU     18H
                  1718  HDSTEP  EQU     1
                  1719  DIRECT  EQU     0
                  1720  READY   EQU     5
                  1721  T0      EQU     6
                  1722  CMP     EQU     7
                  1723  CRC     EQU     7
                  1724  WRTPTC  EQU     7
                  1725  ;       TIMING CONTSTNS
                  1726  TIM7    EQU     67
                  1727  SECT    EQU     50
                  1728  MS08    EQU     77
                  1729  MS18    EQU     172
                  1730  TIM256  EQU     61
                  1731  TM256A  EQU     61
                  1732  TIM512  EQU     73
                  1733
                  1734  *I MCZTAB
0B34              1735    ORG 0B34H
                  1736
                  1737
0B34   12534552   1738  BOOTMS: DEFT 'SERIAL PORT INPUT '
0B46              1739          ORG $-1
0B46   0D         1740     DEFB ASCICR
0B47   09         1741  BRKMSG: DEFB LBREAK-1
0B48   42524541   1742     DEFM 'BREAK AT '
                  1743  LBREAK EQU $-BRKMSG
                  1744


FLOPPY DISK ROUTINE           MCZ.PROM.78089                    PAGE  38
 LOC   OBJ CODE M STMT SOURCE STATEMENT                          ASM 5.8

                  1745
                  1746          COND $>0B51H
                  1747          ERROR - ADDRESS DISPLACEMENT
                  1748          ENDC
0B51              1749          ORG 0B51H
                  1750
0B51   0B         1751  DSKER: DEFB LDSKER-1
0B52   4449534B   1752     DEFM 'DISK ERROR'
0B5C   0D         1753     DEFB ASCICR
                  1754  LDSKER EQU $-DSKER
0B5D   60         1755  RATTAB DEFB 96;   50 BAUD
0B5E   40         1756     DEFB 64;  75 BAUD
0B5F   2C         1757     DEFB 44;  110 BAUD
0B60   24         1758     DEFB 36;  134.5 BAUD
0B61   20         1759     DEFB 32;  150 BAUD
0B62   18         1760     DEFB 24;  200 BAUD
0B63   10         1761     DEFB 16;  300 BAUD
0B64   08         1762     DEFB 8;   600 BAUD
0B65   04         1763     DEFB 4;   1200 BAUD
0B66   02         1764     DEFB 2;   2400 BAUD
0B67   01         1765     DEFB 1;   4800 BAUD
0B68   04         1766     DEFB 4;   9600 BAUD (COUNTER MODE)
0B69   02         1767     DEFB 2;   19.2 KBAUD (COUNTER MODE)
0B6A   01         1768     DEFB 1;   38.4 KBAUD (COUNTER MODE)
                  1769
                  1770  INITPM:;  INITIAL VALUES FOR STORAGE
0B6B   0311       1771     DEFW CONOBF;
0B6D   00         1772     DEFB 0; NULLCT
0B6E   01         1773     DEFB 1; LFCNT;
0B6F   3E         1774     DEFB '>'; PROMPT
0B70   7F         1775     DEFB 7FH;   LINE DELETE CHARACTER
0B71   08         1776     DEFB 08H;   CHARACTER DELETE CHARACTER.
0B72   00         1777     DEFB 0;
0B73   0000       1778     DEFW 0;
0B75   0000       1779     DEFW 0; DSKVSL
0B77   0000       1780     DEFW 0; BRKADR
0B79   0A         1781     DEFB 10;  CRC RETRY
0B7A   02         1782     DEFB 2;   WRONG SECTOR RETRY
0B7B   02         1783     DEFB 2; WRONG TRACK RETRY
0B7C   FFFF       1784     DEFW -1;  CURRENT TRACK POSITIONS
0B7E   FFFF       1785     DEFW -1;
0B80   FFFF       1786     DEFW -1;
0B82   FFFF       1787     DEFW -1;
0B84   FF         1788     DEFB -1;
0B85   9F0A       1789     DEFW RTC0;  DISK INTERRUPT VECTOR
                  1790  PARMCT EQU $-INITPM;
0B87   41204220   1791  RGSTRS DEFM 'A B C D E F H L I A''B''C''D'''
0BA1   45274627   1792     DEFM 'E''F''H''L''IXIYPCSP'
                  1793  REGTAB:
0BB1   C4         1794     DEFB AF_+1&0FFH
0BB2   C6         1795     DEFB BC_+1&0FFH;
0BB3   C5         1796     DEFB BC_&0FFH;
0BB4   C8         1797     DEFB DE_+1&0FFH
0BB5   C7         1798     DEFB DE_&0FFH;
0BB6   C3         1799     DEFB AF_&0FFH;
0BB7   C0         1800     DEFB HL_+1&0FFH;
0BB8   BF         1801     DEFB HL_&0FFH;
0BB9   C2         1802     DEFB I_&0FFH;


FLOPPY DISK ROUTINE           MCZ.PROM.78089                    PAGE  39
 LOC   OBJ CODE M STMT SOURCE STATEMENT                          ASM 5.8

0BBA   CA         1803     DEFB DE_+3&0FFH;
0BBB   CC         1804     DEFB DE_+5&0FFH;
0BBC   CB         1805     DEFB DE_+4&0FFH;   C'
0BBD   CE         1806     DEFB DE_+7&0FFH;   D'
0BBE   CD         1807     DEFB DE_+6&0FFH;   E'
0BBF   C9         1808     DEFB DE_+2&0FFH;   F'
0BC0   D0         1809     DEFB DE_+9&0FFH;
0BC1   CF         1810     DEFB DE_+8&0FFH;
0BC2   D1         1811     DEFB IX_&0FFH;
0BC3   D3         1812     DEFB IY_&0FFH;
0BC4   D5         1813     DEFB PC_&0FFH;
0BC5   D7         1814     DEFB SAVSTK&0FFH;
                  1815  INIOUT:
0BC6   DF         1816     DEFB SERCON;
0BC7   00         1817     DEFB 0;
0BC8   DF         1818     DEFB SERCON;
0BC9   00         1819     DEFB 0;
0BCA   DF         1820     DEFB SERCON;
0BCB   00         1821     DEFB 0;
0BCC   DF         1822     DEFB SERCON;
0BCD   40         1823     DEFB 40H     ; INTERNAL RESET, ENTER MODE INSTRUCTION FORMAT
0BCE   DF         1824     DEFB SERCON;
0BCF   CE         1825     DEFB 0CEH    ; 2 STOP BITS, DISABLE PARITY, 8 DATA BITS, 16X BAUD RATE
0BD0   DF         1826     DEFB SERCON;
0BD1   37         1827     DEFB 37H     ; RTS, ERROR RESET, RECEIVE ENABLE, DTR, TRANSMIT ENABLE
0BD2   D4         1828     DEFB CLK0;
0BD3   E0         1829     DEFB (DSKVEC.SHL.8)/256
0BD4   D3         1830     DEFB DSKSEL+2;
0BD5   CF         1831     DEFB 0CFH;
0BD6   D3         1832     DEFB DSKSEL+2;
0BD7   E0         1833     DEFB 0E0H;
0BD8   D2         1834     DEFB DSKCOM+2;
0BD9   CF         1835     DEFB 0CFH;
0BDA   D2         1836     DEFB DSKCOM+2;
0BDB   E0         1837     DEFB 0E0H;
                  1838  OUTCNT EQU ($-INIOUT)/2;
                  1839
                  1840
                  1841  ; SYSTEM HOOKS   ....   MUST STAY AT 0BE8H
                  1842
                  1843          COND $>0BE8H
                  1844          ERROR - ADDRESS DISPLACEMENT
                  1845          ENDC
0BE8              1846          ORG 0BE8H
                  1847
                  1848
0BE8   C37E06     1849  PCON:   JP TTY
0BEB   C35804     1850          JP GET
0BEE   C34905     1851          JP PUT
0BF1   C35D05     1852          JP PUTMSG
0BF4   C39604     1853          JP GETCHR
0BF7   C3DC00     1854          JP COMD?
0BFA   C34D01     1855  PDEBUG: JP DBGRET
0BFD   C38007     1856  FLOPPY: JP FLOPY
                  1857
                  1858  *I MCZRAM
                  1859  SYSIO EQU 1403H;   SYSTEM IO ENTRY
1100              1860     ORG 1100H;


FLOPPY DISK ROUTINE           MCZ.PROM.78089                    PAGE  40
 LOC   OBJ CODE M STMT SOURCE STATEMENT                          ASM 5.8

                  1861  STACK EQU $;
1100              1862  XINT DEFS 2
1102              1863  DUMMYO DEFS 1
1103              1864  CONOBF DEFS 133
1188              1865  DUMMYI DEFS 1
1189              1866  CONIBF DEFS 255
1288              1867  CONOVC DEFS 11
1293              1868  CONIVC DEFS 11
129E              1869  DSKVC DEFS 13
12AB              1870  BFFADD DEFS 2;   BUFFER ADDRESS STORAGE
12AD              1871  BFFLEN DEFS 2;   BUFFER LENGTH STORAGE
12AF              1872  INTPNT DEFS 2;   NEXT INTERRUPUT ADDRESS
12B1              1873  RQTRK  DEFS 1;   REQUESTED TRACK POSITION
12B2              1874  DS_BUF   DEFS 2;   DISK ADDRESS BUFFER
                  1875     RQSECT:  EQU DS_BUF
                  1876  PTRS
12B4              1877  BCKPTR DEFS 2
12B6              1878  FORPTR DEFS 2
12B8              1879  CRCBUF DEFS 2
                  1880  ;
12BA              1881  INS     DEFS 1;  INSTRUCTION BYTE FOR FIRST BREAK
12BB              1882  N_      DEFS 1;  REPETITION FOR FIRST BREAK
12BC              1883  EIADDR DEFS 2;  ADDRESS OF INSTRUCTION REPLACED BY EI
12BE              1884  EIINST DEFS 1;  INSTRUCTION REPLACED BY EI;
                  1885  STATUS:
12BF              1886  HL_    DEFS 2
12C1              1887  INT DEFS 1
12C2              1888  I_    DEFS 1
12C3              1889  AF_   DEFS 2;  REGISTER SAVE AREA
12C5              1890  BC_   DEFS 2;
12C7              1891  DE_   DEFS 2
12C9              1892        DEFS 8
12D1              1893  IX_  DEFS 2
12D3              1894  IY_   DEFS 2
12D5              1895  PC_   DEFS 2
12D7              1896  SAVSTK DEFS 2
12D9              1897  TINT DEFS 2
                  1898
                  1899          COND $>1300H
                  1900          ERROR - INTERRUPT VECTOR SPACE OVERLAY
                  1901          ENDC
                  1902
                  1903
                  1904
1391              1905     ORG 1391H;
                  1906
1391              1907  NTRKE:  DEFS    2
1393              1908  NCRCE:  DEFS    2
1395              1909  NSECTE: DEFS    2
                  1910
                  1911
                  1912  ; RESTART INSTRUCTION VECTOR RST 1 - RST 6
                  1913
1397              1914  RST1:   DEFS    3
139A              1915  RST2:   DEFS    3
139D              1916  RST3:   DEFS    3
13A0              1917  RST4:   DEFS    3
13A3              1918  RST5:   DEFS    3


FLOPPY DISK ROUTINE           MCZ.PROM.78089                    PAGE  41
 LOC   OBJ CODE M STMT SOURCE STATEMENT                          ASM 5.8

13A6              1919  RST6:   DEFS    3
                  1920
13A9              1921  USRSTK  DEFS    2
13AB              1922  DATE DEFS 6;   STORAGE FOR DATE
13B1              1923  TIME DEFS 6;
13B7              1924  TICKER: DEFS    1       ; CLOCK TICKER
13B8              1925  ETIME:  DEFS    5       ; ELAPSED TIME
13BD              1926  ERCODE DEFS 1;   RETURN CODES FROM USER PROGRAMS
13BE              1927  EXTRET DEFS 2;   EXTERNAL RETURN ADDRESS
13C0              1928  MEMTOP DEFS 2
13C2              1929  MEMBOT DEFS 2
13C4              1930  INPTR DEFS 2
                  1931  PARMS:;  THIS AREA IS INITIALIZED.
13C6              1932  OUTPTR DEFS 2
13C8              1933  NULLCT DEFS 1
13C9              1934  LFCNT DEFS 1
13CA              1935  PROMPT DEFS 1
13CB              1936  LINDEL DEFS 1
13CC              1937  CHRDEL DEFS 1
13CD              1938  BRKFLG DEFS 1;
13CE              1939  BRKRTN DEFS 2;
13D0              1940  DSKVSL DEFS 2
13D2              1941  BRKADR  DEFS 2;  ADDRESS OF FIRST BREAK SET
13D4              1942  CRCCTR DEFS 1
13D5              1943  WSCTR DEFS 1
13D6              1944  WTCTR DEFS 1
13D7              1945  CURT0 DEFS 8
13DF              1946  CURTRK DEFS 1
13E0              1947     ORG 13E0H;  INTERRUPT JUMPTABLE
13E0              1948  DSKVEC  DEFS    2               ; CHANNEL 0
13E2              1949          DEFS    2               ; CHANNEL 1
13E4              1950  RTCVEC  DEFS    2               ; CHANNEL 2 (RTC)
13E6              1951  BRKJMP  DEFS    2               ; JUMP LOCATION FOR BREAK PORT
                  1952
                  1953          END
				  