unit AreaPane;

/////////////////////////////////////////////////////////////////////
//
// Hi-Files Version 2
// Copyright (c) 1997-2004 Dmitry Liman [2:461/79]
//
// http://hi-files.narod.ru
//
/////////////////////////////////////////////////////////////////////

interface

uses Objects, Dialogs, MyViews, _FAreas;

type
  PFileAreaBox = ^TFileAreaBox;
  TFileAreaBox = object (TMyListBox)
    function  GetText( Item, MaxLen: Integer ) : String; virtual;
    function  DataSize: Integer;   virtual;
    procedure SetData( var Data ); virtual;
    procedure GetData( var Data ); virtual;
    procedure TagItem( Item: Integer; Tag: Boolean ); virtual;
    function ItemTagged( Item: Integer ) : Boolean; virtual;
  end; { TFileAreaBox }

procedure OpenFileAreas;
procedure OpenFileArea( Area: PFileArea );

procedure CloseFileBaseBrowser;

{ =================================================================== }

implementation

uses
  SysUtils, MyLib, _CFG, _LOG, _RES, App, Views, Drivers,
  MsgBox, Editors, Spawn, Import, HiFiHelp, StdDlg;

const
  MEMO_BUFFER_SIZE = $FFF0;

var
  ALONE_CMT_TEXT : String;
  MISSING_TEXT   : String;

type
  PMemoData = ^TMemoData;

{ --------------------------------------------------------- }
{ SafeAtoi                                                  }
{ --------------------------------------------------------- }

function SafeAtoi( const S: String ) : Integer;
begin
  try
    Result := StrToInt( S );
  except
    on E: Exception do
      begin
        ShowError( Format(LoadString(_SInvalidNumeric), [S] ));
        Result := 0;
      end;
  end;
end; { SafeAtoi }

{ --------------------------------------------------------- }
{ TFileAreaBox                                              }
{ --------------------------------------------------------- }

{ GetText ------------------------------------------------- }

function TFileAreaBox.GetText( Item, MaxLen: Integer ) : String;
begin
  Result := PFileArea( List^.At(Item) )^.Name^;
end; { GetText }

{ DataSize ------------------------------------------------ }

function TFileAreaBox.DataSize: Word;
begin
  Result := TListBox.DataSize;
end; { DataSize }

{ GetData ------------------------------------------------- }

procedure TFileAreaBox.GetData( var Data );
begin
  TListBox.GetData( Data );
end; { GetData }

{ SetData ------------------------------------------------- }

procedure TFileAreaBox.SetData( var Data );
begin
  TListBox.SetData( Data );
end; { SetData }

{ TagItem ------------------------------------------------- }

procedure TFileAreaBox.TagItem( Item: Integer; Tag: Boolean );
begin
  PFileArea(List^.At(Item))^.Tag := Tag;
end; { TagItem }

{ ItemTagged ---------------------------------------------- }

function TFileAreaBox.ItemTagged( Item: Integer ) : Boolean;
begin
  Result := PFileArea(List^.At(Item))^.Tag;
end; { ItemTagged }


{ --------------------------------------------------------- }
{ TFileBox                                                  }
{ --------------------------------------------------------- }

type
  PFileBox = ^TFileBox;
  TFileBox = object (TMyListBox)
    function GetText( Item, MaxLen: Integer ) : String; virtual;
    procedure TagItem( Item: Integer; Tag: Boolean ); virtual;
    function ItemTagged( Item: Integer ) : Boolean; virtual;
  end; { TFileBox }

{ GetText ------------------------------------------------- }

function TFileBox.GetText( Item, MaxLen: Integer ) : String;
var
  FD: PFileDef;
begin
  FD := List^.At( Item );
  if FD^.AloneCmt then
    Result := #254 + CharStr( #196, 12 ) + #254
  else
    Result := FD^.FileName^;
end; { GetText }

{ TagItem ------------------------------------------------- }

procedure TFileBox.TagItem( Item: Integer; Tag: Boolean );
begin
  PFileDef(List^.At(Item))^.Tag := Tag;
end; { TagItem }

{ ItemTagged ---------------------------------------------- }

function TFileBox.ItemTagged( Item: Integer ) : Boolean;
begin
  Result := PFileDef(List^.At(Item))^.Tag;
end; { ItemTagged }

{ --------------------------------------------------------- }
{ SelectArea                                                }
{ --------------------------------------------------------- }

function SelectArea( var Area: PFileArea ) : Boolean;
var
  R: TRect;
  D: PDialog;
  Data: record
          List: PCollection;
          Sel : Word;
        end;
begin
  R.Assign( 0, 0, 0, 0 );
  D := PDialog( Res^.Get('SELECT_AREA') );
  D^.HelpCtx := hcSelectArea;
  ShoeHorn( D, New( PFileAreaBox, Init( R, 1, nil)));
  Data.List := FileBase;
  Data.Sel  := 0;
  Area   := nil;
  Result := False;
  if Application^.ExecuteDialog( D, @Data ) = cmOk then
  begin
    if Data.Sel < FileBase^.Count then
    begin
      Area := FileBase^.At( Data.Sel );
      Result := True;
    end;
  end;
end; { SelectArea }

{ --------------------------------------------------------- }
{ TAreaPane                                                 }
{ --------------------------------------------------------- }

const
  cmView    = 200;
  cmMove    = 201;
  cmAlone   = 203;
  cmUndo    = 204;
  cmViewers = 205;

