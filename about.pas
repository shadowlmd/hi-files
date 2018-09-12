unit About;

/////////////////////////////////////////////////////////////////////
//
// Hi-Files Version 2
// Copyright (c) 1997-2004 Dmitry Liman [2:461/79]
//
// http://hi-files.narod.ru
//
/////////////////////////////////////////////////////////////////////

interface

procedure ShowAbout;

{ =================================================================== }

implementation

uses
  Objects, Views, Dialogs, Drivers, App, _CFG, _LOG, MyLib, SysUtils, vpSysLow;

type
  PRunFrame = ^TRunFrame;
  TRunFrame = object (TView)
    Phase : Integer;
    Color : Byte;
    constructor Init(var Bounds : TRect; AColor : Byte);
    procedure Draw; virtual;
    procedure Step;
  end { TRunFrame };

{ TRunFrame ------------------------------------------- }

constructor TRunFrame.Init(var Bounds : TRect; AColor : Byte);
begin
  TView.Init(Bounds);
  Color := AColor;
  Phase := 0;
end { Init };

{ Draw ---------------------------------------------------- }

procedure TRunFrame.Draw;
const
  Mark = #254;
var
  n : Integer;
  j : Integer;
  B : TDrawBuffer;
  L : array [0 .. 2 * 80 + 2 * 25] of Boolean;
  C : Byte;
begin
  C := GetColor( Color );
  MoveChar( B, ' ', C, Size.Y );
  WriteBuf( 0, 0, 1, Size.Y, B );
  WriteBuf( Size.X - 1, 0, 1, Size.Y, B );

  MoveChar( B, ' ', C, Size.X );

  if Phase >= Size.X then
    MoveChar( B[Size.X - (Phase-Size.X)], Mark, C, 1 )
  else
    MoveChar( B[Phase], Mark, C, 1 );

  WriteBuf( 0, 0, Size.X, 1, B );
  MoveChar( B, ' ', C, Size.X );

  if Phase >= Size.X then
    MoveChar( B[Phase-Size.X], Mark, C, 1 )
  else
    MoveChar( B[Size.X - Phase], Mark, C, 1 );

  WriteBuf( 0, Size.Y - 1, Size.X, 1, B );
end { Draw };

{ Step ---------------------------------------------------- }

procedure TRunFrame.Step;
begin
  Phase := (Phase + 1) mod (Size.X * 2);
  DrawView;
  Sleep(50);
end { Step };


{ --------------------------------------------------------- }
{ ShowAbout                                                 }
{ --------------------------------------------------------- }

procedure ShowAbout;
var
  R: TRect;
  D: PDialog;
  F: PRunFrame;
  E: TEvent;
  N: Integer;
begin
  R.Assign( 0, 0, 60, 12 );
  D := New( PDialog, Init( R, 'About' ) );
  with D^ do
  begin
    Options := Options or ofCentered;
    Flags   := 0;
    R.Grow( -2, -1 );
    F := New( PRunFrame, Init( R, 3 ));
    Insert( F );
    R.Grow( -1, -1 );
    Insert( New( PStaticText, Init( R,
      ^C + SHORT_PID + ^M^M +
      ^C + COPYRIGHT + ^M^M +
      ^C'http://hi-files.narod.ru'^M^M +
{
      ^C + 'Build #' + IntToStr(BUILD_NO) + ', Compiled on ' + BUILD_TIME + ^M +
}
      ^C + Format( 'Running under %s, ver %d.%d', [SysPlatformName, SysOsVersion and $00FF, SysOsVersion shr 8]  ) + ^M +
      ^C + 'Using log `' + Log^.LogName + ''''
        )));
  end;
  Application^.InsertWindow( D );
  N := 5;
  repeat
    D^.GetEvent( E );
    if E.What = evMouseMove then
    begin
      Dec( N );
      if N > 0 then E.What := evNothing;
    end;
    F^.Step;
  until E.What <> evNothing;
  Destroy( D );
end; { ShowAbout }

end.

