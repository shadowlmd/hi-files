unit _FAreas;

/////////////////////////////////////////////////////////////////////
//
// Hi-Files Version 2
// Copyright (c) 1997-2004 Dmitry Liman [2:461/79]
//
// http://hi-files.narod.ru
//
/////////////////////////////////////////////////////////////////////

interface

uses Objects, MyLib, _CFG;

const
  ALONE_CMT       = '';
  FILES_BBS       = 'files.bbs';
  FILE_ECHO_GROUP = 'FileEcho';

type
  PMagic = ^TMagic;
  TMagic = record
    Alias: PString;
    Path : PString;
    Updt : Boolean;
  end; { TMagic }

  PMagicList = ^TMagicList;
  TMagicList = object (TNoCaseStrCollection)
    Modified: Boolean;
    procedure FreeItem( Item: Pointer ); virtual;
    function  KeyOf( Item: Pointer ) : Pointer; virtual;
    procedure AddMagic( const S: String );
  end; { TMagicList }

  PFileDef = ^TFileDef;
  TFileDef = object (TStrings)
    FileName : PString;
    LongName : PString;
    Size     : Longint;
    Time     : FileTime;
    DLC      : Integer;
    Magic    : PMagic;
    Tag      : Boolean;         // Runtime custom tag

    constructor Init( const FName: String );
    destructor Done; virtual;

    function  Dupe: PFileDef;
    procedure Append( const S: String );
    procedure GoTop;
    function  GetLine( var S: String ) : Boolean;
    function  TextWidth: Integer;
    function  AloneCmt: Boolean;
    function  Missing: Boolean;
    function  NativeName: PString;
    function  NoComment: Boolean;
    procedure AssignDefaultComment;
    procedure Normalize;
    procedure LoadFromFile( const FromWhat: String );
    procedure EatBuffer( Buffer: PChar; BufSize: Integer );
    function  HasSignalString( P: PString ) : Boolean;
  private
    Finger: Integer;
  end; { TFileDef }

  PAddrList = ^TAddrList;
  TAddrList = object (TSortedCollection)
    procedure FreeItem( Item: Pointer ); virtual;
    function Compare( Key1, Key2: Pointer ) : Integer; virtual;
    procedure AddStr( const S: String );
  end; { PAddrList }

  TVolumeStr = String[11];
  TFormatBbs = ( bbs_fmt_Standard, bbs_fmt_Extended );
  TSwitch = ( Lowered, Raised, Default );

  PFileArea = ^TFileArea;
  TFileArea = object (TSortedCollection)
    // Явные паpаметpы Tornado из filearea.ctl
    Name       : PString;               // Собственно, имя файловой области
    DL_Path    : PNoCaseStrCollection;  // Список DL-path области
    FilesBbs   : PString;               // files.bbs
    FormatBbs  : TFormatBbs;            // Фоpмат файла files.bbs
    CopyLocal  : Boolean;               // (-) Нам - по-шаpабану
    UL_Path    : PString;               // (-) UL-path
    ScanTornado: Boolean;               // (-) Поиск новых файлов для Tornado
    DL_Sec     : PString;               // (-) Download access level
    UL_Sec     : PString;               // (-) Upload access level
    List_Sec   : PString;               // (-) List sec
    Show_Sec   : PString;               // (-) Show sec
    Group      : PString;               // Тэг файловой гpуппы

    // Наши паpаметpы из filearea.ctl
    fScan       : TSwitch;              // Пеpсональный флаг сканиpования
    fSorted     : TSwitch;              // Пеpсональный флаг соpтиpовки
    fUseAloneCmt: TSwitch;              // Пеpсональные свободные комментаpии
    VolumeLabel : PString;              // метка тома сменного носителя
    LastScanTime: UnixTime;             // Таймштамп последнего сканиpования
    HideFreq    : Boolean;              // Не включать во freq-dir-list
    Recurse     : Boolean;              // Включать подкаталоги

    // Run-time паpаметpы
    Virt       : Boolean;               // Область виpтуальная?
    FoundFiles : Longint;               // Число non-missing файлов
    FoundBytes : Double;                // Суммаpный pазмеp non-missing файлов
    MissFiles  : Longint;               // Число отсутствующих файлов
    Loaded     : Boolean;               // files.bbs загpужен
    Rescanned  : Boolean;               // Выполнен Rescan после загpузки
    Tag        : Boolean;               // Пометка области пи гупповом выборе

    constructor Init( const AreaName: String );
    destructor Done; virtual;
    procedure FreeItem( Item: Pointer ); virtual;
    function KeyOf( Item: Pointer ) : Pointer; virtual;
    function Compare( Key1, Key2: Pointer ) : Integer; virtual;
    function Search( Key: Pointer; var Index: Integer ) : Boolean; virtual;
    procedure Insert( Item: Pointer ); virtual;
    function Removable: Boolean;
    procedure ReadFilesBbs;
    procedure WriteFilesBbs;
    procedure Complete;
    procedure DropMissingFiles;
    procedure Clone( Target: PFileArea );
    function  Locate( FD: PFileDef; var Path: String ) : Boolean;
    procedure Rescan;
    function  Parking( const FileName: String ) : String;
    function GetPDP( var Path: String ) : Boolean;
    procedure AddTree;

    function Scan: Boolean;
    function Sorted: Boolean;
    function UseAloneCmt: Boolean;
  private
    function  LinearSearch( Key: Pointer; var Index: Integer ) : Boolean;
    procedure SortSubArea( L, R: Integer );
  end; { TFileArea }

  PFileGroup = ^TFileGroup;
  TFileGroup = record
    Tag  : PString;
    Files: Longint;
    Bytes: Double;
  end; { TFileGroup }

  PGroupList = ^TGroupList;
  TGroupList = object (TNoCaseStrCollection)
    procedure FreeItem( Item: Pointer ); virtual;
    function KeyOf( Item: Pointer ) : Pointer; virtual;
    function NewGroup( GroupTag: PString ) : PFileGroup;
    function FindGroup( GroupTag: PString ) : PFileGroup;
  end; { TGroupList }

  TEchoState = ( es_Awaiting, es_Alive, es_Down );

  PFileEcho = ^TFileEcho;
  TFileEcho = object (TObject)
    Name     : PString;                 // Эхотаг файлэхи
    Area     : PFileArea;               // Ссылка на хост-область (nil=pasru)
    Paranoia : Longint;
    Uplinks  : PAddrList;               // Аплинки
    DownLinks: PAddrList;               // Даунлинки
    Hooks    : PFetchList;              // Файловые ловушки
    State    : TEchoState;              // Текущее состояние

    constructor Init( const Tag: String );
    destructor Done; virtual;
    function Passthrough: Boolean;
  end; { TFileEcho }

  PEchoList = ^TEchoList;
  TEchoList = object (TSortedCollection)
    function KeyOf( Item: Pointer ) : Pointer; virtual;
    function Compare( Key1, Key2: Pointer ) : Integer; virtual;
    procedure RefineLinks;
  end; { TEchoList }

  PFileBase = ^TFileBase;
  TFileBase = object (TCollection)
    TotalFiles: Longint;
    TotalBytes: Double;
    Groups    : PGroupList;
    MagicList : PMagicList;
    EchoList  : PEchoList;
    Modified  : Boolean;

    constructor Init;
    destructor Done; virtual;
    procedure ReadFilesBbs;
    procedure WriteFilesBbs;
    procedure WriteFileAreaCtl;
    procedure ReadFileAreaCtl;
    procedure DropMissingFiles;
    procedure CalcSummary;
    function  GetArea( const AreaName: String ) : PFileArea;
    function  GetAreaByPath( Path: String ) : PFileArea;
    function  GetEcho( const EchoTag: String ) : PFileEcho;
    procedure Clean;
    procedure LoadMagicList;
    procedure SaveMagicList;
    procedure LinkMagicList;
  end; { TFileBase }

