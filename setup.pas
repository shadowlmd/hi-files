unit Setup;

/////////////////////////////////////////////////////////////////////
//
// Hi-Files Version 2
// Copyright (c) 1997-2004 Dmitry Liman [2:461/79]
//
// http://hi-files.narod.ru
//
/////////////////////////////////////////////////////////////////////

interface

uses Objects;

procedure SetupFTN;
procedure ChooseFileAreaCtl;
procedure SetupFilesBbs;
procedure SetupDiz;
procedure SetupArc;
procedure SetupFetch;
procedure SetupDefCmt;
procedure SetupBadStr;
procedure SetupExclude;
procedure SetupGenFiles;
procedure SetupScan;
procedure SetupPoster;
procedure SetupFinderOpt;
procedure SetupFinderAreas;
procedure SetupFinderRobots;
procedure SetupForget;
procedure SetupFileApi;

procedure EditStrList ( const Title: String; List: PCollection; HelpCtx: Word );
procedure EditAddrList( const Title: String; List: PCollection; HelpCtx: Word );

{ =================================================================== }

implementation

uses
  Dialogs, App, Views, _CFG, _RES, _LOG, MsgAPI, MyLib, SysUtils,
  _FAreas, MyViews, Drivers, MsgBox, HiFiHelp, _fopen;

{ --------------------------------------------------------- }
{ SetupFTN                                                  }
{ --------------------------------------------------------- }

procedure SetupFTN;
var
  D: PDialog;
  Data: record
    PrimaryAddr: ShortStr;
    RobotAddr  : ShortStr;
    UTC        : ShortStr;
    PktIn   : LongStr;
    PktOut  : LongStr;
    Inbound : LongStr;
    Outbound: LongStr;
    Netmail : LongStr;
    PktPass : ShortStr;
  end;
begin
  D := PDialog( Res^.Get('SETUP_FTN') );
  D^.HelpCtx := hcSetupFtn;
  FillChar( Data, SizeOf(Data), 0 );
  Data.PrimaryAddr := AddrToStr(CFG^.PrimaryAddr);
  Data.RobotAddr   := AddrToStr(CFG^.RobotAddr);
  Data.UTC      := IntToSignedStr(CFG^.UTC);
  Data.PktIn    := CFG^.PktIn;
  Data.PktOut   := CFG^.PktOut;
  Data.Inbound  := CFG^.Inbound;
  Data.Outbound := CFG^.Outbound;
  Data.Netmail  := CFG^.Netmail;
  Data.PktPass  := CFG^.PktPassword;
  if Application^.ExecuteDialog( D, @Data ) = cmOk then
  begin
    CFG^.Modified := True;
    try
      CFG^.PrimaryAddr := StrToAddr( Data.PrimaryAddr );
      DefAddr := CFG^.PrimaryAddr;
      CFG^.RobotAddr   := StrToAddr( Data.RobotAddr );
      CFG^.UTC := StrToInt( Data.UTC );
      CFG^.PktIn    := ExistingDir( Data.PktIn, True );
      CFG^.PktOut   := ExistingDir( Data.PktOut, True );
      CFG^.Inbound  := ExistingDir( Data.Inbound, True );
      CFG^.Outbound := ExistingDir( Data.Outbound, True );
      CFG^.Netmail  := ExistingDir( Data.Netmail, True );
      CFG^.PktPassword := Data.PktPass;
    except
      on E: Exception do
        ShowError( E.Message );
    end;
  end;
end; { SetupFTN }

{ --------------------------------------------------------- }
{ ChooseFileAreaCtl                                         }
{ --------------------------------------------------------- }

procedure ChooseFileAreaCtl;
var
  FileName: String;
begin
  FileName := '*.Ctl';
  if not ExecFileOpenDlg(LoadString(_SChooseFACtl), AtHome(FileName), FileName) then Exit;
  CFG^.Modified := True;
  try
    CFG^.FileAreaCtl := ExistingFile( FileName );
    CloseFileBase;
  except
    on E: Exception do
      ShowError( E.Message );
  end;
  if Log^.HasWarnings then
    ShowLog;
end; { ChooseFileAreaCtl }

{ --------------------------------------------------------- }
{ SetupFilesBbs                                             }
{ --------------------------------------------------------- }

procedure SetupFilesBbs;
const
  bUseAlone     = $0001;
  bSorted       = $0002;
  bDropMissing  = $0004;
  bReadOnly     = $0008;
