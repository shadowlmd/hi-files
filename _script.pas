unit _Script;

/////////////////////////////////////////////////////////////////////
//
// Hi-Files Version 2
// Copyright (c) 1997-2004 Dmitry Liman [2:461/79]
//
// http://hi-files.narod.ru
//
/////////////////////////////////////////////////////////////////////

interface

uses Objects, _Report, _CFG;

procedure ExecuteScript( ScriptName: String; Report: PReport; Poster: PPoster );

{ =================================================================== }

implementation

uses
{$IFDEF Win32}
  Windows,
{$ENDIF}
  MyLib, SysUtils, App, _MapFile, _LOG, _FAreas, Eval, MsgAPI, _Inspector,
  _RES, vpUtils;

type
  TOperator = ( op_None, op_Include, op_Print, op_Assign,
    op_AreaLoop, op_FileLoop, op_EndAreaLoop, op_EndFileLoop,
    op_If, op_Else, op_EndIf, op_While, op_EndWhile, op_Break,
    op_DeclareInt, op_DeclareFloat, op_DeclareBool, op_DeclareStr,
    op_NewArea, op_Copy, op_Reformat, op_Cancel, op_Redirect,
    op_PrintFile );

  TOpSet = set of TOperator;

  PFrame = ^TFrame;
  TFrame = record
    Mode: TOperator;
    Ret : Integer;
  end; { TFrame }

const
  QUERY_THRESHOLD = 100;
  MAX_FRAMES  = 20;
  MAX_CACHE   = 10000;
  BLOCK_OPEN  = [ op_AreaLoop, op_FileLoop, op_If, op_While ];
  BLOCK_CLOSE = [ op_EndAreaLoop, op_EndFileLoop, op_EndIf, op_EndWhile ];


type
  PCacheItem = ^TCacheItem;
  TCacheItem = record
    op  : TOperator;
    sym : Integer;
  end; { TCacheItem }

  PCache = ^TCache;
  TCache = array [1..MAX_CACHE] of PCacheItem;

type
  PScript = ^TScript;
  TScript = object (TExpression)
    constructor Init( const FileName: String );
    destructor Done; virtual;
    procedure Run( OutputReport: PReport );
    procedure SetupPosterVars( Poster: PPoster );
  private
    Text  : PStrings;
    Line  : PString;
    Finger: Integer;
    Symbol: Integer;
    Cache : PCache;     // 1-based !!!
    Report: PReport;
    Area  : PFileArea;
    AreaNo: Integer;
    FileNo: Integer;
    Frames: array [0..MAX_FRAMES] of TFrame;
    BlockLevel: Integer;
    Inspector : PInspector;
    Threshold : Integer;

    procedure SetupGlobals;
    function  GetLine: Boolean;
    function  GetOperator: TOperator;
    procedure PrintValue( var V: TValue );
    procedure Execute( const S: String; var V: TValue );

    function  Frame: PFrame;
    procedure Jump( Where: Integer );
    function  JumpOver( Term: TOpSet ) : TOperator;
    function  Nested( op: TOperator ) : Boolean;
    function  BlockEntrance( Op: TOperator ) : TOperator;
    function  BlockExit( Op: TOperator ) : TOperator;
    procedure EnterBlock( Op: TOperator );
    procedure LeaveBlock;
    procedure ReEnter( Op: TOperator );

    procedure CreateAreaFrame;
    procedure UpdateAreaFrame;
    procedure ReleaseAreaFrame;
    procedure CreateFileFrame;
    procedure UpdateFileFrame;
    procedure ReleaseFileFrame;

    procedure __Declare( vt: TValueType );
    procedure __Print;
    procedure __Assign;
    procedure __AreaLoop;
    procedure __FileLoop;
    procedure __EndAreaLoop;
    procedure __EndFileLoop;
    procedure __If;
    procedure __Else;
    procedure __EndIf;
    procedure __While;
    procedure __EndWhile;
    procedure __Break;
    procedure __Include;
    procedure __NewArea;
    procedure __Copy;
    procedure __Reformat;
    procedure __Cancel;
    procedure __Redirect;
    procedure __PrintFile;
  end; { TScript }

var
  FD: PFileDef;
  KillFileDef: Boolean;

{$I _EXTFUN.PAS}

{ --------------------------------------------------------- }
{ TScript                                                   }
{ --------------------------------------------------------- }

{ Init ---------------------------------------------------- }

constructor TScript.Init( const FileName: String );
var
  S: String;
  Map: TMappedFile;
begin
  inherited Init;
  if not FileExists( FileName ) then
  begin
    ShowError( Format(LoadString(_SFileNotFound), [FileName] ));
    inherited Done;
    Fail;
  end;
  New( Text, Init(100, 100) );
  Map.Init( FileName );
  while Map.GetLine(S) do
  begin
    S := Trim(S);
    if S <> '' then
      Text^.Insert( AllocStr(S) );
  end;
  Map.Done;
  GetMem( Cache, Text^.Count * SizeOf(Pointer) );
  FillChar( Cache^, Text^.Count * SizeOf(Pointer), 0 );
  SetupGlobals;
  New( Inspector, Init( FileName ) );
  Desktop^.Insert( Inspector );
  if doScript in CFG^.Debug then
    Log^.Write( ll_Debug, LoadString(_SScriptInitComplete) );
