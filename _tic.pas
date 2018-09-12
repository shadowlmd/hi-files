unit _Tic;

/////////////////////////////////////////////////////////////////////
//
// Hi-Files Version 2
// Copyright (c) 1997-2004 Dmitry Liman [2:461/79]
//
// http://hi-files.narod.ru
//
/////////////////////////////////////////////////////////////////////

interface

uses Objects, MyLib, MsgAPI, _Fareas;

type
  PTic = ^TTic;
  TTic = object (TObject)
    { *** FSC-0087 fields *** }
    AreaTag  : PString;
    AreaDesc : PString;
    FileName : PString;
    FullName : PString;
    CRC      : Word;
    Magic    : PString;
    Replaces : PString;
    Desc     : PString;
    LDesc    : PStrings;
    Size     : Longint;
    Date     : PString;
    Release  : PString;
    Author   : PString;
    Source   : PString;
    App      : PString;
    Origin   : TAddress;
    FromAddr : TAddress;
    ToAddr   : TAddress;
    Created  : PString;

    Path     : PStrings;
    SeenBy   : PAddrList;
    Pw       : PString;

    { *** run-time fields *** }
    TicName  : String;
    TimeStamp: FileTime;

    constructor Init;
    destructor Done; virtual;

    procedure LoadFrom( const TicFileName: String);
    procedure SaveTo( const NewTicName: String; Downlink: PAddress );
    procedure Reject( const Reason: String );

    function BuildFileDef: PFileDef;
  end; { TTic }

function BuildTicName( Dest: TAddress; const Path: String ) : String;

procedure RunTicTosser;

procedure Notify( const EchoTag, Subject, Event: String );

{ =================================================================== }

implementation

uses
  SysUtils, _MapFile, _LOG, _CFG, _CRC32, _RES,
  VpUtils, VpSysLow, _Report, Spawn;


const
  BADTIC_LOG = 'bad_tic.log';

{ --------------------------------------------------------- }
{ TTic                                                      }
{ --------------------------------------------------------- }

const
  kw_Area     = 'Area';
  kw_AreaDesc = 'AreaDesc';
  kw_Origin   = 'Origin';
  kw_From     = 'From';
  kw_To       = 'To';
  kw_Dest     = 'Destination';
  kw_Replaces = 'Replaces';
  kw_Magic    = 'Magic';
  kw_File     = 'File';
  kw_FullName = 'FullName';
  kw_Created  = 'Created';
  kw_Pw       = 'Pw';
  kw_CRC      = 'CRC';
  kw_Size     = 'Size';
  kw_Date     = 'Date';
  kw_Release  = 'Release';
  kw_Author   = 'Author';
  kw_Source   = 'Source';
  kw_App      = 'App';
  kw_Path     = 'Path';
  kw_Seenby   = 'Seenby';
  kw_Desc     = 'Desc';
  kw_LDesc    = 'LDesc';

{ Init ---------------------------------------------------- }

constructor TTic.Init;
begin
  inherited Init;
  New( Path,   Init(10, 10) );
  New( Seenby, Init(50, 50) );
  Pw := AllocStr( '' );
end; { Init }

{ Done ---------------------------------------------------- }

destructor TTic.Done;
begin
  FreeStr( AreaTag );
  FreeStr( AreaDesc );
  FreeStr( FileName );
  FreeStr( FullName );
  FreeStr( Replaces );
  FreeStr( Magic );
  FreeStr( Created );
  FreeStr( Pw );
  FreeStr( Desc );
  FreeStr( Date );
  FreeStr( Release );
  FreeStr( Author );
  FreeStr( Source );
  FreeStr( App );
  Destroy( Path );
  Destroy( Seenby );
  Destroy( LDesc );
  inherited Done;
end; { Done }

{ LoadFrom ------------------------------------------------ }

procedure TTic.LoadFrom( const TicFileName: String );
var
  Map: TMappedFile;
  Key: String;
  Par: String;
  S  : String;
  A  : PAddress;
begin
  ToAddr := ZERO_ADDR;
  TicName := TicFileName;
  Map.Init( TicName );
  while Map.GetLine( S ) do
  begin
    if S = '' then Continue;
    SplitPair( S, Key, Par );
    if JustSameText( Key, kw_Area ) then
      ReplaceStr( AreaTag, Par )
    else if JustSameText( Key, kw_AreaDesc ) then
      ReplaceStr( AreaDesc, Par )
    else if JustSameText( Key, kw_Origin ) then
      Origin := StrToAddr( Par )
    else if JustSameText( Key, kw_From ) then
      FromAddr := StrToAddr( Par )
    else if JustSameText( Key, kw_To ) then
      ToAddr := StrToAddr( Par )
    else if JustSameText( Key, kw_Dest ) then
      ToAddr := StrToAddr( ExtractWord( 1, Par, [ ' ', ',' ] ) )
    else if JustSameText( Key, kw_Replaces ) then
      ReplaceStr( Replaces, ExtractFileName(Par) )
    else if JustSameText( Key, kw_Magic ) then
      ReplaceStr( Magic, Par )
    else if JustSameText( Key, kw_File ) then
      ReplaceStr( FileName, ExtractFileName(Par) )
    else if JustSameText( Key, kw_FullName ) then
      ReplaceStr( FullName, Par )
    else if JustSameText( Key, kw_Created ) then
      ReplaceStr( Created, Par )
    else if JustSameText( Key, kw_Pw ) then
      ReplaceStr( Pw, Par )
    else if JustSameText( Key, kw_CRC ) then
      CRC := HexToInt( Par )
    else if JustSameText( Key, kw_Size ) then
      Size := StrToInt( Par )
    else if JustSameText( Key, kw_Date ) then
      ReplaceStr( Date, Par )
    else if JustSameText( Key, kw_Release ) then
      ReplaceStr( Release, Par )
    else if JustSameText( Key, kw_Author ) then
      ReplaceStr( Author, Par )
    else if JustSameText( Key, kw_Source ) then
      ReplaceStr( Source, Par )
    else if JustSameText( Key, kw_App ) then
      ReplaceStr( App, Par )
    else if JustSameText( Key, kw_Path ) then
      Path^.Insert( AllocStr(Par) )
    else if JustSameText( Key, 'Seenby' ) then
    begin
      New( A );
      if SafeAddr( Par, A^ ) then
        Seenby^.Insert( A )
      else
      begin
        Dispose( A );
        Log^.Write( ll_Warning, Format(LoadString(_SBadSeenBy), [Par] ));
      end;
    end
    else if JustSameText( Key, kw_Desc ) then
      ReplaceStr( Desc, Par )
    else if JustSameText( Key, 'LDesc' ) then
    begin
      if LDesc = nil then New( LDesc, Init(10, 10) );
      LDesc^.Insert( AllocStr(Par) );
    end
    else
      Log^.Write( ll_Warning, Format(LoadString(_SBadTicToken), [S] ));
  end;
  Map.Done;
  if Desc = nil then Desc := AllocStr( '' );