var
  D: PDialog;
  L: Integer;
  Data: record
    Cmt : Longint;
    Cont: Longint;
    BAK : ShortStr;
    DLC : ShortStr;
  end;
  Reformat: Boolean;
begin
  D := PDialog( Res^.Get('SETUP_BBS') );
  D^.HelpCtx := hcSetupFilesBbs;
  FillChar( Data, SizeOf(Data), 0 );
  SetBit( Data.Cmt, bUseAlone,    CFG^.UseAloneCmt );
  SetBit( Data.Cmt, bSorted,      CFG^.Sorted );
  SetBit( Data.Cmt, bDropMissing, CFG^.DropMissing );
  SetBit( Data.Cmt, bReadOnly,    CFG^.ReadOnly );
  Data.Cont := Ord( CFG^.Formatting );
  Data.BAK := IntToStr( CFG^.BAK_Level );
  Data.DLC := IntToStr( CFG^.DlcDigs );
  if Application^.ExecuteDialog( D, @Data ) = cmOk then
  begin
    Reformat := False;

    if Ord(CFG^.Formatting) <> Data.Cont then
    begin
      if MessageBox( LoadString(_SNeedReformat), nil, mfWarning + mfYesNoCancel ) <> cmYes then
        Exit;
      LoadFileBase;
      Reformat := True;
    end;

    CFG^.Modified := True;
    try
      CFG^.UseAloneCmt := TestBit( Data.Cmt, bUseAlone );
      CFG^.Sorted      := TestBit( Data.Cmt, bSorted );
      CFG^.DropMissing := TestBit( Data.Cmt, bDropMissing );
      CFG^.ReadOnly    := TestBit( Data.Cmt, bReadOnly );
      CFG^.Formatting  := TFilesBbsFormat( Data.Cont );
      CFG^.DlcDigs     := StrToInt( Data.DLC );

      if CFG^.DlcDigs > 5 then
        CFG^.DlcDigs := 5;

      if Data.BAK = '' then
        L := 0
      else
        L := StrToInt(Data.BAK);

      if (L >= 0) and (L <= 9) then
        CFG^.BAK_Level := L
      else
        raise Exception.Create( LoadString(_SBadBakLevel) );

    except
      on E: Exception do
        ShowError( E.Message );
    end;

    if Reformat then
      FileBase^.WriteFilesBbs;

  end;

end; { SetupFilesBbs }

{ --------------------------------------------------------- }
{ SetupDiz                                                  }
{ --------------------------------------------------------- }

procedure SetupDiz;
begin
  EditStrList( LoadString(_SDizCaption), CFG^.DizFiles, hcSetupDiz );
  CFG^.Modified := True;
end; { SetupDiz }

{ --------------------------------------------------------- }
{ SetupArc                                                  }
{ --------------------------------------------------------- }

procedure SetupArc;
begin
  EditStrList( LoadString(_SArcCaption), CFG^.Archivers, hcSetupArc );
  CFG^.Modified := True;
end; { SetupArc }

{ --------------------------------------------------------- }
{ SetupFetch                                                }
{ --------------------------------------------------------- }

procedure SetupFetch;
begin
  EditStrList( LoadString(_SFetchCaption), CFG^.Fetches, hcSetupFetch );
  CFG^.Modified := True;
end; { SetupFetch }

{ --------------------------------------------------------- }
{ SetupDefCmt                                               }
{ --------------------------------------------------------- }

procedure SetupDefCmt;
begin
  EditStrList( LoadString(_SDefCmtCaption), CFG^.DefComments, hcSetupDefCmt );
  CFG^.Modified := True;
end; { SetupDefCmt }

{ --------------------------------------------------------- }
{ SetupBadStr                                               }
{ --------------------------------------------------------- }

procedure SetupBadStr;
begin
  EditStrList( LoadString(_SBadStrCaption), CFG^.BadStrings, hcSetupBadStr );
  CFG^.Modified := True;
end; { SetupBadStr }

{ --------------------------------------------------------- }
{ SetupExclude                                              }
{ --------------------------------------------------------- }

procedure SetupExclude;
begin
  EditStrList( LoadString(_SExclCaption), CFG^.Exclude, hcSetupExclude );
  CFG^.Modified := True;
end; { SetupExclude }

{ --------------------------------------------------------- }
{ SetupGenFiles                                             }
{ --------------------------------------------------------- }

procedure SetupGenFiles;
var
  D: PDialog;
  Data: record
    AllFilesList  : LongStr;
    AllFilesScript: LongStr;
    NewFilesList  : LongStr;
    NewFilesScript: LongStr;
    FreqDir       : LongStr;
    MagicFiles    : LongStr;
  end;
