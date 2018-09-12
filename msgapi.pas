unit MsgAPI;

/////////////////////////////////////////////////////////////////////
//
// Hi-Files Version 2
// Copyright (c) 1997-2004 Dmitry Liman [2:461/79]
//
// http://hi-files.narod.ru
//
/////////////////////////////////////////////////////////////////////

{$IFDEF Win32}
  {$DEFINE USE_FILE_MAPPING}
{$ENDIF}

interface

uses Objects, MyLib;

type
  SWORD = SmallWord;
  DWORD = Word;

  PAddress = ^TAddress;
  TAddress = record
    Zone, Net, Node, Point: SWORD;
  end; { TAddress }

const
   // FTS-0001 attribute flags
   ATTR_PRIVATE  = $0001;        // Private
   ATTR_CRASH    = $0002;        // Crash (high-priority mail)
   ATTR_RECVD    = $0004;        // Received
   ATTR_SENT     = $0008;        // Sent
   ATTR_FILEATT  = $0010;        // File attach
   ATTR_TRANSIT  = $0020;        // Transit
   ATTR_ORPHAN   = $0040;        // Orphan
   ATTR_KILLSENT = $0080;        // Kill/Sent
   ATTR_LOCAL    = $0100;        // Local
   ATTR_HOLD     = $0200;        // Hold
   ATTR_UNUSED   = $0400;        // Unused !!!
   ATTR_FREQ     = $0800;        // File request
   ATTR_RRQ      = $1000;        // Receipt request
   ATTR_RRC      = $2000;        // Is return receipt
   ATTR_ARQ      = $4000;        // Audit request
   ATTR_URQ      = $8000;        // Update request

   // Extended attribute flags (used in FLAGS kludge)
   ATTR_ARCSENT   = $00010000;   // Archive/Sent
   ATTR_DIR       = $00020000;   // Direct
   ATTR_ZONEGATE  = $00040000;   // Zonegate
   ATTR_HUB       = $00080000;   // Host/Hub routing
   ATTR_IMM       = $00100000;   // Immediate
   ATTR_XMAIL     = $00200000;   // Compressed mail attached
   ATTR_TRUNCSENT = $00400000;   // Truncate file sent
   ATTR_LOCK      = $00800000;   // Locked
   ATTR_CFM       = $01000000;   // Confirm request
   ATTR_FPU       = $02000000;   // Force pickup

const
  MAX_MSG_COUNT = 1000;

function AddrToStr( A: TAddress ) : String;
function AddrToShortStr( A, Default: TAddress ) : String;
function StrToAddr( const S: String ) : TAddress;
function StrToAddrDef( const S: String; Default: TAddress ) : TAddress;
function SafeAddr( const S: String; var A: TAddress ) : Boolean;
function MakeAddr( Zone, Net, Node, Point: SWORD ) : TAddress;
function CompAddr( const A1, A2: TAddress ) : Integer;
function NewAddr( const A: TAddress ) : PAddress;

function MakePktName( const Where: String ) : String;

function AttrStr( Attr: DWORD ) : String;

function ParseMsgDate( const S: String ) : UnixTime;
function MsgDateStr( U: UnixTime ) : String;

type
  PBasicMessage = ^TBasicMessage;
  TBasicMessage = object (TStrings)
    constructor Init;

    function GetArea : String;
    function GetFrom : String;
    function GetTo   : String;
    function GetOrig : TAddress;
    function GetDest : TAddress;
    function GetAttr : DWORD;
    function GetDate : UnixTime;
    function GetSubj : String;
    function GetMsgId: String;
    function GetReply: String;
    function GetFlags: String;
    function EchoMail: Boolean;

    procedure SetArea ( const S: String );
    procedure SetFrom ( const S: String );
    procedure SetTo   ( const S: String );
    procedure SetOrig ( A: TAddress );
    procedure SetDest ( A: TAddress );
    procedure SetAttr ( A: DWORD );
    procedure SetDate ( D: UnixTime );
    procedure SetSubj ( const S: String );
    procedure SetMsgId( const S: String );
    procedure SetReply( const S: String );
    procedure SetFlags( const S: String );
    procedure SetPID  ( const S: String );

    procedure BinSave( var bin: TStream );
    procedure Change;
    function  Changed: Boolean; virtual;
    procedure Append( const S: String );

  protected
    function  CheckKludge( const S: String ) : Boolean;
    procedure ParseFlags( const S: String );
    procedure SaveBinHeader( var bin: TStream ); virtual;

  protected
    _From: String;
    _To  : String;
    Orig : TAddress;
    Dest : TAddress;
    Subj : String;
    Date : UnixTime;
    Area : String;
    MsgID: String;
    Reply: String;
    PID  : String;
    Flags: String;
    Attr : DWORD;
  end; { TBasicMessage }


  PPacket = ^TPacket;


  PPackedMessage = ^TPackedMessage;
  TPackedMessage = object (TBasicMessage)
    constructor Init;
{$IFDEF USE_FILE_MAPPING}
    constructor Load( var pkt: PChar );
{$ELSE}
    constructor Load( var Pkt: TStream );
{$ENDIF}
    destructor Kill; virtual;

    procedure Change; virtual;
    function  Changed: Boolean; virtual;
    procedure SetOwner( Pkt: PPacket );

  protected
    procedure SaveBinHeader( var bin: TStream ); virtual;

  private
    Owner: PPacket;
  end; { TPackedMessage }


  TPacket = object (TCollection)
    constructor Init( OrigAddr, DestAddr: TAddress; const Where: String );
    constructor Load( const PktName: String );
    function GetDate: UnixTime;
    function GetPassword: String;

    procedure SetDate( D: UnixTime );
    procedure SetPassword( const S: String );

    procedure Save;

    procedure AddMessage( M: PPackedMessage );
    procedure DelMessage( M: PPackedMessage );

    procedure Change;
    function  Changed: Boolean;

  private
    Modified: Boolean;
    FileName: String;
    Orig    : TAddress;
    Dest    : TAddress;
    Date    : UnixTime;
    Password: String;
  end; { TPacket }


  PNetmailMessage = ^TNetmailMessage;
  TNetmailMessage = object (TBasicMessage)
    constructor Init( const Pattern: String );
    constructor Load( const MsgName: String );

    procedure Kill;
    procedure Change; virtual;
    function  Changed: Boolean; virtual;

    procedure Save;

  protected
    procedure SaveBinHeader( var bin: TStream ); virtual;

  private
    FileName: String;
    Modified: Boolean;
  end; { TNetmailMessage }

  PMsgTable = ^TMsgTable;
  TMsgTable = array [1..MAX_MSG_COUNT] of Boolean;

  PMsgBase = ^TMsgBase;
  TMsgBase = object (TObject)
    constructor Init( const MsgBasePath: String );
    destructor Done; virtual;
    procedure SetPID( const MyPID: String );
    procedure Rescan;
    procedure SeekFirst;
    procedure SeekNext;
    function SeekFound: Boolean;
    function GetMessage: PNetmailMessage;
    function NewMessage: PNetmailMessage;
  private
    MsgPath : String;
    MsgTable: PMsgTable;
    MsgIndex: Integer;
    PID     : String;
  end; { TMsgBase }

