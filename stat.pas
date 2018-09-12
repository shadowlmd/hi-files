program Stat;

uses Objects, SysUtils, Mylib;

type
  SWORD = SmallWord;
  DWORD = Word;

  PAddress = ^TAddress;
  TAddress = record
    Zone, Net, Node, Point: SWORD;
  end; { TAddress }


  PEcho = ^TEcho;
  TEcho = record
    Tag  : PString;
    Files: Longint;
    Bytes: Longint;
  end; { TEcho }

  PCounter = ^TCounter;
  TCounter = object (TSortedCollection)
    procedure FreeItem(Item: Pointer); virtual;
    function KeyOf(Item: Pointer) : Pointer; virtual;
    function Compare(Key1, Key2: Pointer) : Integer; virtual;
  end; { TCounter }

const
  _ZERO_ADDR : TAddress = (Zone: 0; Net: 0; Node: 0; Point: 0);



{ --------------------------------------------------------- }
{ AddrToStr                                                 }
{ --------------------------------------------------------- }

function AddrToStr( A: TAddress ) : String;
begin
  with A do
  begin
    Result := IntToStr(Zone) + ':' + IntToStr(Net) + '/' + IntToStr(Node);
    if Point <> 0 then
      Result := Result + '.' + IntToStr(Point);
  end;
end; { AddrToStr }

{ --------------------------------------------------------- }
{ CompAddr                                                  }
{ --------------------------------------------------------- }

function CompAddr( const A1, A2: TAddress ) : Integer;
begin
  if A1.Zone < A2.Zone then
    Result := -1
  else if A1.Zone > A2.Zone then
    Result := 1
  else if A1.Net < A2.Net then
    Result := -1
  else if A1.Net > A2.Net then
    Result := 1
  else if A1.Node < A2.Node then
    Result := -1
  else if A1.Node > A2.Node then
    Result := 1
  else if A1.Point < A2.Point then
    Result := -1
  else if A1.Point > A2.Point then
    Result := 1
  else
    Result := 0;
end; { CompAddr }


/////////////////////////////////////////////////////////////////////
//
// TCounter
//

{ ---------------------------------------------------------- }
{ FreeItem                                                   }
{ ---------------------------------------------------------- }

procedure TCounter.FreeItem(Item: Pointer);
begin
  FreeStr(PEcho(Item)^.Tag);
  Dispose(Item);
end; { FreeItem }

{ --------------------------------------------------------- }
{ KeyOf                                                     }
{ --------------------------------------------------------- }

function TCounter.KeyOf(Item: Pointer) : Pointer;
begin
  Result := PEcho(Item)^.Tag;
end; { KeyOf }

{ --------------------------------------------------------- }
{ Compare                                                   }
{ --------------------------------------------------------- }

function TCounter.Compare(Key1, Key2: Pointer) : Integer;
begin
  Result := JustCompareText(PString(Key1)^, PString(Key2)^);
end; { Compare }

//
//
/////////////////////////////////////////////////////////////////////


/////////////////////////////////////////////////////////////////////
//
// TUplinks
//

type
  PUplinkInfo = ^TUplinkInfo;
  TUplinkInfo = record
    Addr : TAddress;
    Files: Longint;
    Bytes: Longint;
  end; { TUplinkInfo }

  PUplinks = ^TUplinks;
  TUplinks = object (TSortedCollection)
    procedure FreeItem(Item: Pointer); virtual;
    function Compare(Key1, Key2: Pointer) : Integer; virtual;
  end; { TUplinks }

var
  Uplinks: PUplinks;

{ --------------------------------------------------------- }
{ FreeItem                                                  }
{ --------------------------------------------------------- }

procedure TUplinks.FreeItem(Item: Pointer);
begin
  Dispose(PUplinkInfo(Item));
end;

{ --------------------------------------------------------- }
{ Compare                                                   }
{ --------------------------------------------------------- }

function TUplinks.Compare(Key1, Key2: Pointer) : Integer;
begin
  Result := CompAddr(PUplinkInfo(Key1)^.Addr, PUplinkInfo(Key2)^.Addr);
end;



{ --------------------------------------------------------- }
{ Abort                                                     }
{ --------------------------------------------------------- }

procedure Abort( Message: String );
begin
  Writeln( '! ', Message, ^M^J^M^J'Aborting..' );
  Halt( 1 );
end; { Abort }

{ --------------------------------------------------------- }
{ MakeReport                                                }
{ --------------------------------------------------------- }

