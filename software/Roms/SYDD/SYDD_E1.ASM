*** 	SYDD - System Device Driver    
*	Author: JG Letwin, Oct 1977    
*	Transcribed by Bob Groh August 2009    
*	SYDD is a system device driver for H17mini-floppy      
*	This file is the complete transcription of the entire orignal SYDD listing file (in  pdf format)    
*	Editor: Notepad++    
*	Format: pure text format with TAB delimiters    
*	Revision Table    
*	Version	Date	Author	Description    
*	1.0	8/12/09	Bob Groh	Completed and combined whole listing    
*	E1	9/31/09 Dan Emrick	Assembled on H89, changes documented in
*					SYDD_E1_CHG.TXT
*	    
*    

****	Assembly Constants    
MI.CPI	EQU	376Q	CPI Instruction    
ERPTCNT	EQU	10	Soft Error Retry Count    

*	XTEXT	MTR    
*	MTR - PAM/8 EQUIVALENCES.   
*   
*	THIS DECK CONTAINS SYMBOLIC DEFINITIONS USED TO   
*	MAKE USE OF THE PAM/8 CODE AND CONTROL BYTES.   
	SPACE	3,10   
**	IO PORTS   

IP.PAD	EQU	360Q		PAD INPUT PORT   
OP.CTL	EQU	360Q		CONTROL OUTPUT PORT   
OP.DIG	EQU	360Q		DIGIT SELECT OUTPUT PORT   
OP.SEG	EQU	361Q		SEGMENT SELECT OUTPUT PORT   

**	FRONT PANEL CONTROL BITS.   

CB.SSI	EQU	00010000B	SINGLE STEP INTERRUPT   
CB.MTL	EQU	00100000B	MONITOR LIGHT   
CB.CLI	EQU	01000000B	CLOCK INTERRUPT ENABLE   
CB.SPK	EQU	10000000B	SPEAKER ENABLE   
**	MONITOR MODE FLAGS.   

DM.MR	EQU	0		MEMORY READ   
DM.MW	EQU	1		MEMORY WRITE   
DM.RR	EQU	2		REGISTER READ   
DM.RW	EQU	3		REGISTER WRITE   
**	USER OPTION BITS.   
*   
*	THESE BITS ARE SET IN CELL .MFLAG.   

UO.HLT	EQU	10000000B	DISABLE HALT PROCESSING   
UO.NFR	EQU	CB.CLI		NO REFRESH OF FRONT PANEL   
UO.DDU	EQU	00000010B	DISABLE DISPLAY UPDATE   
UO.CLK	EQU	00000001B	ALLOW PRIVATE INTERRUPT PROCESSING   

**	MONITOR IDENTIFICATION FLAGS   
*   
*	THESE BYTES IDENTIFY THE ROM MONITOR.   
*	THEY ARE THE VARIOUS VALUES OF LOCATION .IDENT   

M.PAM8	EQU	021Q		'LXI' INSTRUCTION AT 000.000 IN PAM-8   
M.FOX	EQU	303Q		'JMP' INSTRUCTION AT 000.000 IN FOX ROM   
**	ROUTINE ENTRY POINTS.   
*   

.IDENT	EQU	0000A		IDENTIFICATION LOCATION   
.DLY	EQU	0053A		DELAY   
.LOAD	EQU	1267A		TAPE LOAD   
.DUMP	EQU	1374A		TAPE DUMP   
.ALARM	EQU	2136A		ALARM ROUTINE   
.HORN	EQU	2140A		HORN   
.CTC	EQU	2172A		CHECK TAPE CHECKSUM   
.TPERR	EQU	2205A		TAPE ERROR ROUTINE   
.PCHL	EQU	2264A		PCHL INSTRUCTION   
.SRS	EQU	2265A		SCAN RECORD START   
.RNP	EQU	2325A		READ NEXT PAIR   
.RNB	EQU	2331A		READ NEXT BYTE   
.CRC	EQU	2347A		CRC-16 CALCULATOR   
.WNP	EQU	3017A		WRITE NEXT PAIR   
.WNB	EQU	3024A		WRITE NEXT BYTE   
.DOD	EQU	3122A		DECODE FOR OCTAL DISPLAY   
.RCK	EQU	3260A		READ CONSOLE KEYSET   
.DODA	EQU	3356A		SEGMENT CODE TABLE   

**	RAM CELLS USED BY H8MTR.   
*   

.START	EQU	40000A		START DUMP ADDRESS   
.IOWRK	EQU	40002A		IN OR OUT INSTRUCTION   
.REGI	EQU	40005A		DISPLAYED REGISTER INDEX   
.DSPROT EQU	40006A		PERIOD FLAG BYTE   
.DSPMOD	EQU	40007A		DISPLAY MODE   
.MFLAG	EQU	40010A		USER OPTION BYTE   
.CTLFLG EQU	40011A		PANEL CONTROL BYTE   
.ALEDS	EQU	40013A		ABUSS LEDS   
.DLEDS	EQU	40021A		DBUSS LEDS   
.ABUSS	EQU	40024A		ABUSS REGISTER   
.CRCSUM EQU	40027A		CRCSUM WORD   
.TPERRX EQU	40031A		TAPE ERROR EXIT VECTOR   
.TICCNT EQU	40033A		CLOCK TICK COUNTER   
.REGPTR EQU	40035A		REGISTER POINTER   
.UIVEC	EQU	40037A		USER INTERRUPT VECTORS   


*	XTEXT	U8251    
*	XTEXT	ASCII    
	LON	C    
*	XTEXT 	HOSEDEF    

**	HOSDEF - Define HOS Parameter    
*    
SYSCALL	EQU	377Q	Syscall Instruction    

	ORG	0    
*	Resident Functions    
.EXIT	DS	1	Exit (must be first)    
.SCIN	DS	1	SCIN (serial input)    
.SCOUT	DS	1	SCOUT (serial output)    
.PRINT	DS	1	PRINT    
.READ	DS	1	READ    
.WRITE	DS	1	WRITE    
.CONSL	DS	1	Set/clear console options    
.CLRCO	DS	1	Clear console buffer    
.SYSRES	DS	1	Preceeding functions are resident    

*	HOSOVL.SYS	Functions    
	ORG	40A    
.LINK	DS	1	LINK (must be first)    
.CTLC	DS	1	CTL-C    
.OPENR	DS	1	Open Read    
.OPENW	DS	1	Open Write    
.OPENU	DS	1	Open Update(?)    
.OPENC	DS	1	Open Channel (?)    
.CLOSE	DS	1	Close    
.POSIT	DS	1	Position    
.DELET	DS	1	Delete    
.RENAM	DS	1	Rename    
.SETTP	DS	1	Set top    
.DECODE	DS	1	Name decode    
.NAME	DS	1	Get file name from channel    
.CLEAR	DS	1	Clear channel    
.CLEARA	DS	1	Clear all channels    
.ERROR	DS	1	Look up error    
.CHFLG	DS	1	Change flags    
.DISMT	DS	1	Flag system disk dismounted    
*	XTEXT	DIRDEF    

** 	Directory Entry Format    
	ORG	0    

UP.EMP	EQU	377Q	Flags Entry Empty    
UP.CLR	EQU	376Q	Flags Entry empty, rest of dire also clear    

DIR.NAM	DS	8	Space for file Name    
DIR.EXT	DS	3	Space for file Extension    
DIR.PRO	DS	1	Project    
DIR.VER	DS	1	Version    
DIRIDL	EQU	*	File identification length    

DIR.CLU	DS	1	Cluster factor    
DIR.FLG	DS	1	Flags    
	DS	1	Reserved
DIR.FGN	DS	1	First group number
DIR.LGN	DS	1	Last group number
DIR.LSI	DS	1	Last sector index (in last group)
DIR.CRD	DS	2	Creation Date    
DIR.ALD	DS	2	Last alteration date    
DIRELEN	EQU	*	Directory Entry length    
*	XTEXT	DEVDEF    

**	Device Table Entrys    
	ORG	0    
DEV.NAM	DS	2	Device Name    
DEV.RES	DS	1	Driver residence code    
DR.IM	EQU	00000001B	Driver in memory    
DR.PR	EQU	00000010B	Driver permanently resident    

DEV.JMP	DS	1	Jump to processor    
DEV.DDA	DS	2	Driver address    
DEV.FLG	DS	1	Flag Byte    
DT.DD	EQU	00000001B	Directory Device    
DT.CR	EQU	00000010B	Capable of READ operation    
DT.CW	EQU	00000100B	Capable of WRITE operation    

DEV.GRT	DS	2	Address of group reservation table (if directory)    
DEV.SPG	DS	1	Sectors per group this device    
DEV.MUM	DS	0	Mounted unit mask    
DEV.MNU	DS	1	Maximum number of units    
DEV.DVL	DS	2	Driver byte length    
DEV.DVG	DS	1	Driver routine group address    
DEV.DIR	DS	2	Directory first sector address    
DEV.GTS	DS	2	GRT sector number    

DEVELEN	EQU	*	Device tble entry length    
*	XTEXT	H17DEF    

**	H17 Control Information    
DP.DC	EQU	07FH	Disk control port    
DF.HD	EQU	00000001B	Hole Detect    
DF.T0	EQU	00000010B	Track 0 detect    
DF.WP	EQU	00000100B	Write protect    
DF.SD	EQU	00001000B	Sync Detect    

DF.WG	EQU	00000001B	Write gate enable    
DF.DSO	EQU	00000010B	Drive select 0    
DF.DS1	EQU	00000100B	Drive select 1    
DF.DS2	EQU	00001000B	Drive select 2    

DF.MO	EQU	00010000B	Motor On (both drives)    
DF.DI	EQU	00100000B	Direction (0 = out)    
DF.ST	EQU	01000000B	Step command (active high)    
DF.WR	EQU	10000000B	Write enable RAM    

**	Disk UART ports and control flags    
UP.DP	EQU	07CH	Data port    
UP.FC	EQU	07DH	Fill Character    
UP.ST	EQU	07DH	Status flags    
UP.SC	EQU	07EH	Syn character (output)    
UP.SR	EQU	07EH	Sync reset (input)    

UF.RDA	EQU	00000001B	Receive data available    
UF.ROR	EQU	00000010B	Receiver overrun    
UF.RPE	EQU	00000100B	Receiver parity error    
UF.FCT	EQU	01000000B	Fill character transmitted    
UF.TBM	EQU	10000000B	Transmitter buffer empty    

** 	Character Definitions    
C.DSYN	EQU	0FDH	Prefix sync character    
*	XTEXT	ECDEF    

**	Error Code Definitions    
	ORG	0    
	DS	1	No error #0    
EC.EOF	DS	1	End of file    
EC.EOM	DS	1	End of media    
EC.ILC	DS	1	Illegal SYSCALL code    
EC.CNA	DS	1	Channel not available    
EC.DNS	DS	1	Device not suitable    
EC.IDN	DS	1	Illegal device name    
EC.IFN	DS	1	Illegal file name    
EC.NRD	DS	1	No room dor device driver    
EC.FNO	DS	1	channel not open    
EC.ILR	DS	1	Illegal request    
EC.FUC	DS	1	File name conflict    
EC.FNF	DS	1	File name not found    
EC.UND	DS	1	Unknown device    
EC.ICN	DS	1	Illegal channel number    
EC.DIF	DS	1	Directory full    
EC.IFC	DS	1	Illegal file contents    
EC.NEM	DS	1	Not enough memory    
EC.RF	DS	1	Read failure    
EC.WF	DS	1	Write failure    
EC.WPV	DS	1	Write protection violation    
EC.WP	DS	1	disk write protected    
EC.FAP	DS	1	file already present    
EC.DDA	DS	1	device driver abort    
EC.FL	DS	1	file locked    
EC.FAO	DS	1	file already open    
EC.IS	DS	1	illegal switch    
EC.UUN	DS	1	unknown unit number    
EC.FNR	DS	1	file name required    
EC.DIW	DS	1	device is not readable    
EC.UNA	DS	1	unit not available    
EC.ILV	DS	1	illegal value    
EC.ILO	DS	1	illegal option    
*	XTEXT	DDDEF	    