const
  DefAddr   : TAddress = (Zone: 0; Net: 0; Node: 0; Point: 0);
  ZERO_ADDR : TAddress = (Zone: 0; Net: 0; Node: 0; Point: 0);
  EMPTY_ADDR: TAddress = (Zone: SWORD(-1); Net: SWORD(-1); Node: SWORD(-1); Point: SWORD(-1));

const
  NETMAIL_AREA = 'Netmail';

{ =================================================================== }

implementation

uses
{$IFDEF USE_FILE_MAPPING}
  Windows,
{$ENDIF}
  SysUtils, _CRC32, Dos, _LOG;

const
  ATTR_FLAGS_COUNT = 26;
  AttrFlag: array [0..Pred(ATTR_FLAGS_COUNT)] of String[3] = (
    'PVT', 'CRA', 'RCV', 'SNT', 'FIL', 'TRS', 'ORP', 'K/S',
    'LOC', 'HLD', 'UNU', 'FRQ', 'RRQ', 'RRC', 'ARQ', 'URQ',
    'A/S', 'DIR', 'ZON', 'HUB', 'IMM', 'XMA', 'TFS', 'LOK',
    'CFM', 'FPU' );

  ORIGIN  = ' * Origin:';

  LF = #10;
  CR = #13;

const
  STREAM_BUFFER_SIZE = 4096;

{ --------------------------------------------------------- }
{ MakeAddr                                                  }
{ --------------------------------------------------------- }

function MakeAddr( Zone, Net, Node, Point: SWORD ) : TAddress;
begin
  Result.Zone  := Zone;
  Result.Net   := Net;
  Result.Node  := Node;
  Result.Point := Point;
end; { MakeAddr }

{ --------------------------------------------------------- }
{ AddrToStr                                                 }
{ --------------------------------------------------------- }

function AddrToStr( A: TAddress ) : String;
begin
  with A do
  begin
    Result := IntToStr(Zone) + ':' + IntToStr(Net) + '/' + IntToStr(Node);
    if Point <> 0 then
      Result := Result + '.' + IntToStr(Point);
  end;
end; { AddrToStr }

{ --------------------------------------------------------- }
{ AddrToShortStr                                            }
{ --------------------------------------------------------- }

function AddrToShortStr( A, Default: TAddress ) : String;
var
  S: String;
begin
  S := '';
  if A.Zone <> Default.Zone then
    S := IntToStr( A.Zone ) + ':'
       + IntToStr( A.Net )  + '/'
       + IntToStr( A.Node )
  else if A.Net <> Default.Net then
    S := IntToStr( A.Net ) + '/'
       + IntToStr( A.Node )
  else if A.Node <> Default.Node then
    S := IntToStr( A.Node );

  if A.Point <> 0 then
    S := S + '.' + IntToStr( A.Point );

  Result := S;

end; { AddrToShortStr }

{ --------------------------------------------------------- }
{ StrToAddrDef                                              }
{ --------------------------------------------------------- }

//      zone:net/node[.point]      (1)
//      net/node[.point]           (2)
//      [/]node[.point][@domain]   (3)
//      .point[@domain]            (4)

function StrToAddrDef( const S: String; Default: TAddress ) : TAddress;
var
  A: TAddress;

  function SkipDigits( Start: Integer ) : Integer;
  const
    DIGITS = ['0'..'9'];
  begin
    Result := Start;
    while (Result <= Length(S)) and (S[Result] in DIGITS) do Inc(Result);
  end;

  function atoi( Start: Integer; var Stop: Integer ) : Integer;
  begin
    Stop := SkipDigits( Start );
    Result := StrToInt( Copy( S, Start, Stop - Start ) );
  end;

  procedure case_4( Start: Integer );
  var
    Stop: Integer;
  begin
    Inc( Start );
    A.Point := atoi( Start, Stop );
    if (Stop <= Length(S)) and (S[Stop] <> '@') then
      raise Exception.Create('');
  end;

  procedure case_3( Start: Integer );
  var
    Stop: Integer;
  begin
    if S[Start] = '/' then
      Inc(Start);
    A.Node := atoi( Start, Stop );
    if Stop <= Length(S) then
    begin
      if S[Stop] = '.' then
        case_4( Stop )
      else if S[Stop] = '@' then
        Exit
      else
        raise Exception.Create('');
    end;
  end;

  procedure case_2( Start: Integer );
  var
    Stop: Integer;
  begin
    A.Net := atoi( Start, Stop );
    if (Stop > Length(S)) or (S[Stop] <> '/') then
      raise Exception.Create('');
    case_3( Stop );
  end;

  procedure case_1;
  var
    Stop: Integer;
  begin
    A.Zone := atoi( 1, Stop );
    case_2( Stop + 1 );
  end;

var
  j: Integer;
begin
  try
    if S = '' then
      raise Exception.Create('');
    A := Default;
    A.Point := 0;
    if S[1] = '/' then
      case_3( 1 )
    else if S[1] = '.' then
      case_4( 1 )
    else
    begin
      j := SkipDigits( 1 );
      if (j > Length(S)) or (S[j] = '.') then
        case_3( 1 )
      else if S[j] = ':' then
        case_1
      else if S[j] = '/' then
        case_2( 1 )
      else
        raise Exception.Create('');
    end;
  except
    raise EConvertError.Create( 'MsgAPI: Bad FTN-addr "' + S + '"' );
  end;
  Result := A;
end; { StrToAddrDef }

{ --------------------------------------------------------- }
{ StrToAddr                                                 }
{ --------------------------------------------------------- }

function StrToAddr( const S: String ) : TAddress;
begin
  Result := StrToAddrDef( S, DefAddr );
end; { StrToAddr }

{ --------------------------------------------------------- }
{ SafeAddr                                                  }
{ --------------------------------------------------------- }

function SafeAddr( const S: String; var A: TAddress ) : Boolean;
begin
  Result := True;
  try
    A := StrToAddr( S );
  except
    Result := False;
  end;
end; { SafeAddr }

{ --------------------------------------------------------- }
{ CompAddr                                                  }
{ --------------------------------------------------------- }

function CompAddr( const A1, A2: TAddress ) : Integer;
begin
  if A1.Zone < A2.Zone then
    Result := -1
  else if A1.Zone > A2.Zone then
    Result := 1
  else if A1.Net < A2.Net then
    Result := -1
  else if A1.Net > A2.Net then
    Result := 1
  else if A1.Node < A2.Node then
    Result := -1
  else if A1.Node > A2.Node then
    Result := 1
  else if A1.Point < A2.Point then
    Result := -1
  else if A1.Point > A2.Point then
    Result := 1
  else
    Result := 0;
end; { CompAddr }

{ --------------------------------------------------------- }
{ NewAddr                                                   }
{ --------------------------------------------------------- }

function NewAddr( const A: TAddress ) : PAddress;
begin
  New( Result );
  Result^ := A;
end; { NewAddr }


