unit _Inspector;

/////////////////////////////////////////////////////////////////////
//
// Hi-Files Version 2
// Copyright (c) 1997-2004 Dmitry Liman [2:461/79]
//
// http://hi-files.narod.ru
//
/////////////////////////////////////////////////////////////////////

interface

uses Objects, Dialogs, Drivers, _Working;

type
  PInspector = ^TInspector;
  TInspector = object (TDialog)
    constructor Init( const ScriptName: String );
    procedure Update( ANo, FNo: Integer );
    procedure UpdateExec( S: PString );
    procedure HandleEvent( var Event: TEvent ); virtual;
    function  QueryCancel: Boolean;
  private
    AreaName  : PParamText;
    FileName  : PParamText;
    ExecLine  : PParamText;
    AreaRoller: PProgress;
    FileRoller: PProgress;
    AreaPtr   : PString;
    FilePtr   : PString;
    ExecPtr   : PString;
    AreaStr   : String;
    FileStr   : String;
    ExecStr   : String;
    AreaNo    : Integer;
    AloneText : String;
    Cancelled : Boolean;
  end; { TInspector }

{ =================================================================== }

implementation

uses
  MyLib, App, Views, MsgBox, _Fareas, _Log, _RES;

{ --------------------------------------------------------- }
{ TInspector                                                }
{ --------------------------------------------------------- }

{ Init ---------------------------------------------------- }

constructor TInspector.Init( const ScriptName: String );
var
  R: TRect;
  B: PButton;
begin
  R.Assign( 0, 0, 50, 12 );
  inherited Init( R, ScriptName );
  Options := Options or ofCentered;
  Flags   := 0;
  R.Grow( -2, -2 ); R.B.Y := Succ( R.A.Y );
  AreaName := New( PParamText, Init( R, '%s', 1 ) );
  Insert( AreaName );
  R.Move( 0, 1 );
  AreaRoller := New( PProgress, Init( R, FileBase^.Count ) );
  Insert( AreaRoller );
  R.Move( 0, 2 );
  FileName := New( PParamText, Init( R, '%s', 1 ) );
  Insert( FileName );
  R.Move( 0, 1 );
  FileRoller := New( PProgress, Init( R, 1 ) );
  Insert( FileRoller );
  R.Move( 0, 1 );
  ExecLine := New( PParamText, Init( R, '%s', 1 ) );
  Insert( ExecLine );
  R.Move( 0, 2 ); Inc(R.B.Y); R.B.X := R.A.X + 20;
  B := New( PButton, Init( R, LoadString(_SCancelBtn), cmCancel, bfNormal ) );
  B^.Options := B^.Options or ofCenterX;
  Insert( B );
  AreaNo := -1;
  AreaPtr := @AreaStr;
  FilePtr := @FileStr;
  ExecPtr := @ExecStr;
  AreaName^.SetData( AreaPtr );
  FileName^.SetData( FilePtr );
  ExecLine^.SetData( ExecPtr );
  AloneText := LoadString( _SAloneText );
end; { Init }

{ Update -------------------------------------------------- }

procedure TInspector.Update( ANo, FNo: Integer );
var
  Area: PFileArea;
  FD  : PFileDef;
begin
  if ANo <> AreaNo then
  begin
    AreaNo  := ANo;
    Area    := FileBase^.At( ANo );
    AreaStr := ^C + Area^.Name^;
    AreaName^.DrawView;
    AreaRoller^.Update( ANo + 1 );
    FileRoller^.Reset( Area^.Count, 0 );
  end
  else
    Area := FileBase^.At( ANo );
  if FNo >= 0 then
  begin
    FD := Area^.At( FNo );
    if FD^.AloneCmt then
      FileStr := ^C + AloneText
    else
      FileStr := ^C + FD^.NativeName^;
  end
  else
    FileStr := '';
  FileName^.DrawView;
  FileRoller^.Update( FNo + 1 );
end; { Update }

{ UpdateExec ---------------------------------------------- }

procedure TInspector.UpdateExec( S: PString );
begin
  ExecStr := S^;
  ExecLine^.DrawView;
end; { UpdateExec }

{ HandleEvent --------------------------------------------- }

procedure TInspector.HandleEvent( var Event: TEvent );
begin
  inherited HandleEvent( Event );
  case Event.What of
    evCommand:
      begin
        case Event.Command of
          cmCancel:
            if MessageBox( LoadString(_SConfirmCancel), nil, mfConfirmation + mfYesNoCancel ) = cmYes then
              Cancelled := True;
        else
          Exit;
        end;
        ClearEvent( Event );
      end;
  end;
end; { HandleEvent }

{ QueryCancel --------------------------------------------- }

function TInspector.QueryCancel: Boolean;
var
  E: TEvent;
begin
  GetEvent( E );
  HandleEvent( E );
  Result := Cancelled;
end; { QueryCancel }

end.

