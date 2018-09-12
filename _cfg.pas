unit _CFG;

/////////////////////////////////////////////////////////////////////
//
// Hi-Files Version 2
// Copyright (c) 1997-2004 Dmitry Liman [2:461/79]
//
// http://hi-files.narod.ru
//
/////////////////////////////////////////////////////////////////////

interface

uses Objects, Views, MsgAPI;

const
  PROG_NAME = 'Hi-Files';
  PROG_VER  = '2.39';
{$IFDEF WIN32}
  PLATFORM  = '[Win32]';
{$ENDIF}
{$IFDEF DPMI32}
  PLATFORM  = '[DPMI32]';
{$ENDIF}
{$IFDEF OS2}
  PLATFORM  = '[OS2]';
{$ENDIF}
{$IFDEF LINUX}
  PLATFORM  = '[LINUX]';
{$ENDIF}

  COPYRIGHT = 'Copyright (C) 1997-2006 Dmitry Liman [2:461/79]';
  SHORT_PID = PROG_NAME + ' ' + PROG_VER + '/' + PLATFORM;
  LONG_PID  = SHORT_PID + ' (C)1997-2006 Dmitry Liman';
  TEARLINE  = '--- ' + SHORT_PID;

type
  PFetchList = ^TFetchList;
  TFetchList = object (TCollection)
    constructor Init;
    procedure Add( const S: String );
    procedure FreeItem( Item: Pointer ); virtual;
    function  GetCall( const FileName: String; var Call: String ) : Boolean;
  end; { TFetchList }

  PWildList = ^TWildList;
  TWildList = object (TCollection)
    constructor Init;
    procedure Add( const S: String );
    procedure FreeItem( Item: Pointer ); virtual;
    function  Match( const FileName: String ) : Boolean;
  end; { TWildList }

  PPoster = ^TPoster;
  TPoster = object (TObject)
    _From : String;
    _To   : String;
    Orig  : TAddress;
    Dest  : TAddress;
    Subj  : String;
    Area  : String;
    Reply : String;
    Script: String;
    constructor Init;
  end; { TPoster }

  TEchoLinkOption = ( elo_Notify, elo_AutoCreate, elo_AutoLink, elo_Pause, elo_FileBox );
  TEchoLinkOptSet = set of TEchoLinkOption;

  // Не изменять поpядок следования!
  TFlavor = ( fl_Hold, fl_Normal, fl_Dir, fl_Crash, fl_Imm );

  PEchoLink = ^TEchoLink;
  TEchoLink = object (TObject)
    Addr    : TAddress;
    OurAKA  : TAddress;
    Opt     : TEchoLinkOptSet;
    Flavor  : TFlavor;
    Password: PString;
    Deny    : PWildList;
    constructor Init( A: TAddress );
    destructor  Done; virtual;
  end; { PEchoLink }

  PEchoLinkTable = ^TEchoLinkTable;
  TEchoLinkTable = object (TSortedCollection)
    function Compare( Key1, Key2: Pointer ) : Integer; virtual;
    function KeyOf( Item: Pointer ) : Pointer; virtual;
    function Find( Addr: TAddress ) : PEchoLink;
  end; { TEchoLinkTable }

  TAvailOption = ( ao_Inactive );
  TAvailOptSet = set of TAvailOption;

  PAvailRec = ^TAvailRec;
  TAvailRec = record
    Addr: TAddress;
    Opt : TAvailOptSet;
    Name: String;
    List: PStringCollection;
  end; { TAvailRec }

  PAvailTable = ^TAvailTable;
  TAvailTable = object (TCollection)
    procedure FreeItem( Item: Pointer ); virtual;
    function FindUplink( EchoTag: String ) : PEchoLink;
    function Find( A: TAddress ) : PAvailRec;
    procedure LoadAll;
  private
    procedure LoadAvailList( AR: PAvailRec );
  end; { TAvailTable }

  TDbgOption = ( doScript, doTrace );
  TDbgOptSet = set of TDbgOption;

  TFileApiMode = (fapi_primary_short, fapi_primary_long, fapi_native);
  TFilesBbsFormat = (fmt_standard, fmt_allfix, fmt_lfn);

  PConfig = ^TConfig;
  TConfig = object (TObject)
    // общесистемные
    FileApi      : TFileApiMode;
    CommonULPath : String;
    Palette      : String;

    // фоpматиpование files.bbs
    Formatting   : TFilesBbsFormat; // Режим форматирования files.bbs
    WrapSingle   : Boolean;   // Пеpенос длинных одностpочных комментаpиев
    UseAloneCmt  : Boolean;   // Разpешены свободные комментаpии?
    Sorted       : Boolean;   // Соpтиpовать дескpиптоpы по имени файла?
    DlcDigs      : Integer;   // Число цифр в DLC, 0 = отключено
    AlignDLC     : Boolean;   // Выpавнивать DLC в отдельную колонку?
    ReadOnly     : Boolean;   // Read-Only для files.bbs
    BAK_Level    : Integer;   // Уpовень сохpанения BAK-копий files.bbs (0..9)
    AreasBakLevel: Integer;   // Уровень бэкапа для FileAreaCtl

    // сканиpование файлопомойки
    ScanNewFiles : Boolean;   // Искать новые файлы?
    DropMissing  : Boolean;   // Убивать из files.bbs отсутствующие файлы?
    TouchNew     : Boolean;   // Помечать текущей датой новые файлы?
    KeepOldCmt   : Boolean;   // Оставить старый описатель у обновлённых файлов?
    CD_Timeout   : Integer;   // Сколько секунд ждать установку CD?

    // упpавление генеpатоpом отчётов
    BuildAllList    : Boolean; // Стpоить общий файл-лист?
    BuildNewList    : Boolean; // Стpоить список новых файлов?
    BuildNewRep     : Boolean; // Стpоить отчёт о новых файлах?
    BuildBestArea   : Boolean; // Генеpиpовать в общем файл-листе область лучших файлов?
    NewFilesAge     : Integer; // Возpаст (дней) новых файлов
    BestCount       : Integer; // Сколько файлов в списке лучших?
    FinderRepAlways : Boolean; // Финдер: отвечать всегда

    FileAreaCtl    : String;  // Описание файловых областей FileArea.Ctl
    AllFilesList   : String;  // Общий файл-лист
    NewFilesList   : String;  // Файл-лист новых файлов
    FreqDirs       : String;  // Файл списка каталогов для фpеков
    MagicFiles     : String;  // Список magic-алиасов для фpеков
    AllFilesScript : String;  // Скpипт общего файл-листа
    NewFilesScript : String;  // Скpипт списка новых файлов

    // FTN-анкета Вашей системы
    PrimaryAddr  : TAddress;  // Основной FTN-адpес данной cистемы
    RobotAddr    : TAddress;  // Адpес Вашего pобота (для PKT)
    UTC          : Integer;   // Смещение UTC (в часах)
    PktIn        : String;    // Каталог для входящих пакетов
    PktOut       : String;    // Каталог для исходящих пакетов
    Inbound      : String;    // Inbound (для tic-тоссера)
    Outbound     : String;    // Коpневой BSO-каталог
    Netmail      : String;    // Каталог общего нетмейла (*.MSG)
    TempDir      : String;    // Каталог вpеменных файлов
    PktPassword  : String;    // Паpоль для PKT-шников

    // всякое pазное для файлэхопpоцессоpа
    OutTicPath   : String;    // Куда складывать выходные тики (*.TIC)
    BadTicPath   : String;    // Куда складывать дифективные тики
    Autocreate   : String;    // Коpневой каталог автосоздаваемых файлэх
    Passthrough  : String;    // Каталог, где живут файлы Passthrough-файлэх
    FileBoxes    : String;    // Корневой каталог для файл-боксов
    AllfixHelp   : String;    // Файл, котоpый высылает менеджеp подписки на файлэхи по команде %HELP
    HatchPw      : String;    // Паpоль для hatch
    KillAfixReq  : Boolean;   // Убивать ли запросы к ареафиксу?
    TrafficLog   : String;    // Имя двоичного лога траффика

    Archivers   : PFetchList;         // Вызовы аpхиватоpов
    Fetches     : PFetchList;         // FETCH-вызовы
    DefComments : PFetchList;         // Default comments (ext-depending)
    BadStrings  : PStringCollection;  // Убиваемые из files.bbs стpоки
    DizFiles    : PWildList;          // Имена внутpиаpхивных файлов-описателей
    Exclude     : PWildList;          // Файлы, котоpые всегда убивать из files.bbs
    Forget      : PWildList;          // Файлы, никогда не новые, даже когда новые ;-)
    Posters     : PCollection;        // Список для pассылки отчетов
    FinderAreas : PCollection;        // Список постеpов для Финдеpа :)
    FinderRobots: PWildList;          // Имена pоботов финдеpа
    AfixRobots  : PWildList;          // Имена pоботов аpеафикса
    Viewers     : PFetchList;         // Вызовы вьювеpов
    Links       : PEchoLinkTable;     // Линки по файлэхам
    Avail       : PAvailTable;        // avail-листы для форвард-реквестов

    BatchMode   : Boolean;
    Modified    : Boolean;
    RunGenerator: Boolean;
    RunFinder   : Boolean;
    RunTicTosser: Boolean;
    RunAreaFix  : Boolean;
    RunHatcher  : Boolean;
    UpdateCmt   : Boolean;
    ForceCmt    : Boolean;
    Debug       : TDbgOptSet;
    HatchCtl    : String;             // Имя управляющего файла batch-hatch

    constructor Init;
    destructor Done; virtual;
    procedure SetDefaults;
    procedure ReadTextFile;
    procedure WriteTextFile;
    procedure EatCommandLine;
  end; { TConfig }

