unit _LOG;

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

type
  TLogLevel = (
    ll_Debug,                // Сообщения камеpы слежения .)
    ll_Protocol,             // Пpотокол pаботы служб
    ll_Expand,               // Дополнительные стpоки
    ll_Service,              // Обpащения к службам
    ll_Warning,              // Пpедупpеждения
    ll_Error,                // Восстановимая ошибка
    ll_UnrecoverableError,   // Невосстановимая ошибка
    ll_FatalError );         // Фатальная ошибка

  PLog = ^TLog;
  TLog = object (TCollection)
    constructor Init( i_am_paranoic: Boolean );
    destructor Done; virtual;
    procedure FreeItem( Item: Pointer ); virtual;
    procedure Write( Level: TLogLevel; const Message: String );
    procedure WriteEx( Level: TLogLevel; const FileName: String;
      LineNo: Integer; const Line: String; const Message: String );
    function HasWarnings: Boolean;
    function HasErrors: Boolean;
    procedure Clear;
  public
    LogName  : String;
  private
    Paranoia : Boolean;
    LogFile  : Text;
    MaxLevel : TLogLevel;
    Expanding: Boolean;
  end; { TLog }

procedure ShowLog;

procedure ShowError( const Message: String );

var
  Log: PLog;

{ =================================================================== }

implementation

uses
  Dos, MyLib, SysUtils, _CFG, _Res, App, Views, Drivers, MsgBox;

type
  PLogView = ^TLogView;
  TLogView = object (TScroller)
    procedure NewList( aList: PLog );
    procedure Draw; virtual;
    procedure LogChanged;
    destructor Done; virtual;
  private
    List: PLog;
    procedure UpdateLimit;
  end; { TLogViewer }

const
  LogViewer: PLogView = nil;

{ --------------------------------------------------------- }
{ TLog                                                      }
{ --------------------------------------------------------- }

type
  TLogPrefix = array [TLogLevel] of String[5];
const
  LogPrefix : TLogPrefix = (
    '.....',
    '  ',
    '> ',
    '* ',
    '? ',
    '! ',
    '!!',
    '!@#$%' );

{ Init ---------------------------------------------------- }

constructor TLog.Init( i_am_paranoic: Boolean );
var
  LogPath: String;
