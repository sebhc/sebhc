File DZ--READ.ME     29 Nov 86            DazzleStar Disassembler
                                         (User-supported software)
1. Is it a bird, is it a...
---------------------------

DazzleStar (DZ) is an interactive disassembler.  It requires a 
Z80 CP/M system, and at least 48K of RAM (preferably more).  
DazzleStar lets you examine an 8080 or Z80 program (a .COM file) 
and decode it into Z80 assembler instructions, showing the result 
on your screen or printer, or producing an assembler source file 
on disk.  Many of the commands are in the style of WordStar (and 
other commonly used microcomputer editors).

If you've used a disassembler before, you'll know that recon-
structing and understanding a program (using sensible names for 
the labels, and meaningful comments) is a painful process.  No 
disassembler can be a complete pain killer.  But DazzleStar does 
make the pain more endurable.

DazzleStar is big, but doesn't limit the size of the program to 
be disassembled.  This freedom is due to the way in which 
DazzleStar reads the program to be disassembled, using a paging 
technique to ensure that few of the accesses require it to re-
read the disk.


2. What you've received
-----------------------

You should have a file DZ-NOV86.LBR, which contains the 
following:

     -CATALOG.000   CRC values for the following files
     DZ--READ.ME    (This file) Read this first
     DZ-BRIEF.DOC   Print this and paste it on the wall
     DZ-FIXES.DOC   Past and future
     DZ.COM         The interactive disassembler program
     DZENGHLP.OVR   Overlay file (help) for DZ.COM (English version)
     DZENGMNU.OVR   Overlay file (menus)
     DZENGMSG.OVR   Overlay file (messages)
     DZINSTAL.CFA   Data file for DZINSTAL.COM
     DZINSTAL.COM   Installation and customization program


3. Licence
----------

This library is NOT public domain.  Copyright is retained by the 
author, John Washington, and all rights are reserved.

A licence is granted for free use and re-distribution of this 
library, subject to the following conditions:

1.   Users may not modify any copyright notices, nor suppress the 
     display of any such notices.

2.   Re-distribution may only be made by distributing this 
     library exactly in its present form, with no additions, no 
     deletions, no amendments of ANY kind.

3.   Use and redistribution may only be made without profit, 
     except when prior written agreement has been granted by the 
     author.  This library may not be included in any other 
     package for sale.  Modest charges to cover media copying and 
     distribution are permitted, provided that the author is 
     notified of this intent.

Please report any violations to the author.  Thank you.


4. WARNING and disclaimer
-------------------------

The author will have no liability or responsibility in the event 
of any loss or damage caused or alleged to be caused directly or 
indirectly by this program.


5. Getting started
------------------