end; { Init }

{ Done ---------------------------------------------------- }

destructor TScript.Done;
var
  j: Integer;
begin
  for j := 1 to Text^.Count do
    if Cache^[j] <> nil then
      Dispose( Cache^[j] );
  FreeMem( Cache );
  Destroy( Text );
  Destroy( Inspector );
  inherited Done;
  if doScript in CFG^.Debug then
    Log^.Write( ll_Debug, LoadString(_SScriptDoneComplete) );
end; { Done }

{ Jump ---------------------------------------------------- }

procedure TScript.Jump( Where: Integer );
begin
  Finger := Where;
end; { Jump }

{ GetLine ------------------------------------------------- }

function TScript.GetLine: Boolean;
begin
  Result := False;
  if Finger >= Text^.Count then Exit;
  Line := Text^.At(Finger);
  Inc(Finger);
  Result := True;
end; { GetLine }

{ Run ----------------------------------------------------- }

procedure TScript.Run( OutputReport: PReport );
var
  Op: TOperator;
begin
  Report := OutputReport;
  Jump( 0 );
  while GetLine do
  begin
    if doTrace in CFG^.Debug then
      Inspector^.UpdateExec( Line );
    if doScript in CFG^.Debug then
      Log^.Write( ll_Debug, 'Trace: {' + Line^ + '}' );
    Op := GetOperator;
    case Op of
      op_Print        : __Print;
      op_If           : __If;
      op_Else         : __Else;
      op_EndIf        : __EndIf;
      op_Reformat     : __Reformat;
      op_FileLoop     : __FileLoop;
      op_EndFileLoop  : __EndFileLoop;
      op_Assign       : __Assign;
      op_AreaLoop     : __AreaLoop;
      op_EndAreaLoop  : __EndAreaLoop;
      op_While        : __While;
      op_EndWhile     : __EndWhile;
      op_Copy         : __Copy;
      op_Break        : __Break;
      op_DeclareInt   : __Declare( val_integer );
      op_DeclareFloat : __Declare( val_float );
      op_DeclareBool  : __Declare( val_bool );
      op_DeclareStr   : __Declare( val_string );
      op_Include      : __Include;
      op_NewArea      : __NewArea;
      op_Cancel       : __Cancel;
      op_Redirect     : __Redirect;
      op_PrintFile    : __PrintFile;
    else
      raise Exception.Create( Format(LoadString(_SBadOperator), [Line^] ));
    end;
  end;
end; { Run }

{ SetupGlobals -------------------------------------------- }

procedure TScript.SetupGlobals;
begin
  RegisterFunction( 'Pad',       val_string,  'SI',  @F_Pad );
  RegisterFunction( 'PadCh',     val_string,  'SIS', @F_PadCh );
  RegisterFunction( 'LeftPad',   val_string,  'SI',  @F_LeftPad );
  RegisterFunction( 'LeftPadCh', val_string,  'SIS', @F_LeftPadCh );
  RegisterFunction( 'ASRF',      val_string,  'F',   @F_ASRF );
  RegisterFunction( 'IntToStr',  val_string,  'I',   @F_IntToStr );
  RegisterFunction( 'IntToStrZ', val_string,  'II',  @F_IntToStrZ );
  RegisterFunction( 'Center',    val_string,  'SI',  @F_Center );
  RegisterFunction( 'CenterCh',  val_string,  'SIS', @F_CenterCh );
  RegisterFunction( 'Random',    val_integer, 'I',   @F_Random );
  RegisterFunction( 'Substr',    val_string,  'SII', @F_Substr );
  RegisterFunction( 'CharStr',   val_string,  'SI',  @F_CharStr );
  RegisterFunction( 'Length',    val_integer, 'S',   @F_Length );
  RegisterFunction( 'Match',     val_bool,    'SS',  @F_Match );
  RegisterFunction( 'FileTime',  val_float,   '',    @F_FileTime );
  RegisterFunction( 'FormatDT',  val_string,  'SF',  @F_FormatDT );
  RegisterFunction( 'Now',       val_float,   '',    @F_Now );
  RegisterFunction( 'Trim',      val_string,  'S',   @F_Trim );
  RegisterFunction( 'TrimR',     val_string,  'S',   @F_TrimR );
  RegisterFunction( 'TrimL',     val_string,  'S',   @F_TrimL );

  RegisterFunction( 'JustFilename', val_string, 'S', @F_JustFileName );

  RegisterFunction( 'FileComment', val_string, '', @F_FileComment );
  RegisterFunction( 'DescMissing', val_bool,   '', @F_DescMissing );

  CreateVar( 'SoftName',    val_string );
  CreateVar( 'SoftVer',     val_string );
  CreateVar( 'Platform',    val_string );
  CreateVar( 'PrimaryAddr', val_string );
  CreateVar( 'Today',       val_string );
  CreateVar( 'Age',         val_integer );
  CreateVar( 'TotalFiles',  val_integer );
  CreateVar( 'TotalBytes',  val_float );

  SetVarString( 'SoftName',    PROG_NAME );
  SetVarString( 'SoftVer',     PROG_VER );
  SetVarString( 'Platform',    PLATFORM );
  SetVarString( 'PrimaryAddr', AddrToStr(CFG^.PrimaryAddr) );
  SetVarString( 'Today',       GetFileDateStr(CurrentFileTime) );
  SetVarInt   ( 'Age',         CFG^.NewFilesAge );
  SetVarInt   ( 'TotalFiles',  FileBase^.TotalFiles );
  SetVarFloat ( 'TotalBytes',  FileBase^.TotalBytes );

  Area   := nil;
  FD     := nil;
  AreaNo := 0;
  FileNo := 0;
  BlockLevel := -1;

