{$B-,I-,R-,S-,V-,X+}
unit ARCv;

interface

uses Objects;

type
  TArchiveLineProc = procedure(
    const FName: String; FTime, OrigSize, PackSize: Longint );

const
  arcOk = 0;
  arcNotFound = 1;
  arcNotIdentified = 2;
  arcBroken = 3;
  arcView = 4;

  avNo  = 0;
  avZip = 1;
  avArc = 2;
  avLzh = 3;
  avArj = 4;
  avPak = 5;
  avChz = 6;
  avZoo = 7;
  avLim = 8;
  avHa  = 9;
  avRar = 10;
  avZiW = 11;
  avArW = 12;
  avRaW = 13;
  avLast = avRaW;
  avUsr = 20;

  afArc = $0001;
  afArj = $0002;
  afChz = $0004;
  afHa  = $0008;
  afLha = $0010;
  afLim = $0020;
  afPak = $0040;
  afRar = $0080;
  afZip = $0100;
  afZoo = $0200;
  afZiW = $0400;
  afArW = $0800;
  afRaW = $1000;
  ArcFlags: Longint = 0;

var
  AddFileCallback: TArchiveLineProc;
  ArchiveInfoPtr : Pointer;

  ArcEnd: Boolean;

procedure ReadArchive(const inName: String);

implementation

uses MyLib, SysUtils;

{==============================================================}
var
  CurView : byte;
  StartArchive : longint;
  PFlag : char;
  FullName, ARCError, ARJ_SEC : boolean;
  CommAvail : boolean;
  NewRAR : boolean;
  F : File;

type
  ap = array[0..100] of smallword;

function BSearch (dat : pointer; datum : smallword; Num : smallword) : smallword;
var
  i, off : smallword;
  a : ^ap;
begin
  i := 0;
  off := 0;
  a := dat;
  while (num > 0) do
   begin
    i := num SHR 1;
    if (datum = smallword(a^[i + off])) then
     begin
      BSearch := i + off;
      exit;
     end;
    if (datum < smallword(a^[i + off])) then num := i
    else
     begin
      off := off + i + 1;
      num := num - (i + 1);
     end
   end;
  BSearch := off;
end;

procedure AddFile(FName: String; FTime, OrigSize, PackSize: Longint);
var
  I: Byte;
  L: Byte absolute FName;
begin
  for I := 1 to L do
   if FName[I] = '/' then FName[I] := '\';
  if FName[2] = '\' then Delete(FName, 2, 1);
  AddFileCallBack(FName, FTime, OrigSize, PackSize);
end;

function CompStruct(const r1; const r2; num : word) : boolean; assembler;
        {&USES esi,edi} {&FRAME-}
asm
        cld
        mov esi,r2
        mov edi,r1
        mov ecx,num
        repe cmpsb
        je @@Ok
        xor eax,eax
        jmp @@Exit
@@Ok:   mov eax,1
@@Exit:
end;

procedure AutoDetect;
type
  Header = record
    HeadId : smallword;   { 60000 }
    SIG1 : smallword;   { Basic Header Size }
  end;

  EXEHead = record
    ID : array [1..2] of char;
    PartPag, PageCnt, ReloCnt, HdrSize,
    MinMem, MaxMem, ReloSS, ExeSP, ChkSum, IP, CS,
    TablOff, Overlay : smallword;
    T : array[1..4] of char;
  end;

var
  ImageInfo : record
    ExeId : array[0..1] of char;
    Remainder,
    size : smallword
  end;
  b, b1 : array[1..30] of byte;
  Result : word;
  Err : boolean;
  ArcSize, AOffset : longint;
  Incr : byte;
  H : EXEHead absolute b;
  e : integer;
  i : byte;

