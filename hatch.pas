unit Hatch;

/////////////////////////////////////////////////////////////////////
//
// Hi-Files Version 2
// Copyright (c) 1997-2004 Dmitry Liman [2:461/79]
//
// http://hi-files.narod.ru
//
/////////////////////////////////////////////////////////////////////

interface

procedure RunHatcher;

{ =================================================================== }

implementation

uses
{$IFDEF Win32}
  Windows,
{$ENDIF}
  Objects, MyLib, MyViews, Views, Dialogs, Drivers, Editors, App, _fopen,
  MsgBox, SysUtils, _LOG, _CFG, _RES, _Fareas, _Tic, _CRC32, Gen, HiFiHelp;

const
  MEMO_BUFFER_SIZE = $FFF0;

{ --------------------------------------------------------- }
{ TFileEchoBox                                              }
{ --------------------------------------------------------- }

type
  PFileEchoBox = ^TFileEchoBox;
  TFileEchoBox = object (TMyListBox)
    function  GetText( Item, MaxLen: Integer ) : String; virtual;
    function  DataSize: Integer; virtual;
    procedure SetData( var Data ); virtual;
    procedure GetData( var Data ); virtual;
  end; { TFileEchoBox }

{ GetText ------------------------------------------------- }

function TFileEchoBox.GetText( Item, MaxLen: Integer ) : String;
begin
  Result := PFileEcho( List^.At(Item) )^.Name^;
end; { GetText }

{ DataSize ------------------------------------------------ }

function TFileEchoBox.DataSize: Word;
begin
  Result := TListBox.DataSize;
end; { DataSize }

{ GetData ------------------------------------------------- }

procedure TFileEchoBox.GetData( var Data );
begin
  TListBox.GetData( Data );
end; { GetData }

{ SetData ------------------------------------------------- }

procedure TFileEchoBox.SetData( var Data );
begin
  TListBox.SetData( Data );
end; { SetData }

{ --------------------------------------------------------- }
{ SelectFileEcho                                            }
{ --------------------------------------------------------- }

function SelectFileEcho( var Echo: PFileEcho ) : Boolean;
var
  R: TRect;
  D: PDialog;
  Q: record
       List: PCollection;
       Sel : Word;
     end;
begin
  R.Assign( 0, 0, 0, 0 );
  D := PDialog( Res^.Get('SELECT_ECHO') );
  D^.HelpCtx := hcSelectEcho;
  ShoeHorn( D, New( PFileEchoBox, Init( R, 1, nil)));
  Q.List := FileBase^.EchoList;
  if Echo <> nil then
    Q.Sel := FileBase^.EchoList^.IndexOf( Echo )
  else
    Q.Sel := 0;
  if Application^.ExecuteDialog( D, @Q ) = cmOk then
  begin
    if Q.Sel < FileBase^.EchoList^.Count then
    begin
      Echo := FileBase^.EchoList^.At( Q.Sel );
      Result := True;
    end;
  end
  else
  begin
    Echo := nil;
    Result := False;
  end;
end; { SelectFileEcho }

{ --------------------------------------------------------- }
{ PHatchDialog                                              }
{ --------------------------------------------------------- }

const
  bDelayToss = $0001;
  bKillFile  = $0002;

type
  PMemoData = ^TMemoData;

  PHatchDialogData = ^THatchDialogData;
  THatchDialogData = record
    FileName: LongStr;
    EchoTag : LongStr;
    Replaces: LongStr;
    Magic   : LongStr;
    Opt     : Longint;
    MemoData: PMemoData;
  end; { THatchDialogData }

  PHatchDialog = ^THatchDialog;
  THatchDialog = object (TDialog)
    FileName: PInputLine;
    Echotag : PInputLine;
    Replaces: PInputLine;
    Magic   : PInputLine;
    Opt     : PCheckBoxes;
    Memo    : PMemo;
    procedure SetupDialog;
    procedure SetData( var Data ); virtual;
    procedure GetData( var Data ); virtual;
    function  DataSize: Word; virtual;
    procedure HandleEvent( var Event: TEvent ); virtual;
  private
    procedure BrowseFile;
    procedure SelectArea;
    procedure GetDiz;
  end; { THatchDialog }

{ DataSize ------------------------------------------------ }

function THatchDialog.DataSize: Word;
begin
  Result := SizeOf(THatchDialogData);
end; { DataSize }

{ GetData ------------------------------------------------- }

procedure THatchDialog.GetData( var Data );
var
  Q: THatchDialogData absolute Data;