end; { SetupGlobals }

{ SetupPosterVars ----------------------------------------- }

procedure TScript.SetupPosterVars( Poster: PPoster );
begin
  CreateVar( 'FirstName', val_string );
  CreateVar( 'LastName',  val_string );
  CreateVar( 'Subj',      val_string );
  CreateVar( 'OrigAddr',  val_string );

  SetVarString( 'FirstName', ExtractWord( 1, Poster^._To, BLANK ) );
  SetVarString( 'LastName',  ExtractWord( WordCount(Poster^._To, BLANK), Poster^._To, BLANK ));
  SetVarString( 'Subj',      Poster^.Subj );
  SetVarString( 'OrigAddr',  AddrToStr(Poster^.Orig) );
end; { SetupPosterVars }

{ FRAME VARIABLES ----------------------------------------- }

const
  // FileLoop Frame
  VAR_FILENAME    = 'FileName';
  VAR_LONGNAME    = 'LongName';
  VAR_HASLONGNAME = 'HasLongName';
  VAR_FILESIZE    = 'FileSize';
  VAR_FILEDLC     = 'FileDLC';
  VAR_ENTRYNO     = 'EntryNo';
  VAR_FILEDATE    = 'FileDate';
  VAR_ALONECMT    = 'AloneCmt';
  VAR_MISSING     = 'Missing';
  VAR_FDLINES     = 'FD_Lines';
  VAR_MAGIC       = 'Magic';
  VAR_TEXTWIDTH   = 'TextWidth';

  // AreaLoop Frame
  VAR_AREANO     = 'AreaNo';
  VAR_AREANAME   = 'AreaName';
  VAR_REMOVABLE  = 'Removable';
  VAR_AREAFILES  = 'AreaFiles';
  VAR_AREABYTES  = 'AreaBytes';
  VAR_AREACOUNT  = 'AreaCount';
  VAR_GROUPTAG   = 'GroupTag';
  VAR_VIRTUAL    = 'Virtual';
  VAR_GROUPFILES = 'GroupFiles';
  VAR_GROUPBYTES = 'GroupBytes';
  VAR_HOMEDIR    = 'HomeDir';

{ CreateFileFrame ----------------------------------------- }

procedure TScript.CreateFileFrame;
begin
  if doScript in CFG^.Debug then
    Log^.Write( ll_Debug, LoadString(_SEnterFileFrame) );
  CreateVar( VAR_FILENAME,    val_string );
  CreateVar( VAR_LONGNAME,    val_string );
  CreateVar( VAR_HASLONGNAME, val_bool );
  CreateVar( VAR_FILESIZE,    val_integer );
  CreateVar( VAR_FILEDLC,     val_integer );
  CreateVar( VAR_ENTRYNO,     val_integer );
  CreateVar( VAR_FILEDATE,    val_string );
  CreateVar( VAR_ALONECMT,    val_bool );
  CreateVar( VAR_MISSING,     val_bool );
  CreateVar( VAR_FDLINES,     val_integer );
  CreateVar( VAR_MAGIC,       val_string );
  CreateVar( VAR_TEXTWIDTH,   val_integer );
  if doScript in CFG^.Debug then
    Log^.Write( ll_Debug, LoadString(_SLeaveFileFrame) );
end; { CreateFileFrame }

{ UpdateFileFrame ----------------------------------------- }

procedure TScript.UpdateFileFrame;
begin
  if FD^.AloneCmt then
  begin
    if doScript in CFG^.Debug then
      Log^.Write( ll_Debug, LoadString(_SUpdateFileFrameAlone) );
    SetVarString( VAR_FILENAME, '' );
    SetVarString( VAR_LONGNAME, '' );
    SetVarBool  ( VAR_HASLONGNAME, False );
    SetVarInt   ( VAR_FILESIZE, 0 );
    SetVarInt   ( VAR_FILEDLC, 0 );
    SetVarString( VAR_FILEDATE, '' );
    SetVarBool  ( VAR_MISSING, False );
  end
  else
  begin
    if doScript in CFG^.Debug then
      Log^.Write( ll_Debug, Format(LoadString(_SUpdateFileFrameFile), [FD^.NativeName^] ));
    SetVarString( VAR_FILENAME,    FD^.FileName^ );
    SetVarBool  ( VAR_MISSING,     FD^.Missing );
    SetVarInt   ( VAR_FILESIZE,    FD^.Size );
    SetVarInt   ( VAR_FILEDLC,     FD^.DLC );
    if FD^.Missing then
    begin
      SetVarString( VAR_LONGNAME, '' );
      SetVarBool  ( VAR_HASLONGNAME, False );
      SetVarString( VAR_FILEDATE, '' );
    end
    else
    begin
      SetVarString( VAR_LONGNAME,    FD^.LongName^ );
      SetVarBool  ( VAR_HASLONGNAME, (FD^.LongName^ <> '') and
                    not JustSameText( FD^.LongName^, FD^.FileName^ ));
      SetVarString( VAR_FILEDATE,    GetFileDateStr(FD^.Time) );
    end;
    if FD^.Magic = nil then
      SetVarString( VAR_MAGIC, '' )
    else
      SetVarString( VAR_MAGIC, FD^.Magic^.Alias^ );
  end;
  SetVarInt ( VAR_FDLINES,   FD^.Count );
  SetVarBool( VAR_ALONECMT,  FD^.AloneCmt );
  SetVarInt ( VAR_ENTRYNO,   FileNo+1 );
  SetVarInt ( VAR_TEXTWIDTH, FD^.TextWidth );
  Inspector^.Update( AreaNo, FileNo );
  if doScript in CFG^.Debug then
    Log^.Write( ll_Debug, LoadString(_SUpdateFileFrameCompl) );