const
  lha213 : array[1..13] of smallword = ($64, 4, 0, 2, $1000, $FFFF, $FFF0,
       $0100, 0, $0100, $FFF0, $1C, 0); { 1636 }
  lharc100 : array[1..13] of smallword = ($B7, $0282, 0, 2, $0256, $FFFF,$FFF0,
       $0100, 0, $0100, $FFF0, $1E, 0);
  lharc113l : array[1..13] of smallword = ($014D, 4, 0, 2, $066C, $FFFF, $FFF0,
       $0100, 0, $0100, $FFF0, $1E, 0); { 1870 }
{
   SFX_NDT.EXE ... EXE - lharc 1.13l, start - 1877
$014D,$0004,$0000,$0002,$066C,$FFFF,$FFF0,$0100,$0000,$0100,$FFF0,$001E,$0000
}
  lhice114s : array[1..13] of smallword = ($8A, $0182, 0, 2, $0256, $FFFF, $FFF0,
       $0100, 0, $0100, $FFF0, $1E, 0); { 1295 }
  lha254l : array[1..13] of smallword = ($01DA, 4, 0, 2, $1800, $1800, $FFF0,
       $0100, 0, $0100, $FFF0, $1C, 0);
  PKSFX1_01 : array[1..13] of smallword = ($98, $1F, $0B, $20, $0AC1, $FFFF,
       $0E0A, $0600, $699D, $2474, 0, $1E, 0); { 15512 }
  zip2exe1_1 : array[1..13] of smallword = ($01EF, $19, 0, 6, $0CD1, $FFFF,
       $0320, $0400, 0, $0100, $FFF0, $1E, 0); { 12784 }
  zip2exe204m : array[1..13] of smallword = ($01BA, 6, 0, 2, $0B89, $1000,
       $FFF0, $C01C, 0, $0100, $FFF0, $1E, 0);  { 3002 }
  zip2exe204 : array[1..13] of smallword = ($CB, $1F, 1, 6, $0C68, $FFFF,
       0, $5FB0, 0, $0100, $FFF0, $52, 0); { 15563 }
  zip2exe204g : array[1..13] of smallword = ($0126, $1E, 1, 6, $0C88, $FFFF,
       0, $5E40, 0, $0100, $FFF0, $52, 0); { 15142}
  zip204e : array[1..13] of smallword = ($0199, $1F, 1, 6, $0C89, $FFFF,
       0, $6120, 0, $0100, $FFF0, $52, 0);
  zip204e1 : array[1..13] of smallword = ($01F4, $1E, 1, 6,$0C89, $FFFF,
       0, $5FB0, 0, $0100, $FFF0, $52, 0); { 15348 }
  zip102_OS2 : array[1..13] of smallword = (9, $18, $4F, $23, $0E5F, $FFFF,
       $01D3, $80, $CD68, $77, $01DB, $40, 0);
  zip204g : array[1..13] of smallword = ($019A, $1F, 1, 6, $0C89, $FFFF,
       0, $6120, $8528, $0100, $FFF0, $52, $8000); { 15770 }
  zip204g1 : array[1..13] of smallword = ($019A,$1F, 1, 6, $0C89, $FFFF,
       0, $6120, 0, $0100, $FFF0, $52, 0); { 15770 }
  zip204g2 : array[1..13] of smallword = ($01F5,$1E, 1, 6, $0C89, $FFFF,
       0, $5FB0, 0, $0100, $FFF0, $52, 0); { 15349 }
  PKSFX1_1 : array[1..13] of smallword = ($0176, 6, 0, 2, $0602, $FFFF,
       $FFF0, $6770, 0, $0100, $FFF0, $1E, 0); { 2934 }
  PKSFX35 : array[1..13] of smallword = ($1E, $14, 5, $20, $0F50, $FFFF,
       $1189, $80, $7431, 0, 0, $1E, 0);
  PK361E : array[1..13] of smallword = ($0152, $1A, $D, $20, $0E6B, $FFFF,
       $1140, $0400, $FEEF, $1D02, 0, $1E, 0); {pksfx 3.61 - 3352h}
  charc13a : array[1..13] of smallword = ($E8, 4, 0, 2, $1770, $1770, $17D5, $0100,
       0, 0, 0, $1C, 0); { 1816 }
  charc11s : array[1..13] of smallword = ($C6, 4, 0, 2, $1770, $1770, $17D7, $0100,
       0, 0, 0, $1C, 0); { 1850 }
  ARJSFX : array[1..4] of char = ('R','J','S','X');
  ARJ110 : array[1..13] of smallword = ($014A, $1D, 0, 2, $0D8F, $FFFF, $053C,
       $80, 0, $0E, $037C, $1C, 0); { 14666 }
  ARJ200 : array[1..13] of smallword = ($EC, $1C, 1, 2, $0E79, $FFFF, $11C0,
       $80, $7E56, 3, 0, $1C, $20);
  ARJSFXJR200 : array[1..13] of smallword = ($10, $D, 1, 2, $0E3A, $FFFF, $0F95,
       $80, $4E91, 3, 0, $1C,$20);
  PAK250 : array[1..13] of smallword = ($D3, $E, 6, $20, $79, $FFFF, $018E, $0780,
       0, $09E1, 0, $3E, 0);
  PAKOLD : array [1..13] of smallword = ($58, $E, $9, $20, $51, $FFFF,
       $0186, $0500, 0, $0860, 0, $22, 0); { 6744 }
  lim10 : array[1..13] of smallword = ($01C0, $1A, 1, 2, $01DE, $FFFF,
       $0510, $80, $899D, 0, 0, $1C, $20);
  RAR_139 : array[1..13] of smallword = ($017B, $B, 0, 2, $26DB, $FFFF,
       $0612, $80, 0, $E, $0140, $1C, 0);
  RAR_141 : array[1..13] of smallword = ($015B, $D, 0, 2, $26E3, $FFFF,
       $0658, $80, 0, $E, $017E, $1C, 0);
  RAR_Block : array[1..7] of byte = ($52,$61,$72,$21,$1a,7,0);

