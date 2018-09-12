unit SetEcho;

/////////////////////////////////////////////////////////////////////
//
// Hi-Files Version 2
// Copyright (c) 1997-2004 Dmitry Liman [2:461/79]
//
// http://hi-files.narod.ru
//
/////////////////////////////////////////////////////////////////////

interface

procedure SetupFileEchoProcessor;
procedure SetupFileEchoLinks;
procedure SetupForwardReq;

{ =================================================================== }

implementation

uses
  Objects, MyLib, SysUtils, Views, Dialogs, Drivers, App, _CFG, _RES, _LOG,
  MsgBox, MyViews, MsgAPI, _FAreas, Setup, HifiHelp, Import, _fopen;

{ --------------------------------------------------------- }
{ TOptionsDialog                                            }
{ --------------------------------------------------------- }

type
  POptionsDialog = ^TOptionsDialog;
  TOptionsDialog = object (TDialog)
    procedure HandleEvent( var Event: TEvent ); virtual;
  private
    procedure SetupAreafixRobots;
  end; { TOptionsDialog }

{ HandleEvent --------------------------------------------- }

procedure TOptionsDialog.HandleEvent( var Event: TEvent );
const
  cmSetupRobots = 200;
begin
  inherited HandleEvent( Event );
  case Event.What of
    evCommand:
      begin
        case Event.Command of
          cmSetupRobots: SetupAreafixRobots;
        else
          Exit;
        end;
        ClearEvent( Event );
      end;
  end;
end; { HandleEvent }

{ SetupAreaFixRobots -------------------------------------- }

procedure TOptionsDialog.SetupAreaFixRobots;
begin
  EditStrList( LoadString(_SAfixRobots), CFG^.AfixRobots, hcSetupAfixRobots );
  CFG^.Modified := True;
end; { SetupFinderRobots }

{ --------------------------------------------------------- }
{ SetupFileEchoProcessor                                    }
{ --------------------------------------------------------- }

procedure SetupFileEchoProcessor;
var
  R: TRect;
  D: PDialog;
  E: POptionsDialog;
  Q: record
       OutTicPath : LongStr;
       BadTicPath : LongStr;
       Autocreate : LongStr;
       Passthrough: LongStr;
       FileBoxes  : LongStr;
       HatchPw    : LongStr;
       AfixHelp   : LongStr;
       KillAfixReq: Longint;
     end;
begin
  FillChar( Q, SizeOf(Q), 0 );
  with CFG^ do
  begin
    Q.OutTicPath  := OutTicPath;
    Q.BadTicPath  := BadTicPath;
    Q.Autocreate  := Autocreate;
    Q.Passthrough := Passthrough;
    Q.FileBoxes   := FileBoxes;
    Q.HatchPw     := HatchPw;
    Q.AfixHelp    := AllFixHelp;
    SetBit( Q.KillAfixReq, $0001, KillAfixReq );
  end;
  D := PDialog( Res^.Get( 'SETUP_EPROC' ) );
  D^.HelpCtx := hcSetupEchoProc;
  R.Assign( 0, 0, 0, 0 );
  E := New( POptionsDialog, Init(R, '') );
  SwapDlg( D, E );
  if Application^.ExecuteDialog( E, @Q ) = cmOk then
  begin
    with CFG^ do
    try
      OutTicPath  := ExistingDir( Q.OutTicPath, True );
      BadTicPath  := ExistingDir( Q.BadTicPath, True );
      Autocreate  := ExistingDir( Q.Autocreate, True );
      Passthrough := ExistingDir( Q.Passthrough, True );
      FileBoxes   := ExistingDir( Q.FileBoxes, True );
      HatchPw     := Q.HatchPw;
      AllfixHelp  := ExistingFile( Q.AfixHelp );
      KillAfixReq := TestBit( Q.KillAfixReq, $0001 );
    except
      on E: Exception do
        ShowError( E.Message );
    end;
    CFG^.Modified := True;
  end;
end; { SetupFileEchoProcessor }

{ --------------------------------------------------------- }
{ TAccessBox                                                }
{ --------------------------------------------------------- }

type
  PAccessBox = ^TAccessBox;
  TAccessBox = object (TMyListBox)
    LinkAddr: PAddress;
    destructor Done; virtual;
    function GetText( Item, MaxLen: Integer ) : String; virtual;
  end; { TAccessBox }

