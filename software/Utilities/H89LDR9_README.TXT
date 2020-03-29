         Disk Image Transfer Program  Vers. 8
               By Dwight Elvey
               CopyLeft 06/06/04

Hi
 This is the version 9 of my transfer program to move
disk images from a PC to a H89/8 and from the H89/8 to a PC.
 New features are that if the volume number is incorrect
it will abort without completing the transfer. It will
flag tracks that have read errors but will continue the
transfer. It has the added command to adjust the Baud
rate for use with H8-5 boards that do not work reliably
at 9600 Baud ( quite common ). The volume override command
is a little less confusing.
 It is intended to bring a H89/8 up without any floppies
with code to start the H89/8. It has poor error handling.
One needs to follow instructions or it will behave badly.
Put write protect tags on any disk you cherish.
 This has also been checked out with a H8 having a Z80
uP, XCON8 monitor and H8-4 serial board. On this board
I use channel 1. This is normally the LP port and is
at address 340Q at 9600 baud.
 It also works with the H8 8080 processor and the H8-5
Cassette/Serial board. The serial TX/RX must both be
set to the 9600 baud jumpered position. This transfers
through the main serial interface, in place of a terminal.
 If you experience troubles at 9600 Baud with the H8-5
you can change the Baud rate with the B command to a
slower rate that should work.
 It has been tested with a Z90 as well. Both the H89
and Z90 are required to have the serial expansion board
with the LP cable. It might work by using the serial
interface between the H88 part and the H19 part. If
so, one should use the H8 w/ H8-5 setup. One would
need to make a special cable as well.
 Make sure that the serial cable you use has the right
DTE/DCE sense. Use a light box or similar. It is a pain
to enter the entire boot strap routine, just to find
that the cabling is wrong. I have been using a 1:1 cable
for my setups but your setup may be different. Both
pin 2 and pin 3 should be active when both systems are
powered on.
 There are two methods of using this. The first way is
if you are bringing a system up from scratch or this is
the first time you've used this program. The second is if
you've made a copy of the loader onto a H89/8 disk,
after bringing it up from scratch( See the 'S' command ).
 This program is dependent on the H17 ROM inside of the H89/8
for much of its functions. It may not work with modified
ROMs or different versions. It runs on a standard H89/8
with a hard 10 sectored disk, 40 track and H17. It only uses
the first drive ( SY0: ). It only works currently with single
sided. It does not handle 80 track, single sided or double
sided 40 track ( yet ).
 There is a file that runs on the PC that uses a selected
serial port to do serial transfers. One must also have
the serial board in the H89. It uses the LP: serial port
with a straight 1-to-1 RS232 cable. For a H8 it must be
channel 1 of the H8-4 board or the serial port of a H8-5
board.
 The program on the PC is intended to run from DOS. It
will not work from a DOS window in Windows.
I'm told that one can disable a serial from windows
control panel but I've never tried this. If you boot a
pure DOS, it should work.
 You need to run H89TRANS from the same directory as the
files H8LDR.BIN and H89LDR1.BIN as it needs to find these
files to send to the H89/8 machine. It is convenient to
also keep the image file here as well but not required.
 The difference between rev 7 and 9 is that there is now
just one file H89LDR2.BIN instead of the two LDR files.
H89LDR2 looks at the bootstrap used to determine what type
of serial port is being used. There are still two different
boot strap octal files to enter, depending on the serial
port used on the H8.

This release has the following files:
 BOOTSTRP.ASM    Source file for H89 and H8 w/ H8-4
 BOOTSTRP.OCL *  Octal list to enter to H89/8
 BOTSTRP8.ASM    Source file for H8 w/ H8-5
 BOTSTRP8.OCL *  Octal list to enter to H8
 H89LDR2.ASM      Source to main loader H89/8
 H89LDR2.BIN *    Image for H89TRANS to use
 H89TRANS.SEQ    Forth source for the *.COM file
 H89TRANS.COM *  Executes on PC with menu.
 README.TXT      This file
  ( Note: * indicates needed files )
 It should be noted that if any of the source files are edited