end; { LoadFrom }

{ SaveTo -------------------------------------------------- }

procedure TTic.SaveTo( const NewTicName: String; Downlink: PAddress );
var
  F: Text;
  Link : PEchoLink;
  Hatch: Boolean;

  procedure WriteLDesc( P: PString ); far;
  begin
    Writeln( F, 'LDesc ', P^ );
  end; { WriteLDesc }

  procedure WritePath( P: PString ); far;
  begin
    Writeln( F, 'Path ', P^ );
  end; { WritePath }

  procedure WriteSeenby( A: PAddress ); far;
  begin
    Writeln( F, 'SeenBy ', AddrToStr( A^ ) );
  end; { WriteSeenby }

  function PathTimeStamp: String;
  var
    D: TDateTime;
    Year, Month, Day: SWORD;
    Hour, Min, Sec, MSec: SWORD;
  begin
    D := FileDateToDateTime( TimeStamp );
    DecodeDate( D, Year, Month, Day );
    DecodeTime( D, Hour, Min, Sec, MSec );
    Result := IntToStr( FileTimeToUnix(TimeStamp) - 3600 * CFG^.UTC ) + ' ' +
              DayName[ DayOfWeek(D) ] + ' ' +
              MonthName[ Month ] + ' ' +
              TwoDigits( Day ) + ' ' +
              TwoDigits( Hour ) + ':' + TwoDigits( Min ) + ':' + TwoDigits( Sec ) + ' ' +
              IntToStr( Year ) +
              ' UTC' + IntToSignedStr(CFG^.UTC);
  end; { PathTimeStamp }

begin
  TicName := NewTicName;

  Hatch := (CompAddr( FromAddr, Downlink^) = 0) and
           JustSameText( Pw^, CFG^.HatchPw );

  Assign( F, TicName ); Rewrite( F );
  Writeln( F, kw_Area, ' ', AreaTag^ );
  if AreaDesc <> nil then
    Writeln( F, kw_AreaDesc, ' ', AreaDesc^ );
  Writeln( F, kw_File, ' ', FileName^ );
  if FullName <> nil then
    Writeln( F, kw_FullName, ' ', FullName^ );
  Writeln( F, kw_CRC, ' ', IntToHex( CRC, 8 ) );
  if Magic <> nil then
    Writeln( F, kw_Magic, ' ', Magic^ );
  if Replaces <> nil then
    Writeln( F, kw_Replaces, ' ', Replaces^ );
  Writeln( F, kw_Desc, ' ', Desc^ );
  if LDesc <> nil then
    LDesc^.ForEach( @WriteLDesc );
  if Size <> 0 then
    Writeln( F, kw_Size, ' ', IntToStr( Size ) );
  if Date <> nil then
    Writeln( F, kw_Date, ' ', Date^ );
  if Release <> nil then
    Writeln( F, kw_Release, ' ', Release^ );
  if Author <> nil then
    Writeln( F, kw_Author, ' ', Author^ );
  if Source <> nil then
    Writeln( F, kw_Source, ' ', Source^ );
  if App <> nil then
    Writeln( F, kw_App, ' ', App^ );
  Writeln( F, kw_Origin, ' ', AddrToStr( Origin ) );

  if not Hatch then
  begin
    Link := CFG^.Links^.Find( Downlink^ );
    Writeln( F, kw_From, ' ', AddrToStr( Link^.OurAka ) );
  end
  else
    Writeln( F, kw_From, ' ', AddrToStr( CFG^.PrimaryAddr ));

  Writeln( F, kw_To, ' ', AddrToStr( Downlink^ ) );
  if Created <> nil then
    Writeln( F, kw_Created, ' ', Created^ );

  if not Hatch then
  begin
    Path^.ForEach( @WritePath );
    Writeln( F, kw_Path, ' ', AddrToStr( Link^.OurAka ), ' ', PathTimeStamp );
    Seenby^.ForEach( @WriteSeenby );
    Writeln( F, kw_Pw, ' ', Link^.Password^ );
  end
  else
    Writeln( F, kw_Pw, ' ', CFG^.HatchPw );

  Close( F );
  Log^.Write( ll_Protocol, Format(LoadString(_STicBuilt), [TicName] ));