end; { UpdateFileFrame }

{ ReleaseFileFrame ---------------------------------------- }

procedure TScript.ReleaseFileFrame;
begin
  if doScript in CFG^.Debug then
    Log^.Write( ll_Debug, LoadString(_SEnterRelFileFrame) );
  DropVar( VAR_FILENAME );
  DropVar( VAR_LONGNAME );
  DropVar( VAR_HASLONGNAME );
  DropVar( VAR_FILESIZE );
  DropVar( VAR_FILEDLC );
  DropVar( VAR_ENTRYNO );
  DropVar( VAR_FILEDATE );
  DropVar( VAR_ALONECMT );
  DropVar( VAR_MISSING );
  DropVar( VAR_FDLINES );
  DropVar( VAR_MAGIC );
  DropVar( VAR_TEXTWIDTH );
  if doScript in CFG^.Debug then
    Log^.Write( ll_Debug, LoadString(_SExitRelFileFrame) );
end; { ReleaseFileFrame }

{ CreateAreaFrame ----------------------------------------- }

procedure TScript.CreateAreaFrame;
begin
  if doScript in CFG^.Debug then
    Log^.Write( ll_Debug, LoadString(_SEnterCreAreaFrame) );
  CreateVar( VAR_AREANO,     val_integer );
  CreateVar( VAR_AREANAME,   val_string );
  CreateVar( VAR_REMOVABLE,  val_bool );
  CreateVar( VAR_AREAFILES,  val_integer );
  CreateVar( VAR_AREABYTES,  val_float );
  CreateVar( VAR_AREACOUNT,  val_integer );
  CreateVar( VAR_GROUPTAG,   val_string );
  CreateVar( VAR_VIRTUAL,    val_bool );
  CreateVar( VAR_GROUPFILES, val_integer );
  CreateVar( VAR_GROUPBYTES, val_float );
  CreateVar( VAR_HOMEDIR,    val_string );
  if doScript in CFG^.Debug then
    Log^.Write( ll_Debug, LoadString(_SExitCreAreaFrame) );
end; { CreateAreaFrame }

{ UpdateAreaFrame ----------------------------------------- }

procedure TScript.UpdateAreaFrame;
var
  Group: PFileGroup;
begin
  if doScript in CFG^.Debug then
    Log^.Write( ll_Debug, Format(LoadString(_SEnterUpdtAreaFrame), [Area^.Name^] ));
  Group := FileBase^.Groups^.FindGroup( Area^.Group );
  SetVarInt   ( VAR_AREANO,     AreaNo+1 );
  SetVarString( VAR_AREANAME,   Area^.Name^ );
  SetVarBool  ( VAR_REMOVABLE,  Area^.Removable );
  SetVarInt   ( VAR_AREAFILES,  Area^.FoundFiles );
  SetVarFloat ( VAR_AREABYTES,  Area^.FoundBytes );
  SetVarInt   ( VAR_AREACOUNT,  Area^.Count );
  SetVarString( VAR_GROUPTAG,   Area^.Group^ );
  SetVarBool  ( VAR_VIRTUAL,    Area^.Virt );
  SetVarInt   ( VAR_GROUPFILES, Group^.Files );
  SetVarFloat ( VAR_GROUPBYTES, Group^.Bytes );
  if Area^.Virt then
    SetVarString( VAR_HOMEDIR, '<virtual>' )
  else
    SetVarString( VAR_HOMEDIR,    Area^.Parking('') );
  Inspector^.Update( AreaNo, -1 );
  if doScript in CFG^.Debug then
    Log^.Write( ll_Debug, LoadString(_SExitUpdtAreaFrame) );
end; { UpdateAreaFrame }

{ ReleaseAreaFrame ---------------------------------------- }

procedure TScript.ReleaseAreaFrame;
begin
  if doScript in CFG^.Debug then
    Log^.Write( ll_Debug, LoadString(_SEnterRelAreaFrame) );
  DropVar( VAR_AREANO );
  DropVar( VAR_AREANAME );
  DropVar( VAR_REMOVABLE );
  DropVar( VAR_AREAFILES );
  DropVar( VAR_AREABYTES );
  DropVar( VAR_AREACOUNT );
  DropVar( VAR_GROUPTAG );
  DropVar( VAR_VIRTUAL );
  DropVar( VAR_GROUPFILES );
  DropVar( VAR_GROUPBYTES );
  DropVar( VAR_HOMEDIR );
  if doScript in CFG^.Debug then
    Log^.Write( ll_Debug, LoadString(_SExitRelAreaFrame) );
