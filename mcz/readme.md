# ZILOG MCZ 8 BIT COMPUTERS

![MCZ IMAGE](pics/MCZPIC.png)
MCB cpu board (required)  
![MCB IMAGE](pics/PCB01MCBREVE.png)  
MDC floppy disk controller with 48K RAM (required)  
![MDC IMAGE](pics/PCB03MDC2.png)  
SIB multi serial port board (optional)  
![SIB IMAGE](pics/PCB04SIB.png)  
Z8000 development board (optional)  
![Z8000 IMAGE](pics/PCB05Z8000.png)  
  
# DOCUMENTATION
  
[MCZ-1/20 Hardware Users Manual](docs/03-0018-02_MCZ-1_20_25_Hardware_Users_Manual.pdf)  
[MCZ-1/20 MDC Hardware Reference Manual](docs/03-3006-02_Z-80_MDC_Hardware_Reference_Manual.pdf)  
[MCZ-1/20 FLOPPY PROM Users Guide](docs/03-3106-01A_MCZ-1_20A_and_MCZ-1_25A_Microcomputers_Floppy_Prom_User_Guide_Dec79.pdf)  
  
# RIO OPERATING SYSTEM
  
[RIO Operating System Users Guide](docs/03-0072-01A_Z80_RIO_Operating_System_Users_Manual_Sep78.pdf)  
[RIO Operating System Assembler Users Manual](docs/03-0073-00_Z80-RIO_Relocating_Assembler_and_Linker_Users_Manual.pdf)  
  
# SOFTWARE DISK IMAGES
**System Software (coming soon)**  
- 13-1000-01 UNABRIDGED SYSTEM DISK
- 13-3001-01 MCZ 1/05 1/20 1/25 1/30 RIO OPERATING SYSTEM
- 13-3309-05 MCZ/PDS FLOPPY DISK Z8000 SDP 3.0
- 13-3361-06 MCZ/PDS FLOPPY DISK Z8 SDP 4.0
- 13-3391-03 ASYNC MCZ 1/PDS FD SYSTEM REL 1.1  
- RIO 2.2 PDS8000 MCZ 1/20 SYSTEM DISK
- SYSTEM (DEV SOFTWARE FOR Z8000 - 4 DISK SET)
- RIO 2.06 SYSTEM DISK WITH ZILOG BASIC

# DISK IMAGING SOFTWARE
- currently in development

# DEV NOTES
**Read from TTY console**  
```asm
SERDAT:	EQU	0DEH
SERCON:	EQU	0DFH
RXRDY:	EQU	1

TTYIN:  IN 	A,(SERCON)
	BIT	RXRDY,A
	JR	Z,TTYIN		; NOT READY YET.
	IN	A,(SERDAT)
```  
  
**Write to TTY console**  
```asm
SERDAT:	EQU	0DEH
SERCON:	EQU	0DFH
TXRDY:  EQU 0

TTYOUT:	
	PUSH	AF
TTYOU1:
	IN	A,(SERCON)
	BIT	TXRDY,A
	JR	Z,TTYOU1
	POP	AF
	OUT	(SERDAT),A
```

![DISK FORMAT](pics/DSKFMT.png)
  
**Read a sector**  
```asm
RD_DAT  EQU     04H
TIM256  EQU     61
DSKDAT	EQU	0CFH
DSKCOM	EQU	0D0H
DSSTAT	EQU	0D0H

RDSECT: LD	HL,(BFFADD)	; GET USER DATA AREA.
        PUSH	HL
        LD	HL,DS_BUF	; ADDRESS OF SECTOR ADDRESS.
        LD	A,RD_DAT	; PREPARE TO TURN ON READ AMP.
        LD	B,TIM256

;       175 T-STATES FROM INTERRUPT

        DJNZ	$		; TIME OUT
        OUT	(DSKCOM),A
        LD	BC,8000H+DSKDAT	; 128 BYTES OF SECTOR DATA

; 400 USECS FROM INTERRUPT

        IN	A,(DSKDAT)	; INPUT SECTOR ADDRESS.
        CP	(HL)		; COMPARE IT.
        POP	HL		; GET DATA ADDRESS.
        IN	A,(DSKDAT)	; INPUT TRACK ADDRESS.
        JP	NZ,WRNGSC
READIT: INI			; READ 80H BYTES OF DATA
        NOP
        NOP
        NOP
        JR	NZ,READIT
        LD	HL,PTRS		; INPUT THE POINTERS.
        INI
        LD	B,5
        INIR
        IN	A,(DSSTAT)	; CHECK FOR CRC ERROR.
        BIT	CRC,A
        LD	A,B		; SET A TO ZERO TO
        OUT	(DSKCOM),A	; TURN OFF READ.
        JR	NZ,BADCRC
```
  
**Write a sector**
```asm
WRCRC   EQU     18H
TIM512  EQU     73
DSKDAT	EQU	0CFH
DSKCOM	EQU	0D0H
DSSTAT	EQU	0D0H

WRTOK: 	LD	BC,8200H+DSKDAT
        LD	HL,(BFFADD)	; GET USER DATA ADDRESS.
        PUSH	HL
        LD	HL,DS_BUF	; ADDRESS OF SECTOR ADDRESS.
        LD	A,TIM512	; TIME OUT 512 USECS. FOR PREAMBLE.

; 229 T-STATES FROM INTERRUPT

        DEC	A
        JR	NZ,$-1

; 568 USECS FROM INTERRUPT

        OUTI
        OUTI
        POP	HL		; GET BACK DATA ADDRESS.
WRITIT: OUTI			; OUTPUT THE DATA.
        NOP			; INCREASE REFRESH RATE
        NOP
        NOP
        JR	NZ,WRITIT
        LD	HL,PTRS		; LOAD ADDRESS OF POINTERS.
        OUTI
        OUTI
        OUTI
        LD	A,WRCRC		; WRITE CRC ENABLE
        OUTI			; OUTPUT LAST POINTER
        OUT	(DSKCOM),A	; ENABLE CRC
        OUT	(DSKDAT),A	; OUTPUT TWO CRC WORDS.
        OUT	(DSKDAT),A
        XOR	A		; CLEAR A
        OUT	(DSKDAT),A
        OUT	(DSKDAT),A
        OUT	(DSKCOM),A
        JR	FINOP
```
  
**MCZ PROM LISTING**  
[MCZ PROM SOURCE LISTING](src/MCZ.PROM.78089.L)  
[MCZ PROM SOURCE CODE](src/MCZ.PROM.78089.S)  