{ Done ---------------------------------------------------- }

destructor TAccessBox.Done;
begin
  List^.DeleteAll; // Sic! Dont use FreeAll.
  Destroy( List );
  inherited Done;
end; { Done }

{ GetText ------------------------------------------------- }

function TAccessBox.GetText( Item, MaxLen: Integer ) : String;
var
  E: PFileEcho;
  S: String[2];
  j: Integer;
begin
  E := List^.At(Item);

  S := '--';

  if E^.Downlinks^.Search( LinkAddr, j ) then
    S[1] := 'R';
  if E^.Uplinks^.Search( LinkAddr, j ) then
    S[2] := 'W';

  Result := S + ' │ ' + E^.Name^;

end; { GetText }


{ --------------------------------------------------------- }
{ LinkedEchosEditor                                         }
{ --------------------------------------------------------- }

type
  PLinkedEchosEditor = ^TLinkedEchosEditor;
  TLinkedEchosEditor = object (TDialog)
    ListBox: PAccessBox;
    Access : PCheckBoxes;

    procedure SetupDialog( Link: PEchoLink );
    procedure HandleEvent( var Event: TEvent ); virtual;
  end; { TLinkedEchosEditor }

{ SetupDialog ---------------------------------------------- }

procedure TLinkedEchosEditor.SetupDialog( Link: PEchoLink );
var
  R: TRect;
  S: String;
  List: PEchoList;

  procedure CopyAllowedEcho( Echo: PFileEcho ); far;
  begin
    if not Link^.Deny^.Match(Echo^.Name^) then
      List^.Insert( Echo );
  end; { CopyAllowedEcho }

begin
  R.Assign( 0, 0, 0, 0 );
  Access  := PCheckBoxes( ShoeHorn(@Self, New(PCheckBoxes, Init(R, nil) )));
  ListBox := PAccessBox ( ShoeHorn(@Self, New(PAccessBox,  Init(R, 1, nil) )));

  OpenFileBase;

  // This list MUST be destroyed but it's items MUST NOT be freed!

  List := New( PEchoList, Init(50, 10) );

  FileBase^.EchoList^.ForEach( @CopyAllowedEcho );

  ListBox^.SetMode( [] );
  ListBox^.LinkAddr := @Link^.Addr;
  ListBox^.NewList( List );

  S := '';
  if elo_pause in Link^.Opt then
    S := ' (passive)';

  // MyLib.ReplaceStr вызывать нельзя:
  // TDialog.Done вызывает DisposeStr, а не FreeStr :(

  FreeStr( Title ); Title := Objects.NewStr(AddrToStr(Link^.Addr) + S);

end; { SetupDialog }

{ --------------------------------------------------------- }
{ HandleEvent                                               }
{ --------------------------------------------------------- }