type
  PAreaPane = ^TAreaPane;
  TAreaPane = object (TDialog)
    ListBox: PFileBox;
    Memo   : PMemo;
    Status : PInfoPane;
    procedure SetupDialog( A: PFileArea );
    procedure HandleEvent( var Event: TEvent ); virtual;
    function  Valid( Command: Word ) : Boolean; virtual;
  private
    Area: PFileArea;
    Data: String;
    Link: PString;
    Modified: Boolean;
    procedure MoveFD;
    procedure DeleteFD;
    procedure AloneFD;
    procedure GetFileInfo( Item: Integer );
    procedure SetFileInfo( Item: Integer );
    function  GetFileDef( var FD: PFileDef ) : PFileDef;
    procedure RemoveDescriptor( Item: Integer; FreeIt: Boolean );
    procedure LaunchViewer;
    procedure SetupViewers;
  end; { TAreaPane }

{ SetupDialog --------------------------------------------- }

procedure TAreaPane.SetupDialog( A: PFileArea );
var
  R: TRect;
begin
  R.Assign( 0, 0, 0, 0 );
  Status  := PInfoPane( ShoeHorn( @Self, New( PInfoPane, Init( R, '', 0 ))));
  Memo    := PMemo( ShoeHorn( @Self, New( PMemo, Init( R, nil, nil, nil, MEMO_BUFFER_SIZE) )));
  ListBox := PFileBox( ShoeHorn( @Self, New( PFileBox, Init( R, 1, nil ))));

  if A^.Sorted and not A^.UseAloneCmt then
    ListBox^.SetMode( [lb_speedsearch, lb_multisel] )
  else
    ListBox^.SetMode( [lb_speedsearch, lb_multisel, lb_reorder] );

  Memo^.Options := Memo^.Options or ofFirstClick or ofFramed;
  Memo^.GetBounds( R );
  R.A.X := R.B.X; R.B.X := R.A.X + 1;
  Memo^.VScrollBar := New( PScrollBar, Init(R) );
  Insert( Memo^.VScrollBar );
  Memo^.GetBounds( R );
  R.A.Y := R.B.Y; R.B.Y := R.A.Y + 1; Inc( R.A.X, 16 ); Dec( R.B.X );
  Memo^.HScrollBar := New( PScrollBar, Init(R) );
  Insert( Memo^.HScrollBar );
  Memo^.GetBounds( R );
  R.A.Y := R.B.Y; R.B.Y := R.A.Y + 1;
  R.B.X := R.A.X + 16;
  Memo^.Indicator := New( PIndicator, Init(R) );
  Insert( Memo^.Indicator );
  Memo^.SetState( sfSelected, False );
  Link := @Data;
  Status^.SetData( Link );
  Area := A;
  Area^.ReadFilesBbs;
  Area^.Rescan;
  ListBox^.NewList( Area );
  GetFileInfo( 0 );
  {
    MyLib.ReplaceStr( Title, Area^.Name^ );
    Так делать нельзя: TDialog.Done вызывает DisposeStr, а не FreeStr :(
  }
  FreeStr( Title ); Title := Objects.NewStr( Area^.Name^ );

  if Area^.UseAloneCmt then
    EnableCommands( [cmAlone] )
  else
    DisableCommands( [cmAlone] );
end; { SetupDialog }

{ GetFileInfo --------------------------------------------- }

procedure TAreaPane.GetFileInfo( Item: Integer );
var
  FD: PFileDef;
  L : Word;
  D : PMemoData;

  procedure DoSum( P: PString ); far;
  begin
    Inc( L, Length(P^) + 2 );
  end; { DoSum }

  procedure DoCopy( P: PString ); far;
  begin
    Move( P^[1], D^.Buffer[L], Length(P^) );
    Inc( L, Length(P^) + 2 );
    D^.Buffer[L-2] := ^M;
    D^.Buffer[L-1] := ^J;
  end; { DoCopy }

begin
  if GetFileDef( FD ) <> nil then
  begin
    if FD^.AloneCmt then
      Data := ALONE_CMT_TEXT
    else if FD^.Missing then
      Data := MISSING_TEXT
    else if CFG^.DlcDigs > 0 then
      Data := Format( '%s  %s  [%' + IntToStr(CFG^.DlcDigs) + 'd] %s',
        [ ASRF(FD^.Size), GetFileDateStr(FD^.Time), FD^.DLC, FD^.LongName^ ] )
    else
      Data := Format( '%s  %s  %s',
        [ ASRF(FD^.Size), GetFileDateStr(FD^.Time), FD^.LongName^ ] );
    L := 0;
    FD^.ForEach( @DoSum );
    GetMem( D, L + SizeOf(Word) );
    D^.Length := L;
    L := 0;
    FD^.ForEach( @DoCopy );
    Memo^.SetData( D^ );
    FreeMem( D );
    Memo^.SetState( sfDisabled, False);
    if FD^.Missing or FD^.AloneCmt then
      DisableCommands( [cmView] )
    else
      EnableCommands( [cmView] );
    if FD^.AloneCmt then
      DisableCommands( [cmMove] )
    else
      EnableCommands( [cmMove] );
  end
  else
  begin
    Data := '';
    L := 0;
    Memo^.SetData( L );
    Memo^.SetState( sfDisabled, True);
  end;
  Status^.DrawView;
end; { GetFileInfo }

{ SetFileInfo --------------------------------------------- }

procedure TAreaPane.SetFileInfo( Item: Integer );
var
  j: Integer;
  S: String;
  D: PMemoData;
  FD: PFileDef;

  function Get( var S: String ) : Boolean;
  var
    k: Integer;
    n: Byte absolute S;
  begin
    if j >= D^.Length then
    begin
      S := '';
      Result := False;
    end
    else
    begin
      k := ScanR( D^.Buffer, j, D^.Length, ^M );
      n := k - j;
      Move( D^.Buffer[j], S[1], n );
      j := k + 2;
      Result := True;
    end;
  end; { Get }

begin
  if Memo^.Modified and (GetFileDef( FD ) <> nil) then
  begin
    GetMem( D, Memo^.DataSize );
    Memo^.GetData( D^ );
    FD^.FreeAll;
    j := 0;
    while Get( S ) do
      FD^.Append( S );
    FreeMem( D );
    FD^.Normalize;
    Modified := True;
  end;
end; { SetFileInfo }

{ MoveFD -------------------------------------------------- }

procedure TAreaPane.MoveFD;
var
  j : Integer;
  FD: PFileDef;
  Moved: Boolean;
  TargetArea: PFileArea;


  procedure DoMove(FD: PFileDef);
  var
    SourcePath: String;
    TargetPath: String;
  begin
    if FD^.AloneCmt and not TargetArea^.UseAloneCmt then Exit;

    Log^.Write( ll_Protocol, Format(LoadString(_SLogMovingFileToArea), [FD^.NativeName^, TargetArea^.Name^] ));

    if not FD^.Missing then
    begin
      if not Area^.Locate( FD, SourcePath ) then
        raise Exception.Create( LoadString(_SCantMoveSrcNotFound) );
      TargetPath := TargetArea^.Parking( FD^.NativeName^ );
      if VFS_MoveFile( SourcePath, TargetPath ) <> 0 then
        raise Exception.Create( Format(LoadString(_SMovingFailed), [TargetPath]));
    end;

    Modified := True;
    Moved    := True;

    RemoveDescriptor( ListBox^.List^.IndexOf(FD), False );
    TargetArea^.Insert( FD );
  end; { DoMove }


begin
  SetFileInfo( ListBox^.Focused );

  if ( ListBox^.GetTagCount = 0 ) and (GetFileDef( FD ) = nil ) or
       not SelectArea( TargetArea )
  then
    Exit;

  if TargetArea = Area then
  begin
    ShowError( LoadString(_SCantMoveToSameArea) );
    Exit;
  end;

  try
    Moved := False;
    TargetArea^.ReadFilesBbs;

    if ListBox^.GetTagCount > 0 then
    begin
      for j := Pred(Area^.Count) downto 0 do
      begin
        FD := Area^.At(j);
        if FD^.Tag then
          DoMove(FD);
      end;
    end
    else
      DoMove(FD);

    if Moved then
      with TargetArea^ do
      begin
        Complete;
        WriteFilesBbs;
      end;

  except
    on E: Exception do ShowError( E.Message );

  end;


{
  if (GetFileDef( FD ) = nil) or
     FD^.AloneCmt or
     not SelectArea( TargetArea )
  then
    Exit;
  try
    if TargetArea = Area then
      raise Exception.Create( LoadString(_SCantMoveToSameArea) );

    TargetArea^.ReadFilesBbs;
    if TargetArea^.Search( FD^.FileName, j ) then
      raise Exception.Create( LoadString(_SCantMoveAlreadyExists) );

    Modified := True;
    Log^.Write( ll_Protocol, Format(LoadString(_SLogMovingFileToArea), [FD^.NativeName^, TargetArea^.Name^] ));
    if not FD^.Missing then
    begin
      if not Area^.Locate( FD, SourcePath ) then
        raise Exception.Create( LoadString(_SCantMoveSrcNotFound) );
      TargetPath := TargetArea^.Parking( FD^.NativeName^ );
      if VFS_MoveFile( SourcePath, TargetPath ) <> 0 then
        raise Exception.Create( Format(LoadString(_SMovingFailed), [TargetPath]));
    end;
    RemoveDescriptor( ListBox^.Focused, False );
    with TargetArea^ do
    begin
      Insert( FD );
      Complete;
      WriteFilesBbs;
    end;
  except
    on E: Exception do ShowError( E.Message );
  end;
}

end; { MoveFD }

{ DeleteFD ------------------------------------------------ }

procedure TAreaPane.DeleteFD;
const
  bDescr = $0001;
  bFile  = $0002;
var
  FD: PFileDef;
  j : Integer;
  D : PDialog;
  Q : record
    FileName: PString;
    Options : Longint;
  end;
  Path : String;
  Alone: String;
begin
  if ListBox^.GetTagCount > 0 then
  begin
    if MessageBox( Format(LoadString(_SConfirmDelMultiFile),
       [ListBox^.GetTagCount, GetCounterStr(_SFileCounter, ListBox^.GetTagCount)]), nil,
       mfConfirmation + mfYesNoCancel) <> cmYes then Exit;

    for j := Pred(Area^.Count) downto 0 do
    begin
      FD := Area^.At(j);
      if FD^.Tag then
      begin
        if not FD^.AloneCmt then
        begin
          Area^.Locate( FD, Path );
          if not VFS_EraseFile( Path ) then
            ShowError( Format(LoadString(_SCantDelFile), [Path] ));
        end;
        Area^.AtFree(j);
      end;
    end;

    with ListBox^ do
    begin
      SetRange( Area^.Count );
      FocusItem( Focused );
    end;
    Modified := True;
    Exit;

  end;

  if GetFileDef( FD ) = nil then Exit;

  D := PDialog( Res^.Get( 'DEL_FD' ) );
  D^.HelpCtx := hcDelFD;
  Q.Options := bDescr;
  if FD^.AloneCmt then
  begin
    Alone := ALONE_CMT_TEXT;
    Q.FileName := @Alone;
  end
  else
    Q.FileName := FD^.NativeName;
  if Application^.ExecuteDialog( D, @Q ) = cmOk then
  begin
    if TestBit( Q.Options, bFile ) and not FD^.AloneCmt and not FD^.Missing then
    begin
      if MessageBox( Format(LoadString(_SConfirmDelFile), [Q.FileName^]), nil,
         mfConfirmation + mfYesNoCancel ) = cmYes then
      begin
        Modified := True;
        Area^.Locate( FD, Path );
        if not VFS_EraseFile( Path ) then
          ShowError( Format(LoadString(_SCantDelFile), [Path] ));
      end;
    end;
    if TestBit( Q.Options, bDescr ) then
    begin
      Modified := True;
      RemoveDescriptor( ListBox^.Focused, True );
    end;
  end;
end; { DeleteFD }

{ AloneFD ------------------------------------------------- }

procedure TAreaPane.AloneFD;
var
  FD1: PFileDef;
  FD2: PFileDef;
begin
  SetFileInfo( ListBox^.Focused );
  if (GetFileDef( FD1 ) <> nil) and not FD1^.AloneCmt then
    FD1 := nil;
  if ListBox^.Focused > 0 then
  begin
    FD2 := Area^.At(Pred(ListBox^.Focused));
    if not FD2^.AloneCmt then
      FD2 := nil;
  end
  else
    FD2 := nil;
  if (FD1 <> nil) or (FD2 <> nil) then
  begin
    ShowError( LoadString(_SCantAloneNearAlone) );
    Exit;
  end;
  FD1 := New( PFileDef, Init( ALONE_CMT ) );
  FD1^.Append( ' '#254 );
  with ListBox^ do
  begin
    Area^.AtInsert( Focused, FD1 );
    SetRange( Succ(Range) );
    GetFileInfo( Focused );
    DrawView;
  end;
  Modified := True;
end; { AloneFD }

{ RemoveDescriptor ---------------------------------------- }

procedure TAreaPane.RemoveDescriptor( Item: Integer; FreeIt: Boolean );
begin
  if Item < Area^.Count then
  begin
    if FreeIt then
      Area^.AtFree( Item )
    else
      Area^.AtDelete( Item );

    with ListBox^ do
    begin
      SetRange( Pred(Range) );
      GetFileInfo( Focused );
      DrawView;
    end;
  end;
end; { RemoveDescriptor }

{ GetFileDef ---------------------------------------------- }

function TAreaPane.GetFileDef( var FD: PFileDef ) : PFileDef;
begin
  if ListBox^.Focused < Area^.Count then
    FD := Area^.At( ListBox^.Focused )
  else
    FD := nil;
  Result := FD;
end; { GetFileDef }

{ LaunchViewer -------------------------------------------- }

procedure TAreaPane.LaunchViewer;
var
  FD: PFileDef;
  Path: String;
  Call: String;
  Exe : String;
  Par : String;
  Err : Integer;
begin
  if (GetFileDef( FD ) = nil) or FD^.AloneCmt then Exit;
  Area^.Locate( FD, Path );
  if CFG^.Viewers^.GetCall( Path, Call ) then
  begin
    SplitPair( Call, Exe, Par );
    Err := Spawn.Execute( Exe, Par + ' ' + Path, False );
    if Err < 0 then
      ShowError( Format(LoadString(_SViewerError), [-Err]));
  end
  else
    MessageBox( LoadString(_SNoViewer), nil, mfWarning + mfOkButton );
end; { LaunchViewer }

{ SetupViewers -------------------------------------------- }

procedure TAreaPane.SetupViewers;
var
  R: TRect;
  D: PDialog;
  E: PStrListEditor;
begin
  R.Assign( 0, 0, 0, 0 );
  D := PDialog( Res^.Get('SETUP_DIZ') );
  D^.HelpCtx := hcSetupViewers;
  E := New( PStrListEditor, Init(R, '') );
  SwapDlg( D, E );
  E^.SetupDialog( LoadString(_SViewersCaption), CFG^.Viewers );
  Application^.ExecuteDialog( E, nil );
  CFG^.Modified := True;
end; { SetupViewers }

{ HandleEvent --------------------------------------------- }

procedure TAreaPane.HandleEvent( var Event: TEvent );
begin
  inherited HandleEvent( Event );
  case Event.What of
    evCommand:
      begin
        case Event.Command of
          cmMove    : MoveFD;
          cmDelItem : DeleteFD;
          cmAlone   : AloneFD;
          cmUndo    : GetFileInfo( ListBox^.Focused );
          cmView    : LaunchViewer;
          cmViewers : SetupViewers;
        else
          Exit;
        end;
        ClearEvent( Event );
      end;
    evBroadcast:
      case Event.Command of
        cmFocusMoved:
          GetFileInfo( Event.InfoLong );
        cmFocusLeave:
          SetFileInfo( Event.InfoLong );
      end;
  end;
end; { HandleEvent }

{ Valid --------------------------------------------------- }

function TAreaPane.Valid( Command: Word ) : Boolean;
begin
  Result := True;
  if (Command = cmClose) or (Command = cmCancel) then
  begin
    if Memo^.Modified then
      SetFileInfo( ListBox^.Focused );
    if Modified or ListBox^.Reordered then
    begin
       case MessageBox( LoadString(_SConfirmSaveFilesBbs), nil, mfWarning + mfYesNoCancel ) of
         cmYes: Area^.WriteFilesBbs;
         cmNo : {Nothing};
         cmCancel: Result := False;
       end;
    end;
  end;
end; { Valid }

{ --------------------------------------------------------- }
{ TAreaSetupDialog                                          }
{ --------------------------------------------------------- }

type
  TAreaSetupDialogData = record
    Name       : LongStr;
    FileList   : LongStr;
    Group      : LongStr;
    DL_Path    : LongStr;
    Recurse    : Longint;
    UL_Path    : LongStr;
    FListFormat: Longint;
    TornadoOpt : Longint;
    AloneCmt   : Longint;
    SortMode   : Longint;
    ScanNew    : Longint;
    DL_Sec     : ShortStr;
    UL_Sec     : ShortStr;
    List_Sec   : ShortStr;
    Show_Sec   : ShortStr;
    HideFreq   : Longint;
  end;

  PAreaSetupDialog = ^TAreaSetupDialog;
  TAreaSetupDialog = object (TDialog)
    procedure SetupDialog( A: PFileArea );
    procedure HandleEvent( var Event: TEvent ); virtual;
  private
    Area: PFileArea;
    DL_Path: PInputLine;
    UL_Path: PInputLine;
    procedure MoreDownloadPath;
    procedure PrimaryDLPath;
    procedure CommonULPath;
  end; { TAreaSetupDialog }

{ SetupDialog --------------------------------------------- }

procedure TAreaSetupDialog.SetupDialog( A: PFileArea );
var
  R: TRect;
begin
  R.Assign( 0, 0, 0, 0 );
  UL_Path := PInputLine( ShoeHorn( @Self, New( PInputLine, Init(R, Pred(SizeOf(LongStr))))));
  DL_Path := PInputLine( ShoeHorn( @Self, New( PInputLine, Init(R, Pred(SizeOf(LongStr))))));
  Area := A;
end; { SetupDialog }

{ HandleEvent --------------------------------------------- }

procedure TAreaSetupDialog.HandleEvent( var Event: TEvent );
const
  cmMore = 200;
  cmPDP  = 201;
  cmCUP  = 202;
begin
  inherited HandleEvent( Event );
  case Event.What of
    evCommand:
      begin
        case Event.Command of
          cmMore: MoreDownloadPath;
          cmPDP : PrimaryDLPath;
          cmCUP : CommonULPath;
        else
          Exit;
        end;
        ClearEvent( Event );
      end;
  end;
end; { HandleEvent }

{ MoreDownloadPath ---------------------------------------- }

procedure TAreaSetupDialog.MoreDownloadPath;
var
  S: String;
  P: String;
  R: TRect;
  D: PDialog;
  E: PStrListEditor;
begin
  R.Assign( 0, 0, 0, 0 );
  D := PDialog( Res^.Get('SETUP_DIZ') );
  D^.HelpCtx := hcMoreDLPath;
  E := New( PStrListEditor, Init(R, '') );
  SwapDlg( D, E );
  E^.SetupDialog( LoadString(_SMoreDLPathCaption), Area^.DL_Path );
  Application^.ExecuteDialog( E, nil );
  if Area^.GetPDP( P ) then
  begin
    DL_Path^.GetData( S );
    if not JustSameText( S, P ) then
      DL_Path^.SetData( P );
  end
  else
  begin
    S := '';
    DL_Path^.SetData( S );
  end;
end; { MoreDownloadPath }

{ PrimaryDLPath ------------------------------------------- }

procedure TAreaSetupDialog.PrimaryDLPath;
var
  D: PDialog;
  SaveDir: String;
  Root: String;
  Data: TAreaSetupDialogData;
begin
  GetData( Data );
  SaveDir := GetCurrentDir;
  SetCurrentDir( Data.DL_Path );
  D := New( PChDirDialog, Init( cdNormal, 100 ) );
  if Application^.ExecuteDialog( D, nil ) = cmOk then
  begin
    Root := GetCurrentDir;
    SetCurrentDir( SaveDir );
    GetData( Data );
    Area^.DL_Path^.FreeAll;
    Area^.DL_Path^.Insert( AllocStr(Root) );
    Data.FileList := AtPath( FILES_BBS, Root );
    Data.DL_Path  := Root;
    if not JustSameText( ExpandFileName(AddBackSlash(Data.UL_Path)),
                         ExpandFileName(AddBackSlash(CFG^.CommonULPath)) ) then
      Data.UL_Path  := Root;
    SetData( Data );
  end
  else
    SetCurrentDir( SaveDir );
end; { PrimaryDLPath }

{ CommonULPath -------------------------------------------- }

procedure TAreaSetupDialog.CommonULPath;
var
  R: TRect;
  D: PDialog;
  OldCUP: String;
begin
  R.Assign( 0, 0, 0, 0 );
  D := PDialog( Res^.Get('USE_CUP') );
  D^.HelpCtx := hcUseCUP;
  OldCUP := CFG^.CommonULPath;
  if Application^.ExecuteDialog( D, @CFG^.CommonULPath ) = cmOk then
  begin
    MyLib.ReplaceStr( Area^.UL_Path, ExistingDir(CFG^.CommonULPath, True) );
    UL_Path^.SetData( Area^.UL_Path^ );
    if not JustSameText(OldCUP, CFG^.CommonULPath) then
      CFG^.Modified := True;
  end;
end; { CommonULPath }

{ --------------------------------------------------------- }
{ TFileBaseBrowser                                          }
{ --------------------------------------------------------- }

type
  PFileBaseBrowser = ^TFileBaseBrowser;
  TFileBaseBrowser = object (TDialog)
    ListBox: PFileAreaBox;
    destructor Done; virtual;
    procedure SetupDialog;
    procedure HandleEvent( var Event: TEvent ); virtual;
    function  Valid( Command: Word ) : Boolean; virtual;
  private
    Modified: Boolean;
    function  SelectedArea( var Area: PFileArea ) : PFileArea;
    function  SetupArea : Boolean;
    procedure SetupTaggedAreas;
    procedure CreateArea;
    procedure DeleteArea;
    procedure Refresh;
  end; { TFileBaseBrowser }

const
  FileBaseBrowser: PFileBaseBrowser = nil;

const
  bDefault        = 0;
  bRaised         = 1;
  bLowered        = 2;
type
  TSwitchToBit = array [TSwitch] of Longint;
  TBitToSwitch = array [bDefault..bLowered] of TSwitch;
const
  SwitchToBit: TSwitchToBit = ( bLowered, bRaised, bDefault );
  BitToSwitch: TBitToSwitch = ( Default, Raised, Lowered );

{ Done ---------------------------------------------------- }

destructor TFileBaseBrowser.Done;
begin
  FileBaseBrowser := nil;
  inherited Done;
end; { Done }

{ SetupDialog --------------------------------------------- }

procedure TFileBaseBrowser.SetupDialog;
var
  R: TRect;
begin
  Desktop^.GetExtent( R );
  R.Grow( -1, -1 );
  Locate( R );
  OpenFileBase;
  R.Assign( 0, 0, 0, 0 );
  ListBox := PFileAreaBox( ShoeHorn( @Self, New( PFileAreaBox, Init(R, 1, nil))));
  ListBox^.SetMode([lb_speedsearch, lb_reorder, lb_multisel]);
  GetExtent( R );
  R.Grow( -1, -1 );
  ListBox^.SetBounds( R );
  R.A.X := R.B.X; Inc( R.B.X );
  ListBox^.VScrollBar^.SetBounds(R);
  ListBox^.NewList( FileBase );
end; { SetupDialog }

{ Refresh ------------------------------------------------- }

procedure TFileBaseBrowser.Refresh;
begin
  with ListBox^ do
  begin
    List := nil;
    NewList( FileBase );
  end;
end; { Refresh }

{ HandleEvent --------------------------------------------- }

procedure TFileBaseBrowser.HandleEvent( var Event: TEvent );
var
  Area: PFileArea;
begin
  inherited HandleEvent( Event );
  case Event.What of
    evCommand:
      begin
        case Event.Command of
          cmEnter   : OpenFileArea( SelectedArea(Area) );
          cmOptions : SetupArea;
          cmInsItem : CreateArea;
          cmDelItem : DeleteArea;
          cmImport  : if ImportArea( SelectedArea(Area) ) then Refresh;
        else
          Exit;
        end;
        ClearEvent( Event );
      end;
  end;
end; { HandleEvent }

{ Valid --------------------------------------------------- }

function TFileBaseBrowser.Valid( Command: Word ) : Boolean;
begin
  Result := True;
  if Modified or ListBox^.Reordered then
    FileBase^.Modified := True;
end; { Valid }

{ SelectedArea -------------------------------------------- }

function TFileBaseBrowser.SelectedArea( var Area: PFileArea ) : PFileArea;
begin
  Area := nil;
  with ListBox^ do
    if Focused < Range then
      Area := List^.At(Focused);
  Result := Area;
end; { SelectedArea }

{ SetupArea ----------------------------------------------- }

function TFileBaseBrowser.SetupArea : Boolean;
const
  bStandardFormat = 0;
  bExtendedFormat = 1;
  bTorScanNew     = $0001;
  bTorCopyLocal   = $0002;
var
  R: TRect;
  D: PDialog;
  E: PAreaSetupDialog;
  A: PFileArea;
  Area : PFileArea;
  Data : TAreaSetupDialogData;
  Path : String;
begin
  Result := False;
  if ListBox^.GetTagCount > 0 then
  begin
    SetupTaggedAreas;
    Exit;
  end;
  if SelectedArea( Area ) = nil then Exit;
  R.Assign( 0, 0, 0, 0 );
  D := PDialog( Res^.Get('SETUP_AREA') );
  D^.HelpCtx := hcSetupArea;
  E := New( PAreaSetupDialog, Init(R, '') );
  SwapDlg( D, E );
  E^.SetupDialog( Area );
  FillChar( Data, SizeOf(Data), 0 );
  with Area^ do
  begin
    Data.Name     := Name^;
    Data.FileList := FilesBbs^;
    Data.Group    := Group^;
    Area^.GetPDP( Data.DL_Path );
    Data.UL_Path := UL_Path^;
    case FormatBbs of
      bbs_fmt_Standard : Data.FListFormat := bStandardFormat;
      bbs_fmt_Extended : Data.FListFormat := bExtendedFormat;
    end;
    SetBit( Data.TornadoOpt, bTorScanNew,   ScanTornado );
    SetBit( Data.TornadoOpt, bTorCopyLocal, CopyLocal );
    Data.AloneCmt := SwitchToBit[ fUseAloneCmt ];
    Data.SortMode := SwitchToBit[ fSorted ];
    Data.ScanNew  := SwitchToBit[ fScan ];
    Data.DL_Sec   := DL_Sec^;
    Data.UL_Sec   := UL_Sec^;
    Data.List_Sec := List_Sec^;
    Data.Show_Sec := Show_Sec^;
    Data.HideFreq := Ord( HideFreq );
    Data.Recurse  := Ord( Recurse );
  end;

  if Application^.ExecuteDialog( E, @Data ) = cmOk then
  begin
    A := FileBase^.GetArea( Data.Name );
    if (A <> nil) and (A <> Area) then
    begin
      ShowError( LoadString(_SCantRenameAreaExists) );
      Exit;
    end;
    Modified := True;
    with Area^ do
    begin
      MyLib.ReplaceStr( Name, Data.Name );
      MyLib.ReplaceStr( FilesBbs, Data.FileList );
      MyLib.ReplaceStr( Group, Data.Group );

      if Data.DL_Path <> '' then
        Data.DL_Path := AddBackSlash( Data.DL_Path );
      if Data.UL_Path <> '' then
        Data.UL_Path := AddBackSlash( Data.UL_Path );

      if Area^.GetPDP( Path ) then
      begin
        if not JustSameText( Data.DL_Path, Path ) then
        begin
          DL_Path^.AtFree(0);
          DL_Path^.AtInsert( 0, AllocStr(Data.DL_Path) );
        end;
      end
      else
        DL_Path^.Insert( AllocStr(Data.DL_Path) );

      MyLib.ReplaceStr( UL_Path, Data.UL_Path );
      case Data.FListFormat of
        bStandardFormat : FormatBbs := bbs_fmt_Standard;
        bExtendedFormat : FormatBbs := bbs_fmt_Extended;
      end;
      ScanTornado  := TestBit( Data.TornadoOpt, bTorScanNew );
      CopyLocal    := TestBit( Data.TornadoOpt, bTorCopyLocal );
      fUseAloneCmt := BitToSwitch[ Data.AloneCmt ];
      fSorted      := BitToSwitch[ Data.SortMode ];
      fScan        := BitToSwitch[ Data.ScanNew  ];
      MyLib.ReplaceStr( DL_Sec, Trim(Data.DL_Sec) );
      MyLib.ReplaceStr( UL_Sec, Trim(Data.UL_Sec) );
      MyLib.ReplaceStr( List_Sec, Trim(Data.List_Sec) );
      MyLib.ReplaceStr( Show_Sec, Trim(Data.Show_Sec) );
      HideFreq     := Boolean( Data.HideFreq );
      Recurse      := Boolean( Data.Recurse );
      ListBox^.DrawView;
      Result := True;
    end;
  end;
end; { SetupArea }

{ SetupTaggedAreas ---------------------------------------- }

procedure TFilebaseBrowser.SetupTaggedAreas;
const
  bGroupTag = $0001;
  bUpload   = $0002;
  bFreq     = $0004;
  bAloneCmt = $0008;
  bSort     = $0010;
  bScanNew  = $0020;

var
  D: PDialog;
  Q: record
    Activity: Word;
    GroupTag: LongStr;
    Upload  : LongStr;
    Freq    : Word;
    AloneCmt: Word;
    Sort    : Word;
    ScanNew : Word;
  end;

  procedure Apply( Area: PFileArea ); far;
  begin
    if Area^.Tag then
    begin
      if TestBit(Q.Activity, bGroupTag) then
        MyLib.ReplaceStr(Area^.Group, Q.GroupTag);
      if TestBit(Q.Activity, bUpload) then
        MyLib.ReplaceStr(Area^.UL_Path, Q.Upload);
      if TestBit(Q.Activity, bFreq) then
        Area^.HideFreq := Q.Freq <> 0;
      if TestBit(Q.Activity, bAloneCmt) then
        Area^.fUseAloneCmt := BitToSwitch[Q.AloneCmt];
      if TestBit(Q.Activity, bSort) then
        Area^.fSorted := BitToSwitch[Q.Sort];
      if TestBit(Q.Activity, bScanNew) then
        Area^.fScan := BitToSwitch[Q.ScanNew];
    end;
  end; { Apply }

begin
  D := PDialog(Res^.Get('SETUP_MUL_FA'));
  D^.HelpCtx := hcSetupMultiArea;

  FillChar( Q, SizeOf(Q), 0 );

  if (Application^.ExecuteDialog(D, @Q) <> cmOk) or (Q.Activity = 0) then
    Exit;

  FileBase^.ForEach( @Apply );

  Modified := True;

end; { SetupTaggedAreas }

{ CreateArea ---------------------------------------------- }

procedure TFileBaseBrowser.CreateArea;

  procedure DoClearTag(A: PFileArea); far;
  begin
    A^.Tag := False;
  end; { DoClearTag }

var
  Shit: Integer;
  Name: String;
  NewArea: PFileArea;
  SelArea: PFileArea;
begin
  Name := LoadString( _SNewAreaName );
  Shit := 0;
  while FileBase^.GetArea( Name ) <> nil do
  begin
    Inc( Shit );
    Name := LoadString( _SNewAreaName ) + ' (' + IntToStr(Shit) + ')';
  end;

  New( NewArea, Init(Name) );
  if SelectedArea( SelArea ) <> nil then
    SelArea^.Clone( NewArea );

  ListBox^.SetRange(Succ(ListBox^.Range));

  if FileBase^.Count = 0 then
    FileBase^.AtInsert( 0, NewArea )
  else
  begin
    FileBase^.AtInsert( Succ(ListBox^.Focused), NewArea );
    ListBox^.FocusItem(Succ(ListBox^.Focused));
  end;

  FileBase^.ForEach( @DoClearTag );

  ListBox^.DrawView;

  if SetupArea then
    Modified := True
  else
  begin
    FileBase^.AtFree( ListBox^.Focused );
    with ListBox^ do
    begin
      SetRange(Pred(Range));
      DrawView;
    end
  end;
end; { CreateArea }

{ DeleteArea ---------------------------------------------- }

procedure TFileBaseBrowser.DeleteArea;
var
  j    : Integer;
  Area : PFileArea;
  Echo : PFileEcho;
  Count: Integer;

  function Hosted( E: PFileEcho ) : Boolean; far;
  begin
    Result := E^.Area = Area;
  end; { Hosted }

  function HostedByTag( E: PFileEcho ) : Boolean; far;
  begin
    Result := (E^.Area <> nil) and E^.Area^.Tag;
  end; { HostedByTag }

begin
  if ListBox^.GetTagCount > 0 then
  begin
    Echo := FileBase^.EchoList^.FirstThat( @HostedByTag );
    if Echo <> nil then
    begin
      MessageBox( Format(LoadString(_SCantDelHostArea), [Echo^.Name^]), nil, mfWarning + mfOkButton );
      Exit;
    end;

    if MessageBox( Format(LoadString(_SConfirmDelMultiArea),
       [ListBox^.GetTagCount, GetCounterStr(_SFileAreaCounter, ListBox^.GetTagCount)]), nil, mfConfirmation + mfYesNoCancel) <> cmYes then Exit;

    for j := Pred(FileBase^.Count) downto 0 do
      if PFileArea(FileBase^.At(j))^.Tag then
        FileBase^.AtFree(j);

    ListBox^.SetRange( FileBase^.Count );
    ListBox^.DrawView;

    Modified := True;

  end
  else if SelectedArea( Area ) <> nil then
  begin
    Echo := FileBase^.EchoList^.FirstThat( @Hosted );
    if Echo <> nil then
    begin
      MessageBox( Format(LoadString(_SCantDelHostArea), [Echo^.Name^]), nil, mfWarning + mfOkButton );
      Exit;
    end;
    if MessageBox( Format(LoadString(_SConfirmDelArea), [Area^.Name^]), nil, mfWarning + mfYesNoCancel ) = cmYes then
    begin
      with ListBox^ do
      begin
        FileBase^.AtFree( Focused );
        SetRange( Pred(Range) );
        DrawView;
      end;
      Modified := True;
    end;
  end;
end; { DeleteArea }

{ --------------------------------------------------------- }
{ OpenFileArea                                              }
{ --------------------------------------------------------- }

procedure OpenFileArea( Area: PFileArea );
var
  R: TRect;
  E: PAreaPane;
  D: PDialog;
begin
  if Area = nil then Exit;
  R.Assign( 0, 0, 0, 0 );
  D := PDialog( Res^.Get('AREA_PANE') );
  D^.HelpCtx := hcAreaPane;
  E := New( PAreaPane, Init(R, '') );
  SwapDlg( D, E );
  E^.SetupDialog( Area );
  Application^.ExecuteDialog( E, nil );
end; { OpenFileArea }

{ --------------------------------------------------------- }
{ OpenFileAreas                                             }
{ --------------------------------------------------------- }

procedure OpenFileAreas;
var
  R: TRect;
  D: PDialog;
begin
  if FileBaseBrowser <> nil then
    FileBaseBrowser^.Select
  else
  begin
    ALONE_CMT_TEXT := LoadString( _SAloneCmtText );
    MISSING_TEXT   := LoadString( _SMissingText );
    R.Assign( 0, 0, 0, 0 );
    D := PDialog( Res^.Get('FILE_AREAS') );
    D^.HelpCtx := hcAreaMgr;
    FileBaseBrowser := New( PFileBaseBrowser, Init(R, '') );
    SwapDlg( D, FileBaseBrowser );
    FileBaseBrowser^.SetupDialog;
    Desktop^.Insert( FileBaseBrowser );
  end;
end; { OpenFileAreas }

{ --------------------------------------------------------- }
{ CloseFileBaseBrowser                                      }
{ --------------------------------------------------------- }

procedure CloseFileBaseBrowser;
begin
  if FileBaseBrowser <> nil then
  begin
    Destroy( FileBaseBrowser );
    FileBaseBrowser := nil;
  end;
end; { CloseFileBaseBrowser }

end.