{ --------------------------------------------------------- }
{ MakePktName                                               }
{ --------------------------------------------------------- }

function MakePktName( const Where: String ) : String;
var
  hash: Longint;
begin
  hash := (CurrentUnixTime shl 8) or
          (SysSysMsCount and $FFFF);
  Result := LowerCase( AtPath( Format( '%p', [Pointer(hash)] ) + '.pkt', Where ) );
end; { MakePktName }

{ --------------------------------------------------------- }
{ StripExtendedAttr                                         }
{ --------------------------------------------------------- }

function StripExtendedAttr( Attr: DWORD ) : DWORD;
begin
  Result := (Attr and $FFFF);
end; { StripExtendedAttr }

{ --------------------------------------------------------- }
{ StripFTS1Attr                                             }
{ --------------------------------------------------------- }

function StripFTS1Attr( Attr: DWORD ) : DWORD;
begin
  Result := (Attr and $FFFF0000);
end; { StripFTSAttr1 }

{ --------------------------------------------------------- }
{ StripNetmailAttr                                          }
{ --------------------------------------------------------- }

const
  ECHOMAIL_ATTR_MASK = ATTR_LOCAL + ATTR_LOCK;

function StripNetmailAttr( Attr: DWORD ) : DWORD;
begin
  Result := (Attr and ECHOMAIL_ATTR_MASK);
end; { StripNetmailAttr }

{ --------------------------------------------------------- }
{ AttrStr                                                   }
{ --------------------------------------------------------- }

function AttrStr( Attr: DWORD ) : String;
var
  j: Integer;
begin
  Result := '';
  for j := 0 to Pred(ATTR_FLAGS_COUNT) do
    if TestBit( Attr, 1 shl j ) then
      Result := Result + AttrFlag[j] + ' ';
  Result := TrimRight(Result);
end; { AttrStr }

{ --------------------------------------------------------- }
{ WhatsAttr                                                 }
{ --------------------------------------------------------- }

function WhatsAttr( const S: String ) : DWORD;
var
  j: Integer;
begin
  for j := 0 to Pred(ATTR_FLAGS_COUNT) do
    if JustSameText( S, AttrFlag[j] ) then
    begin
      Result := (1 shl j);
      Exit;
    end;
  Result := 0;
end; { WhatsAttr }

{ --------------------------------------------------------- }
{ FlagsStr                                                  }
{ --------------------------------------------------------- }

function FlagsStr( Attr: DWORD; const Flags: String ) : String;
begin
  Result := AttrStr( Attr );
  if Result <> '' then
    Result := Result + ' ';
  Result := Result + Flags;
end; { FlagsStr }

{ --------------------------------------------------------- }
{ GenMsgID                                                  }
{ --------------------------------------------------------- }

function GenMsgID( var A: TAddress ) : String;
var
  S: String;
  crc: Longint;
begin
  S := DateTimeToStr( Now ) + IntToStr( Random(9999) );
  crc := GetStrCRC( S );
  Result := AddrToStr( A ) + ' ' + Format( '%p', [Pointer(crc)] );
end; { GenMsgID }

{ --------------------------------------------------------- }
{ ParseMsgDate                                              }
{ --------------------------------------------------------- }

//      1234567890123456789
//      dd mmm yy  hh:mm:ss

function ParseMsgDate( const S: String ) : UnixTime;

  function Month( const S: String ) : Integer;
  var
    j: Integer;
  begin
    for j := 1 to 12 do
      if JustSameText( S, MonthName[j] ) then
      begin
        Result := j;
        Exit;
      end;
    raise Exception.Create( 'MsgAPI: invalid month' );
  end; { Month }

var
  D: DateTime;
  T: Longint;
begin
  if Length(S) <> 19 then
    raise Exception.Create( 'MsgAPI: bad date' );
  D.Day   := StrToInt( Copy(S, 1, 2) );
  D.Month := Month( Copy(S, 4, 3) );
  D.Year  := StrToInt( Copy(S,  8, 2) );
  D.Hour  := StrToInt( Copy(S, 12, 2) );
  D.Min   := StrToInt( Copy(S, 15, 2) );
  D.Sec   := StrToInt( Copy(S, 18, 2) );
  if D.Year < 30 then
    Inc(D.Year, 2000)
  else
    Inc(D.Year, 1900);
  PackTime( D, T );
  Result := FileTimeToUnix( T );
end; { ParseMsgDate }

{ --------------------------------------------------------- }
{ MsgDateStr                                                }
{ --------------------------------------------------------- }

function MsgDateStr( U: UnixTime ) : String;
var
  D: DateTime;
begin
  UnpackTime( UnixTimeToFile(U), D );
  Dec( D.Year, 1900 );
  if D.Year >= 100 then Dec( D.Year, 100 );
  Result := Format( '%2.2d %3s %2.2d  %2.2d:%2.2d:%2.2d',
    [D.Day, MonthName[D.Month], D.Year, D.Hour, D.Min, D.Sec] );
end; { MsgDateStr }

{ --------------------------------------------------------- }
{ WriteStr                                                  }
{ --------------------------------------------------------- }

procedure WriteStr( var Stream: TStream; S: String; Term: Char );
begin
  Stream.Write( S[1], Length(S) );
  Stream.Write( Term, 1 );
end; { WriteStr }

{ --------------------------------------------------------- }
{ TBasicMessage                                             }
{ --------------------------------------------------------- }

{ Init ---------------------------------------------------- }

constructor TBasicMessage.Init;
begin
  inherited Init(50, 50);
  Date := CurrentUnixTime;
end; { Init }

{ CheckKludge --------------------------------------------- }

function TBasicMessage.CheckKludge( const S: String ) : Boolean;
var
  Kludge: String;
  Value : String;
  left  : Integer;
  right : Integer;
  A: TAddress;
begin
  if S = '' then
  begin
    Result := False;
    Exit;
  end;
  Result := True;
  if S[1] = ^A then
  begin
    SplitPair( S, Kludge, Value );
    System.Delete( Kludge, 1, 1 );
    if JustSameText( Kludge, 'MSGID:' ) then
    begin
      MsgID := Value;
      Exit;
    end;
    if JustSameText( Kludge, 'INTL' ) then
    begin
      if SafeAddr( ExtractWord( 1, Value, BLANK ), A ) then
        Dest.Zone := A.Zone;
      if SafeAddr( ExtractWord( 2, Value, BLANK ), A ) then
        Orig.Zone := A.Zone;
      Exit;
    end;
    if JustSameText( Kludge, 'FMPT' ) then
    begin
      Orig.Point := StrToInt( Value );
      Exit;
    end;
    if JustSameText( Kludge, 'TOPT' ) then
    begin
      Dest.Point := StrToInt( Value );
      Exit;
    end;
    if JustSameText( Kludge, 'REPLY:' ) then
    begin
      Reply := Value;
      Exit;
    end;
    if JustSameText( Kludge, 'PID:' ) then
    begin
      PID := Value;
      Exit;
    end;
    if JustSameText( Kludge, 'FLAGS' ) then
    begin
      ParseFlags( Value );
      Exit;
    end;
  end
  else if EchoMail then
  begin
    if (Pos( ORIGIN, S ) = 1) and (Orig.Zone = 0) then
    begin
      left  := Pos( '(', S );
      right := Pos( ')', S );
      if (left * right <> 0) and (left < right) then
      begin
        Value := Copy( S, Succ(left), Pred(right - left) );
        if SafeAddr( Value, A ) then
          Orig := A;
      end;
    end;
  end;
  Result := False;