end; { ReleaseAreaFrame }

{ GetOperator --------------------------------------------- }

function TScript.GetOperator: TOperator;

  procedure MakeCache;
  begin
    Cache^[Finger] := New( PCacheItem );
    with Cache^[Finger]^ do
    begin
      op  := Result;
      sym := Symbol;
    end;
  end; { MakeCache }

var
  S: String;
  Start: Integer;
  Stop : Integer;
begin
  Inc( Threshold );
  if Threshold > QUERY_THRESHOLD then
  begin
    Threshold := 0;
    if Inspector^.QueryCancel then
      __Cancel;
  end;

  if Cache^[Finger] <> nil then
    with Cache^[Finger]^ do
    begin
      Result := op;
      Symbol := sym;
      Exit;
    end;

  Result := op_None;
  Symbol := 0;
  if (Length(Line^) < 3) or (Line^[1] <> '/') or (Line^[2] <> '/') then
    Result := op_Print
  else
  begin
    Start := SkipR( Line^[1], 2, Length(Line^), ' ' );
    if Start < Length(Line^) then
    begin
      Stop := ScanR( Line^[1], Start, Length(Line^), ' ' );
      S := Copy( Line^, Start + 1, Stop - Start );
      if JustSameText( 'If', S ) then
        Result := op_If
      else if JustSameText( 'Else', S ) then
        Result := op_Else
      else if JustSameText( 'EndIf', S ) then
        Result := op_EndIf
      else if JustSameText( 'Reformat', S ) then
        Result := op_Reformat
      else if JustSameText( 'EndFileLoop', S ) then
        Result := op_EndFileLoop
      else if JustSameText( 'FileLoop', S ) then
        Result := op_FileLoop
      else if JustSameText( 'EndAreaLoop', S ) then
        Result := op_EndAreaLoop
      else if JustSameText( 'AreaLoop', S ) then
        Result := op_AreaLoop
      else if JustSameText( 'While', S ) then
        Result := op_While
      else if JustSameText( 'EndWhile', S ) then
        Result := op_EndWhile
      else if JustSameText( 'Copy', S ) then
        Result := op_Copy
      else if JustSameText( 'Break', S ) then
        Result := op_Break
      else if JustSameText( 'Integer', S ) then
        Result := op_DeclareInt
      else if JustSameText( 'String', S ) then
        Result := op_DeclareStr
      else if JustSameText( 'Float', S ) then
        Result := op_DeclareFloat
      else if JustSameText( 'Bool', S ) then
        Result := op_DeclareBool
      else if JustSameText( 'Include', S ) then
        Result := op_Include
      else if JustSameText( 'NewArea', S ) then
        Result := op_NewArea
      else if JustSameText( 'Cancel', S ) then
        Result := op_Cancel
      else if JustSameText( 'Redirect', S ) then
        Result := op_Redirect
      else if JustSameText( 'PrintFile', S ) then
        Result := op_PrintFile
      else
      begin
        Result := op_Assign;
        Symbol := Start;
        MakeCache;
        Exit;
      end;
      if Stop < Length(Line^) then
        Stop := SkipR( Line^[1], Stop, Length(Line^), ' ' );
      Symbol := Succ(Stop);
    end;
  end;
  MakeCache;
end; { GetOperator }

{ __Print ------------------------------------------------- }

procedure TScript.__Print;
var
  V: TValue;
begin
  if Line^ = '' then
  begin
    V.ValType := val_String;
    V.StringValue := '';
  end
  else
    Execute( Line^, V );
  PrintValue( V );
end; { __Print }

{ __Assign ------------------------------------------------ }

procedure TScript.__Assign;
var
  S: String;
  V: TValue;
begin
  S := Copy( Line^, Symbol, Length(Line^) );
  Execute( S, V );
end; { __Assign }

{ __Reformat ---------------------------------------------- }

procedure TScript.__Reformat;
var
  S: String;
  W: String;
  Margin : Integer;
  NewDef : PFileDef;
begin
  if FD = nil then
    raise Exception.Create( LoadString(_SReformatOutsideFLoop) );
  Margin := StrToInt( Copy(Line^, Symbol, Length(Line^)) );
  if FD^.Count <> 1 then Exit;
  FD^.GoTop;
  if not FD^.GetLine( S ) then Exit;
  FD^.GoTop;
  if Length( S ) <= Margin then Exit;
  NewDef := FD^.Dupe;
  NewDef^.FreeAll;
  repeat
    WordWrap( S, W, S, Margin, False );
    NewDef^.Append( W );
  until S = '';
  SetVarInt( VAR_FDLINES, NewDef^.Count );
  SetVarInt( VAR_TEXTWIDTH, NewDef^.TextWidth );
  FD := NewDef;
  KillFileDef := True;
end; { __Reformat }

{ __FileLoop ---------------------------------------------- }