**	Device driver communication flags    
*    
	ORG	0    
DC.REA	DS	1	Read    
DC.WRI	DS	1	Write    
DC.RER	DS	1	Read Regardless    
DC.OPR	DS	1	Open for read    
DC.OPW	DS	1	Open for write    
DC.OPU	DS	1	Open for update    
DC.CLO	DS	1	Close    
DC.ABT	DS	1	Abort    
DC.MOU	DS	1	Mount Device    
*	XTEXT	PICDEF    

**	PIC Format equivalences    
*    
	ORG	0    
PIC.ID	DS	1	377Q = Binary file flag    
	DS	1	File type (FT.PIC)    
PIC.LEN	DS	2	Length of entire record    
PIC.PTR	DS	2	Index of start of PIC table    
PIC.COD	DS	0	Code starts here    
*	XTEXT	HOSEQU    

**	HDOS System Equivalences    
*    
S.GRT	EQU	24000A	System area for GRT0    
S.GRT1	EQU	25000A	System area for GRT1    
SECSCR	EQU	26000A	System 512 byte scratch area    
ROMBOOT	EQU	30000A	ROM boot entry    

	ORG	40100A	Free Space From PAM-8    
	DS	8	Jump to system exit    
D.CON	DS	16	Disk constants    
SYDD	EQU	*	System disk entry point    
D.VEC	DS	24*3	System ROM entry vectors    
D.RAM	DS	31	System ROM Work area    
S.VAL	DS	38	System values    
S.INT	DS	113	SYSTEM INTERNAL WORK AREA   
	DS	16	    
S.SOVR	DS	2	Stack overflow warning    
	DS	42200A-*	System stack    
STACKL	EQU	*-S.SOVR	Stack size    
STACK	EQU	*	LWA+1 system stack    
USERFWA	EQU	*	User FWA    
*	XTEXT	EDCON    

**	D.CON detailed equivalences    
*	HOSEQU  must be modified when this table is modified    

	ORG	D.CON    
D.XITA	DS	2	See system ROM for description    
D.WRITA	DS	1	    
D.WRITB	DS	1	    
D.WRITC	DS	1	    
D.MAIA	DS	1	    
D.LPSA	DS	1	    
D.SDPA	DS	1	    
D.SDPB	DS	1	    
D.STSA	DS	1	    
D.STSB	DS	1	    
D.WHDA	DS	1	    
D.WNHA	DS	1	    
D.WSCA	DS	1	    
D.ERTS	DS	2	Track and sector of last disk errors    
*	XTEXT	EDVEC    


**	Jump vectors for ROM code    
*	See disk rom for addresses    
*	HOSEQU must be altered when this table is altered    

	ORG	D.VEC    
D.SYDD	DS	3	JMP   R.SYDD (Must be first)    
D.MOUNT	DS	3	JMP   R.MOUNT    
D.XOK	DS	3	JMP   R.XOK    
D.ABORT	DS	3	JMP   R.ABORT    
D.XIT	DS	3	JMP   R.XIT    
D.READ	DS	3	JMP   R.READ    
D.READR	DS	3	JMP   R.READR    
D.WRITE	DS	3	JMP   R.WRITE    
D.CDE	DS	3	JMP   R.CDE    
D.DTS	DS	3	JMP   R.DTS    
D.SDT	DS	3	JMP   R.SDT    
D.MAI	DS	3	JMP   R.MAI    
D.MAO	DS	3	JMP   R.MAO    
D.LPS	DS	3	JMP   R.LPS    
D.RDB	DS	3	JMP   R.RDB    
D.SDP	DS	3	JMP   R.SDP    
D.STS	DS	3	JMP   R.STS    
D.STZ	DS	3	JMP   R.STZ    
D.UDLY	DS	3	JMP   R.UDLY    
D.WSC	DS	3	JMP   R.WSC    
D.WSP	DS	3	JMP   R.WSP    
D.WNB	DS	3	JMP   R.WNB    
D.ERRT	DS	3	JMP   R.ERRT    
D.DLY	DS	3	JMP   R.DLY    
*	XTEXT	EDRAM    

**	EDRAM - disk RAM workarea definition    
*	Zeroed on boot up    
*	HOSEQU must be changed i this table is changed    

	ORG	D.RAM    
D.TT	DS	1	Target Track (current operation)    
D.TS	DS	1	Target Sector (current operation)    
D.DVCTL	DS	1	Device Control byte    
D.DLYMO	DS	1	Motor on delay count    
D.DLYHS	DS	1	Head settle delay counter    

D.TRKPT	DS	2	Address in D.DRVTB for track number    
D.VOLPT	DS	2	Address in D.DRVTB for volume number    
D.DRVTB	DS	2*4	Track number and volume number for 4 drives    
D.HECNT	DS	1	Hard error count    
D.SECNT	DS	2	Soft error count    
D.OECNT	DS	1	Operation error count    

*	Global Disk error counters    
D.ERR	DS	0	Beginning of error block    
D.E.MDS	DS	1	Missing data sync    
D.E.HSY	DS	1	Missing reader sync    
D.E.CHK	DS	1	Data checksum     
D.E.HCK	DS	1	Header checksum    
D.E.VOL	DS	1	Wrong volume number    
D.E.TRK	DS	1	Bad Track seek    
D.ERRL	DS	0	Limit of error counters    

*	I/O Operation counts    
D.OPR	DS	2	    
D.OPW	DS	2	    
D.RAML	EQU	*-D.RAM	    
*	XTEXT	ESVAL    

**	S.VAL  -- System value definitions    
*	These values are set and maintained by the system    
*	HOSEQU must be modified when this is modified    

	ORG	S.VAL    
S.DATE	DS	9	System Date (in ASCII)    
S.DATC	DS	2	Coded date    
S.TIME	DS	4	Time from midnight (in Tics)    
S.HIMEM	DS	2	Hardware high memory address + 1    
S.SYSM	DS	2	FWA Resident system    
S.USRM	DS	2	LWA user memory    
S.OMAX	DS	2	Max overlay size for system	    


**	The following five cells should be modified/read only via the .consl syscall    
CSL.ECH	EQU	10000000B	Suppress echo    
CSL.WRP	EQU	00000010B	Wrap lines at width    
CSL.CHR	EQU	00000001B	Operate in character mode    

I.CSLMD	EQU	0	S.CSLMD is first byte	    
S.CSLMD	DS	1	Console mode    

CTP.BKS	EQU	10000000B	Terminal processes backspaces    
CTP.MLI	EQU	00100000B	Map lower case to upper on input    
CTP.MLO	EQU	00010000B	Map lower case to upper on output    
CTP.2SB	EQU	00001000B	Terminal needs two stop bits    
CTP.BKM	EQU	00000010B	Map Backspace on input to Rubout    
CTP.TAB	EQU	00000001B	Terminal supports tab characters    

I.CONTY	EQU	1	S.CONTY is 2nd byte    
	ERRNZ	*-S.CSLMD-I.CONTY    
S.CONTY	DS	1	Console type flags    

I.CUSOR	EQU	2	S.CUSOR is 3rd byte    
	ERRNZ	*-S.CSLMD-I.CUSOR    
S.CUSOR	DS	1	CURRENT CURSOR POSITION    
I.CONWI	EQU	3	S.CONWI is 4th byte    
	ERRNZ	*-S.CSLMD-I.CONWI    

S.CONWI	DS	1	Console width    

CO.FLG	EQU	00000001B	CTL-O flag    
CS.FLG	EQU	10000000B	CTL-S flag    

I.CONFL	EQU	4	S.CONFL is 5th byte    
	ERRNZ	*-S.CSLMD-I.CONFL    

S.CONFL	DS	1	Console flags    
S.CAADR	DS	2	Address for abort processing (>256 if valid)    
S.CCTAB	DS	6	Address for CTL-A, CTL-B, CTL-C processing    
*	XTEXT	ESINT    

**	S.INT - system internal workarea definitions    
*	These cells are referenced by overlays and main code, and    
*	therefore must reside in fixed low memory    

	ORG	S.INT    
**	Console Status flags    
S.CDB	DS	1	Console descriptor byte    
CDB.H85	EQU	00000000B    
CDB.H84	EQU	00000001B	=0 If H8-5, =1 if H8-4    
S.BAUD	DS	2	[0-14] H8-4 baud rate, =0 if H8-5    
*			[15] = 1 if baud rate => 2 stop bits    

**	Table Address Words    
S.DLINK	DS	2	Address of data in HDOS code    
S.CFWA	DS	2	FWA channel table    
S.DFWA	DS	2	FWA device table    
S.RFWA	DS	2	FWS resident HDOS code    

**	Device Driver Delayed load flags    
S.DDLDA	DS	2	Driver load address (high byte=0 if no load pending)    
S.DDLEN	DS	2	Code length in bytes    
S.DDGRP	DS	1	Group number for driver    
	DS	1	Hold place    
* S.DDSEC	DS	2	(Obsolete) Sector number for driver    
S.DDDTA	DS	2	Device's address in DEVLST + DEV.RES    
S.DDOPC	DS	1	Open Opcode pending    

**	Overlay management flags    
OVL.IN 	EQU	00000001B	In memory    
OVL.RES	EQU	00000010B	Permanently resident    
OVL.UCS	EQU	10000000B	User code swapped for overlay    

S.OVLFL	DS	1	Overlay flag    
S.UCSF	DS	2	FWA Swapped user code    
S.UCSL	DS	2	Length swapped user code    
S.OVLS	DS	2	Size of overlay code    
S.OVLE	DS	2	Entry point of overlay code    
S.SSN	DS	2	Swap area sector number    
S.OSN	DS	2	Overlay sector number    

*	Syscall processing areas    
S.CACC	DS	1	(ACC) Upon Syscall    
S.CODE	DS	1	Syscall index in progress    

*	Jumps to routines in resident HDOS code    
S.JUMPS	DS	0	Start of dump vectors    
S.SDD	DS	3	Jump to stand-in device driver    
S.FASER	DS	3	Jump to FATSERR (Fatal system error)    
S.DIREA	DS	3	Jump to DIREAD (Disk file read)    
S.FCI	DS	3	Jump to Fetch Channel Info    
S.SCI	DS	3	Jump to Store Channel Info    
S.MOUNT	DS	1	<> 0 if the system disk is mounted    
S.DCS	DS	1	Default cluster size - 1    
	DS	1	Unused    

*	Stack value saved for overlay syscalls    
S.OVSTK	DS	2	Value of SP upon Syscalls using overlay    

*	Volume dependent values for SY1:    
S.S1DIS	DS	2	directory sector    
S.S1GRT	DS	2	GRT sector    

**	Active I/O area    
*    
*	The AIO.XXX area contains informaton about the I/OOperation    
*	currently being performed.  The information is obtained from     
*	the channel table and will be restored there when done.    
*    
*	Normally the AIO.XXX information would be obtained directly     
*	from various system tables via pointer registers.  Since the    
*	8080 has no good indexed addressing, the data is manually    
*	copied into the AIO.XXXX cells before processing and     
*	backdated after processing.    

