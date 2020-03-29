December 2013 Les Bird (lesbird@lesbird.com)

SDUP-SP - a modified SDUP by Les Bird

SDUP is a HDOS program by Patrick Swayne for duplicating HDOS hard sector disks of any size.

The original SDUP.ABS program is on the HDOS H17 Support Disk 1(885-1121A)
The original SDUP.ASM source is on the HDOS H17 Support Disk 2 (885-1121B)

Both of these disks are part of the HUG Library archive HUGLibrary.zip) at sebhc.lesbird.com

I modified the original source code to support sending and receiving disk images via a serial port (340Q). To do this I embedded parts of Dwight Elvey's H89LDR code into the original SDUP.ASM source and added an additional option to send/receive via the serial port instead of to/from another disk. I then modified the original SDUP code flow to skip sections that were not necessary when sending/receiving by serial connection.

You will need H8DUtility V1.50 or later to support SDUP-SP.

How to use it:

1. Send the disk image called "HDOS_2 SDUP Boot 1S40T.h8d" using the standard H89LDR procedure to a H89.
2. Boot to HDOS with the newly created disk.
3. Run the program SDUP.ABS
4. Select option 4 to go to H89LDR command mode.
5. Use H8DUtility V1.5 to send/receive images.

SDUP and the H8D Utility will automatically detect the disk size by reading the disk label. All supported HDOS HSY disk sizes are supported:

One side, 40 track (disk type 0) - 100KB
Two side, 40 track (disk type 1) - 200KB
One side, 80 track (disk type 2) - 200KB
Two side, 80 track (disk type 3) - 800KB

You can send/receive using any disk drive on the H89 (SY0, SY1, SY2) by selecting the drive from the drop down box in H8D Utility.

The SDUP boot disk is setup with the following configuration:
SY0 - 1 side, 40 track
SY1 - 1 side, 40 track
SY2 - 1 side, 40 track

Reconfigure to match your hardware configuration by doing the following:

for 80 track, 2 side drive:
>SET SY1: 80TRK
>SET SY1: SIDES 2

for 40 track, 1 side drive:
>SET SY1: 40TRK
>SET SY1: SIDES 1

The advantages of using SDUP-SP over H89LDR are:
1. Supports all disk sizes (100KB, 200KB, 400KB)
2. Supports any hard sector disk drive (SY0 thru SY2)
3. Visual feedback on the H89 screen

This package contains 4 disk images:

HDOS_2 SDUP Boot 1S40T.h8d - this is a bootable HDOS 2 disk with the HSY device driver and the modified SDUP.ABS utility.

HDOS_2 SY0 HDOS Boot 1S40T.h8d - this a bootable HDOS 2 disk to use in the H89 emulator for assembling the SDUP.ASM code. It is configured as follows: SY0 (1S,40T), SY1 (2S,80T), SY2 (1S 40T)

HDOS_2 SY1 SDUP Work 2S80T.h8d - this contains all the ACM files along with ASM.ABS for assembling the SDUP.ASM source file. It is formatted as 2 sides, 80 tracks so you will need to set up the emulator to match. Copy the SDUP.ASM source file to this disk then run SY1:ASM and then at the ASM prompt type "SY1:SDUP,=SY1:SDUP". This will create a SY1:SDUP.ABS file. Copy the ABS file to SY2 and send that image to a real H89 using H89LDR or the H8D Utility.

HDOS_2 SY2 SDUP Work 1S40T.h8d - this disk image contains the SDUP.ASM modified source file which should be copied to SY1 before running ASM.ABS.

My work flow was as follows:

- Edit SDUP.ASM source in Windows 7 using Notepad++.
- Add the SDUP.ASM to a disk image using H8D Utility (click the ADD button).
- Start the H89 emulator with SY0, SY1 and SY2 disk images (as noted above).
- Copy SDUP.ASM to SY1 like this: >PIP SY1:*.*=SY2:*.*
- Run ASM.ABS like this: >SY1:ASM
- Assemble the code like this: *SY1:SDUP,=SY1:SDUP
- Copy SY1:SDUP.ABS to SY2 >PIP SY2:SDUP.ABS=SY1:SDUP.ABS
- !! IMPORTANT !! Save the disk images from the emulator (the SY1 and SY2 buttons will be yellow, click them to save).
- Send the SY2 disk image to a real H89 using H8D Utility.
- Run and test SDUP.ABS on the H89.