end; { CheckKludge }

{ ParseFlags ---------------------------------------------- }

procedure TBasicMessage.ParseFlags( const S: String );
var
  j: Integer;
  n: Integer;
  a: DWORD;
  f: String;
begin
  Flags := '';
  n := WordCount( S, BLANK );
  for j := 1 to n do
  begin
    f := ExtractWord( j, S, BLANK );
    a := WhatsAttr( f );
    if a <> 0 then
      SetBit( Attr, A, True )
    else
      Flags := Flags + f + ' ';
  end;
  Flags := TrimRight( Flags );
end; { ParseFlags }

{ BinSave ------------------------------------------------- }

procedure TBasicMessage.BinSave( var bin: TStream );
const
  ZERO: Byte = 0;
var
  f: String;
  ea: DWORD;
  OrigNode: TAddress;
  DestNode: TAddress;

  procedure WriteLine( P: PString ); far;
  begin
    WriteStr( bin, P^, CR );
  end; { WriteLine }

begin
  SaveBinHeader( bin );
  if EchoMail then
    WriteStr( bin, 'AREA:' + Area, CR );
  if MsgID <> '' then
    WriteStr( bin, ^A'MSGID: ' + MsgID, CR );
  if Reply <> '' then
    WriteStr( bin, ^A'REPLY: ' + Reply, CR );

  ea := StripFTS1Attr( Attr );

  if EchoMail then
    ea := StripNetmailAttr( ea )
  else
  begin
    DestNode := Dest;
    OrigNode := Orig;
    DestNode.Point := 0;
    OrigNode.Point := 0;
    WriteStr( bin, ^A'INTL ' + AddrToStr(DestNode) + ' ' + AddrToStr(OrigNode), CR);
    if Orig.Point <> 0 then
      WriteStr( bin, ^A'FMPT ' + IntToStr(Orig.Point), CR );
    if Dest.Point <> 0 then
      WriteStr( bin, ^A'TOPT ' + IntToStr(Dest.Point), CR );
  end;

  f := FlagsStr( ea, Flags );
  if f <> '' then
    WriteStr( bin, ^A'FLAGS ' + f, CR);

  if PID <> '' then
    WriteStr( bin, ^A'PID: ' + PID, CR );

  ForEach( @WriteLine );
  bin.Write( ZERO, 1 );
end; { BinSave }

{ EchoMail ------------------------------------------------ }

function TBasicMessage.EchoMail: Boolean;
begin
  Result := (Area <> '');
end; { EchoMail }

{ GetArea ------------------------------------------------- }

function TBasicMessage.GetArea: String;
begin
  if Area = '' then
    Result := NETMAIL_AREA
  else
    Result := Area;
end; { GetArea }

{ GetFrom ------------------------------------------------- }

function TBasicMessage.GetFrom: String;
begin
  Result := _From;
end; { GetFrom }

{ GetTo --------------------------------------------------- }

function TBasicMessage.GetTo: String;
begin
  Result := _To;
end; { GetTo }

{ GetOrig ------------------------------------------------- }

function TBasicMessage.GetOrig: TAddress;
begin
  Result := Orig;
end; { GetOrig }

{ GetDest ------------------------------------------------- }

function TBasicMessage.GetDest: TAddress;
begin
  Result := Dest;
end; { GetDest }

{ GetAttr ------------------------------------------------- }

function TBasicMessage.GetAttr: DWORD;
begin
  Result := Attr;
end; { GetAttr }

{ GetDate ------------------------------------------------- }

function TBasicMessage.GetDate: UnixTime;
begin
  Result := Date;
end; { GetDate }

{ GetSubj ------------------------------------------------- }

function TBasicMessage.GetSubj: String;
begin
  Result := Subj;
end; { GetSubj }

{ GetMsgID ------------------------------------------------ }

function TBasicMessage.GetMsgID: String;
begin
  Result := MsgID;
end; { GetMsgID }

{ GetReply ------------------------------------------------ }

function TBasicMessage.GetReply: String;
begin
  Result := Reply;
end; { GetReply }

{ GetFlags ------------------------------------------------ }

function TBasicMessage.GetFlags: String;
begin
  Result := Flags;
end; { GetFlags }

{ SetArea ------------------------------------------------- }

procedure TBasicMessage.SetArea( const S: String );
begin
  if JustSameText( S, NETMAIL_AREA ) then
    Area := ''
  else
    Area := S;
  Change;
end; { SetArea }

{ SetFrom ------------------------------------------------- }

procedure TBasicMessage.SetFrom( const S: String );
begin
  _From := S;
  Change;
end; { SetFrom }

{ SetTo --------------------------------------------------- }

procedure TBasicMessage.SetTo( const S: String );
begin
  _To := S;
  Change;
end; { SetTo }

{ SetOrig ------------------------------------------------- }

procedure TBasicMessage.SetOrig( A: TAddress );
begin
  MsgID := GenMsgID( A );
  Orig  := A;
  Change;
end; { SetOrig }

{ SetDest ------------------------------------------------- }

procedure TBasicMessage.SetDest( A: TAddress );
begin
  Dest := A;
  Change;
end; { SetDest }

{ SetAttr ------------------------------------------------- }

procedure TBasicMessage.SetAttr( A: DWORD );
begin
  Attr := A;
  Change;
end; { SetAttr }

{ SetDate ------------------------------------------------- }

procedure TBasicMessage.SetDate( D: UnixTime );
begin
  Date := D;
  Change;
end; { SetDate }

{ SetSubj ------------------------------------------------- }

procedure TBasicMessage.SetSubj( const S: String );
begin
  Subj := S;
  Change;
end; { SetSubj }

{ SetMsgID ------------------------------------------------ }

procedure TBasicMessage.SetMsgID( const S: String );
begin
  MsgID := S;
  Change;
end; { SetMsgID }

{ SetReply ------------------------------------------------ }

procedure TBasicMessage.SetReply( const S: String );
begin
  Reply := S;
  Change;
end; { SetReply }

{ SetFlags ------------------------------------------------ }

procedure TBasicMessage.SetFlags( const S: String );
begin
  Flags := S;
  Change;
end; { SetFlags }

{ SetPID -------------------------------------------------- }

procedure TBasicMessage.SetPID( const S: String );
begin
  PID := S;
  Change;
end; { SetPID }

{ Change -------------------------------------------------- }

procedure TBasicMessage.Change;
begin
end; { Change }

{ Changed ------------------------------------------------- }

function TBasicMessage.Changed: Boolean;
begin
  Result := False;
end; { Changed }

{ SaveBinHeader ------------------------------------------- }