procedure TScript.__FileLoop;
begin
  if Nested( op_FileLoop ) then
    raise Exception.Create( LoadString(_SNestedFLoop) );

  EnterBlock( op_FileLoop );

  if Area = nil then
    raise Exception.Create( LoadString(_SOrphanFLoop) );

  if FD = nil then
  begin
    FileNo := 0;
    CreateFileFrame;
  end
  else
  begin
    Inc( FileNo );
    if KillFileDef then
    begin
      Destroy( FD );
      KillFileDef := False;
    end;
  end;

  if FileNo < Area^.Count then
  begin
    FD := Area^.At(FileNo);
    FD^.GoTop;
    UpdateFileFrame;
  end
  else
  begin
    FD := nil;
    ReleaseFileFrame;
    JumpOver( [op_EndFileLoop] );
  end;
end; { __FileLoop }

{ __AreaLoop ---------------------------------------------- }

procedure TScript.__AreaLoop;
begin
  if Nested( op_AreaLoop ) then
    raise Exception.Create( LoadString(_SNestedALoop) );

  EnterBlock( op_AreaLoop );

  KillFileDef := False;

  if Area = nil then
  begin
    AreaNo := 0;
    CreateAreaFrame;
  end
  else
    Inc( AreaNo );

  if AreaNo < FileBase^.Count then
  begin
    Area := FileBase^.At(AreaNo);
    UpdateAreaFrame;
  end
  else
  begin
    Area := nil;
    ReleaseAreaFrame;
    JumpOver( [op_EndAreaLoop] );
  end;
end; { __AreaLoop }

{ __EndFileLoop ------------------------------------------- }

procedure TScript.__EndFileLoop;
begin
  ReEnter( op_EndFileLoop );
end; { __EndFileLoop }

{ __EndAreaLoop ------------------------------------------- }

procedure TScript.__EndAreaLoop;
begin
  ReEnter( op_EndAreaLoop );
end; { __EndAreaLoop }

{ __If ---------------------------------------------------- }

procedure TScript.__If;
var
  E: String;
  V: TValue;
begin
  E := Copy( Line^, Symbol, Length(Line^) );
  Execute( E, V );
  if V.ValType <> val_Bool then
    raise Exception.Create( LoadString(_SIfNotBool) );
  EnterBlock( op_If );
  if not V.BoolValue then
  begin
    if JumpOver( [op_else, op_endif] ) = op_else then
      EnterBlock( op_else );
  end;
end; { __If }

{ __Else -------------------------------------------------- }

procedure TScript.__Else;
begin
  if Frame^.Mode <> op_if then
    raise Exception.Create( LoadString(_SOrphanElse) );
  JumpOver( [op_EndIf] );
end; { __Else }

{ __EndIf ------------------------------------------------- }

procedure TScript.__EndIf;
begin
  if not (Frame^.Mode in [op_if, op_else]) then
    raise Exception.Create( LoadString(_SOrphanEndif) );
  LeaveBlock;
end; { __EndIf }

{ __Declare ----------------------------------------------- }

procedure TScript.__Declare( vt: TValueType );
const
  COMMA = [','];
var
  S: String;
  K: String;
  j: Integer;
  n: Integer;
begin
  S := Copy( Line^, Symbol, Length(Line^) );
  n := WordCount( S, COMMA );
  if n = 0 then
    raise Exception.Create( LoadString(_SEmptyDecList) );
  for j := 1 to n do
  begin
    K := Trim(ExtractWord( j, S, COMMA ));
    CreateVar( K, vt );
  end;
end; { __Declare }

{ __While ------------------------------------------------- }

procedure TScript.__While;
var
  E: String;
  V: TValue;
begin
  E := Copy( Line^, Symbol, Length(Line^) );
  Execute( E, V );
  if V.ValType <> val_bool then
    raise Exception.Create( LoadString(_SWhileNotBool) );
  EnterBlock( op_While );
  if not V.BoolValue then
    JumpOver( [op_EndWhile] );
end; { __While }

{ __EndWhile ---------------------------------------------- }

procedure TScript.__EndWhile;
begin
  if Frame^.Mode <> op_While then
    raise Exception.Create( LoadString(_SOrphanWhile) );
  Jump( Frame^.Ret );
  LeaveBlock;
end; { __EndWhile }

{ __Break ------------------------------------------------- }

procedure TScript.__Break;
var
  S: String;
  Skip: Integer;
  Over: TOperator;
begin
  S := Trim(Copy(Line^, Symbol, Length(Line^)));
  if S = '' then
    Skip := 1
  else
    Skip := StrToInt(S);

  while Skip > 0 do
  begin
    if BlockLevel < 0 then
      raise Exception.Create( LoadString(_SNoBlockBreak) );
    Over := BlockExit( Frame^.Mode );
    if Over <> op_EndIf then Dec( Skip );
    JumpOver( [Over] );
    if Over = op_FileLoop then
      ReleaseFileFrame
    else if Over = op_AreaLoop then
      ReleaseAreaFrame;
  end;
end; { __Break }

{ __Cancel ------------------------------------------------ }

procedure TScript.__Cancel;
begin
  Report^.Cancel;
  raise Exception.Create( LoadString(_SScriptCancelled) );
end; { __Cancel }

{ __NewArea ----------------------------------------------- }

procedure TScript.__NewArea;
label
  Failure;
