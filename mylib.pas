unit MyLib;

/////////////////////////////////////////////////////////////////////
//
// Hi-Files Version 2
// Copyright (c) 1997-2004 Dmitry Liman [2:461/79]
//
// http://hi-files.narod.ru
//
/////////////////////////////////////////////////////////////////////

interface

uses Objects, SysUtils;

function JustUpperCase( S: String ) : String;

function JustSameText( S1, S2: String ) : Boolean;
function JustCompareText( S1, S2: String ) : Integer;

function HomeDir: String;
function AtPath( const FileName, Path: String ) : String;
function AtHome( const FileName: String ) : String;
function RelativePath( var S: String ) : Boolean;
function HasWildChars(const S: String ) : Boolean;
function DefaultExtension( const FileName, Ext: String ) : String;
function AddBackSlash(const DirName : string) : string;
function RemoveBackSlash( Path: String ) : String;
function ExtractFileNameOnly( const FileName: String ) : String;
function QuotedFile( const S: String ) : String;

function TrimmedName(const Name: String; Limit: Byte): String;

function GetCounterStr(ResID, Counter: Integer) : String;

type
  UnixTime = Longint;
  FileTime = Longint; { ref: GetFTime/SetFTime }

function CurrentUnixTime : UnixTime;
function CurrentFileTime : FileTime;

function FileTimeToUnix( ft: FileTime ) : UnixTime;
function UnixTimeToFile( ut: UnixTime ) : FileTime;

function UnixTimeToDateStr( ut: UnixTime ) : String;

// Всегда возвpащает в фоpмате dd-Mmm-yy
function GetFileDateStr( ft: FileTime ) : String;

// dd-Mmm-yy hh:mm:ss
function LogTimeStamp( ft: FileTime ) : String;

function DaysBetween( u1, u2: UnixTime ) : Integer;

procedure Sleep( MSec: Word );

type
  CharSet = set of Char;

{ Следующие 3 пpоцедуpы - это вpаппеp к интеpфейсу NewStr/DisposeStr }
{ из TurboVision (Objects.pas), и используется, чтобы отвязаться от  }
{ одноимённый дельфийских пpоцедуp из SysUtils.Pas. Дополнительная   }
{ функциональность: можно спокойно pаботать с пустыми стpоками.      }

function  AllocStr( const S: String ) : PString;
procedure FreeStr( var P: PString );
procedure ReplaceStr( var P: PString; const S: String );

function SafeStr( const P: PString ) : String;

function WildMatch( Source, Pattern : String) : Boolean;
function HasWild( S: String ) : Boolean;

function WordCount(const S : string; WordDelims : CharSet) : Integer;
function WordPosition(N : Integer; const S : string; WordDelims : CharSet) : Integer;
function ExtractWord(N : Integer; const S : string; WordDelims : CharSet) : String;
procedure WordWrap(InSt : string; var OutSt, Overlap : string;
                   Margin : Integer; PadToMargin : Boolean);
function Replace(const S, What, Value : String ) : String;

procedure SplitPair( const S: String; var Key, Value: String );
procedure StripComment( var S: String );
function  ExtractQuoted( S: String ) : String;
procedure SkipWhiteSpace( S: String; var pos: Integer );
function  GetLiterals( S: String; Start: Integer; var Stop: Integer ) : String;
function  GetRightID( S: String; Start: Integer; var Stop: Integer ) : String;
function  MakePrintable( const S: String ) : String;

function HexToInt( const S: String ) : Longint;
function StrToBool( const S: String ) : Boolean;
function BoolToStr( B: Boolean ) : String;
function IntToSignedStr( N: Integer ) : String;
function TwoDigits( N: Integer ) : String;
function ASRF( FSize: Double ) : String;

function CreateDirTree( DirName: String ) : Boolean;
function ExistingDir ( const S: String; AutoCreate: Boolean ) : String;
function ExistingPath( const S: String ) : String;

// Если путь не указан, дополняется из ParamStr(0)
function ExistingFile( const S: String ) : String;

function ScanR( var P; Offset, Size: Integer; C: Char ): Integer;
function SkipR( var P; Offset, Size: Integer; C: Char ): Integer;

function CharStr( C: Char; Len: Integer ) : String;
function Pad( const S: String; Len: Integer ) : String;
function PadCh( const S: String; Len: Integer; Ch: Char ) : String;
function LeftPad( const S: String; Len: Integer ) : String;
function LeftPadCh( const S: String; Len: Integer; Ch: Char ) : String;
function CenterCh( const S : string; Width : Integer; Ch: Char ) : String;
function Center( const S: String; Width: Integer ) : String;
function StrSet( Ch: PChar; const S: String; Size: Integer ) : PChar;

procedure Destroy( O: PObject );

procedure SetBit( var Where: Longint; Mask: Longint; Raised: Boolean );
function TestBit( Where, Mask: Longint ) : Boolean;

