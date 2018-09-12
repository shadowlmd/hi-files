unit EchoPane;

/////////////////////////////////////////////////////////////////////
//
// Hi-Files Version 2
// Copyright (c) 1997-2004 Dmitry Liman [2:461/79]
//
// http://hi-files.narod.ru
//
/////////////////////////////////////////////////////////////////////

interface

procedure OpenFileEchoes;

procedure CloseFileEchoBrowser;

{ =================================================================== }

implementation

uses
  Objects, MyLib, MyViews, SysUtils, Views, Dialogs, Drivers, App, MsgBox,
  _CFG, _RES, _LOG, _FAreas, AreaPane, Setup, MsgAPI, Import, HiFiHelp;

var
  NO_HOST_AREA: String;

{ --------------------------------------------------------- }
{ TTagBox                                                   }
{ --------------------------------------------------------- }

type
  PTagBox = ^TTagBox;
  TTagBox = object (TMyListBox)
    Echo: PFileEcho;
    function GetText( Item, MaxLen: Integer ) : String; virtual;
  end; { TTagBox }

{ GetText ------------------------------------------------- }

function TTagBox.GetText( Item, MaxLen: Integer ) : String;
var
  j: Integer;
  S: String[2];
  Link: PEchoLink;
begin
  S := '--';
  Link := List^.At(Item);

  if Echo^.Downlinks^.Search( @Link^.Addr, j ) then
    S[1] := 'R';
  if Echo^.Uplinks^.Search( @Link^.Addr, j ) then
    S[2] := 'W';

  Result := Format( '%2s ³ %-25s', [S, AddrToStr(Link^.Addr)] );

end; { GetText }


{ --------------------------------------------------------- }
{ TLinkSelector                                             }
{ --------------------------------------------------------- }

type
  PLinkSelector = ^TLinkSelector;
  TLinkSelector = object (TDialog)
    ListBox: PTagBox;
    Rights : PCheckBoxes;
    procedure SetupDialog( Echo: PFileEcho );
    procedure HandleEvent( var Event: TEvent ); virtual;
  end; { TLinkSelector }

{ SetupDialog --------------------------------------------- }

procedure TLinkSelector.SetupDialog( Echo: PFileEcho );
var
  R: TRect;
begin
  R.Assign( 0, 0, 0, 0 );
  Rights  := PCheckBoxes( ShoeHorn( @Self, New( PCheckBoxes, Init(R, nil) )));
  ListBox := PTagBox( ShoeHorn( @Self, New( PTagBox, Init( R, 1, nil ))));
  ListBox^.SetMode( [] );
  ListBox^.Echo := Echo;
  ListBox^.NewList( CFG^.Links );
end; { SetupDialog }

{ HandleEvent --------------------------------------------- }

procedure TLinkSelector.HandleEvent( var Event: TEvent );
const
  bRead  = $0001;
  bWrite = $0002;

  cmSet = 200;

  procedure SetRights;
  var
    Q: Longint;
    j: Integer;
    Link: PEchoLink;

    procedure Add( List: PAddrList );
    begin
      if not List^.Search( @Link^.Addr, j ) then
      begin
        List^.Insert( NewAddr(Link^.Addr) );
        FileBase^.Modified := True;
      end;
    end; { Add }

    procedure Del( List: PAddrList );
    begin
      if List^.Search( @Link^.Addr, j ) then
      begin
        List^.AtFree( j );
        FileBase^.Modified := True;
      end;
    end; { Del }

  begin
    if ListBox^.Focused < ListBox^.Range then
    begin
      Rights^.GetData( Q );
      Link := CFG^.Links^.At(ListBox^.Focused);

      if TestBit( Q, bRead ) then
        Add( ListBox^.Echo^.Downlinks )
      else
        Del( ListBox^.Echo^.Downlinks );

      if TestBit( Q, bWrite ) then
        Add( ListBox^.Echo^.Uplinks )
      else
        Del( ListBox^.Echo^.Uplinks );

      ListBox^.DrawView;

    end;
  end; { SetRights }

  procedure GetRights;
  var
    Q: Longint;
    j: Integer;
    Link: PEchoLink;
  begin
    Q := 0;
    if ListBox^.Focused < ListBox^.Range then
    begin
      Link := CFG^.Links^.At(ListBox^.Focused);
      SetBit( Q, bRead,  ListBox^.Echo^.Downlinks^.Search( @Link^.Addr, j ) );
      SetBit( Q, bWrite, ListBox^.Echo^.Uplinks^.Search( @Link^.Addr, j ) );
      if Rights^.GetState( sfDisabled ) then
        Rights^.SetState( sfDisabled, False );
    end
    else
    begin
      if not Rights^.GetState( sfDisabled ) then
        Rights^.SetState( sfDisabled, True );
    end;
    Rights^.SetData( Q );
  end; { GetRights }