var
  j: Integer;
  S: String;
  A: PFileArea;
  AreaName: String;
  Sorted  : Boolean;
  Group   : String;
begin
  AreaName := GetLiterals( Line^, Symbol, j );
  if AreaName = '' then goto Failure;
  if FileBase^.GetArea( AreaName ) <> nil then
    raise Exception.Create( Format(LoadString(_SNewAreaDupe), [AreaName] ));
  Sorted := False;
  Group  := '';
  while j <= Length(Line^) do
  begin
    SkipWhiteSpace( Line^, j );
    S := GetRightID( Line^, j, j );
    SkipWhiteSpace( Line^, j );
    if JustSameText( S, 'Group' ) then
      Group := GetLiterals( Line^, j, j )
    else if JustSameText( S, 'Sorted' ) then
      Sorted := True
    else
      goto Failure;
  end;
  New( A, Init(AreaName) );
  ReplaceStr( A^.Group, Group );
  A^.fSorted      := Lowered;
  A^.fUseAloneCmt := Lowered;
  A^.Virt         := True;
  FileBase^.Insert( A );
  with FileBase^.Groups^ do
    if FindGroup( A^.Group ) = nil then
      NewGroup( A^.Group );
  Exit;
Failure:
  raise Exception.Create( LoadString(_SBadNewArea) );
end; { __NewArea }

{ __Include ----------------------------------------------- }

procedure TScript.__Include;
var
  S: String;
  N: Integer;
  j: Integer;
  P: PCache;
  Map : TMappedFile;
begin
  S := ExistingFile( ExtractQuoted( Line^ ) );
  Log^.Write( ll_Protocol, Format(LoadString(_SLogIncluding), [S] ));

  for j := Finger to Text^.Count do
  begin
    if Cache^[j] <> nil then
      Dispose( Cache^[j] );
    Cache^[j] := nil;
  end;

  Dec( Finger );
  Text^.AtFree( Finger );
  N := 0;
  Map.Init( S );
  while Map.GetLine( S ) do
  begin
    S := Trim( S );
    if S <> '' then
    begin
      Text^.AtInsert( Finger + N, AllocStr(S) );
      Inc( N );
    end;
  end;
  Map.Done;

{
  ...Fails...

  ReallocMem( Cache, Text^.Count * SizeOf(Pointer) );
}

  GetMem( P, Text^.Count * SizeOf(Pointer) );
  FillChar( P^, Text^.Count * SizeOf(Pointer), 0 );
  Move( Cache^, P^, Finger * SizeOf(Pointer) );
  FreeMem( Cache );
  Cache := P;

end; { __Include }

{ __PrintFile --------------------------------------------- }

procedure TScript.__PrintFile;
var
  S: String;
  Map: TMappedFile;
begin
  S := ExistingFile( ExtractQuoted( Line^ ) );
  Log^.Write( ll_Protocol, Format(LoadString(_SLogIncluding), [S] ));

  Map.Init( S );
  while Map.GetLine( S ) do
    Report^.WriteOut( S );
  Map.Done;
end; { __PrintFile }

{ __Redirect ---------------------------------------------- }

procedure TScript.__Redirect;
var
  E: String;
  V: TValue;
begin
  E := Copy( Line^, Symbol, Length(Line^) );
  Execute( E, V );
  if V.ValType <> val_string then
    raise Exception.Create( LoadString(_SBadRedirArg) );
  Log^.Write( ll_Protocol, Format(LoadString(_SLogRedir), [V.StringValue] ));
  Report^.Redirect( V.StringValue );
end; { __Redirect }

{ __Copy -------------------------------------------------- }

procedure TScript.__Copy;
var
  j: Integer;
  Target: PFileArea;
  Group : PFileGroup;
  Name  : String;
begin
  if FD = nil then
    raise Exception.Create( LoadString(_SOrphanCopy) );
  Name := ExtractQuoted( Line^ );
  Target := FileBase^.GetArea( Name );
  if Target = nil then
    raise Exception.Create( Format(LoadString(_SCopyAreaNotExists), [Name] ));
  if Target = Area then
    raise Exception.Create( LoadString(_SCopySameArea) );
  if not Target^.Virt then
    raise Exception.Create( LoadString(_SCopyNeedVirtual) );
  if Area^.Search( FD^.FileName, j ) then
    raise Exception.Create( Format(LoadString(_SCopyFileDupe), [FD^.FileName^] ));
  with Area^ do
  begin
    Insert( FD^.Dupe );
    Inc( FoundFiles );
    FoundBytes := FoundBytes + FD^.Size;
  end;
  Group := FileBase^.Groups^.FindGroup( Area^.Group );
  with Group^ do
  begin
    Inc( Files );
    Bytes := Bytes + FD^.Size;
  end;
end; { __Copy }

{ PrintValue ---------------------------------------------- }

procedure TScript.PrintValue( var V: TValue );
const
  BoolStr: array [Boolean] of String[5] = ( 'False', 'True' );
var
  S: String;
begin
  case V.ValType of
    val_integer: S := IntToStr( V.IntValue );
    val_float  : S := Format( '%g', [V.FloatValue] );
    val_bool   : S := BoolStr[V.BoolValue];
    val_string : S := V.StringValue;
  else
    S := LoadString(_SBadValType );
  end;
  Report^.WriteOut( S );