begin
  CurView := avNo;
  NewRAR := FALSE;
  ARCError := FALSE;
  seek(f, StartArchive);
  BlockRead(f, b, SizeOf(B), Result);
  if (b[1] = $50) and (b[2] = $4B)
    and (b[3] = 3) and (b[4] = 4) then CurView := avZip
  else if (b[3] = $2D) and (b[4] = $6C) and
          (b[5] = $68) and (b[7] = $2D) then CurView := avLzh
  else if (b[1] = $1A) and (b[2] <= 11) then CurView := avArc
  else if (b[1] = $60) and (b[2] = $EA) then CurView := avArj
  else if (b[1]=$53) and (b[2]=$43) and (b[3]=$68) then CurView := avChz
  else if (b[1]=$5A) and (b[2]=$4F) and (b[3]=$4F) then CurView := avZoo
  else if (b[1]=$4C) and (b[2]=$4D) and (b[3]=$1A) then CurView := avLim
  else if (b[1]=Byte('H')) and (b[2]=Byte('A')) then CurView := avHa
  else if (b[1]=$52) and (b[2]=$45) and (b[3]=$7E) and
          (b[4]=$5E) then CurView := avRar
  else if CompStruct(b, RAR_Block, 7) then
        begin
         NewRAR := TRUE;
         CurView := avRar;
        end
  else if H.ID = 'MZ' then
        begin
         ArcSize := Filesize(f);
         AOffset := LongInt(H.PageCnt - 1) * 512 + H.PartPag;
         Seek(f, AOffset);
         if IoResult > 0 then Exit;
         BlockRead(f, b1, SizeOf(B1), Result);
         Err := (IoResult <> 0) or (Result < SizeOf(b1));
         if not Err then
         begin
          Incr := 0;
          if (b1[1] = $50) and (b1[2] = $4B) and
             (b1[3] = 3) and (b1[4] = 4) then CurView := avZip
          else if (b1[3] = $2D) and (b1[4] = $6C) and
                  (b1[5] = $68) and (b1[7] = $2D) then CurView := avLzh
          else if (b1[1] = $1A) and (b1[2] <= 11) then CurView := avArc
          else if (b1[1] = $60) and (b1[2] = $EA) then CurView := avArj
          else if (b1[3] = $60) and (b1[4] = $EA) then
                begin
                 Incr := 2;
                 CurView := avArj
                end
          else if (b1[1]=$53) and (b1[2]=$43) and
                  (b1[3]=$68) then CurView := avChz
          else if (b1[1]=$5A) and (b1[2]=$4F) and
                  (b1[3]=$4F) then CurView := avZoo
          else if (b1[1]=$4C) and (b1[2]=$4D) and
                  (b1[3]=$1A) then CurView := avLim
          else if (b1[1]=Byte('H')) and (b1[2]=Byte('A')) then CurView := avHa
          else if (b1[1]=$52) and (b1[2]=$45) and
                  (b1[3]=$7E) and (b1[4]=$5E) then CurView := avRar
          else if CompStruct(b1, RAR_Block, 7) then
                begin
                 NewRAR := TRUE;
                 CurView := avRar;
                end;
         end;
    if CurView <> avNo then StartArchive := AOffset + Incr { add 2 bytes for ARJ241}
    else
     begin
      if CompStruct(lha213[2], H.PageCnt, 24) then
       begin
        if H.PartPag = $63 then StartArchive := 1635 { lh 2.05 S }
        else if H.PartPag = $0198 then StartArchive := 1944 { lh 2.05 L }
        else if H.PartPag = $64 then StartArchive := 1636
        else if H.PartPag = $65 then StartArchive := 1637 { lha 2.10 S }
        else if H.PartPag = $0199 then StartArchive := 1945
        else if H.PartPag = $019A then StartArchive := 1946 { lha 210l }
        else StartArchive := -1;
       end
      else if CompStruct(lharc113l, H.PartPag, 26)  then StartArchive := 1870  { lharc 1.13l }
      else if CompStruct(lhice114s, H.PartPag, 26)  then StartArchive := 1295
      else if CompStruct(H.T, ARJSFX, 4)  then
        case H.PartPag of
          $A   : StartArchive := 14858;
          $1BA : StartArchive := 14778; { ARJ 2.20 }
          $0111: StartArchive := 5393; { ARJ jr 2.21a }
          { $0111, $B, 0, 2, $0E32, $FFFF, $01CF, $80, 0, $E, $0139, $1C, 0 }
          $C1  : StartArchive := 5313;  { ARJ 2.30 beta2 jr }
          $D1  : StartArchive := 5329;
          $101 : StartArchive := 5377;  { ARJSXJR 2.20 }
          { $100 : StartArchive := 15104;} { ARJ 2.39b    }
          $161 : StartArchive := 5473;  { ARJ 2.39b jr }
          $F0  : StartArchive := 15090; { ARJ 2.39d    }
          $91  : StartArchive := 5779;  { ARJ 2.41jr   }
          $100 : StartArchive := 15106; { ARJ 2.41     }
          { $100, $1E, 0, 2, $F6F, $FFFF, $551, $80, 0, $E, $397, $1C, 0 }
          $80  : StartArchive := 17026; { ARJ 2.41 еще один }
          { $80, $22, 0, 2, $0FBF, $FFFF, $0619, $80, 0, $E, $040F, $1C, 0 }
          $1EA : StartArchive := 16876; { ARJ 2.41b }
          { $01EA, $21, 0, 2,$0FBA,$FFFF, $060C, $80, 0, $E, $0406, $1C, 0 }
          $3D  : StartArchive := 16959; { ARJ 2.41a }
          { $3D, $22, 0, 2, $0FBF, $FFFF, $0615, $80, 0, $E, $040B, $1C, 0 }
          else StartArchive := 14810;
        end
      else if CompStruct(ARJ110, H.PartPag, 26)  then StartArchive := 14666
      else if CompStruct(ARJ200, H.PartPag, 26)  then StartArchive := 14060
      else if CompStruct(ARJSFXJR200, H.PartPag, 26) then StartArchive := 6160
      else if CompStruct(PKSFX1_01, H.PartPag, 26) then StartArchive := 15512
      else if CompStruct(zip2exe1_1, H.PartPag, 26) then StartArchive := 12784
      else if CompStruct(zip2exe204, H.PartPag, 26) then StartArchive := 15563
      else if CompStruct(zip2exe204m, H.PartPag, 26) then StartArchive := 3002
      else if CompStruct(zip2exe204g, H.PartPag, 26) then StartArchive := 15142
      else if CompStruct(zip204e, H.PartPag, 26) then StartArchive := 15769
      else if CompStruct(zip204e1, H.PartPag, 26) then StartArchive := 15348
      else if CompStruct(zip204g, H.PartPag, 26) then StartArchive := 15770
      else if CompStruct(zip204g1, H.PartPag, 26) then StartArchive := 15770
      else if CompStruct(zip204g2, H.PartPag, 26) then StartArchive := 15349
      else if CompStruct(zip102_OS2, H.PartPag, 26) then StartArchive := 28374
      else if CompStruct(PKSFX1_1, H.PartPag, 26) then StartArchive := 2934
      else if CompStruct(charc13a, H.PartPag, 26) then StartArchive := 1816
      else if CompStruct(charc11s, H.PartPag, 26) then StartArchive := 1850
      else if CompStruct(PAK250, H.PartPag, 26) then StartArchive := 6867
      else if CompStruct(PAKOLD, H.PartPag, 26) then StartArchive := 6744
      else if CompStruct(PKSFX35, H.PartPag, 26) then StartArchive := 9758
      else if CompStruct(PK361E, H.PartPag, 26) then StartArchive := 13138
      else if CompStruct(Lim10, H.PartPag, 26) then StartArchive := 13250                             { limit 1.0 }
      else if CompStruct(RAR_139, H.PartPag, 26) then StartArchive := 5499
      else if CompStruct(RAR_141, H.PartPag, 26) then StartArchive := 6491
      else if CompStruct(lha254l, H.PartPag, 26) then StartArchive := 2010  { lha 2.54l }
      else if CompStruct(lharc100, H.PartPag, 26) then StartArchive := 1322  { lharc 1.00 }
      else StartArchive := -1;
      if StartArchive <> -1 then AutoDetect;
    end;
  end;
end;

function SearchBack(const buf; Pbuf: word; const Msk; PMsk: word) : word; assembler;
          {&USES esi,edi} {&FRAME-}
asm
           std
           mov eax, 1
           mov edx, PBuf
           mov esi, buf