const
  bSkipRepl  = $0001;
  bCheckCRC  = $0002;
  bKeepDupes = $0004;

var
  FileBase: PFileBase;

// Только читает filearea.ctl
procedure OpenFileBase;

// OpenFileBase + читает все files.bbs, читает и линкует magic-list
procedure LoadFileBase;

// Сохpаняет изменения и Destroy( FileBase )
procedure CloseFileBase;

{ =================================================================== }

implementation

uses
  SysUtils, Memory, _MapFile, vpUtils, QSort, _LOG, Views, MsgBox, MsgAPI,
  _Report, _Working, _RES;

const
  LF = #10;
  CR = #13;
  FD_Size = 0;
  FD_Incr = 512;

  LEFT_MARGIN = 13;

const
  ORPHAN_COMMENT = 'Понятия не имею...';

{ --------------------------------------------------------- }
{ TMagicList                                                }
{ --------------------------------------------------------- }

{ FreeItem ------------------------------------------------ }

procedure TMagicList.FreeItem( Item: Pointer );
var
  M: PMagic absolute Item;
begin
  FreeStr( M^.Alias );
  FreeStr( M^.Path );
  Dispose( M );
end; { FreeItem }

{ KeyOf --------------------------------------------------- }

function TMagicList.KeyOf( Item: Pointer ) : Pointer;
begin
  Result := PMagic(Item)^.Alias;
end; { KeyOf }

{ AddMagic ------------------------------------------------ }

procedure TMagicList.AddMagic( const S: String );
var
  j: Integer;
  M: PMagic;
  A: String;
  P: String;
begin
  SplitPair( S, A, P );
  if (A = '') or (P = '') then Exit;
  New( M );
  if A[1] = '@' then
  begin
    System.Delete( A, 1, 1 );
    M^.Updt := True;
  end
  else
    M^.Updt := False;
  M^.Alias := AllocStr( A );
  M^.Path  := AllocStr( P );
  if Search( @A, j ) then AtFree( j );
  Insert( M );
end; { AddMagic }

{ --------------------------------------------------------- }
{ TFileDef                                                  }
{ --------------------------------------------------------- }

{ Init ---------------------------------------------------- }

constructor TFileDef.Init( const FName: String );
begin
  inherited Init(20, 20);
  if Cfg.FileApi = fapi_primary_short then
    FileName := AllocStr( JustUpperCase(FName) )
  else
    FileName := AllocStr( FName );
end; { Init }

{ Done ---------------------------------------------------- }

destructor TFileDef.Done;
begin
  FreeStr( FileName );
  FreeStr( LongName );
  inherited Done;
end; { Done }

{ Dupe ---------------------------------------------------- }

function TFileDef.Dupe: PFileDef;

  procedure CopyLine( P: PString ); far;
  begin
    Result^.Append( P^ );
  end; { CopyLine }

begin
  New( Result, Init(FileName^) );
  if LongName <> nil then
    Result^.LongName := AllocStr( LongName^ );
  Result^.Size     := Size;
  Result^.Time     := Time;
  Result^.DLC      := DLC;
  if Magic <> nil then
  begin
    New( Result^.Magic );
    Result^.Magic^.Alias := AllocStr( Magic^.Alias^ );
    Result^.Magic^.Path  := AllocStr( Magic^.Path^ );
    Result^.Magic^.Updt  := Magic^.Updt;
  end;
  ForEach( @CopyLine );
end; { Dupe }

{ GoTop --------------------------------------------------- }

procedure TFileDef.GoTop;
begin
  Finger := 0;
end; { GoTop }

{ Append -------------------------------------------------- }

procedure TFileDef.Append( const S: String );

  function Match( P: PString ) : Boolean; far;
  begin
    Result := Pos( P^, S ) > 0;
  end; { Match }

begin
  if CFG^.BadStrings^.FirstThat( @Match ) = nil then
    Insert( AllocStr(TrimRight(S)) );
end; { Append }

{ GetLine ------------------------------------------------- }

function TFileDef.GetLine( var S: String ) : Boolean;
begin
  if Finger < Count then
  begin
    S := PString(At(Finger))^;
    Inc( Finger );
    Result := True;
  end
  else
  begin
    S := '';
    Result := False;
  end;
end; { GetLine }

{ TextWidth ----------------------------------------------- }

function TFileDef.TextWidth: Integer;
var
  n: Integer;

  procedure DoCount( P: PString ); far;
  begin
    if Length(P^) > n then
      n := Length(P^);
  end; { DoCount }

begin
  n := 0;
  ForEach( @DoCount );
  Result := n;
end; { TextWidth }

{ AloneCmt ------------------------------------------------ }

function TFileDef.AloneCmt: Boolean;
begin
  Result := (FileName^ = ALONE_CMT);
end; { AloneCmt }

{ Missing ------------------------------------------------- }

function TFileDef.Missing: Boolean;
begin
  Result := not AloneCmt and (Time = 0);
end; { Missing }

{ NativeName ---------------------------------------------- }

function TFileDef.NativeName: PString;
begin
  if (LongName <> nil) and (LongName^ <> '') then
    Result := LongName
  else
    Result := FileName;
end; { NativeName }

{ NoComment ----------------------------------------------- }

function TFileDef.NoComment : Boolean;
var
  S: String;
  C: String;

  function NotOrphan: Boolean;
  begin
    Result := not JustSameText( ORPHAN_COMMENT, S );
  end; { NotOrphan }

  function NotDefault: Boolean;
  begin
    Result := (C = '') or not JustSameText( C, S );
  end; { NotDefault }

begin
  Result := False;
  CFG^.DefComments^.GetCall( FileName^, C );
  C := Replace( C, '&LFN',   NativeName^ );
  C := Replace( C, '&LNAME', ExtractFileNameOnly(NativeName^) );
  GoTop;
  while GetLine(S) do
    if (S <> '') and NotDefault and NotOrphan then
      Exit;
  Result := True;
end; { NoComment }

{ AssignDefaultComment ------------------------------------ }

procedure TFileDef.AssignDefaultComment;
const
  DIVIDER = ['|'];
var
  S: String;
  j: Integer;
begin
  FreeAll;
  if CFG^.DefComments^.GetCall( FileName^, S ) then
  begin
    S := Replace( S, '&LFN', NativeName^ );
    S := Replace( S, '&LNAME', ExtractFileNameOnly(NativeName^) );
    for j := 1 to WordCount(S, DIVIDER) do
      Append( ExtractWord(j, S, DIVIDER) );
  end
  else
    Append( ORPHAN_COMMENT );
end; { AssignDefaultComment }

{ LoadFromFile -------------------------------------------- }

procedure TFileDef.LoadFromFile( const FromWhat: String );
var
  S: String;
  Map: TMappedFile;
begin
  FreeAll;
  Map.Init( FromWhat );
  while Map.GetLine(S) do
    Append( S );
  Map.Done;
  Normalize;
end; { LoadFromFile }

{ EatBuffer ----------------------------------------------- }

procedure TFileDef.EatBuffer( Buffer: PChar; BufSize: Integer );
var
  S: String;
  Map: TMappedFile;