begin
  D := PDialog( Res^.Get('SETUP_GFIL') );
  D^.HelpCtx := hcSetupGenFiles;
  FillChar( Data, SizeOf(Data), 0 );
  Data.AllFilesList   := CFG^.AllFilesList;
  Data.AllFilesScript := CFG^.AllFilesScript;
  Data.NewFilesList   := CFG^.NewFilesList;
  Data.NewFilesScript := CFG^.NewFilesScript;
  Data.FreqDir        := CFG^.FreqDirs;
  Data.MagicFiles     := CFG^.MagicFiles;
  if Application^.ExecuteDialog( D, @Data ) = cmOk then
  begin
    CFG^.Modified := True;
    try
      CFG^.AllFilesList   := ExistingPath( Data.AllFilesList );
      CFG^.AllFilesScript := ExistingFile( Data.AllFilesScript );
      CFG^.NewFilesList   := ExistingPath( Data.NewFilesList );
      CFG^.NewFilesScript := ExistingFile( Data.NewFilesScript );
      CFG^.FreqDirs       := ExistingPath( Data.FreqDir );
      CFG^.MagicFiles     := ExistingPath( Data.MagicFiles );
    except
      on E: Exception do
        ShowError( E.Message );
    end;
  end;
end; { SetupGenFiles }

{ --------------------------------------------------------- }
{ SetupScan                                                 }
{ --------------------------------------------------------- }

procedure SetupScan;
const
  bScanNew   = $0001;
  bTouchNew  = $0002;
  bKeepOld   = $0004;
  bAllList   = $0001;
  bNewList   = $0002;
  bBestArea  = $0004;
  bNewRep    = $0008;
var
  D: PDialog;
  Data: record
    Scan: Longint;
    Gen : Longint;
    CD  : ShortStr;
    Age : ShortStr;
    Best: ShortStr;
    Bak : ShortStr;
  end;
begin
  D := PDialog( Res^.Get('SETUP_SCAN') );
  D^.HelpCtx := hcSetupScan;
  FillChar( Data, SizeOf(Data), 0 );
  SetBit( Data.Scan, bScanNew,  CFG^.ScanNewFiles );
  SetBit( Data.Scan, bTouchNew, CFG^.TouchNew );
  SetBit( Data.Scan, bKeepOld,  CFG^.KeepOldCmt );
  SetBit( Data.Gen,  bAllList,  CFG^.BuildAllList );
  SetBit( Data.Gen,  bNewList,  CFG^.BuildNewList );
  SetBit( Data.Gen,  bBestArea, CFG^.BuildBestArea );
  SetBit( Data.Gen,  bNewRep,   CFG^.BuildNewRep );
  Data.CD   := IntToStr( CFG^.CD_Timeout );
  Data.Age  := IntToStr( CFG^.NewFilesAge );
  Data.Best := IntToStr( CFG^.BestCount );
  Data.Bak  := IntToStr( CFG^.AreasBakLevel );
  if Application^.ExecuteDialog( D, @Data ) = cmOk then
  begin
    CFG^.Modified := True;
    try
      CFG^.ScanNewFiles  := TestBit( Data.Scan, bScanNew );
      CFG^.TouchNew      := TestBit( Data.Scan, bTouchNew );
      CFG^.KeepOldCmt    := TestBit( Data.Scan, bKeepOld );
      CFG^.BuildAllList  := TestBit( Data.Gen,  bAllList );
      CFG^.BuildNewList  := TestBit( Data.Gen,  bNewList );
      CFG^.BuildBestArea := TestBit( Data.Gen,  bBestArea );
      CFG^.BuildNewRep   := TestBit( Data.Gen,  bNewRep );
      CFG^.CD_Timeout    := StrToInt( Data.CD );
      CFG^.NewFilesAge   := StrToInt( Data.Age );
      CFG^.BestCount     := StrToInt( Data.Best );
      CFG^.AreasBakLevel := StrToInt( Data.Bak );
    except
      on E: Exception do
        ShowError( E.Message );
    end;
  end;
end; { SetupScan }

{ --------------------------------------------------------- }
{ SetupFinderRobots                                         }
{ --------------------------------------------------------- }

procedure SetupFinderRobots;
begin
  EditStrList( LoadString(_SFinderRobotsCaption), CFG^.FinderRobots, hcSetupFinderRobots );
  CFG^.Modified := True;