@@1:       mov edi, Msk
           mov ecx, PMsk
           repe cmpsb
           je @@Exit
           add eax, PMsk
           sub eax, ecx
           dec PBuf
           sub edx, PMsk
           add edx, ecx
           cmp edx, 0
           jne @@1
           mov eax, edx
@@Exit:    cld
end;

procedure ViewZip;
type
 CentralFileRec = record
   Signature : longint;
   VersionMade : smallword;
   Version2Extr : smallword;
   Flag : smallword;
   CompressionMethod : smallword;
   FileTime : longint;
   CRC32 : longint;
   PackSize : longint;
   OrigSize : longint;
   FileNameLength : smallword;
   ExtraLength : smallword;
   FileCommLength : smallword;
   DiskNumStart : smallword;
   InternalFAttr : smallword;
   ExternalFAttr : longint;
   OffsetLocHeader : longint;
 end;

 CentralDirRec = record
   Signature : longint;
   DiskNum : smallword;
   StartDiskNum : smallword;
   StartDisk : smallword;
   Total : smallword;
   SizeDir : longint;
   OffsStart : longint;
   CommLeng : smallword;
 end;
 Tbuf = array[1..1024*40] of byte;

const
  msk : array[1..4] of byte = ($50, $4B, 5, 6);
  blen = 1024*2{90};

var
  H : CentralFileRec;
  HC : CentralDirRec;
  fs, fb : longint;
  buf : ^Tbuf;
  Found, Ok : boolean;
  Result, Rsearch, i : word;
  ip : byte;
  FileName : String;
  s : string;

begin
  ARCEnd := FALSE;
  Found := FALSE;
  fs := FileSize(f);
  fb := Blen;
  GetMem(buf, Blen);
  repeat
    if (fb > fs) or (fb > 7000) then
    begin
      fb := fs;
      ARCEnd := TRUE;
    end;
    seek(f, fs-fb);
    BlockRead(f, buf^[1], BLen, Result);
    if Result = 0 then ARCEnd := TRUE
    else
    begin
      RSearch := SearchBack(buf^[Result], Result, Msk[4], 4);
      if RSearch <> $FFFF then RSearch := Result-RSearch-3;
      Found := (RSearch <> $FFFF);
      if not Found then Inc(fb, Blen);
    end;
  until ARCEnd or Found;
  FreeMem(buf, Blen);
  if not Found then begin
    ARCError := TRUE;
    exit;
  end;

  Seek(f, fs-fb+RSearch);
  Ok := IOResult = 0;
  BlockRead(f, HC, SizeOf(CentralDirRec), Result);
  if (HC.Signature = $6054b50) and (HC.CommLeng > 0) and {!!!!!}
     (HC.CommLeng < MaxAvail) then
   begin
    GetMem(buf, HC.CommLeng);
    BlockRead(f, Buf^[1], HC.CommLeng, Result);
    CommAvail := TRUE;
    ip := 1;
    for i := 1 to HC.CommLeng do
     begin
      if (Buf^[i] = $D) or (ip > 80) then
       begin
        s[0] := Char(ip-1);
//        AddComment(s);
        if i < HC.CommLeng then Inc(i);
//        s := '';
        ip := 1;
       end
      else
       begin
        s[ip] := Char(Buf^[i]);
        inc(ip);
       end;
     end;
    s[0] := Char(ip-1);