end; { SaveTo }

{ Reject -------------------------------------------------- }

procedure TTic.Reject( const Reason: String );
var
  F: Text;
begin
  if VFS_MoveFile( TicName, AtPath(TicName, CFG^.BadTicPath) ) = 0 then
  begin
    Assign( F, AtPath( BADTIC_LOG, CFG^.BadTicPath ) );
    try
      Append( F );
    except
      try
        Rewrite( F );
      except
        ShowError( Format(LoadString(_SCantCreBadTicLog), [AtPath( BADTIC_LOG, CFG^.BadTicPath )]));
        Exit;
      end;
    end;
    Writeln( F, LogTimeStamp(CurrentFileTime) + ' ' + ExtractFileName(TicName) + ' ' + Reason );
    Close( F );
  end
  else
    ShowError( Format(LoadString(_SCantMoveRej), [AtPath( TicName, CFG^.BadTicPath )]));
  raise Exception.Create( Format(Loadstring(_STicRejected), [ExtractFileName(TicName), Reason] ));
end; { Reject }

{ BuildFileDef -------------------------------------------- }

function TTic.BuildFileDef: PFileDef;

  procedure Add( P: PString ); far;
  begin
    Result^.Append( P^ );
  end; { Add }

begin
  New( Result, Init(FileName^) );
  Result^.Append( Desc^ );
  if LDesc <> nil then
    LDesc^.ForEach( @Add );
  Result^.Normalize;
end; { PFileDef }

{ --------------------------------------------------------- }
{ BuildTicName                                              }
{ --------------------------------------------------------- }

function BuildTicName( Dest: TAddress; const Path: String ) : String;
begin
  repeat
    Result := LowerCase( AtPath(IntToHex(Dest.Node, 4) + IntToHex(Random($FFFF), 4) + '.tic', Path ) );
  until not FileExists( Result );
end; { BuildTicName }

{ --------------------------------------------------------- }
{ TAttach                                                   }
{ --------------------------------------------------------- }

type
  PAttach = ^TAttach;
  TAttach = object (TStrings)
    procedure ReadFrom( const FileName: String );
    procedure WriteTo( const FileName: String );
    procedure AddFile( const FileName: String );
  end; { TAttach }

{ ReadFrom ------------------------------------------------ }

procedure TAttach.ReadFrom( const FileName: String );
var
  S: String;
  Map: TMappedFile;
begin
  Map.Init( FileName );
  while Map.GetLine( S ) do
    if S <> '' then
      AddFile( S );
  Map.Done;
end; { ReadFrom }

{ WriteTo ------------------------------------------------- }

procedure TAttach.WriteTo( const FileName: String );
var
  F: Text;

  procedure WriteItem( P: PString ); far;
  begin
    Writeln( F, P^ );
  end; { WriteItem }

begin
  Assign( F, FileName ); Rewrite( F );
  ForEach( @WriteItem );
  Close( F );
end; { WriteTo }

{ AddFile ------------------------------------------------- }

procedure TAttach.AddFile( const FileName: String );

  function Match( P: PString ) : Boolean; far;
  begin
    Result := JustSameText( P^, FileName );
  end; { Match }

var
  A: PString;
  j: Integer;
begin
  A := FirstThat( @Match );
  if A <> nil then
  begin
    Log^.Write( ll_Protocol, Format(LoadString(_SOldAttachCut), [FileName] ));
    j := IndexOf( A );
    AtFree( j );
    if j < Count then
    begin
      A := At(j);
      if WildMatch( A^, '*.tic' ) then
      begin
        Log^.Write( ll_Protocol, Format(LoadString(_SOldTicDied), [A^] ));
        if A^[1] in ['^', '#'] then
          VFS_EraseFile( Copy(A^, 2, Length(A^)) )
        else
          VFS_EraseFile( A^ );
        AtFree( j  );
      end;
    end;
  end;
  Insert( AllocStr(FileName) );
end; { AddFile }

{ --------------------------------------------------------- }
{ Notify                                                    }
{ --------------------------------------------------------- }

procedure Notify( const EchoTag, Subject, Event: String );

  procedure Send( Link: PEchoLink ); far;
  var
    Addr  : PAddress;
    Poster: PPoster;
    Report: PPktReport;
  begin
    if Link = nil then
      Addr := @CFG^.PrimaryAddr
    else if (elo_Notify in Link^.Opt) and not (elo_Pause in Link^.Opt) then
      Addr := @Link^.Addr
    else
      Exit;

    Report := nil;
    Poster := nil;
    try
      New( Poster, Init );
      with Poster^ do
      begin
        _From := PROG_NAME;
        _To   := 'Sysop';
        Subj  := Subject;
        Area  := NETMAIL_AREA;
        Dest := Addr^;
        if Link = nil then
          Orig := CFG^.PrimaryAddr
        else
          Orig := Link^.OurAka;
      end;
      New( Report, Init(Poster) );
      with Report^ do
      begin
        WriteOut( LoadString(_SMsgHi) );
        WriteOut( '' );
        WriteOut( Event );
        WriteOut( EchoTag );
        WriteOut( '' );
        WriteOut( TEARLINE );
      end;
    finally
      Destroy( Report );
      Destroy( Poster );
    end;
  end; { Send }

begin
  Log^.Write( ll_Service, LoadString(_SLogNotifying) );
  Send( nil );
  CFG^.Links^.ForEach( @Send );