AIO.VEC	DS	3	Jump instruction    
AIO.DDA	EQU	*-2	Device driver address   
AIO.FLG	DS	1	Flag byte    
AIO.GRT	DS	2	Address of group reserv table    
AIO.SPG	DS	1	sectors per group    
AIO.CGN	DS	1	Current Group number    
AIO.CSI	DS	1	current sector index    
AIO.LGN	DS	1	Last group number    
AIO.LSI	DS	1	Last sector index    
AIO.DTA	DS	2	Device Table address    
AIO.DES	DS	2	directory sector    
AIO.DEV	DS	2	Device code    
AIO.UNI	DS	1	Unit number (0-9)    

AIO.DIR	DS	DIRELEN	Directory Entry    

AIO.CNT	DS	1	Sector count    
AIO.EOM	DS	1	End of media flag    
AIO.EOF	DS	1	End of file flag    
AIO.TFP	DS	2	Temp file pointers    
AIO.CHA	DS	2	Address of Channel block (IOC.DDA)    

****	Start at page 12    
	ORG	30000A    
START	JMP	BOOT	Jump to Boot code    

**	Memory Diagnostic    
*    

	LXI	H,-64    
	DAD	SP	(HL) = End    
	XCHG		(DE) = End + 1    
	LXI	H,40100A	(HL) = Start    
	HLT		Pause for adjustment    

*	(HL) = Start    
*	(DE) = End    

*	Zero Test Area    
	SHLD	40100A-2    
MEM1	MVI	M,0    
	INX	H    
	CALL	$CDEHL    
	JNE	MEM1    

*	Start testing memory, increment each byte in turn, and compare    
*	that result to the expected value    

	MVI	B,0	(B) = Expected value    
MEM2	LHLD	40100A-2    
	INR	B    

MEM3	INR	M    
	MOV	A,M	(A) = Value    
	CMP	B    
	JE	MEM4	Value is ok    

*	Have error, (HL) = address of byte in error    
	HLT    
	NOP    

MEM4	INX	H    
	CALL	$CDEHL    
	JNE	MEM3	Not at the end of the pass    
	JMP	MEM2	At end of pass    
*	XTEXT	COMP    

**	$COMP - compare two character strings    
*	$COMP compares 2 byte strings    
*    
*	Entry	(C) = compare count    
*		(DE) = FWA of string #1    
*		(HL) = FWA of string #2    
*	Exit	'Z' Clear, is mismatch    
*		(C) = length remaining    
*		(DE) = address of mismatch in string1    
*		(HL) = address of mismatch in string 2    
*		'C' Set, have match    
*		(DE) = (DE) + (OC)    
*		(HL) = (HL) + (OC)    
*	Uses A,F,C,D,E,H,L    

$COMP	LDAX	D    
	CMP	M	Compare    
	RNE		No match    
	INX	D    
	INX	H    
	DCR	C    
	JNZ	$COMP	Try some more    
	RET		Have match    
*	XTEXT	DADA    

**	$DADA - perform (H,L) = (H,L) + (O,A)    
*    
*	Entry	(H,L) = before value    
*		(A) = before value    
*	    
*	Exit	(H,L) = (H,L) + (O,A)    
*		'C' set if overflow    
*	Uses F,H,L    
$DADA	PUSH	D    
	MOV	E,A    
	MVI	D,0    
	DAD	D    
	POP	D    
	RET		Exit    
*	XTEXT	DADA2    

**	$DADA.  -  add (O,A) to (H,L)    
*    
*	Entry	None    
*	Exit	(HL) = (HL) + (OA)    
*	Uses	A,F,H,L    

$DADA.	ADD	L    
	MOV	L,A    
	RNC    
	INR	H    
	RET    
*	XTEXT	DU66    

**	$DU66 unsigned 16/16 divide    
*    
*	(HL) = (BC)/(DE)    
*    
*	Entry	(BC), (DE) preset    
*	Exit	(HL) = result    
*		(DE) = remainder    
*	Uses 	All    

$DU66	MOV	A,D	Two's complement (DE)    
	CMA    
	MOV	D,A    
	MOV	A,E    
	CMA    
	MOV	E,A    
	INX	D    
	MOV	A,D    
	ORA	E    
	JZ	DU665	If divide by zero    
	XRA	A    

*	Shift (DE) left until    
*	1)  DE > BL    
*	2)  Overflow    

DU661	MOV	H,D    
	MOV	L,E    
	DAD	B    
	JNC	DU662	Is too large    
	INR	A	Count shift    
	MOV	H,D    
	MOV	L,E    
	DAD	H    
	XCHG		(DE) = (DE) *2    
	JC	DU661	If no overflow    

*	(DE) overflowed, put it back    
	XCHG    
	DCR	A	Remove extra count    

*	Ready to start subtracting, (A) = loop count    

DU662	MOV	H,B	(H,L) = working value    
	MOV	L,C    
	LXI	B,0	(BC) = result    
DU663	PUSH	PSW	Save (A)    
	DAD	D    
	JC	DU664	If subtract ok    
	MOV	A,L	Add back in    
	SUB	E    
	MOV	L,A    
	MOV	A,H    
	SBB	D    
	MOV	H,A    
DU664	MOV	A,C    
	RAL    
	MOV	C,A    
	MOV	A,B    
	RAL    
	MOV	B,A    

*	Right shift (DE)    
	STC    
	MOV	A,D    
	RAR    
	MOV	D,A    
	MOV	A,E    
	RAR    
	MOV	E,A    
	POP	PSW    
	DCR	A    
	JP	DU663	If not done    
DU665	XCHG	(D,E) = remainder    
	MOV	H,B	(HL) = result    
	MOV	L,C    
	RET    
*	XTEXT	HLIHL    

**	$HLIHL	Load HL indirect through HL    
*    
*	(HL) = ((HL))    
*    
*	Entry 	None    
*	Exit	None    
*	Uses	A,H,L    

$HLIHL	MOV	A,M    
	INX	H    
	MOV	H,M    
	MOV	L,A    
	RET    
*	XTEXT	CDEHL    

**	$CDEHL  - compare (DE) to (HL)    
*	$CDEHL compare (DE) to (HL) for equality    
*    
*	Entry	None    
*	Exit	'Z' set if (DE) = (HL)    
*	Uses	A, F    

$CDEHL	MOV	A,E    
	XRA	L    
	RNZ		If different    
	MOV	A,D    
	XRA	H    
	RET    
*	XTEXT	CHL	Complement (HL)    

**	$CHL - complement (HL)    
*	(HL) = - (HL)	Two's complement    
*    
*	Entry	None    
*	Exit	None    
*	Uses	A,F,H,L    

$CHL	MOV	A,H    
	CMA    
	MOV	H,A    
	MOV	A,L    
	CMA    
	MOV	L,A    
	INX	H    
	RET    
*	XTEXT	INDL	Indexed load    

**	$INDL	Indexed load    
*	$INDL loads DE with 2 bytes at (HL) + displacement    
*	This acts as an indexed full word load    
*    
*	(DE) = ((HL) + displacement )    
*    
*	Entry	((RET)) = displacement (full word)    
*		(HL) = table address    
*	Exit	to (RET + 2)    
*	Uses	A,F, D, E    

$INDL	XTHL		(HL) = RET, ((SP)) = Table address    
	MOV	E,M    
	INX	H    
	MOV	D,M	(DE) = displacement    

	INX	H    
	XTHL		((SP)) = RET, (HL) = table address    
	XCHG		(DE) = Table address, (HL) = displacement    
	DAD	D	(HL) = target address    
	MOV	A,M	    
	INX	H    
	MOV	H,M    
	MOV	L,A	(HL) = ((HL))    
	XCHG		(DE) = value, (HL) = table address    
	RET    

**	$MOVE - move data    
*	$MOVE moves a block of bytes to a new memory address.    
*	If the move is to a lower address, the bytes are moved from     
*	First to Last.    
*    
*	If the move is to a higher adres, the bytes are moved from    
*	Last to First.    
*    
*	This is done so that an overlapped move will not 'ripple'    
*    
*	Entry	(BC) = count    
*		(DE) = From    
*		(HL) = To    
*	Exit	Moved    
*		(DE) = address of next 'From' byte    
*		(HL) = address of next 'To' byte    
*		'C' Clear    
*	Uses	All    

$MOVE	EQU	*    
	MOV	A,B    
	ORA	C    
	RZ		Nothing to move    
	MOV	A,L	Compare 'From' to 'To'    
	SUB	E	    
	MOV	A,H    
	SBB	D    
	JC	MOV2	Is move down (to lower addresses)    

*	is move up (to higher addresses)    
	DCX	B    
	DAD	B	(HL) = 'To' LWA    
	PUSH	H	Save 'To' limit    
	XCHG    
	DAD	B	(HL) = 'From' LWA    
	PUSH	H	Save 'From' limit    

MOV1	MOV	A,M	Move byte    
	STAX	D    
	DCX	D	Increment 'To' addresss    
	DCX	H	Increment 'from' address    
	DCX	B	Decrement count    
	MOV	A,B    
	ANA	A    
	JP	MOV1	More to do    
	POP	D	(DE) = 'From' limit    
	POP	H	(HL) = 'To' limit    
	INX	D    
	INX	H    
	RET		Done!    

*	is move down to lower address    
MOV2	LDAX	D	Move byte    
	MOV	M,A    
	INX H		Increment 'From'    
	INX	D	Increment 'To'    
	DCX	B	Decrement count    
	MOV	A,B    
	ORA	C    
	JNZ	MOV2	If not done, do it again    
	RET		Otherwise done    
*	XTEXT	MU10    

** 	$MU10 - multiply unsigned 16 bit quantity by 10    
*    
*	(HL) = (DE) * 10    
*    
*	Entry	(DE) = multiplier    
*	Exit	'C' clear if ok    
*		(HL) = product    
*		'C' set if error    
*	Uses	D,E,H,L,F    

$MU10	XCHG		(HL) = multiplier    
	DAD	H	(HL) = X * 2    
	RC    
	MOV	D,H    
	MOV	E,L    
	DAD	H	(HL) = X*4    
	RC    
	DAD	H	(HL) = X*8    
	RC	    
	DAD	D	(HL) = X*10    
	RET    
*	XTEXT	MU66    

** 	$MU66 - multiply unsigned 16 x 16    
*    
*	Entry	(BC) = multiplicand    
*		(DE) = Multiplier    
*	Exit	(HL) = result    
*		'Z' set if not overflow    
*	Uses	All    

$MU66	XRA	A    
	PUSH	PSW	Save overflow status    
	LXI	H,0    

MU661	MOV	A,B    
	RAR    
	MOV	B,A    
	MOV	A,C    
	RAR    
	MOV	C,A    
	JNC	MU662	If bit clear    
	DAD	D    
	JNC	MU662	If not overflow    
	POP	PSW    
	INR	A    
	PUSH	PSW    
MU662	MOV	A,B    
	ORA	C	See if multiplier = 0    
	JZ	MU663	IF mulitplier =0, we're done    
	XCHG    
	DAD	H	(DE) = (DE) * 2    
	XCHG    
	JNC	MU661	If not overflow    
	POP	PSW    
	INR	A    
	PUSH	PSW	Flag overflow    
	JMP	MU661	Process next bit    

MU663	POP	PSW	(A,F) = overflow status    
	RET    
*	XTEXT	MU86    

**	$MU86 - multiply 8 x 16 unsigned    
*	$MU86 multiplies a 16 bit value by an 8 bit value    
*    
*    
*	Entry	(A) = multiplier    
*		(DE) = multiplicand    
*	Exit	(HL) = result    
*		'Z' set if not overflow    
*	Uses	A,F,H,L    

