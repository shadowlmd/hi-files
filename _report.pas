unit _Report;

/////////////////////////////////////////////////////////////////////
//
// Hi-Files Version 2
// Copyright (c) 1997-2004 Dmitry Liman [2:461/79]
//
// http://hi-files.narod.ru
//
/////////////////////////////////////////////////////////////////////

interface

uses Objects, MsgAPI, _CFG;

type
  PReport = ^TReport;
  TReport = object (TObject)
    procedure WriteOut( S: String ); virtual;
    procedure Cancel; virtual;
    procedure Redirect( FileName: String ); virtual;
  end; { TReport }

  PTextReport = ^TTextReport;
  TTextReport = object (TReport)
    constructor Init( const FileName: String );
    destructor Done; virtual;
    procedure WriteOut( S: String ); virtual;
    procedure Cancel; virtual;
    procedure Redirect( FileName: String ); virtual;
  private
    Stream: TBufStream;
  end; { TTextReport }

  PPktReport = ^TPktReport;
  TPktReport = object (TReport)
    constructor Init( Poster: PPoster );
    destructor  Done; virtual;
    procedure   WriteOut( S: String ); virtual;
    procedure   Cancel; virtual;
  private
    Pkt: PPacket;
    Msg: PPackedMessage;
  end; { TPktReport }

procedure WriteChangedLogo( Report: PReport );

{ =================================================================== }

implementation

uses SysUtils, MyLib, _Res;

{ --------------------------------------------------------- }
{ TReport                                                   }
{ --------------------------------------------------------- }

{ WriteOut ------------------------------------------------ }

procedure TReport.WriteOut( S: String );
begin
  Abstract;
end; { WriteOut }

{ Cancel -------------------------------------------------- }

procedure TReport.Cancel;
begin
  Abstract;
end; { Cancel }

{ Redirect ------------------------------------------------ }

procedure TReport.Redirect( FileName: String );
begin
end; { Redirect }

{ --------------------------------------------------------- }
{ TTextReport                                               }
{ --------------------------------------------------------- }

{ Init ---------------------------------------------------- }

constructor TTextReport.Init( const FileName: String );
begin
  inherited Init;
  Stream.Init( FileName, stCreate, 2048 );
  if Stream.Status <> stOk then
    raise Exception.Create( Format(LoadString(_SCantCreateRep), [FileName] ));
end; { Init }

{ Done ---------------------------------------------------- }

destructor TTextReport.Done;
begin
  Stream.Done;
  inherited Done;
end; { Done }

{ WriteOut ------------------------------------------------ }

procedure TTextReport.WriteOut( S: String );
const
  CRLF: array [0..1] of char = ^M^J;
begin
  Stream.Write( S[1], Length(S) );
  Stream.Write( CRLF, 2 );
end; { WriteOut }

{ Cancel -------------------------------------------------- }

procedure TTextReport.Cancel;
begin
  WriteOut( '' );
  WriteOut( LoadString(_SCancelled) );
end; { Cancel }

{ Redirect ------------------------------------------------ }

procedure TTextReport.Redirect( FileName: String );
begin
  Stream.Done;
  Stream.Init( FileName, stCreate, 2048 );
  if Stream.Status <> stOk then
    raise Exception.Create( Format(LoadString(_SCantCreateRep), [FileName] ));
end; { Redirect }

{ --------------------------------------------------------- }
{ TPktReport                                                }
{ --------------------------------------------------------- }

{ Init ---------------------------------------------------- }

constructor TPktReport.Init( Poster: PPoster );
begin
  inherited Init;
  New( Pkt, Init( CFG^.RobotAddr, CFG^.PrimaryAddr, CFG^.PktOut ) );
  New( Msg, Init );
  with Msg^ do
  begin
    SetArea ( Poster^.Area );
    SetFrom ( Poster^._From );
    SetTo   ( Poster^._To );
    SetOrig ( Poster^.Orig );
    if CompAddr( Poster^.Dest, ZERO_ADDR ) = 0 then
      SetDest( Cfg^.PrimaryAddr )
    else
      SetDest ( Poster^.Dest );
    SetSubj ( Poster^.Subj );
    SetReply( Poster^.Reply );
    SetAttr ( ATTR_LOCAL );
    SetFlags( 'NPD' );
    SetPID( SHORT_PID );
  end;
  Pkt^.SetPassword( CFG^.PktPassword );
  Pkt^.AddMessage( Msg );
end; { Init }

{ Done ---------------------------------------------------- }

destructor TPktReport.Done;
begin
  if Pkt <> nil then
  begin
    Pkt^.Save;
    Destroy( Pkt );
  end;
  inherited Done;
end; { Done }

{ WriteOut ------------------------------------------------ }

procedure TPktReport.WriteOut( S: String );
var
  j: Integer;
begin
{
  for j := 1 to Length(S) do
    case S[j] of
      #141: S[j] := 'H';
      #224: S[j] := 'p';
    end;
}
  Msg^.Append( S );
end; { WriteOut }

{ Cancel -------------------------------------------------- }

procedure TPktReport.Cancel;
begin
  Destroy( Pkt );
  Pkt := nil;
end; { Cancel }


{ --------------------------------------------------------- }
{ WriteChangedLogo                                          }
{ --------------------------------------------------------- }

procedure WriteChangedLogo( Report: PReport );
begin
  with Report^ do
  begin
    WriteOut( ';' );
    WriteOut( '; This file was created by ' + PROG_NAME + ' ' + PROG_VER );
    WriteOut( '; ' + DateTimeToStr( Now ) );
    WriteOut( ';' );
  end;
end; { WriteChangedLogo }


end.