in such a way that sizes of images are changed, it will effect
the other files as well. These files are all interlocked in
operation and require knowledge of the other files sizes. The
source files are mainly provided for informational use only.

Bootstrapping from Scratch for the H89:
 1. Connect a RS232 cable from the PC to the H89 LP port.
 2. Start the H89TRANS.COM program on the PC. DOS windows
    in Windows do not work. You need to boot to DOS.
 3. Select a com port that you are using, 1 to 4.

For a H89:
 1. Turn on the H89
 2. With no disk in the drive enter 'B'. This loads the
      H17 jump tables.
 3. Hit Shift-Reset to restore the H: prompt.
 4. Enter S43000<return>.
 5. Enter the bootstrap loader by typing in the values
    found in the file BOOTSTRP.OCL ( You should print
    this file out beforehand ). Enter only the byte value
    at the end of the line. The address is only there
    for reference and entry error checking. Between
    bytes entered, use the space bar to sequence to the
    next address. When complete use <return> to get back
    to the H: prompt.
 6. From the H: prompt enter G43000<return>.
    Skip over the H8 instructions.

Bootstrapping from Scratch for the H8:
Sequence for a H8-4 Serial board channel 1:
 1. Power up the H8 and disk drive with no disk in the
    drives.
 2. Reset and restart:
    For a H8 w/ XCON8 and PAM8:
     (REG) PC (Alter) 030 000 (GO)
     Wait 5 seconds until LED extinguish.
     0+/  ( simultaneous 0 and / for reset ).
 3. Hand enter the boot strap code found in the file
   A. For H8 w/ H8-4:
     Hand enter the text file BOOTSTRP.OCL from the monitor,
     one byte at a time into the H8's memory.
   B. For H8 w/ H8-5:
     Hand enter the text file BOTSTRP8.OCL from the monitor,
     one byte at a time into the H8's memory.

    Note: The *.OCL file can be seen with " MORE < File.Name "
           or other text viewer.
    Use the following sequence.
     (MEM) 043 000 (Alter)
      {Enter the .OCL file values now, about 50 bytes}
     (Alter)
     (REG)(PC)
     043 000 (Alter)
 4. Start the program H89TRANS on the PC. First select
    the serial port, 1 to 4.
 5. Hit the (Go) button on the H8.
 6. Enter the "L" option on the PC.
 7. If the menu returns, you were sucessful. If not,
    check that the code was entered correctly. If the bootstrap
    was working, the location 043.051 should have changed from
    351Q to 000Q. Make sure you entered the correct bootstrap
    and that you are using the correct serial ports. Make
    sure that the RS232 signals are correct.

Commond instructions for both H89 and H8:
Saving the loader to a Boot Image Transfer disk:
 1. On the PC, you should see a command table displayed.
    Type the letter L to download the main loader to the
    H89. Enter the L second time. You should see a message
    that it is already loaded. If this was successful, you
    entered the bootstrap correctly and can proceed.
 2. It is a good idea to save a bootable image of this
    main loader onto a disk so that you can use it later
    when you need to tranfer other disk images. To do
    this follow the remaining steps.
 3. With a blank disk, put the disk in the SY0: drive.
    The disk should not have a write protect notch covered.
 4. This is the last step. From the command table
    enter S to save the main loader to the disk so
    the next time you don't need to reenter the bootstrap
    code. Mark this disk as "Boots Image Transfer" and
    place a write protect tab on it.
 5. This disk can now be used to boot to the loader. It
    is not an HDOS disk. It is a standalone boot image.