procedure TLinkedEchosEditor.HandleEvent( var Event: TEvent );
const
  cmSet      = 300;
  cmClearAll = 301;
  cmClearWA  = 302;

  bDL = $0001;
  bUL = $0002;

  procedure UpdateCheckBoxes;
  var
    E: PFileEcho;
    j: Integer;
    Q: Longint;
  begin
    E := ListBox^.SelectedItem;
    if E = nil then
    begin
      if not Access^.GetState( sfDisabled ) then
        Access^.SetState( sfDisabled, True );
    end
    else
    begin
      if Access^.GetState( sfDisabled ) then
        Access^.SetState( sfDisabled, False);
      Q := 0;
      SetBit(Q, bDL, E^.Downlinks^.Search(ListBox^.LinkAddr, j ));
      SetBit(Q, bUL, E^.Uplinks^.Search(ListBox^.LinkAddr, j));
      Access^.SetData( Q );
    end;
  end; { UpdateCheckBoxes }

  procedure SetRights;
  var
    E: PFileEcho;
    j: Integer;
    Q: Longint;
  begin
    E := ListBox^.SelectedItem;
    if E = nil then Exit;

    Access^.GetData( Q );
    if TestBit( Q, bDL ) <> E^.Downlinks^.Search( ListBox^.LinkAddr, j ) then
    begin
      if TestBit( Q, bDL ) then
        E^.Downlinks^.Insert( NewAddr(ListBox^.LinkAddr^) )
      else
        E^.Downlinks^.AtFree(j);
      FileBase^.Modified := True;
    end;
    if TestBit( Q, bUL ) <> E^.Uplinks^.Search( ListBox^.LinkAddr, j ) then
    begin
      if TestBit( Q, bUL ) then
        E^.Uplinks^.Insert( NewAddr(ListBox^.LinkAddr^) )
      else
        E^.Uplinks^.AtFree(j);
      FileBase^.Modified := True;
    end;

    ListBox^.DrawView;

  end; { SetRights }

  procedure DoClearUL( E: PFileEcho ); far;
  var
    j: Integer;
  begin
    if E^.Uplinks^.Search(ListBox^.LinkAddr, j) then
    begin
      E^.Uplinks^.AtFree(j);
      FileBase^.Modified := True;
    end;
  end; { DoCleaUL }

  procedure DoClearDL( E: PFileEcho ); far;
  var
    j: Integer;
  begin
    if E^.Downlinks^.Search(ListBox^.LinkAddr, j) then
    begin
      E^.Downlinks^.AtFree(j);
      FileBase^.Modified := True;
    end;
  end; { DoClearDL }

  procedure ClearAllRights;
  begin
    if (ListBox^.Range > 0) and
       (MessageBox(LoadString(_SCfmClrAllRights), nil, mfConfirmation + mfYesNoCancel) = cmYes)
    then
    begin
      ListBox^.List^.ForEach( @DoClearUL );
      ListBox^.List^.ForEach( @DoClearDL );
      ListBox^.DrawView;
    end;
  end; { ClearAllRights }

  procedure ClearWriteAccess;
  begin
    if (ListBox^.Range > 0) and
       (MessageBox(LoadString(_SCfmClrWriteRights), nil, mfConfirmation + mfYesNoCancel) = cmYes)
    then
    begin
      ListBox^.List^.ForEach( @DoClearUL );
      ListBox^.DrawView;
    end;
  end; { ClearWriteAccess }

begin
  inherited HandleEvent( Event );
  case Event.What of
    evCommand:
      begin
        case Event.Command of
          cmSet     : SetRights;
          cmClearAll: ClearAllRights;
          cmClearWA : ClearWriteAccess;
        else
          Exit;
        end;
        ClearEvent( Event );
      end;

    evBroadcast:
      case Event.Command of
        cmFocusMoved: UpdateCheckBoxes;
      end;
  end;
end; { HandleEvent }


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
begin
  Result := AddrToStr( PEchoLink(List^.At(Item))^.Addr );
end; { GetText }

{ --------------------------------------------------------- }
{ TLinkEditor                                               }
{ --------------------------------------------------------- }

type
  PLinkEditor = ^TLinkEditor;
  TLinkEditor = object (TDialog)
    ListBox: PAddrListBox;
    procedure SetupDialog;
    procedure HandleEvent( var Event: TEvent ); virtual;
  private
    procedure Refresh;
    procedure EditLinkedAreas( Link: PEchoLink );
  end; { TLinkEditor }

{ SetupDialog --------------------------------------------- }

procedure TLinkEditor.SetupDialog;
var
  R: TRect;
begin
  R.Assign( 0, 0, 0, 0 );
  ListBox := PAddrListBox( ShoeHorn( @Self, New( PAddrListBox, Init(R, 1, nil))));
  ListBox^.NewList( CFG^.Links );
end; { SetupDialog }

{ HandleEvent --------------------------------------------- }

procedure TLinkEditor.HandleEvent( var Event: TEvent );
const
  cmImport = 200;
  cmDeny   = 201;
  cmAreas  = 202;
const
  bAutoCreate = $0001;
  bAutoLink   = $0002;
  bNotify     = $0004;
  bPause      = $0008;
  bFileBox    = $0010;
var
  Link: PEchoLink;
  Q: record
       Addr: LongStr;
       Pass: LongStr;
       Aka : LongStr;
       Opt : Longint;
       Fla : Longint;
     end; { TLinkEditorData }