end; { Notify }

{ --------------------------------------------------------- }
{ AutoCreate                                                }
{ --------------------------------------------------------- }

function AutoCreate( Link: PEchoLink; Tic: PTic ) : PFileEcho;
var
  j: Integer;
  Echo: PFileEcho;
  Area: PFileArea;
  Name: String;
  Path: String;
  Addr: TAddress;
begin
  Result := nil;

  if Link = nil then
    Addr := CFG^.PrimaryAddr
  else if elo_AutoCreate in Link^.Opt then
    Addr := Link^.Addr
  else
    Exit;

  New( Echo, Init(Tic^.AreaTag^) );
  Name := 'FileEcho: ' + Echo^.Name^;
  j := -1;
  while FileBase^.GetArea( Name ) <> nil do
  begin
    Inc( j );
    Name := 'FileEcho: ' + Echo^.Name^ + ' (' + TwoDigits(j) + ')';
  end;
  Path := AtPath( Echo^.Name^, CFG^.Autocreate );
  j := -1;
  while DirExists( Path ) do
  begin
    Inc( j );
    Path := AtPath( Echo^.Name^ + '.' + TwoDigits(j), CFG^.Autocreate );
  end;
  if not CreateDirTree( Path ) then
    raise Exception.Create( Format(LoadString(_SMkDirFailed), [Path] ));
  New( Area, Init(Name) );
  with Area^ do
  begin
    DL_Path^.Insert( AllocStr(Path) );
    ReplaceStr( FilesBbs, AtPath( FILES_BBS, Path ) );
    ReplaceStr( Group, FILE_ECHO_GROUP );
    Loaded := True;
  end;
  Echo^.Area := Area;
  FileBase^.Insert( Area );
  FileBase^.EchoList^.Insert( Echo );
  FileBase^.Modified := True;
  Log^.Write( ll_Protocol, Format(LoadString(_SLogAutoCre), [AddrToStr(Addr), Echo^.Name^] ));
  Log^.Write( ll_Protocol, Format(LoadString(_SLogHostCre), [Area^.Name^] ));
  Notify( Echo^.Name^, 'New file echo', Format(LoadString(_SMsgAutoCre), [AddrToStr(Addr)] ));
  Result := Echo;
end; { AutoCreate }

{ --------------------------------------------------------- }
{ LockAddr                                                  }
{ --------------------------------------------------------- }

function LockAddr( Bink: String ) : Boolean;
var
  j: Integer;
  F: File;
  BusyFlag: String;
  TempBusy: String;
begin
  Result   := False;
  BusyFlag := ChangeFileExt( Bink, '.bsy' );
  TempBusy := ChangeFileExt( Bink, '.$b$' );
  Assign( F, TempBusy );
  try
    Rewrite( F );
  except
    Log^.Write( ll_Warning, Format(LoadString(_SCantBsoLock), [TempBusy]));
    Exit;
  end;
  Close( F );
  for j := 1 to 50 do
  begin
    try
      Rename( F, BusyFlag );
    except
      Sleep( 100 );
      Continue;
    end;
    Result := True;
    Exit;
  end;
  Erase( F );
  Log^.Write( ll_Warning, LoadString(_SBsoTimeout) );
end; { LockAddr }

{ --------------------------------------------------------- }
{ UnlockAddr                                                }
{ --------------------------------------------------------- }

procedure UnlockAddr( const Bink: String );
begin
  if not VFS_EraseFile( Bink + '.bsy' ) then
    Log^.Write( ll_Warning, Format(LoadString(_SCantKillBsy), [Bink + '.bsy']));
end; { UnlockAddr }

{ --------------------------------------------------------- }
{ BuildBinkName                                             }
{ --------------------------------------------------------- }

function BuildBinkName( Addr: TAddress ) : String;
begin
  Result := AtPath( IntToHex(Addr.Net, 4) + IntToHex(Addr.Node, 4), CFG^.Outbound );
  if Addr.Point <> 0 then
  begin
    Result := Result + '.pnt';
    if not DirExists( Result ) then
    begin
      if not CreateDir( Result ) then
        raise Exception.Create( Format(LoadString(_SMkDirFailed), [Result] ));
    end;
    Result := Result + SysPathSep + IntToHex(Addr.Point, 8);
  end;
  Result := LowerCase( Result );
end; { BuildBinkName }

{ --------------------------------------------------------- }
{ CopyAttach                                                }
{ --------------------------------------------------------- }

function CopyAttach( const HeldName, LOName: String ) : Boolean;
var
  LO  : TDosStream;
  Held: TDosStream;
  Size: Integer;
  Buffer: PChar;
begin
  Result := False;
  Held.Init( HeldName, stOpenRead );
  if Held.Status <> stOk then
  begin
    Held.Done;
    Log^.Write( ll_Warning, Format(LoadString(_SCantOpenTempLo), [HeldName] ));
    Exit;
  end;
  if FileExists( LOName ) then
    LO.Init( LOName, stOpenWrite )
  else
    LO.Init( LOName, stCreate );
  if LO.Status <> stOk then
  begin
    LO.Done;
    Held.Done;
    Log^.Write( ll_Warning, Format(LoadString(_SCantCreLo), [LOName] ));
    Exit;
  end;
  Size := Held.GetSize;
  LO.Seek( LO.GetSize );
  GetMem( Buffer, Size );
  Held.Read( Buffer^, Size );
  if Held.Status = stOk then
  begin
    LO.Write( Buffer^, Size );
    if LO.Status = stOk then
      Result := True
    else
      Log^.Write( ll_Warning, Format(LoadString(_SCantAppendLo), [LOName] ));
  end
  else
    Log^.Write( ll_Warning, Format(LoadString(_SCantReadTempLo), [HeldName] ));
  FreeMem( Buffer );
  LO.Done;
  Held.Done;