const
  BLANK = [' '];
  IDCHARS = ['A'..'z', '0'..'9', '_'];
  HIDDEN_PREFIX = ';#';

  MonthName: array [1..12] of String[3] = (
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec' );

  DayName: array [1..7] of String[3] = (
    'Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat' );

type
  PStrings = ^TStrings;
  TStrings = object (TCollection)
    procedure FreeItem( Item: Pointer ); virtual;
  end; { TStrings }

  PNoCaseStrCollection = ^TNoCaseStrCollection;
  TNoCaseStrCollection = object (TStringCollection)
    procedure FreeItem( Item: Pointer ); virtual;
    function Compare( Key1, Key2: Pointer ) : Integer; virtual;
  end; { TNoCaseStrCollection }

// Virtual File System API :)

procedure DecodeLFN( var R: TSearchRec; var ShortName, LongName: String );

function VFS_MoveFile( const Source, Target: String ) : Integer;
function VFS_CopyFile( const Source, Target: String ) : Boolean;
function VFS_TouchFile( const FileName: String; Stamp: FileTime ) : Boolean;
function VFS_EraseFile( const FileName: String ) : Boolean;
function VFS_RenameFile( const Source, Dest: String ) : Boolean;

function VFS_ValidatePath( const Source: String ) : String;

{$IFDEF Win32}

// Возвращает только короткое имя _файла_, без пути!

function VFS_GetShortName( Source: String; var Target: String ) : Boolean;
{$ENDIF}

procedure VFS_BackupFile( const FileName: String; Level: Integer );

{ =================================================================== }

implementation

uses
{$IFDEF WIN32}
  Windows,
{$ENDIF}
  Dos, VpSysLow, VpUtils, MsgBox, Views, _RES, _Cfg;

const
  DosDelimSet = ['\', '/', ':', #0];

type
  TXlateArray = array [Char] of Char;

const
  Upper_Xlate: TXlateArray = (

#0, #1, #2, #3, #4, #5, #6, #7, #8, #9, #10, #11, #12, #13, #14, #15,
#16, #17, #18, #19, #20, #21, #22, #23, #24, #25, #26, #27, #28, #29, #30, #31,
#32, #33, #34, #35, #36, #37, #38, #39, #40, #41, #42, #43, #44, #45, #46, #47,
#48, #49, #50, #51, #52, #53, #54, #55, #56, #57, #58, #59, #60, #61, #62, #63,
#64, #65, #66, #67, #68, #69, #70, #71, #72, #73, #74, #75, #76, #77, #78, #79,
#80, #81, #82, #83, #84, #85, #86, #87, #88, #89, #90, #91, #92, #93, #94, #95,
#96, #65, #66, #67, #68, #69, #70, #71, #72, #73, #74, #75, #76, #77, #78, #79,
#80, #81, #82, #83, #84, #85, #86, #87, #88, #89, #90, #123, #124, #125, #126, #127,
#128, #129, #130, #131, #132, #133, #134, #135, #136, #137, #138, #139, #140, #141, #142, #143,
#144, #145, #146, #147, #148, #149, #150, #151, #152, #153, #154, #155, #156, #157, #158, #159,
#128, #129, #130, #131, #132, #133, #134, #135, #136, #169, #138, #139, #140, #141, #142, #143,
#176, #177, #178, #179, #180, #181, #182, #183, #184, #185, #186, #187, #188, #189, #190, #191,
#192, #193, #194, #195, #196, #197, #198, #199, #200, #201, #202, #203, #204, #205, #206, #207,
#208, #209, #210, #211, #212, #213, #214, #215, #216, #217, #218, #219, #220, #221, #222, #223,
#144, #145, #146, #147, #148, #149, #150, #151, #152, #153, #154, #155, #156, #157, #158, #159,
#240, #240, #242, #243, #244, #245, #246, #247, #248, #249, #250, #251, #252, #253, #254, #255

  );


{ --------------------------------------------------------- }
{ JustUpperCase                                             }
{ --------------------------------------------------------- }

function JustUpperCase( S: String ) : String;
var
  j: Integer;
begin
  for j := 1 to Length(S) do
    S[j] := Upper_Xlate[S[j]];
  Result := S;
end; { JustUpperCase }

{ --------------------------------------------------------- }
{ JustSameText                                              }
{ --------------------------------------------------------- }

function JustSameText( S1, S2: String ) : Boolean;
var
  j: Integer;
begin
  Result := False;
  if Length(S1) <> Length(S2) then Exit;
  for j := 1 to Length(S1) do
    if Upper_Xlate[S1[j]] <> Upper_Xlate[S2[j]] then Exit;
  Result := True;
end; { JustSameText }

{ --------------------------------------------------------- }
{ JustCompareText                                           }
{ --------------------------------------------------------- }

function JustCompareText( S1, S2: String ) : Integer;
begin
  S1 := JustUpperCase( S1 );
  S2 := JustUpperCase( S2 );
  Result := CompareStr( S1, S2 );
end; { JustCompareText }

{ --------------------------------------------------------- }
{ Sleep                                                     }
{ --------------------------------------------------------- }

procedure Sleep( MSec: Word );
begin
  SysCtrlSleep( MSec );
end; { Sleep }


{ --------------------------------------------------------- }
{ AddBackSlash                                              }
{ --------------------------------------------------------- }

function AddBackSlash(const DirName : string) : string;
begin
  if DirName[Length(DirName)] in DosDelimSet then
    Result := DirName
  else
    Result := DirName + SysPathSep;
end; { AddBackSlash }

{ --------------------------------------------------------- }
{ RemoveBackSlash                                           }
{ --------------------------------------------------------- }

function RemoveBackSlash( Path: String ) : String;
var
  PLen: Byte absolute Path;
begin
  RemoveBackSlash := '';
  if PLen = 0 then Exit;
  if Path[ PLen ] = SysPathSep then Dec( PLen );
  RemoveBackSlash := Path;
end; { RemoveBackSlash }

{ --------------------------------------------------------- }
{ HomeDir                                                   }
{ --------------------------------------------------------- }

function HomeDir: String;
{$IFDEF Win32}
var
  FNameZ: array [0..260] of Char;
begin
  StrPCopy( FNameZ, ParamStr(0) );
  CharToOem( FNameZ, FNameZ );
  Result := StrPas( FNameZ );
{$ELSE}
begin
  Result := ParamStr(0);
{$ENDIF}
end; { HomeDir }

{ --------------------------------------------------------- }
{ AtPath                                                    }
{ --------------------------------------------------------- }

function AtPath( const FileName, Path: String ) : String;
begin
  Result := AddBackSlash(Path) + ExtractFileName(FileName);
end; { AtPath }


{ --------------------------------------------------------- }
{ AtHome                                                    }
{ --------------------------------------------------------- }

function AtHome( const FileName: String ) : String;
begin
  Result := AtPath( FileName, ExtractFilePath(HomeDir) );
end; { AtHome }

{ --------------------------------------------------------- }
{ RelativePath                                              }
{ --------------------------------------------------------- }

function RelativePath(var S: String): Boolean;
begin
  S := Trim(S);
  RelativePath := not ((S <> '') and ((S[1] = '\') or (S[2] = ':')));
end; { RelativePath }

{ --------------------------------------------------------- }
{ HasWildChars                                              }
{ --------------------------------------------------------- }

function HasWildChars(const S: String) : Boolean;
begin
  Result := (Pos('*', S) <> 0) or (Pos('?', S) <> 0);
end; { HasWildChars }

{ --------------------------------------------------------- }
{ DefaultExtension                                          }
{ --------------------------------------------------------- }

function DefaultExtension( const FileName, Ext: String ) : String;
begin
  if ExtractFileExt( FileName ) = '' then
    Result := FileName + Ext
  else
    Result := FileName;
end; { DefaultExtension }

{ --------------------------------------------------------- }
{ ExtractFileNameOnly                                       }
{ --------------------------------------------------------- }

function ExtractFileNameOnly( const FileName: String ) : String;
var
  n: Integer;
begin
  Result := ExtractFileName( FileName );
  n := Length( Result );
  while n > 0 do
  begin
    if Result[n] = '.' then
    begin
      SetLength( Result, Pred(n) );
      Exit;
    end;
    Dec(n);
  end;
end; { ExtractFileNameOnly }

{ --------------------------------------------------------- }
{ TrimmedName                                               }
{ --------------------------------------------------------- }

function TrimmedName(const Name: String; Limit: Byte): String;
var
  B, E, L: Integer;
  S: String;
begin
  L := Length(Name);
  if L <= Limit then TrimmedName := Name
  else
  begin
    B := 1;
    while (B < L) and (Name[B] <> '\') do Inc(B);
    while (B < L) and (Name[B] =  '\') do Inc(B);
    E := B;
    while (E < L) and (L - (E - B) + 3 > Limit) do Inc(E);
    while (E < L) and (Name[E] <> '\') do Inc(E);
    if Name[E] = '\' then
    begin
      S := Name;
      Delete(S, B, E - B);
      Insert('...', S, B);
    end
    else S := ExtractFileName(Name);
    if Length(S) > Limit then S[0] := Char(Limit);
    TrimmedName := S;
  end;
end;

{ --------------------------------------------------------- }
{ GetCounterStr                                             }
{ --------------------------------------------------------- }

function GetCounterStr(ResID, Counter: Integer) : String;
var
  D: Integer;
begin
  D := Counter - (Counter div 10) * 10;
  case D of
    1:
      Result := LoadString( ResID );
    2, 3, 4:
      Result := LoadString( ResID + 1 );
  else
    Result := LoadString( ResID + 2 );
  end;
end; { GetCounterStr }


{ --------------------------------------------------------- }
{ Unix-Time routines                                        }
{ --------------------------------------------------------- }

const
  C1970 = 2440588;
  D0    =    1461;
  D1    =  146097;
  D2    = 1721119;


Procedure GregorianToJulianDN( Year, Month, Day : integer;
                               var JulianDN : longint );
var
  Century,
  XYear    : longint;
begin
  If Month <= 2 then
    begin
      Year  := Pred(Year);
      Month := Month + 12;
    end;
  Month    := Month - 3;
  Century  := Year div 100;
  XYear    := Year mod 100;
  Century  := (Century * D1) shr 2;
  XYear    := (XYear * D0) shr 2;
  JulianDN := ((((Month * 153) + 2) div 5) + Day) + D2 + XYear + Century;
end;


Procedure JulianDNToGregorian( JulianDN : longint;
                               var Year, Month, Day : integer );
var
  Temp,
  XYear   : longint;
  YYear,
  YMonth,
  YDay    : integer;
begin
  Temp     := (((JulianDN - D2) shl 2) - 1);
  XYear    := (Temp mod D1) or 3;
  JulianDN := Temp div D1;
  YYear    := (XYear div D0);
  Temp     := ((((XYear mod D0) + 4) shr 2) * 5) - 3;
  YMonth   := Temp div 153;
  If YMonth >= 10 then
    begin
      YYear  := YYear + 1;
      YMonth := YMonth - 12;
    end;
  YMonth := YMonth + 3;
  YDay   := Temp mod 153;
  YDay   := (YDay + 5) div 5;
  Year   := YYear + (JulianDN * 100);
  Month  := YMonth;
  Day    := YDay;
end;


Function FileTimeToUnix( ft: FileTime ) : UnixTime;
var
  DT       : DateTime;
  DateNum,
  SecsPast,
  dth,
  DaysPast : longint;
begin
  UnpackTime(ft,DT);
  GregorianToJulianDN(DT.Year,DT.Month,DT.Day,DateNum);
  DaysPast := DateNum - c1970;
  SecsPast := DaysPast * 86400;
  {.Fucking Hydra.}
  DTH:=Dt.hour;
  SecsPast := SecsPast + DTH * 3600 + DT.Min * 60 + DT.Sec;
  Result := SecsPast;
end;


Function UnixTimeToFile( ut: UnixTime ) : FileTime;
var
  DT       : DateTime;
  DateNum  : longint;
  n        : word;
begin
  DateNum := (ut div 86400) + c1970;
  JulianDNToGregorian(DateNum,integer(DT.Year),integer(DT.Month),integer(DT.Day));
  ut := ut mod 86400;
  DT.Hour  := ut div 3600;
  ut := ut mod 3600;
  DT.Min   := ut div 60;
  DT.Sec   := ut mod 60;
  PackTime(DT,ut);
  Result := ut;
end;


{ --------------------------------------------------------- }
{ CurrentUnixTime                                           }
{ --------------------------------------------------------- }

function CurrentUnixTime : UnixTime;
begin
  Result := FileTimeToUnix( CurrentFileTime );
end; { CurrentUnixTime }


{ --------------------------------------------------------- }
{ CurrentFileTime                                           }
{ --------------------------------------------------------- }

function CurrentFileTime: FileTime;
var
  Touch: Longint;
  Today: DateTime;
  Dummy: Word;
begin
  with Today do GetDate( Year, Month, Day, Dummy );
  with Today do GetTime( Hour, Min, Sec, Dummy );
  PackTime( Today, Touch );
  Result := Touch;
end; { CurrentFileTime }

{ --------------------------------------------------------- }
{ UnixTimeToDateStr                                         }
{ --------------------------------------------------------- }

function UnixTimeToDateStr( ut: UnixTime ) : String;
begin
  Result := DateToStr( FileDateToDateTime( UnixTimeToFile(ut) ) );
end; { UnixTimeToDateStr }

{ --------------------------------------------------------- }
{ GetFileDateStr                                            }
{ --------------------------------------------------------- }

function GetFileDateStr( ft: FileTime ) : String;
var
  D: DateTime;
begin
  UnpackTime( ft, D );
  if D.Year >= 2000 then
    Dec( D.Year, 2000 )
  else
    Dec( D.Year, 1900 );
  Result := Format( '%2d-%3s-%2d', [D.Day, MonthName[D.Month], D.Year] );
  if Result[1] = ' ' then Result[1] := '0';
  if Result[8] = ' ' then Result[8] := '0';
end; { GetFileDateStr }


{ --------------------------------------------------------- }
{ LogTimeStamp                                              }
{ --------------------------------------------------------- }

function LogTimeStamp( ft: FileTime ) : String;
var
  Hour, Min, Sec, MSec: SmallWord;
begin
  DecodeTime( FileDateToDateTime(ft), Hour, Min, Sec, MSec );
  Result := GetFileDateStr( ft ) + ' ' +
            TwoDigits( Hour ) + ':' +
            TwoDigits( Min ) +  ':' +
            TwoDigits( Sec );
end; { LogTimeStamp }

{ --------------------------------------------------------- }
{ ClearTimePart                                             }
{ --------------------------------------------------------- }

function ClearTimePart( ut: UnixTime ) : UnixTime;
var
  D: DateTime;
  f: FileTime;
begin
  UnpackTime( UnixTimeToFile(ut), D );
  D.Hour := 0; D.Min := 0; D.Sec := 0;
  PackTime( D, f );
  Result := FileTimeToUnix( f );
end; { ClearTimePart }


{ --------------------------------------------------------- }
{ DaysBetween                                               }
{ --------------------------------------------------------- }

function DaysBetween( u1, u2: UnixTime ) : Integer;
const
  SecPerDay = 3600 * 24;
begin
  Result := (ClearTimePart(u1) - ClearTimePart(u2)) div SecPerDay;
end; { DaysBetween }


{ --------------------------------------------------------- }
{ WildMatch                                                 }
{ --------------------------------------------------------- }

function WildMatch( Source, Pattern : String ) : Boolean;

  function RMatch(var s : String; i : Integer;
                  var p : String; j : Integer) : Boolean;

   { s = to be tested ,     i = position in s }
   { p = pattern to match , j = position in p }

  var
    Matched : Boolean;
    k       : Integer;
   begin
     if Length(p) = 0 then
     begin
       RMatch := True;
       Exit;
     end;

     while True do
     begin
       if (i > Length(s)) and (j > Length(p)) then
       begin
         RMatch := True;
         Exit;
       end
       else if j > Length(p) then
       begin
         RMatch := False;
         Exit;
       end
       else if p[j] = '*' then
       begin
         k := i;
         if j = Length(p) then
         begin
           RMatch := True;
           Exit;
         end
         else
         begin
           repeat
             Matched := RMatch(s, k, p, j + 1);
             Inc(k);
           until Matched or (k > Length(s));
           RMatch := Matched;
           Exit;
         end;
       end
       else if (p[j] <> '?') and (p[j] <> s[i]) then
       begin
         RMatch := False;
         Exit;
       end
       else
       begin
         Inc(i);
         Inc(j);
       end;
     end;
   end { Rmatch };

begin
  if HasWild( Pattern ) then
  begin
    Source  := JustUpperCase( Source );
    Pattern := JustUpperCase( Pattern );
    Result  := RMatch( Source, 1, Pattern, 1 );
  end
  else
    Result := JustSameText( Source, Pattern );
end { WildMatch };

{ --------------------------------------------------------- }
{ HasWild                                                   }
{ --------------------------------------------------------- }

function HasWild( S: String ) : Boolean;
begin
  S[Succ(Length(S))] := #0;
  Result := (StrScan( @S[1], '*' ) <> nil) or (StrScan( @S[1], '?' ) <> nil);
end; { HasWild }

{ --------------------------------------------------------- }
{ WordCount                                                 }
{ --------------------------------------------------------- }

function WordCount(const S : string; WordDelims : CharSet) : Integer;
var
  I : Integer;
  SLen : Byte absolute S;
begin
  Result := 0;
  I := 1;
  while I <= SLen do
  begin
    {skip over delimiters}
    while (I <= SLen) and (S[I] in WordDelims) do
      Inc(I);

    {if we're not beyond end of S, we're at the start of a word}
    if I <= SLen then
      Inc(Result);

    {find the end of the current word}
    while (I <= SLen) and not(S[I] in WordDelims) do
      Inc(I);
  end;
end; { WordCount }

{ --------------------------------------------------------- }
{ WordPosition                                              }
{ --------------------------------------------------------- }

function WordPosition(N : Integer; const S : string; WordDelims : CharSet) : Integer;
var
  Count : Integer;
  I : Integer;
  SLen : Byte absolute S;
begin
  Count := 0;
  I := 1;
  Result := 0;

  while (I <= SLen) and (Count <> N) do
  begin
    {skip over delimiters}
    while (I <= SLen) and (S[I] in WordDelims) do
      Inc(I);

    {if we're not beyond end of S, we're at the start of a word}
    if I <= SLen then
      Inc(Count);

    {if not finished, find the end of the current word}
    if Count <> N then
      while (I <= SLen) and not(S[I] in WordDelims) do
        Inc(I)
    else
        Result := I;
  end;
end; { WordPosition }


{ --------------------------------------------------------- }
{ ExtractWord                                               }
{ --------------------------------------------------------- }

function ExtractWord(N : Integer; const S : string; WordDelims : CharSet) : String;
var
  I, Len : Integer;
  SLen : Byte absolute S;
begin
  Len := 0;
  I := WordPosition(N, S, WordDelims);
  if I <> 0 then
    {find the end of the current word}
    while (I <= SLen) and not(S[I] in WordDelims) do
    begin
      {add the I'th character to result}
      Inc(Len);
      Result[Len] := S[I];
      Inc(I);
    end;
  Result[0] := Char(Len);
end; { ExtractWord }

{ --------------------------------------------------------- }
{ WordWrap                                                  }
{ --------------------------------------------------------- }

procedure WordWrap(InSt : string; var OutSt, Overlap : string;
                   Margin : Integer; PadToMargin : Boolean);
  {-Wrap InSt at Margin, storing the result in OutSt and the remainder
    in Overlap}
var
  InStLen : Byte absolute InSt;
  OutStLen : Byte absolute OutSt;
  OvrLen : Byte absolute Overlap;
  EOS, BOS : Word;
begin
  {find the end of the output string}
  if InStLen > Margin then begin
    {find the end of the word at the margin, if any}
    EOS := Margin;
    while (EOS <= InStLen) and (InSt[EOS] <> ' ') do
      Inc(EOS);
    if EOS > InStLen then
      EOS := InStLen;

    {trim trailing blanks}
    while (InSt[EOS] = ' ') and (EOS > 0) do
      Dec(EOS);

    if EOS > Margin then begin
      {look for the space before the current word}
      while (EOS > 0) and (InSt[EOS] <> ' ') do
        Dec(EOS);

      {if EOS = 0 then we can't wrap it}
      if EOS = 0 then
        EOS := Margin
      else
        {trim trailing blanks}
        while (InSt[EOS] = ' ') and (EOS > 0) do
          Dec(EOS);
    end;
  end
  else
    EOS := InStLen;

  {copy the unwrapped portion of the line}
  OutStLen := EOS;
  Move(InSt[1], OutSt[1], OutStLen); {!!.01}

  {find the start of the next word in the line}
  BOS := EOS+1;
  while (BOS <= InStLen) and (InSt[BOS] = ' ') do
    Inc(BOS);

  if BOS > InStLen then
    OvrLen := 0
  else begin
    {copy from the start of the next word to the end of the line}
    OvrLen := Succ(InStLen-BOS);
    Move(InSt[BOS], Overlap[1], OvrLen); {!!.01}
  end;

  {pad the end of the output string if requested}
  if PadToMargin and (OutStLen < Margin) then begin
    FillChar(OutSt[OutStLen+1], Margin-OutStLen, ' ');
    OutStLen := Margin;
  end;
end; { WordWrap }

{ --------------------------------------------------------- }
{ SplitPair                                                 }
{ --------------------------------------------------------- }

procedure SplitPair( const S: String; var Key, Value: String );
const
  BLANK = [' '];
var
  j: Integer;
begin
  Key := JustUpperCase( ExtractWord( 1, S, BLANK ) );
  if WordCount( S, BLANK ) > 1 then
    Value := TrimRight( Copy( S, WordPosition( 2, S, BLANK ), Length(S) ))
  else
    Value := '';
end; { SplitPair }


{ --------------------------------------------------------- }
{ StripComment                                              }
{ --------------------------------------------------------- }

procedure StripComment( var S: String );
var
  j: Integer;
begin
  if Pos( HIDDEN_PREFIX, S ) = 1 then Delete( S, 1, Length(HIDDEN_PREFIX) );
  j := Pos( ';', S );
  if j > 0 then
    S[0] := Chr(j-1);
  S := Trim( S );
end; { StripComment }


{ --------------------------------------------------------- }
{ HexToInt                                                  }
{ --------------------------------------------------------- }

function HexToInt( const S: String ) : Longint;
var
  j: Longint;
begin
  Result := 0;
  for j := 8 downto 1 do
  begin
    if S[j] > #57 then
      Result := Result or (Ord(S[j]) - 55) shl ((8 - j) shl 2)
    else
      Result := Result or (Ord(S[j]) - 48) shl ((8 - j) shl 2)
  end;
end; { HexToInt }


{ --------------------------------------------------------- }
{ StrToBool                                                 }
{ --------------------------------------------------------- }

function StrToBool( const S: String ) : Boolean;
const
  NumVal = 5;
type
  TValues = array [1..NumVal] of String;
const
  TrueValues  : TValues = ( 'Yes', 'Y', 'True', 'T', '1' );
  FalseValues : TValues = ( 'No', 'N', 'False', 'F', '0' );
var
  j: Integer;
begin
  for j := 1 to NumVal do
  begin
    if JustSameText( S, TrueValues[j] ) then
    begin
      Result := True;
      Exit;
    end;
    if JustSameText( S, FalseValues[j] ) then
    begin
      Result := False;
      Exit;
    end;
  end;
  raise EConvertError.Create( Format(LoadString(_SInvalidBool), [S] ));
end; { StrToBool }

{ --------------------------------------------------------- }
{ IntToSignedStr                                            }
{ --------------------------------------------------------- }

function IntToSignedStr( N: Integer ) : String;
begin
  if N > 0 then
    Result := '+'
  else if N < 0 then
    Result := '-'
  else
    Result := '';
  Result := Result + IntToStr(N);
end; { IntToSignedStr }

{ --------------------------------------------------------- }
{ TwoDigits                                                 }
{ --------------------------------------------------------- }

function TwoDigits( N: Integer ) : String;
begin
  if N > 99 then
    raise EIntError.Create( 'TwoDigits: argument > 99' );
  if N <= 9 then
    Result := '0' + IntToStr( N )
  else
    Result := IntToStr( N );
end; { TwoDigits }

{ --------------------------------------------------------- }
{ CreateDirTree                                             }
{ --------------------------------------------------------- }

function CreateDirTree( DirName: String ) : Boolean;
var
  S : String;
  wc: Integer;
  j : Integer;
  BS: CharSet;
begin
  BS := [ SysPathSep ];
  DirName := FExpand( DirName );
  wc := WordCount( DirName, BS );
  S  := ExtractWord( 1, DirName, BS );
  Result := False;
  for j := 2 to wc do
  begin
    S := S + SysPathSep + ExtractWord( j, DirName, BS );
    if not DirExists( S ) then
    begin
      try
        MkDir( S );
      except
        Exit;
      end;
    end;
  end;
  Result := True;
end; { MakeDir }

{ --------------------------------------------------------- }
{ ExistingDir                                               }
{ --------------------------------------------------------- }

function ExistingDir( const S: String; AutoCreate: Boolean ) : String;
begin
  Result := S;
  if (S = '') or DirExists( S ) then
    Exit
  else if AutoCreate and (MessageBox( Format(LoadString(_SAskCreateDir), [S]), nil, mfWarning + mfYesNoCancel ) = cmYes) then
  begin
    if not CreateDirTree(S) then
      raise Exception.Create( Format(LoadString(_SMkDirFailed), [S]));
  end
  else
    raise Exception.Create( Format(LoadString(_SDirNotExists), [S]));
end; { ExistingDir }

{ --------------------------------------------------------- }
{ ExistingPath                                              }
{ --------------------------------------------------------- }

function ExistingPath( const S: String ) : String;
var
  P: String;
begin
  P := ExtractFilePath(ExpandFileName(S));
  if (S = '') or DirExists(P) then
    Result := S
  else
    raise Exception.Create( Format(LoadString(_SDirNotExists), [S]) );
end; { ExistingPath }

{ --------------------------------------------------------- }
{ ExistingFile                                              }
{ --------------------------------------------------------- }

function ExistingFile( const S: String ) : String;
begin
  if S = '' then
    Result := S
  else
  begin
    if ExtractFileDir( S ) = '' then
      Result := AtPath( S, ExtractFileDir( HomeDir ) )
    else
      Result := S;
    if not FileExists( Result ) then
      raise Exception.Create( Format(LoadString(_SFileMustExists), [S] ));
  end;
end; { ExistingFile }

{ --------------------------------------------------------- }
{ BoolToStr                                                 }
{ --------------------------------------------------------- }

function BoolToStr( B: Boolean ) : String;
begin
  if B then
    Result := 'Yes'
  else
    Result := 'No';
end; { BoolToStr }


{ --------------------------------------------------------- }
{ AllocStr                                                  }
{ --------------------------------------------------------- }

const
  EmptyStr : String[1] = '';
  NullStr  : PString = @EmptyStr;

function AllocStr( const S: String ) : PString;
begin
  if S <> '' then
  begin
    GetMem(Result, Length(S) + 1);
    Move(S, Result^, Length(S) + 1);
  end
  else
    Result := NullStr;
end; { AllocStr }


{ --------------------------------------------------------- }
{ FreeStr                                                   }
{ --------------------------------------------------------- }

procedure FreeStr( var P: PString );
begin
  if (P <> nil) and (P <> NullStr) then
    FreeMem(P, Length(P^) + 1);
  P := nil;
end; { FreeStr }


{ --------------------------------------------------------- }
{ ReplaceStr                                                }
{ --------------------------------------------------------- }

procedure ReplaceStr( var P: PString; const S: String );
begin
  FreeStr( P );
  P := AllocStr( S );
end; { ReplaceStr }


{ --------------------------------------------------------- }
{ SafeStr                                                   }
{ --------------------------------------------------------- }

function SafeStr( const P: PString ) : String;
begin
  if (P <> nil) and (P <> NullStr) then
    Result := P^
  else
    Result := '<none>';
end; { SafeStr }


{ --------------------------------------------------------- }
{ ScanR                                                     }
{ --------------------------------------------------------- }
{
function ScanR( var P; Offset, Size: Integer; C: Char ) : Integer;
var
  B: TByteArray absolute P;
begin
  while (Offset < Size) and (B[Offset] <> Byte(C)) do Inc(Offset);
  Result := Offset;
end; { ScanR }
}

function ScanR(var P; Offset, Size: Integer; C: Char): Integer; assembler;
        {&USES esi,edi} {&FRAME-}
asm
        cld
        mov     edi,P
        mov     edx, edi
        add     edi,&Offset
        mov     ecx,Size
        sub     ecx,&Offset
        mov     al,C
        repne   scasb
        je      @@found
        mov     eax, Size
        jmp     @@exit
@@found:
        sub     edi, edx
        mov     eax, edi
        dec     eax
@@exit:
end;


{ --------------------------------------------------------- }
{ SkipR                                                     }
{ --------------------------------------------------------- }
{
function SkipR( var P; Offset, Size: Integer; C: Char ) : Integer;
var
  B: TByteArray absolute P;
begin
  while (Offset < Size) and (B[Offset] = Byte(C)) do Inc(Offset);
  Result := Offset;
end; { ScanR }
}

function SkipR( var P; Offset, Size: Integer; C: Char ): Integer; assembler;
        {&USES esi,edi} {&FRAME-}
asm
        cld
        mov     edi,P
        mov     edx, edi
        add     edi,&Offset
        mov     ecx,Size
        sub     ecx,&Offset
        mov     al,C
        repe    scasb
        jne     @@found
        mov     eax, Size
        jmp     @@exit
@@found:
        sub     edi, edx
        mov     eax, edi
        dec     eax
@@exit:
end;

{ --------------------------------------------------------- }
{ CharStr                                                   }
{ --------------------------------------------------------- }

function CharStr( C: Char; Len: Integer ) : String;
begin
  FillChar( Result[1], Len, C );
  Result[0] := Chr(Len);
end; { CharStr }


{ --------------------------------------------------------- }
{ PadCh                                                     }
{ --------------------------------------------------------- }

function PadCh( const S: String; Len: Integer; Ch: Char ) : String;
var
  d: Integer;
begin
  d := Len - Length(S);
  if d > 0 then
    Result := S + CharStr( Ch, d )
  else
    Result := Copy( S, 1, Len );
end; { PadCh }

{ --------------------------------------------------------- }
{ Pad                                                       }
{ --------------------------------------------------------- }

function Pad( const S: String; Len: Integer ) : String;
begin
  Result := PadCh( S, Len, ' ' );
end; { Pad }

{ --------------------------------------------------------- }
{ LeftPadCh                                                 }
{ --------------------------------------------------------- }

function LeftPadCh( const S: String; Len: Integer; Ch: Char ) : String;
var
  d: Integer;
begin
  d := Len - Length(S);
  if d > 0 then
    Result := CharStr( Ch, d ) + S
  else
    Result := Copy( S, 1, Len );
end; { LeftPadCh }

{ --------------------------------------------------------- }
{ LeftPad                                                   }
{ --------------------------------------------------------- }

function LeftPad( const S: String; Len: Integer ) : String;
begin
  Result := LeftPadCh( S, Len, ' ' );
end; { LeftPad }

{ --------------------------------------------------------- }
{ CenterCh                                                  }
{ --------------------------------------------------------- }

function CenterCh( const S : string; Width : Integer; Ch: Char ) : String;
var
  SLen : Byte absolute S;
  o : string;
begin
  if SLen >= Width then
    CenterCh := S
  else if SLen < 255 then
  begin
    o[0] := Chr(Width);
    FillChar(o[1], Width, Ch);
    Move(S[1], o[Succ((Width-SLen) shr 1)], SLen);
    CenterCh := o;
  end;
end; { CenterCh }

{ --------------------------------------------------------- }
{ Center                                                    }
{ --------------------------------------------------------- }

function Center( const S: String; Width: Integer ) : String;
begin
  Result := CenterCh( S, Width, ' ' );
end; { Center }

{ --------------------------------------------------------- }
{ StrSet                                                    }
{ --------------------------------------------------------- }

function StrSet( Ch: PChar; const S: String; Size: Integer ) : PChar;
begin
  FillChar( Ch[0], Size, 0 );
  if Size > Length(S) then
    Size := Length(S);
  Move( S[1], Ch[0], Size );
end; { StrSet }

{ --------------------------------------------------------- }
{ ExtractQuoted                                             }
{ --------------------------------------------------------- }

function ExtractQuoted( S: String ) : String;
var
  Start: Integer;
  Stop : Integer;
begin
  Start := 1;
  while (Start <= Length(S)) and (S[Start] <> '''') and (S[Start] <> '"') do
    Inc( Start );
  Result := GetLiterals( S, Start, Stop );
end; { ExtractQuoted }

{ --------------------------------------------------------- }
{ QuotedFile                                                }
{ --------------------------------------------------------- }

function QuotedFile( const S: String ) : String;
begin
  if Pos( ' ', S ) <> 0 then
    Result := '"' + S + '"'
  else
    Result := S;
end; { QuotedFile }

{ --------------------------------------------------------- }
{ SkipWhiteSpace                                            }
{ --------------------------------------------------------- }

procedure SkipWhiteSpace( S: String; var pos: Integer );
begin
  pos := SkipR( S[1], pos, Length(S), ' ' ) + 1;
end; { SkipWhiteSpace }

{ --------------------------------------------------------- }
{ GetLiterals                                               }
{ --------------------------------------------------------- }

function GetLiterals( S: String; Start: Integer; var Stop: Integer ) : String;
label
  Failure;
var
  ch: Char;
begin
  Result := '';
  Stop := Start;
  if Start > Length(S) then Exit;
  ch := S[Start];
  if (ch <> '''') and (ch <> '"') then goto Failure;
  Inc(Start);
  while Start <= Length(S) do
  begin
    if S[Start] <> ch then
      Result := Result + S[Start]
    else
    begin
      Inc(Start);
      if (Start <= Length(S)) and (S[Start] = ch) then
        Result := Result + ch
      else
      begin
        Stop := Start;
        Exit;
      end;
    end;
    Inc(Start);
  end;
Failure:
  raise Exception.Create( Format(LoadString(_SQuotedExpected), [S] ));
end; { GetLiterals }

{ --------------------------------------------------------- }
{ GetRightID                                                }
{ --------------------------------------------------------- }

function GetRightID( S: String; Start: Integer; var Stop: Integer ) : String;
begin
  Result := '';
  Stop := Start;
  if (Stop > Length(S)) or (S[Stop] < 'A') or (S[Stop] > 'z') then Exit;
  while S[Stop] in IDCHARS do Inc(Stop);
  Result := Copy( S, Start, Stop - Start );
end; { GetRightID }

{ --------------------------------------------------------- }
{ MakePrintable                                             }
{ --------------------------------------------------------- }

function MakePrintable( const S: String ) : String;
var
  j: Integer;
  n: Byte absolute Result;
begin
  n := 0;
  for j := 1 to Length(S) do
  begin
    if S[j] < #$20 then
    begin
      Inc(n);
      Result[n] := '^';
      Inc(n);
      Result[n] := Chr( Ord(S[j]) + $40 );
    end
    else
    begin
      Inc(n);
      Result[n] := S[j];
    end;
  end;
end; { MakePrintable }


{ --------------------------------------------------------- }
{ Destroy                                                   }
{ --------------------------------------------------------- }

procedure Destroy( O: PObject );
begin
  if O <> nil then
    Dispose( O, Done );
end; { Destroy }


{ --------------------------------------------------------- }
{ SetBit                                                    }
{ --------------------------------------------------------- }

procedure SetBit( var Where: Longint; Mask: Longint; Raised: Boolean );
begin
  if Raised then
    Where := Where or Mask
  else
    Where := Where and not Mask;
end; { SetBit }


{ --------------------------------------------------------- }
{ TestBit                                                   }
{ --------------------------------------------------------- }

function TestBit( Where, Mask: Longint ) : Boolean;
begin
  Result := (Where and Mask) <> 0;
end; { TestBit }


{ --------------------------------------------------------- }
{ Replace                                                   }
{ --------------------------------------------------------- }

function Replace( const S, What, Value: String ) : String;
var
  Start: Integer;
begin
  Result := S;
  Start := Pos( What, S );
  if Start <> 0 then
  begin
    Delete( Result, Start, Length(What) );
    Insert( Value, Result, Start );
  end;
end; { Replace }

{ --------------------------------------------------------- }
{ ASRF       Implements ASRF(tm) format                     }
{            ver 2.0 - 24-Oct-01                            }
{ --------------------------------------------------------- }

function ASRF( FSize: Double ) : String;
const
  KByte = Longint(1024);
  MByte = Longint(1024) * KByte;
  GByte = Longint(1024) * MByte;
begin
  if FSize < KByte then
    Result := Format( '%4dB', [Trunc(FSize)] )
  else if FSize < 10.0 * KByte then
    Result := Format( '%4.2fK', [FSize / KByte] )
  else if FSize < 100.0 * KByte then
    Result := Format( '%4.1fK', [FSize / KByte] )
  else if FSize < MByte then
    Result := Format( '%4dK', [Trunc(FSize / KByte)] )
  else if FSize < 10.0 * MByte then
    Result := Format( '%4.2fM', [FSize / MByte] )
  else if FSize < 100.0 * MByte then
    Result := Format( '%4.1fM', [FSize / MByte] )
  else if FSize < GByte then
    Result := Format( '%4dM', [Trunc(FSize / MByte)] )
  else if FSize < 10.0 * GByte then
    Result := Format( '%4.2fG', [FSize / GByte] )
  else
    Result := Format( '%4.1fG', [FSize / GByte] );
end; { ASRF }


{ --------------------------------------------------------- }
{ TStrings                                                  }
{ --------------------------------------------------------- }

{ FreeItem ------------------------------------------------ }

procedure TStrings.FreeItem( Item: Pointer );
begin
  FreeStr( PString(Item) );
end; { FreeItem }


{ --------------------------------------------------------- }
{ TNoCaseStrCollection                                      }
{ --------------------------------------------------------- }

{ FreeItem ------------------------------------------------ }

procedure TNoCaseStrCollection.FreeItem( Item: Pointer );
begin
  FreeStr( PString(Item) );
end; { FreeItem }

{ Compare ------------------------------------------------- }

function TNoCaseStrCollection.Compare( Key1, Key2: Pointer ) : Integer;
begin
  Result := JustCompareText( PString(Key1)^, PString(Key2)^ );
end; { Compare }


{ --------------------------------------------------------- }
{ DecodeLFN                                                 }
{ --------------------------------------------------------- }

procedure DecodeLFN( var R: TSearchRec; var ShortName, LongName: String );
var
  S: String;
begin
{$IFDEF WIN32}
  with R.FindData do
  begin
    if cAlternateFileName[0] = #0 then
    begin
      ShortName := StrPas(cFileName);
      LongName  := '';
    end
    else
    begin
      ShortName := StrPas(cAlternateFileName);
      LongName  := StrPas(cFileName);
    end;
  end;
{$ELSE}
  ShortName := R.Name;
  LongName  := '';
{$ENDIF}
  case Cfg.FileApi of
    fapi_primary_long:
      begin
        if LongName <> '' then
        begin
          S := LongName;
          LongName := ShortName;
          ShortName := S;
        end;
      end;

    fapi_native:
      begin
        if LongName <> '' then
        begin
          ShortName := LongName;
          LongName  := '';
        end;
      end;
  end;
end; { DecodeLFN }


{ --------------------------------------------------------- }
{ VFS_TouchFile                                             }
{ --------------------------------------------------------- }

function VFS_TouchFile( const FileName: String; Stamp: FileTime ) : Boolean;
var
  H: Integer;
begin
  H := FileOpen( FileName, fmOpenReadWrite OR fmShareExclusive );
  if H > 0 then
  begin
    Result := FileSetDate( H, Stamp ) = 0;
    FileClose( H );
  end
  else
    Result := False;
end; { VFS_TouchFile }

{ --------------------------------------------------------- }
{ VFS_EraseFile                                             }
{ --------------------------------------------------------- }

function VFS_EraseFile( const FileName: String ) : Boolean;
var
  Attr: Integer;
begin
  Result := False;
  Attr := FileGetAttr( FileName );
  if Attr = -1 then Exit;
  if TestBit( Attr, faReadOnly + faHidden ) then
  begin
    SetBit( Attr, faReadOnly + faHidden, False );
    FileSetAttr( FileName, Attr );
  end;
  Result := SysUtils.DeleteFile( FileName );
end; { VFS_EraseFile }

{ --------------------------------------------------------- }
{ VFS_RenameFile                                            }
{ --------------------------------------------------------- }

function VFS_RenameFile( const Source, Dest: String ) : Boolean;
begin
  Result := VFS_MoveFile( Source, Dest ) = 0;
end; { VFS_RenameFile }

{ --------------------------------------------------------- }
{ VFS_MoveFile                                              }
{ --------------------------------------------------------- }

function VFS_MoveFile( const Source, Target: String ) : Integer;
var
  s, d: array [0..256] of Char;
begin
  StrPCopy( s, ExpandFileName(Source) );
  StrPCopy( d, ExpandFileName(Target) );

  if StrIComp( s, d ) = 0 then
  begin
    Result := 0;
    Exit;
  end;

{$IFDEF Win32}
  OemToCharBuff( s, s, 256 );
  OemToCharBuff( d, d, 256 );
{$ENDIF}

  if SysFileExists( d ) then
    SysFileDelete( d );

  if UpCase( s[0] ) = UpCase( d[0] ) then
    Result := SysFileMove( s, d )
  else
  begin
    if SysFileCopy( s, d, True ) then
      Result := SysFileDelete( s )
    else
      Result := 1;
  end;
end; { VFS_MoveFile }

{ --------------------------------------------------------- }
{ VFS_CopyFile                                              }
{ --------------------------------------------------------- }

function VFS_CopyFile( const Source, Target: String ) : Boolean;
var
  s, d: array [0..256] of Char;
begin
{$IFDEF Win32}
  StrPCopy( s, Source );
  OemToCharBuff( s, s, 256 );

  StrPCopy( d, Target );
  OemToCharBuff( d, d, 256 );

  Result := SysFileCopy( s, d, True );
{$ELSE}
  Result := SysFileCopy( StrPCopy(s, Source), StrPCopy(d, Target), True );
{$ENDIF}
end; { VFS_CopyFile }

{ --------------------------------------------------------- }
{ VFS_GetShortName                                          }
{ --------------------------------------------------------- }

{$IFDEF Win32}
function VFS_GetShortName( Source: String; var Target: String ) : Boolean;
var
  s, d: array [0..256] of Char;
begin
  Result := False;
  StrPCopy( s, Source );
  OemToCharBuff( s, s, 256 );
  if GetShortPathName( s, d, 256 ) <> 0 then
  begin
    CharToOemBuff( d, d, 256 );
    Target := ExtractFileName( StrPas( d ) );
    Source := ExtractFileName( Source );
    Result := not JustSameText( Source, Target );
  end;
end; { VFS_GetShortName }
{$ENDIF}


{ --------------------------------------------------------- }
{ VFS_ValidatePath                                          }
{ --------------------------------------------------------- }

function VFS_ValidatePath( const Source: String ) : String;
{$IFDEF Win32}
var
  s, d: array [0..256] of Char;
begin
  if Cfg.FileApi = fapi_primary_short then
  begin
    StrPCopy( s, Source );
    OemToCharBuff( s, s, 256 );
    GetShortPathName( s, d, 256 );
    CharToOemBuff( d, d, 256 );
    Result := StrPas( d );
  end
  else
    Result := Source;
{$ELSE}
begin
  Result := Source;
{$ENDIF}
end; { VFS_ValidatePath }


{ --------------------------------------------------------- }
{ VFS_BackupFile                                            }
{ --------------------------------------------------------- }

procedure VFS_BackupFile( const FileName: String; Level: Integer );

  procedure DoBackup( const Me: String; Deep: Integer );
  var
    Bak: String;
  begin
    Bak := ChangeFileExt( Me, '.ba' + Chr( Ord('0') + Deep ) );
    if FileExists( Bak ) then
    begin
      if Deep < Level then
        DoBackup( Bak, Deep + 1 )
      else
        VFS_EraseFile( Bak );
    end;
    VFS_RenameFile( Me, Bak );
  end; { DoBackup }

begin
  if (Level > 0) and FileExists( FileName ) then
    DoBackup( FileName, 1 );
end; { Backup }



end.
