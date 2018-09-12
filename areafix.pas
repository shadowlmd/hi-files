unit AreaFix;

/////////////////////////////////////////////////////////////////////
//
// Hi-Files Version 2
// Copyright (c) 1997-2004 Dmitry Liman [2:461/79]
//
// http://hi-files.narod.ru
//
/////////////////////////////////////////////////////////////////////

interface

procedure RunAreaFix;

{ =================================================================== }

implementation

uses
  Objects, SysUtils, MyLib, _CFG, _LOG, _Res, _FAreas, _Tic, MsgAPI, _MapFile;

{ --------------------------------------------------------- }
{ UnlinkAll                                                 }
{ --------------------------------------------------------- }

procedure UnlinkAll( Echo: PFileEcho; MsgBase: PMsgBase );
var
  todo: PAddrList;

  procedure Copy( A: PAddress ); far;
  var
    j: Integer;
  begin
    if not todo^.Search( A, j ) then
      todo^.AtInsert( j, NewAddr(A^) );
  end; { Copy }

  procedure Unlink( A: PAddress ); far;
  var
    M: PNetmailMessage;
    Link: PEcholink;
  begin
    Link := CFG^.Links^.Find( A^ );
    M := MsgBase^.NewMessage;
    try
      with M^ do
      begin
        SetOrig( Link^.OurAka );
        SetFrom( PROG_NAME );
        SetDest( A^ );
        SetTo  ( 'Allfix' );
        SetSubj( Link^.Password^ );
        case Link^.Flavor of
          fl_Hold : SetAttr( ATTR_LOCAL or ATTR_HOLD );
          fl_Dir  : SetAttr( ATTR_LOCAL or ATTR_DIR );
          fl_Imm  : SetAttr( ATTR_LOCAL or ATTR_IMM );
          fl_Crash: SetAttr( ATTR_LOCAL or ATTR_CRASH );
        end;
        Append( '-' + Echo^.Name^ );
        Append( TEARLINE );
        Save;
      end;
    finally
      Destroy( M );
    end;
  end; { Unlink }

begin
  New( todo, Init(50, 50) );
  with Echo^ do
  begin
    Uplinks^.ForEach( @Copy );
    Uplinks^.FreeAll;
    Downlinks^.ForEach( @Copy );
    Downlinks^.FreeAll;
  end;
  todo^.ForEach( @Unlink );
  Destroy( todo );
end; { UnlinkAll }

{ --------------------------------------------------------- }
{ HandleMessage                                             }
{ --------------------------------------------------------- }

procedure HandleMessage( IM: PNetmailMessage; MsgBase: PMsgBase );
const
  AWAITING_STATE = '  ...awaiting';
  DOWN_STATE     = '  ...down';