end; { CopyAttach }

{ --------------------------------------------------------- }
{ UpdateAttach                                              }
{ --------------------------------------------------------- }

procedure UpdateAttach( Addr: TAddress; const TicName, TargetFile: String );
const
  FlavorExt: array [TFlavor] of String[3] = ( 'hlo', 'flo', 'dlo', 'clo', 'ilo' );
var
  Link  : PEchoLink;
  Bink  : String;
  LO    : String;
  Held  : String;
  Attach: PAttach;
begin
  Link := CFG^.Links^.Find( Addr );
  Log^.Write( ll_Protocol, Format(LoadString(_SUpdatingLo), [FlavorExt[Link^.Flavor], AddrToStr(Addr)] ));
  Bink := BuildBinkName( Addr );
  LO   := Bink + '.' + FlavorExt[Link^.Flavor];
  Held := Bink + '.hhh';
  if LockAddr( Bink ) then
  begin
    if FileExists( Held ) then
    begin
      Log^.Write( ll_Protocol, Format(LoadString(_SRestoringLo), [Held] ));
      if CopyAttach( Held, LO ) then
        VFS_EraseFile( Held );
    end;
  end
  else
    LO := Held;

  New( Attach, Init(20, 20) );
  try
    if FileExists( LO ) then
      Attach^.ReadFrom( LO );
    Attach^.AddFile( TargetFile );
    Attach^.AddFile( '^' + TicName );
    try
      Attach^.WriteTo( LO );
    except
      on E: Exception do
        ShowError( Format(LoadString(_SErrorSavingLo), [E.Message] ));
    end;
  finally
    Destroy( Attach );
  end;

  if LO <> Held then
    UnlockAddr( Bink );

end; { UpdateAttach }

{ --------------------------------------------------------- }
{ CreateFileBox                                             }
{ --------------------------------------------------------- }

function CreateFileBox( Link: PEchoLink; var FileBox: String ) : Boolean;
begin
  Result := False;

  if CFG^.FileBoxes = '' then
  begin
    ShowError( LoadString(_SFileBoxRootMissed) );
    Exit;
  end;

  with Link^.Addr do
    FileBox := AtPath(Format('%d.%d.%d.%d', [Zone, Net, Node, Point]), CFG^.FileBoxes);

  case Link^.Flavor of
    fl_hold  : FileBox := FileBox + '.h';
    fl_dir   : FileBox := FileBox + '.d';
    fl_crash : FileBox := FileBox + '.c';
    fl_imm   : FileBox := FileBox + '.i';
  end;

  Result := DirExists( FileBox ) or CreateDirTree( FileBox );

end; { CreateFileBox }

{ --------------------------------------------------------- }
{ LogTraffic                                                }
{ --------------------------------------------------------- }

procedure LogTraffic( Tic: PTic );
var
  S: TDosStream;
  R: record
       TimeStamp: UnixTime;
       Uplink   : TAddress;
       FileSize : Longint;
       TextSize : Longint;
     end;
begin
  if CFG^.TrafficLog <> '' then
  begin
    try
      if FileExists( CFG^.TrafficLog ) then
      begin
        S.Init( CFG^.TrafficLog, stOpenWrite );
        S.Seek( S.GetSize );
      end
      else
        S.Init( CFG^.TrafficLog, stCreate );

      if S.Status = stOk then
      begin
        R.TimeStamp := CurrentUnixTime;
        R.Uplink    := Tic^.FromAddr;
        R.FileSize  := Tic^.Size;
        R.TextSize  := Length(Tic^.FileName^) + Length(Tic^.AreaTag^) + 2;
        S.Write( R, SizeOf(R) );
        S.WriteStr( Tic^.FileName );
        S.WriteStr( Tic^.AreaTag );
      end;

      S.Done;

    except
     on E: Exception do
       Log^.Write( ll_Error, E.Message );
    end;
  end;
end; { LogTraffic }


{ --------------------------------------------------------- }
{ HandleTic                                                 }
{ --------------------------------------------------------- }