If you obtained your master disk direct from me, I have probably
included NULU.COM, NULU15.LBR, CRUNCH22.LBR and CRC.COM on the
disk.  If you downloaded from a bulletin board, you can almost
certainly find NULU, CRUNCH and CRC elsewhere on that board (if
you really can't, I suggest you ask the sysop for advice before
contacting me, though I'll be happy to act as longstop).

These installation instructions assume you have two disk drives. 
It is possible to install and run DazzleStar with only a single
drive, but I have no experience of doing so.  I have two 800K
drives and therefore have never calculated the disk capacity
required.  I imagine much smaller drives will suffice.

You should now have a master disk containing the file DZ-
NOV86.LBR.  We'll call this disk 1A.  You should also have a disk 
containing NULU.COM, UNCR.COM and CRC.COM, which we'll call disk 
1B (or you could have everything on one disk if there's enough 
room, in which case we'll call it disk 1).

Your first task is to use NULU to split up the library into its 
component files, and then use UNCR to expand these files into 
working versions.  Put disk 1B (or 1) into drive A, and press ^C.  
Put an empty (but formatted) disk (call it disk 2) into drive B.  
Type

          B:
          A:NULU                   (Start running NULU)

Remove disk 1B from drive A, and replace it with disk 1A (unless 
1A and 1B are the same disk, disk 1).  Then type

          -O A:DZ-OCT86            (Open the library file)
          -Q *.*                   (Extract & unsqueeze contents)
          -C                       (Close the library file)
          -X                       (Exit to CP/M)

Remove disk 1A from drive A and replace it with disk 1B.
Type
          B:
          A:UNCR *.*               (Uncrunch all files)
          DIR B:

Each line is terminated with the <return> key, as usual for CP/M.

Disk 2 should now have the files as mentioned in section 2 (above).

Your next task is to use CRC.COM to check that you received the 
files ok, and they have been correctly reconstituted.  Put disk 
1A into drive A, and warm boot (press ctrl-C).  Type

          B:<return>
          A:CRC<return>

If the CRCs don't all check out, or any files are missing, this 
is very serious -- first check with your sysop.  If his copy is 
also corrupt, please contact me URGENTLY.  Do not try to continue
with a bad copy.

I've had reports that the CRC.COM that I use (version 5.0) may 
not work properly on CP/M 3.  Since I only use CP/M 2.2 I'm 
unable to advise on this (and I'd appreciate guidance from a 
knowledgable CP/M 3 user).

Now that you have a good version...  Before doing anything 
further, MAKE A COPY, and put your master disk on the shelf out 
of harm's way.  

If you have a printer, you may find it useful to print out the
following files

     DZ--READ.ME (this file)
*    DZ-BRIEF.DOC
     DZ-FIXES.DOC
*    DZENGHLP.OVR

The files marked "*" are in WordStar "document" format, and
therefore are most easily printed by using WordStar.  If you don't
have WordStar, you can still get a reasonable listing by using a
printer (or CP/M BIOS) which ignores the high bit of characters. 
Some printers treat the high bit as a signal to use italics; if
you don't like that maybe there's an escape sequence which turns
off this feature.  Check your printer manual.  For an Epson
printer, try

          PIP LST:=CON:<return>
          <escape><hash or pound><ctrl-Z>

However, some printers treat the high bit as graphic characters, 
without any means of suppressing them, in which case you won't 
have much joy.  So try, for example,

          PIP DZENGHLP.TXT=DZENGHLP.OVR[Z]<return>

and print the new file DZENGHLP.TXT that PIP produces.



6. You've seen the trailer, now watch the film!
-----------------------------------------------

DazzleStar must use screen control codes, to achieve its 
impressive display.  As these codes are not the same for every 
computer, you can't run DazzleStar "straight out of the box" 
(unless you use a Hazeltine 1500 terminal).  First you have to 
run DZINSTAL which modifies DZ.COM to run properly on your 
screen.  Put disk 2 in your drive A.  Press ^C.

Type
          DZINSTAL<return>

DZINSTAL will present you with menu choices.  It is easy to use, 
provided that you resist any temptation to choose the menu option 
that sets you in expert mode.

Screen size is assumed to be not more than 25 rows of 80 columns.  
It is expected that most screens will have 24 rows, though 
perhaps 16 would be sufficient (though irritatingly small if you 
also want the menus).  DazzleStar can be used on an Epson Geneva 
PX-8 (only eight rows).  However, you need to be a very 
experienced user because no menu display is possible.  Well, I 
sometimes use it myself on a PX-8, and am really happy with it, 
but I guess I can fairly claim to be a VERY experienced 
DazzleStar user!

[Note for users with very low disk capacity:  during installation 
the only files required are DZINSTAL.COM, DZINSTAL.CF1, DZ.COM]


Having configured DZ.COM, you're ready to start disassembling.  
Choose something fairly small to start with, say, EXAMPLE.COM, 
and type

          DZ EXAMPLE<return>

[Note for users with very low disk capacity:  DZ.COM is only 
accessed for the initial program load, and can therefore be on a 
different drive.  The overlay files DZ*.OVR should be on the 
default drive (though this can be modified by DZINSTAL).  If a .OVR
file is not found, DZ will operate but will be rather cryptic.]


7. Problems
-----------

It isn't easy to write installation directions that work well on 
every machine, and for every user.  But I'd like to.  So tell me 
your horror stories, so I can do better next time.  Thanks.


8. You've seen the film, now get the book!
------------------------------------------

If you've followed these directions, there's sufficient 
information to allow you to make good use of DazzleStar.  But to 
make full use of it, get the manuals.  There are three manuals:
"Installation & Configuration", "Tutorial", and "Reference".  To
obtain the manuals, send an order form (see DZ-FORMS.DOC) together
with your registration fee.

... That's how it used to be, but life is too hectic at present 
for me to spend time printing and binding.  Look out for another 
library called DZDOCS86.LBR.  This will contain the text of the 
manuals.  In fact, my life is SO hectic at present, that I need 
regular doses of muscle relaxant.  So if you find DazzleStar 
entertaining then I'd appreciate a small contribution for my 
slate in the local.

Many thanks to the users who supported earlier versions of
DazzleStar; this new version is a direct result of your
encouragement.



9. Feedback
-----------

I'd like to get your ideas and comments, whether general or
detailed, positive or negative, on anything concerning DazzleStar.

Contact:      John Washington
              Washington Electronics and Systems Ltd
              33 Turnoak Avenue, Woking, Surrey, GU22 0AJ, England.

If you want a reply, YOU MUST include British postage stamps, or 
a dollar bill, or the smallest note in your local currency.  I am 
a typical generous-hearted Englishman (free advert for the 
English Tourist Board!), but postage costs do make a hole in my 
wallet.

enerous-hearted Englishman (free advert for the