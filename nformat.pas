program format;
{$M 16384,0,16384}
uses dos,crt;
{ replaces DOS format: expects DOS format to be called LFORMAT.EXE or }
{ LFORMAT.COM, and to be located either in C:\DOS or C:\.  It doesn't }
{ allow formats of drives other than A or B, and it provides a 'safe' }
{ format for floppy disks.  This is implemented by reading the boot   }
{ sector of the floppy prior to formatting; if the read is            }
{ unsuccessful, the program passes control to the DOS format command. }
{ If the read is successful, the program checks the the contents of   }
{ the root directory.  If there are entries in the root directory,    }
{ the program advises the user of this and proceeds only if the user  }
{ indicates acceptance of the format.  Assuming a format is desired,  }
{ the program uses the data obtained from the boot sector regarding   }
{ disk structure to read all of the disk surface.  If an error is     }
{ encountered, that track/sector is formatted.  When the disk has     }
{ been checked, the FATs and root directory are zeroed.               }

type
  buffarray = array [1..512*18] of byte;
  buffptr = ^buffarray;

var
  DOS_format : string;
  Parameters : string;
  count      : word;
  num_of_par : word;
  parstr     : string;
  BootOk     : boolean;
  drive      : byte;
  bps,
  spt,
  spf,
  heads,
  tracks     : word;
  sys        : boolean;
  Buffer     : buffptr;
  temp       : char;

procedure find_DOS_format (var path:string);
begin
  path := Fexpand(Fsearch ('LFORMAT.COM','C:\;C:\DOS'));
end;

procedure upper (var low : string);
var
  i : integer;
begin
  for i := 1 to length (low) do low[i] := upcase (low[i]);
end;

procedure abort (error_number:integer;error_message:string);
begin
  Writeln;
  Writeln ('ERROR : ',error_message);
  Writeln;
  Halt (error_number);
end;

procedure ResetDisk (drive:byte);
var
  Regs : Registers;
begin
  Regs.AH := $00;
  Regs.DL := drive;
  intr($13,Regs);
end;


function CheckBootSector(drive:byte;var BytesPerSector, SectorsPerFAT,
                                        SectorsPerTrack, Heads,
                                        Tracks : word) : boolean;
var
  Regs : Registers;
  Count : integer;
  Ok : boolean;
  MediaDescriptor:byte;

begin
  Ok := false;
  Count := 0;
  while not ok and (Count < 3) do begin
    Regs.AH := $02; { Read Disk Sectors }
    Regs.AL := $01; { Number of sectors to transfer }
    Regs.ES := seg(Buffer^);   { ES:BX is pointer to disk buffer }
    Regs.BX := ofs(Buffer^);
    Regs.CH := $00; { Track number }
    Regs.CL := $01; { Sector number }
    Regs.DH := $00; { Head number }
    Regs.DL := drive; { Drive number }
    intr($13,Regs);
    if not ((Regs.Flags and FCarry)=FCarry) then
      Ok := true
    else
      ResetDisk(drive);
    count := count + 1;
  end;
  BytesPerSector := buffer^[12]+(buffer^[13]*256);
  SectorsPerTrack := buffer^[12+$0d]+(buffer^[13+$0d]*256);
  SectorsPerFAT := buffer^[12+$0b]+(buffer^[13+$0b]*256);
  Heads := buffer^[12+$0f]+(buffer^[13+$0f]*256);
  MediaDescriptor := buffer^[12+$0a];
  if (MediaDescriptor = $F9) or (SectorsPerTrack = 18) then
    Tracks := 80
  else
    Tracks := 40;
  CheckBootSector := Ok;
end;

procedure format_track(drive:byte;head,track:word);
var
  Regs : Registers;
  Count : integer;
  Ok : boolean;

begin
  For count := 0 to (spt-1) do begin
    buffer^[count*4+1]:=track;
    buffer^[count*4+2]:=head;
    buffer^[count*4+3]:=count;
    buffer^[count*4+4]:=2;
  end;
  ok := false;
  count := 0;
  while not ok and (Count < 3) do begin
    Regs.AH := $05;            { Format Disk Track }
    Regs.ES := seg (Buffer^);  { ES:BX is pointer to track address list }
    Regs.BX := ofs (Buffer^);
    Regs.CH := track;
    Regs.DH := head;
    Regs.DL := drive;
    Intr ($13,Regs);
    if not ((Regs.Flags and FCarry)=FCarry) then
      Ok := true
    else
      resetDisk(drive);
    count := count + 1;
  end;
end;

procedure format_disk(drive:byte;bps,spf,spt,heads,tracks:word);
var
  Regs : Registers;
  Count : integer;
  Ok : boolean;
  head,
  track,
  sector : word;
  sp : word;
begin
  sp := 0;
  Regs.ES := seg(Buffer^);   { ES:BX is pointer to disk buffer }
  Regs.BX := ofs(Buffer^);
  Regs.DL := drive; { Drive number }
  for track := 1 to (tracks-1) do begin
    Regs.CH := track; { Track number }
    for head := 0 to (heads-1) do begin
      Regs.DH := head; { Head number }
      Ok := false;
      Count := 0;
      while not ok and (Count < 3) do begin
        Regs.AH := $04; { Verify Disk Sectors }
        Regs.AL := spt; { Number of sectors to transfer }
        Regs.CL := $01; { Sector number }
        intr($13,Regs);
        if not ((Regs.Flags and FCarry)=FCarry) then
          Ok := true
        else
          resetDisk(drive);
        count := count + 1;
      end;
      if not ok then
        format_track(drive,head,track);
{          writeln ('Confirming drive ',drive,
                   ', head ',head,
                   ', track ',track,
                   ', sector ',sector);
}
      inc(sp);
      write(sp/(heads*tracks)*100:5:0,'% t=',track:3,' h=',head:3);
      if not ok then writeln (' !') else writeln ('  ');
      gotoxy(1,wherey-1);
    end;
  end;
end;

begin
  find_DOS_format (DOS_format);
  sys := false;
  Parameters := '';
  if ParamCount = 0 then abort (1,'No drive specified');
  for count := 1 to ParamCount do begin
    parstr := ParamStr(count);
    upper(parstr);
    if (parstr[2] = ':') then
      if (parstr[1] <> 'A') and (parstr[1] <> 'B') then
        abort (1,'Cannot format non-removable drive')
      else
        drive := ord(parstr[1])-ord('A');
    if (parstr[1]='/') and (parstr[2]='S') then sys := true;
    Parameters := Parameters + parstr+ ' ';
  end;
  If (length (Parameters) > 0) then
    Parameters := Copy(Parameters,1,Length(Parameters)-1);
  ResetDisk(drive);
  new (Buffer);
  Writeln ('About to FORMAT the disk in Drive ',chr(drive+ord('A')));
  Write ('Press return to continue or Ctrl-C to abort');
  Read(temp);
  BootOk := CheckBootSector(drive,bps,spf,spt,heads,tracks);
  If not BootOk then exec (DOS_format,Parameters)
  else format_disk(drive,bps,spf,spt,heads,tracks);
  writeln ('Format complete   ');
  dispose (Buffer);
  if sys = true then begin
{    exec (DOS_sys,chr(drive+ord('A'))+':');
    exec (DOS_copy,getenv(comspec)+' '+chr(drive+ord('A'))+':');}
  end;
end.