begin
  FreeAll;
  Map.Mirror( Buffer, BufSize );
  while Map.GetLine(S) do
    Append(S);
  Map.Done;
  Normalize;
end; { EatBuffer }

{ HasSignalString ----------------------------------------- }

function TFileDef.HasSignalString( P: PString ) : Boolean;
  function Match( S: PString ) : Boolean; far;
  begin
    Result := Pos( P^, S^ ) > 0;
  end; { Match }
begin
  Result := FirstThat( @Match ) <> nil;
end; { HasSignalString }

{ Normalize ----------------------------------------------- }

procedure TFileDef.Normalize;
begin
  while (Count > 0) and (PString(At(0))^ = '') do
    AtFree( 0 );
  while (Count > 0) and (PString(At(Pred(Count)))^ = '') do
    AtFree( Pred(Count) );
  if NoComment then
    AssignDefaultComment;
end; { Normalize }

{ --------------------------------------------------------- }
{ TAddrList                                                 }
{ --------------------------------------------------------- }

{ FreeItem ------------------------------------------------ }

procedure TAddrList.FreeItem( Item: Pointer );
begin
  Dispose( PAddress(Item) );
end; { TAddrList }

{ Compare ------------------------------------------------- }

function TAddrList.Compare( Key1, Key2: Pointer ) : Integer;
begin
  Result := CompAddr( PAddress(Key1)^, PAddress(Key2)^ );
end; { Compare }

{ AddStr -------------------------------------------------- }

procedure TAddrList.AddStr( const S: String );
var
  n: Integer;
  j: Integer;
  q: String;
  a: TAddress;
  d: TAddress;
begin
  d := DefAddr;
  n := WordCount( S, BLANK );
  for j := 1 to n do
  begin
    q := ExtractWord( j, S, BLANK );
    a := StrToAddrDef( q, d );
    Insert( NewAddr(a) );
    d := a;
  end;
end; { AddStr }

{ --------------------------------------------------------- }
{ TFileArea                                                 }
{ --------------------------------------------------------- }

{ Init ---------------------------------------------------- }

constructor TFileArea.Init( const AreaName: String );
begin
  inherited Init( 100, 50 );
  Name         := AllocStr( AreaName );
  FilesBbs     := AllocStr( '' );
  DL_Path      := New( PNoCaseStrCollection, Init(10, 10) );
  UL_Path      := AllocStr( '' );
  fScan        := Default;
  fSorted      := Default;
  fUseAloneCmt := Default;
  FormatBbs    := bbs_fmt_Standard;
  Virt         := False;
  Group        := AllocStr( '' );
  DL_Sec       := AllocStr( '0' );
  UL_Sec       := AllocStr( '0' );
  List_Sec     := AllocStr( '0' );
  Show_Sec     := AllocStr( '0' );
end; { Init }

{ Done ---------------------------------------------------- }

destructor TFileArea.Done;
begin
  FreeStr( Name );
  Destroy( DL_Path );
  FreeStr( FilesBbs );
  FreeStr( UL_Path );
  FreeStr( Group );
  FreeStr( DL_Sec );
  FreeStr( UL_Sec );
  FreeStr( List_Sec );
  FreeStr( Show_Sec );
  FreeStr( VolumeLabel );
  inherited Done;
end; { Done }

{ FreeItem ------------------------------------------------ }

procedure TFileArea.FreeItem( Item: Pointer );
begin
  Destroy( PFileDef(Item) );
end; { FreeItem }

{ KeyOf --------------------------------------------------- }

function TFileArea.KeyOf( Item: Pointer ) : Pointer;
begin
  Result := PFileDef(Item)^.FileName;
end; { KeyOf }

{ Compare ------------------------------------------------- }

function TFileArea.Compare( Key1, Key2: Pointer ) : Integer;
begin
  Result := JustCompareText( PString(Key1)^, PString(Key2)^ );
end; { Compare }

{ Search -------------------------------------------------- }

function TFileArea.Search( Key: Pointer; var Index: Integer ) : Boolean;
begin
  if Sorted and not UseAloneCmt then
    Result := inherited Search( Key, Index )
  else
    Result := LinearSearch( Key, Index );
end; { Search }

{ LinearSearch -------------------------------------------- }

function TFileArea.LinearSearch( Key: Pointer; var Index: Integer ) : Boolean;
var
  j: Integer;
begin
  for j := 0 to Count - 1 do
    if JustSameText( PFileDef(At(j))^.FileName^, PString(Key)^ ) then
    begin
      Index  := j;
      Result := True;
      Exit;
    end;
  Index  := Count;
  Result := False;
end; { LinearSearch }

{ Insert -------------------------------------------------- }

procedure TFileArea.Insert( Item: Pointer );
begin
  if Sorted and not UseAloneCmt then
    inherited Insert( Item )
  else
    AtInsert( Count, Item );
end; { Insert }

{ Scan ---------------------------------------------------- }

function TFileArea.Scan: Boolean;
begin
  if fScan = Default then
    Result := Boolean(CFG^.ScanNewFiles)
  else
    Result := Boolean(fScan);
end; { Scan }

{ Sorted -------------------------------------------------- }

function TFileArea.Sorted: Boolean;
begin
  if fSorted = Default then
    Result := Boolean(CFG^.Sorted)
  else
    Result := Boolean(fSorted);
end; { Sorted }

{ UseAloneCmt --------------------------------------------- }

function TFileArea.UseAloneCmt: Boolean;
begin
  if fUseAloneCmt = Default then
    Result := Boolean(CFG^.UseAloneCmt)
  else
    Result := Boolean(fUseAloneCmt);
end;

{ Removable ----------------------------------------------- }

function TFileArea.Removable: Boolean;
begin
  Removable := (VolumeLabel <> nil);
end; { Removable }

{ ReadFilesBbs -------------------------------------------- }

procedure TFileArea.ReadFilesBbs;
const
  DIGITS = [ ' ', '0'..'9' ];
var
  S  : String;
  FD : PFileDef;
  Map: TMappedFile;
  Shift: Integer;

  function IsFileDef : Boolean;
  begin
    Result := (S <> '') and (S[1] <> ' ') and (S[1] <> '>');
  end; { IsComment }

  function IsAloneComment: Boolean;
  var
    j: Integer;
  begin
    Result := False;
    if (S = '') or (S[1] = '>') then Exit;
    j := SkipR( S[1], 0, Length(S), ' ' );
    Result := (j > 0) and (j < Length(S)) and (j < LEFT_MARGIN);
  end; { IsAloneCmt }

  procedure NewFileDef;
  var
    j: Integer;
    Name: String;

    procedure CheckDLC;
    var
      k: Integer;
    begin
      Shift := 0;
      if (j + 2 > Length(S)) or (S[j] <> '[') then Exit;
      k := Succ(j);
      while (k <= Length(S)) and (S[k] in DIGITS) do Inc(k);
      if (k > Length(S)) or (S[k] <> ']') then Exit;
      try
        FD^.DLC := StrToInt( Trim(Copy(S, Succ(j), k - j - 1)) );
      except
        Exit;
      end;
      Shift := k - j + 2;
      Inc( j, Shift );
      if not CFG^.AlignDLC then
        Shift := 0;
    end; { CheckDLC }

  begin
    if S[1] = '"' then
      Name := GetLiterals( S, 1, j )
    else
    begin
      Name := ExtractWord( 1, S, BLANK );
      j := ScanR( S, 1, Length(S), ' ' );
    end;

    if (CFG^.Formatting <> fmt_lfn) and (j <= LEFT_MARGIN) then
      j := LEFT_MARGIN;

    FD := New( PFileDef, Init(Name) );
    AtInsert( Count, FD );

    Inc( j );
    CheckDLC;

    if j > Length(S) then Exit;

    FD^.Append( TrimRight(Copy(S, j, Length(S))) );
  end; { NewFileDef }