function GetConfigName: String;

var
  CFG: PConfig;

const
  DIZ_FILE = 'FILE_ID.DIZ';
  DEFAULT_POSTER_SCRIPT = 'NewRep.Scr';
  DEFAULT_FINDER_SCRIPT = 'Finder.Scr';

const
  // Exit Codes
  EXIT_NEW_FILES_FOUND = 1;

{ =================================================================== }

implementation

uses
  Dos, SysUtils, MyLib, _MapFile, _LOG, _Working, _Res, _Pal;

{ --------------------------------------------------------- }
{ TEchoLink                                                 }
{ --------------------------------------------------------- }

{ Init ---------------------------------------------------- }

constructor TEchoLink.Init( A: TAddress );
begin
  inherited Init;
  Password := AllocStr( '' );
  Addr   := A;
  Flavor := fl_Hold;
  Deny   := New( PWildList, Init );
end; { Init }

{ Done ---------------------------------------------------- }

destructor TEchoLink.Done;
begin
  Destroy( Deny );
  FreeStr( Password );
  inherited Done;
end; { Done }

{ --------------------------------------------------------- }
{ TEchoLinkTable                                            }
{ --------------------------------------------------------- }

{ KeyOf --------------------------------------------------- }

function TEchoLinkTable.KeyOf( Item: Pointer ) : Pointer;
begin
  Result := @PEchoLink(Item)^.Addr;
end; { KeyOf }

{ Compare ------------------------------------------------- }

function TEchoLinkTable.Compare( Key1, Key2: Pointer ) : Integer;
begin
  Result := CompAddr( PAddress(Key1)^, PAddress(Key2)^ );
end; { Compare }

{ Find ---------------------------------------------------- }

function TEchoLinkTable.Find( Addr: TAddress ) : PEchoLink;
var
  j: Integer;
begin
  if Search( @Addr, j ) then
    Result := At(j)
  else
    Result := nil;
end; { Find }

{ --------------------------------------------------------- }
{ TAvailTable                                               }
{ --------------------------------------------------------- }

{ FreeItem ------------------------------------------------ }

procedure TAvailTable.FreeItem( Item: Pointer );
var
  AR: PAvailRec absolute Item;
begin
  Destroy( AR^.List );
  Dispose( AR );
end; { FreeItem }

{ Find ---------------------------------------------------- }

function TAvailTable.Find( A: TAddress ) : PAvailRec;

  function Match( AR: PAvailRec ) : Boolean; far;
  begin
    Result := CompAddr( AR^.Addr, A ) = 0;
  end; { Match }

begin
  Result := FirstThat( @Match );
end; { Find }

{ FindUplink ---------------------------------------------- }

function TAvailTable.FindUplink( EchoTag: String ) : PEchoLink;
var
  AR: PAvailRec;

  function Match( AR: PAvailRec ) : Boolean; far;
  var
    j: Integer;
  begin
    if not (ao_Inactive in AR^.Opt) then
    begin
      if AR^.List = nil then
        LoadAvailList( AR );
      Result := AR^.List^.Search( @Echotag, j );
    end;
  end; { Match }

begin
  Echotag := JustUpperCase( Echotag );
  AR := FirstThat( @Match );
  if AR = nil then
    Result := nil
  else
    Result := CFG^.Links^.Find( AR^.Addr );
end; { FindUplink }

{ LoadAvailList ------------------------------------------- }

procedure TAvailTable.LoadAvailList( AR: PAvailRec );
var
  S: String;
  Map: TMappedFile;
begin
  Log^.Write( ll_Service, Format(LoadString(_SLogLoadingAvail),
    [AddrToStr(AR^.Addr), AR.Name]) );

  New( AR^.List, Init( 100, 100 ) );

  Map.Init( AR^.Name );
  OpenWorking( LoadString(_SLogLoadingAvail) );
  OpenProgress( Map.GetSize );
  try
    while Map.GetLine( S ) do
    begin
      UpdateProgress( Map.GetPos );
      S := JustUpperCase(ExtractWord(1, S, BLANK));
      if S <> '' then
        AR^.List^.Insert( AllocStr(S) );
    end;
  finally
    CloseWorking;
    Map.Done;
  end;
end; { LoadAvailList }

{ LoadAll ------------------------------------------------- }

procedure TAvailTable.LoadAll;

  procedure DoLoad( AR: PAvailRec ); far;
  begin
    if not (ao_Inactive in AR^.Opt) and (AR^.List = nil) then
      LoadAvailList( AR );
  end; { LoadAll }