end; { SetupFinderRobots }


{ --------------------------------------------------------- }
{ TPosterBox                                                }
{ --------------------------------------------------------- }

type
  PPosterBox = ^TPosterBox;
  TPosterBox = object (TMyListBox)
    function GetText( Item, MaxLen: Integer ) : String; virtual;
  end; { TPosterBox }

{ GetText ------------------------------------------------- }

function TPosterBox.GetText( Item, MaxLen: Integer ) : String;
begin
  Result := PPoster( List^.At(Item) )^.Area;
end; { GetText }


{ --------------------------------------------------------- }
{ TPosterEditor                                             }
{ --------------------------------------------------------- }

type
  PPosterEditor = ^TPosterEditor;
  TPosterEditor = object (TDialog)
    ListBox: PPosterBox;
    procedure SetupDialog( PostList: PCollection );
    procedure HandleEvent( var Event: TEvent ); virtual;
  end; { TPosterEditor }

{ SetupDialog --------------------------------------------- }

procedure TPosterEditor.SetupDialog( PostList: PCollection );
var
  R: TRect;
begin
  R.Assign( 0, 0, 0, 0 );
  ListBox := PPosterBox( ShoeHorn( @Self, New( PPosterBox, Init(R, 1, nil) )));
  ListBox^.NewList( PostList );
end; { SetupDialog }

{ HandleEvent --------------------------------------------- }

procedure TPosterEditor.HandleEvent( var Event: TEvent );
const
  cmRobots = 200;
type
  TEditData = record
    Area   : LongStr;
    Script : LongStr;
    _From  : LongStr;
    Orig   : ShortStr;
    _To    : LongStr;
    Dest   : ShortStr;
    Subj   : LongStr;
  end; { TEditData }

procedure UpdatePoster( P: PPoster );
var
  D: TEditData;
begin
  GetData( D );
  try
    P^.Area   := Trim(D.Area);
    P^._From  := D._From;
    P^.Orig   := StrToAddr( D.Orig );
    P^.Script := D.Script;
    if ListBox^.List = CFG^.Posters then
    begin
      P^._To := D._To;
      if JustSameText( P^.Area, NETMAIL_AREA ) or (D.Dest <> '') then
        P^.Dest := StrToAddr( D.Dest )
      else
        P^.Dest := ZERO_ADDR;
      P^.Subj := D.Subj;
    end;
  except
    on E: Exception do
      ShowError( E.Message );
  end;
end; { UpdatePoster }

procedure RefreshData( P: PPoster );
var
  D: TEditData;
begin
  FillChar( D, SizeOf(D), 0 );
  if P <> nil then
  begin
    D.Area   := P^.Area;
    D._From  := P^._From;
    D.Orig   := AddrToStr( P^.Orig );
    D.Script := P^.Script;
    if ListBox^.List = CFG^.Posters then
    begin
      D._To   := P^._To;
      D.Subj  := P^.Subj;
      if JustSameText( P^.Area, NETMAIL_AREA ) or (CompAddr(P^.Dest, ZERO_ADDR) <> 0) then
        D.Dest := AddrToStr( P^.Dest )
      else
        D.Dest := '';
    end;
  end;
  SetData( D );
end; { RefreshData }

procedure AppendItem;
var
  p: PPoster;
begin
  with ListBox^ do
  begin
    New( p, Init );
    List^.Insert( p );
    UpdatePoster( p );
    SetRange( Succ(Range) );
    FocusItem( Pred(Range) );
  end;
end; { AppendItem }

procedure ChangeItem;
begin
  with ListBox^ do
  begin
    if Range > 0 then
    begin
      UpdatePoster( List^.At(Focused) );
      FocusItem( Focused );
    end
    else
      AppendItem;
  end;
end; { ChangeItem }

procedure DeleteItem;
begin
  with ListBox^ do
  begin
    if Range = 0 then Exit;
    List^.AtFree( Focused );
    SetRange( Pred(Range) );
    FocusItem( Focused );
  end;
end; { DeleteItem }

procedure FocusMoved;
begin
  RefreshData( ListBox^.SelectedItem );
end; { FocusMoved }

begin
  inherited HandleEvent( Event );
  case Event.What of
    evCommand:
      begin
        case Event.Command of
          cmChgItem: ChangeItem;
          cmDelItem: DeleteItem;
          cmAppItem: AppendItem;
          cmRobots : SetupFinderRobots;
        else
          Exit;
        end;
        ClearEvent( Event );
      end;
    evBroadcast:
      case Event.Command of
        cmFocusMoved: FocusMoved;
      end;
  end;