begin
  if Loaded then Exit;
  if (FilesBbs = nil) or (FilesBbs^ = '') or not DirExists(ExtractFileDir(FilesBbs^)) then
  begin
    Log^.Write( ll_Warning, Format(LoadString(_SFilesBbsMissing), [Name^] ));
    Exit;
  end;
  Loaded := True;
  Rescanned := False;
  if not FileExists( FilesBbs^ ) then
  begin
    Log^.Write( ll_Warning, Format(LoadString(_SNoFilesBbs), [Name^] ));
    Exit;
  end;
  Map.Init( FilesBbs^ );
  FD := nil;
  while Map.GetLine( S ) do
  begin
    S := TrimRight( S );
    if IsFileDef then
      NewFileDef
    else if IsAloneComment then
    begin
      if (FD = nil) or not FD^.AloneCmt then
      begin
        FD := New( PFileDef, Init( ALONE_CMT ) );
        AtInsert( Count, FD );
      end;
      FD^.Append( S );
    end
    else if FD <> nil then
    begin
      if (S <> '') and (S[1] = '>') then
        FD^.Append( Copy(S, 2, Length(S)) )
      else
        FD^.Append( Copy(S, Succ(LEFT_MARGIN) + Shift, Length(S)) );
    end;
  end;
  Map.Done;
  Complete;
end; { ReadFilesBbs }

{ WriteFilesBbs ------------------------------------------- }

procedure TFileArea.WriteFilesBbs;
var
  F: Text;

  procedure SaveFileDef( FD: PFileDef ); far;
  var
    S: String;
    n: Integer;
  begin
    FD^.GoTop;
    if FD^.AloneCmt then
      while FD^.GetLine(S) do Writeln( F, S )
    else
    begin
      FD^.GetLine(S);
      n := LEFT_MARGIN;
      if CFG^.DlcDigs > 0 then
      begin
        S := '[' + Int2StrZ(FD^.DLC, CFG^.DlcDigs) + '] ' + S;
        if CFG^.AlignDLC then Inc( n, CFG^.DlcDigs + 3 );
      end;
      if (CFG^.Formatting <> fmt_lfn) and
         (Length(FD^.FileName^) < LEFT_MARGIN) and
         (Pos(' ', FD^.FileName^) = 0)
      then
        Writeln( F, Pad(FD^.FileName^, LEFT_MARGIN) + S )
      else
        Writeln( F, QuotedFile(FD^.FileName^) + ' ' + S );
      while FD^.GetLine( S ) do
      begin
        if CFG^.Formatting <> fmt_standard then
          Writeln( F, '>' + S )
        else
          Writeln( F, CharStr(' ', n) + S );
      end;
    end;
  end; { SaveFileDef }

begin
  if not Loaded or CFG^.ReadOnly then Exit;
  if FilesBbs = nil then
  begin
    Log^.Write( ll_Error, Format(LoadString(_SFilesBbsMissing), [Name^] ));
    Exit;
  end;

  VFS_BackupFile( FilesBbs^, CFG^.BAK_Level );

  Assign( F, FilesBbs^ ); Rewrite( F );
  ForEach( @SaveFileDef );
  Close( F );
end; { WriteFilesBbs }

{ Complete ------------------------------------------------ }

procedure TFileArea.Complete;
  procedure DoNorm( FD: PFileDef ); far;
  begin
    FD^.Normalize;
  end; { DoNorm }
var
  L, R: Integer;
  FD  : PFileDef;
begin
  ForEach( @DoNorm );
  if not Sorted then Exit;
  L := 0;
  R := 0;
  while R < Count do
  begin
    FD := At( R );
    if FD^.AloneCmt then
    begin
      SortSubArea( L, R );
      L := R;
    end;
    Inc( R );
  end;
  SortSubArea( L, R - 1 );
end; { Complete }

{ CompareFD ----------------------------------------------- }

function CompareFD( var A, B ) : Boolean; far;
var
  X: PFileDef absolute A;
  Y: PFileDef absolute B;
begin
  CompareFD := JustCompareText( X^.FileName^, Y^.FileName^ ) < 0;
end; { CompareFD }

{ SortSubArea --------------------------------------------- }

procedure TFileArea.SortSubArea( L, R: Integer );
begin
  if (L < 0) or (R < 0) then Exit;
  if PFileDef( At(L) )^.AloneCmt then Inc( L );
  if PFileDef( At(R) )^.AloneCmt then Dec( R );
  if L < R then
    QuickSort( @Items^[L], Succ(R - L), SizeOf(Pointer), CompareFD );
end; { SortSubArea }

{ DropMissingFiles ---------------------------------------- }

procedure TFileArea.DropMissingFiles;
var
  j: Integer;
  FD: PFileDef;
begin
  j := 0;
  while j < Count do
  begin
    FD := At(j);
    if FD^.Missing then
    begin
      Log^.Write( ll_Protocol, Format(LoadString(_SDroppingMiss), [FD^.FileName^, Name^]));
      AtFree( j );
    end
    else
      Inc( j );
  end;
end; { DropMissingFiles }

{ Clone --------------------------------------------------- }

procedure TFileArea.Clone( Target: PFileArea );
begin
  if JustSameText( UL_Path^, CFG^.CommonULPath ) then
    ReplaceStr( Target^.UL_Path, CFG^.CommonULPath );
  Target^.FormatBbs   := FormatBbs;
  Target^.CopyLocal   := CopyLocal;
  Target^.ScanTornado := ScanTornado;
  ReplaceStr( Target^.Group, Group^ );
  Target^.fScan := fScan;
  Target^.fSorted := fSorted;
  Target^.fUseAloneCmt := fUseAloneCmt;
  ReplaceStr( Target^.DL_Sec, DL_Sec^ );
  ReplaceStr( Target^.UL_Sec, UL_Sec^ );
  ReplaceStr( Target^.Show_Sec, Show_Sec^ );
  ReplaceStr( Target^.List_Sec, List_Sec^ );
  Target^.HideFreq := HideFreq;
end; { Clone }

{ Locate -------------------------------------------------- }

function TFileArea.Locate( FD: PFileDef; var Path: String ) : Boolean;
var
  j: Integer;
  R: TSearchRec;
  FileName : String;
  ShortName: String;
  LongName : String;
  DosError : Integer;
begin
  for j := 0 to Pred(DL_Path^.Count) do
  begin
    Path := PString(DL_Path^.At(j))^;
    FileName := AtPath( FD^.FileName^, Path );
    DosError := FindFirst( FileName, faArchive + faReadOnly, R );
    if DosError = 0 then
    begin
      DecodeLFN( R, ShortName, LongName );
      ReplaceStr( FD^.LongName, LongName );
      FD^.Time := R.Time;
      FD^.Size := R.Size;
      FindClose( R );
      Path := AtPath( FD^.NativeName^, Path );
      Result := True;
      Exit;
    end;
    FindClose( R );
  end;
  Result := False;
  Path   := '';
end; { Locate }

{ Rescan -------------------------------------------------- }

procedure TFileArea.Rescan;

  procedure DoRescan( FD: PFileDef ); far;
  var
    Path: String;
  begin
    Locate( FD, Path );
  end; { DoRescan }