$MU86	LXI	H,0	(HL) = result accumulator    
	PUSH	B    
	MOV	B,H	(B) = overflow flag    
MU860	ORA	A	Clear carry    
MU861	RAR    
	JNC	MU862	If not to add    
	DAD	D    
	JNC	MU862	Not overflow    
	INR	B    
MU862	ORA	A    
	JZ	MU863	If done    
	XCHG	    
	DAD	H	    
	XCHG    
	JNC	MU861	Loop if not overflow    
	INR	B    
	JMP	MU860    

MU863	ORA	B	Set *Z* flag if not overflow    
	POP	B	Restore (BC)    
	RET    
*	XTEXT	SAVALL    

**	$RSTALL - restore all registers    
*    
*	$RSTALL restores all registers off the stack and     
*	returns to the previous caller    
*    
*	Entry	(SP) = PSW    
*		(SP+2) = BC    
*		(SP+4) = DE    
*		(SP+6) = HL    
*		(SP+8) = Return address    
*	Exit	To *Return*, registers restored    
*	Uses	All    

$RSTALL	POP	PSW    
	POP	B    
	POP	D    
	POP	H    
	RET    

**	$SAVALL - saves all registers on stack    
*    
*	Entry	None    
*	Exit	(SP) = PSW    
*		(SP+2) = BC    
*		(SP+4) = DE    
*		(SP+6) = HL    
*		(SP+8) = Return address    
*	Uses	H,L    

$SAVALL	XTHL		Push H, (HL) = return address    
	PUSH	D    
	PUSH	B    
	PUSH	PSW    
	PCHL		Return to caller    
*	XTEXT	TJMP    

**	$TJMP - Table jump    
*	Useage:    
*	CALL	$TJMP	(A) = index    
*	DW	ADDR1	Index = 0    
*    
*    
*	DW	ADDRN	Index = N-1    
*    
*	Entry	(A) = Index    
*	Exit	To Processor    
*		(A) = Index * 2    
*	Uses	A,F    

$TJMP	RLC		(A) = Index *2    

$TJMP.	EQU	*    
	XTHL		(HL) = Table Address    
	PUSH	PSW	Save Index * 2    
	CALL	$DADA.   
	MOV	A,M    
	INX	H    
	MOV	H,M    
	MOV	L,A    
	POP	PSW	(A) = index * 2    
	XTHL		Address on stack    
	RET		Jump to processor    
*	XTEXT	TBRA    

**	$TBRA - branch relative through table    
*    
*	$TBRA uses the supplied index to select a byte from the    
*	Jump table.  The contents of this byte are added to the     
*	address of the byte, yielding the processor address.    
*    
*	CALL 	$TBRA    
*	DB	LAB1 - *		Index = 0 for Lab1    
*	DB	LAB2 - *		Index = 1 for Lab2    
*	DB	LABN - *		Index = N-1 for LabN    
*    
*	Entry	(A) = Index    
*		(RET) = Table FWA    
*	Exit	to computed address    
*	Uses	F,H,L    

$TBRA	EQU	*    
	XTHL		(HL) = table address    
	PUSH	D    
	MOV	E,A    
	MVI	D,0    
	DAD	D	(HL) = address of element    
	MOV	E,M	    
	DAD	D	(HL) = processor address    
	POP	D    
	XTHL    
	RET    

**	$TBLS - table search    
*    
*	Table format    
*	DB	Key1, Val1    
*	.	.    
*	.	.    
*	DB	KeyN, ValN    
*	DB	0    
*    
*	Entry	(A) = pattern    
*		(H,L) = table FWA    
*	Exit	(A) = pattern if found    
*		'Z' set if found    
*	Uses	a, F, H, L    

$TBLS	PUSH	B    
	MOV	B,A    
$TBL1	MOV	A,M	(A) = character    
	CMP	B    
	JZ	$TBL2	If match    
	ANA	A    
	INX	H    
	INX	H	Skip past    
	JNZ	$TBL1	If not end of table    
	DCX	H    
	DCX	H    
	ORA	H	Clear 'Z'    
	MVI	A,0	Set (A) = 0 for old users    

*	DONE    

$TBL2	POP	B    
	INX	H    
	RET    

**	$TYPTX - Type text    
*	$TYPTX is called to type a block of text on the system console.    
*    
*	Embedded zero bytes indicate a carriage return line line feed.    
*	A byte with the 200Q bit set is the last byte in the message.    
*    
*	Entry	(RET) = Text    
*	Exit	To (RET + Length)    
*	Uses	A,F    

$TYPTX	XTHL		(HL) = text address    
	CALL	$TYPTX.	Type it    
	XTHL    
	RET    

$TYPTX.	MOV	A,M    
	ANI	177Q    
	DB	SYSCALL,.SCOUT    
	CMP 	M    
	INX	H    
	JE	$TYPTX.	More to go    
	RET    
*	XTEXT	UDD    

**	$UDD - unpack decimal digits    
*    
*	UDD converts a 16 bit value into a specified number of    
*	decimal digits.  The result is zero filled.    
*    
*	Entry	(B,C) = Address value    
*		(A) = Digit count    
*		(H,L) = memory address    
*	Exit	(HL) = (HL) + (A)    
*	USes	All    

$UDD	EQU	*    
	CALL	$DADA    
	PUSH	H	Save final (HL) value    

UDD1	PUSH	PSW    
	PUSH	H    
	LXI	D,10    
	CALL	$DU66	(HL) = value/10    
	PUSH	H    
	POP	B	(B,C) = remainder    
	POP	H    
	MVI	A,'0'    
	ADD	E	Add remainder    
	DCX	H    
	MOV	M,A	Store digit    
	POP	PSW    
	DCR	A    
	JNZ	UDD1	If more to go    
	POP	H	Restore H    
	RET    
*	XTEXT 	ZERO    

**	$ZERO - zero memory    
*    
*	zero a block of memory    
*    
*	Entry	(HL) = address    
*		(B) = count    
*	Exit	(A) = 0    
*	Uses	A,B,F,H,L    

$ZERO	XRA	A    
ZRO1	MOV	M,A    
	INX	H    
	DCR	B    
	JNZ	ZRO1	If more to do    
	RET    

****	Start at page 25    
**	$WDR -write disable RAM    
*	is called to disable the writability of the H17 controller RAM area    
*	Entry	None    
*	Exit	None    
*	Uses	None    

$WDR	PUSH	PSW    
	DI    
	LDA	D.DVCTL    
	ANI	377Q-DF.WR    
$WDR1	STA	D.DVCTL    
	OUT	DP.DC    
	EI    
	POP	PSW    
	RET    

**	$WER -write ensable RAM    
*	is called to enable the writability of the H17 controller RAM area    
*	Entry	None    
*	Exit	None    
*	Uses	None    

$WER	PUSH	PSW    
	DI    
	LDA	D.DVCTL    
	ORI	DF.WR    
	JMP	$WDR1    

**	D.DISK - Device driver read code    
*    
*	Entry	(BC) = count (in sectors)    
*		(DE) = address    
*		(HL) = sector    
*	Exit	'C' clear if OK, exit to caller    
*		'C' set if error    
*		To S.FASER (Fatal/System Error) if Unit 0    
*		To caller if other unit    
*		(A) = Error code    
*	Uses	<not given in source code listing>    

DWRITE	MVI	A,DC.WRI    
	DB	MI.CPI	Skip next    
DREAD	XRA	A	Set read code    
	ERRNZ	DC.REA    
	CALL	SYDD	Call device driver    
	RNC		If OK    
	PUSH	PSW	Save code    
	LDA	AIO.UNI    
	ANA	A    
	CZ	S.FASER	Is SY0:    
	POP	PSW    
	RET		Return with bad news    

**	SREAD - read from system disk    
*    
*	Entry	(BC) = count (in sectors)    
*		(DE) = address    
*		(HL) = sector    
*	Exit	To Caller if OK    
*		To S.FASER (Fatal system error) IF error    
*	Uses	<not noted>    

SREAD	LDA	AIO.UNI    
	PUSH	PSW	Save current unit    
	XRA	A    
	ERRNZ	DC.REA    
	STA	AIO.UNI    
SREAD1	CALL	SYDD    
	CC	S.FASER	Read error    
	POP	PSW    
	STA	AIO.UNI    
	RET    

**	Constant zeros    
ZEROS	DB	0,0,0,0,0,0,0,0    

**	SWRITE - write to system disk    
*    
*	Entry	(BC) = count (in sectors)    
*		(DE) = address    
*		(HL) = sector    
*	Exit	To Caller if OK    
*		To S.FASER (Fatal system error) IF error    
*	Uses	<not noted>    

SWRITE	LDA	AIO.UNI    
	PUSH	PSW	Save old unit #    
	XRA	A    
	STA	AIO.UNI	Set system unit    
	ERRNZ	DC.WRI-1    
	INR	A	(A) = DC.WRI    
	JMP	SREAD1    

**	ERR.FNO - Error: File not open    
ERR.FNO	MVI	A,EC.FNO	File not open    
	STC    
	RET		Error code    

**	ERR.ILR - Error - Illegal request    

ERR.ILR	MVI	A,EC.ILR	Illegal request    
	STC    
	RET    

**	CFF - Chain free block to file    
*    
*	CFF unchains a free block from the free list and chains     
*	it to the end of the active file    
*    
*	Entry	(HL) = address in group table of the group in question    
*		(E) = index of previous group inlist    
*		AIO.XXX setup    
*	Exit	AIO.LGN = (L) (at entry)    
*		AIO.LSI = 0    
*	Uses 	A,F,D,H,L    

CFF	MOV	A,M		(A) = next free    
	MVI	M,0		New block is end of chain for file    
	MOV	D,L		(D) = new index    
	MOV	L,E		(HL) = address of previous block    
	MOV	M,A		Unchain from free chain    
	LDA	AIO.LGN		(A) = last group number    
	MOV	L,A		(HL) = address of file last group    
	MOV	M,D		Link to new last block    
	LXI	H,AIO.LGN    
	MOV	M,D		Set new LGN    
	ERRNZ	AIO.LSI-AIO.LGN-1    
	INX	H    
	MVI	M,0		Clear LSI    
	RET    

**	DCA - determine contiguous area    
*    
*	DCA is called to find how many of the sectors which are to be    
*	read are continguous    
*    
*	ENTRY	(B) = sectors desired    
*		AIO.xxx setup    
*	EXIT	(B) = sectors - AIO.CNT    
*		AIO.CNT = sectors which are continuous    
*		AIO.EOF = EC.EOF * 2 + 1 if EOF    
*		AIO.TFP = setup with group and index of start of area    
*	USES	All    

DCA1	CALL FFL		Follow Forward Link    

DCA	LHLD	AIO.CGN	(H) = current GP #, (L) = current sector index    
	ERRNZ	AIO.CSI-AIO.CGN-1    
	SHLD	AIO.TFP	Temp file ptr    
	CALL	TFE	Test for EOF    
	STA	AIO.EOF	Set flag    
	STA	AIO.CNT	Set CNT = 0 if EOF    
	RE		Is EOF    
	LDA	AIO.CSI	(A) = current sector index    
	MOV	H,A    
	LDA	AIO.SPG    
	CMP	H	See if group exhausted    
	JE	DCA1	Was pointing at end of group    
* 	See if more needed    
DCA2	MOV	A,B    
	ANA	A    
	RZ		No more sectors to check    
*	See how many sectors are left in this group    
	LHLD	AIO.LGN	(L) = AIO.LGN, (H) = AIO.LSI    
	ERRNZ	AIO.LSI-AIO.LGN-1    
	LDA	AIO.CGN    
	CMP	L	See if we are pointed at last group    
	JE	DCA3	We are pointed at last group    
	LHLD	AIO.SPG-1	(H) = AIO.SPG    
