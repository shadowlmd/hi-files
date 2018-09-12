unit Main;

/////////////////////////////////////////////////////////////////////
//
// Hi-Files Version 2
// Copyright (c) 1997-2004 Dmitry Liman [2:461/79]
//
// http://hi-files.narod.ru
//
/////////////////////////////////////////////////////////////////////

interface

procedure Run;

{ =================================================================== }

implementation

uses
{$IFDEF WIN32}
  Unrar, Unzip, _Locale,
{$ENDIF}
  Objects, App, Drivers, Views, Dialogs, vpUtils, MyLib,
  Menus, SysUtils, MsgBox, _RES,  _CFG, _LOG, _BSY, _FAreas,
  Setup, SetEcho, _Working, Gen, Finder, AreaPane, EchoPane, _Tic,
  AreaFix, Hatch, BHatch, HelpFile, About, _pal, hifihelp, myviews;

type
  PMyApp = ^TMyApp;
  TMyApp = object (TApplication)
    HelpInUse: Boolean;
    constructor Init;
    destructor Done; virtual;
    procedure ShowHelp( Ctx: Word );
    procedure GetEvent( var Event: TEvent ); virtual;
    procedure HandleEvent( var Event: TEvent ); virtual;
    procedure InitMenuBar; virtual;
    procedure InitStatusLine; virtual;
    function  GetPalette: PPalette; virtual;
    procedure Configure;
    procedure Batch;
    function OkForBatch: Boolean;
  end; { TMyApp }

const
  cmSetupFtn = 300;
  cmChooseFileAreaCtl = 301;
  cmSetupFilesBbs = 302;
  cmSetupDiz = 303;
  cmSetupArc = 304;
  cmSetupFetch = 305;
  cmSetupDefCmt = 306;
  cmSetupBadStr = 307;
  cmSetupGenFiles = 308;
  cmSetupScan = 309;
  cmSetupPoster = 310;
  cmSetupForget = 317;
  cmSetupFileAreas = 313;
  cmSetupFileEchoProcessor = 314;
  cmSetupFileEchoLinks = 315;
  cmOpenFileEcho = 316;
  cmHatch = 318;
  cmGen = 319;
  cmHelpContents = 320;
  cmAbout = 321;
  cmForwardReq = 322;
  cmSetupFileApi = 190;
  cmSetupExclude = 324;
  cmSetupFinderOpt    = 330;
  cmSetupFinderAreas  = 331;
  cmSetupFinderRobots = 332;
  cmEditPal = 350;
  cmLoadPal = 351;
  cmSavePal = 352;


{ --------------------------------------------------------- }
{ TMyApp                                                    }
{ --------------------------------------------------------- }

constructor TMyApp.Init;
begin
  CFG := nil;
  LOG := nil;
  FileBase := nil;
{$IFDEF Win32}
  ReadLocale;
{$ENDIF}
  RegisterObjects;
  RegisterViews;
  RegisterDialogs;
  RegisterMenus;
  RegisterType( RStringList );
  RegisterHelpFile;
  OpenResource;
  inherited Init;
end; { Init }

{ --------------------------------------------------------- }
{ Done                                                      }
{ --------------------------------------------------------- }

destructor TMyApp.Done;
begin
{$IFDEF WIN32}
  UnloadUnrar;
  UnloadUnzip;
{$ENDIF}
  CloseFileBase;
  if (CFG <> nil) and CFG^.Modified and
     (CFG^.BatchMode or
     (MessageBox( LoadString(_SSaveConfig), nil, mfConfirmation + mfYesButton + mfNoButton ) = cmYes))
  then
    CFG^.WriteTextFile;
  Destroy( CFG );
  CloseResource;
  inherited Done;
end; { Done }

{ --------------------------------------------------------- }
{ InitStatusLine                                            }
{ --------------------------------------------------------- }

procedure TMyApp.InitStatusLine;
var
  R: TRect;
begin
  GetExtent(R);
  R.A.Y := R.B.Y - 1;
  New(StatusLine, Init(R,
    NewStatusDef(hcAreaMgr, hcFileEchoManager,
      NewStatusKey('~F1~ Help', kbF1, cmHelp,
      NewStatusKey('~F3~ Открыть', kbF3, cmEnter,
      NewStatusKey('~F4~ Опции', kbF4, cmOptions,
      NewStatusKey('~F5~ Импорт', kbF5, cmImport,
      NewStatusKey('~Ins~ Создать', kbIns, cmInsItem,
      NewStatusKey('~Del~ Удалить', kbDel, cmDelItem,
      nil)))))),
    NewStatusDef(0, $FFFF,
      NewStatusKey('~F1~ Help',    kbF1,   cmHelp,
      NewStatusKey('~F10~ Menu',   kbF10,  cmMenu,
      NewStatusKey('~Alt-X~ Exit', kbAltX, cmQuit,
      StdStatusKeys(nil)))), nil))));