begin
  if Rescanned then Exit;
  Log^.Write( ll_Protocol, Format(LoadString(_SLogRescan), [Name^] ));
  ForEach( @DoRescan );
  Rescanned := True;
end; { Rescan }

{ Parking ------------------------------------------------- }

function TFileArea.Parking( const FileName: String ) : String;
var
  Path: String;
begin
  if GetPDP( Path ) then
    Result := AtPath( FileName, Path )
  else
    raise Exception.Create( Format(LoadString(_SNoDLPath), [Name^] ));
end; { Parking }

{ GetPDP -------------------------------------------------- }

function TFileArea.GetPDP( var Path: String ) : Boolean;
begin
  Result := True;
  Path   := '';
  if DL_Path^.Count > 0 then
    Path := PString( DL_Path^.At(0) )^
  else
    Result := False;
end; { GetPDP }

{ AddTree ------------------------------------------------- }

procedure TFileArea.AddTree;
var
  Root: String;

  procedure ScanDir( Deep: String );
  var
    R: SysUtils.TSearchRec;
    DosError : Integer;
    LevelName: String;
    LevelPath: String;
  begin
    DosError := SysUtils.FindFirst(
      AddBackSlash(Deep) + '*.*', faDirectory shl 8 or faAnyFile, R );
    while DosError = 0 do
    begin
      if (R.Name <> '.') and (R.Name <> '..') then
      begin
        LevelPath := AddBackSlash(Deep) + R.Name;
        if DL_Path^.IndexOf( @LevelPath ) < 0 then
        begin
          DL_Path^.Insert( AllocStr(LevelPath) );
          FileBase^.Modified := True;
          Log^.Write( ll_protocol, Format(LoadString(_SDirAdded), [LevelPath] ));
        end;
        ScanDir( LevelPath );
      end;
      DosError := SysUtils.FindNext( R );
    end;
    SysUtils.FindClose( R );
  end;

begin
  if GetPDP( Root ) then
    ScanDir( Root );
end; { AddTree }


{ --------------------------------------------------------- }
{ TGroupList                                                }
{ --------------------------------------------------------- }

{ FreeItem ------------------------------------------------ }

procedure TGroupList.FreeItem( Item: Pointer );
var
  G: PFileGroup absolute Item;
begin
  FreeStr( G^.Tag );
  Dispose( G );
end; { FreeItem }

{ KeyOf --------------------------------------------------- }

function TGroupList.KeyOf( Item: Pointer ) : Pointer;
var
  G: PFileGroup absolute Item;
begin
  Result := G^.Tag;
end; { KeyOf }

{ NewGroup ------------------------------------------------ }

function TGroupList.NewGroup( GroupTag: PString ) : PFileGroup;
var
  j: Integer;
  G: PFileGroup;
begin
  if Search( GroupTag, j ) then Exit;
  New( G );
  FillChar( G^, SizeOf(TFileGroup), 0 );
  G^.Tag := AllocStr( GroupTag^ );
  Insert( G );
  Result := G;
end; { NewGroup }

{ FindGroup ----------------------------------------------- }

function TGroupList.FindGroup( GroupTag: PString ) : PFileGroup;
var
  j: Integer;
begin
  if Search( GroupTag, j ) then
    Result := At(j)
  else
    Result := nil;
end; { FindGroup }

{ --------------------------------------------------------- }
{ TFileEcho                                                 }
{ --------------------------------------------------------- }

{ Init ---------------------------------------------------- }

constructor TFileEcho.Init( const Tag: String );
begin
  inherited Init;
  Name := AllocStr( Tag );
  New( Uplinks, Init(20, 20) );
  New( Downlinks, Init(20, 20) );
  New( Hooks, Init );
  State := es_Awaiting;
end; { Init }

{ Done ---------------------------------------------------- }

destructor TFileEcho.Done;
begin
  Destroy( Hooks );
  Destroy( Downlinks );
  Destroy( Uplinks );
  FreeStr( Name );
  inherited Done;
end; { Done }

{ Passthrough --------------------------------------------- }

function TFileEcho.Passthrough: Boolean;
begin
  Result := Area = nil;
end; { Passthrough }


{ --------------------------------------------------------- }
{ TEchoList                                                 }
{ --------------------------------------------------------- }

{ KeyOf --------------------------------------------------- }

function TEchoList.KeyOf( Item: Pointer ) : Pointer;
begin
  Result := PFileEcho(Item)^.Name;
end; { KeyOf }

{ Compare ------------------------------------------------- }

function TEchoList.Compare( Key1, Key2: Pointer ) : Integer;
begin
  Result := JustCompareText( PString(Key1)^, PString(Key2)^ );
end; { Compare }

{ RefineLinks --------------------------------------------- }

procedure TEchoList.RefineLinks;

  procedure Refine( List: PAddrList ); far;
  var
    j: Integer;
    k: Integer;
  begin
    j := 0;
    while j < List^.Count do
      if CFG^.Links^.Search( PAddress(List^.At(j)), k ) then
        Inc( j )
      else
      begin
        List^.AtFree( j );
        FileBase^.Modified := True;
      end;
  end; { Refine }

  procedure RefineEcho( Echo: PFileEcho ); far;
  begin
    Refine( Echo^.Uplinks );
    Refine( Echo^.Downlinks );
  end; { RefineEcho }

begin
  ForEach( @RefineEcho );
end; { RefineLinks }

{ --------------------------------------------------------- }
{ TFileBase                                                 }
{ --------------------------------------------------------- }

type
  TFileBaseKeyWord  = (
    kw_None,
    kw_Name,
    kw_DLPath,
    kw_FileList,
    kw_FList_Format,
    kw_Copy_Local,
    kw_ULPath,
    kw_Scan_NewFiles,
    kw_DL_Security,
    kw_UL_Security,
    kw_List_Security,
    kw_Show_Security,
    kw_Group,
    kw_VolumeLabel,
    kw_Scan,
    kw_Sorted,
    kw_UseAloneCmt,
    kw_LastScan,
    kw_Paranoia,
    kw_Uplink,
    kw_Downlink,
    kw_Hook,
    kw_Area,
    kw_EchoTag,
    kw_State,
    kw_HideFreq,
    kw_Recurse );

  TFileBaseKeyWordNames = array [TFileBaseKeyWord] of String;

const
  FILE_AREA_HEADER = '[FileArea]';
  FILE_ECHO_HEADER = '[FileEcho]';

  BI_SKIP_REPL  = 'IgnoreReplaces';
  BI_USE_CRC    = 'UseCRC';
  BI_KEEP_DUPES = 'KeepDupes';

  TOK_AWAITING = 'Awaiting';
  TOK_DOWN     = 'Down';
  TOK_ALIVE    = 'Alive';

const
  FileBaseKeyWord: TFileBaseKeyWordNames = (
    '',
    'Name',
    'DLPath',
    'FileList',
    'FList_Format',
    'Copy_Local',
    'ULPath',
    'Scan_NewFiles',
    'DL_Security',
    'UL_Security',
    'List_Security',
    'Show_Security',
    'Group',
    'VolumeLabel',
    'Scan',
    'Sorted',
    'AloneCmt',
    'LastScan',
    'Paranoia',
    'Uplink',
    'Downlink',
    'Hook',
    'Area',
    'EchoTag',
    'State',
    'HideFreq',
    'Recurse' );

  HiddenKeyWords =
    [kw_Scan, kw_Sorted, kw_UseAloneCmt, kw_VolumeLabel, kw_LastScan,
     kw_Paranoia, kw_Uplink, kw_Downlink, kw_Hook, kw_Area, kw_EchoTag,
     kw_State, kw_HideFreq, kw_Recurse];