DCA3	PUSH	PSW	Save status    
	LDA	AIO.CSI	(A) = current sector index    
	SUB	H	(A) = - sectors left in group    
	CMA    
	INR	A	(A) = + sectors left in group    
	CMP	B    
	JC	DCA4	Need more    
	MOV	A,B	Don't take more than we need    
DCA4	MOV	C,A	(C) = amount to take    
	LXI	H,AIO.CSI    
	ADD	M	Update CSI to indicate number to be read    
	MOV	M,A    
	MOV	A,C	(A) = number to be read    
	LXI	H,AIO.CNT    
	ADD	M	Add to count    
	MOV	M,A    
	MOV	A,B	(A) = amount needed    
	SUB	C    
	MOV	B,A    
	POP	PSW    
	RE		Was on last track; done    
	MOV	A,B    
	ANA	A    
	RZ		No more needed, done    

*	Used up this block, link to next    
*	If not contiguous, stop here    

	LDA	AIO.CGN    
	INR	A    
	PUSH	PSW	Save next contiguous block #    
	CALL	FFL	Follow file link    
	POP	PSW    
	CMP	L    
	JE	DCA2	Got it, was contiguous    
	RET		STOP Here    

**	FFB - find free block    
*    
*	FFB is called to locate a free block in the GRT's free chain    
*    
*	FFB will attempt to get a 'preferred block', if possible.    
*	If the preferred block is not available, FFB will (optionally)    
*	do the best he can: start a virgin cluster.  If possible, then    
*	just settle for anything    
*    
*	ENTRY	(D) = preferred block number (0 if none)    
*		(C) = preferred flag <= 0, will take something else    
*			      <> 0, must have preferred block or nothing    
*	EXIT	'C' set, EOM on device    
*		'C' clear, not EOM    
*		'Z' clear, couldn't get preferred block (only if (C)<>0 on Entry)    
*		'Z' set, got a block (preferred or not)    
*		(HL) = address of block in GRT table    
*		(E) = index of free block before the found one    
*	USES	A,F,E,H,L    

FFB	LHLD	AIO.GRT    
	MOV	A,M	(A) = first free block    
	ANA	A    
	STC		Assume EOM    
	RZ		End of media    
*	Not end of media, try to find the contiguous block in the free list    

	MOV	E,L	(E) = index of previous byte    
	INR	L    
	MOV	M,A	Flag change in GRT    
FFB4	MOV	L,A	(HL) = address of next byte in free chain    
	CMP	D    
	RE		Got the one we need    
	JNC	FFB5	Gone too far    
	MOV	E,L	Save this block index    
	MOV	A,M    
	ANA	A    
	JNZ	FFB4    

*	Couldn't find contiguous block. This means a break in    
*	Continuity.  If we have anything, return with it. If we     
*	have nothing yet, try to find a virgin cluster.    

FFB5	MOV	A,C    
	ANA	A    
	RNZ		Must NOT continue    
	MOV	L,A	(HL) = (AIO.GRT)    
FFB6	MOV	E,L	(E) = index of previous node    
	MOV	L,M	Link forward    
	LDA	AIO.DIR+DIR.CLU    
	ANA	L	See if start of cluster    
	RZ		Got virgin cluster    
	MOV	A,M    
	ANA	A    
	JNZ	FFB6	Try again    

*	Can't find virgin cluster, will take whatever we can get    

	MOV	L,A    
	MOV	E,L	(E) = index of previous mode    
	MOV	L,M	(HL) = address of first free block byte    
	RET		Return with 'Z' : got one    

**	FFL - follow forward link    
*    
*	FFL links AIO.CGN to the next group    
*    
*	ENTRY	None    
*	EXIT	AIO.CGN = Link(AIO.CGN)    
*		AIO.CSI = 0    
*		(L) = AIO.CGN    
*	USES	A,F,H,L    

FFL	LHLD	AIO.GRT    
	LDA	AIO.CGN    
	MOV	L,A	(HL) = address    
	MOV	L,M	(L) = link    
	MVI	H,0    
	SHLD	AIO.CGN	Set CGN, Clear CSI    
	ERRNZ	AIO.CSI-AIO.CGN-1    
	RET    

**	LDD - Load Device Driver    
*    
*	LDD is called to perform the suspended load of a device driver.    
*    
*	IF some OVL code wishes to load a device driver, it must    
*	suspend the request since the device driver will overlay the    
*	OVL code.  After the OVL code exits, the resident code will call    
*	LDD to perform the actual load, over the DVL.    
*    
*	ENTRY	DD.IOC = Pointer to IOC.DDA    
*		DD.LDA = load address    
*		DD.LEN = load length    
*		DD.SEC = sector index on system device    
*		DD.DTA = device resident address    
*		DD.OPE = Open code (DC.OPR, DC.OPW, DC>OPU)    
*	EXIT	OVL code destroyed    
*	USES	None    

S.DDSEC	EQU	S.DDGRP	Reference to make assemble ok    

LDD	CALL	$SAVALL	Save registers    

*	Clear OVL resident flag    
	LXI	H,S.OVLFL    
	MOV	A,M    
	ANI	377Q-OVL.IN    
	MOV	M,A	Clear in flag    

*	Load overlay  
	LHLD	S.DDLEN	(HL) = length    
	MOV	B,H    
	MOV	C,L	(BC) is length    
	LHLD	S.DDLDA	(HL) is load address    
	PUSH	H	Save for later    
	XCHG    
	LXI	H,SECSCR+255	Force new disk read right away    

*	Load binary    
LDD2	CALL	LDD8	Find next byte    
	MOV	A,M	(A) = Next byte    
	STAX	D	Copy    
	INX	D    
	DCX	B    
	MOV	A,B    
	ORA	C    
	JNZ	LDD2	More to go    

*	Code all loaded, relocate it    
	POP	B	(BC) = REL factor    
	DCR	B    
	DCR	B    
	ERRNZ	DD.ENT-2000A	Assume driver entry = 2000A    
LDD3	CALL	LDD8    
	MOV	E,M    
	CALL	LDD8    
	MOV	D,M	(DE) = rel adreese of workd to relocate    
	MOV	A,D    
	ORA	E    
	JZ	LDD4	All done    
	XCHG		(HL) = relative address of word to relocate    
	DAD	B	(HL) = absolute address of word to relocate    
	MOV	A,M    
	ADD	C    
	MOV	M,A    
	INX	H    
	MOV	A,M    
	ADC	B    
	MOV	M,A    
	XCHG		Restore (HL)    
	JMP	LDD3    

*	Setup entry addresses in tables    
LDD4	LHLD	S.DDLDA    
	XCHG		(DE) = Entry address    
	LHLD	S.DDDTA	(HL) = address of devlst entry    
	MOV	A,M    
	ORI	DR.IM	Set in memory    
	MOV	M,A    
	INX	H    
	INX	H    
	ERRNZ	DEV.DDA-DEV.RES-2    
	MOV	M,E    
	INX	H    
	MOV	M,D	Set address in table    
	XCHG		(HL) = entry point address    
	XRA	A    
	STA	S.DDLDA+1	Clear Load Flag    
	LDA	S.DDOPC	(A) = Open Code    
	CALL	PCHL	Call code    
	JMP	$RSTALL	Restore registers    

PCHL	PCHL    

**	LDD8 - read a byte from the file    
*    
*	ENTRY	(HL) = SecScr Pointer of current byte    
*		S.DDSEC = sector number of next sector    
*	EXIT	(HL) = address of next byte    
*	USES	L    

LDD8	INR	L	Point to next byte    
	RNZ		Got it    

*	Must read another    

	PUSH	B    
	PUSH	D    
	PUSH	H    
	XCHG		(DE) = address    
	LXI	B,256    
	LHLD	S.DDSEC	(HL) = sector number to read    
	INX	H    
	SHLD	S.DDSEC	(HL) = next sector number to read    
	DCX	H	Restore (HL)    
	CALL	SREAD	Read it    
	POP	H    
	POP	D    
	POP	B    
	RET    

**	LDO - Load OVL code    
*	LDO is called when the OVL Overlay must be loaded    
*    
*	IF User High Mem is too high, part of the user code will    
*	have to be saved on the swap area before the OVL code can be    
*	loaded.    
*    
*	ENTRY	None    
*	EXIT	None    
*	USES	A,F,H,L    

LDO	PUSH	D    
	PUSH	B    
*	See if will have to page user code    
	LHLD	S.OVLS	(HL) = size of HDOSOVL    
	CALL	$CHL	Complement (HL)    
	XCHG	(DE) = -size    
	LHLD	S.SYSM	(HL) = current FWA    
	DAD	D	(HL) = new FWA with OVL    
	SHLD	S.UCSF	Set user swap in case it is swapped    
	XCHG    
	LHLD	S.USRM    
	MOV	A,L    
	SUB	E    
	MOV	L,A     
	MOV	A,H    
	SBB	D    
	MOV	H,A	(HL) = amount to swap    
	JC	LDO1	No need to swap    
*	Must dump (HL) bytes of user code starting at (DE)    
	PUSH	D	check: is B really D??     
	SHLD	S.UCSL	SET LENGTH OF DUMP    
	MOV	B,H    
	MOV	C,L	(BC) = COUNT    
	LHLD	S.SSN	(HL) = SECTOR FOR SWAP (SET BY BOOT)    
	CALL	SWRITE    
	LXI	H,S.OVLFL    
	MVI	A,OVL.UCS    
	ORA	M	SET USER CODE SWAPPED    
	MOV	M,A    
	POP	D	(DE) = ADDRESS TO LOAD    

*	READY TO LOAD OVL OVERLAY    
*	(DE) = ADDRESS    
LDO1	LHLD	S.OVLS    
	MOV	B,H    
	MOV	C,L	(BC) = SIZE OF OVERLAY    
	LHLD	S.OSN    
	CALL	SREAD	READ DATA    
	LXI	H,S.OVLFL    
	MOV	A,M    
	ORI	OVL.IN	SET IT IN    
	MOV	M,A    
*	Relocate OVL    
	LHLD	S.UCSF	(HL) = FWA OVERLAY LOAD    
	LXI	D,PIC.COD    
	MOV	B,H    
	MOV	C,L	(BC) = OVL FWA    
	DAD	D	(HL) = ADDRESS OF ENTRY POINT    
	SHLD	S.OVLE	SET ENTRY POINT    
	ERRNZ	PIC.PTR-PIC.COD+2    
	DCX	H    
	MOV	A,M    
	DCX	H    
	MOV	L,M    
	MOV	H,A	(HL) = RELATIVE ADDRESS OF TABLE    
	DAD	B	(HL) = ABSOLUTE ADDRESS OF TABLE    
	CALL	REL.	RELOCATE OVL    

	POP	B    
	POP	D    
	RET    

** line 1862    
**	PDI - prepare for device I/)    
*	PDI preparees for physical I/O by    
*	  1) computing the physical addresses    
*	  2) prepare the count    
*    
*	ENTRY	AIO.XXX setup    
*	EXIT	(BC) = count    
*		(HL) = sector    
*		(A) = 0    
*	USES	A,F,B,C,H,L    

PDI	LHLD	AIO.TFP	(L) = AIO.CGN, (H) = AIO.CSI    
	ERRNZ	AIO.CSI-AIO.CGN-1	    
	LDA	AIO.SPG	(A) = sectors per group    
	MOV	C,A    
	MOV	A,L	(A) = group number    
	MOV	L,H    
	MVI	H,0	(HL) = (0, CSI)    
	MOV	B,H	(BC) = (0, SPG)    