var
  OM  : PNetmailMessage;
  Link: PEchoLink;

  procedure SendHelp;
  var
    S: String;
    Map: TMappedFile;
  begin
    if (CFG^.AllfixHelp <> '') and FileExists(CFG^.AllfixHelp) then
    begin
      Log^.Write( ll_Protocol, Format(LoadString(_SLogSendingHelp), [CFG^.AllfixHelp]) );
      Map.Init( CFG^.AllfixHelp );
      while Map.GetLine( S ) do
        OM^.Append( S );
      Map.Done;
    end
    else
    begin
      Log^.Write( ll_Warning, Format(LoadString(_SLogHelpNotAvail), [CFG^.AllfixHelp]));
      OM^.Append( LoadString(_SReplyHelpNotAvail) );
    end;
  end; { SendHelp }

  procedure SendList;
  const
    EMPTY = '-- ';
  var
    j: Integer;
    n: Integer;
    w: Integer;
    S: String;
    Echo: PFileEcho;

    procedure CalcWidth( Echo: PFileEcho ); far;
    begin
      if Length(Echo^.Name^) > w then
        w := Length(Echo^.Name^);
    end; { CalcWidth }

  begin
    Log^.Write( ll_Protocol, LoadString(_SLogSendingEchoList) );
    OpenFileBase;
    w := 0;
    FileBase^.EchoList^.ForEach( @CalcWidth );
    n := 0;
    for j := 0 to Pred( FileBase^.EchoList^.Count ) do
    begin
      Echo := FileBase^.EchoList^.At( j );
      S := EMPTY;
      if Echo^.Downlinks^.IndexOf( @Link^.Addr ) >= 0 then
        S[1] := 'R';
      if Echo^.Uplinks^.IndexOf( @Link^.Addr ) >= 0 then
        S[2] := 'W';
      if S <> EMPTY then Inc( n );
      S := S + Pad(Echo^.Name^, w);
      case Echo^.State of
        es_Awaiting: S := S + AWAITING_STATE;
        es_Down    : S := S + DOWN_STATE;
      end;
      OM^.Append( S );
    end;
    OM^.Append( '' );
    for j := 0 to 5 do
      OM^.Append( LoadString(_SAfixReplyRW + j) );
    OM^.Append( '' );

    OM^.Append( Format(LoadString(_SReplyListFooter),
      [FileBase^.EchoList^.Count, n] ));

    if elo_Pause in Link^.Opt then
      OM^.Append( LoadString(_SPauseWarning) );

  end; { SendList }

  procedure SendQuery;
  const
    EMPTY = '-- ';
  var
    j: Integer;
    n: Integer;
    w: Integer;
    S: String;
    Echo: PFileEcho;

    procedure CalcWidth( Echo: PFileEcho ); far;
    var
      j: Integer;
    begin
      if Echo^.Downlinks^.Search( @Link^.Addr, j ) or Echo^.Uplinks^.Search( @Link^.Addr, j ) then
      begin
        if Length(Echo^.Name^) > w then
          w := Length(Echo^.Name^);
      end;
    end; { CalcWidth }

  begin
    Log^.Write( ll_Protocol, LoadString(_SLogSendingEchoQuery) );
    OpenFileBase;
    w := 0;
    FileBase^.EchoList^.ForEach( @CalcWidth );
    n := 0;
    for j := 0 to Pred( FileBase^.EchoList^.Count ) do
    begin
      Echo := FileBase^.EchoList^.At( j );
      S := EMPTY;
      if Echo^.Downlinks^.IndexOf( @Link^.Addr ) >= 0 then
        S[1] := 'R';
      if Echo^.Uplinks^.IndexOf( @Link^.Addr ) >= 0 then
        S[2] := 'W';
      if S <> EMPTY then
      begin
        Inc( n );
        S := S + Pad(Echo^.Name^, w);
        case Echo^.State of
          es_Awaiting: S := S + AWAITING_STATE;
          es_Down    : S := S + DOWN_STATE;
        end;
        OM^.Append( S );
      end;
    end;

    OM^.Append( '' );
    for j := 0 to 5 do
      OM^.Append( LoadString(_SAfixReplyRW + j) );
    OM^.Append( '' );

    OM^.Append( Format(LoadString(_SReplyQueryFooter), [n] ));

    if elo_Pause in Link^.Opt then
      OM^.Append( LoadString(_SPauseWarning) );

  end; { SendQuery }

  procedure SendAvail;
    procedure Write( P: PString ); far;
    begin
      OM^.Append( P^ );
    end; { Write }
    procedure WriteList( AR: PAvailRec ); far;
    begin
      if not (ao_Inactive in AR^.Opt) and (AR^.List <> nil) then
      begin
        OM^.Append( '' );
        OM^.Append( Format(LoadString(_SReplyAvailFrom), [AddrToStr(AR^.Addr)]) );
        OM^.Append( '' );
        AR^.List^.ForEach( @Write );
        OM^.Append( '' );
      end;
    end; { WriteList }
  begin
    Log^.Write( ll_Protocol, LoadString(_SLogSendingAvail) );
    CFG^.Avail^.LoadAll;
    CFG^.Avail^.ForEach( @WriteList );

    if elo_Pause in Link^.Opt then
      OM^.Append( LoadString(_SPauseWarning) );

  end; { SendAvail }

  procedure SetNotifyMode( const S: String );
  var
    Mode: String;
  begin
    if JustSameText( S, 'On' ) then
    begin
      Include( Link^.Opt, elo_Notify );
      Mode := LoadString( _SModeTurnedOn );
    end
    else if JustSameText( S, 'Off' ) then
    begin
      Exclude( Link^.Opt, elo_Notify );
      Mode := LoadString( _SModeTurnedOff );
    end
    else
    begin
      Log^.Write( ll_Warning, Format(LoadString(_SLogInvalidNotifyCmd), [S] ));
      OM^.Append( LoadString(_SReplyInvalidNotifyCmd) );
      Exit;
    end;
    CFG^.Modified := True;
    OM^.Append( Format(LoadString(_SNotifyChanged), [Mode] ));
  end; { SetNotifyMode }

  procedure ApplyPause;
  var
    S: String;
  begin
    Include( Link^.Opt, elo_Pause );
    S := Format( LoadString(_SPauseChanged), [LoadString(_SModeTurnedOn)] );
    OM^.Append( S );
    Log^.Write( ll_Protocol, S );
    CFG^.Modified := True;
  end; { ApplyPause }

  procedure ApplyResume;
  var
    S: String;
  begin
    Exclude( Link^.Opt, elo_Pause );
    S := Format( LoadString(_SPauseChanged), [LoadString(_SModeTurnedOff)] );
    OM^.Append( S );
    Log^.Write( ll_Protocol, S );
    CFG^.Modified := True;
  end; { ApplyResume }

  procedure MakeStat(const S: String);
  var
    p1, p2 : String;
    Period : Integer;
  begin
{
    SplitPair(S, p1, p2);

    try
      Period := StrToInt(p1);
      if (Period < 1) or (Period > 365) then
        raise Exception.Create;
    except
      on E: Exception do
}
  end; { MakeStat }

  procedure DoCommand( const S: String );
  var
    Key, Par: String;
  begin
    SplitPair( S, Key, Par );
    if JustSameText( Key, '%Help' ) then
      SendHelp
    else if JustSameText( Key, '%List' ) then
      SendList
    else if JustSameText( Key, '%Query' ) then
      SendQuery
    else if JustSameText( Key, '%Avail' ) then
      SendAvail
    else if JustSameText( Key, '%Notify' ) then
      SetNotifyMode( Par )
    else if JustSameText( Key, '%Pause' ) then
      ApplyPause
    else if JustSameText( Key, '%Resume' ) then
      ApplyResume
    else if JustSameText( Key, '%Stat' ) then
      MakeStat( Par )
    else
    begin
      Log^.Write( ll_Warning, Format(LoadString(_SLogInvalidAfixCmd), [Key] ));
      OM^.Append( LoadString(_SReplyInvalidAfixCmd) );
    end;
  end; { DoCommand }

  function LastLink( Echo: PFileEcho ) : Boolean;


  begin
    if Echo^.Downlinks^.Count = 0 then
      Result := True
    else if (Echo^.Downlinks^.Count = 1) and (Echo^.Uplinks^.Count = 1) then
      Result := CompAddr( PAddress(Echo^.Downlinks^.At(0))^,
                          PAddress(Echo^.Uplinks^.At(0))^ ) = 0
    else
      Result := False;
  end; { LastLink }

  procedure Event_UplinksLost( Echo: PFileEcho );
  begin
    Log^.Write( ll_Warning, LoadString(_SLogUplinksLost) );
    Notify( Echo^.Name^, LoadString(_SNotifyWarnSubj), LoadString(_SNotifyUplinksLost) );
    UnlinkAll( Echo, MsgBase );
    FileBase^.EchoList^.Free( Echo );
  end; { Event_UplinksLost }

  procedure Event_DownlinksLost( Echo: PFileEcho );
  begin
    Log^.Write( ll_Warning, LoadString(_SLogDownlinksLost) );
    UnlinkAll( Echo, MsgBase );
    FileBase^.Echolist^.Free( Echo );
  end; { Event_DownlinksLost }

  procedure SubChanged;
  begin
    FileBase^.Modified := True;
    OM^.SetSubj( LoadString(_SSubChangedSubj) );
  end; { SubChanged }

  procedure LinkEcho( Echo: PFileEcho; Action: Char; DontWarn: Boolean );
  var
    j: Integer;
    Wrote: Boolean;
  begin
    if Action = '+' then
    begin
      if Echo^.Downlinks^.Search( @Link^.Addr, j ) then
      begin
        if not DontWarn then
          OM^.Append( Format(LoadString(_SReplyAlreadyDL), [Echo^.Name^] ));
      end
      else if Link^.Deny^.Match( Echo^.Name^ ) then
      begin
        Log^.Write( ll_Warning, Format(LoadString(_SAfixEchoDenied), [Echo^.Name^] ));
        OM^.Append( LoadString(_SEchoDenied) );
      end
      else
      begin
        SubChanged;
        Echo^.Downlinks^.AtInsert( j, NewAddr(Link^.Addr) );
        Log^.Write( ll_Protocol, Format(LoadString(_SLogDLinked), [Echo^.Name^] ));
        OM^.Append( Format(LoadString(_SReplyDLinked), [Echo^.Name^] ));
      end;
    end
    else
    begin
      Wrote := False;
      if Echo^.Downlinks^.Search( @Link^.Addr, j ) then
      begin
        Wrote := True;
        SubChanged;
        Echo^.Downlinks^.AtFree( j );
        Log^.Write( ll_Protocol, Format(LoadString(_SLogDUnlinked), [Echo^.Name^] ));
        OM^.Append( Format(LoadString(_SReplyUnlinked), [Echo^.Name^] ));
        if (Echo^.Area = nil) and LastLink( Echo ) then
        begin
          Event_DownlinksLost( Echo );
          Exit;
        end;
      end;
      if Echo^.Uplinks^.Search( @Link^.Addr, j ) then
      begin
        SubChanged;
        Echo^.Uplinks^.AtFree( j );
        Log^.Write( ll_Protocol, Format(LoadStr(_SLogUUnlinked), [Echo^.Name^] ));
        if not Wrote then
          OM^.Append( Format(LoadString(_SReplyUnlinked), [Echo^.Name^] ));
        if Echo^.Uplinks^.Count = 0 then
          Event_UplinksLost( Echo );
      end;
    end;
  end; { LinkEcho }

  function ResolveForward( const EchoTag: String ) : PFileEcho;
  var
    Uplink: PEchoLink;
    Echo  : PFileEcho;
    UM    : PNetmailMessage;
  begin
    Result := nil;
    Uplink := CFG^.Avail^.FindUplink( EchoTag );
    if Uplink = nil then Exit;
    New( Echo, Init(EchoTag) );
    FileBase^.Echolist^.Insert( Echo );
    FileBase^.Modified := True;
    Result := Echo;
    Echo^.Uplinks^.Insert( NewAddr(Uplink^.Addr) );

    Log^.Write( ll_Service, Format(LoadString(_SLogWriteFwd),
      [AddrToStr(Uplink^.Addr), Echotag] ));

    UM := MsgBase^.NewMessage;

    try
      with UM^ do
      begin
        SetOrig( Uplink^.OurAka );
        SetFrom( PROG_NAME );
        SetDest( Uplink^.Addr );
        SetTo  ( 'Allfix' );
        SetSubj( Uplink^.Password^ );
        case Uplink^.Flavor of
          fl_Hold : SetAttr( ATTR_LOCAL or ATTR_HOLD );
          fl_Dir  : SetAttr( ATTR_LOCAL or ATTR_DIR );
          fl_Imm  : SetAttr( ATTR_LOCAL or ATTR_IMM );
          fl_Crash: SetAttr( ATTR_LOCAL or ATTR_CRASH );
        end;
        Append( '+' + Echotag );
        Append( TEARLINE );
        Save;
      end;
    finally
      Destroy( UM );
    end;
  end; { ResolveForward }

  procedure Subscribe( S: String );
  var
    j: Integer;
    Action: Char;
    Found : Boolean;
    Echo  : PFileEcho;
  begin
    OpenFileBase;
    Action := S[1];
    System.Delete( S, 1, 1 );
    if HasWild( S ) then
    begin
      Found := False;
      for j := 0 to Pred( FileBase^.EchoList^.Count ) do
      begin
        Echo := FileBase^.EchoList^.At( j );
        if WildMatch( Echo^.Name^, S ) then
        begin
          LinkEcho( Echo, Action, True );
          Found := True;
        end;
      end;
      if not Found then
        OM^.Append( LoadString(_SReplyWildNotFound) );
    end
    else
    begin
      Echo := FileBase^.GetEcho( S );
      if Echo = nil then
      begin
        Echo := ResolveForward( S );
        if Echo <> nil then
        begin
          OM^.Append( Format(LoadString(_SReplyReqForw),
            [AddrToStr( PAddress(Echo^.Uplinks^.At(0))^ )] ));
        end;
      end;
      if Echo <> nil then
        LinkEcho( Echo, Action, False )
      else
      begin
        Log^.Write( ll_Warning, Format(LoadString(_SLogNoSuchEcho), [S] ));
        OM^.Append( Format(LoadString(_SReplyNoSuchEcho), [S]));
      end;
    end;
  end; { Subscribe }

  procedure EatLine( S: PString ); far;
  begin
    if (S^ = '') or (S^[1] = ^A) or (Pos('---', S^) = 1) or (Pos(' * Origin: ', S^) = 1) then Exit;
    OM^.Append( '' );
    OM^.Append( '> ' + S^ );
    if S^[1] = '%' then
      DoCommand( S^ )
    else if S^[1] in ['+', '-'] then
      Subscribe( S^ )
    else
      OM^.Append( 'Пpопускаем...' );
  end; { EatLine }

  function OurMessage: Boolean;
  var
    Robot: String;
  begin
    if IM^.Echomail or
       (Link = nil) or
       (CompAddr(IM^.GetDest, Link^.OurAka) <> 0) or
       TestBit(IM^.GetAttr, ATTR_RECVD)
    then
      Result := False
    else
    begin
      Robot := IM^.GetTo;
      Result := CFG^.AfixRobots^.Match( Robot );
    end;
  end; { OurMessage }