procedure HandleTic( const TicName: String );
var
  j   : Integer;
  Tic : PTic;
  Link: PEchoLink;
  Echo: PFileEcho;
  SourceFile : String;
  TargetFile : String;
  FileCRC    : Longint;
  ExportList : PAddrList;
  BSO_Used   : Boolean;
  AutoCreated: Boolean;

  { KillDupe ---------------------------------------------- }

  procedure KillDupe;
  begin
    Log^.Write( ll_Protocol, Format(LoadString(_SKillingDupe), [SourceFile] ));
    if not VFS_EraseFile( SourceFile ) then
      Log^.Write( ll_Warning, LoadString(_SFailed) );
    if not VFS_EraseFile( TicName ) then
      Log^.Write( ll_Warning, Format(LoadString(_SCantKillFile), [TicName] ));
    raise Exception.Create( LoadString(_SDupeKilled) );
  end; { KillDupe }

  { CheckDupe --------------------------------------------- }

  procedure CheckDupe;
  var
    Dup: Boolean;
  begin
    try
      Dup := FileExists( TargetFile ) and (GetFileCRC(TargetFile) = FileCRC);
    except
      on E: Exception do
        Log^.Write( ll_Warning, Format(LoadString(_SErrCalcCrc), [E.Message] ));
    end;
    if Dup then
    begin
      if TestBit( Echo^.Paranoia, bKeepDupes ) then
        Tic^.Reject( Format(LoadString(_SDupeFound), [TargetFile] ))
      else
        KillDupe;
    end;
  end; { CheckDupe }

  { AcceptTarget ------------------------------------------ }

  procedure AcceptTarget;
  var
    j: Integer;
{$IFDEF Win32}
    Path: String;
{$ENDIF}
  begin
    Log^.Write( ll_Protocol, Format(LoadString(_SAcceptingTarget), [Tic^.FileName^, Echo^.Name^] ));
    j := VFS_MoveFile( SourceFile, TargetFile );
    if j = 0 then
    begin
      if not Echo^.Passthrough then
      begin
{$IFDEF Win32}
        if Tic^.FullName <> nil then
        begin
          Path := ExtractFilePath( TargetFile );
          if VFS_RenameFile( TargetFile, AtPath(Tic^.FullName^, Path) ) then
          begin
            Log^.Write( ll_Protocol, Format(LoadString(_SExpandToLFN), [Tic^.FileName^, Tic^.FullName^] ));
            if VFS_GetShortName( AtPath(Tic^.FullName^, Path), TargetFile ) then
              ReplaceStr( Tic^.FileName, TargetFile );
          end;
        end;
{$ENDIF}
        Echo^.Area^.ReadFilesBbs;
        if Echo^.Area^.Search( Tic^.FileName, j ) then
          Echo^.Area^.AtFree( j );
        Echo^.Area^.Insert( Tic^.BuildFileDef );
        FileBase^.Modified := True;

        LogTraffic( Tic );

      end;
    end
    else
      Log^.Write( ll_Warning, Format(LoadString(_SErrorParking), [j, TargetFile] ));
  end; { AcceptTarget }

  { ApplyReplaces ----------------------------------------- }

  procedure ApplyReplaces;
  var
    j: Integer;
    Repl: String;
  begin
    if not TestBit( Echo^.Paranoia, bSkipRepl ) then
    begin
      if not HasWild( Tic^.Replaces^ ) then
      begin
        Repl := Echo^.Area^.Parking( Tic^.Replaces^ );
        if FileExists( Repl ) then
        begin
          if VFS_EraseFile( Repl ) then
          begin
            Log^.Write( ll_Protocol, Format(LoadString(_SReplacesKill), [Repl] ));
            Repl := ExtractFileName( Repl );
            if Echo^.Area^.Search( @Repl, j ) then
              Echo^.Area^.AtFree( j );
          end
          else
            Log^.Write( ll_Warning, Format(LoadString(_SReplacesFailed), [Repl] ));
        end;
      end
      else
        Log^.Write( ll_Warning, Format(LoadString(_SLogSkippingRepl), [Tic^.Replaces^] ));
    end;
  end; { ApplyReplaces }

  { UpdateMagic ------------------------------------------- }

  procedure UpdateMagic;
  var
    M: PMagic;
  begin
    FileBase^.LoadMagicList;
    if FileBase^.MagicList = nil then Exit;
    if FileBase^.MagicList^.Search( Tic^.Magic, j ) then
    begin
      M := FileBase^.MagicList^.At( j );
      if M^.Updt then
      begin
        ReplaceStr( M^.Path, TargetFile );
        FileBase^.MagicList^.Modified := True;
      end;
    end
    else
    begin
      New( M );
      FillChar( M^, SizeOf(M^), 0 );
      M^.Alias := AllocStr( Tic^.Magic^ );
      M^.Path  := AllocStr( TargetFile );
      M^.Updt  := True;
      FileBase^.MagicList^.AtInsert( j, M );
      FileBase^.MagicList^.Modified := True;
    end;
  end; { UpdateMagic }

  { AddSeenby --------------------------------------------- }

  procedure AddSeenby( A: PAddress ); far;
  var
    Downlink: PEchoLink;
  begin
    if (Tic^.Seenby^.IndexOf(A) < 0) and (CompAddr(A^, Tic^.Origin) <> 0) then
    begin
      Downlink := CFG^.Links^.Find( A^ );
      if (Downlink <> nil) and not (elo_Pause in Downlink^.Opt) then
      begin
        Tic^.Seenby^.Insert( NewAddr(A^) );
        ExportList^.Insert( NewAddr(A^) );
      end;
    end;
  end; { AddSeenby }

  { ExportTarget ------------------------------------------ }

  procedure ExportTarget( A: PAddress ); far;
  var
    Downlink: PEchoLink;
    FileBox : String;
  begin
    Downlink := CFG^.Links^.Find( A^ );
    if Downlink <> nil then
    begin
      if elo_FileBox in Downlink^.Opt then
      begin

        // Trying to use FileBox

        if CreateFileBox( Downlink, FileBox ) then
        begin
          if VFS_CopyFile( TargetFile, AtPath(TargetFile, FileBox) ) then
          begin
             Tic^.SaveTo( BuildTicName(A^, FileBox), A );
             Exit;
          end;
          Log^.Write( ll_Error,  Format(LoadString(_SCouldNotCopyToFileBox), [FileBox]) )
        end
        else
          Log^.Write( ll_Error, Format(LoadString(_SCouldNotCreateFileBox), [FileBox] ));

        Log^.Write( ll_Expand, Format(LoadString(_STryBso), [AddrToStr(A^)] ));

      end;

      // Using BSO

      BSO_Used := True;

      Tic^.SaveTo( BuildTicName(A^, CFG^.OutTicPath), A );
      UpdateAttach( A^, Tic^.TicName, TargetFile );
    end;
  end; { ExportTarget }

  { ApplyHook --------------------------------------------- }

  procedure ApplyHook( Hook: PString ); far;
  var
    Call: String;
    ErrCode: Integer;
  begin
    if Echo^.Hooks^.GetCall( ExtractFileName(TargetFile), Call ) then
    begin
      Log^.Write( ll_Protocol, Format(LoadString(_SHookExec), [Call] ));
      ErrCode := Execute( Call, TargetFile + ' ' +
                                ExtractFileName(TargetFile)  + ' ' +
                                ExtractFileExt (TargetFile)  + ' ' +
                                ExtractFilePath(TargetFile),
                          True );
      if ErrCode < 0 then
        Log^.Write( ll_Warning, Format(LoadString(_SExecError), [-ErrCode] ))
      else if ErrCode > 0 then
        Log^.Write( ll_Warning, Format(LoadString(_SErrRetCode), [ErrCode] ));
    end;
  end; { ApplyHook }