end; { PrintValue }

{ Execute ------------------------------------------------- }

procedure TScript.Execute( const S: String; var V: TValue );
begin
  try
    Exec( S );
  except
    on E: Exception do
      begin
        Log^.Write( ll_Expand, GetText );
        Log^.Write( ll_Expand, CharStr('.', Pred(ErrorPos)) + '^' );
        raise;
      end;
  end;
  GetResult( V );
end; { Execute }

{ JumpOver ------------------------------------------------ }

function TScript.JumpOver( Term: TOpSet ) : TOperator;
var
  Op: TOperator;
  Level: Integer;
begin
  Level := BlockLevel;
  while GetLine do
  begin
    Op := GetOperator;
    if Op in BLOCK_CLOSE then
    begin
      if BlockLevel >= Level then
      begin
        if Frame^.Mode <> BlockEntrance( Op ) then
          raise Exception.Create( LoadString(_SMismatchedBlock) );
        LeaveBlock;
      end;
      if BlockLevel < Level then
      begin
        Result := Op;
        if Op in Term then Exit;
        raise Exception.Create( LoadString(_SMismatchedBlock) );
      end
    end
    else if Op in BLOCK_OPEN then
      EnterBlock( Op )
    else if Op = op_Else then
    begin
      if (BlockLevel = Level) and (Op_Else in Term) then
      begin
        LeaveBlock;
        Result := op_Else;
        Exit;
      end
      else if Frame^.Mode <> op_If then
        raise Exception.Create( LoadString(_SOrphanElse) );
    end;
  end;
  raise Exception.Create( LoadString(_SMismatchedBlock) );
end; { JumpOver }

{ Frame --------------------------------------------------- }

function TScript.Frame: PFrame;
begin
  if BlockLevel >= 0 then
    Result := @Frames[BlockLevel]
  else
    raise Exception.Create( LoadString(_SMismatchedBlock) );
end; { Frame }

{ BlockEntrance ------------------------------------------- }

function TScript.BlockEntrance( Op: TOperator ) : TOperator;
begin
  case Op of
    op_Else     : Result := op_If;
    op_EndIf    : Result := op_If;
    op_EndWhile : Result := op_While;
    op_EndFileLoop: Result := op_FileLoop;
    op_EndAreaLoop: Result := op_AreaLoop;
  else
    Result := op_None;
  end;
end; { BlockEntrance }

{ BlockExit ----------------------------------------------- }

function TScript.BlockExit( Op: TOperator ) : TOperator;
begin
  case Op of
    op_If   : Result := op_EndIf;
    op_Else : Result := op_EndIf;
    op_While: Result := op_EndWhile;
    op_FileLoop: Result := op_EndFileLoop;
    op_AreaLoop: Result := op_EndAreaLoop;
  else
    Result := op_None;
  end;
end; { BlockExit }

{ EnterBlock ---------------------------------------------- }

procedure TScript.EnterBlock( Op: TOperator );
begin
  if BlockLevel >= MAX_FRAMES then
    raise Exception.Create( LoadString(_SBlockTooNested) );
  Inc( BlockLevel );
  with Frames[BlockLevel] do
  begin
    Mode := Op;
    Ret  := Pred(Finger);
  end;
end; { EnterBlock }

{ LeaveBlock ---------------------------------------------- }

procedure TScript.LeaveBlock;
begin
  if BlockLevel < 0 then
    raise Exception.Create( LoadString(_SMismatchedBlock) );
  Dec( BlockLevel );
end; { LeaveBlock }

{ Nested -------------------------------------------------- }

function TScript.Nested( Op: TOperator ) : Boolean;
var
  j: Integer;
begin
  Result := True;
  for j := BlockLevel downto 0 do
    if Frames[j].Mode = Op then
      Exit;
  Result := False;
end; { Nested }

{ ReEnter ------------------------------------------------- }

procedure TScript.ReEnter( Op: TOperator );
begin
  if Frame^.Mode <> BlockEntrance( Op ) then
    raise Exception.Create( LoadString(_SMismatchedBlock) );
  Jump( Frame^.Ret );
  LeaveBlock;
end; { ReEnter }

{ --------------------------------------------------------- }
{ ExecuteScript                                             }
{ --------------------------------------------------------- }

procedure ExecuteScript( ScriptName: String; Report: PReport; Poster: PPoster );
var
  Script: PScript;
  FileName: String;
  LineNo  : Longint;
begin
  if ExtractFilePath(ScriptName) = '' then
    ScriptName := AtHome( ScriptName );
  Log^.Write( ll_Protocol, Format(LoadString(_SLogRunningScript), [ScriptName] ));
  New( Script, Init(ScriptName) );
  if Script = nil then Exit;
  if Poster <> nil then
    Script^.SetupPosterVars( Poster );
  try
    Script^.Run( Report );
  except
    on E: Exception do
      begin
        ShowError( E.Message );
        if GetLocationInfo( ExceptAddr, FileName, LineNo ) <> nil then
          Log^.Write( ll_expand, Format( 'Location: `%s'', line #%d', [FileName, LineNo] ) );
      end
      else
  end;
  Destroy( Script );
  if Log^.HasWarnings then ShowLog;
end; { ExecuteScript }

end.