begin
  inherited HandleEvent( Event );
  case Event.What of
    evCommand:
      begin
        case Event.Command of
          cmSet: SetRights;
        else
          Exit;
        end;
        ClearEvent( Event );
      end;

    evBroadcast:
      case Event.Command of
        cmFocusMoved:
          GetRights;
      end;
  end;
end; { HandleEvent }

{ --------------------------------------------------------- }
{ SelectLinks                                               }
{ --------------------------------------------------------- }

function SelectLinks( Echo: PFileEcho ) : Boolean;
var
  R: TRect;
  E: PLinkSelector;
  D: PDialog;
begin
  R.Assign( 0, 0, 0, 0 );
  D := PDialog( Res^.Get('SEL_LINKS') );
  D^.HelpCtx := hcSelLinks;
  E := New( PLinkSelector, Init(R, '') );
  SwapDlg( D, E );
  E^.SetupDialog( Echo );
  Application^.ExecuteDialog( E, nil );
end; { SelectLinks }

{ --------------------------------------------------------- }
{ TAreaSelector                                             }
{ --------------------------------------------------------- }

const
  cmPassthrough = 200;

type
  PAreaSelector = ^TAreaSelector;
  TAreaSelector = object (TDialog)
    ListBox : PFileAreaBox;
    InfoPane: PInfoPane;
    procedure SetupDialog( Host: PFileArea );
    procedure HandleEvent( var Event: TEvent ); virtual;
    procedure SetData( var Data ); virtual;
    procedure GetData( var Data ); virtual;
    function  DataSize: Word; virtual;
  private
    InfoData: String;
    InfoLink: Pointer;
    procedure Refresh;
  end; { TAreaSelector }

{ SetupDialog --------------------------------------------- }

procedure TAreaSelector.SetupDialog( Host: PFileArea );
var
  R: TRect;
  H: PStaticText;
  S: String;
  j: Integer;
begin
  R.Assign( 0, 0, 0, 0 );
  InfoPane := PInfoPane( ShoeHorn( @Self, New( PInfoPane, Init( R, '', 0 ))));
  ListBox  := PFileAreaBox( ShoeHorn( @Self, New( PFileAreaBox, Init(R, 1, nil))));
  H := PStaticText( ShoeHorn( @Self, New( PStaticText, Init(R, ''))));
  H^.GetText( S );
  if Host = nil then
    ReplaceStr( H^.Text, S + NO_HOST_AREA )
  else
    ReplaceStr( H^.Text, S + Host^.Name^ );
  InfoLink := @InfoData;
  InfoPane^.SetData( InfoLink );
  ListBox^.NewList( FileBase );
  if Host <> nil then
  begin
    j := FileBase^.IndexOf(Host);
    if j >= 0 then
      ListBox^.FocusItem(j);
  end;
end; { SetupDialog }

{ HandleEvent --------------------------------------------- }

procedure TAreaSelector.HandleEvent( var Event: TEvent );
begin
  inherited HandleEvent( Event );
  case Event.What of
    evCommand:
      begin
        case Event.Command of
          cmPassthrough: EndModal( cmPassthrough );
        else
          Exit;
        end;
      end;
    evBroadcast:
      case Event.Command of
        cmFocusMoved: Refresh;
      end;
  end;
end; { HandleEvent }

{ SetData ------------------------------------------------- }

procedure TAreaSelector.SetData( var Data );
begin
  Refresh;
end; { SetData }

{ GetData ------------------------------------------------- }

procedure TAreaSelector.GetData( var Data );
begin
  Integer(Data) := ListBox^.Focused;
end; { GetData }

{ DataSize ------------------------------------------------ }