begin
  ForEach( @DoLoad );
end; { LoadAll }

{ --------------------------------------------------------- }
{ TWildList                                                 }
{ --------------------------------------------------------- }

{ Init ---------------------------------------------------- }

constructor TWildList.Init;
begin
  inherited Init( 10, 10 );
end; { Init }

{ FreeItem ------------------------------------------------ }

procedure TWildList.FreeItem( Item: Pointer );
begin
  FreeStr( PString(Item) );
end; { FreeItem }

{ Add ----------------------------------------------------- }

procedure TWildList.Add( const S: String );
begin
  Insert( AllocStr(S) );
end; { AddLine }

{ Match --------------------------------------------------- }

function TWildList.Match( const FileName: String ) : Boolean;

function Matched( P: PString ) : Boolean; far;
begin
  Result := WildMatch( FileName, P^ );
end; { Matched }

begin
  Result := FirstThat( @Matched ) <> nil;
end; { Match }


{ --------------------------------------------------------- }
{ TFetchList                                                }
{ --------------------------------------------------------- }

{ Init ---------------------------------------------------- }

constructor TFetchList.Init;
begin
  inherited Init(10, 10);
end; { Init }

{ FreeItem ------------------------------------------------ }

procedure TFetchList.FreeItem( Item: Pointer );
begin
  FreeStr( PString(Item) );
end; { FreeItem }

{ AddCall ------------------------------------------------- }

procedure TFetchList.Add( const S: String );
begin
  Insert( AllocStr(S) );
end; { AddCall }

{ GetCall ------------------------------------------------- }

function TFetchList.GetCall( const FileName: String; var Call: String ) : Boolean;

  function Match( P: PString ) : Boolean; far;
  const
    Delim = [',', ';'];
  var
    N: Integer;
    M: String;
    j: Integer;
    Mask : String;
    Value: String;
  begin
    Result := True;
    SplitPair( P^, Mask, Value );
    N := WordCount( Mask, Delim );
    for j := 1 to N do
    begin
      M := ExtractWord( j, Mask, Delim );
      if WildMatch( FileName, M ) then
      begin
        Call := Value;
        Exit;
      end;
    end;
    Result := False;
  end; { Match }

begin
  Call   := '';
  Result := FirstThat( @Match ) <> nil;
end; { GetCall }

{ --------------------------------------------------------- }
{ TPoster                                                   }
{ --------------------------------------------------------- }

{ Init ---------------------------------------------------- }

constructor TPoster.Init;
begin
  inherited Init;
  Orig  := CFG^.RobotAddr;
  Dest  := CFG^.PrimaryAddr;
end; { Init }

{ --------------------------------------------------------- }
{ TConfig                                                   }
{ --------------------------------------------------------- }

type
  TCfgChapter = (
    ch_None,            // Обязательно должен стоять пеpвым!
    ch_FilesBbs,
    ch_FileList,
    ch_DizFiles,
    ch_Archive,
    ch_DefCmt,
    ch_Fetch,
    ch_Exclude,
    ch_Forget,
    ch_BadStr,
    ch_Poster,
    ch_FTN,
    ch_Finder,
    ch_Viewer,
    ch_FileEcho,
    ch_Links,
    ch_Avail,
    ch_System );

  TCfgKeyWord = (
    kw_None,            // Обязательно должен стоять пеpвым!
    kw_AllfixMode,
    kw_Formatting,
    kw_WrapSingle,
    kw_UseAloneCmt,
    kw_Sorted,
    kw_UseDLC,
    kw_DlcDigs,
    kw_AlignDLC,
    kw_ReadOnly,
    kw_BAK_Level,
    kw_AreasBakLevel,
    kw_DropMissing,
    kw_TouchNew,
    kw_KeepOldCmt,
    kw_NewFilesAge,
    kw_BestCount,
    kw_CD_Timeout,
    kw_ScanNewFiles,
    kw_BuildAllList,
    kw_BuildNewList,
    kw_BuildNewRep,
    kw_BuildBestArea,
    kw_FileAreaCtl,
    kw_AllFilesList,
    kw_NewFilesList,
    kw_FreqDirList,
    kw_MagicFiles,
    kw_AllFilesScript,
    kw_NewFilesScript,
    kw_NewRepScript,
    kw_FinderScript,
    kw_PrimaryAddr,
    kw_RobotAddr,
    kw_UTC,
    kw_Inbound,
    kw_PktIn,
    kw_PktOut,
    kw_Outbound,
    kw_Netmail,
    kw_PktPassword,
    kw_TempDir,
    kw_OutTicPath,
    kw_BadTicPath,
    kw_AutoCreate,
    kw_Passthrough,
    kw_FileBoxes,
    kw_TrafficLog,
    kw_HatchPw,
    kw_AfixHelp,
    kw_KillAfixReq,
    kw_Robot,
    kw_Area,
    kw_FileApi,
    kw_FinderRepAlways,
    kw_CommonULPath,
    kw_Palette );

  TChapterName = array [TCfgChapter] of String;
  TKeyWordName = array [TCfgKeyWord] of String;

const
  ChapterName : TChapterName = (
    '',
    'Files.Bbs',
    'FileList',
    'DIZ',
    'Archive',
    'DefComment',
    'Fetch',
    'Exclude',
    'Forget',
    'BadStrings',
    'Poster',
    'FTN',
    'Finder',
    'Viewer',
    'FileEcho',
    'Links',
    'Avail',
    'System' );

  KeyWordName : TKeyWordName = (
    '',
    'AllfixMode',
    'Formatting',
    'WrapSingle',
    'UseAloneCmt',
    'Sorted',
    'UseDLC', // obsolete, should not be used
    'DlcDigs',
    'AlignDLC',
    'ReadOnly',
    'BAK_Level',
    'AreasBakLevel',
    'DropMissing',
    'TouchNew',
    'KeepOldCmt',
    'NewFilesAge',
    'BestCount',
    'CD_Timeout',
    'ScanNewFiles',
    'BuildAllList',
    'BuildNewList',
    'BuildNewRep',
    'BuildBestArea',
    'FileAreaCtl',
    'AllFilesList',
    'NewFilesList',
    'FreqDirList',
    'MagicFiles',
    'AllFilesScript',
    'NewFilesScript',
    'NewRepScript',
    'FinderScript',
    'PrimaryAddr',
    'RobotAddr',
    'UTC',
    'Inbound',
    'PktIn',
    'PktOut',
    'Outbound',
    'Netmail',
    'PktPassword',
    'TempDir',
    'OutTicPath',
    'BadTicPath',
    'AutoCreate',
    'Passthrough',
    'FileBoxes',
    'TrafficLog',
    'HatchPw',
    'AreaFixHelp',
    'KillAfixReq',
    'Robot',
    'Area',
    'FileNameApi',
    'FinderReplyAlways',
    'CommonULPath',
    'Palette' );