procedure TBasicMessage.SaveBinHeader( var bin: TStream );
begin
end; { SaveBinHeader }

{ Append -------------------------------------------------- }

procedure TBasicMessage.Append( const S: String );
begin
  Insert( AllocStr(S) );
end; { Append }


{ --------------------------------------------------------- }
{ TPackedMessage                                            }
{ --------------------------------------------------------- }

type
  PPackedMessageHeader = ^TPackedMessageHeader;
  TPackedMessageHeader = packed record
    Version : SWORD;
    OrigNode: SWORD;
    DestNode: SWORD;
    OrigNet : SWORD;
    DestNet : SWORD;
    Attr    : SWORD;
    Cost    : SWORD;
  end; { TPackedMessageHeader }

{ Init ---------------------------------------------------- }

constructor TPackedMessage.Init;
begin
  inherited Init;
end; { Init }

{$IFDEF USE_FILE_MAPPING}

{ PktGetStr ----------------------------------------------- }

function PktGetStr( var Buffer: PChar; Term: Char ) : String;
var
  P: PChar;
begin
  P := Buffer;
  Buffer := StrScan( Buffer, Term );
  if (Buffer <> nil) and (Buffer[0] = CR) and (Buffer[1] = LF) then
    Inc(Buffer);
  Result[0] := Chr( Buffer - P );
  Inc(Buffer);
  Move( P[0], Result[1], Ord(Result[0]) );
end; { PktGetStr }

{ Load ---------------------------------------------------- }

constructor TPackedMessage.Load( var pkt: PChar );
var
  A: TAddress;
  S: String;
  Header: PPackedMessageHeader;