begin
  Link := CFG^.Links^.Find( IM^.GetOrig );

  if not OurMessage then Exit;

  OM := nil;
  try
    OM := MsgBase^.NewMessage;
    with OM^ do
    begin
      SetOrig( Link^.OurAka );
      SetFrom( PROG_NAME );
      SetDest( IM^.GetOrig );
      SetTo  ( IM^.GetFrom );
      SetSubj( Format(LoadString(_SYourAfixReqSubj), [IM^.GetTo] ));
      if Cfg^.KillAfixReq then
        SetAttr( ATTR_LOCAL or ATTR_KILLSENT )
      else
        SetAttr( ATTR_LOCAL );
      SetReply( IM^.GetMsgID );
      Append( 'Hi, ' + ExtractWord( 1, IM^.GetFrom, BLANK ) + '!' );
    end;

    Log^.Write( ll_Protocol, Format(LoadString(_SLogAfixReply), [IM^.GetFrom, AddrToStr(IM^.GetOrig)]));
    case Link^.Flavor of
      fl_Hold  : OM^.SetAttr( OM^.GetAttr or ATTR_HOLD );
      fl_Dir   : OM^.SetAttr( OM^.GetAttr or ATTR_DIR );
      fl_Imm   : OM^.SetAttr( OM^.GetAttr or ATTR_IMM );
      fl_Crash : OM^.SetAttr( OM^.GetAttr or ATTR_CRASH );
    end;
    if JustSameText( IM^.GetSubj, Link^.Password^ ) then
      IM^.ForEach( @EatLine )
    else
    begin
      Log^.Write( ll_Warning, Format(LoadString(_SLogWrongAfixPw), [IM^.GetSubj] ));
      OM^.Append( LoadString(_SReplyWrongAfixPw));
    end;
    with OM^ do
    begin
      Append( '' );
      Append( TEARLINE );
      Save;
    end;
  finally
    if CFG^.KillAfixReq then
      IM^.Kill
    else
    begin
      IM^.SetAttr( IM^.GetAttr or ATTR_RECVD );
      IM^.Save;
    end;
    Destroy( OM );
  end;
end; { HandleMessage }


{ --------------------------------------------------------- }
{ RunAreaFix                                                }
{ --------------------------------------------------------- }

procedure RunAreaFix;
var
  Message: PNetmailMessage;
  MsgBase: PMsgBase;
begin
  Log^.Write( ll_Service, LoadString(_SLogStartAfix) );
  MsgBase := nil;
  try
    New( MsgBase, Init(CFG^.Netmail) );
    MsgBase^.SetPID( SHORT_PID );
    MsgBase^.SeekFirst;
    while MsgBase^.SeekFound do
    begin
      Message := nil;
      try
        Message := MsgBase^.GetMessage;
        HandleMessage( Message, MsgBase );
      finally
        Destroy( Message );
      end;
      MsgBase^.SeekNext;
    end;
  finally
    Destroy( MsgBase );
  end;
  Log^.Write( ll_Service, LoadString(_SLogStopAfix) );
end; { RunAreaFix }

end.
