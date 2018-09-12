unit Finder;

/////////////////////////////////////////////////////////////////////
//
// Hi-Files Version 2
// Copyright (c) 1997-2004 Dmitry Liman [2:461/79]
//
// http://hi-files.narod.ru
//
/////////////////////////////////////////////////////////////////////

interface

procedure RunFinder;

{ =================================================================== }

implementation

uses
  Objects, SysUtils, MyLib, _CFG, _LOG, _RES, _FAreas, MsgAPI, _Report, _Script;

{ --------------------------------------------------------- }
{ TMirrorArea                                               }
{ --------------------------------------------------------- }

type
  PMirrorArea = ^TMirrorArea;
  TMirrorArea = object (TFileArea)
    constructor Init( Image: PFileArea );
    procedure FreeItem( Item: Pointer ); virtual;
  end; { TMirrorArea }

{ Init ---------------------------------------------------- }

constructor TMirrorArea.Init( Image: PFileArea );

  procedure CopyPath( P: PString ); far;
  begin
    DL_Path^.Insert( AllocStr(P^) );
  end; { CopyPath }

begin
  inherited Init( Image^.Name^ );
  Image^.DL_Path^.ForEach( @CopyPath );
  fSorted      := Raised;
  fUseAloneCmt := Lowered;
end; { Init }

{ FreeItem ------------------------------------------------ }

procedure TMirrorArea.FreeItem( Item: Pointer );
begin
end; { FreeItem }

{ --------------------------------------------------------- }
{ GenerateAnswer                                            }
{ --------------------------------------------------------- }

procedure GenerateAnswer( IncomingMessage: PPackedMessage; MirrorBase: PFileBase; Poster: PPoster );
var
  Report  : PPktReport;
  SaveBase: PFileBase;
begin
  with Poster do
  begin
    _To   := IncomingMessage^.GetFrom;
    Subj  := IncomingMessage^.GetSubj;
    Reply := IncomingMessage^.GetMsgID;
    Dest  := IncomingMessage^.GetOrig;
  end;
  Log^.Write( ll_Protocol, Format(LoadString(_SLogAnswering), [Poster^.Area]) );
  Log^.Write( ll_Expand, 'From: ' + Poster^._To + ', ' + AddrToStr( Poster^.Dest ) );
  Log^.Write( ll_Expand, 'Subj: ' + Poster^.Subj );
  New( Report, Init(Poster) );
  SaveBase := FileBase;
  FileBase := MirrorBase;
  try
    FileBase^.CalcSummary;
    ExecuteScript( Poster^.Script, Report, Poster );
  finally
    FileBase := SaveBase;
    Destroy( Report );
  end;
end; { GenerateAnswer }


{ --------------------------------------------------------- }
{ SiftPacket                                                }
{ --------------------------------------------------------- }

procedure SiftPacket( const PktName: String );
var
  IncomingPacket: PPacket;
  MirrorBase: PFileBase;
  TheArea   : PFileArea;
  MaskList  : PWildList;
  SubsList  : PStringCollection;

  procedure NewCriteria( S: String );
  var
    j: Integer;
    k: Integer;
    n: Integer;
    T: String;
  begin
    New( MaskList, Init );
    New( SubsList, Init(10, 10) );
    j := 1;
    n := Length( S );
    while j <= n do
    begin
      if S[j] = '"' then
      begin
        T := GetLiterals( S, j, j );
        if Length(T) > 0 then
          SubsList^.Insert( AllocStr(T) );
      end
      else if S[j] <> ' ' then
      begin
        k := ScanR( S[1], j - 1, n, ' ' ) + 1;
        T := Copy( S, j, k - j );
        if Length(T) > 0 then
          MaskList^.Insert( AllocStr(T) );
        j := Succ( k );
      end
      else
        Inc( j );
    end;
  end; { NewCriteria }

  procedure DestroyCriteria;
  begin
    Destroy( MaskList );
    Destroy( SubsList );
    MaskList := nil;
    SubsList := nil;
  end; { DestroyCriteria }

  function MatchCriteria( FD: PFileDef ) : Boolean;
    function SubsMatched( P: PString ) : Boolean; far;
    begin
      Result := FD^.HasSignalString( P );
    end; { SubsMatched }
  begin
    Result := MaskList^.Match( FD^.FileName^ ) or
              (SubsList^.FirstThat( @SubsMatched ) <> nil);
  end; { MatchCriteria }

  procedure AddMirror( FD: PFileDef );
  var
    MirrorArea: PMirrorArea;
  begin
    MirrorArea := PMirrorArea(MirrorBase^.GetArea( TheArea^.Name^ ));
    if MirrorArea = nil then
    begin
      New( MirrorArea, Init(TheArea) );
      MirrorBase^.Insert( MirrorArea );
    end;
    MirrorArea^.Insert( FD );
  end; { AddMirror }

  procedure DoMirrorFile( FD: PFileDef ); far;
  var
    Path: String;
  begin
    if MatchCriteria( FD ) and TheArea^.Locate( FD, Path ) then
      AddMirror( FD );
  end; { DoMirrorFile }

  procedure DoMirrorArea( Area: PFileArea ); far;
  begin
    TheArea := Area;
    Area^.ForEach( @DoMirrorFile );
  end; { DoMirrorArea }

  procedure SiftMessage( IncomingMessage: PPackedMessage ); far;
  var
    Poster: PPoster;

    function MatchedArea( P: PPoster ) : Boolean; far;
    begin
      Result := JustSameText( IncomingMessage^.GetArea, P^.Area );
    end; { MatchedArea }

  begin
    if not CFG^.FinderRobots^.Match( IncomingMessage^.GetTo ) then Exit;
    Poster := CFG^.FinderAreas^.FirstThat( @MatchedArea );
    if Poster = nil then Exit;
    LoadFileBase;
    New( MirrorBase, Init );
    try
      NewCriteria( IncomingMessage^.GetSubj );
      FileBase^.ForEach( @DoMirrorArea );
    except
      on E: Exception do
        Log^.Write( ll_Warning, Format(LoadString(_SLogMsgFailed), [E.Message]));
    end;
    DestroyCriteria;
    if (MirrorBase^.Count > 0) or CFG^.FinderRepAlways then
      GenerateAnswer( IncomingMessage, MirrorBase, Poster );
    Destroy( MirrorBase );
    MirrorBase := nil;
  end; { SiftMessage }

begin
  New( IncomingPacket, Load(PktName) );
  if IncomingPacket = nil then
  begin
    Log^.Write( ll_Warning, Format(LoadString(_SLogPktFailed), [PktName] ));
    Exit;
  end;
  MaskList  := nil;
  SubsList  := nil;
  MirrorBase := nil;
  IncomingPacket^.ForEach( @SiftMessage );
  Destroy( IncomingPacket );
end; { SiftPacket }


{ --------------------------------------------------------- }
{ RunFinder                                                 }
{ --------------------------------------------------------- }

procedure RunFinder;
var
  DosError: Integer;
  PktName : String;
  R: TSearchRec;
begin
  if (CFG^.FinderAreas^.Count * CFG^.FinderRobots^.Count = 0) then Exit;
  Log^.Write( ll_Service, LoadString(_SStartFinder) );
  DosError := FindFirst( AtPath('*.pkt', CFG^.PktIn), faArchive + faReadOnly, R );
  while DosError = 0 do
  begin
    SiftPacket( AtPath(R.Name, CFG^.PktIn) );
    DosError := FindNext( R );
  end;
  FindClose( R );
end; { RunFinder }

end.