function TAreaSelector.DataSize: Word;
begin
  Result := SizeOf(Integer);
end; { DataSize }

{ Refresh ------------------------------------------------- }

procedure TAreaSelector.Refresh;
var
  Area: PFileArea;
begin
  with ListBox^ do
  begin
    if Focused < Range then
    begin
      Area := List^.At(Focused);
      if not Area^.GetPDP( InfoData ) then
        InfoData := LoadString(_SNoValidDLPath);
    end
    else
      InfoData := '';
  end;
  InfoPane^.DrawView;
end; { Refresh }

{ --------------------------------------------------------- }
{ SeletArea                                                 }
{ --------------------------------------------------------- }

function SelectArea( var Area: PFileArea; const NoNameTag: String ) : Boolean;
var
  R: TRect;
  D: PDialog;
  E: PAreaSelector;
  Q: Integer;
begin
  R.Assign( 0, 0, 0, 0 );
  D := PDialog( Res^.Get('SELECT_HOST') );
  D^.HelpCtx := hcSelectHost;
  E := New( PAreaSelector, Init(R, '') );
  SwapDlg( D, E );
  E^.SetupDialog( Area );
  Result := True;
  case Application^.ExecuteDialog( E, @Q ) of
    cmOk:
      Area := FileBase^.At( Q );
    cmPassthrough:
      Area := nil;
  else
    Result := False;
  end;
end; { SelectArea }

{ --------------------------------------------------------- }
{ TFileEchoSetupDialog                                      }
{ --------------------------------------------------------- }

type
  TFileEchoSetupData = record
    EchoTag : LongStr;
    HostArea: LongStr;
    Paranoia: Longint;
    State   : Longint;
  end; { TFileEchoSetupData }

  PFileEchoSetupDialog = ^TFileEchoSetupDialog;
  TFileEchoSetupDialog = object (TDialog)
    HostAreaInput: PInputLine;
    procedure SetupDialog( E: PFileEcho );
    procedure HandleEvent( var Event: TEvent ); virtual;
    procedure SetData( var Data ); virtual;
  private
    Echo: PFileEcho;
    procedure RefreshInput;
    procedure ChangeHost;
  end; { TFileEchoSetupDialog }

{ SetupDialog --------------------------------------------- }

procedure TFileEchoSetupDialog.SetupDialog( E: PFileEcho );
var
  R: TRect;
begin
  R.Assign( 0, 0, 0, 0 );
  HostAreaInput := PInputLine( ShoeHorn(@Self, New(PInputLine, Init(R, Pred(SizeOf(LongStr))))));
  HostAreaInput^.SetState( sfDisabled, True );
  Echo := E;
  RefreshInput;
end; { SetupDialog }

{ SetData ------------------------------------------------- }

procedure TFileEchoSetupDialog.SetData( var Data );
var
  S: LongStr;
begin
  HostAreaInput^.GetData( S );
  inherited SetData( Data );
  HostAreaInput^.SetData( S );
end; { SetData }

{ RefreshInput -------------------------------------------- }

procedure TFileEchoSetupDialog.RefreshInput;
var
  S: String;
begin
  if Echo^.Area = nil then
    S := NO_HOST_AREA
  else
    S := Echo^.Area^.Name^;
  HostAreaInput^.SetData( S );
end; { RefreshInput }

{ HandleEvent --------------------------------------------- }

procedure TFileEchoSetupDialog.HandleEvent( var Event: TEvent );
const
  cmLink = 200;
  cmHook = 202;
  cmHost = 203;
begin
  inherited HandleEvent( Event );
  case Event.What of
    evCommand:
      begin
        case Event.Command of
          cmLink: SelectLinks( Echo );
          cmHook: EditStrList( LoadString(_SHooksCaption), Echo^.Hooks, hcSetupHooks );
          cmHost: ChangeHost;
        else
          Exit;
        end;
        ClearEvent( Event );
      end;
  end;
end; { HandleEvent }

{ ChangeHost ---------------------------------------------- }

procedure TFileEchoSetupDialog.ChangeHost;
begin
  if FileBase^.EchoList^.Count > 0 then
  begin
    SelectArea( Echo^.Area, NO_HOST_AREA );
    RefreshInput;
  end;
end; { ChangeHost }