begin
  OpenFileBase;
  Log^.Write( ll_Service, Format(LoadString(_SLogEatTic), [ExtractFileName(TicName)] ));
  New( Tic, Init );
  try
    Tic^.LoadFrom( TicName );

    Log^.Write( ll_Protocol, Format(LoadString(_SLogTicHeader),
       [AddrToStr(Tic^.FromAddr), AddrToStr(Tic^.ToAddr),
        SafeStr(Tic^.FileName), SafeStr(Tic^.AreaTag), AddrToStr(Tic^.Origin)] ));

    if (CompAddr( Tic^.FromAddr, Tic^.ToAddr ) = 0) and
       (CompAddr( Tic^.FromAddr, Cfg^.PrimaryAddr ) = 0) then
    begin
      if JustSameText( Tic^.Pw^, CFG^.HatchPw ) then
      begin
        Link := nil;
        Log^.Write( ll_Protocol, LoadString(_SOurHatchedTic) );
        Echo := FileBase^.GetEcho( Tic^.AreaTag^ );
      end
      else
        Tic^.Reject( LoadString(_SBadHatchPw) );
    end
    else
    begin
      Link := CFG^.Links^.Find( Tic^.FromAddr );
      if Link = nil then
        Tic^.Reject( LoadString(_SSenderNotOurLink) );
      if (CompAddr(Tic^.ToAddr, ZERO_ADDR) <> 0) and
         (CompAddr( Tic^.ToAddr, Link^.OurAka ) <> 0) then
        Tic^.Reject( LoadString(_SNotOurTic) );
      if not JustSameText( Link^.Password^, Tic^.Pw^ ) then
        Tic^.Reject( LoadString(_SBadTicPw) );
      if Tic^.AreaTag = nil then
        Tic^.Reject( LoadString(_SNoEchoTag) );
      if Link^.Deny^.Match( Tic^.AreaTag^ ) then
        Tic^.Reject( LoadString(_SEchoDenied) );
    end;

    AutoCreated := False;
    Echo := FileBase^.GetEcho( Tic^.AreaTag^ );
    if Echo = nil then
    begin
      Echo := AutoCreate( Link, Tic );
      AutoCreated := True;
    end
    else
    begin
      if Echo^.State = es_Down then
        Tic^.Reject( LoadString(_SEchoDown) );
      if Echo^.State = es_Awaiting then
      begin
        Echo^.State := es_Alive;
        FileBase^.Modified := True;
      end;
    end;

    if Echo = nil then
      Tic^.Reject( Format(LoadString(_SEchoNotExists), [Tic^.AreaTag^] ));

    if Link <> nil then
    begin
      if not Echo^.Uplinks^.Search( @Link^.Addr, j ) then
      begin
        if elo_Autolink in Link^.Opt then
        begin
          Echo^.Uplinks^.Insert( NewAddr(Link^.Addr) );
          FileBase^.Modified := True;
          if not AutoCreated then
          begin
            Log^.Write( ll_Protocol, Format(LoadString(_SLogAutolinked),
              [AddrToStr( Link^.Addr ), Tic^.AreaTag^] ));
            Notify( Echo^.Name^, 'New uplink', Format(LoadString(_SMsgNewUplink),
            [AddrToStr(Link^.Addr)]));
          end
        end
        else
          Tic^.Reject( Format(LoadString(_SNotUplink), [AddrToStr(Link^.Addr), Echo^.Name^ ] ));
      end;
    end;

    if Tic^.FileName = nil then
      Tic^.Reject( LoadString(_SNoGlueFileName) );

    SourceFile := AtPath( Tic^.FileName^, CFG^.Inbound );
    if not FileExists( SourceFile ) then
      Tic^.Reject( Format(LoadString(_SNoGlueFile), [SourceFile] ));

    if FileGetAttr( SourceFile ) and faHidden <> 0 then
       raise Exception.Create( LoadString(_SGlueHidden) );

    try
      FileCRC := GetFileCRC( SourceFile );
    except
      on E: Exception do
        begin
          FileCRC := 0;
          if TestBit( Echo^.Paranoia, bCheckCRC ) then
            Tic^.Reject( Format(LoadString(_SUnableCRC), [E.Message] ))
          else
            Log^.Write( ll_Warning, Format(LoadString(_SUnableCRC), [E.Message] ) );
        end;
    end;

    if TestBit( Echo^.Paranoia, bCheckCRC ) and (Tic^.CRC <> FileCRC) then
      Tic^.Reject( Format(LoadString(_SCRCFailed), [IntToHex(FileCRC, 8)] ));

    if Echo^.Passthrough then
    begin
      if CFG^.Passthrough = '' then
        Tic^.Reject( LoadString(_SNoPasruDir) )
      else
        TargetFile := AtPath( Tic^.FileName^, CFG^.Passthrough )
    end
    else
      TargetFile := Echo^.Area^.Parking( Tic^.FileName^ );

    CheckDupe;

    if (Tic^.Replaces <> nil) and not Echo^.Passthrough then
      ApplyReplaces;

    AcceptTarget;

    if (Tic^.Magic <> nil) and not Echo^.Passthrough then
      UpdateMagic;

    Tic^.TimeStamp := CurrentFileTime;

    if Echo^.Downlinks^.Count > 0 then
    begin
      BSO_Used := False;
      New( ExportList, Init(10, 10) );
      Echo^.Downlinks^.ForEach( @AddSeenby );
      ExportList^.ForEach( @ExportTarget );
      Destroy( ExportList );
      if Echo^.Passthrough and not BSO_Used and not VFS_EraseFile(TargetFile) then
        Log^.Write( ll_Warning, Format(LoadString(_SCantKillFile), [TargetFile] ));
    end;

    Echo^.Hooks^.ForEach( @ApplyHook );

    if not VFS_EraseFile( TicName ) then
      Log^.Write( ll_Warning, Format(LoadString(_SCantKillFile), [TicName] ));

  except
    on E: Exception do
      Log^.Write( ll_Warning, E.Message );
  end;
  Destroy( Tic );
  Log^.Write( ll_Protocol, LoadString(_SLogTicPassed) );