end; { HandleEvent }


{ --------------------------------------------------------- }
{ SetupPoster                                               }
{ --------------------------------------------------------- }

procedure SetupPoster;
var
  R: TRect;
  E: PPosterEditor;
  D: PDialog;
begin
  R.Assign( 0, 0, 0, 0 );
  D := PDialog( Res^.Get('SETUP_POSTER') );
  D^.HelpCtx := hcSetupPoster;
  E := New( PPosterEditor, Init(R, '') );
  SwapDlg( D, E );
  E^.SetupDialog( CFG^.Posters );
  Application^.ExecuteDialog(E, nil);
  CFG^.Modified := True;
end; { SetupPoster }


{ --------------------------------------------------------- }
{ SetupFinderAreas                                          }
{ --------------------------------------------------------- }

procedure SetupFinderAreas;
var
  R: TRect;
  E: PPosterEditor;
  D: PDialog;
begin
  R.Assign( 0, 0, 0, 0 );
  D := PDialog( Res^.Get('SETUP_FINDER') );
  D^.HelpCtx := hcSetupFinder;
  E := New( PPosterEditor, Init(R, '') );
  SwapDlg( D, E );
  E^.SetupDialog( CFG^.FinderAreas );
  Application^.ExecuteDialog(E, nil);
  CFG^.Modified := True;
end; { SetupFinderAreas }

{ --------------------------------------------------------- }
{ SetupFinderOpt                                            }
{ --------------------------------------------------------- }

procedure SetupFinderOpt;
const
  bReplyAlways = $0001;
var
  R: TRect;
  D: PDialog;
  Data: Longint;
begin
  R.Assign( 0, 0, 0, 0 );
  D := PDialog( Res^.Get('SETUP_FDROPT') );
  D^.HelpCtx := hcSetupFinderOpt;
  Data := 0;
  SetBit( Data, bReplyAlways, CFG^.FinderRepAlways );
  if Application^.ExecuteDialog(D, @Data) = cmOk then
  begin
    CFG^.FinderRepAlways := TestBit( Data, bReplyAlways );
    CFG^.Modified := True;
  end;
end; { SetupFinderOpt }

{ --------------------------------------------------------- }
{ SetupForget                                               }
{ --------------------------------------------------------- }

procedure SetupForget;
begin
  EditStrList( LoadString(_SForgetCaption), CFG^.Forget, hcSetupForget );
  CFG^.Modified := True;
end; { SetupForget }

{ --------------------------------------------------------- }
{ EditStrList                                               }
{ --------------------------------------------------------- }

procedure EditStrList( const Title: String; List: PCollection; HelpCtx: Word );
var
  R: TRect;
  D: PDialog;
  E: PStrListEditor;
begin
  R.Assign( 0, 0, 0, 0 );
  D := PDialog( Res^.Get('SETUP_DIZ') );
  D^.HelpCtx := HelpCtx;
  E := New( PStrListEditor, Init(R, '') );
  SwapDlg( D, E );
  E^.SetupDialog( Title, List );
  Application^.ExecuteDialog( E, nil );
end; { EditStrList }

{ --------------------------------------------------------- }
{ TAddrListBox                                              }
{ --------------------------------------------------------- }

type
  PAddrListBox = ^TAddrListBox;
  TAddrListBox = object (TMyListBox)
    function GetText( Item, MaxLen: Integer ) : String; virtual;
  end; { TAddrListBox }

{ GetText ------------------------------------------------- }

function TAddrListBox.GetText( Item, MaxLen: Integer ) : String;
var
  p: PAddress;
begin
  p := List^.At(Item);
  Result := AddrToStr( p^ );
end; { GetText }


{ --------------------------------------------------------- }
{ TAddrListEditor                                           }
{ --------------------------------------------------------- }

type
  PAddrListEditor = ^TAddrListEditor;
  TAddrListEditor = object (TDialog)
    InputLine: PInputLine;
    ListBox  : PAddrListBox;
    procedure SetupDialog( const Caption: String; List: PCollection );
    procedure HandleEvent( var Event: TEvent ); virtual;
  end; { TAddrListEditor }

{ SetupDialog --------------------------------------------- }

procedure TAddrListEditor.SetupDialog( const Caption: String; List: PCollection );
var
  R: TRect;