{ --------------------------------------------------------- }
{ TFileEchoBox                                              }
{ --------------------------------------------------------- }

type
  PFileEchoBox = ^TFileEchoBox;
  TFileEchoBox = object (TMyListBox)
    function GetText( Item, MaxLen: Integer ) : String; virtual;
  end; { TFileEchoBox }

{ GetText ------------------------------------------------- }

function TFileEchoBox.GetText( Item, MaxLen: Integer ) : String;
begin
  Result := PFileEcho(List^.At(Item))^.Name^;
end; { GetText }

{ --------------------------------------------------------- }
{ TFileEchoBrowser                                          }
{ --------------------------------------------------------- }

type
  PFileEchoBrowser = ^TFileEchoBrowser;
  TFileEchoBrowser = object (TDialog)
    ListBox: PFileEchoBox;
    destructor Done; virtual;
    procedure SetupDialog;
    procedure HandleEvent( var Event: TEvent ); virtual;
    function  Valid( Command: Word ) : Boolean; virtual;
  private
    Modified: Boolean;
    procedure Refresh;
    procedure SetupEcho;
    procedure CreateEcho;
    procedure DeleteEcho;
    function  SelectedEcho( var Echo: PFileEcho ) : PFileEcho;
    function  GetHostArea( var Area: PFileArea ) : PFileArea;
  end; { TFileEchoBrowser }

const
  FileEchoBrowser: PFileEchoBrowser = nil;

{ Done ---------------------------------------------------- }

destructor TFileEchoBrowser.Done;
begin
  FileEchoBrowser := nil;
  inherited Done;
end; { Done }

{ SetupDialog --------------------------------------------- }

procedure TFileEchoBrowser.SetupDialog;
var
  R: TRect;
begin
  Desktop^.GetExtent( R );
  R.Grow( -1, -1 );
  Locate( R );
  OpenFileBase;
  R.Assign( 0, 0, 0, 0 );
  ListBox := PFileEchoBox( ShoeHorn( @Self, New( PFileEchoBox, Init(R, 1, nil) )));
  GetExtent( R );
  R.Grow( -1, -1 );
  ListBox^.SetBounds( R );
  R.A.X := R.B.X; Inc( R.B.X );
  ListBox^.VScrollBar^.SetBounds(R);
  ListBox^.NewList( FileBase^.EchoList );
end; { SetupDialog }

{ Valid --------------------------------------------------- }

function TFileEchoBrowser.Valid( Command: Word ) : Boolean;
begin
  Result := True;
  if Modified then
    FileBase^.Modified := True;
end; { Valid }

{ Refresh ------------------------------------------------- }

procedure TFileEchoBrowser.Refresh;
begin
  with ListBox^ do
  begin
    List := nil;
    NewList( FileBase^.EchoList );
  end;
end; { Refresh }

{ HandleEvent --------------------------------------------- }

procedure TFileEchoBrowser.HandleEvent( var Event: TEvent );
var
  Area: PFileArea;
begin
  inherited HandleEvent( Event );
  case Event.What of
    evCommand:
      begin
        case Event.Command of
          cmEnter  : OpenFileArea( GetHostArea(Area) );
          cmOptions: SetupEcho;
          cmInsItem: CreateEcho;
          cmDelItem: DeleteEcho;
          cmImport : if ImportEcho then Refresh;
        else
          Exit;
        end;
        ClearEvent( Event );
      end;
  end;
end; { HandleEvent }

{ SelectedEcho -------------------------------------------- }

function TFileEchoBrowser.SelectedEcho( var Echo: PFileEcho ) : PFileEcho;
begin
  with ListBox^ do
  begin
    if Focused < Range then
      Echo := List^.At(Focused)
    else
      Echo := nil;
  end;
  Result := Echo;
end; { SelectedEcho }

{ GetHostArea --------------------------------------------- }

function TFileEchoBrowser.GetHostArea( var Area: PFileArea ) : PFileArea;
var
  Echo: PFileEcho;
begin
  if SelectedEcho(Echo) = nil then
  begin
    Area := nil;
    Result := nil;
  end
  else
  begin
    Area := Echo^.Area;
    Result := Area;
  end;
end; { GetHostArea }

{ SetupEcho ----------------------------------------------- }