end; { InitStatusLine }


{ --------------------------------------------------------- }
{ InitMenuBar                                               }
{ --------------------------------------------------------- }

procedure TMyApp.InitMenuBar;
begin
  MenuBar := PMenuBar( Res^.Get( 'MAIN_MENU' ) );
  MenuBar.Size.X := Desktop.Size.X;
{$IFNDEF Win32}
  DisableCommands( [cmSetupFileApi] );
{$ENDIF}
end { InitMenuBar };

{ --------------------------------------------------------- }
{ GetPalette                                                }
{ --------------------------------------------------------- }

function TMyApp.GetPalette: PPalette;
const
  CNewColor = CAppColor + CHelpColor;
  CNewBlackWhite = CAppBlackWhite + CHelpBlackWhite;
  CNewMonochrome = CAppMonochrome + CHelpMonochrome;
  P: array[apColor..apMonochrome] of string[Length(CNewColor)] =
    (CNewColor, CNewBlackWhite, CNewMonochrome);
begin
  GetPalette := @P[AppPalette];
end; { GetPalette }

{ --------------------------------------------------------- }
{ ShowHelp                                                  }
{ --------------------------------------------------------- }

procedure TMyApp.ShowHelp( Ctx: Word );
var
  W: PWindow;
  HFile: PHelpFile;
  HelpStrm: PDosStream;
begin
  if not HelpInUse then
  begin
    HelpInUse := True;
    HelpStrm := New(PDosStream, Init(ChangeFileExt(HomeDir, '.hlp'), stOpenRead));
    HFile := New(PHelpFile, Init(HelpStrm));
    if HelpStrm^.Status <> stOk then
    begin
      MessageBox(LoadString(_SNoHelpFile), nil, mfError + mfOkButton);
      Destroy(HFile);
    end
    else
    begin
      W := New(PHelpWindow,Init(HFile, Ctx));
      if ValidView(W) <> nil then
      begin
        ExecView(W);
        Destroy(W);
      end;
    end;
    HelpInUse := False;
  end;
end; { ShowHelp }


{ --------------------------------------------------------- }
{ GetEvent                                                  }
{ --------------------------------------------------------- }

procedure TMyApp.GetEvent( var Event: TEvent );
begin
  inherited GetEvent( Event );
  case Event.What of
    evCommand:
      if Event.Command = cmHelp then
      begin
        ShowHelp( GetHelpCtx );
        ClearEvent( Event );
      end;
  end;
end; { GetEvent }


{ --------------------------------------------------------- }
{ HandleEvent                                               }
{ --------------------------------------------------------- }

procedure TMyApp.HandleEvent( var Event: TEvent );
begin
  inherited HandleEvent( Event );
  case Event.What of
    evCommand:
      begin
        case Event.Command of
          cmSetupFtn: SetupFTN;
          cmChooseFileAreaCtl: ChooseFileAreaCtl;
          cmSetupFilesBbs: SetupFilesBbs;
          cmSetupDiz: SetupDiz;
          cmSetupArc: SetupArc;
          cmSetupFetch: SetupFetch;
          cmSetupDefCmt: SetupDefCmt;
          cmSetupBadStr: SetupBadStr;
          cmSetupGenFiles: SetupGenFiles;
          cmSetupScan: SetupScan;
          cmSetupPoster: SetupPoster;
          cmSetupFinderOpt   : SetupFinderOpt;
          cmSetupFinderAreas : SetupFinderAreas;
          cmSetupFinderRobots: SetupFinderRobots;
          cmSetupForget: SetupForget;
          cmSetupFileAreas: OpenFileAreas;
          cmSetupFileEchoProcessor: SetupFileEchoProcessor;
          cmSetupFileEchoLinks: SetupFileEchoLinks;
          cmOpenFileEcho: OpenFileEchoes;
          cmHatch: RunHatcher;
          cmGen: RunGenerator;
          cmHelpContents: ShowHelp( hcNoContext );
          cmAbout: ShowAbout;
          cmForwardReq: SetupForwardReq;
          cmSetupFileApi: SetupFileApi;
          cmSetupExclude: SetupExclude;
          cmEditPal: EditPal;
          cmLoadPal: LoadPal;
          cmSavePal: SavePal;
        else
          Exit;
        end;
        ClearEvent( Event );
      end;
  end;
end; { HandleEvent }