const
  TOK_HOLD       = 'Hold';
  TOK_DIRECT     = 'Direct';
  TOK_NORMAL     = 'Normal';
  TOK_CRASH      = 'Crash';
  TOK_IMM        = 'Imm';
  TOK_AUTOLINK   = 'AutoLink';
  TOK_AUTOCREATE = 'AutoCreate';
  TOK_NOTIFY     = 'Notify';
  TOK_PAUSE      = 'Pause';
  TOK_FILEBOX    = 'FileBox';
  TOK_OURAKA     = 'OurAKA';
  TOK_DENY       = 'Deny';

  TOK_INACTIVE   = 'Inactive';

{ Init ---------------------------------------------------- }

constructor TConfig.Init;
begin
  inherited Init;
  Archivers      := New( PFetchList, Init );
  Fetches        := New( PFetchList, Init );
  DefComments    := New( PFetchList, Init );
  DizFiles       := New( PWildList, Init );
  Exclude        := New( PWildList, Init );
  Forget         := New( PWildList, Init );
  BadStrings     := New( PStringCollection, Init(10, 10) );
  Posters        := New( PCollection, Init(10, 10) );
  FinderAreas    := New( PCollection, Init(10, 10) );
  FinderRobots   := New( PWildList, Init );
  AfixRobots     := New( PWildList, Init );
  Viewers        := New( PFetchList, Init );
  Links          := New( PEchoLinkTable, Init(20, 20) );
  Avail          := New( PAvailTable, Init(20, 20) );
  TempDir        := GetEnv('TEMP');
end; { Init }

{ Done ---------------------------------------------------- }

destructor TConfig.Done;
begin
  Destroy( Archivers );
  Destroy( Fetches );
  Destroy( DefComments );
  Destroy( BadStrings );
  Destroy( DizFiles );
  Destroy( Exclude );
  Destroy( Forget );
  Destroy( Posters );
  Destroy( FinderAreas );
  Destroy( FinderRobots );
  Destroy( AfixRobots );
  Destroy( Viewers );
  Destroy( Links );
  Destroy( Avail );
  inherited Done;
end; { Done }

{ SetDefaults --------------------------------------------- }

procedure TConfig.SetDefaults;
begin
{$IFDEF Win32}
  FileApi     := fapi_primary_short;
{$ELSE}
  FileApi     := fapi_native;
{$ENDIF}

  Formatting    := fmt_standard;
  WrapSingle    := True;
  UseAloneCmt   := False;
  Sorted        := True;
  DlcDigs       := 3;
  AlignDLC      := True;
  ReadOnly      := False;
  BAK_Level     := 0;
  AreasBakLevel := 0;
  KeepOldCmt    := True;

  ScanNewFiles := True;
  DropMissing  := True;
  TouchNew     := True;
  NewFilesAge  := 10;
  CD_Timeout   := 30;
  BestCount    := 20;

  BuildAllList  := True;
  BuildNewList  := True;
  BuildNewRep   := True;
  BuildBestArea := False;

  FileAreaCtl    := 'FileArea.Ctl';
  AllFilesList   := 'AllFiles.Txt';
  NewFilesList   := 'NewFiles.Txt';
  FreqDirs       := 'c:\Fido\T-Mail\Freq.Dir';
  MagicFiles     := 'c:\Fido\T-Mail\Freq.Als';
  AllFilesScript := 'AllFiles.Scr';
  NewFilesScript := 'NewFiles.Scr';

  UTC            := +2;
  PktIn          := 'c:\Fido\Inbound';
  PktOut         := 'c:\Fido\Inbound';
  Inbound        := 'c:\fido\Inbound';
  Outbound       := 'c:\Fido\Outbound';
  Netmail        := 'c:\Fido\Netmail';

  OutTicPath     := 'c:\Fido\Tic';
  BadTicPath     := 'c:\Fido\BadTic';
  Autocreate     := 'c:\Online\FileEcho';
  Passthrough    := 'c:\Fido\Pasru';
  FileBoxes      := 'c:\Fido\FileBox';
  TrafficLog     := AtHome('traffic.bin');
  HatchPw        := 'Change_this_password!!!';
  AllfixHelp     := 'AreaMgr.Hlp';
  TempDir        := GetEnv('TEMP');

  HatchCtl       := 'hatch.ctl';

  with DizFiles^ do
  begin
    FreeAll;
    Add( DIZ_FILE );
  end;

  with Archivers^ do
  begin
    FreeAll;
    Add( '*.zip pkunzip -o' );
    Add( '*.arj arj x -y' );
    Add( '*.rar rar x -o+ -c- -std' );
    Add( '*.ha  ha ey' );
  end;

  with Fetches^ do
  begin
    FreeAll;
    Add( '*.mp3,*.xm,*.mod musicinf.exe' );
    Add( '*.jpg,*.jpp jpginfo.exe' );
    Add( '*.pcx,*.gif xpj_info.exe' );
  end;

  with Exclude^ do
  begin
    FreeAll;
    Add( 'files.bbs' );
  end;

  with Viewers^ do
  begin
    FreeAll;
    Add( '*.zip,*.rar,*.arj rar.exe' );
    Add( '* hiew.exe' );
  end;

  with AfixRobots^ do
  begin
    FreeAll;
    Add( 'AllFix' );
    Add( 'FileFix' );
    Add( 'T-Fix' );
    Add( 'Hi-Files' );
  end;

end; { SetDefaults }

{ EatCommandLine ------------------------------------------ }

procedure TConfig.EatCommandLine;
const
  EQ = ['='];
var
  j: Integer;
  S: String;
begin
  for j := 1 to ParamCount do
  begin
    S := ParamStr(j);
    if JustSameText( ExtractWord( 1, S, EQ ), 'CFG' ) then
      Continue
    else if JustSameText( S, 'GEN' ) then
      RunGenerator := True
    else if JustSameText( S, 'FIND' ) then
      RunFinder := True
    else if JustSameText( S, 'TIC' ) then
      RunTicTosser := True
    else if JustSameText( S, 'AFIX' ) then
      RunAreaFix := True
    else if JustSameText( ExtractWord( 1, S, EQ ), 'HATCH' ) then
    begin
      RunHatcher := True;
      if ExtractWord( 2, S, EQ) <> '' then
        HatchCtl := ExtractWord( 2, S, EQ );
    end
    else if JustSameText( S, '-NOREP' ) then
      BuildNewRep := False
    else if JustSameText( S, '-NOSCAN' ) then
      ScanNewFiles := False
    else if JustSameText( S, '-UPDATE' ) then
      UpdateCmt := True
    else if JustSameText( S, '-FORCE' ) then
      ForceCmt := True
    else if JustSameText( S, '-READONLY' ) then
      ReadOnly := True
    else if JustSameText( S, '-DEBUG=SCRIPT' ) then
      Include( Debug, doScript )
    else if JustSameText( S, '-DEBUG=TRACE' ) then
      Include( Debug, doTrace )
    else
      raise Exception.Create( Format(LoadString(_SBadCmdLine), [S] ));
  end;
  BatchMode := RunGenerator or RunFinder or RunAreaFix or RunTicTosser or RunHatcher;
end; { EatCommandLine }

{ ReadTextFile -------------------------------------------- }

procedure TConfig.ReadTextFile;
const
  COMMA = [','];