*	Compute sector number by adding SPG 'BLock Number' Times    
PDI1	DAD	B	add    
	DCR	A    
	JNZ	PDI1	more to go    
	LDA	AIO.CNT	(A) = count    
	MOV	C,B	(C) = 0    
	MOV	B,A	(B) = sector count    
	XRA	A	clear (A)    
	RET    

**	REL - relocate code    
*	REL processes a relocation list    
*    
*	ENTRY	(BC) = displacement from addresses    
*		(DE) = reloaction factor (from current address)    
*		(HL) = FWA relocation list    
*	EXIT	None    
*	USES	All    

REL.	MOV	D,B	Entry for code displace = rel factor    
	MOV	E,C    

REL	PUSH	D	Save relocation factor    
	MOV	E,M	    
	INX	H    
	MOV	D,M    
	INX	H	(DE) = relative address of word to relocate    
	MOV	A,D    
	ORA	E    
	JNZ	REL1	More to do    
	POP	D    
	RET		Exit    

*	(DE) = index of word to relocate    
*	(HL) = relocation table address    
*	(BC) = code displacement factor    
*	((SP)) = code relocation factor    

REL1	XCHG    
	DAD	B	(HL) = absolute address of word to relocate    
	XCHG		(DE) = abs code address, (HL) = rel table addr    
	XTHL		(HL) = code rel factor    
	LDAX	D    
	ADD	L	Relocate word of code    
	STAX	D    
	INX	D    
	LDAX	D    
	ADC	H    
	STAX	D	Relocate    
	XCHG		(DE) = relocation factor    
	POP	H	(HL) = relocation table entry address    
	JMP	REL	Do It again    


**	TFE - Test for EOF    
*    
*	TFE checks for end of file - indicated by    
*	  1) AIO.CGN = AIO.LGN    
*	  2) AIO.CSI = AIO.LSI    
*    
*	ENTRY	None    
*	EXIT	'Z' clear if NOT EOF    
*		(A) = 0    
*		'Z' set if EOF    
*		'C' set    
*		(A) = EC.EOF    
*	USES	A,F,H,L    

TFE	LHLD	AIO.LGN    
	ERRNZ	AIO.LSI-AIO.LGN-1    
	LDA	AIO.CGN    
	CMP	L    
	MVI	A,0    
	RNE		Not EOF    
	LDA	AIO.CSI    
	CMP	H    
	MVI	A,0    
	RNE		Not EOF    
	MVI	A,EC.EOF*2+1	set EOF code    
	RET		    

**	RUC - restore user code    
*	RCU restores the user program code which was swapped    
*	for the OVL code.  Since RUC resides in the OVL area,    
*	it may not retrun after the disk I/O call    
*    
*	ENTRY	None    
*	EXIT	None    
*	Uses	None    

RUC	CALL	$SAVALL	Save registers    
	LXI	H,$RSTALL    
	PUSH	H	Resturn via $RSTALL    
	LXI	H,S.OVLFL    
	MOV	A,M    
	ANA	A    
	ERRNZ	OVL.UCS-200Q    
	RP			Not swapped    
	ANI	377Q-OVL.UCS-OVL.IN	Restore user code, remove OVL    
	MOV	M,A    
*	Restore user code    
	LHLD	S.UCSL    
	MOV	B,H    
	MOV	C,L	(BC) = COUNT    
	LHLD	S.UCSF    
	XCHG		(DE) = ADDRESS    
	LHLD	S.SSN	(HL) = sector for swap    
	JMP	SREAD	Read and exit.    

**	SYDD - system disk device driver    
*	SYDD is the HDOS system H17 device driver    
*    
*	ENTRY	(A) = DC.XXX function code    
*		Other registers set as needed by function    
*		Registers set by function    
*		'C' set, error    
*		(A) = error code    
*	USES	All    

R.SYDD	EQU	*    
	ERRNZ	DC.REA    
	ANA	A    
	JZ	D.READ    
	ERRNZ	DC.WRI-1    
	DCR	A    
	JZ	D.WRITE    
	ERRNZ	DC.RER-2    
	DCR	A    
	JZ	D.READR	READ regardless    
	CPI	DC.ABT-2    
	JC	D.XOK	Is not abort or mount, ignore    
	ERRNZ	DC.MOU-DC.ABT-1    
	JE	D.ABORT	is abort    
	JMP	D.MOUNT    

***	Mount - mount new device    
*    
*	Mount processes device dependent mounting of new media    
*    
*	The volume serial (number?) is read into the volume table    
*	and the heads are homed.    
*    
*	ENTRY 	(L) = volume number (if any)    
*	EXIT	(not specified in source)    
*	USES	(Not specified in source)    

R.MOUNT	EQU	*    
	MOV	B,L	(B) = volume serial    
	LXI	H,0	Set sector index    
	CALL	D.SDP	Set device parameters    
	CALL	D.STZ	Seek track 0    
	LHLD	D.VOLPT    
	MOV	M,B	Set volume number    
	JMP	D.XOK	Exit with stuff ok    

***	ABORT - abort any active I/O    
*	Abort causes any on-going I/O to be aborted    

R.ABORT	EQU	*    
	CALL	D.SDP	Set device parameters    
	CALL	D.STZ	Seek track zero    
.	SET	R.XOK	Implicit reference to R.XOK    
*	JMP	D.XOK	Exit as if ok (note: source has line commented out)    

***	XOK - exit with all ok flag    

R.XOK	XRA	A    
R.XIT	PUSH	PSW	Save status    
XIT1	LDA	D.DLYHS    
	ANA	A    
	JNZ	XIT1	Wait for hardware delays    
	DI		Lock out clock    
	LDA	D.DVCTL    
	ANI	DF.MO+DF.WR	Remove device select    
	OUT	DP.DC	Deselect motor    
	STA	D.DVCTL	update byte    
	LHLD	D.XITA    
	SHLD	D.DLYMO	Set 120/2 seconds of motor on    
	ERRNZ	D.DLYHS-D.DLYMO-1	Set 7*2 mS of head unsettle    
	POP	PSW    
EIXIT	EI		Restore interrups    
	RET    

***	Clock - Process clock interrupts    
*    
CLOCK	LDA	.TICCNT    
	RRC    
	RC		Not even    
	ANA	A    
	LXI	H,D.DLYMO    
	JNZ	CLOCK1	Not half second    
	DCR	A	(A) = -1    
	ADD	M	Subtract one    
	JNC	CLOCK1	Was zero    
	MOV	M,A	Update    
	JNZ	CLOCK1	Not time for motor off    
	LDA	D.DVCTL	    
	ANI	DF.WR	Remove all but RAM/WRITE    
	STA	D.DVCTL    
	OUT	DP.DC	Off motor    
CLOCK1	INX	H	(HL) = $DLYHS    
	ERRNZ	D.DLYHS-D.DLYMO-1    
	MOV	A,M	(A) = D.DLYHS    
	SUI	1    
	RC		Was zero    
	MOV	M,A    
	RET	    

***	READ - read from disk    
*    
*	ENTRY	(BC) = count    
*		(DE) = address    
*		(HL) = block number    
*		Interrupts enabled    
*	EXIT	(DE) =next unused address    
*		Interrupts disabled    
*	USES	All    

R.READ	PUSH	H	SAVE (HL)    
	CALL	D.SDP	SETUP DEVICE PARAMETERS    
	LHLD	D.OPR    
	INX	H    
	SHLD	D.OPR	COUNT OPERATION    

*	read to read sector    
*	(BC) = amount    
*	(DE) = address    
*	((SP)) = sector number    

READ1	POP	H	(HL) = sector number    
	PUSH	D	Save address    
	MOV	A,C	Adjust (B) so that (B) = # of whole or partial    
	ANA	A	sectors to read. (C) = bytes of last sector to    
	JZ	READ1.5	read. (C) = 0 if to read entire last sector    
	INR	B    

**	**** NOTE ****    
*	This code runs with interrrupts disabled from here on    

READ1.5	PUSH	B	Save count    
	CALL	D.DTS	Decode track and sector    
READ2	MVI	A,1	(A) = delay count for start    
*	Look for right sector    
*	(A) = delay count before search    

READ2.4	CALL	D.UDLY	Delay some uS    
	CALL 	D.LPS	Locate proper sector    
	JC	READ7	ERROR    
	POP	B	(BC) = count    
	POP	H	(HL) = address for data    

*	check amount to read    

READ3	MOV	A,B    
	ORA	C    
	JZ	READ8	No more to read    
	PUSH	H    
	PUSH	B	Save count and address in case of error    
	DCR	B	See if on last (maybe partial) sector    
	JZ	READ3.5	On last sector, read (C) count    
***** Start of page 43    
	MVI	C,0	will read all 256 bytes    
READ3.5	MOV	B,C	(B) = # to read +1, (C) = # to skip    
	CALL	D.WSC	Wait for sync character    
	JC	READ71	Didn't get one    

*	READ DATA    
READ4	CALL	D.RDB	READ BYTE    
	MOV	M,A	STORE    
	INX	H    
	DCR	B    
	JNZ	READ4	MORE TO GO    
	MOV	A,C    
	ANA	A    
	JZ	READ6	NONE TO DISCARD    

*	READ, CHECKSUM, AND DISCARD DATA    
READ5	CALL	D.RDB    
	INR	C    
	JNZ	READ5    
READ6	MOV	B,D	(B) = CHECKSUM    
	CALL	D.RDB    
	CMP	B    
	JNE	READ72	CHECKSUM ERROR    

*	GOT GOOD SECTOR    
	POP	B	(BC) = OLD COUNT    
	DCR	B	COUNT SECTOR READ    
	JZ	READ8	JUST READ LAST ONE    

*	HAVE MORE TO READ    
	XTHL		SAVE ADDRESS    
	PUSH	B	SAVE COUNT    
	LXI	H,D.TS    
	INR	M	COUNT SECTOR    
	MVI	A,10    
	SUB	M    
	MVI	A,0    
	ERRNZ	30*64*2/15-1000A	(A) = time to delay for 30 char's    
	JNE	READ2.4	Not at end of track    
	MOV	M,A	Sector # = 0    
	ERRNZ	D.TS-D.TT-1    
	DCX	H    
	INR	M    
	EI		Restore interrupts until *STS* called    
	CALL	D.SDT	Seek desired track    
	JMP 	READ2    

*	Can't get data, header or checksum problem    
READ71	LXI	H,D.E.MDS	Missing data sync error    
	CALL	D.ERRT    
	JMP	READ7    
READ72	LXI	H,D.E.CHK	CHecksum error    
	CALL	D.ERRT    

READ7	CALL	D.CDE	Count disk error    
	JNC	READ2	Try again    
	POP	B    
	POP	D    
	MVI	A,EC.RF	Read failure    
	JMP	D.XIT	Too many errors, too bad    

* 	Entire read was ok    
READ8	POP	H	Clean stack    
	JMP	D.XOK	Exit ok    

***	READR - read disk regardless of volume protection    
*    
*	ENTRY	(BC) = count    
*		(DE) = address    
*		(HL) = block #    
*	EXIT	(DE) = next unused address    
*	USES	All    

R.READR	PUSH	H	Save (HL)    
	CALL	D.SDP	Setup device parameters    
	LXI	H,ZEROS    
	SHLD	D.VOLPT    
	JMP	READ1	Process as regular read    

***	WRITE - process disk write    
*    
*	ENTRY	(BC) = count    
*		(DE) = address    
*		(HL) = block #    
*	EXIT	(LINK) = last block #    
*	USES	All    