Image Transfers:
 1. This assumes that you have either started from the
    bootstrap proceedure or used a previously created
    "Boot Image Transfer" disk.
 2. If you are starting from disk on the H89, first connect
    the RS232 cable and start the H89TRANS.COM program
    on the PC.
 3. Boot the "Boot Image Transfer" disk on the H89 by
    powering up the H89, inserting the disk and entering
    B to boot. Don't expect anything to display on the
    H89 from this program. It doesn't use the keyboard
    or display of the H89.
    On the H8 w/ XCON8 enter "1" to boot. With the PAM8 set
    the PC to 030.000 and GO.
 4. You can test to see if the disk boot was successful
    by using the L command. If the disk was good, you
    should get the already loaded message.
 5. Operate the desired operation(s) from the command table.

Things to Do and Understand:
 1. Make sure that if you are using the volume override that
    you use this only for non-HDOS disk. For HDOS disk,
    use the "From Image" for the volume number( V command ).
 2. Make sure to put a write protect tag on disk you intend
    to extract images from. You don't want to accidentally
    destroy a disk.
 3. If the drive does re-seeks while reading or writing,
    there is a problem with the disk format. It doesn't
    always mean the disk is bad. I have some that are intended
    for a 96 tpi ( 80 track ) disk. If there is a bad read,
    the program will continue after the re-seeks. It will
    report track read errors. The good is that it can make
    a copy of a bad disk that only that one file or unused
    sector(s) is corrupted. This can help to restore a bad
    disk. Make note of the bad location. It will surely have
    a bad sector or more. Watch and note any bad track errors.
    You'll want to check these track to see if that particular
    data is being used.
 4. Most of these old H89's used a belt drive. Make sure that
    it is tight or you will have a lot of errors. These tend
    to be stretch after a number of years. Also make sure that
    the flywheel and motor pully are clean and have no
    lumps on their surfaces. These will also cause errors.
    They can be cleaned by scraping with a pocket knife,
    while the disk rotates. Very small lumps can cause problems
    here. Old belt material tends to stick to the surface.
 5. If you cause one of the errors that drops you back to the
    PC's DOS prompt. You should be able to restart the H89TRANS.COM
    program without reloading the program on the H89. This
    assumes that there was no transfer error and the the H89
    is still running OK.
 6. Before doing a write or read, make sure to select a
    file with the "O" command.
 7. If a command hanges on the PC side, you can either reboot
    or use the <ESC> key to break to DOS.
 8. You can drop back to DOS with the X command to do DIR
    or other DOS functions, as long as you don't run anything
    that talks to the serial port. You can then re-enter H89TRANS
    to do other operations without needing to reload the
    main loader program or boot strap.
 9. If transfering a non-HDOS disk, the volume number may not
    be used the same as the HDOS disk do. In the HDOS, the
    volume number is kept track of in the image. For non-HDOS
    disk, you'll have to keep track of the value separately.
    This version will abort if it sees a mismatch between the
    actual volume number seen in the headers as compared with
    the value selected ( form image or override ). It prints
    the header value before aborting so that you can restart
    the program and use the new value with the override. This
    feature only works with the reading of disk images. This
    is also an easy way to discover a non-HDOS disk's volume
    number. Writes depend on one either using the 'from image',
    for HDOS disk only, or the override. If the non-HDOS disk needs
    a particular volume number, make note of it before archiving
    that disk image ( This program can no guess what it might be ).

Typical Command Table:

V set volume# now:   From Image
O open/create image file now:     None
W write image to H89
R read image from H89
L Send H89LDR2.BIN to H89
S Save loader on H89
I Set interleave = 1:1
B Set Baud rate for use with H8-5
X exit to DOS
Command?

Command descriptions:

V  Set Volume number mode
   All of my Forth disk must have the override of volume = 0.
   This may be needed for CP/M hard sectored disk as well.
   It first prompts for a Y/N to change the current mode.
   Leave it in "From Image" for HDOS images. It knows how to
   read HDOS disk volume numbers from the images for both
   read and write operations. Keep track of the volume numbers
   for non-HDOS disk.