var
  Map: TMappedFile;
  Chapter: TCfgChapter;
  KeyWord: TCfgKeyWord;
  S, P1, P2: String;

  { ------------------------------------------------------- }
  function TryChapter: Boolean;
  var
    c: TCfgChapter;
  begin
    TryChapter := False;
    if (S[1] <> '[') or (S[Length(S)] <> ']') then Exit;
    p1 := Copy( S, 2, Length(S) - 2 );
    for c := Succ(Low(TCfgChapter)) to High(TCfgChapter) do
    begin
      if JustSameText( p1, ChapterName[c] ) then
      begin
        Chapter := c;
        TryChapter := True;
        Exit;
      end;
    end;
    raise Exception.Create( LoadString(_SBadChapter) );
  end; { TryChapter }

  { ------------------------------------------------------- }
  function TryParam: Boolean;
  var
    k: TCfgKeyWord;
  begin
    TryParam := False;
    SplitPair( S, p1, p2 );
    for k := Succ(Low(TCfgKeyWord)) to High(TCfgKeyWord) do
    begin
      if JustSameText( p1, KeyWordName[k] ) then
      begin
        KeyWord := k;
        TryParam := True;
        Exit;
      end;
    end;
  end; { TryParam }

  { ------------------------------------------------------- }
  procedure Dispatch_FilesBbs;
  begin
    case KeyWord of
      // AllfixMode упразднён в build #34
      kw_AllfixMode   : if StrToBool( P2 ) then
                          Formatting := fmt_allfix
                        else
                          Formatting := fmt_standard;
      kw_Formatting   : Formatting   := TFilesBbsFormat( StrToInt(P2) );
      kw_WrapSingle   : WrapSingle   := StrToBool( P2 );
      kw_UseAloneCmt  : UseAloneCmt  := StrToBool( P2 );
      kw_Sorted       : Sorted       := StrToBool( P2 );
      kw_UseDLC       : if StrToBool( P2 ) then
                          DlcDigs := 3
                        else
                          DlcDigs := 0;
      kw_DlcDigs      : DlcDigs      := StrToInt ( P2 );
      kw_AlignDLC     : AlignDLC     := StrToBool( P2 );
      kw_ReadOnly     : ReadOnly     := StrToBool( P2 );
      kw_BAK_Level    : BAK_Level    := StrToInt( P2 );
      kw_AreasBakLevel: AreasBakLevel:= StrToInt( P2 );
      kw_DropMissing  : DropMissing  := StrToBool( P2 );
      kw_TouchNew     : TouchNew     := StrToBool( P2 );
      kw_KeepOldCmt   : KeepOldCmt   := StrToBool( P2 );
      kw_NewFilesAge  : NewFilesAge  := StrToInt( P2 );
      kw_CD_Timeout   : CD_Timeout   := StrToInt( P2 );
      kw_BestCount    : BestCount    := StrToInt( P2 );
    else
      raise Exception.Create( LoadString(_SBadToken) );
    end;
  end; { Dispatch_FilesBBS }

  { ------------------------------------------------------- }
  procedure Dispatch_FileList;
  begin
    case KeyWord of
      kw_ScanNewFiles    : ScanNewFiles   := StrToBool( P2 );
      kw_BuildAllList    : BuildAllList   := StrToBool( P2 );
      kw_BuildNewList    : BuildNewList   := StrToBool( P2 );
      kw_BuildNewRep     : BuildNewRep    := StrToBool( P2 );
      kw_BuildBestArea   : BuildBestArea  := StrToBool( P2 );
      kw_FileAreaCtl     : FileAreaCtl    := ExistingFile( P2 );
      kw_AllFilesList    : AllFilesList   := P2;
      kw_NewFilesList    : NewFilesList   := P2;
      kw_FreqDirList     : FreqDirs       := P2;
      kw_MagicFiles      : MagicFiles     := P2;
      kw_AllFilesScript  : AllFilesScript := ExistingFile( P2 );
      kw_NewFilesScript  : NewFilesScript := ExistingFile( P2 );
      kw_FinderRepAlways : FinderRepAlways:= StrToBool( P2 );
      kw_NewRepScript    : { устарело, игнорируем };
      kw_FinderScript    : { устарело, игнорируем };
    else
      raise Exception.Create( LoadString(_SBadToken) );
    end;
  end; { Dispatch_FileList }

  { ------------------------------------------------------- }
  procedure Dispatch_Diz;
  begin
    DizFiles^.Add( S );
  end; { Dispatch_Diz }

  { ------------------------------------------------------- }
  procedure Dispatch_Archive;
  begin
    Archivers^.Add( S );
  end; { Dispatch_Archive }

  { ------------------------------------------------------- }
  procedure Dispatch_DefCmt;
  begin
    DefComments^.Add( S );
  end; { Dispatch_ExtCmt }

  { ------------------------------------------------------- }
  procedure Dispatch_Fetch;
  begin
    Fetches^.Add( S );
  end; { Dispatch_Fetch }

  { ------------------------------------------------------- }
  procedure Dispatch_Exclude;
  begin
    Exclude^.Add( S );
  end; { Dispatch_Exclude }

  { ------------------------------------------------------- }
  procedure Dispatch_Forget;
  begin
    Forget^.Add( S );
  end; { Dispatch_Forget }

  { ------------------------------------------------------- }
  procedure Dispatch_BadStr;
  begin
    BadStrings^.Insert( AllocStr(S) );
  end; { Dispatch_BadStr }

  { ------------------------------------------------------- }
  function GetPar(j: Integer) : String;
  begin
    Result := Trim( ExtractWord( j, S, COMMA ) );
  end; { GetPar }

  { ------------------------------------------------------- }
  procedure Dispatch_Poster;
  var
    p: PPoster;
  begin
    if WordCount( S, COMMA ) <> 7 then
    begin
      // Седьмой параметр появился в build 27
      if WordCount( S, COMMA ) <> 6 then
        raise Exception.Create( LoadString(_SBadPoster) );
      S := S + ', ' + QuotedStr( DEFAULT_POSTER_SCRIPT );
    end;
    New( p, Init );
    with p^ do
    begin
      Area   := GetPar(1);
      _From  := GetPar(2);
      Orig   := StrToAddr( GetPar(3) );
      _To    := GetPar(4);
      Dest   := StrToAddr( GetPar(5) );
      Subj   := GetPar(6);
      Script := ExtractQuoted( GetPar(7) );
    end;
    Posters^.Insert( p );
  end; { DispatchPoster }

  { ------------------------------------------------------- }
  procedure Dispatch_FTN;
  begin
    case KeyWord of
      kw_PrimaryAddr:
        begin
          PrimaryAddr := StrToAddr( P2 );
          Defaddr     := PrimaryAddr;
        end;
      kw_RobotAddr  : RobotAddr   := StrToAddr( P2 );
      kw_UTC        : UTC         := StrToInt( P2 );
      kw_Inbound    : Inbound     := ExistingDir( P2, False );
      kw_PktIn      : PktIn       := ExistingDir( P2, False );
      kw_PktOut     : PktOut      := ExistingDir( P2, False );
      kw_Outbound   : Outbound    := ExistingDir( P2, False );
      kw_Netmail    : Netmail     := ExistingDir( P2, False );
      kw_PktPassword: PktPassword := P2;
    else
      raise Exception.Create( LoadString(_SBadToken) );
    end;
  end; { Dispatch_FTN }

  { ------------------------------------------------------- }
  procedure Dispatch_Finder;
  var
    p: PPoster;
  begin
    S := P2;
    case KeyWord of
      kw_Robot:
        FinderRobots^.Add( S );
      kw_Area :
        begin
          if WordCount( S, COMMA ) <> 4 then
          begin
            // Четвёртый параметр появился в build 27
            if WordCount( S, COMMA ) <> 3 then
              raise Exception.Create( LoadString(_SBadArea) );
            S := S + ', ' + QuotedStr(DEFAULT_FINDER_SCRIPT);
          end;
          New( p, Init );
          with p^ do
          begin
            Area   := GetPar(1);
            _From  := GetPar(2);
            Orig   := StrToAddr( GetPar(3) );
            Script := ExtractQuoted( GetPar(4) );
          end;
          FinderAreas^.Insert( p );
        end;
    else
      raise Exception.Create( LoadString(_SBadToken) );
    end;
  end; { Dispatch_Finder }

  { ------------------------------------------------------- }
  procedure Dispatch_Viewer;
  begin
    Viewers^.Add( S );
  end; { Dispatch_Viewers }

  { ------------------------------------------------------- }
  procedure Dispatch_FileEcho;
  begin
    case KeyWord of
      kw_Robot       : AfixRobots^.Add( P2 );
      kw_OutTicPath  : OutTicPath  := ExistingDir( P2, False );
      kw_BadTicPath  : BadTicPath  := ExistingDir( P2, False );
      kw_Autocreate  : Autocreate  := ExistingDir( P2, False );
      kw_Passthrough : Passthrough := ExistingDir( P2, False );
      kw_FileBoxes   : FileBoxes   := ExistingDir( P2, False );
      kw_TrafficLog  : TrafficLog  := P2;
      kw_HatchPw     : HatchPw     := P2;
      kw_AfixHelp    : AllfixHelp  := P2;
      kw_KillAfixReq : KillAfixReq := StrToBool( P2 );
    else
      raise Exception.Create( LoadString(_SBadToken) );
    end;
  end; { Dispatch_FileEcho }

  { ------------------------------------------------------- }
  procedure Dispatch_Links;
  const
    _EQ = ['='];
  var
    n: Integer;
    j: Integer;
    A: TAddress;
    p: String;
    Link: PEchoLink;
  begin
    n := WordCount( S, COMMA );
    if n < 2 then
      raise Exception.Create( LoadString(_SBadLinks) );
    A := StrToAddr( GetPar(1) );
    p := ExtractQuoted( GetPar(2) );
    if Links^.Search( @A, j ) then
      raise Exception.Create( Format(LoadString(_SLinkDupe), [AddrToStr(A)] ));
    New( Link, Init(A) );
    Links^.Insert( Link );
    with Link^ do
    begin
      OurAka := Cfg^.PrimaryAddr;
      ReplaceStr( Password, p );

      for j := 3 to n do
      begin
        p := GetPar(j);
        if JustSameText( p, TOK_DIRECT ) then
          Flavor := fl_Dir
        else if JustSameText( p, TOK_HOLD ) then
          Flavor := fl_Hold
        else if JustSameText( p, TOK_CRASH ) then
          Flavor := fl_Crash
        else if JustSameText( p, TOK_IMM ) then
          Flavor := fl_Imm
        else if JustSameText( p, TOK_NORMAL ) then
          Flavor := fl_Normal
        else if JustSameText( p, TOK_AUTOCREATE ) then
          Include( Opt, elo_AutoCreate )
        else if JustSameText( p, TOK_AUTOLINK ) then
          Include( Opt, elo_AutoLink )
        else if JustSameText( p, TOK_NOTIFY ) then
          Include( Opt, elo_Notify )
        else if JustSameText( p, TOK_PAUSE ) then
          Include( Opt, elo_Pause )
        else if JustSameText( p, TOK_FILEBOX ) then
          Include( Opt, elo_FileBox )
        else if JustSameText( ExtractWord(1, p, _EQ), TOK_OURAKA ) then
          OurAka := StrToAddr( ExtractWord(2, p, _EQ) )
        else if JustSameText( ExtractWord(1, p, _EQ), TOK_DENY ) then
          Deny^.Insert( AllocStr( ExtractWord(2, p, _EQ) ) )
        else
          raise Exception.Create( Format(LoadString(_SBadLinkToken), [p]) );

      end;
    end;
  end; { Dispatch_Links }

  { ------------------------------------------------------- }

  procedure Dispatch_Avail;
  var
    n : Integer;
    j : Integer;
    p : String;
    A : TAddress;
    AR: PAvailRec;
  begin
    n := WordCount( S, COMMA );
    if n < 2 then
      raise Exception.Create( LoadString(_SBadAvail) );
    A := StrToAddr( GetPar(1) );
    New( AR );
    FillChar( AR^, SizeOf(TAvailRec), 0 );
    CFG^.Avail^.Insert( AR );
    AR^.Addr := A;
    AR^.Name := ExtractQuoted( GetPar(2) );
    for j := 3 to n do
    begin
      p := GetPar(j);
      if JustSameText( p, TOK_INACTIVE ) then
        Include( AR^.Opt, ao_Inactive )
      else
        raise Exception.Create( Format(LoadString(_SBadAvailToken), [p]) );
    end;
  end; { Dispatch_Avail }

  { ------------------------------------------------------- }

  procedure Dispatch_System;
  begin
    case KeyWord of
      kw_FileApi      : FileApi := TFileApiMode( StrToInt(P2) );
      kw_CommonULPath : CommonULPath := ExistingDir( P2, False );
      kw_TempDir      : TempDir := ExistingDir( P2, True );
      kw_Palette      : Palette := P2;
    else
      raise Exception.Create( LoadString(_SBadToken) );
    end;
  end; { Dispatch_System }

  { ------------------------------------------------------- }