begin
  R.Assign( 0, 0, 0, 0 );
  ListBox   := PAddrListBox( ShoeHorn( @Self, New( PAddrListBox, Init(R, 1, nil))));
  InputLine := PInputLine( ShoeHorn( @Self, New( PInputLine, Init(R, Pred(SizeOf(LongStr))))));
  ListBox^.NewList( List );
  ReplaceStr( Title, Caption );
end; { SetupDialog }

{ HandleEvent --------------------------------------------- }

procedure TAddrListEditor.HandleEvent( var Event: TEvent );
var
  S: LongStr;
  A: TAddress;
  j: Integer;

function UniqueAddr: Boolean;
begin
  Result := not PSortedCollection(ListBox^.List)^.Search( @A, j );
  if not Result  then
    MessageBox( Format(LoadString(_SAddrExists), [AddrToStr(A)]), nil, mfWarning + mfOkButton );
end; { UniqueAddr }

procedure AppendItem;
begin
  with ListBox^, List^ do
  begin
    if UniqueAddr then
    begin
      AtInsert( j, NewAddr(A) );
      SetRange( Succ(Range) );
      FocusItem( j );
    end;
  end;
end; { AppendItem }

procedure ChangeItem;
begin
  with ListBox^, List^ do
  begin
    if UniqueAddr then
    begin
      if Range > 0 then
      begin
        AtFree( Focused );
        Insert( NewAddr(A) );
        PSortedCollection(ListBox^.List)^.Search( @A, j );
        FocusItem( j );
      end
      else
        AppendItem;
    end;
  end;
end; { ChangeItem }

procedure DeleteItem;
begin
  with ListBox^, List^ do
  begin
    if Range = 0 then Exit;
    AtFree(Focused);
    SetRange(Pred(Range));
    FocusItem(Focused);
  end;
end; { DeleteItem }

procedure FocusMoved;
var
  p: PAddress;
begin
  p := ListBox^.SelectedItem;
  if p <> nil then
    S := AddrToStr( p^ )
  else
    S := '';
  InputLine^.SetData( S );
end; { FocusMoved }

begin
  inherited HandleEvent( Event );
  case Event.What of
    evCommand:
      begin
        InputLine^.GetData( S );
        if SafeAddr( S, A ) then
        begin
          case Event.Command of
            cmChgItem: ChangeItem;
            cmDelItem: DeleteItem;
            cmAppItem: AppendItem;
          else
            Exit;
          end;
        end
        else
          MessageBox( Format(LoadString(_SBadAddr), [S]), nil, mfError + mfOkButton );
        ClearEvent( Event );
      end;
    evBroadcast:
      case Event.Command of
        cmFocusMoved: FocusMoved;
      end;
  end;
end; { HandleEvent }


{ --------------------------------------------------------- }
{ EditAddrList                                              }
{ --------------------------------------------------------- }

procedure EditAddrList( const Title: String; List: PCollection; HelpCtx: Word );
var
  R: TRect;
  D: PDialog;
  E: PAddrListEditor;
begin
  R.Assign( 0, 0, 0, 0 );
  D := PDialog( Res^.Get('EDIT_ADRLST') );
  D^.HelpCtx := HelpCtx;
  E := New( PAddrListEditor, Init(R, '') );
  SwapDlg( D, E );
  E^.SetupDialog( Title, List );
  Application^.ExecuteDialog( E, nil );
end; { EditStrList }


{ --------------------------------------------------------- }
{ SetupFileApi                                              }
{ --------------------------------------------------------- }

procedure SetupFileApi;
{$IFDEF Win32}
var
  D: PDialog;
  Q: Longint;
begin
  D := PDialog( Res^.Get('SETUP_FAPI') );
  D^.HelpCtx := hcSetupFileApi;
  Q := Ord( CFG^.FileApi );
  if Application^.ExecuteDialog( D, @Q ) = cmOk then
  begin
    if (Q = Ord( CFG^.FileApi )) or
       (MessageBox( LoadString(_SCfmFileApi), nil, mfConfirmation + mfYesNoCancel) <> cmYes)
    then
      Exit;
    LoadFileBase;
    CFG.FileApi := TFileApiMode( Q );
    if (CFG.FileApi = fapi_primary_long) or (CFG.FileApi = fapi_native) then
      CFG.Formatting := fmt_lfn;
    FileBase^.WriteFilesBbs;
    FileBase^.WriteFileAreaCtl;
    CFG.Modified := True;
  end;
{$ELSE}
begin
  MessageBox( LoadString(_SFapiNotAvail), nil, mfWarning + mfOkButton );
{$ENDIF}
end; { SetupFileApi }

end.
