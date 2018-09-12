unit _BSY;

/////////////////////////////////////////////////////////////////////
//
// Hi-Files Version 2
// Copyright (c) 1997-2004 Dmitry Liman [2:461/79]
//
// http://hi-files.narod.ru
//
/////////////////////////////////////////////////////////////////////


interface

function SetBusyFlag: Boolean;
procedure DropBusyFlag;

{ =================================================================== }

implementation

uses
  Views, Dialogs, Drivers, _Working, Objects, App, MsgBox,
  SysUtils, MyLib, _RES, HiFiHelp;

const
  BUSY_EXT   = '.bsy';
  WAIT_DELAY  = 30;
  RIP_TIMEOUT = 30 * 60; // 30 min

type
  PWaiting = ^TWaiting;
  TWaiting = object (TDialog)
    constructor Init( const aBusyFlag: String; aWaitDelay : Integer );
    procedure GetEvent( var Event: TEvent ); virtual;
    procedure HandleEvent( var Event: TEvent ); virtual;
  private
    Started: UnixTime;
    Delayed: UnixTime;
    TimeOut: UnixTime;
    ProgBar: PProgress;
    BusyFlag : String;
    function BusyFlagDied: Boolean;
  end; { TWaiting }

const
  cmKillBusyFlag = 1000;

{ --------------------------------------------------------- }
{ TWaiting                                                  }
{ --------------------------------------------------------- }

constructor TWaiting.Init( const aBusyFlag: String; aWaitDelay : Integer );
var
  R: TRect;
begin
  R.Assign( 0, 0, 46, 9 );
  inherited Init( R, LoadString(_SBusyCaption));
  Options   := Options or ofCentered;
  BusyFlag  := aBusyFlag;
  Started   := CurrentUnixTime;
  TimeOut   := Started + aWaitDelay;
  R.Grow( -2, -2 );
  R.B.Y := R.A.Y + 2;
  Insert( New( PStaticText, Init( R, ^C + LoadString(_SBusyMsg1) + ^M^J^C + LoadString(_SBusyMsg2) )));
  R.Move( 0, 2 ); R.B.Y := Succ( R.A.Y );
  ProgBar := New( PProgress, Init( R, aWaitDelay ) );
  Insert( ProgBar );
  R.Move( 0, 2 ); Inc( R.B.Y ); R.B.X := R.A.X + 20;
  Insert( New( PButton, Init( R, LoadString(_SKillFlagBtn), cmKillBusyFlag, bfNormal )));
  R.Move( 22, 0 );
  Insert( New( PButton, Init( R, LoadString(_SExitBtn), cmCancel, bfNormal )));
  SelectNext( False );
  HelpCtx := hcBusyWaiting;
end; { Init }

{ --------------------------------------------------------- }
{ GetEvent                                                  }
{ --------------------------------------------------------- }

procedure TWaiting.GetEvent( var Event: TEvent );
var
  d: UnixTime;
begin
  d := CurrentUnixTime;
  if d <> Delayed then
  begin
    Delayed := d;
    ProgBar^.Update( Delayed - Started );
    if not FileExists( BusyFlag ) then
    begin
      Event.What := evCommand;
      Event.Command := cmOk;
      Exit;
    end;
    if Delayed >= TimeOut then
    begin
      Event.What := evCommand;
      Event.Command := cmCancel;
      Exit;
    end;
  end;
  inherited GetEvent( Event );
end; { GetEvent }


{ --------------------------------------------------------- }
{ BusyFlagDied                                              }
{ --------------------------------------------------------- }

function TWaiting.BusyFlagDied: Boolean;
begin
  Result := VFS_EraseFile( BusyFlag );
  if not Result then
    MessageBox( Format(LoadString(_SCantKillFlag), [BusyFlag]), nil,
    mfWarning + mfOkButton );
end; { BusyFlagDied }


{ --------------------------------------------------------- }
{ HandleEvent                                               }
{ --------------------------------------------------------- }

procedure TWaiting.HandleEvent( var Event: TEvent );
begin
  inherited HandleEvent( Event );
  case Event.What of
    evCommand:
      begin
        case Event.Command of
          cmKillBusyFlag:
            if BusyFlagDied then
              EndModal( cmOk );
        end;
        ClearEvent( Event );
      end;
  end;
end; { HandleEvent }


{ --------------------------------------------------------- }
{ StillAlive                                                }
{ --------------------------------------------------------- }

function StillAlive( const FileName: String; WaitDelay: Integer ) : Boolean;
var
  D: PDialog;
begin
  if (CurrentUnixTime - FileTimeToUnix( FileAge( FileName ) ) < RIP_TIMEOUT) or
     not VFS_EraseFile( FileName ) then
  begin
    OpenWorking( LoadString(_SWaiting) );
    D := New( PWaiting, Init( FileName, WaitDelay ) );
    Result := Application^.ExecView( D ) <> cmOk;
    D^.Free;
    CloseWorking;
  end
  else
    Result := False;
end; { StillAlive }


{ --------------------------------------------------------- }
{ CreateFlag                                                }
{ --------------------------------------------------------- }

function CreateFlag( const Flag: String ) : Boolean;
var
  h: Integer;
begin
  Result := True;
  h := FileCreate( Flag );
  if h > 0 then
    FileClose( h )
  else
    Result := False;
end; { CreateFlag }


{ --------------------------------------------------------- }
{ SetBusyFlag                                               }
{ --------------------------------------------------------- }

function SetBusyFlag: Boolean;
var
  Busy: String;
begin
  Result := False;
  Busy := ChangeFileExt( ParamStr(0), BUSY_EXT );
  if FileExists( Busy ) and StillAlive( Busy, WAIT_DELAY ) then Exit;
  Result := CreateFlag( Busy );
end; { SetBusyFlag }


{ --------------------------------------------------------- }
{ DropBusyFlag                                              }
{ --------------------------------------------------------- }

procedure DropBusyFlag;
begin
  VFS_EraseFile( ChangeFileExt( ParamStr(0), BUSY_EXT ) );
end; { DropBusyFlag }

end.