//    AddComment(s);
    FreeMem(buf, HC.CommLeng);
   end;

  Seek(f, HC.OffsStart);
  ARCEnd := FALSE;
  repeat
    PFlag := ' ';
    FillChar(H.Signature, SizeOf(CentralFileRec), #0);
    BlockRead(f, H, SizeOf(CentralFileRec), Result);
    if Result = 0 then ARCError := TRUE;
    if H.Signature = $02014B50 then
     begin
      FileName := '';
      if H.FileNameLength >= SizeOf(FileName) then  {!!!!!!!!!}
      begin
       ARCError := True;
       Break;
      end;
      BlockRead(f, FileName[1], H.FileNameLength, Result);
      FileName[0] := chr(H.FileNameLength);
      if (H.Flag and 1) <> 0 then PFlag := '*';
      AddFile(PFlag+FileName, H.FileTime, H.OrigSize, H.PackSize);
      Seek(f,FilePos(f) + H.ExtraLength + H.FileCommLength);
     end
    else ARCEnd := TRUE;

  until ARCEnd or ARCError;
end; { ViewZip }

procedure ViewICE;
type
 LzHead = record
   HeadSiz : byte;
   HeadChk : byte;
   HeadID : array [1..5] of char;
   PackSize, OrigSize : longint;
   FTime : longint;
   Attr : smallword;
   FileName : string[80];
 end;

var
  H : LzHead;
  cb, sl, i : byte;
  len : smallword;
  Result: word;
  PathS : array [1..80] of char;
  s : string[80];

begin
  ARCEnd := FALSE;
  BlockRead(f, H.HeadSiz, 1, Result);
  if H.HeadSiz >= SizeOf(LzHead) then      {!!!!!!!!!!}
   begin
    ARCError := True;
    Exit;
   end;
  BlockRead(f, H.HeadChk, H.HeadSiz + 1, Result);
  while (H.HeadSiz <> 0) and (Result <> 0) and
        (not ARCError) and (not ARCEnd) do
   begin
    len := 0;
    if ((H.HeadID[1] <> '-') and (H.HeadID[2] <> 'l') and
       (H.HeadID[5] <> '-')) then ARCError := TRUE;
    if ARCError then break;
    s := '';
    Move(H.FileName[length(H.FileName)+4], Len, 2);
    if Len <> 0 then
     begin
      BlockRead(f, cb, 1, Result);
      if (cb = 2) and (Len < 70) then
       begin
        BlockRead(f, PathS, Len-3, Result);
        for i := 1 to Result do
         begin
          if PathS[i] = #$FF then PathS[i] := '\';
          {s := s + PathS[i];}
          Inc(s[0]);
          s[Length(s)] := PathS[i];
         end;
        H.FileName := s + H.FileName;
        Dec(len, 2);
       end
      else Len := 1;
     end;
    PFlag := ' ';
    AddFile(PFlag+H.FileName, H.FTime, H.OrigSize, H.PackSize);
    Seek(f, FilePos(f) + H.PackSize - len);
    FillChar(H.HeadSiz, SizeOf(LzHead), #0);
    BlockRead(f, H.HeadSiz, 1, Result);
    if (Result = 1) and (H.HeadSiz = 0) then ARCEnd := TRUE
    else if (Result = 0) or (H.HeadSiz >= SizeOf(LzHead)) then
      ARCError := TRUE;
    if not ARCError then BlockRead(f, H.HeadChk, H.HeadSiz + 1, Result);
   end;
end; { ViewICE }

procedure ViewArc; { ARC/PAK }
type
  ARCHeader = record
    Signature : byte;
    Ver : byte;
    FileName : array [1..12]  of char;
    Flag : byte;
    PackSize : longint;
    FTime : longint;
    CRC : smallword;
    OrigSize : longint;
  end;

var
  H : ARCHeader;
  Time : longint;
  FileTime : array [1..2] of smallword absolute Time;
  tmp : smallword;
  i : byte;
  Ok : boolean;
  Result: word;
  FileName : String;
begin
  ARCEnd := FALSE;
  repeat
    FillChar(H.Signature, SizeOf(ARCHeader), #0);
    BlockRead(f, H.Signature, SizeOf(ARCHeader), Result);
    if (Result = 0) or (H.Signature <> $1A) then ARCError := TRUE;
    if (H.Ver <> 0) and (not ARCError) then
     begin
      if (H.Ver in [$A, $B]) then CurView := avPak;
      PFlag := ' ';
      FileName := '';
      i := 1;
      while H.FileName[i] <> #0 do
       begin
        FileName := FileName + H.FileName[i];
        Inc(i);
       end;
      Time := H.FTime;
      tmp := FileTime[1];
      FileTime[1] := FileTime[2];
      FileTime[2] := tmp;
      AddFile(PFlag+FileName, Time, H.OrigSize, H.PackSize);
      Seek(f,FilePos(f) + H.PackSize);
      Ok := IOResult = 0;
     end;
  until (H.Ver = 0) or ARCError or ARCEnd;
end; { ViewArc }

procedure ViewArj;
type
 ARJHead = record
   HeadID : smallword;
   BHeadSize : smallword;
   HeadSize : byte;
   Version : byte;
   MinVersion : byte;
   HostOS : byte;
   ARJFlag : byte;
   Method : byte;
   FileType : byte;
   Reserved : byte;
   FTime : longint;
   PackSize, OrigSize : longint;
   EntryName : smallword;
   FileAccessMode : smallword;
   HostData : smallword;
   Buffer : array[0..2600] of byte;
 end;

var
  H : ^ARJHead;
  ch : char;
  i : smallword;
  HeaderCRC : longint;
  ExtHeaderSize : smallword;
  First : boolean;
  Result: word;
  FileName : String;
  s : string;

procedure ReadHeader;
var
  ip : byte;
begin
  FillChar(H^, SizeOf(ARJHead), #$FF);
  BlockRead(f, H^.HeadID, 4, Result);
  if H^.HeadID <> $EA60 then ARCError := TRUE;
  if H^.BHeadSize > 2600 then ARCError := TRUE;
  if H^.BHeadSize = 0 then ARCEnd := TRUE;
  if ARCEnd or ARCError then Exit;
  BlockRead(f, H^.HeadSize, H^.BHeadSize, Result);
  if Result = 0 then ARCError := TRUE;
  FileName := '';
  i := H^.HeadSize - 26;
  while H^.Buffer[i] <> 0 do
   begin
    FileName := FileName + Char(H^.Buffer[i]);
    inc(i);
   end;
  Inc(i);

  if First then
   begin
    if (H^.ARJFlag and 2) <> 0 then ARJ_SEC := TRUE;  { old arj <= 2.39 }
    if (H^.ARJFlag and 64) <> 0 then ARJ_SEC := TRUE; { arj 2.40-41}
    if (H^.Buffer[i] <> 0) then
     begin
      CommAvail := TRUE;
      ip := 1;
      while (H^.Buffer[i] <> 0) do
       begin
        if (H^.Buffer[i] = $A) or (ip > 80) then
         begin
          s[0] := Char(ip-1);
//          AddComment(s);
//          s := '';
          ip := 1;
         end
        else
         begin
          s[ip] := Char(H^.Buffer[i]);
          inc(ip);
         end;
        inc(i);
       end;
     end;
   end;

  BlockRead(f, HeaderCRC, 4, Result);
  BlockRead(f, ExtHeaderSize, 2, Result);
  while (ExtHeaderSize <> 0) and (Result <> 0) do
   begin
    seek(f, FilePos(f) + ExtHeaderSize + 4);
    BlockRead(f, ExtHeaderSize, 2, Result);
   end;
end;

begin
  ARCEnd := FALSE;
  First := TRUE;
  ARJ_SEC := FALSE;
  GetMem(H, SizeOf(ARJHead));
  ReadHeader;
  First := FALSE;
  repeat
    ReadHeader;
    PFlag := ' ';
    if (not ARCError) and (not ARCEnd) then
     begin
      if (H^.ARJFlag and 1) <> 0 then PFlag := '*';
      if (H^.ARJFlag and 8) <> 0 then AddFile('Up', $210000, 0, 0);
      if H^.FileType <> 3 then
        AddFile(PFlag+FileName, H^.FTime, H^.OrigSize, H^.PackSize)
      else
        AddFile(PFlag + FileName + '/', H^.FTime, 0, 0);
      if (H^.ARJFlag and 4) <> 0 then AddFile('Dn', $210000, 0, 0);
     end;
    Seek(f, FilePos(f) + H^.PackSize);
  until ARCEnd or ARCError;
  FreeMem(H, SizeOf(ARJHead));
end; { ViewArj }

procedure ViewCharc;
type
  CharcHead = record
    PackSize : longint;
    OrigSize : longint;
    t1 : longint;
    FTime : longint;
    t2 : smallword;
    LFName : smallword;
  end;

  CharcDHead = record
    DTime : longint;
    t1 : byte;
    LDName : byte;
  end;

var
  H : CharcHead;
  HD :CharcDHead;
  HeadID : array [1..4] of char;
  i : byte;
  level : byte;
  Result: word;
  Path, FileName : string;
begin
  ARCEnd := FALSE;
  level := 1;
  Path := '';
  repeat
    BlockRead(f, HeadID, 4, Result);
    if (HeadID[1] <> 'S') and (HeadID[2] <> 'C') and
      (HeadID[3] <> 'h') then ARCError := TRUE;
    if HeadID[4] = 'd' then
     begin
      Dec(level);
      repeat
        Dec(Path[0]);
      until (Path[length(Path)] = '\') or (Path[0] = #0);
     end
    else if HeadID[4] = 'D' then
          begin
           Inc(level);
           BlockRead(f, HD.DTime, SizeOf(CharcDHead), Result);
           if HD.LDName >= SizeOf(FileName) then {!!!!!!!!!!}
            begin
             ARCError := True;
             Break;
            end;
           BlockRead(f, FileName[1], HD.LDName, Result);
           FileName[0] := Char(HD.LDName);
           Path := Path + FileName + '\';
          end
         else
          begin
           BlockRead(f, H.PackSize, SizeOf(CharcHead), Result);
           if (not ARCError) and (Result <> 0) then
            begin
             PFlag := ' ';
             if HD.LDName >= SizeOf(FileName) then {!!!!!!!!!!}
             begin
              ARCError := True;
              Break;
             end;
             BlockRead(f, FileName[1], H.LFName, Result);
             FileName[0] := Char(Lo(H.LFName));
             FileName := Path + FileName;
             AddFile(PFlag+FileName, H.FTime, H.OrigSize, H.PackSize);
             Seek(f,FilePos(f) + (H.PackSize-24-H.LFName));
            end;
          end;
  until (level = 0) or (Result = 0) or ARCError or ARCEnd;
end; { ViewCharc }

procedure ViewLIM;
type
  LIM_Head = record
    b1, b2 : byte;
    ASize : smallword;
    b3, b4 : byte;
    FTime : longint;
    FAttr : byte;
    b5, b6 : byte;
    OrigSize : longint;
    PackSize : longint;
    CRC : longint;
    FileName : array[1..79] of char;
  end;

var
  H : LIM_Head;
  Result : word;
  cb, i : byte;
  PathName, FileName : string;

procedure ReadFirstHeader;
var
  b : array[1..10] of byte;
  bl : byte;
  wc : smallword;
  w : smallword;
  ip : byte;
  s : string[90];
begin
  BlockRead(f, b, 10, Result);
  if b[6] = 4 then
   begin
    ARCError := TRUE;
    exit;
   end;
  BlockRead(f, wc, 2, Result);
  Dec(wc,5);
  if wc <> 0 then
   begin
    CommAvail := TRUE;
    ip := 1;
    for w := 1 to wc do
     begin
      BlockRead(f, bl, 1, Result);
      if (bl = $D) or (ip > 80) then
       begin
        s[0] := Char(ip-1);
//        AddComment(s);
//        s := '';
        ip := 1;
       end
      else if (bl <> $A) then
            begin
             s[ip] := Char(bl);
             inc(ip);
            end;
     end;
    s[0] := Char(ip-1);
//    AddComment(s);
    BlockRead(f, b, 5, Result);
  end;
  BlockRead(f, b, 1, Result);
end;

begin
  ARCEnd := FALSE;
  PathName := '';
  ReadFirstHeader;
  if ARCError then exit;
  repeat
    FileName := '';
    BlockRead(f, H.b1, 4, Result);
    if H.b1 = $80 then
     begin
      if H.ASize-4 > SizeOf(H.FileName) then {!!!!!!!!!!}
       begin
        ARCError := True;
        Break;
       end;
      BlockRead(f, H.FileName, H.ASize-4, Result);
     end
    else
     begin
      if H.ASize-4 > SizeOf(LIM_Head) - 3 then {!!!!!!!!!!}
       begin
        ARCError := True;
        Break;
       end;
      BlockRead(f, H.b3, H.ASize-4, Result);
     end;
    if H.ASize <= 5 then
     begin
      ARCEnd := TRUE;
      Break;
     end;
    i := 1;
    while H.FileName[i] <> #0 do
     begin
      {FileName := FileName+H.FileName[i];}
      inc(FileName[0]);
      FileName[Length(FileName)] := H.FileName[i];
      Inc(i);
      if i > 80 then
       begin
        ARCError := TRUE;
        exit;
       end;
     end;
    if H.b1 = $80 then
     begin
      PathName := FileName;
      H.PackSize := 0;
     end
    else if H.FAttr <> $10 then
          begin
           if PathName <> '' then FileName := PathName + '\' + FileName;
           AddFile(PFlag+FileName, H.FTime, H.OrigSize, H.PackSize);
          end;
    Seek(f, FilePos(f)+H.PackSize);
  until ARCEnd;
end; {ViewLIM}

procedure ViewZOO;
type
  ZOO_Header = record
    ZOO_Text : array[1..20] of char;
    ZOO_Tag : longint;
    ZOO_Start,
    ZOO_Minus : longint;
    Major_Ver,
    Minor_Ver : byte;
  end;

  ZOO_DirEntry = record
    ZOO_Tag : longint;
    ZOO_Type : byte;
    Method : byte;
    Next,
    ZOO_Offset : longint;
    FTime : longint;
    CRC : smallword;
    OrigSize,
    PackSize : longint;
    Major_Ver,
    Minor_Ver : byte;
    Deleted : byte;
    Struc : byte;
    Comment : longint;
    Cmt_Size : smallword;
    FName : array[1..13] of char;
    Dir_Len : smallword;
    tz : byte;
    Dir_CRC : smallword;
    NamLen : byte;
    DirLen : byte;
    Arr : array[1..70] of char;
  end;

var
  MH : ZOO_Header;
  FH : ZOO_DirEntry;
  w : word;
  i : byte;
  Time : longint;
  FileTime : array [1..2] of smallword absolute Time;
  tmp : smallword;
  FileName : string;
  DirName : string;
begin
  ARCEnd := FALSE;
  BlockRead(f, MH, SizeOf(ZOO_Header));
  Seek(f, MH.ZOO_Start);
  BlockRead(f, FH, SizeOf(ZOO_DirEntry), w);
  repeat
    if FH.ZOO_Tag <> $FDC4A7DC then ARCError := TRUE;
    FileName := '';
    i := 1;
    while FH.FName[i] <> #0 do
     begin
      FileName := FileName + FH.FName[i];
      Inc(i);
     end;

    if FH.DirLen <> 0 then
     begin
      DirName := '';
      DirName[0] := Char(FH.DirLen-1);
      move(FH.Arr[FH.NamLen+1], DirName[1], FH.DirLen);
      FileName := DirName+ '\' + FileName;
     end;
    Time := FH.FTime;
    tmp := FileTime[1];
    FileTime[1] := FileTime[2];
    FileTime[2] := tmp;

    AddFile(PFlag+FileName, Time, FH.OrigSize, FH.PackSize);
    Seek(f, FH.NEXT);
    FillChar(FH, SizeOf(ZOO_DirEntry), #$FF);
    BlockRead(f, FH, SizeOf(ZOO_DirEntry), w);
    if FH.FTime = 0 then ARCEnd := TRUE
    else if w <> SizeOf(ZOO_DirEntry) then ARCError := TRUE;
  until (FH.ZOO_Offset = 0) or ARCError or ARCEnd;
end; {ViewZOO}

procedure ViewHA;
type
  HA_M_Head = record
    M : array [1..2] of char;
    Files : smallword;
  end;

  HA_Head = record
    Method : byte; { $32 - ASC, $33 - CPY }
    PackSize : longint;
    OrigSize : longint;
    CRC : longint;
    FTime : longint;
    PathTRUE : char;
  end;

var
  H : HA_Head;
  HM : HA_M_Head;
  FCount : smallword;
  Result : word;
  i : byte;
  ch : char;
  b3, b4, b5 : byte;
  FileName : string;
  PathName : string;
begin
  ARCEnd := FALSE;
  BlockRead(f, HM, 4);
  for FCount := 1 to HM.Files do
   begin
    PathName := '';
    FileName := '';
    BlockRead(f, H, SizeOf(HA_Head), Result);
    if Result <> SizeOf(HA_Head) then
     begin
      ARCError := TRUE;
      break;
     end;

    if H.PathTRUE <> #0 then
     begin
      PathName[1] := H.PathTRUE;
      i := 2;
      BlockRead(f, ch, 1);
      while (ch <> #0) and (i < 80) do
       begin
        if ch = #$FF then ch := '\';
        PathName[i] := ch;
        Inc(i);
        BlockRead(f, ch, 1, Result);
        if Result <> 1 then
         begin
          ARCError := TRUE;
          break;
         end;
       end;
      PathNAme[0] := Char(i-1);
     end;

    i := 1;
    BlockRead(f, ch, 1);
    while (ch <> #0) and (i < 80) do
     begin
      FileName[i] := ch;
      Inc(i);
      BlockRead(f, ch, 1, Result);
      if Result <> 1 then
       begin
        ARCError := TRUE;
        break;
       end;
     end;
    FileName[0] := Char(i-1);
    H.FTime := UnixTimeToFile(H.FTime);

    AddFile(' ' + PathName+FileName, H.FTime, H.OrigSize, H.PackSize);
    BlockRead(f, b3, 3, Result);
    if Result <> 3 then
     begin
      ARCError := TRUE;
      break;
     end;
    Seek(f, FilePos(f) + H.PackSize);
   end;
end; { ViewHA }

procedure ViewRAR;
type
  tRARHead = record
    HeadID : longint;
    HeadLen : smallword;
    HeadFlag : byte;
  end;
{ 0x01    - признак Volume (архивный том)
  0x02    - присутствует комментарий к архиву
  0x04    - архив защищен от модификации
  0x08    - признак Solid (непрерывный архив)
  0x10    - комментарий к архиву упакован
  0x20    - в архиве содержится поле EXT1
}
  tRARFile = record
    PackedSize : longint;
    OrigSize : longint;
    CRC : smallword;
    HeadLen : smallword; { Полная длина заголовка файла, включая комментарии к файлу и строку с именем файла }
    FTime : longint;
    FAttr : byte;
    Flags : byte;
    MinVer : byte;
    NameLen : byte;
    Method : byte;
  end;
{ 0x01 - признак Volume (архивный том)
  0x02 - присутствует комментарий к архиву
  0x04 - архив защищен от модификации
  0x08 - признак Solid (непрерывный архив)
}
type
  tBuf = array[1..1024*40] of byte;
var
  H : tRARHead;
  HF : tRARFile;
  w : word;
  buf : ^tBuf;
  i, ip : smallword;
  HCommLen, FCommLen, Ext1Size : smallword;
  s : string;
begin
  ARCError := TRUE;
  ARCEnd := FALSE;
  BlockRead(f, H, SizeOf(H), w);
  if w <> SizeOf(H) then exit;
  if H.HeadID <> $5E7E4552 then exit;
  if (H.HeadFlag AND 2) <> 0 then
   begin
    BlockRead(f, HCommLen, 2);
    if HCommLen >= MaxAvail then Exit;         {!!!!!!!!}
    GetMem(buf, HCommLen);
    BlockRead(f, buf^[1], HCommLen, w);
    if w <> HCommLen then
     begin
      FreeMem(buf, HCommLen);
      exit;
     end;
    if (H.HeadFlag AND $10) = 0 then
     begin { не пакованный комментарий }
      CommAvail := TRUE;
      ip := 1;
      for i := 1 to HCommLen do
       begin
        if (Buf^[i] = $D) or (ip > 80) then
         begin
          s[0] := Char(ip-1);
//          AddComment(s);
          if i < HCommLen then Inc(i);
//         s := '';}
          ip := 1;
         end
        else
         begin
          s[ip] := Char(Buf^[i]);
          inc(ip);
         end;
       end;
      s[0] := Char(ip-1);
//      AddComment(s);
     end;
    FreeMem(buf, HCommLen);
  end;

  if (H.HeadFlag AND $20) <> 0 then
   begin
    BlockRead(f, Ext1Size, 2);
    Seek(f, FilePos(f)+Ext1Size);
   end;

  repeat
    PFlag := ' ';
    BlockRead(f, HF, SizeOf(tRARFile), w);
    if w = 0 then
     begin
      ARCEnd := TRUE;
      break;
     end;
    if w <> SizeOf(HF) then exit;
    if (HF.Flags and 4) <> 0 then PFlag := '*';
    if (HF.Flags and 8) <> 0 then
     begin
      BlockRead(f, FCommLen, 2);
      Seek(f, FilePos(f) + FCommLen);
     end;
    if HF.NameLen >= SizeOf(S) then         {!!!!!!!!!!}
     begin
      ArcError := True;
      Break;
     end;
    BlockRead(f, s[1], HF.NameLen);
    s[0] := char(HF.NameLen);
    if (HF.FAttr and $10) <> 0 then
     begin
      {s := S + '/';}
      Inc(s[0]);
      s[Length(s)] := '/';
     end;
    AddFile(PFlag + s, HF.FTime, HF.OrigSize, HF.PackedSize);

    Seek(f, FilePos(f)+HF.PackedSize);
  until ARCEnd;

  ARCError := FALSE;
end;

procedure ViewNRAR;
type
  MarkBlock = record
    HeadCRC : smallword;
    HeadType : byte;
    HeadFlags : smallword;
    HeadSize : smallword;
  end;

  FileHead = record
    PackedSize : longint;
    OrigSize : longint;
    Host_OS : byte;
    FILE_CRC : longint;
    FTime : longint;
    UNP_VER : byte;
    METHOD : byte;
    NameSize : smallword;
    Attr : longint;
  end;

const
  H_Block : array[1..7] of byte = ($52,$61,$72,$21,$1a,7,0);

var
  mb : MarkBlock;
  fh : FileHead;
  AddSize : longint;
  FileName : string;

procedure ReadMBlock;
var
  w : word;
begin
  AddSize := 0;
  BlockRead(f, MB, SizeOf(MarkBlock), w);
  if w = 0 then ARCEnd := TRUE
  else if w <> SizeOf(MarkBlock) then ARCError := TRUE;
end;

begin
  ARCEnd := FALSE;
  ReadMBlock; { маркерный блок }
  if CompStruct(MB, H_Block, 7) then
  begin
  end;

  ReadMBlock; { заголовок архива }
  Seek(f, FilePos(f)+6);
  if (MB.HeadFlags and 2 ) <> 0 then
   begin
    ReadMBlock; { заголовок комментария }
    Seek(f, FilePos(f)+MB.HeadSize-7);
    if AddSize <> 0 then Seek(f, FilePos(f)+AddSize);
   end;
  {    HEAD_FLAGS - 0x01    - признак Volume (архивный том)
                    0x02    - присутствует комментарий к архиву
                    0x04    - архив защищен от модификации
                    0x20    - архив содержит authenticity information}
  repeat
    PFlag := ' ';
    ReadMBlock;
    if ARCEnd or ARCError then break;
    case MB.HeadType of
      $74 : begin    {заголовок файла}
              BlockRead(f, fh, SizeOf(FileHead));
              if fh.NameSize > SizeOf(FileName) then    {!!!!!!!!}
               begin
                ARCError := True;
                Break;
               end;
              BlockRead(f, FileName[1], fh.NameSize);
              FileName[0] := Char(fh.NameSize);
       {   Head_FLAGS  0x01 - файл продолжается с предыдущего тома
                       0x02 - файл продолжается в следующем томе
                       0x08 - присутствует комментарий к файлу}
              if (MB.HeadFlags and 4) <> 0 then PFlag := '*';
              if (fh.Attr and $10) <> 0 then FileName := FileName + '\';
              AddFile(PFlag+FileName, FH.FTime, FH.OrigSize, FH.PackedSize);

              Seek(f, FilePos(f)+mb.HeadSize-fh.NameSize-SizeOf(FileHead)-7);
              Seek(f, FilePos(f)+fh.PackedSize);
            end;

      $75 : begin { заголовок комментария }
              Seek(f, FilePos(f)+MB.HeadSize-7);
              if AddSize <> 0 then Seek(f, FilePos(f)+AddSize);
            end;
      $76 : begin { дополнительная информация}
              Seek(f, FilePos(f)+MB.HeadSize-7);
              if AddSize <> 0 then Seek(f, FilePos(f)+AddSize);
            end;
      $77 : begin { дополнительная информация}
              BlockRead(f, AddSize, 4);
              Seek(f, FilePos(f)+MB.HeadSize-11 {-7-4});
              if AddSize <> 0 then Seek(f, FilePos(f)+AddSize);
            end;
      $78 : begin { дополнительная информация}
              ARCEnd := True;
            end;

    end;
  until ARCEnd or ARCError;

end;

procedure ReadArchive(const inName : String);
//var
//  SaveAttr: Word;
begin
  Assign(f, inName);
  //SaveAttr := FileGetAttr(inName);
  //FileSetAttr(inName, $20);

  FileMode := $40; // open_access_ReadOnly or open_share_DenyNone;
  reset(f, 1);
  if IOResult <> 0 then Exit;

  AutoDetect;

  Seek(f, StartArchive);
  case CurView of
    1 : ViewZip;
    2 : ViewArc;
    3 : ViewICE;
    4 : ViewARJ;
    5 : ViewArc;
    6 : ViewCharc;
    7 : ViewZOO;
    8 : ViewLIM;
    9 : ViewHA;
   10 : if NewRAR then ViewNRAR else ViewRAR;
  // Это больше не нужно.
  {
  else
    AddFileCallBack('FILE_ID.DIZ', 1, 1, 1); // let's try to extract file_id.diz from unknown archives
  }
  end;
  close(f);
end;

end.