end; { HandleTic}

{ --------------------------------------------------------- }
{ CleanPassthrough                                          }
{ --------------------------------------------------------- }

procedure CleanPassthrough;
var
  R: TSearchRec;
  Files   : PNoCaseStrCollection;
  DosError: Integer;

  procedure CheckAttach( const FileName: String );
  var
    j : Integer;
    S : String;
    LO: TMappedFile;
  begin
    LO.Init( FileName );
    while LO.GetLine( S ) do
    begin
      if S <> '' then
      begin
        if S[1] in ['^', '#'] then
          System.Delete( S, 1, 1 );
        if Files^.Search( @S, j ) then
          Files^.AtFree( j );
      end;
    end;
    LO.Done;
  end; { CheckAttach }

  procedure Scan_BSO( const RootFolder: String ); far;
  var
    R: TSearchRec;
    DosError: Integer;
  begin
    DosError := SysUtils.FindFirst( AtPath('*.?LO', RootFolder), faArchive, R );
    while DosError = 0 do
    begin
      CheckAttach( AtPath(R.Name, RootFolder) );
      DosError := SysUtils.FindNext( R );
    end;
    SysUtils.FindClose( R );

    DosError := SysUtils.FindFirst( AtPath('*.PNT', RootFolder), faDirectory, R );
    while DosError = 0 do
    begin
      Scan_BSO( AtPath(R.Name, RootFolder) );
      DosError := SysUtils.FindNext( R );
    end;
    SysUtils.FindClose( R );
  end; { Scan_BSO }

  procedure KillFile( P: PString ); far;
  begin
    if VFS_EraseFile( P^ ) then
      Log^.Write( ll_Protocol, Format(LoadString(_SLogFileDied), [P^] ))
    else
      Log^.Write( ll_Warning, Format(LoadString(_SLogFileNotDied), [P^] ));
  end; { KillFile }

begin
  if CFG^.Passthrough = '' then Exit;
  New( Files, Init(50, 50) );
  DosError := SysUtils.FindFirst( AtPath('*.*', CFG^.Passthrough), faArchive + faReadOnly, R );
  while DosError = 0 do
  begin
    Files^.Insert( AllocStr( AtPath(R.Name, CFG^.Passthrough) ));
    DosError := SysUtils.FindNext( R );
  end;
  SysUtils.FindClose( R );
  try
    if Files^.Count > 0 then
    begin
      Log^.Write( ll_Protocol, LoadString(_SLogCleanPasru) );
      Scan_BSO( CFG^.Outbound );
      Files^.ForEach( @KillFile );
    end;
  finally
    Destroy( Files );
  end;
end; { CleanPassthrough }

{ --------------------------------------------------------- }
{ RunTicTosser                                              }
{ --------------------------------------------------------- }

procedure RunTicTosser;
var
  R: TSearchRec;
  DosError: Integer;

  procedure DoComplete( A: PFileArea ); far;
  begin
    if A^.Loaded then
      A^.Complete;
  end; { DoComplete }

begin
  Log^.Write( ll_Service, LoadString(_SLogTicTosserStart) );
  CleanPassthrough;
  DosError := SysUtils.FindFirst( AtPath('*.tic', CFG^.Inbound), faArchive + faReadOnly, R );
  while DosError = 0 do
  begin
    HandleTic( AtPath( R.Name, CFG^.Inbound ) );
    DosError := SysUtils.FindNext( R );
  end;
  SysUtils.FindClose( R );
  if (FileBase <> nil) and FileBase^.Modified then
  begin
    FileBase^.ForEach( @DoComplete );
    FileBase^.WriteFilesBbs;
  end;
  Log^.Write( ll_Service, LoadString(_SLogTicTosserStop) );
end; { RunTicTosser }

end.