begin
  inherited Init;
  Header := PPackedMessageHeader( pkt );

  Attr      := Header^.Attr;
  Orig.Net  := Header^.OrigNet;
  Orig.Node := Header^.OrigNode;
  Dest.Net  := Header^.DestNet;
  Dest.Node := Header^.DestNode;
  Inc( pkt, SizeOf(TPackedMessageHeader) );
  try
    Date := ParseMsgDate( PktGetStr( pkt, #0 ) );
  except
    Date := CurrentUnixTime;
  end;
  _To   := PktGetStr( pkt, #0 );
  _From := PktGetStr( pkt, #0 );
  Subj  := PktGetStr( pkt, #0 );
  if StrLIComp( pkt, 'AREA:', 5 ) = 0 then
    Area := Copy( PktGetStr( pkt, CR ), 6, 255 );
  while pkt[0] <> #0 do
  begin
    S := PktGetStr( pkt, CR );
    if not CheckKludge( S ) then
      Insert( AllocStr(S) );
  end;
  Inc( pkt );
  if Orig.Zone = 0 then
  begin
    if SafeAddr( ExtractWord( 1, MsgID, BLANK ), A ) then
      Orig.Zone := A.Zone;
    if Orig.Zone = 0 then
      Orig.Zone := DefAddr.Zone;
  end;
  if Dest.Zone = 0 then
    Dest.Zone := Orig.Zone;
end; { Load }

{$ELSE}

{ PktGetStr ----------------------------------------------- }

function PktGetStr( var Stream: TStream; Term: Char ) : String;
var
  C: Char;
  S: String;
  L: Byte absolute S;
begin
  L := 0;
  Stream.Read( C, 1 );
  while C <> Term do
  begin
    Inc( L );
    S[L] := C;
    Stream.Read( C, 1 );
  end;
  if Term = CR then
  begin
    Stream.Read( C, 1 );
    if C <> LF then
      Stream.Seek( Pred(Stream.GetPos) );
  end;
  Result := S;
end; { PktGetStr }

{ Load ---------------------------------------------------- }

constructor TPackedMessage.Load( var Pkt: TStream );
var
  A: TAddress;
  S: String;
  p: Longint;
  t: Char;
  Header: TPackedMessageHeader;
begin
  inherited Init;

  Pkt.Read( Header, SizeOf(Header) );

  Attr      := Header.Attr;
  Orig.Net  := Header.OrigNet;
  Orig.Node := Header.OrigNode;
  Dest.Net  := Header.DestNet;
  Dest.Node := Header.DestNode;
  try
    Date := ParseMsgDate( PktGetStr( Pkt, #0 ) );
  except
    Date := CurrentUnixTime;
  end;
  _To   := PktGetStr( pkt, #0 );
  _From := PktGetStr( pkt, #0 );
  Subj  := PktGetStr( pkt, #0 );
  p := Pkt.GetPos;
  S := PktGetStr( Pkt, CR );
  if Pos( 'AREA:', S ) = 1 then
    Area := Copy( S, 6, 255 )
  else
    Pkt.Seek( p );

  Pkt.Read( t, 1 );
  while t <> #0 do
  begin
    Pkt.Seek( Pred(Pkt.GetPos) );
    S := PktGetStr( pkt, CR );
    if not CheckKludge( S ) then
      Insert( AllocStr(S) );
    Pkt.Read( t, 1 );
  end;
  if Orig.Zone = 0 then
  begin
    if SafeAddr( ExtractWord( 1, MsgID, BLANK ), A ) then
      Orig.Zone := A.Zone;
    if Orig.Zone = 0 then
      Orig.Zone := DefAddr.Zone;
  end;
  if Dest.Zone = 0 then
    Dest.Zone := Orig.Zone;
end; { Load }

{$ENDIF}

{ SaveBinHeader ------------------------------------------- }

procedure TPackedMessage.SaveBinHeader( var bin: TStream );
var
  Header: TPackedMessageHeader;
begin
  FillChar( Header, SizeOf(Header), #0 );
  Header.Version  := 2;
  Header.OrigNode := Orig.Node;
  Header.DestNode := Dest.Node;
  Header.OrigNet  := Orig.Net;
  Header.DestNet  := Dest.Net;
  if EchoMail then
    Header.Attr := StripExtendedAttr( StripNetmailAttr(Attr) )
  else
    Header.Attr := StripExtendedAttr( Attr );
  bin.Write( Header, SizeOf(Header) );
  WriteStr( bin, MsgDateStr(Date), #0 );
  WriteStr( bin, _To,   #0 );
  WriteStr( bin, _From, #0 );
  WriteStr( bin, Subj,  #0 );
end; { SaveBinHeader }

{ Change -------------------------------------------------- }

procedure TPackedMessage.Change;
begin
  if Owner <> nil then
    Owner^.Change;
end; { Change }

{ Changed ------------------------------------------------- }

function TPackedMessage.Changed: Boolean;
begin
  if Owner <> nil then
    Result := Owner^.Changed
  else
    Result := False;
end; { Changed }

{ Kill ---------------------------------------------------- }

destructor TPackedMessage.Kill;
begin
  if Owner <> nil then
    Owner^.DelMessage( @Self );
  Done;
end; { Kill }

{ SetOwner ------------------------------------------------ }

procedure TPackedMessage.SetOwner( pkt: PPacket );
begin
  Owner := pkt;
end; { SetOwner }

{ --------------------------------------------------------- }
{ TPacket                                                   }
{ --------------------------------------------------------- }

type
  PPacketHeader = ^TPacketHeader;
  TPacketHeader = packed record
    OrigNode : SWORD;
    DestNode : SWORD;
    Year     : SWORD;
    Month    : SWORD;
    Day      : SWORD;
    Hour     : SWORD;
    Min      : SWORD;
    Sec      : SWORD;
    Baud     : SWORD;
    PktType  : SWORD;
    OrigNet  : SWORD;
    DestNet  : SWORD;
    PCodeLo  : BYTE;
    RevMajor : BYTE;
    Password : array [0..7] of Char;
    QOrigZone: SWORD;
    QDestZone: SWORD;
    AuxNet   : SWORD;
    CWValid  : SWORD;
    PCodeHi  : BYTE;
    RevMinor : BYTE;
    CW       : SWORD;
    OrigZone : SWORD;
    DestZone : SWORD;
    OrigPoint: SWORD;
    DestPoint: SWORD;
    LongData : DWORD;
  end; { TPacketHeader }

{ Init ---------------------------------------------------- }

constructor TPacket.Init( OrigAddr, DestAddr: TAddress; const Where: String );
begin
  inherited Init(20, 20);
  FileName := MakePktName(Where);
  Orig  := OrigAddr;
  Dest  := DestAddr;
  Date  := CurrentUnixTime;
  Modified := False;
end; { Init }

{$IFDEF USE_FILE_MAPPING}

{ Load ---------------------------------------------------- }

constructor TPacket.Load( const PktName: String );
var
  D: DateTime;
  T: Longint;
  B: array [0..10] of Char;
  pkt: PChar;
  hFile: THandle;
  hMapping: THandle;
  Header: PPacketHeader;
begin
  try
    inherited Init(20, 20);
    FileName := PktName;
    FileName[Succ(Length(FileName))] := #0;
    hFile := CreateFile( @FileName[1], GENERIC_READ, FILE_SHARE_READ,
                         nil, OPEN_EXISTING, FILE_FLAG_SEQUENTIAL_SCAN, 0 );
    if hFile = 0 then
      raise EInOutError.Create( 'MsgAPI: error opening file "' + FileName + '"' );

    hMapping := CreateFileMapping( hFile, nil, PAGE_READONLY, 0, 0, nil );

    if hMapping = 0 then
    begin
      CloseHandle( hFile );
      raise EInOutError.Create( 'MsgAPI: CreateFileMapping error, file "' + FileName + '"' );
    end;

    Header := MapViewOfFile( hMapping, FILE_MAP_READ, 0, 0, 0 );

    if Header = nil then
    begin
      CloseHandle( hMapping );
      CloseHandle( hFile );
      raise EInOutError.Create( 'MsgAPI: MapViewOfFile error, file: "' + FileName + '"' );
    end;

    with Header^ do
    begin
      Orig := MakeAddr( OrigZone, OrigNet, OrigNode, OrigPoint );
      Dest := MakeAddr( DestZone, DestNet, DestNode, DestPoint );
    end;

    D.Day   := Header^.Day;
    D.Month := Header^.Month;
    D.Year  := Header^.Year;
    D.Hour  := Header^.Hour;
    D.Min   := Header^.Min;
    D.Sec   := Header^.Sec;

    PackTime( D, T );
    Date := FileTimeToUnix( T );

    FillChar( B, SizeOf(B), 0 );
    Password := StrPas( StrLCopy( B, Header^.Password, 8 ) );

    pkt := PChar(Header) + SizeOf(TPacketHeader);

    try
      while pkt[0] <> #0 do
        AddMessage( New( PPackedMessage, Load( pkt ) ));
    finally
      UnmapViewOfFile( Header );
      CloseHandle( hMapping );
      CloseHandle( hFile );
    end;

    Modified := False;

  except
    on E: Exception do
      begin
        ShowError( 'MsgAPI: error reading PKT: ' + E.Message );
        Fail;
      end;
  end;
end; { Load }

{$ELSE}

constructor TPacket.Load( const PktName: String );
var
  D : DateTime;
  B : array [0..10] of Char;
  T : Longint;
  Pkt   : TBufStream;
  Header: TPacketHeader;
begin
  inherited Init( 20, 20 );
  FileName := PktName;
  Pkt.Init( PktName, stOpenRead, STREAM_BUFFER_SIZE );
  if Pkt.Status <> stOk then
  begin
    Pkt.Done;
    ShowError( 'MsgAPI: Could not open ' + PktName );
    Fail;
  end;

  Pkt.Read( Header, SizeOf(Header) );

  with Header do
  begin
    Orig := MakeAddr( OrigZone, OrigNet, OrigNode, OrigPoint );
    Dest := MakeAddr( DestZone, DestNet, DestNode, DestPoint );
    D.Day   := Header.Day;
    D.Month := Header.Month;
    D.Year  := Header.Year;
    D.Hour  := Header.Hour;
    D.Min   := Header.Min;
    D.Sec   := Header.Sec;
  end;

  PackTime( D, T );
  Date := FileTimeToUnix( T );

  FillChar( B, SizeOf(B), 0 );
  Password := StrPas( StrLCopy( B, Header.Password, 8 ) );

  try
    Pkt.Read( B, 1 );
    while b[0] <> #0 do
    begin
      Pkt.Seek( Pred(Pkt.GetPos) );
      AddMessage( New( PPackedMessage, Load( Pkt ) ));
      Pkt.Read( B, 1 );
    end;
  finally
    Pkt.Done;
  end;

  Modified := False;
end; { Load }

{$ENDIF}

{ GetDate ------------------------------------------------- }

function TPacket.GetDate: UnixTime;
begin
  Result := Date;
end; { GetDate }

{ GetPassword --------------------------------------------- }

function TPacket.GetPassword: String;
begin
  Result := Password;
end; { GetPassword }

{ SetDate ------------------------------------------------- }

procedure TPacket.SetDate( D: UnixTime );
begin
  Date := D;
  Change;
end; { SetDate }

{ SetPassword --------------------------------------------- }

procedure TPacket.SetPassword( const S: String );
begin
  Password := S;
  Change;
end; { SetPassword }

{ Save ---------------------------------------------------- }

procedure TPacket.Save;
const
  ZERO: SWORD = 0;
var
  D: DateTime;
  pkt: TBufStream;
  Header: TPacketHeader;

  procedure SaveMsg( M: PPackedMessage ); far;
  begin
    M^.BinSave( Pkt );
  end; { SaveMsg }

begin
  pkt.Init( FileName, stCreate, 2048 );
  if pkt.Status <> stOk then
  begin
    pkt.Done;
    raise EInOutError.Create( 'MsgAPI: could not create "' + FileName + '"' );
  end;
  FillChar( Header, SizeOf(Header), 0 );
  UnpackTime( UnixTimeToFile(Date), D );
  with Header do
  begin
    PktType   := 2;
    OrigZone  := Orig.Zone;
    OrigNet   := Orig.Net;
    OrigNode  := Orig.Node;
    OrigPoint := Orig.Point;
    DestZone  := Dest.Zone;
    DestNet   := Dest.Net;
    DestNode  := Dest.Node;
    DestPoint := Dest.Point;
    AuxNet    := Orig.Net;
    {
    if Orig.Point <> 0 then
    begin
      AuxNet  := Orig.Net;
      OrigNet := $FFFF;
    end;
    }
    QOrigZone := Orig.Zone;
    QDestZone := Dest.Zone;
    Day       := D.Day;
    Month     := D.Month;
    Year      := D.Year;
    Hour      := D.Hour;
    Min       := D.Min;
    Sec       := D.Sec;
    CWValid   := $0100;
    CW        := $0001;
  end;
  StrSet( Header.Password, Password, 8 );
  Pkt.Write( Header, SizeOf(Header) );
  ForEach( @SaveMsg );
  Pkt.Write( ZERO, 2 );
  Pkt.Done;
  Modified := False;
end; { Save }

{ AddMessage ---------------------------------------------- }

procedure TPacket.AddMessage( M: PPackedMessage );
begin
  Insert( M );
  M^.SetOwner( @Self );
  Change;
end; { AddMessage }

{ DelMessage ---------------------------------------------- }

procedure TPacket.DelMessage( M: PPackedMessage );
begin
  M^.SetOwner( nil );
  Free( M );
  Change;
end; { DelMessage }

{ Change -------------------------------------------------- }

procedure TPacket.Change;
begin
  Modified := True;
end; { Change }

{ Changed ------------------------------------------------- }

function TPacket.Changed: Boolean;
begin
  Result := Modified;
end; { Changed }

{ --------------------------------------------------------- }
{ NetmailMessage                                            }
{ --------------------------------------------------------- }

type
  PNetmailHeader = ^TNetmailHeader;
  TNetmailHeader = packed record
    _From: array [0..35] of Char;
    _To  : array [0..35] of Char;
    Subj : array [0..71] of Char;
    Date : array [0..19] of Char;
    TimesRead: SWORD;
    DestNode : SWORD;
    OrigNode : SWORD;
    Cost     : SWORD;
    OrigNet  : SWORD;
    DestNet  : SWORD;
    DestZone : SWORD;
    OrigZone : SWORD;
    DestPoint: SWORD;
    OrigPoint: SWORD;
    ReplyTo  : SWORD;
    Attr     : SWORD;
    NextReply: SWORD;
  end; { TNetmailHeader }


{ Init ---------------------------------------------------- }

constructor TNetmailMessage.Init( const Pattern: String );
begin
  inherited Init;
  SetArea( NETMAIL_AREA );
  FileName := Pattern;
end; { Init }

{$IFDEF USE_FILE_MAPPING}

{ MsgGetStr ----------------------------------------------- }

function MsgGetStr( var S: String; var P: PChar; Limit: PChar ) : Boolean;
var
  N: Byte absolute S;
  Start: PChar;
begin
  N := 0;
  Start := P;
  while P <> Limit do
  begin
    if P[0] = CR then
    begin
      Inc(P);
      Move( Start[0], S[1], N );
      Result := True;
      Exit;
    end;
    if P[0] = #0 then
    begin
      Move( Start[0], S[1], N );
      Result := False;
      Exit;
    end;
    Inc(P);
    Inc(N);
  end;
  Result := N > 0;
end; { MsgGetStr }

{ Load ---------------------------------------------------- }

constructor TNetmailMessage.Load( const MsgName: String );
var
  P: PChar;
  E: PChar;
  S: String;
  A: TAddress;
  B: array [0..79] of Char;
  hFile: THandle;
  hMapping: THandle;
  Header: PNetmailHeader;
begin
  inherited Init;
  FileName := MsgName;
  FileName[Succ(Length(FileName))] := #0;
  hFile := CreateFile( @FileName[1], GENERIC_READ, FILE_SHARE_READ,
           nil, OPEN_EXISTING, FILE_FLAG_SEQUENTIAL_SCAN, 0 );
  if hFile = 0 then
    raise EInOutError.Create( 'MsgAPI: error opening file "' + FileName + '"' );

  hMapping := CreateFileMapping( hFile, nil, PAGE_READONLY, 0, 0, nil );

  if hMapping = 0 then
  begin
    CloseHandle( hFile );
    raise EInOutError.Create( 'MsgAPI: CreateFileMapping error, file "' + FileName + '"' );
  end;

  Header := MapViewOfFile( hMapping, FILE_MAP_READ, 0, 0, 0 );

  if Header = nil then
  begin
    CloseHandle( hMapping );
    CloseHandle( hFile );
    raise EInOutError.Create( 'MsgAPI: MapViewOfFile error, file: "' + FileName + '"' );
  end;

  _From := StrPas( StrLCopy(B, Header^._From, 36) );
  _To   := StrPas( StrLCopy(B, Header^._To, 36) );
  Subj  := StrPas( StrLCopy(B, Header^.Subj, 72) );
  Attr  := Header^.Attr;

  try
    Date := ParseMsgDate( StrPas(StrLCopy(B, Header^.Date, 20) ));
  except
    Date := CurrentUnixTime;
  end;

  with Header^ do
  begin
    Orig.Zone  := 0;
    Orig.Net   := OrigNet;
    Orig.Node  := OrigNode;
    Dest.Zone  := 0;
    Dest.Net   := DestNet;
    Dest.Node  := DestNode;
  end;

  P := PChar(Header) + SizeOf(TNetmailHeader);
  E := PChar(Header) + GetFileSize( hFile, nil );

  while MsgGetStr( S, P, E ) do
    if not CheckKludge( S ) then
      Insert( AllocStr(S) );

  if Orig.Zone = 0 then
  begin
    if SafeAddr( ExtractWord( 1, MsgID, BLANK ), A ) then
      Orig.Zone := A.Zone;
    if Orig.Zone = 0 then
      Orig.Zone := DefAddr.Zone;
  end;

  if Dest.Zone = 0 then
    Dest.Zone := DefAddr.Zone;

  UnmapViewOfFile( Header );
  CloseHandle( hMapping );
  CloseHandle( hFile );
  Modified := False;
end; { Load }

{$ELSE}

{ MsgGetStr ----------------------------------------------- }

function MsgGetStr( var S: String; var Msg: TStream ) : Boolean;
var
  C: Char;
  N: Byte absolute S;
begin
  Result := False;
  N := 0;
  Msg.Read( C, 1 );
  while Msg.Status = stOk do
  begin
    if C = #0 then
      Exit;
    if C = CR then
    begin
      Result := True;
      Exit;
    end;
    Inc( N );
    S[N] := C;
    Msg.Read( C, 1 );
  end;
end; { MsgGetStr }

{ Load ---------------------------------------------------- }

constructor TNetmailMessage.Load( const MsgName: String );
var
  B: array [0..79] of Char;
  S: String;
  A: TAddress;

  Msg   : TBufStream;
  Header: TNetmailHeader;

begin
  inherited Init;
  FileName := MsgName;
  Msg.Init( MsgName, stOpenRead, STREAM_BUFFER_SIZE );
  if Msg.Status <> stOk then
  begin
    Msg.Done;
    ShowError( 'MsgAPI: Could not open ' + MsgName );
    Fail;
  end;

  Msg.Read( Header, SizeOf(Header) );

  _From := StrPas( StrLCopy(B, Header._From, 36) );
  _To   := StrPas( StrLCopy(B, Header._To, 36) );
  Subj  := StrPas( StrLCopy(B, Header.Subj, 72) );
  Attr  := Header.Attr;

  try
    Date := ParseMsgDate( StrPas(StrLCopy(B, Header.Date, 20) ));
  except
    Date := CurrentUnixTime;
  end;

  with Header do
  begin
    Orig.Zone  := 0;
    Orig.Net   := OrigNet;
    Orig.Node  := OrigNode;
    Dest.Zone  := 0;
    Dest.Net   := DestNet;
    Dest.Node  := DestNode;
  end;

  while MsgGetStr( S, Msg ) do
    if not CheckKludge( S ) then
      Insert( AllocStr(S) );

  Msg.Done;

  if Orig.Zone = 0 then
  begin
    if SafeAddr( ExtractWord( 1, MsgID, BLANK ), A ) then
      Orig.Zone := A.Zone;
    if Orig.Zone = 0 then
      Orig.Zone := DefAddr.Zone;
  end;

  Modified := False;

end; { Load }

{$ENDIF}

{ SaveBinHeader ------------------------------------------- }

procedure TNetmailMessage.SaveBinHeader( var bin: TStream );
var
  Header: TNetmailHeader;
begin
  FillChar( Header, SizeOf(Header), 0 );
  StrSet( Header._From, _From, 36 );
  StrSet( Header._To, _To, 36 );
  StrSet( Header.Subj, Subj, 72 );
  StrSet( Header.Date, MsgDateStr(Date), 20 );
  Header.OrigZone  := Orig.Zone;
  Header.OrigNet   := Orig.Net;
  Header.OrigNode  := Orig.Node;
  Header.OrigPoint := Orig.Point;
  Header.DestZone  := Dest.Zone;
  Header.DestNet   := Dest.Net;
  Header.DestNode  := Dest.Node;
  Header.DestPoint := Dest.Point;
  Header.Attr      := StripExtendedAttr( Attr );
  bin.Write( Header, SizeOf(Header) );
end; { SaveBinHeader }

{ Change -------------------------------------------------- }

procedure TNetmailMessage.Change;
begin
  Modified := True;
end; { Change }

{ Changed ------------------------------------------------- }

function TNetmailMessage.Changed: Boolean;
begin
  Result := Modified;
end; { Changed }

{ Kill ---------------------------------------------------- }

procedure TNetmailMessage.Kill;
begin
  VFS_EraseFile( FileName );
end; { Kill }

{ GenMsgName ---------------------------------------------- }

function GenMsgName( const Pattern: String ) : String;
var
  N: Integer;
  j: Integer;
  R: TSearchRec;
  S: String;
  DosError: Integer;
begin
  N := 0;
  DosError := SysUtils.FindFirst( Pattern, faArchive + faReadOnly, R );
  while DosError = 0 do
  begin
    try
      j := StrToInt( ChangeFileExt( R.Name, '' ) );
    except
      j := 0;
    end;
    if j > N then N := j;
    DosError := SysUtils.FindNext( R );
  end;
  SysUtils.FindClose( R );
  Result := Replace( Pattern, '*', IntToStr(N+1) );
end; { GenMsgName }

{ Save ---------------------------------------------------- }

procedure TNetmailMessage.Save;
var
  msg : TBufStream;
begin
  if Pos( '*', FileName ) > 0 then
    FileName := GenMsgName( FileName );
  msg.Init( FileName, stCreate, 2048 );
  if msg.Status <> stOk then
  begin
    msg.Done;
    raise EInOutError.Create( 'MsgAPI: could not create "' + FileName + '"' );
  end;
  BinSave( msg );
  msg.Done;
end; { Save }


{ --------------------------------------------------------- }
{ TMsgBase                                                  }
{ --------------------------------------------------------- }

{ Init ---------------------------------------------------- }

constructor TMsgBase.Init( const MsgBasePath: String );
begin
  inherited Init;
  MsgPath := MsgBasePath;
  GetMem( MsgTable, SizeOf(TMsgTable) );
  Rescan;
end; { Init }

{ Done ---------------------------------------------------- }

destructor TMsgBase.Done;
begin
  if MsgTable <> nil then FreeMem( MsgTable );
  inherited Done;
end; { Done }

{ Rescan -------------------------------------------------- }

procedure TMsgBase.Rescan;
var
  R: TSearchRec;
  N: Integer;
  S: String;
begin
  FillChar( MsgTable^, SizeOf(TMsgTable), 0 );
  DosError := SysUtils.FindFirst( AtPath('*.msg', MsgPath), faArchive + faReadOnly, R );
  while DosError = 0 do
  begin
    try
      N := StrToInt( ExtractFilenameOnly(R.Name) );
      MsgTable^[N] := True;
    except
      {...nothing...};
    end;
    DosError := SysUtils.FindNext( R );
  end;
  SysUtils.FindClose( R );
  MsgIndex := 0;
end; { Rescan }

{ SetPID -------------------------------------------------- }

procedure TMsgBase.SetPID( const MyPID: String );
begin
  PID := MyPID;
end; { SetPID }

{ SeekFirst ----------------------------------------------- }

procedure TMsgBase.SeekFirst;
begin
  MsgIndex := 1;
  while MsgIndex <= MAX_MSG_COUNT do
  begin
    if MsgTable^[ MsgIndex ] then Exit;
    Inc( MsgIndex );
  end;
  MsgIndex := 0;
end; { SeekFirst }

{ SeekNext ------------------------------------------------ }

procedure TMsgBase.SeekNext;
begin
  Inc( MsgIndex );
  while MsgIndex <= MAX_MSG_COUNT do
  begin
    if MsgTable^[ MsgIndex ] then Exit;
    Inc( MsgIndex );
  end;
  MsgIndex := 0;
end; { SeekNext }

{ SeekFound ----------------------------------------------- }

function TMsgBase.SeekFound: Boolean;
begin
  Result := MsgIndex > 0;
end; { SeekFound }

{ GetMessage ---------------------------------------------- }

function TMsgBase.GetMessage: PNetmailMessage;
var
  S: String;
begin
  Result := nil;
  if not SeekFound then Exit;
  S := AtPath( IntToStr( MsgIndex ) + '.msg', MsgPath );
  Result := New( PNetmailMessage, Load( S ) );
end; { GetMessage }

{ NewMessage ---------------------------------------------- }

function TMsgBase.NewMessage: PNetmailMessage;
var
  j: Integer;
begin
  j := MAX_MSG_COUNT;
  while (j > 0) and not MsgTable^[ j ] do Dec( j );
  Inc( j );
  MsgTable^[ j ] := True;
  Result := New( PNetmailMessage, Init( AtPath( IntToStr(j) + '.msg', MsgPath ) ));
end; { NewMessage }


end.