{ Init ---------------------------------------------------- }

constructor TFileBase.Init;
begin
  inherited Init( 100, 50 );
  New( Groups, Init(10, 10) );
  New( EchoList, Init(20, 20) );
end; { Init }

{ Done ---------------------------------------------------- }

destructor TFileBase.Done;
begin
  Destroy( Groups );
  Destroy( MagicList );
  Destroy( EchoList );
  inherited Done;
end; { Done }

{ ReadFileAreaCtl ----------------------------------------- }

procedure TFileBase.ReadFileAreaCtl;
var
  Map: TMappedFile;
  kw : TFileBaseKeyWord;
  S  : String;
  A  : PFileArea;
  E  : PFileEcho;
  H  : String;
  P1 : String;
  P2 : String;

  function GetKeyWord( const S: String ) : TFileBaseKeyWord;
  var
    j: TFileBaseKeyWord;
  begin
    for j := Succ(Low(TFileBaseKeyWord)) to High(TFileBaseKeyWord) do
      if JustSameText( S, FileBaseKeyWord[j] ) then
      begin
        Result := j;
        Exit;
      end;
    Result := kw_None;
  end; { GetKeyWord }

  function GetFormatBbs( const S: String ) : TFormatBbs;
  begin
    if JustSameText( S, 'FilesBBS' ) then
      Result := bbs_fmt_Standard
    else if JustSameText( S, 'CD-List' ) then
      Result := bbs_fmt_Extended
    else
      raise Exception.Create( Format(LoadString(_SBadFListFormat), [S] ));
  end; { GetFormatBbs }

  function ParanoicOpt( const S: String ) : Longint;
  var
    j: Integer;
    n: Integer;
    w: String;
  begin
    Result := 0;
    n := WordCount( S, BLANK );
    for j := 1 to n do
    begin
      w := ExtractWord( j, S, BLANK );
      if JustSameText( w, BI_SKIP_REPL ) then
        SetBit( Result, bSkipRepl, True )
      else if JustSameText( w, BI_USE_CRC ) then
        SetBit( Result, bCheckCRC, True )
      else if JustSameText( w, BI_KEEP_DUPES ) then
        SetBit( Result, bKeepDupes, True )
      else
        raise Exception.Create( Format(LoadString(_SBadParanoic), [w] ));
    end;
  end; { ParanoicOpt }

  function ReadState( const S: String ) : TEchoState;
  begin
    if JustSameText( S, TOK_AWAITING ) then
      Result := es_Awaiting
    else if JustSameText( S, TOK_ALIVE ) then
      Result := es_Alive
    else if JustSameText( S, TOK_DOWN ) then
      Result := es_Down
    else
      raise Exception.Create( Format(LoadString(_SBadEchoState), [S] ));
  end; { ReadState }

  procedure DoneArea;
  begin
    if A <> nil then
    begin
      if GetArea( A^.Name^ ) <> nil then
      begin
        Log.WriteEx( ll_Error, CFG^.FileAreaCtl, Map.LineNo, '', LoadString(_SDupeAreaDef) );
        Destroy( A );
      end
      else
        Insert( A );
    end;
    A := nil;
  end; { DoneArea }

  procedure DoneEcho;
  begin
    if E <> nil then
    begin
      if GetEcho( E^.Name^ ) <> nil then
      begin
        Log.WriteEx( ll_Error, CFG^.FileAreaCtl, Map.LineNo, '', LoadString(_SDupeAreaDef) );
        Destroy( E );
      end
      else
      begin
        if H <> '' then
        begin
          E^.Area := GetArea( H );
          if E^.Area = nil then
          begin
            Log^.Write( ll_Error,  Format(LoadString(_SNoHost), [E^.Name^] ));
            Log^.Write( ll_Expand, Format(LoadString(_SNeedHost), [H] ));
          end
        end;
        EchoList^.Insert( E );
      end;
    end;
    E := nil;
  end; { DoneEcho }

  procedure NewArea;
  begin
    DoneArea;
    DoneEcho;
    A := New( PFileArea, Init( '' ) );
  end; { NewArea }

  procedure NewEcho;
  begin
    DoneArea;
    DoneEcho;
    E := New( PFileEcho, Init( '' ) );
    H := '';
  end; { NewEcho }

begin
  if CFG^.FileAreaCtl = '' then
    raise Exception.Create( LoadString(_SNoFileAreaCtl) );

  OpenWorking( Format(LoadString(_SReadingFileAreaCtl), [CFG^.FileAreaCtl] ));
  Log^.Write( ll_Service, Format(LoadString(_SReadingFileAreaCtl), [CFG^.FileAreaCtl] ));
  A := nil;
  E := nil;
  H := '';
  try
    Map.Init( CFG^.FileAreaCtl );
    OpenProgress( Map.GetSize );
    while Map.GetLine( S ) do
    try
      UpdateProgress( Map.GetPos );
      StripComment( S );
      if S = '' then Continue;
      if JustSameText( S, FILE_AREA_HEADER ) then
        NewArea
      else if JustSameText( S, FILE_ECHO_HEADER ) then
        NewEcho
      else
      begin
        SplitPair( S, P1, P2 );
        kw := GetKeyWord( P1 );
        if A <> nil then
        with A^ do
        begin

          // Файловая область

          case kw of
            kw_Name         : ReplaceStr( Name, ExtractQuoted(P2) );
            kw_DLPath       : if (P2 <> '') and DirExists(P2) then
                                DL_Path^.Insert( AllocStr(AddBackSlash(P2)) );
            kw_FileList     : if (P2 <> '') and DirExists( ExtractFileDir(P2) ) then
                                ReplaceStr( FilesBbs, P2 );
            kw_FList_Format : FormatBbs := GetFormatBbs( P2 );
            kw_Copy_Local   : CopyLocal := StrToBool( P2 );
            kw_ULPath       : ReplaceStr( UL_Path, AddBackSlash(P2) );
            kw_Scan_NewFiles: ScanTornado := StrToBool( P2 );
            kw_DL_Security  : ReplaceStr( DL_Sec, P2 );
            kw_UL_Security  : ReplaceStr( UL_Sec, P2 );
            kw_List_Security: ReplaceStr( List_Sec, P2 );
            kw_Show_Security: ReplaceStr( Show_Sec, P2 );
            kw_Group        : ReplaceStr( Group, P2 );
            kw_VolumeLabel  : ReplaceStr( VolumeLabel, ExtractQuoted(P2) );
            kw_Scan         : fScan := TSwitch(StrToBool( P2 ));
            kw_Sorted       : fSorted := TSwitch(StrToBool( P2 ));
            kw_UseAloneCmt  : fUseAloneCmt := TSwitch(StrToBool( P2 ));
            kw_HideFreq     : HideFreq := StrToBool( P2 );
            kw_Recurse      : Recurse := StrToBool( P2 );
            kw_LastScan     : LastScanTime := ParseMsgDate(ExtractQuoted(P2));
          else
            raise Exception.Create( LoadString(_SBadToken) );
          end;
        end
        else if E <> nil then
        with E^ do

          // Файл-эха

        begin
          case kw of
            kw_EchoTag  : ReplaceStr( E^.Name, ExtractQuoted(P2) );
            kw_Area     : H := ExtractQuoted(P2);
            kw_Paranoia : E^.Paranoia := ParanoicOpt( P2 );
            kw_Uplink   : E^.Uplinks^.AddStr( P2 );
            kw_Downlink : E^.Downlinks^.AddStr( P2 );
            kw_Hook     : E^.Hooks^.Insert( AllocStr(ExtractQuoted(P2)) );
            kw_State    : E^.State := ReadState( P2 );
          else
            raise Exception.Create( LoadString(_SBadToken) );
          end;
        end
        else
          raise Exception.Create( LoadString(_SNoActiveArea) );
      end;
    except
      on E: Exception do
        Log^.WriteEx( ll_Error, CFG^.FileAreaCtl, Map.LineNo, S, E.Message );
    end;
    DoneArea;
    DoneEcho;
  finally
    Map.Done;
    FileBase^.EchoList^.RefineLinks;
    CloseWorking;
  end;