procedure MakeReport(Differ: Integer; TrafficBin, ReportLog: String);
var
  j: Integer;
  E: PEcho;
  U: PUplinkInfo;
  F: Text;

  R: record
       TimeStamp: UnixTime;
       Uplink   : TAddress;
       FileSize : Longint;
       TextSize : Longint;
     end;

  Traffic: TBufStream;
  Started: UnixTime;
  Counter: PCounter;

  TotalFiles: Longint;
  TotalBytes: Longint;
  NameSize  : Integer;
  AddrSize  : Integer;

  function Early: Boolean;
  begin
    Result := False;

    Traffic.Read(R, SizeOf(R));

    if Traffic.Status <> stOk then
      Exit;

    if DaysBetween(Started, R.TimeStamp) > Differ then
    begin
      Traffic.Seek(Traffic.GetPos + R.TextSize);
      Result := True;
    end;

  end; { Early }

  function InTime: Boolean;
  var
    D: Longint;
  begin
    InTime := False;
    if Traffic.Status <> stOk then Exit;
    D := DaysBetween(Started, R.TimeStamp);
    Result := (D <= Differ) and (D > 0);
  end; { InTime }

  procedure Accept;
  var
    FileName: String;
    AreaTag : String;
  begin
    Traffic.Read(FileName[0], 1);
    Traffic.Read(FileName[1], Ord(FileName[0]));
    Traffic.Read(AreaTag[0], 1);
    Traffic.Read(AreaTag[1], Ord(AreaTag[0]));

    if Counter^.Search(@AreaTag, j) then
      E := Counter^.At(j)
    else
    begin
      New(E);
      FillChar(E^, SizeOf(E^), 0);
      E^.Tag := AllocStr(AreaTag);
      Counter^.Insert(E);
      if Length(AreaTag) > NameSize then
        NameSize := Length(AreaTag);
    end;

    if Uplinks^.Search(@R.Uplink, j) then
      U := Uplinks^.At(j)
    else
    begin
      New(U);
      FillChar(U^, SizeOf(U^), 0);
      U^.Addr  := R.Uplink;
      Uplinks^.Insert(U);
      if Length(AddrToStr(R.Uplink)) > AddrSize then
        AddrSize := Length(AddrToStr(R.Uplink));
    end;

    Inc(E^.Files);
    Inc(E^.Bytes, R.FileSize);

    Inc(U^.Files);
    Inc(U^.Bytes, R.FileSize);

    Traffic.Read(R, SizeOf(R));
  end; { Accept }

  procedure MakeRow(E: PEcho); far;
  begin
    Inc(j);
    Inc(TotalFiles, E^.Files);
    Inc(TotalBytes, E^.Bytes);

    Writeln(F, Format('%3d. %-' + IntToStr(NameSize) + 's %5d  %s  (~%s)', [j, E^.Tag^, E^.Files, ASRF(E^.Bytes), ASRF(E^.Bytes / E^.Files)]));
  end; { MakeRow }


  procedure MakeURow(U: PUplinkInfo); far;
  var
    S: String;
  begin
    Inc(j);

    if CompAddr(U^.Addr, _ZERO_ADDR) = 0 then
      S := 'Unknown'
    else
      S := AddrToStr(U^.Addr);

    Writeln(F, Format('%3d. %' + IntToStr(AddrSize) + 's  %5d  %s', [j, S, U^.Files, ASRF(U^.Bytes)]));
  end;

begin
  Started := CurrentUnixTime;

  Traffic.Init(TrafficBin, stOpenRead, 4096);

  if Traffic.Status <> stOk then
    Abort(Format('Unable to open traffic file `%s''', [TrafficBin]));

  while Early do {..Nothing..};

  if Traffic.Status <> stOk then
  begin
    Traffic.Done;
    Abort('Нет информации за нужный период');
  end;

  Counter  := New(PCounter, Init(100, 100));
  Uplinks  := New(PUplinks, Init(100, 100));
  NameSize := 0;
  AddrSize := Length('Unknown');

  while inTime do
    Accept;

  Traffic.Done;

  try
    Assign(F, ReportLog); Rewrite(F);
  except
    on E: Exception do
      Abort(E.Message);
  end;

  Writeln(F, Format('* Fileecho statistics for last %d days'^M^J, [Differ]));

  j := 0;
  TotalFiles := 0;
  TotalBytes := 0;

  Writeln(F, CharStr(' ',   6 + NameSize) + 'Files  Total  Average');
  Writeln(F, CharStr(#196, 28 + NameSize));
  Counter^.ForEach(@MakeRow);
  Writeln(F, CharStr(#196, 28 + NameSize));
  Writeln(F, Format('%' + IntToStr(11 + NameSize) + 'd  %s', [TotalFiles, ASRF(TotalBytes)]));

  Writeln(F, ^M^J^M^J'* Traffic by uplinks'^M^J);
  j := 0;

  Writeln(F, CharStr(' ', 7 + AddrSize) + 'Files   Size');
  Writeln(F, CharStr(#196, 19 + AddrSize));
  Uplinks^.ForEach(@MakeURow);
  Writeln(F, CharStr(#196, 19 + AddrSize));

  Close(F);
  Destroy(Counter);
  Destroy(Uplinks);
end; { MakeReport }


begin
  Writeln(^M^J'■ Hi-Files Statistics Viewer, v1.00, (c)2005 Dmitry Liman [2:461/79]'^M^J);

  if ParamCount <> 3 then
  begin
    Writeln('Usage: stat <days> traffic.bin report.log'^M^J);
    Abort('Bad command line')
  end;

  MakeReport(StrToInt(ParamStr(1)), ParamStr(2), ParamStr(3));

  Writeln(^M^J'■ Construction complete ;-)');
end.