procedure RefreshData( Link: PEchoLink );
begin
  FillChar( Q, SizeOf(Q), 0 );
  if Link <> nil then
  begin
    with Link^ do
    begin
      Q.Addr := AddrToStr(Addr);
      Q.Pass := Password^;
      Q.Aka  := AddrToStr(OurAka);
      SetBit( Q.Opt, bAutoCreate, elo_AutoCreate in Opt );
      SetBit( Q.Opt, bAutoLink,   elo_AutoLink in Opt );
      SetBit( Q.Opt, bNotify,     elo_Notify in Opt );
      SetBit( Q.Opt, bPause,      elo_Pause in Opt );
      SetBit( Q.Opt, bFileBox,    elo_FileBox in Opt );
      Q.Fla := Ord( Flavor );
    end;
  end;
  SetData( Q );
end; { RefreshData }

procedure UpdateLink;
begin
  ReplaceStr( Link^.Password, Q.Pass );
  Link^.Opt := [];
  if TestBit( Q.Opt, bAutoCreate ) then
    Include( Link^.Opt, elo_AutoCreate );
  if TestBit( Q.Opt, bAutoLink ) then
    Include( Link^.Opt, elo_AutoLink );
  if TestBit( Q.Opt, bNotify ) then
    Include( Link^.Opt, elo_Notify );
  if TestBit( Q.Opt, bPause ) then
    Include( Link^.Opt, elo_Pause );
  if TestBit( Q.Opt, bFileBox ) then
    Include( Link^.Opt, elo_FileBox );
  Link^.Flavor := TFlavor( Q.Fla );
  if not SafeAddr( Q.Aka, Link^.OurAka ) then
    MessageBox( Format(LoadString(_SBadAddr), [Q.Aka]), nil, mfError + mfOkButton );
end; { UpdateLink }

procedure ChangeItem;
var
  A: TAddress;
  j: Integer;
begin
  with ListBox^ do
  begin
    if Focused < Range then
    begin
      Self.GetData( Q );
      Q.Pass := Trim( Q.Pass );
      if SafeAddr( Q.Addr, A ) then
      begin
        if CFG^.Links^.Search( @A, j ) and (j <> Focused) then
        begin
          MessageBox( LoadString(_SCantChgAddrDupe), nil, mfWarning + mfOkButton );
          Exit;
        end;
      end
      else
      begin
        MessageBox( Format(LoadString(_SBadAddr), [Q.Addr]), nil, mfError + mfOkButton );
        Exit;
      end;
      if Q.Pass = '' then
      begin
        MessageBox( LoadString(_SEmptyPwd), nil, mfWarning + mfOkButton );
        Exit;
      end;
      Link := CFG^.Links^.At( Focused );
      if CompAddr( Link^.Addr, A ) <> 0 then
        with CFG^.Links^ do
        begin
          AtDelete( Focused );
          if j >= Focused then Dec(j);
          Link^.Addr := A;
          AtInsert( j, Link );
        end;
      UpdateLink;
      FocusItem( j );
      CFG^.Modified := True;
    end;
  end;
end; { ChangeItem }

procedure AppendItem;
var
  A: TAddress;
  j: Integer;
begin
  GetData( Q );
  Q.Pass := Trim( Q.Pass );
  if SafeAddr( Q.Addr, A ) then
  begin
    if CFG^.Links^.Search( @A, j ) then
    begin
      MessageBox( LoadString(_SCantAddLinkDupe), nil, mfWarning + mfOkButton );
      Exit;
    end;
    if Q.Pass = '' then
    begin
      MessageBox( LoadString(_SCantAddLinkEmptyPwd), nil, mfWarning + mfOkButton );
      Exit;
    end;
    New( Link, Init(A) );
    CFG^.Links^.AtInsert( j, Link );
    UpdateLink;
    with ListBox^ do
    begin
      SetRange( Succ(Range) );
      FocusItem( j );
    end;
    CFG^.Modified := True;
  end
  else
    MessageBox( Format(LoadString(_SBadAddr), [Q.Addr]), nil, mfError + mfOkButton );
end; { AppendItem }

procedure DeleteItem;
var
  Link: PEchoLink;
begin
  with ListBox^ do
  begin
    if Focused < Range then
    begin
      Link := CFG^.Links^.At( Focused );
      if MessageBox( Format(LoadString(_SAskKillLink), [AddrToStr(Link^.Addr)]), nil, mfConfirmation + mfYesNoCancel ) <> cmYes then Exit;
      CFG^.Links^.AtFree( Focused );
      SetRange( Pred(Range) );
      FocusItem( Focused );
      OpenFileBase;
      FileBase^.EchoList^.RefineLinks;
      CFG^.Modified := True;
    end;
  end;