end; { ReadFileAreaCtl }

{ WriteFileAreaCtl ---------------------------------------- }

procedure TFileBase.WriteFileAreaCtl;
var
  F: Text;

  function FormatBbsStr( f: TFormatBbs ) : String;
  begin
    case f of
      bbs_fmt_Standard: Result := 'FilesBBS';
      bbs_fmt_Extended: Result := 'CD-List';
    else
      Result := '';
    end;
  end; { FormatBbsStr }

  procedure WriteMerge( kw: TFileBaseKeyWord; const Value: String );
  var
    D: String;
  begin
    if Value <> '' then
    begin
      if kw in HiddenKeyWords then
        D := HIDDEN_PREFIX
      else
        D := '';
      Writeln( F, Pad( D + FileBaseKeyWord[kw], 20) + Trim(Value) );
    end;
  end; { Merge }

  procedure WriteArea( A: PFileArea ); far;
  var
    j: Integer;
  begin
    with A^ do
    begin
      Writeln( F, ';' );
      Writeln( F, FILE_AREA_HEADER );
      WriteMerge( kw_Name, QuotedStr(Name^) );
      for j := 0 to DL_Path^.Count - 1 do
        WriteMerge( kw_DLPath, VFS_ValidatePath(PString(DL_Path^.At(j))^) );
      WriteMerge( kw_FileList, VFS_ValidatePath(FilesBbs^) );
      WriteMerge( kw_FList_Format, FormatBbsStr(FormatBbs) );
      WriteMerge( kw_Copy_Local, BoolToStr(CopyLocal) );
      WriteMerge( kw_ULPath, UL_Path^ );
      WriteMerge( kw_Scan_NewFiles, BoolToStr(ScanTornado) );
      WriteMerge( kw_DL_Security, DL_Sec^ );
      WriteMerge( kw_UL_Security, UL_Sec^ );
      WriteMerge( kw_List_Security, List_Sec^ );
      WriteMerge( kw_Show_Security, Show_Sec^ );
      WriteMerge( kw_HideFreq, BoolToStr(HideFreq) );
      WriteMerge( kw_Recurse, BoolToStr(Recurse) );
      WriteMerge( kw_Group, Group^ );
      if fScan <> Default then
        WriteMerge( kw_Scan, BoolToStr(Boolean(fScan)) );
      if fSorted <> Default then
        WriteMerge( kw_Sorted, BoolToStr(Boolean(fSorted)) );
      if fUseAloneCmt <> Default then
        WriteMerge( kw_UseAloneCmt, BoolToStr(Boolean(fSorted)) );
      if VolumeLabel <> nil then
        WriteMerge( kw_VolumeLabel, QuotedStr(VolumeLabel^) );
      if LastScanTime <> 0 then
        WriteMerge( kw_LastScan, QuotedStr(MsgDateStr(LastScanTime)));
    end;
  end; { WriteArea }

  procedure WriteAddrList( kw: TFileBaseKeyWord; List: PAddrList );
  var
    S: String;
    j: Integer;
    A: PAddress;
    Default: TAddress;
  begin
    S := '';
    Default := EMPTY_ADDR;
    for j := 0 to Pred(List^.Count) do
    begin
      A := List^.At(j);
      S := S + ' ' + AddrToShortStr( A^, Default );
      Default := A^;
      Default.Point := 0;
      if Length(S) > 50 then
      begin
        WriteMerge(kw, S);
        S := '';
      end;
    end;
    if S <> '' then
      WriteMerge(kw, S);
  end; { WriteAddrList }

  procedure WriteHook( P: PString ); far;
  begin
    WriteMerge( kw_Hook, QuotedStr(P^) );
  end; { WriteHook }

  function ParanoicOptions( Opt: Longint ) : String;
  begin
    Result := '';
    if TestBit( Opt, bSkipRepl ) then
      Result := Result + BI_SKIP_REPL + ' ';
    if TestBit( Opt, bCheckCRC ) then
      Result := Result + BI_USE_CRC + ' ';
    if TestBit( Opt, bKeepDupes ) then
      Result := Result + BI_KEEP_DUPES;
  end; { ParanoicOptions }

  procedure WriteEcho( E: PFileEcho ); far;
  const
    StateToken: array [TEchoState] of String[10] =
      ( 'Awaiting', 'Alive', 'Down' );
  begin
    with E^ do
    begin
      Writeln( F, ';' );
      Writeln( F, HIDDEN_PREFIX + FILE_ECHO_HEADER );
      WriteMerge( kw_EchoTag, QuotedStr(Name^) );
      if Area <> nil then
        WriteMerge( kw_Area, QuotedStr(Area^.Name^) );
      WriteMerge( kw_State, StateToken[E^.State] );
      if Paranoia <> 0 then
        WriteMerge( kw_Paranoia, ParanoicOptions( E^.Paranoia ) );
      WriteAddrList( kw_Uplink, Uplinks );
      WriteAddrList( kw_DownLink, Downlinks );
      Hooks^.ForEach( @WriteHook );
    end;
  end; { WriteEcho }

begin
  Log^.Write( ll_Service, LoadString(_SSavingFileAreaCtl) );

  VFS_BackupFile( CFG^.FileAreaCtl, CFG^.AreasBakLevel );

  Assign( F, CFG^.FileAreaCtl );
  try
    Rewrite( F );
  except
    Log^.Write( ll_UnrecoverableError, Format(LoadString(_SCantCreateFile), [CFG^.FileAreaCtl] ));
    Exit;
  end;
  OpenWorking( LoadString(_SSavingFileAreaCtl) );
  try
    ForEach( @WriteArea );
    EchoList^.ForEach( @WriteEcho );
    Close( F );
  finally
    CloseWorking;
  end;
  Modified := False;
end; { WriteFileAreaCtl }

{ ReadFilesBbs -------------------------------------------- }

procedure TFileBase.ReadFilesBbs;
var
  j: Integer;

begin
  Log^.Write( ll_Service, LoadString(_SReadingFilesBbs) );
  OpenWorking( LoadString(_SReadingFilesBbs) );
  OpenProgress( Count );
  try
    for j := 0 to Pred( Count ) do
    begin
      PFileArea( At(j) )^.ReadFilesBbs;
      UpdateProgress( j );
    end;
  finally
    CloseWorking;
  end;
end; { ReadFilesBbs }

{ WriteFilesBbs ------------------------------------------- }

procedure TFileBase.WriteFilesBbs;
var
  j: Integer;
begin
  if CFG^.ReadOnly then Exit;
  Log^.Write( ll_Service, LoadString(_SSavingFilesBbs) );
  OpenWorking( LoadString(_SSavingFilesBbs) );
  OpenProgress( Count );
  try
    for j := 0 to Pred( Count ) do
    begin
      PFileArea( At(j) )^.WriteFilesBbs;
      UpdateProgress( j );
    end;
  finally
    CloseWorking;
  end;
