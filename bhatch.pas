unit BHatch;

/////////////////////////////////////////////////////////////////////
//
// Hi-Files Version 2
// Copyright (c) 1997-2004 Dmitry Liman [2:461/79]
//
// http://hi-files.narod.ru
//
/////////////////////////////////////////////////////////////////////

interface

procedure BatchHatcher;

{ =================================================================== }

implementation

uses
  SysUtils, Objects, MyLib, _Crc32,
  _Cfg, _Res, _Log, _Tic, _MapFile, _Working;

{ --------------------------------------------------------- }
{ BatchHatcher                                              }
{ --------------------------------------------------------- }

procedure BatchHatcher;
var
  TicList : PCollection;
  Map: TMappedFile;
  Tic: PTic;
  S  : String;
  j  : Integer;
  Key, Val: String;


  procedure StartNewJob;
  begin
    Tic := New( PTic, Init );
    Tic^.TicName := Val;      // TicName == JobName
    TicList^.Insert( Tic );
  end; { StartNewJob }

  procedure CloseJob;
  begin
    Tic := nil;
  end; { CloseJob }

  procedure DoJob( Tic: PTic ); far;
  var
    ShortName  : String;
    InboundName: String;
  begin
    Log.Write( ll_Protocol, Format( LoadString(_SDoingJob), [Tic^.TicName] ) );
    OpenWorking( Format( LoadString(_SDoingJob), [Tic^.TicName] ));
    try
{$IFDEF Win32}
      if VFS_GetShortName( Tic^.FileName^, ShortName ) then
      begin
        InboundName := AtPath( ShortName, CFG^.Inbound );
        if not VFS_CopyFile( Tic^.FileName^, InboundName ) then
          raise Exception.Create( Format(LoadString(_SCantCopyToInbound), [Tic^.FileName^] ));
        MyLib.ReplaceStr( Tic^.FullName, ExtractFileName(Tic^.FileName^) );
        MyLib.ReplaceStr( Tic^.FileName, ExtractFileName(InboundName) );
      end
      else
      begin
{$ENDIF}
        InboundName := AtPath(Tic^.FileName^, CFG^.Inbound);
        if not VFS_CopyFile( Tic^.FileName^, InboundName ) then
          raise Exception.Create( Format(LoadString(_SCantCopyToInbound), [Tic^.FileName^] ));
        MyLib.ReplaceStr( Tic^.FileName, ExtractFileName(Tic^.FileName^) );
{$IFDEF Win32}
      end;
{$ENDIF}

      with Tic^ do
      begin
        CRC := GetFileCrc( InboundName );
        Origin   := CFG^.PrimaryAddr;
        FromAddr := Origin;
        ToAddr   := Origin;
        MyLib.ReplaceStr( Created, 'by ' + SHORT_PID );
        MyLib.ReplaceStr( Pw, CFG^.HatchPw );
        Tic^.SaveTo( BuildTicName(CFG^.PrimaryAddr, CFG^.Inbound), @CFG^.PrimaryAddr );
        Log.Write( ll_Service, Format(LoadString(_SFileHatchOk), [Tic^.FileName^, Tic^.AreaTag^] ));
      end;

    except
      on E: Exception do
        ShowError( Format(LoadString(_SJobCancel), [E.Message] ) );
    end;
    CloseWorking;
  end; { OpenWorking }


begin
  Log.Write( ll_Service, LoadString(_SBHatchStarted) );

  if CFG^.HatchCtl = '' then
    CFG^.HatchCtl := 'hatch.ctl';

  CFG^.HatchCtl := ExistingFile( CFG^.HatchCtl );
  Log.Write( ll_Protocol, Format( LoadString(_SReadingBHatch), [CFG^.HatchCtl] ) );
  TicList := New( PCollection, Init(10, 10) );

  try

    OpenWorking( Format( LoadString(_SReadingBHatch), [CFG^.HatchCtl] ) );

    try
      Map.Init( CFG^.HatchCtl );
      while Map.GetLine( S ) do
      begin
        StripComment( S );
        if S = '' then Continue;
        SplitPair( S, Key, Val );
        if JustSameText( Key, 'Job' ) then
          StartNewJob
        else
        begin
          if Tic = nil then
          begin
            ShowError( Format( LoadString(_SJobNeed), [S] ) );
            Continue;
          end;
          if JustSameText( Key, 'File' ) then
          begin
            if (Val <> '') and (Val[1] = '"') then
              ReplaceStr( Tic^.FileName, GetLiterals( Val, 1, j ) )
            else
              ReplaceStr( Tic^.FileName, Val );
          end
          else if JustSameText( Key, 'Area' ) then
            ReplaceStr( Tic^.AreaTag, Val )
          else if JustSameText( Key, 'Replaces' ) then
            ReplaceStr( Tic^.Replaces, Val )
          else if JustSameText( Key, 'Magic' ) then
            ReplaceStr( Tic^.Magic, Val )
          else if JustSameText( Key, 'End' ) then
            CloseJob
          else if Pos( '// ', S ) = 1 then
          begin
            S := Copy( S, 4, Length(S) );

            if Tic^.Desc = nil then
              Tic^.Desc := AllocStr( S )
            else
            begin
              if Tic^.LDesc = nil then
                Tic^.LDesc := New( PStrings, Init(10, 10) );
              Tic^.LDesc^.Insert( AllocStr(S) );
            end;
          end
          else
            ShowError( Format( LoadString(_SUnknownOp), [S] ) );
        end;
      end;

    finally
      Map.Done;
      CloseWorking;
    end;

    if Tic <> nil then
      ShowError( Format(LoadString(_SUnclosedJob), [Tic^.TicName] ));

    TicList^.ForEach( @DoJob );

  finally
    Destroy( TicList );
  end;

  Log.Write( ll_Protocol, LoadString(_SBatchComplete) );

end; { BatchHatcher }

end.


