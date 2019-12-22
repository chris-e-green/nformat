# nformat
Ancient replacement for DOS format command

This program was designed to make it harder for users to mess things up (eg by formatting their hard drive...)

A description from the code:

`nformat` replaces DOS format: expects DOS format to be called `LFORMAT.EXE` or `LFORMAT.COM`, and to be located either in 
`C:\DOS` or `C:\`.  It doesn't allow formats of drives other than A or B, and it provides a 'safe' format for floppy disks.
This is implemented by reading the boot sector of the floppy prior to formatting; if the read is unsuccessful, the program 
passes control to the DOS format command.

If the read is successful, the program checks the the contents of the root directory.  If there are entries in the root
directory, the program advises the user of this and proceeds only if the user indicates acceptance of the format.  Assuming a
format is desired, the program uses the data obtained from the boot sector regarding disk structure to read all of the disk 
surface.  If an error is encountered, that track/sector is formatted.  When the disk has been checked, the FATs and root 
directory are zeroed. 