end; { WriteFilesBbs }

{ DropMissingFiles ---------------------------------------- }

procedure TFileBase.DropMissingFiles;
var
  a, b: Integer;

  procedure Drop( A: PFileArea ); far;
  begin
    A^.DropMissingFiles;
  end; { Drop }

begin
  a := count;
  b := filebase^.Count;
  Log^.Write( ll_Service, LoadString(_SDropMissFiles) );
  ForEach( @Drop );
end; { DropMissingFiles }

{ CalcSummary --------------------------------------------- }

procedure TFileBase.CalcSummary;

  procedure Calc( A: PFileArea ); far;
  var
    j: Integer;
    G: PFileGroup;
    FD: PFileDef;
  begin
    G := Groups^.FindGroup( A^.Group );
    if G = nil then
      G := Groups^.NewGroup( A^.Group );
    with A^ do
    begin
      FoundFiles := 0;
      FoundBytes := 0;
      for j := 0 to Pred(Count) do
      begin
        FD := At(j);
        if not FD^.AloneCmt then
        begin
          Inc( FoundFiles );
          if not FD^.Missing then
            FoundBytes := FoundBytes + FD^.Size;
        end;
      end;
      if not Virt then
      begin
        Inc( TotalFiles, FoundFiles );
        TotalBytes := TotalBytes + FoundBytes;
      end;
      Inc( G^.Files, FoundFiles );
      G^.Bytes := G^.Bytes + FoundBytes;
    end;
  end; { Calc }

begin
  Groups^.FreeAll;
  TotalFiles := 0;
  TotalBytes := 0;
  ForEach( @Calc );
end; { CalcSummary }

{ GetArea ------------------------------------------------- }

function TFileBase.GetArea( const AreaName: String ) : PFileArea;

  function Match( A: PFileArea ) : Boolean; far;
  begin
    Result := JustSameText( A^.Name^, AreaName );
  end; { Match }

begin
  Result := FirstThat( @Match );
end; { GetArea }

{ GetAreaByPath ------------------------------------------- }

function TFileBase.GetAreaByPath( Path: String ) : PFileArea;

  function MatchArea( A: PFileArea ) : Boolean; far;
  var
    j: Integer;
  begin
    Result := A^.DL_Path.Search( @Path, j );
  end; { MatchedArea }

begin
  Path := AddBackSlash( Path );
  Result := FirstThat( @MatchArea );
end; { GetAreaByPath }

{ GetEcho ------------------------------------------------- }

function TFileBase.GetEcho( const EchoTag: String ) : PFileEcho;
var
  j: Integer;
begin
  if EchoList^.Search( @EchoTag, j ) then
    Result := EchoList^.At( j )
  else
    Result := nil;
end; { GetEcho }

{ Clean --------------------------------------------------- }

procedure TFileBase.Clean;
var
  j: Integer;
  A: PFileArea;
begin
  CalcSummary;
  j := 0;
  while j < Count do
  begin
    A := At(j);
    if A^.Virt or (A^.FoundFiles = 0) then
      AtFree(j)
    else
      Inc( j );
  end;
end; { Clean }

{ LoadMagicList ------------------------------------------- }

procedure TFileBase.LoadMagicList;
var
  S: String;
  Map: TMappedFile;
begin
  if (MagicList <> nil) or (CFG^.MagicFiles = '') then Exit;
  Log^.Write( ll_Service, Format(LoadString(_SReadingMagic), [CFG^.MagicFiles] ));
  if not FileExists( CFG^.MagicFiles ) then
  begin
    ShowError( Format(LoadString(_SFileNotFound), [CFG^.MagicFiles] ));
    Exit;
  end;

  New( MagicList, Init(50, 50) );

  OpenWorking( Format(LoadString(_SReadingMagic), [CFG^.MagicFiles] ));
  try
    Map.Init( CFG^.MagicFiles );
    while Map.GetLine( S ) do
    begin
      StripComment( S );
      if S <> '' then
        MagicList^.AddMagic( S );
    end;
    Map.Done;
  finally
    CloseWorking;
  end;
end; { LoadMagicList }

{ SaveMagicList ------------------------------------------- }

procedure TFileBase.SaveMagicList;
var
  Report: PTextReport;

  procedure SaveMagic( M: PMagic ); far;
  begin
    if M^.Updt then
      Report^.WriteOut( '@' + M^.Alias^ + ' ' + M^.Path^ )
    else
      Report^.WriteOut( M^.Alias^ + ' ' + M^.Path^ );
  end; { SaveMagic }

begin
  if (MagicList <> nil) and MagicList^.Modified then
  begin
    Log^.Write( ll_Service, LoadString(_SSavingMagic) );
    Report := nil;
    try
      New( Report, Init(CFG^.MagicFiles) );
      WriteChangedLogo( Report );
      MagicList^.ForEach( @SaveMagic );
      MagicList^.Modified := False;
    except
      on E: Exception do
        Log^.Write( ll_Warning, Format(LoadString(_SSaveMagicFailed), [E.Message] ));
    end;
    Destroy( Report );
  end;
end; { SaveMagicList }

{ LinkMagicList ------------------------------------------- }

procedure TFileBase.LinkMagicList;

  procedure Link( M: PMagic ); far;
  var
    j   : Integer;
    FD  : PFileDef;
    Area: PFileArea;
    Name: String;
  begin
    Area := GetAreaByPath( ExtractFileDir( M^.Path^ ) );
    if Area = nil then
    begin
      Log^.Write( ll_Warning, Format(LoadString(_SAliasRefNotFound), [M^.Alias^, M^.Path^] ));
      Exit;
    end;
    Name := ExtractFileName( M^.Path^ );
    if Area^.Search( @Name, j ) then
    begin
      FD := Area^.At(j);
      FD^.Magic := M;
    end
    else
      Log^.Write( ll_Warning, Format(LoadString(_SAliasRefNotFound), [M^.Alias^, M^.Path^] ));
  end; { Link }

begin
  LoadMagicList;
  if MagicList <> nil then
  begin
    Log^.Write( ll_Service, LoadString(_SLinkingMagic) );
    MagicList^.ForEach( @Link );
  end;
end; { LinkMagicList }

{ --------------------------------------------------------- }
{ OpenFileBase                                              }
{ --------------------------------------------------------- }

procedure OpenFileBase;
begin
  if FileBase = nil then
  begin
    New( FileBase, Init );
    FileBase^.ReadFileAreaCtl;
    if Log^.HasWarnings then
      ShowLog;
  end;
end; { OpenFileBase }

{ --------------------------------------------------------- }
{ LoadFileBase                                              }
{ --------------------------------------------------------- }

procedure LoadFileBase;
begin
  OpenFileBase;
  FileBase^.ReadFilesBbs;
  FileBase^.LinkMagicList;
  if Log^.HasWarnings then ShowLog;
end; { LoadFileBase }

{ --------------------------------------------------------- }
{ CloseFileBase                                             }
{ --------------------------------------------------------- }

procedure CloseFileBase;
begin
  if FileBase = nil then Exit;
  if FileBase^.Modified then
  begin
    if CFG^.BatchMode or
       (MessageBox( LoadString(_SAskSaveAreaDef), nil,
        mfConfirmation + mfYesButton + mfNoButton ) = cmYes)
    then
      FileBase^.WriteFileAreaCtl;
  end;
  FileBase^.SaveMagicList;
  Destroy( FileBase );
  FileBase := nil;
end; { CloseFileBase }

end.