{ --------------------------------------------------------- }
{ Configure                                                 }
{ --------------------------------------------------------- }

procedure TMyApp.Configure;
begin
  CFG := New( PConfig, Init );
  if FileExists( GetConfigName ) then
  begin
    CFG^.ReadTextFile;
    try
      CFG^.EatCommandLine;
    except
      on E: Exception do
        ShowError( Format(LoadString(_SCmdLineError), [E.Message]) );
    end;
  end
  else if MessageBox( LoadString(_SCreateNewCfg),
                      nil, mfWarning + mfYesNoCancel ) = cmYes then
  begin
    CFG^.SetDefaults;
    CFG^.WriteTextFile;
  end
  else
    raise Exception.Create( LoadString(_SNewCfgDisabled) );
end; { Configure }

{ --------------------------------------------------------- }
{ OkForBatch                                                }
{ --------------------------------------------------------- }

function TMyApp.OkForBatch: Boolean;
begin
  Result := CFG^.BatchMode;
  if Result and Log^.HasErrors then
  begin
    MessageBox( LoadString(_SBatchRejected), nil, mfInformation + mfOkButton );
    Result := False;
  end;
end; { OkForBatch }

{ --------------------------------------------------------- }
{ Batch                                                     }
{ --------------------------------------------------------- }

procedure TMyApp.Batch;
begin
  OpenWorking( LoadString(_SBatchRunning) );
  try
    if CFG^.RunAreafix then
      RunAreafix;
    if CFG^.RunTicTosser then
      RunTicTosser;
    if CFG^.RunHatcher then
      BatchHatcher;
    // Финдеp нада запущать *до* генеpатоpа, тогда генеpатоp
    // будет ипользовать файловую базу, откpытую финдеpом.
    // Ессно, финдеp после себя должен бpосить базу откpытой .)
    if CFG^.RunFinder then
      RunFinder;
    if CFG^.RunGenerator then
      RunGenerator;
  except
    on E: Exception do
      Log^.Write( ll_error, Format(LoadString(_SBatchInterrupted), [E.Message] ));
  end;
  CloseWorking;
end; { Batch }

{ --------------------------------------------------------- }
{ ShowHelp                                                  }
{ --------------------------------------------------------- }

procedure ShowHelp;
begin
  Writeln( 'Параметры командной строки:' );
  Writeln;
  Writeln( 'CFG=<cfg-file> - задание конфига, отличного от дефолтного' );
  Writeln;
  Writeln( 'GEN     - Новая форма "-DO" ;-)' );
  Writeln( 'TIC     - Тоссинг тиков' );
  Writeln( 'AFIX    - Менеджер подписки файлэхопроцессора' );
  Writeln( 'FIND    - Финдер' );
  Writeln;
  Writeln( 'HATCH[=<ctl-file>] - Пакетный хатчер');
  Writeln;
  Writeln( 'Применительно к "GEN" можно указывать следующие опции:' );
  Writeln;
  Writeln( '-NOREP    - Запрет генерации отчетов' );
  Writeln( '-NOSCAN   - Запрет сканирования файловых областей' );
  Writeln( '-FORCE    - Принудительно выдернуть из архивов описатели, если они там есть' );
  Writeln( '-UPDATE   - То же, что и "-FORCE", только если файл еще не описан' );
  Writeln( '-READONLY - Запрет модификации files.bbs' );
  Writeln;
  Writeln( 'Запуск без параметров - интерактивный режим.' );
  Halt;
end; { ShowHelp }


{ --------------------------------------------------------- }
{ Run                                                       }
{ --------------------------------------------------------- }

procedure Run;
var
  App: TMyApp;
  Mem: Integer;
begin
  Mem := MemUsed;
  Writeln(
    #10#13#254#32 +
    PROG_NAME +
    ' Version ' + PROG_VER + ' ' + PLATFORM + ' ' +
    COPYRIGHT + ^M^J );

  if Pos( '?', ParamStr(1) ) > 0 then
    ShowHelp;

  Randomize;
  App.Init;
  if SetBusyFlag then
  begin
    Log := New( PLog, Init(True) );
    try
      App.Configure;
      if Log^.HasWarnings then
        ShowLog;
      if App.OkForBatch then
        App.Batch
      else
      begin
        ShowAbout;
        App.Run;
      end;
    finally
      App.Done;
      Destroy( Log );
      DropBusyFlag;
    end;
  end
  else
    App.Done;

  Mem := MemUsed - Mem;
  Writeln(
    #10#13#254#32 +
    PROG_NAME + ' done; memory leak = ' + Int2Str(Mem) + ' bytes' );

end; { Run }

end.
