# ZILOG MCZ 8 BIT COMPUTERS

![MCZ IMAGE](pics/MCZPIC.png)  
  
Front view with installed cards (right to left: MCB,MDC2,SIB - note the required slot locations for each card)  
![MCZ FRONT](pics/PDS-MOD5-FRONT-OPEN-Z8000.JPG)  
  
Drive 1 board configuration (addressed as drive **0** in the RIO OS)  
![MCZ DS0](pics/PDS-MOD5-DS0.JPG)  
  
Drive 2 board configuration (addressed as drive **2** in the RIO OS - note the 4 terminator jumpers)  
![MCZ DS1](pics/PDS-MOD5-DS1.JPG)  
  
MCB cpu board (required for functional system)  
![MCB IMAGE](pics/PCB01MCBREVE.png)  
  
MDC floppy disk controller with 48K RAM (required for functional system)  
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
**System Software**  (335KB)
- [13-1000-01 UNABRIDGED SYSTEM DISK](https://drive.google.com/file/d/1S8CdG0heZX6rx3Lu4Yhft_gOVtjvQO3g/view?usp=sharing)
- [13-3001-01 MCZ 1/05 1/20 1/25 1/30 RIO OPERATING SYSTEM](https://drive.google.com/file/d/1lxR58Ioxn_rV4gfGed1RWfSN5SNofkwC/view?usp=sharing)
- [13-3001-03 MCZ RIO 2.2 WITH MCZIMAGER AND BASIC](https://drive.google.com/file/d/1qn5fDMmVz75WKUL_7HKzWmwiM-IDD1iZ/view?usp=sharing)
- [13-3001-03 MCZ/PDS RIO 2.2](https://drive.google.com/file/d/12AsWyJgidSBs8qwPeehfMdyAvEYc4_Nv/view?usp=sharing)
- [13-3309-05 MCZ/PDS FLOPPY DISK Z8000 SDP 3.0](https://drive.google.com/file/d/1dPCjObwaHzy8frUUW2HsT1oG9Zo23pXo/view?usp=sharing)
- [13-3361-06 MCZ/PDS FLOPPY DISK Z8 SDP 4.0](https://drive.google.com/file/d/1NoaU3jMIE_HGKojCwaUJ6-3J85oi17aZ/view?usp=sharing)
- [13-3391-03 ASYNC MCZ 1/PDS FD SYSTEM REL 1.1](https://drive.google.com/file/d/1j5vn7_MgA3J5fTIL2R7T6lwrLziEWqBq/view?usp=sharing)
- [RIO 2.2 PDS8000 MCZ 1/20 SYSTEM DISK](https://drive.google.com/file/d/1GXXkUx8c5iuZNeWE2ZX732U0AsFuD3TK/view?usp=sharing)
- [SYSTEM (DEV SOFTWARE FOR Z8000 - 1 OF 4)](https://drive.google.com/file/d/1Dcsd-38Wq5MzV1vkYWjHhNE3PtAXvzvR/view?usp=sharing)
- [SYSTEM (DEV SOFTWARE FOR Z8000 - 2 OF 4)](https://drive.google.com/file/d/1fTGEOyvsGMFwBxHb-6tkocO4zJlBHH7O/view?usp=sharing)
- [SYSTEM (DEV SOFTWARE FOR Z8000 - 3 OF 4)](https://drive.google.com/file/d/17OHB0qkfkceu39YZDeohybeWXgP_rd6d/view?usp=sharing)
- [SYSTEM (DEV SOFTWARE FOR Z8000 - 4 OF 4)](https://drive.google.com/file/d/1J8_X7wnGGqapTyQAjRGW7n-IMwLiRBfC/view?usp=sharing)
- [Z8000 ASM](https://drive.google.com/file/d/1DcKXiebNaZmLAqRVR2I8HIPpLGz2e5Ds/view?usp=sharing)
- [Z8000 BACKUP](https://drive.google.com/file/d/1ju-9qQ9mMlZd72wH3_2eotzPv3F93HAT/view?usp=sharing)
- [Z8000 DEV MODULE SOURCE](https://drive.google.com/file/d/1CRevT1DjZgiZUNM5yZnOlTRbYYkOP71m/view?usp=sharing)
- [Z8000 DEV MODULE](https://drive.google.com/file/d/1kuacpstJnPm3lpgMFJbeiQ7lnvP4F5DP/view?usp=sharing)

# DISK IMAGING SOFTWARE
- 6/24/2021 working disk imaging solution with some caveats
- As of 6/24/2021 I can read disks and create digital copies including back/forward file pointers
- As of 6/24/2021 I can write disk images to a floppy on the MCZ system
- Caveats:
- Currently requires a RIO bootable system and will only write to preformatted RIO disks
- Plan moving forward:
- Convert FORMAT program to binary hex so can upload using MCZ debug console so can format disks (not sure if this will work)
- Convert MCZIMAGER client to binary hex so can upload using MCZ debug console so can receive disk images and write to floppy disk
- Imager currently uses MCZ console serial port to send/receive disk images
- Host software is written in Unity C# so can port to pretty much all platforms (Linux, OSX, PC)

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