begin
  Log^.Write( ll_Service, Format(LoadString(_SLogReadingCfg), [GetConfigName] ));
  Chapter := ch_None;
  Map.Init( GetConfigName );
  OpenWorking( LoadString(_SReadingCfg) );
  OpenProgress( Map.GetSize );
  while Map.GetLine( S ) do
  begin
    try
      UpdateProgress( Map.GetPos );
      StripComment( S );
      if S = '' then Continue;
      if TryChapter then
        Continue;
      case Chapter of
        ch_DizFiles: Dispatch_Diz;
        ch_Archive : Dispatch_Archive;
        ch_DefCmt  : Dispatch_DefCmt;
        ch_Fetch   : Dispatch_Fetch;
        ch_Exclude : Dispatch_Exclude;
        ch_Forget  : Dispatch_Forget;
        ch_BadStr  : Dispatch_BadStr;
        ch_Poster  : Dispatch_Poster;
        ch_Viewer  : Dispatch_Viewer;
        ch_Links   : Dispatch_Links;
        ch_Avail   : Dispatch_Avail;
      else
        if TryParam then
          case Chapter of
            ch_FilesBbs: Dispatch_FilesBbs;
            ch_FileList: Dispatch_FileList;
            ch_FTN     : Dispatch_FTN;
            ch_Finder  : Dispatch_Finder;
            ch_FileEcho: Dispatch_FileEcho;
            ch_System  : Dispatch_System;
          else
            raise Exception.Create( LoadString(_SBadToken) );
          end
        else
          raise Exception.Create( LoadString(_SBadToken) );
      end;
    except
      on E: Exception do
        Log^.WriteEx( ll_Error, GetConfigName, Map.LineNo, S, E.Message );
    end;
  end;
  Map.Done;
  CloseWorking;
{$IFNDEF Win32}
  FileApi := fapi_native;
{$ENDIF}
  if PktIn = ''  then PktIn  := Inbound;
  if PktOut = '' then PktOut := Inbound;

  if Palette <> '' then SetPal( Palette );