R.WRITE	EQU	*    
	PUSH	H	Save block #    
	CALL	D.SDP	Set device parameters    
	LHLD	D.OPW    
	INX	H    
	SHLD	D.OPW	Count operation    
	IN	DP.DC	See if dick write protected    
	ANI	DF.WP    
	STC    
	MVI	A,EC.WP    
	JNZ	WRITE8	Disk is write protected    

*** Ready to write sector    
*    
*  (BC) = count    
*  (DE) = address    
*   ((SP)) = sector number    

	LXI	H,377Q    
	DAD	B    
	MOV	B,H	(B) = # sectors to write    

WRITE1	POP	H	(HL) = sector number    
	PUSH	D	Save address    

*	** NOTE **    
* This code runs with interrupts disabled form this point on    
	CALL	D.DTS	Determine track and sector    
WRITE2	MVI	A,1	(A) = short delay count    

* find right sector (A0 = delay count    
WRIT2.5	CALL	D.UDLY	Delay some microsecs    
	PUSH	B	Save count    
	CALL	D.LPS	Locate proper sector    
	POP	B	(BC) = count    
	JC	WRITE7	Can't find it    
	POP	H	(HL) = address    
	LDA	D.WRITA	(A) = guardband delay    
WRITE4	DCR	A    
	JNZ	WRITE4	Pause over guardband    
	LDA	D.WRITB    
	MOV	C,A	(C) = # of 00 characters    
	LDA	D.WRITC	(A) = 128/2 = two character times before writing    
	CALL	D.WSP	Write sync pattern    

WRITE5	MOV	A,M    
	CALL	D.WNB    
	INX	H    
	DCR	C    
	JNZ	WRITE5	Not done yet so loop    
	MOV	A,D	(A) = checksum    
	CALL	D.WNB	Write checksum    

*	Have completed writing, leave write-gate open for 3 character times    
*	to finish tunnel erasing    

	CALL 	D.WNB    
	CALL	D.WNB    
	CALL	D.WNB    
	LDA	D.DVCTL    
	OUT	DP.DC	Off disk control    
	DCR	B    
	JZ	D.XOK	All done    
	PUSH	H	SAVE ADDRESS    
	LXI	H,D.TS    
	INR	M    
	MVI	A,10    
	SUB	M    
	MVI	A,0    
	ERRNZ	30*64*2/15-1000A	(A) = ct to delay 30 character x    
	JNZ	WRIT2.5	Not at end of track    

*	move to next track    
	ERRNZ	D.TS-D.TT-1    
	MOV	M,A	clear current sector index    
	DCX	H    
	INR	M    
	EI		Restore interrupts until *STS* call    
	CALL	D.SDT	Seek desired track    
	JMP	WRITE2    

*	ERROR    
WRITE7	CALL	D.CDE	Count disk error    
	JNC	WRITE2	try again    
	MVI	A,EC.WF	write failure    
WRITE8	POP	H	restore stack    
	JMP	D.XIT	Too many .. try again    

***	CDE - count disk errors    
*	CDE is called when a disk soft error occurs.  If there have     
*	been 10 soft errors for this operation then a hard error    
*	is flagged.    
*    
*	ENTRY	None    
*	EXIT	'C' set if hard error    
*		Interrupts disabled    
*	USES	A,F,H,L    

R.CDE	EI    
	CALL	D.STZ	Seek track zero    
	CALL	D.SDT	seek desired track    
	ANA	A	Clear carry    
	LHLD	D.SECNT    
	INX	H    
	SHLD	D.SECNT	Increment count    
	LXI	H,D.OECNT	(HL) = # operation error count    
	DCR	M    
	RP		Not too many    
	DCX	H	    
	MVI	A,-ERPTCNT    
	ADD	M	Remove soft count    
	MOV	M,A    
	ERRNZ	D.SECNT-D.HECNT-1    
	INR	M	Count hard error    
	STC    
	RET		Exit with 'C' set    

***	DTS - decode track and sector    
*	DTS decodes the track and sector number from    
*	the supplied sector index    
*    
*	ENTRY	(HL) = sector index    
*		Interrupts enabled    
*	EXIT	D.TS = sector number    
*		D.TT = track number    
*		Interrupts disabled    
*	USES	A,F,H,L    

R.DTS	PUSH	B	Save (BC)    
	LXI	B,-10	    
	MOV	A,B	(A) = 377Q    
DTS1	INR	A    
	DAD	B    
	JC	DTS1    
	STA	D.TT	Set track number    
	MOV	A,L    
	ADI	10    
	STA	D.TS	Set sector	    
	POP	B	restore (BC)    
	JMP	R.SDT	Seek desired track    

*** 	SDT - set desired track    
*	SDT moves the disk arm to the desired (D.TT) track    
*    
*	ENTRY	None    
*	EXIT	None    
*	USES	A,F,H,L    

*	Move arm in    
SDT3	INR	M    
	CALL	D.MAI    

R.SDT	LHLD	D.TRKPT    
	LDA	D.TT    
	CMP	M    
	JE	D.STS	Got there    
	JP	SDT3	Must move in    

*	Move arm out    
SDT1	DCR	M	update track number    
	CALL	D.MAO	move arm out    
	JMP	R.SDT	see if arm there yet    

***	MAI - move disk arm in one track    
*    
*	ENTRY	None    
*	EXIT	None    
*	USES	A,F    

***	MAO - move disk arm out    
*    
*	ENTRY	None    
*	EXIT	None    
*	USES	A,F    

R.MAI	MVI	A,DF.DI	Set direction	    
	DB	MI.CPI	Gobble XRA instruction    

R.MAO	XRA	A	Set direction    
	PUSH	H    
	MOV	H,A    
	LDA	D.DVCTL    
	ANI	377Q-DF.DI-DF.ST    
	ORA	H	Set direction    
	OUT	DP.DC	set direction    
	POP	H    
	ORI	DF.ST    
	OUT	DP.DC	Start step    
	XRI	DF.ST    
	OUT	DP.DC	Complete step    
	LDA	D.MAIA	(A) = MS/2 for track timing    
.	SET	D.DLY	Set reference to ROM {note period in 1st char}    
*	JMP	D.DLY	Delay 8 mS    

***	DLY - delay by front panel clock    
*    
***	MAI - move disk arm in one track    
*    
*	ENTRY	(A) = millisecond count/2    
*	EXIT	None    
*	USES	A,F    
R.DLY	PUSH	H    
	LXI	H,.TICCNT    
	ADD	M    
DLY1	CMP	M    
	JNE	DLY1    
	POP	H    
	RET    

***	LPS - Locate proper sector    
*	LPS reads over sector headers until the proper sector    
*	is found.    
*    
*	Upon entry, the arm should be positioned over the sector.    
*    
*	D.TT = desired track    
*	D.TS = desired sector    
***	MAI - move disk arm in one track    
*    
*	ENTRY	None    
*	EXIT	Interrrups disabled    
*		'C' set if error    
*	USES	All but C    

LPS0	CALL	D.STS	Skip this sector    

R.LPS	LDA	D.LPSA	(A) = #trys for this sector    
	MOV	B,A    
	LDA	D.DLYHS    
	ANA	A    
	JNZ	LPS0    

LPS1	DI    
	CALL	D.WSC	wait for sync character    
	JC	LPS3	none    
	LHLD	D.VOLPT    
	CALL	D.RDB    
	CMP	M	see if proper volume    
	JNE	LPS4	wrong volume    
	LXI	H,D.TT    
	CALL	D.RDB    
	CMP	M	see if proper track    
	JNE	LPS5	wrong track    
	ERRNZ	D.TS-D.TT-1    
	INX	H    
	CALL	D.RDB    
	CMP	M    
	JNE	LPS2	wrong sector    

*	got right sector, read checksum    
	MOV	H,D    
	CALL	D.RDB    
	CMP	H    
	RE		ALL OK    
	MVI	L,#D.E.HCK	Header checksum error    
LPS1.5	MVI	H,D.ERR/256	(HL) = error byte address    
.	SET	D.ERR/256    
	ERRNZ	D.ERRL/256-.	Must in same bank    
	CALL	D.ERRT	Count error    

*	Wrong sector or bad data. Try some more    

LPS2	CALL	D.STS	Skip this sector    
	DCR	B    
	JNZ	LPS1	Try again    
	STC		Enough trys    
	RET		ERROR    

LPS3	MVI	L,#D.E.HSY	Header sync error    
	JMP	LPS1.5    

LPS4	MVI	L,#D.E.VOL	Bad volume number    
	JMP	LPS1.5	count error    

LPS5	MVI	L,#D.E.TRK	Bad track number    
	JMP	LPS1.5    

***	RDB - Read byte from disk    
*	RDB reads the next byte from the disk    
*    
*	ENTRY	(D) = checksum    
*	EXIT	(A) = byte    
*		(D) updated    
*	USES	A,F,D,E    

R.RDB	IN	UP.ST    
	ERRNZ	UF.RDA-1    
	RAR    
	JNC	R.RDB	Not ready yet    
	IN	UP.DP	(A) = data    
	MOV	E,A    
	XRA	D	Differ    
	RLC		Shift left    
	MOV	D,A	Replace    
	MOV	A,E	(A) = char    
	RET    

***	SDP - set device parameters    
*	SDP sets up arguements for the specific unit    
*	D.DVCTL = motor on, device select    
*	D.TRKPT = address of device track number    
*    
*	ENTRY	AIO.UNI = unit number    
*	EXIT	(HL)= (D.TRKPT)    
*	USES	A,F,H,L    

R.SDP	MVI	A,ERPTCNT    
	STA	D.OECNT	Set max error count for operation	    
	LDA	AIO.UNI    
	PUSH	PSW	save unit number    
	INR	A	(A) =1 if Dev 0, 2 if dev 1    
	ADD	A    
	ERRNZ	DF.DSO-2	Select 0 or 1    
	ERRNZ	DF.DS1-4	    
	DI		Interlock clock interrupts    
	LXI	H,D.DVCTL    
	XRA	M    
	ANI	377Q-DF.WR    
	XRA	M	Merge with DF.WR bit from D.DVCTL    
	ORI	DF.MO	Motor on    
	MOV	M,A	update    
	OUT	DP.DC	Select drive, load head    

*	See if heads have been unloaded logn enough to require load delay    
	LXI	H,D.DLYHS    
	MOV	A,M    
	ANA	A    
	MVI	M,0    
	JNZ	SDP1    
	LDA	D.SDPA    
	MOV	M,A    
SDP1	DCX	H    
	ERRNZ	D.DLYMO-D.DLYHS+1	(HL) = #D.DLYMO    
	MOV	A,M	(A) = motor on delay    
	MVI	M,120	60 secs before turn off again    
	ANA	A	'Z' if motor turned off    
	INX	H	(HL) = #D.DLYHS    
	JNZ	SDP2	Motor is still on    
	LDA	D.SDPB	(A) = motor wait time (mS/4)    
	MOV	M,A    
SDP2	EI    
	POP	PSW	(A) = unit number    
	ADD	A	(A) = 2*unit number    
	LXI	H,D.DRVTB    
	ADD	L    
	MOV	L,A	(HL) = address of track entry    
	SHLD	D.TRKPT    
	INX	H    
	SHLD	D.VOLPT	set volume number    
	RET    

***	STS - skip this sector    
*	STS is called to skip the current sector, regardless of where    
*	the head is positioned.    
*	    
*	STS will exit at the beginning of the next sector    
*    
*  1. if the head is not over a hole, wait 8 mS while    
*     hole checking. If no hole in this time, when we are in    
*     a regular gap.  Wait for the next hole and exit.    
*    
*  2. If the head is over a hole or becomes so during the 8 mS wait,    
*     then wait for the hole to pass.  Wait 12 mS in case of the index    
*     then wait for the next hole and exit.    
*    
*	ENTRY	None    
*	EXIT	Interrrups disabled    
*	USES	A,F,H,L    

R.STS	EI    
	PUSH	B	save (BC)    
	IN	DP.DC    
	ERRNZ	DF.HD-1    
	RAR    
	JC	STS2	Am currently over hole    

*	No hole yet. Wait 8 mS minimum (10 max) for hole to appear    

	LXI	H,.TICCNT    
	MOV	B,M	(B) = current time    
STS1	IN	DP.DC    
**** LINE 2679 PAGE 54    
	RAR    
	ERRNZ	DF.HD-1    
	JC	STS2	Got hole    
	LDA	D.STSA	(A) = delay count    
	ADD	B	10 mS max, 8mS min     
	CMP	M    
	JNE	STS1	8 mS not up yet    
	JMP	STS3	Am in sector gap    

* 	Have hole. Skip it and wait 12 mS    
STS2	CALL	WNH	Wait for no hole    
	LDA	D.STSB	(A) = count (10 mS min, 12 mS max)    
	CALL	D.DLY	Wait    
STS3	POP	B	Restore (BC)    
	DI    
*	JMP	WHD	Wait hole detect {source disabled}    

***	WHD - Wait hole detect    
*	WHD waits until a hole is located    
*    
*	ENTRY	None    
*	EXIT	None    
*	USES	A,F    

WHD	IN	DP.DC    
	ERRNZ	DF.HD-1    
	RAR    
	JNC	WHD	Wait until found    
	LDA	D.WHDA	(A) = loop delay count    
	JMP	D.UDLY    

***	STZ - seek track zero    
*	STZ seeks the selected unit arm outwards until it reaches    
*	Track 0    
*    
*	The arm position byte is then updated to 0    
*    
*	ENTRY	Interrupts enabled    
*	EXIT	Interrrups enabled    
*	USES	A,F,H,L    

STZ0	CALL	D.MAO	Move arm out    
R.STZ	IN	DP.DC    
	ANI	DF.T0    
	JZ	STZ0	Not track 0 yet    
	LHLD	D.TRKPT    
	MVI	M,0	Set track pointer    
	RET    

***	WNH - wait for no hole    
*	WNH waits until the current hole is past    
*    
*	ENTRY	None    
*	EXIT	None    
*	USES	A,F    

WNH	IN	DP.DC    
	ERRNZ	DF.HD-1    
	RAR    
	JC	WNH	Still hole    
	LDA	D.WNHA	(A) = debounce count    
.	SET	R.UDLY	Reference to R.UDLY    
*	JMP	D.UDLY	Wait a little    

*** 	UDLY - microsectond delay    
*	UDLY is called (with interrupts disabled)    
*	to wait a certain number of microseconds    
*    
*	Each time through the delay loop causes a pause of    
*	15/2.048 uS    
*    
*	ENTRY	(A) = loop count (zero taken as 256)    
*	EXIT	(A) = 0    
*	USES	A, F    

R.UDLY	DCR	A    
	JNZ	R.UDLY    
	RET    

***	WSC - wait for sync character    
*	WSC waits for the appearance of a sync character. The disk should be    
*	selected, moving, and the head should be over the pre-syn zero band.    
*    
*	If a sync is not detected in 25 character times, an error is returned.    
*    
*	ENTRY	None    
*	EXIT	'C' clear if ok, sync character read    
*		(D) = 0 (checksum)    
*		'C' set if no sync found    
*	USES	A,F, D    

R.WSC	MVI	A,C.DSYN    
	OUT	UP.SC	    
	IN	UP.SR	    
	LDA	D.WSCA	(A) = NUMBER OF LOOPS IN 25 CHARACTERS    
	MOV	D,A    
WSC1	IN	DP.DC    
	ANI	DF.SD	See if sync    
	JNZ	WSC2	got sync    
	DCR	D    
	JNZ	WSC1	Try some more    

*	couldn't find sync    
	STC		Can't find sync	    
	RET    

*	Found sync    
WSC2	IN 	UP.DP	Gobble sync character    
	MVI	D,0	Clear checksum    
	RET    

***	WSP - write sync pattern    
*	WSP writes a sync pattern of zeros, followed by a sync character.    
*    
*	ENTRY	(A) = initial delay counter    
*		(C) = # of zero bytes to write    
*	EXIT	(D) = checksum    
*		(C) = 0    
*	USES	A,F,C,D,E    

R.WSP	DCR	A    
	JNZ	R.WSP	DELAY    

*	delay is up on write gate    
	LDA	D.DVCTL    
	ERRNZ	DF.WG-1    
	INR	A	Set write gate    
	OUT	DP.DC	Set gate    

*	Used as an entry point by DDIAG     
WSP1	XRA	A    
	CALL	D.WNB    
	DCR	C    
	JNZ	WSP1	Do more    
	MVI	A,C.DSYN    
	MOV	D,A	Pre-clear checksum so WNB exits with (D) = 0    
	JMP	D.WNB	Write next byte    

***	WNB - Write next byte    
*	WNB write a byte to the disk, assuming that the write gate    
*	is already selected    
*    
*	ENTRY	(A) = character    
*		(D) = checksum    
*	EXIT	(D) = checksum    
*	USES	A,F,D,E    

R.WNB	MOV	E,A    
WNB1	IN	UP.ST    
	ANA	A    
	ERRNZ	UF.TBM-200Q    
	JP	WNB1	Not ready	    
	MOV	A,E    
	OUT	UP.DP	Out data    
	XRA	D    
	RLC    
	MOV	D,A    
	RET    

	DB	'G+S'    

***	Boot code    
*	Entered to boot system    

BOOT	DI		Want no trouble with interrupts!    
	LXI	SP,STACK	Clear stack    
	LXI	B,BOOTAL    
	LXI	D,BOOTA    
	LXI	H,D.CON    
	CALL	$MOVE	Move in constants and vectors    

*	ZERO WORK FIELD    
	LXI	H,D.RAM    
	MVI	B,D.RAML    
	CALL	$ZERO	Zero memory    
	STA	AIO.UNI    
	OUT	DP.DC	Off disk    

*	Setup all interrupt vectors to an EI/RET sequence    
	ERRNZ	UO.CLK-1    
	INR	A	    
	STA	.MFLAG    

	LXI	H,.UIVEC	(HL) = .UIVEC address, (A) = 1    
BOOT2	MVI	M,303Q	    
	INX	H    
	MVI	M,#EIXIT    
	INX	H    
	MVI	M,EIXIT/256    
	INX	H    
	ADD	A	Shift '1' into (A) left 1    
	JP	BOOT2	More to go    

*	Setup clock interrupts    
BOOT3	LXI	H,CLOCK    
	SHLD	.UIVEC+1    
	EI    

*	Read boot code    
	CALL	R.ABORT	    
	LXI	D,USERFWA    
	LXI	B,9*256    
	LXI	H,0    
	CALL	R.READ	    
	JNC	USERFWA	    

*	WAIT FOR CHARACTER TO BE ENTERED.    
	HLT    
	JMP	BOOT	Boot again    

****** page 59      
***	disk constant and vector initialization table    
BOOTA	EQU	*    
	ERRNZ	*-BOOTA+D.CON-D.XITA    
	DW	2*256+120	Head unsettle and motor on times    

	ERRNZ	*-BOOTA+D.CON-D.WRITA    
	DB	20	Guardband count for write    

	ERRNZ	*-BOOTA+D.CON-D.WRITB    
	DB	10	Number of zero characters after hold edge    
***** line 2933 on page 59    
	ERRNZ	*-BOOTA+D.CON-D.WRITC    
	DB	128/8	Two character delay before writing    

	ERRNZ	*-BOOTA+D.CON-D.MAIA    
	DB	15	Track-to-track step times    

	ERRNZ	*-BOOTA+D.CON-D.LPSA    
	DB	20	Number of trys for correct sector    

	ERRNZ	*-BOOTA+D.CON-D.SDPA    
	DB	70/4	70 mS wait for heat settle    

	ERRNZ	*-BOOTA+D.CON-D.SDPB    
	DB	1000/4	1 second wait for motor on    

	ERRNZ	*-BOOTA+D.CON-D.STSA    
	DB	8/2+1	mS/2 to wait for index hole    

	ERRNZ	*-BOOTA+D.CON-D.STSB    
	DB	12/2+1	mS/2 to wait past index hole    

	ERRNZ	*-BOOTA+D.CON-D.WHDA    
	DB	20	UDLY count for hole debounce    

	ERRNZ	*-BOOTA+D.CON-D.WNHA    
	DB	20	UDlY count for hole debounce    

	ERRNZ	*-BOOTA+D.CON-D.WSCA    
	DB	64*25/20	Loop count for 25 characters    

***	ERRT - Error test loop    
R.ERRT	INR	M	Count error    
	RET		Exit    

*	JMP Vectors    
	JMP	R.SYDD	D.SYDD (must be first)    
	JMP	R.MOUNT	D.MOUNT    
	JMP	R.XOK	D.XOK    
	JMP	R.ABORT	D.ABORT    
	JMP	R.XIT	D.XIT    
	JMP	R.READ	D.READ    
	JMP	R.READR	D.READR    
	JMP	R.WRITE	D.WRITE    
	JMP	R.CDE	D.CDE    
	JMP	R.DTS	D.DTS    
	JMP	R.SDT	D.SDT    
	JMP	R.MAI	D.MAI    
	JMP	R.MAO	D.MAO    
	JMP	R.LPS	D.LPS    
	JMP	R.RDB	D.RDB    
	JMP	R.SDP	D.SDP    
	JMP	R.STS	D.STS    
	JMP	R.STZ	D.STZ    
	JMP	R.UDLY	D.UDLY    
	JMP	R.WSC	D.WSC    
	JMP	R.WSP	D.WSP    
	JMP	R.WNB	D.WNB    
	JMP	R.ERRT	D.ERRT    
	JMP	R.DLY	D.DLY    
BOOTAL	EQU	*-BOOTA    

***	DDIAG - initial deive diagnosis    
DDIAG	EQU	*    
	MVI	A,DF.MO+DF.DS2+DF.WG    
	OUT	DP.DC	On disk    
	MVI	C,250    
	MOV	A,C	(A) = 250    
	CALL	R.DLY    
	MOV	A,C	(A) = 250    
	CALL	R.DLY	delay 1 second    
	DI    
	CALL	DDIAG0	Do check, return if error    

*	Disk Diagnostic error    
	EI    
	HLT    

*	Test disk    
DDIAG0	CALL	WSP1	Write sync pattern    
	LXI	B,3164    
DDIAG1	MVI	A,'G'    
	CALL	R.WNB	Write byte    
	DCX	B    
	MOV	A,B    
	ORA	C    
	JNZ	DDIAG1    
	MVI	A,30Q    
	OUT	DP.DC	Off write select    

*	Now try read    
	MVI	A,219    
	STA	D.WSCA	Wait for 68 chars max    
	CALL	R.WSC	Wait for sync detect    
	RC		Error    
	LXI	B,3164-2	Allow USART to gobble two during write     
DDIAG2	CALL	R.RDB	Read byte    
	CPI	'G'    
	RNE		Error    
	DCX	B    
	MOV	A,B    
	ORA	C    
	JNZ	DDIAG2    
	EI		Restore interrupts    
	HLT		Ok    

	DB	0,'JGL',0	Error routing code    
	DB	'HEATH'    
	DB	0    

	ERRPL	*-40001A	Overflow 
	END	START 

* ENDE listing    