O  Selects the image file to read or write to. Use caution.
   A read operation will overwrite any file with that name
   on the disk. Make sure to have backups of images you've
   saved. This resets to 'none' after an operation so one
   doesn't accidentally over write the same file.
W  Writes from the file selected by the O command to the
   H89/8 disk. Format is done a track at a time while writing.
   You can use a new disk or old one. Just don't have a write
   protect tag.
R  Reads the disk in the H89 to the file selected by the
   O command. HDOS disk should be set to the volume number
   "From Image" mode while Forth disk should have the override
   to vol# = 0. Other non-HDOS disk may require other volume
   numbers.
L  Loads the main loader to the H89/8 when the bootstrap program
   is loaded by hand. If the main loader is already there
   it says so. This is handy to check before other operations
   that might hang. If you booted the H89/8 from the
   "Boots Image Transfer" disk. This will check that it was
   done correctly. If it returns with " Already Loaded" you are
   OK. It prompts for the machine configuration to load the correct
   code for your machine.
S  Save the main loader to a disk on the H89/8. This disk
   will boot to the loader without the need to enter the
   boot strap code. I highly recommend you do this first onto
   a blank disk to help later on. You might want to mark it
   with H8-5, H8-4 or H89 because these may have different
   images, depending on system configuration.
I  Sets the interleave factor. For the most part, this should
   be left set to 1:1. If you have BASIC programs that need to
   load data or chain a lot of files, try other factors for
   speed of loading. When reading a disk onto the PC, interleave
   information is lost. If you have a disk that has interleave
   set to other than 1:1, a new copy made from that image file
   may seem slower. Try using a different interleave factor.
B  This command is only for the H8-5 that has a hardwired Baud
   rate set. Many of these boards have speed issues at 9600
   Baud but will work fine at slower rates. This command will
   cause failures if used with the H8-4 or H89/90 setups.
   The H8-5 must be preselected to the desired Baud rate by jumper
   wire before using this command. This command only effects the
   Baud rate of the PC and not the H8 ( the reason it doesn't
   work with the H8-4 or the H89/90.
X  Returns to DOS. You can exit to DOS to check on file names
   and restart this program but the opened file and volume
   number mode are reset.

Debugging:
 If it doesn't seem to work, here are some things to check:
1. Make sure you use the correct channel and port address
   if using the H8-4 serial board.
2. Make sure the cabling is correct and that pins 2 and 3
   are driven one from each end of the cable. I recommend
   using a RS-232 light box.
3. Make sure you are not running windows on the PC. NO WINDOWS!
4. If using a H8, select the DE register pair before using
   the L command on the PC. This should start at 046.022
   or 046.021. Once the L command is entered, it should
   decrement to 043.050. If it doesn't move, you have
   a serial problem. If it only moves part way, you have
   flaky serial.
5. It has been found that many H8-5 serial boards will
   not run at 9600 baud. If you are running one of these
   boards and are experiencing problems, you can rejumper
   the H8-5 for a slower serial rate.
   You can then modify the Baud rate used from the menu
   by the B command.
6. One may be able to get the H8-5 board to run faster
   by swapping the optical isolators or replacing the
   receive side isolator.
7. Make sure you use the correct bootstrap file.
    BOOTSTRP.OCL  for H89 or H8 with H8-4
    BOTSTRP8.OCL  for H8 with H8-5

  If you'd like changes, contact me: Dwight Elvey
As far as I know, I'm the only 'Dwight Elvey' in the US so
a quick web search should find me. Email addresses can change.
 If you use this tool please let me know. I don't get payed,
I only get praise or scorn. Feedback will always be listened to.
Don't be shy, I won't send you junk mail but if I update,
I may send you a note about the latest H89TRANS. To not
acknowledge the use of this tool is like stealing.
Later
Dwight Elvey



 