begin
  if Q.MemoData <> nil then
    FreeMem( Q.MemoData );
  GetMem( Q.MemoData, Memo^.DataSize );
  FileName^.GetData( Q.FileName );
  EchoTag^.GetData( Q.EchoTag );
  Replaces^.GetData( Q.Replaces );
  Magic^.GetData( Q.Magic );
  Opt^.GetData( Q.Opt );
  Memo^.GetData( Q.MemoData^ );
end; { GetData }

{ SetData ------------------------------------------------- }

procedure THatchDialog.SetData( var Data );
var
  Q: THatchDialogData absolute Data;
begin
  FileName^.SetData( Q.FileName );
  EchoTag^.SetData( Q.EchoTag );
  Replaces^.SetData( Q.Replaces );
  Magic^.SetData( Q.Magic );
  Opt^.SetData( Q.Opt );
  if Q.MemoData = nil then
  begin
    GetMem( Q.MemoData, SizeOf(Word) );
    Q.MemoData^.Length := 0;
  end;
  Memo^.SetData( Q.MemoData^ );
  FreeMem( Q.MemoData );
  Q.MemoData := nil;
end; { SetData }

{ SetupDialog --------------------------------------------- }

procedure THatchDialog.SetupDialog;
const
  ISize = SizeOf(LongStr) - 1;
var
  R: TRect;
begin
  R.Assign( 0, 0, 0, 0 );
  Memo  := PMemo( ShoeHorn( @Self, New( PMemo, Init( R, nil, nil, nil, MEMO_BUFFER_SIZE) )));
  Opt   := PCheckBoxes( ShoeHorn( @Self, New( PCheckBoxes, Init( R, nil ))));
  Magic := PInputLine( ShoeHorn( @Self, New( PInputLine, Init( R, ISize ))));
  Replaces := PInputLine( ShoeHorn( @Self, New( PInputLine, Init( R, ISize ))));
  EchoTag := PInputLine( ShoeHorn( @Self, New( PInputLine, Init( R, ISize ))));
  FileName := PInputLine( ShoeHorn( @Self, New( PInputLine, Init( R, ISize ))));
  Memo^.GetBounds( R );
  R.A.X := R.B.X; R.B.X := R.A.X + 1;
  Memo^.VScrollBar := New( PScrollBar, Init(R) );
  Insert( Memo^.VScrollBar );
end; { SetupDialog }

{ HandleEvent --------------------------------------------- }

procedure THatchDialog.HandleEvent( var Event: TEvent );
const
  cmBrowseFile = 200;
  cmSelectArea = 201;
  cmGetDiz     = 202;
begin
  inherited HandleEvent( Event );
  case Event.What of
    evCommand:
      begin
        case Event.Command of
          cmBrowseFile: BrowseFile;
          cmSelectArea: SelectArea;
          cmGetDiz    : GetDiz;
        else
          Exit;
        end;
        ClearEvent( Event );
      end;
  end;
end; { HandleEvent }

{ BrowseFile ---------------------------------------------- }

procedure THatchDialog.BrowseFile;
var
  FName: String;
begin
  FName := '*.*';
  if not ExecFileOpenDlg(LoadString(_SHatchCaption), FName, FName) then Exit;

  if FileExists( FName ) then
    FileName^.SetData( FName )
  else
    ShowError( Format(LoadString(_SFileNotFound), [FName] ));
end; { BrowseFile }

{ SelectArea ---------------------------------------------- }

procedure THatchDialog.SelectArea;
var
  EName: String;
  Echo : PFileEcho;
begin
  OpenFileBase;
  EchoTag^.GetData( EName );
  Echo := FileBase^.GetEcho( EName );
  if SelectFileEcho( Echo ) then
    EchoTag^.SetData( Echo^.Name^ );
end; { SelectArea }

{ GetDiz -------------------------------------------------- }

procedure THatchDialog.GetDiz;
var
  FD: PFileDef;
  NS: LongStr;
  MD: PMemoData;
  N : Word;

  procedure DoSum( P: PString ); far;
  begin
    Inc( N, Length(P^) + 2 );
  end; { DoSum }

  procedure DoCopy( P: PString ); far;
  begin
    Move( P^[1], MD^.Buffer[N], Length(P^) );
    Inc( N, Length(P^) + 2 );
    MD^.Buffer[N-2] := ^M;
    MD^.Buffer[N-1] := ^J;
  end; { DoCopy }

begin
  FileName^.GetData( NS );
  FD := New( PFileDef, Init(ExtractFileName(NS)));
  try
    BuildComment( FD, ExtractFilePath(NS) );
    if FD^.NoComment then
      MessageBox( LoadString(_SGetDizFailed), nil, mfWarning + mfOkButton )
    else
    begin
      N := 0;
      FD^.ForEach( @DoSum );
      GetMem( MD, N + SizeOf(Word) );
      MD^.Length := N;
      N := 0;
      FD^.ForEach( @DoCopy );
      Memo^.SetData( MD^ );
      FreeMem( MD );
    end;
  finally
    Destroy( FD );
  end;