procedure TFileEchoBrowser.SetupEcho;
var
  R: TRect;
  E: PFileEchoSetupDialog;
  D: PDialog;
  T: PFileEcho;
  Q: TFileEchoSetupData;
  Echo: PFileEcho;
begin
  if SelectedEcho( Echo ) = nil then Exit;
  R.Assign( 0, 0, 0, 0 );
  D := PDialog( Res^.Get('SETUP_FE') );
  D^.HelpCtx := hcSetupEcho;
  E := New( PFileEchoSetupDialog, Init(R, '') );
  SwapDlg( D, E );
  E^.SetupDialog( Echo );
  FillChar( Q, SizeOf(Q), #0 );
  Q.EchoTag  := Echo^.Name^;
  Q.Paranoia := Echo^.Paranoia;
  Q.State    := Ord(Echo^.State);
  if Application^.ExecuteDialog( E, @Q ) = cmOk then
  begin
    Modified := True;
    Q.EchoTag := Trim(Q.EchoTag);
    T := FileBase^.GetEcho( Q.EchoTag );
    if (T <> nil) and (T <> Echo) then
    begin
      ShowError( LoadString(_SCantRenEchoNameExists) );
      Exit;
    end;
    FileBase^.EchoList^.AtDelete( ListBox^.Focused );
    ReplaceStr( Echo^.Name, Q.EchoTag );
    FileBase^.EchoList^.Insert( Echo );
    ListBox^.FocusItem( FileBase^.EchoList^.IndexOf( Echo ) );
    Echo^.Paranoia := Q.Paranoia;
    Echo^.State    := TEchoState(Q.State);
  end;
end; { SetupEcho }

{ CreateEcho ---------------------------------------------- }

procedure TFileEchoBrowser.CreateEcho;
var
  Shit: Integer;
  Name: String;
  NewEcho: PFileEcho;
begin
  Name := LoadString(_SNewEchoName);
  Shit := 0;
  while FileBase^.GetEcho( Name ) <> nil do
  begin
    Inc( Shit );
    Name := LoadString(_SNewEchoName) + ' (' + IntToStr(Shit) + ')';
  end;
  New( NewEcho, Init(Name) );
  FileBase^.EchoList^.Insert( NewEcho );
  Shit := FileBase^.EchoList^.IndexOf( NewEcho );
  with ListBox^ do
  begin
    SetRange( Succ(Range) );
    FocusItem( Shit );
  end;
  SetupEcho;
  Modified := True;
end; { CreateEcho }

{ DeleteEcho ---------------------------------------------- }

procedure TFileEchoBrowser.DeleteEcho;
var
  Echo: PFileEcho;
begin
  if SelectedEcho( Echo ) = nil then Exit;
  if MessageBox( Format(LoadString(_SConfirmDelEcho), [Echo^.Name^]), nil, mfWarning + mfYesNoCancel) = cmYes then
  begin
    with ListBox^ do
    begin
      FileBase^.EchoList^.AtFree( Focused );
      SetRange( Pred(Range) );
      DrawView;
    end;
    Modified := True;
  end;
end; { DeleteEcho }

{ --------------------------------------------------------- }
{ OpenFileEchoes                                            }
{ --------------------------------------------------------- }

procedure OpenFileEchoes;
var
  R: TRect;
  D: PDialog;
begin
  if FileEchoBrowser <> nil then
    FileEchoBrowser^.Select
  else
  begin
    NO_HOST_AREA := LoadString( _SNoHostArea );
    R.Assign( 0, 0, 0, 0 );
    D := PDialog( Res^.Get('FILE_ECHOES') );
    D^.HelpCtx := hcFileEchoManager;
    FileEchoBrowser := New( PFileEchoBrowser, Init(R, '') );
    SwapDlg( D, FileEchoBrowser );
    FileEchoBrowser^.SetupDialog;
    Desktop^.Insert( FileEchoBrowser );
  end;
end; { OpenFileEchoes }

{ --------------------------------------------------------- }
{ CloseFileEchoBrowser                                      }
{ --------------------------------------------------------- }

procedure CloseFileEchoBrowser;
begin
  if FileEchoBrowser <> nil then
  begin
    Destroy( FileEchoBrowser );
    FileEchoBrowser := nil;
  end;
end; { CloseFileEchoBrowser }

end.