begin
  inherited Init( 50, 50 );
  Paranoia := i_am_paranoic;

  LogName  := ChangeFileExt( ParamStr(0), '.Log' );
  LogPath  := GetEnv( 'LOG_PATH' );
  if LogPath <> '' then
    LogName := AtPath( LogName, LogPath );

  Assign( LogFile, LogName );
  try
    Append( LogFile );
  except
    Rewrite( LogFile );
  end;
  Writeln( LogFile,
    ^M^J + PadCh( CharStr( #176, 10 ) + ' Date: ' + DateToStr(Now) +
    '; Time: ' + TimeToStr(Now) + ' ', 70, #176 ) + ^M^J +
    ^M^J#4#32 + PROG_NAME + ' ' + PROG_VER + ' ' + PLATFORM + ' started' );
  if Paranoia then Close( LogFile );
end; { Init }

{ Done ---------------------------------------------------- }

destructor TLog.Done;
begin
  if Paranoia then Append( LogFile );
  Writeln( LogFile, #4#32 + PROG_NAME + ' finished at ' + TimeToStr(Now) );
  Close( LogFile );
  inherited Done;
end; { Done }

{ FreeItem ------------------------------------------------ }

procedure TLog.FreeItem( Item: Pointer );
begin
  FreeStr( PString(Item) );
end; { FreeItem }

{ Write --------------------------------------------------- }

procedure TLog.Write( Level: TLogLevel; const Message: String );
begin
  if Level > MaxLevel then
    MaxLevel := Level;
  if Paranoia then
    Append( LogFile );
  Writeln( LogFile, LogPrefix[Level] + Message );
  if Paranoia then
    Close( LogFile );
  if Level >= ll_Warning then
  begin
    Insert( AllocStr( LogPrefix[Level] + Message ) );
    if LogViewer <> nil then
      LogViewer^.LogChanged;
  end;
end; { Write }

{ WriteEx ------------------------------------------------- }

procedure TLog.WriteEx( Level: TLogLevel; const FileName: String;
  LineNo: Integer; const Line: String; const Message: String );
begin
  Write( Level, FileName + ' (' + IntToStr(LineNo) + ') ' + Message );
    Write( ll_Expand, Line );
end; { WriteEx }

{ HasWarnings --------------------------------------------- }

function TLog.HasWarnings: Boolean;
begin
  HasWarnings := (MaxLevel >= ll_Warning);
end; { HasWarnings }

{ HasErrors ----------------------------------------------- }

function TLog.HasErrors: Boolean;
begin
  HasErrors := (MaxLevel >= ll_Error );
end; { HasErrors }

{ Clear --------------------------------------------------- }

procedure TLog.Clear;
begin
  FreeAll;
  MaxLevel := TLogLevel(0);
end; { Clear }

{ --------------------------------------------------------- }
{ TLogView                                                  }
{ --------------------------------------------------------- }

{ Done ---------------------------------------------------- }

destructor TLogView.Done;
begin
  LogViewer := nil;
  List^.MaxLevel := Low(TLogLevel);
  inherited Done;
end; { Done }

{ LogChanged ---------------------------------------------- }

procedure TLogView.LogChanged;
begin
  UpdateLimit;
end; { LogChanged }

{ UpdateLimit --------------------------------------------- }

procedure TLogView.UpdateLimit;

  function MaxWidth: Integer;
  var
    j: Integer;
    l: Integer;
  begin
    Result := 0;
    for j := 0 to List^.Count - 1 do
    begin
      l := Length( PString(List^.At(j))^ );
      if l > Result then
        Result := l;
    end;
  end; { MaxWidth }

begin
  if List <> nil then
  begin
    SetLimit( MaxWidth, List^.Count );
    ScrollTo( 0, Limit.Y );
  end
  else
    SetLimit( 0, 0 );
end; { UpdateLimit }

{ NewList ------------------------------------------------- }

procedure TLogView.NewList( aList: PLog );
begin
  if List <> nil then
  begin
    Dispose( List, Done );
    List := nil;
  end;
  List := aList;
  UpdateLimit;
end; { NewList }

{ Draw ---------------------------------------------------- }

procedure TLogView.Draw;
var
  B: TDrawBuffer;
  C: Byte;
  j: Integer;
  S: String;

  function GetLine( n: Integer; Offs, Size: Integer ) : String;
  var
    p: String;
  begin
    p := PString(List^.At(n))^;
    if Offs > Length(S) then
      Result := ''
    else
      Result := Copy( p, Offs, Size );
  end; { GetLine }

begin
  C := GetColor(1);
  for j := 0 to Size.Y - 1 do
  begin
    MoveChar( B, ' ', C, Size.X );
    if Delta.Y + j < Limit.Y then
    begin
      S := GetLine( Delta.Y + j, Delta.X, Size.X );
      MoveStr( B, S, C );
    end;
    WriteLine( 0, j, Size.X, 1, B );
  end;
end; { Draw }


{ --------------------------------------------------------- }
{ ShowLog                                                   }
{ --------------------------------------------------------- }

procedure ShowLog;
var
  R: TRect;
  W: PWindow;
  V: PLogView;
begin
  if LogViewer <> nil then Exit;
  Desktop^.GetExtent( R );
  R.A.Y := R.B.Y - 10;
  W := New( PWindow, Init( R, LoadString(_SMsgWinCaption), wnNoNumber ));
  W^.Palette := wpCyanWindow;
  W^.Options := W^.Options + ofTileable;
  W^.GetExtent( R );
  R.Grow(-1, -1);
  V := New( PLogView,
         Init( R, W^.StandardScrollBar(sbHorizontal + sbHandleKeyboard),
                  W^.StandardScrollBar(sbVertical + sbHandleKeyboard)
             ));
  V^.GrowMode := gfGrowHiX + gfGrowHiY;
  V^.NewList( Log );
  W^.Insert( V );
  Desktop^.Insert( W );
  LogViewer := V;
end; { ShowLog }


{ --------------------------------------------------------- }
{ ShowError                                                 }
{ --------------------------------------------------------- }

procedure ShowError( const Message: String );
begin
  if not CFG^.BatchMode then
    MessageBox( Message, nil, mfError + mfOkButton );
  Log^.Write( ll_Error, Message );
end; { ShowError }

end.