end; { GetDiz }

{ --------------------------------------------------------- }
{ RunHatcher                                                }
{ --------------------------------------------------------- }

procedure RunHatcher;
var
  R: TRect;
  D: PDialog;
  E: PHatchDialog;
  Q: THatchDialogData;
  S: String;
  B: Integer;
  Tic: PTic;
  Ok : Boolean;

{$IFDEF Win32}
var
  ShortName  : String;
  InboundName: String;
{$ENDIF}

  function GetLine( var S: String ) : Boolean;
  var
    j: Word;
    L: Byte absolute S;
  begin
    S := '';
    Result := False;
    if B >= Q.MemoData^.Length then Exit;
    j := ScanR( Q.MemoData^.Buffer, B, Q.MemoData^.Length, #$0d );
    L := j - B;
    Move( Q.MemoData^.Buffer[B], S[1], L );
    B := j + 2;
    Result := True;
  end; { GetLine }

begin
  Log^.Write( ll_Service, LoadString(_SLogStartHatcher) );
  R.Assign( 0, 0, 0, 0 );
  D := PDialog( Res^.Get('HATCH') );
  D^.HelpCtx := hcHatch;
  E := New( PHatchDialog, Init(R, '') );
  SwapDlg( D, E );
  E^.SetupDialog;
  FillChar( Q, SizeOf(Q), 0 );
  Tic := nil;
  try
    if Application^.ExecuteDialog( E, @Q ) = cmOk then
    begin
      New( Tic, Init );

{$IFDEF Win32}
      if VFS_GetShortName( Q.FileName, ShortName ) then
      begin
        InboundName := AtPath( ShortName, CFG^.Inbound );

        if TestBit( Q.Opt, bKillFile ) then
          ok := VFS_MoveFile( Q.FileName, InboundName ) = 0
        else
          ok := VFS_CopyFile( Q.FileName, InboundName );

        if not ok then
          raise Exception.Create( Format(LoadString(_SCantCopyToInbound), [Q.FileName] ));

        MyLib.ReplaceStr( Tic^.FileName, ExtractFileName(InboundName) );
        MyLib.ReplaceStr( Tic^.FullName, ExtractFileName(Q.FileName) );
      end
      else
      begin
{$ENDIF}
        if TestBit( Q.Opt, bKillFile ) then
          ok := VFS_MoveFile( Q.FileName, AtPath(Q.FileName, CFG^.Inbound) ) = 0
        else
          ok := VFS_CopyFile( Q.FileName, AtPath(Q.FileName, CFG^.Inbound) );

        if not ok then
          raise Exception.Create( Format(LoadString(_SCantCopyToInbound), [Q.FileName] ));

        MyLib.ReplaceStr( Tic^.FileName, ExtractFileName(Q.FileName) );
{$IFDEF Win32}
      end;
{$ENDIF}

      with Tic^ do
      begin
        CRC := GetFileCrc( Q.FileName );
        MyLib.ReplaceStr( AreaTag, Q.EchoTag );
        if Q.Magic <> '' then
          MyLib.ReplaceStr( Magic, Q.Magic );
        if Q.Replaces <> '' then
          MyLib.ReplaceStr( Replaces, Q.Replaces );
        B := 0;
        GetLine( S );
        New( LDesc, Init(20, 20) );
        MyLib.ReplaceStr( Desc, S );
        while GetLine( S ) do
          LDesc^.Insert( AllocStr(S) );
        Origin   := CFG^.PrimaryAddr;
        FromAddr := Origin;
        ToAddr   := Origin;
        MyLib.ReplaceStr( Created, 'by ' + SHORT_PID );
        MyLib.ReplaceStr( Pw, CFG^.HatchPw );
        Tic^.SaveTo( BuildTicName(CFG^.PrimaryAddr, CFG^.Inbound), @CFG^.PrimaryAddr );
        Log.Write( ll_Service, Format(LoadString(_SFileHatchOk), [Q.FileName, Q.EchoTag] ));
        if TestBit( Q.Opt, bDelayToss ) then
          MessageBox( LoadString(_STicBuilt), nil, mfInformation + mfOkButton )
        else
        begin
          RunTicTosser;
          MessageBox( LoadString(_SHatchDone), nil, mfInformation + mfOkButton );
        end
      end
    end;
  except
    on E: Exception do
        ShowError( E.Message );
  end;
  if Q.MemoData <> nil then
    FreeMem( Q.MemoData );
  if Tic <> nil then
    Destroy( Tic );
end; { RunHatcher }

end.