end; { DeleteItem }

procedure FocusMoved;
begin
  RefreshData( ListBox^.SelectedItem );
end; { FocusMoved }

procedure EditDenyList;
var
  Link: PEchoLink;
begin
  Link := ListBox^.SelectedItem;
  if Link <> nil then
  begin
    EditStrList( LoadString(_SEditDenyCaption), Link^.Deny, hcEditDenyList );
    CFG^.Modified := True;
  end;
end; { EditDenyList }

begin
  inherited HandleEvent( Event );
  case Event.What of
    evCommand:
      begin
        case Event.Command of
          cmChgItem: ChangeItem;
          cmAppItem: AppendItem;
          cmDelItem: DeleteItem;
          cmDeny   : EditDenyList;
          cmAreas  : EditLinkedAreas( ListBox^.SelectedItem );
          cmImport : if ImportLinks then Refresh;
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

{ Refresh ------------------------------------------------- }

procedure TLinkEditor.Refresh;
begin
  with ListBox^ do
  begin
    List := nil;
    NewList( CFG^.Links );
  end;
end; { Refresh }

{ EditLinkedAreas ----------------------------------------- }

procedure TLinkEditor.EditLinkedAreas( Link: PEchoLink );
var
  R: TRect;
  D: PDialog;
  E: PLinkedEchosEditor;
begin
  if Link = nil then Exit;
  R.Assign( 0, 0, 0, 0 );
  D := PDialog( Res^.Get('LINKED_ECHOS') );
  D^.HelpCtx := hcEditLinkedAreas;
  E := New( PLinkedEchosEditor, Init(R, '') );
  SwapDlg( D, E );
  E^.SetupDialog( Link );
  Application^.ExecuteDialog( E, nil );
end; { EditLinkedAreas }


{ --------------------------------------------------------- }
{ SetupFileEchoLinks                                        }
{ --------------------------------------------------------- }

procedure SetupFileEchoLinks;
var
  R: TRect;
  D: PDialog;
  E: PLinkEditor;
begin
  R.Assign( 0, 0, 0, 0 );
  D := PDialog( Res^.Get('SETUP_LINK') );
  D^.HelpCtx := hcSetupLink;
  E := New( PLinkEditor, Init(R, '') );
  SwapDlg( D, E );
  E^.SetupDialog;
  Application^.ExecuteDialog( E, nil );
end; { SetupFileEchoLinks }

{ --------------------------------------------------------- }
{ PAvailListBox                                             }
{ --------------------------------------------------------- }

type
  PAvailListBox = ^TAvailListBox;
  TAvailListBox = object (TMyListBox)
    function GetText( Item, MaxLen: Integer ) : String; virtual;
  end; { TAvailListBox }

{ GetText ------------------------------------------------- }

function TAvailListBox.GetText( Item, MaxLen: Integer ) : String;
begin
  Result := AddrToStr( PAvailRec(List^.At(Item))^.Addr );
end; { TAvailListBox }


{ --------------------------------------------------------- }
{ TReqEditor                                                }
{ --------------------------------------------------------- }

type
  PReqEditor = ^TReqEditor;
  TReqEditor = object (TDialog)
    ListBox: PAvailListBox;
    Avail  : PInputLine;
    procedure SetupDialog;
    procedure HandleEvent( var Event: TEvent ); virtual;
  end; { TReqEditor }

{ SetupDialog --------------------------------------------- }

procedure TReqEditor.SetupDialog;
var
  R: TRect;
begin
  R.Assign( 0, 0, 0, 0 );
  Avail := PInputLine( ShoeHorn( @Self, New( PInputLine, Init(R, Pred(SizeOf(LongStr))))));
  ListBox := PAvailListBox( ShoeHorn( @Self, New( PAvailListBox, Init(R, 1, nil))));
  ListBox^.SetMode([lb_speedsearch, lb_reorder]);
  ListBox^.NewList( CFG^.Avail );
end; { SetupDialog }

{ HandleEvent --------------------------------------------- }

procedure TReqEditor.HandleEvent( var Event: TEvent );
const
  cmBrowse  = 200;
  bInactive = $0001;
