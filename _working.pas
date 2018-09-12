unit _Working;

/////////////////////////////////////////////////////////////////////
//
// Hi-Files Version 2
// Copyright (c) 1997-2004 Dmitry Liman [2:461/79]
//
// http://hi-files.narod.ru
//
/////////////////////////////////////////////////////////////////////

interface

uses Objects, Views;

type
  PProgress = ^TProgress;
  TProgress = object (TView)
    Max : Integer;
    Pos : Integer;

    constructor Init( var Bounds : TRect; aMax : Longint );
    procedure Draw; virtual;
    procedure Update( NewPos: Longint );
    procedure Reset( aMax, aPos: Longint );
  end { TProgress };

procedure OpenWorking( Text: String );
procedure OpenProgress( MaxValue: Integer );
procedure UpdateProgress( CurValue: Integer );
procedure CloseWorking;

{ ========================================================= }

implementation

uses
  Drivers, Dialogs, App, Menus, MyLib;

type
  PWorkLine = ^TWorkLine;
  TWorkLine = object (TStaticText)
    constructor Init( const Msg: String );
    destructor Done; virtual;
    function GetPalette: PPalette; virtual;
  private
    Progress: PProgress;
  end; { TWorkLine }

{ Init ---------------------------------------------------- }

constructor TWorkLine.Init( const Msg: String );
var
  R: TRect;
begin
  StatusLine^.GetBounds( R );
  inherited Init( R, ' ' + Msg );
  Progress := nil;
end; { Init }

{ Done ---------------------------------------------------- }

destructor TWorkLine.Done;
begin
  Destroy( Progress );
  inherited Done;
end; { Done }

{ GetPalette ---------------------------------------------- }

function TWorkLine.GetPalette: PPalette;
const
  P: String[Length(CStatusLine)] = CStatusLine;
begin
  GetPalette := @P;
end; { GetPalette }

{ --------------------------------------------------------- }
{ OpenWorking                                               }
{ --------------------------------------------------------- }

procedure OpenWorking( Text: String );
begin
  Application^.Insert( New( PWorkLine, Init( Text ) ));
end; { OpenWorking }

{ --------------------------------------------------------- }
{ TopWorking                                                }
{ --------------------------------------------------------- }

function TopWorking: PWorkLine;

function Match( V: PView ) : Boolean; far;
begin
  Match := TypeOf(V^) = TypeOf(TWorkLine);
end; { Match }

begin
  Result := PWorkLine( Application^.FirstThat( @Match ) );
end; { TopWorking }

{ --------------------------------------------------------- }
{ CloseWorking                                              }
{ --------------------------------------------------------- }

procedure CloseWorking;
begin
  Destroy( TopWorking );
end; { CloseWorking }

{ --------------------------------------------------------- }
{ OpenProgress                                              }
{ --------------------------------------------------------- }

procedure OpenProgress( MaxValue: Integer );
var
  R: TRect;
  W: PWorkLine;
begin
  W := TopWorking;
  if W <> nil then
  begin
    W^.GetBounds( R );
    R.A.X := R.B.X - 10;
    W^.Progress := New( PProgress, Init( R, MaxValue ) );
    Application^.Insert( W^.Progress );
  end;
end; { OpenProgress }

{ --------------------------------------------------------- }
{ UpdateProgress                                            }
{ --------------------------------------------------------- }

procedure UpdateProgress( CurValue: Integer );
var
  W: PWorkLine;
begin
  W := TopWorking;
  if (W <> nil) and (W^.Progress <> nil) then
    W^.Progress^.Update( CurValue );
end; { UpdateProgress }


{ --------------------------------------------------------- }
{ TProgress                                                 }
{ --------------------------------------------------------- }

constructor TProgress.Init( var Bounds : TRect; aMax : Longint );
begin
  inherited Init( Bounds );
  Max := aMax;
  Pos := 0;
end; { Init }

{ Draw ---------------------------------------------------- }

procedure TProgress.Draw;
var
  B : TDrawBuffer;
  C : Byte;
  L : Word;
begin
  C := GetColor(14);
  L := Pos div 2;
  MoveChar(B, ' ', C, Size.X);
  MoveChar(B, 'Û', C, L);
  if Odd(Pos) then
    MoveChar(B[L], 'Ý', C, 1);
  WriteLine(0, 0, Size.X, Size.Y, B);
end; { Draw }

{ Update -------------------------------------------------- }

procedure TProgress.Update( NewPos : Longint );
var
  Current: Integer;
begin
  if Max = 0 then
    Current := 0
  else
    Current := Round((NewPos / Max) * Size.X * 2);
  if Current <> Pos then
  begin
    Pos := Current;
    DrawView;
    Application^.Idle;
  end;
end; { Update }

{ Reset --------------------------------------------------- }

procedure TProgress.Reset( aMax, aPos: Longint );
begin
  Max := aMax;
  Pos := -1;
  Update( aPos );
end; { Reset }

end.