end; { ReadTextFile }


{ WriteTextFile ------------------------------------------- }

procedure TConfig.WriteTextFile;
var
  F: Text;

  { ------------------------------------------------------- }
  procedure WriteChapter( Chapter: TCfgChapter );
  begin
    Writeln( F, ^M^J'[' + ChapterName[Chapter] + ']' );
  end; { WriteChapter }

  { ------------------------------------------------------- }
  procedure WriteInt( kw: TCfgKeyWord; Value: Integer );
  begin
    Writeln( F, Format( '%-17s %d', [KeyWordName[kw], Value] ) );
  end; { WriteInt }

  { ------------------------------------------------------- }
  procedure WriteBool( kw: TCfgKeyWord; Value: Boolean );
  begin
    Writeln( F, Format( '%-17s %s', [KeyWordName[kw], BoolToStr(Value)] ));
  end; { WriteBool }

  { ------------------------------------------------------- }
  procedure WriteStr( kw: TCfgKeyWord; const Value: String );
  begin
    if Value <> '' then
      Writeln( F, Format( '%-17s %s', [KeyWordName[kw], Value] ));
  end; { WriteStr }

  { ------------------------------------------------------- }
  procedure Write_FilesBbs;
  begin
    WriteChapter( ch_FilesBbs );
    WriteInt ( kw_Formatting,    Ord(Formatting) );
    WriteBool( kw_WrapSingle,    WrapSingle );
    WriteBool( kw_UseAloneCmt,   UseAloneCmt );
    WriteBool( kw_Sorted,        Sorted );
    WriteInt ( kw_DlcDigs,       DlcDigs );
    WriteBool( kw_AlignDLC,      AlignDLC );
    WriteBool( kw_ReadOnly,      ReadOnly );
    WriteInt ( kw_BAK_Level,     BAK_Level );
    WriteInt ( kw_AreasBakLevel, AreasBakLevel );
    WriteBool( kw_DropMissing,   DropMissing );
    WriteBool( kw_TouchNew,      TouchNew );
    WriteBool( kw_KeepOldCmt,    KeepOldCmt );
    WriteInt ( kw_NewFilesAge,   NewFilesAge );
    WriteInt ( kw_BestCount,     BestCount );
    WriteInt ( kw_CD_Timeout,    CD_Timeout );
  end; { Write_FilesBbs }

  { ------------------------------------------------------- }
  procedure Write_FileList;
  begin
    WriteChapter( ch_FileList );
    WriteBool( kw_ScanNewFiles,    ScanNewFiles );
    WriteBool( kw_BuildAllList,    BuildAllList );
    WriteBool( kw_BuildNewList,    BuildNewList );
    WriteBool( kw_BuildNewRep,     BuildNewRep );
    WriteBool( kw_BuildBestArea,   BuildBestArea );
    WriteStr ( kw_FileAreaCtl,     FileAreaCtl );
    WriteStr ( kw_AllFilesList,    AllFilesList );
    WriteStr ( kw_NewFilesList,    NewFilesList );
    WriteStr ( kw_FreqDirList,     FreqDirs );
    WriteStr ( kw_MagicFiles,      MagicFiles );
    WriteStr ( kw_AllFilesScript,  AllFilesScript );
    WriteStr ( kw_NewFilesScript,  NewFilesScript );
    WriteBool( kw_FinderRepAlways, FinderRepAlways );
  end; { Write_FileList }

  { ------------------------------------------------------- }
  procedure Write_Diz;
  var
    j: Integer;
  begin
    if DizFiles^.Count > 0 then
    begin
      WriteChapter( ch_DizFiles );
      for j := 0 to DizFiles^.Count - 1 do
        Writeln( F, PString(DizFiles^.At(j))^ );
    end;
  end; { Write_Diz }

  { ------------------------------------------------------- }
  procedure Write_Archive;
  var
    j: Integer;
  begin
    if Archivers^.Count > 0 then
    begin
      WriteChapter( ch_Archive );
      for j := 0 to Archivers^.Count - 1 do
        Writeln( F, PString(Archivers^.At(j))^ );
    end;
  end; { Write_Archive }

  { ------------------------------------------------------- }
  procedure Write_Fetch;
  var
    j: Integer;
  begin
    if Fetches^.Count > 0 then
    begin
      WriteChapter( ch_Fetch );
      for j := 0 to Fetches^.Count - 1 do
        Writeln( F, PString(Fetches^.At(j))^ );
    end;
  end; { Write_Fetch }

  { ------------------------------------------------------- }
  procedure Write_DefCmt;
  var
    j: Integer;
  begin
    if DefComments^.Count > 0 then
    begin
      WriteChapter( ch_DefCmt );
      for j := 0 to DefComments^.Count - 1 do
        Writeln( F, PString(DefComments^.At(j))^ );
    end;
  end; { Write_ExtCmt }

  { ------------------------------------------------------- }
  procedure Write_BadStr;
  var
    j: Integer;
  begin
    if BadStrings^.Count > 0 then
    begin
      WriteChapter( ch_BadStr );
      for j := 0 to BadStrings^.Count - 1 do
        Writeln( F, PString(BadStrings^.At(j))^ );
    end;
  end; { Write_BadStr }

  { ------------------------------------------------------- }
  procedure Write_Exclude;
  var
    j: Integer;
  begin
    if Exclude^.Count > 0 then
    begin
      WriteChapter( ch_Exclude );
      for j := 0 to Exclude^.Count - 1 do
        Writeln( F, PString(Exclude^.At(j))^ );
    end;
  end; { Write_Exclude }

  { ------------------------------------------------------- }
  procedure Write_Forget;
  var
    j: Integer;
  begin
    if Forget^.Count > 0 then
    begin
      WriteChapter( ch_Forget );
      for j := 0 to Forget^.Count - 1 do
        Writeln( F, PString(Forget^.At(j))^ );
    end;
  end; { Write_Forget }

  { ------------------------------------------------------- }
  procedure Write_FTN;
  begin
    WriteChapter( ch_FTN );
    WriteStr( kw_PrimaryAddr, AddrToStr(PrimaryAddr) );
    WriteStr( kw_RobotAddr,   AddrToStr(RobotAddr) );
    WriteInt( kw_UTC,         UTC );
    WriteStr( kw_PktIn,       PktIn );
    WriteStr( kw_PktOut,      PktOut );
    WriteStr( kw_Inbound,     Inbound );
    WriteStr( kw_Outbound,    Outbound );
    WriteStr( kw_Netmail,     Netmail );
    WriteStr( kw_PktPassword, PktPassword );
  end; { Write_FTN }

  { ------------------------------------------------------- }
  procedure Write_Poster;
    procedure DoWrite( P: PPoster ); far;
    begin
      with P^ do
        Writeln( F, Area, ', ',
          _From, ', ', AddrToStr(Orig), ', ',
          _To,   ', ', AddrToStr(Dest), ', ',
          Subj, ', ', QuotedStr(Script) );
    end; { WritePoster }
  begin
    if Posters^.Count > 0 then
    begin
      WriteChapter( ch_Poster );
      Posters^.ForEach( @DoWrite);
    end;
  end; { WritePoster }

  { ------------------------------------------------------- }
  procedure Write_Finder;

    procedure WriteRobot( P: PString ); far;
    begin
      WriteStr( kw_Robot, P^ );
    end; { WriteRobot }

    procedure WriteArea( P: PPoster); far;
    begin
      with P^ do
        WriteStr( kw_Area, Area + ', ' + _From + ', ' + AddrToStr(Orig) + ', ' + QuotedStr(Script) );
    end; { WriteArea }

  begin
    if (FinderRobots^.Count > 0) or (FinderAreas^.Count > 0) then
    begin
      WriteChapter( ch_Finder );
      FinderRobots^.ForEach( @WriteRobot );
      FinderAreas^.ForEach( @WriteArea );
    end;
  end; { WriteFinder }

  { ------------------------------------------------------- }
  procedure Write_Viewer;
  var
    j: Integer;
  begin
    if Viewers^.Count > 0 then
    begin
      WriteChapter( ch_Viewer);
      for j := 0 to Viewers^.Count - 1 do
        Writeln( F, PString(Viewers^.At(j))^ );
    end;
  end; { Write_Viewer }

  { ------------------------------------------------------- }
  procedure Write_FileEcho;
    procedure WriteRobot( P: PString ); far;
    begin
      WriteStr( kw_Robot, P^ );
    end; { WriteRobot }
  begin
    WriteChapter( ch_FileEcho );
    WriteStr ( kw_OutTicPath,  OutTicPath );
    WriteStr ( kw_BadTicPath,  BadTicPath );
    WriteStr ( kw_Autocreate,  Autocreate );
    WriteStr ( kw_Passthrough, Passthrough );
    WriteStr ( kw_FileBoxes,   FileBoxes );
    WriteStr ( kw_TrafficLog,  TrafficLog );
    WriteStr ( kw_HatchPw,     HatchPw );
    WriteStr ( kw_AfixHelp,    AllFixHelp );
    WriteBool( kw_KillAfixReq, KillAfixReq );
    AfixRobots^.ForEach( @WriteRobot );
  end; { Write_FileEcho }

  { ------------------------------------------------------- }
  procedure Write_Links;
    procedure WriteLink( Link: PEchoLink ); far;
    var
      S: String;
      j: Integer;
    begin
      with Link^ do
      begin
        case Flavor of
          fl_Normal: S := TOK_NORMAL;
          fl_Hold  : S := TOK_HOLD;
          fl_Crash : S := TOK_CRASH;
          fl_Dir   : S := TOK_DIRECT;
          fl_Imm   : S := TOK_IMM;
        end;
        S := AddrToStr( Addr ) + ', ' + QuotedStr(Password^) + ', ' + S;
        if CompAddr( OurAka, Cfg^.PrimaryAddr ) <> 0 then
          S := S + ', ' + TOK_OURAKA + '=' + AddrToStr( OurAka );
        if elo_Notify in Opt then
          S := S + ', ' + TOK_NOTIFY;
        if elo_AutoCreate in Opt then
          S := S + ', ' + TOK_AUTOCREATE;
        if elo_AutoLink in Opt then
          S := S + ', ' + TOK_AUTOLINK;
        if elo_Pause in Opt then
          S := S + ', ' + TOK_PAUSE;
        if elo_FileBox in Opt then
          S := S + ', ' + TOK_FILEBOX;

        for j := 0 to Pred(Deny^.Count) do
          S := S + ', ' + TOK_DENY + '=' + PString(Deny^.At(j))^;

      end;
      Writeln( F, S );
    end; { WriteLink }

  begin
    if Links^.Count > 0 then
    begin
      WriteChapter( ch_Links );
      Links^.ForEach( @WriteLink );
    end;
  end; { Write_Links }

  { ------------------------------------------------------- }

  procedure Write_Avail;
    procedure WriteAR( AR: PAvailRec ); far;
    var
      S: String;
    begin
      S := AddrToStr(AR^.Addr) + ', ' + QuotedStr(AR^.Name);
      if ao_Inactive in AR^.Opt then
        S := S + ', ' + TOK_INACTIVE;
      Writeln( F, S );
    end; { WriteAR }
  begin
    if Avail^.Count > 0 then
    begin
      WriteChapter( ch_Avail );
      Avail^.ForEach( @WriteAR );
    end;
  end; { Write_Avail }

  { ------------------------------------------------------- }

  procedure Write_System;
  begin
    WriteChapter( ch_System );
    WriteInt( kw_FileApi, Ord(FileApi) );
    WriteStr( kw_CommonULPath, CommonULPath );
    if not JustSameText( TempDir, GetEnv('TEMP') ) then
      WriteStr( kw_TempDir, TempDir );
    WriteStr( kw_Palette, Palette );
  end; { Write_System }

  { ------------------------------------------------------- }

begin
  Log^.Write( ll_Service, LoadString(_SLogSavingCfg) );
  Assign( F, GetConfigName ); Rewrite( F );
  Write_System;
  Write_FilesBbs;
  Write_FileList;
  Write_Diz;
  Write_Viewer;
  Write_Archive;
  Write_Fetch;
  Write_DefCmt;
  Write_Exclude;
  Write_Forget;
  Write_BadStr;
  Write_FTN;
  Write_Poster;
  Write_Finder;
  Write_FileEcho;
  Write_Links;
  Write_Avail;
  Close( F );
  Modified := False;
end; { WriteTextFile }


{ --------------------------------------------------------- }
{ GetConfigName                                             }
{ --------------------------------------------------------- }

function GetConfigName: String;
const
  EQ = ['='];
var
  S: String;
  j: Integer;
begin
  for j := 1 to ParamCount do
  begin
    S := ParamStr( j );
    if JustSameText( ExtractWord( 1, S, EQ ), 'CFG' ) then
    begin
      Result := ExtractWord( 2, S, EQ );
      Exit;
    end;
  end;
  Result := ChangeFileExt( HomeDir, '.cfg' );
end; { GetConfigName }


end.