var
  Q: record
       Name: LongStr;
       Addr: LongStr;
       Opt : Longint;
     end;

  procedure InsertItem;
  var
    AR: PAvailRec;
  begin
    if CFG^.Avail^.Find( ZERO_ADDR ) <> nil then Exit;
    New( AR );
    FillChar( AR^, SizeOf(TAvailRec), 0 );
    with ListBox^ do
    begin
      List^.AtInsert( Focused, AR );
      SetRange( Succ(Range) );
      FocusItem( Focused );
      CFG^.Modified := True;
    end;
  end; { InsertItem }

  procedure DeleteItem;
  begin
    with ListBox^ do
    begin
      if Focused >= Range then Exit;
      if MessageBox( Format(LoadString(_SCfmDelAvailRec),
          [AddrToStr(PAvailRec(List^.At(Focused))^.Addr)]), nil,
          mfConfirmation + mfYesNoCancel ) = cmYes then
      begin
        List^.AtFree( Focused );
        SetRange( Pred(Range) );
        FocusItem( Focused );
        CFG^.Modified := True;
      end;
    end;
  end; { DeleteItem }

  procedure ReplaceItem;
  var
    A : TAddress;
    AR: PAvailRec;
  begin
    with ListBox^ do
    begin
      if Focused >= Range then Exit;
      Self.GetData( Q );
      if not SafeAddr( Q.Addr, A ) then
      begin
        ShowError( Format(LoadString(_SBadAddr), [Q.Addr]) );
        Exit;
      end;
      if CFG^.Links^.Find( A ) = nil then
        ShowError( Format(LoadString(_SUnknownAvailLink), [AddrToStr(A)] ) );
      if not FileExists( Q.Name ) then
      begin
        ShowError( Format(LoadString(_SFileNotFound), [Q.Name]) );
        Exit;
      end;
      AR := List^.At( Focused );
      if (CompAddr(AR^.Addr, A) <> 0) and (CFG^.Avail^.Find(A) <> nil) then
      begin
        ShowError( Format(LoadString(_SAvailAddrDupe), [Q.Addr]) );
        Exit;
      end;
      AR^.Addr := A;
      AR^.Name := Q.Name;
      AR^.Opt  := [];
      if TestBit( Q.Opt, bInactive ) then
        Include( AR^.Opt, ao_Inactive );
      FocusItem( Focused );
      CFG^.Modified := True;
    end;
  end; { ReplaceItem }

  procedure Refresh( AR: PAvailRec );
  begin
    FillChar( Q, SizeOf(Q), 0 );
    if AR <> nil then
    begin
      Q.Addr := AddrToStr( AR^.Addr );
      Q.Name := AR^.Name;
      SetBit( Q.Opt, bInactive, ao_Inactive in AR^.Opt );
    end;
    SetData( Q );
  end; { Refresh }

  procedure Browse;
  begin
    Avail^.GetData( Q.Name );
    Q.Name := '*.*';
    if ExecFileOpenDlg(LoadString(_SBrowseAvailCaption), Q.Name, Q.Name) then
        Avail^.SetData( Q.Name );
  end; { Browse }

begin
  inherited HandleEvent( Event );
  case Event.What of
    evCommand:
      begin
        case Event.Command of
          cmInsItem: InsertItem;
          cmDelItem: DeleteItem;
          cmChgItem: ReplaceItem;
          cmBrowse : Browse;
        else
          Exit;
        end;
        ClearEvent( Event );
      end;
    evBroadcast:
      case Event.Command of
        cmFocusMoved: Refresh( ListBox^.SelectedItem );
      end;
  end;
end; { HandleEvent }

{ --------------------------------------------------------- }
{ SetupForwardReq                                           }
{ --------------------------------------------------------- }

procedure SetupForwardReq;
var
  R: TRect;
  D: PDialog;
  E: PReqEditor;
begin
  R.Assign( 0, 0, 0, 0 );
  D := PDialog( Res^.Get( 'SETUP_AVAIL' ) );
  D^.HelpCtx := hcSetupForwardReq;
  E := New( PReqEditor, Init(R, '') );
  SwapDlg( D, E );
  E^.SetupDialog;
  Application^.ExecuteDialog( E, nil );
end; { SetupForwardReq }


end.

