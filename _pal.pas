unit _pal;

/////////////////////////////////////////////////////////////////////
//
// Hi-Files Version 2
// Copyright (c) 1997-2004 Dmitry Liman [2:461/79]
//
// http://hi-files.narod.ru
//
/////////////////////////////////////////////////////////////////////

interface

procedure EditPal;
procedure LoadPal;
procedure SavePal;
procedure SetPal(const FileName: String );

{ =================================================================== }

implementation

uses
  Objects, ColorSel, Dialogs, App, Views, Memory, MyLib,
  _Res, _Log, _Cfg, _fopen, SysUtils, MsgBox;

{ --------------------------------------------------------- }
{ EditPal                                                   }
{ --------------------------------------------------------- }

procedure EditPal;
var
  D: PColorDialog;
begin
  D := New(PColorDialog, Init('',
    ColorGroup('Desktop',  DesktopColorItems(nil),
    ColorGroup('Menu',     MenuColorItems(nil),
    ColorGroup('Dialog',   DialogColorItems(dpGrayDialog, nil),
    ColorGroup('Help',
      ColorItem('Frame passive',    128,
      ColorItem('Frame active',     129,
      ColorItem('Frame icons',      130,
      ColorItem('Scroll bar page',  131,
      ColorItem('Scroll bar icons', 132,
      ColorItem('Normal text',      133,
      ColorItem('Ref normal',       134,
      ColorItem('Ref selected',     135,
      nil)))))))), nil))))));

  with Application^ do
  begin
    if ExecuteDialog( D, GetPalette ) <> cmCancel then
    begin
      DoneMemory;
      InitMemory;
      ReDraw;
    end;
  end;
end { EditPal };

{ --------------------------------------------------------- }
{ SetPal                                                  }
{ --------------------------------------------------------- }

const
  PalSign = Longint($236c6170);

procedure SetPal(const Filename: String);
var
  S: TDosStream;
  Sign: Longint;
  Buffer  : array [0..255] of char;
begin
  S.Init( FileName, stOpenRead );
  if S.Status <> stOk then
  begin
    S.Done;
    ShowError( Format(LoadString(_SFileNotFound), [FileName]) );
    Exit;
  end;

  S.Read( Sign, 4 );
  if Sign <> PalSign then
  begin
    S.Done;
    ShowError( LoadString(_SBadPalFile) );
    Exit;
  end;

  S.Read( Buffer, Length(Application^.GetPalette^) );

  if S.Status = stOk then
  begin
    Move( Buffer, Application^.GetPalette^[1], Length(Application^.GetPalette^) );
    DoneMemory;
    InitMemory;
    Application^.Redraw;
    if not JustSameText(CFG^.Palette, FileName) then
    begin
      CFG^.Palette  := FileName;
      CFG^.Modified := True;
    end;
  end
  else
    ShowError(LoadString(_SBadPalFile));
  S.Done;

end; { SetPal }

{ --------------------------------------------------------- }
{ LoadPal                                                   }
{ --------------------------------------------------------- }

procedure LoadPal;
var
  Cmd : Word;
  FileName: String;
begin
  FileName := '*.pal';

  if ExecFileOpenDlg(LoadString(_SOpenPalCaption), AtHome('*.pal'), FileName ) then
    SetPal( FileName );
end; { LoadPal }

{ --------------------------------------------------------- }
{ SavePal                                                   }
{ --------------------------------------------------------- }

procedure SavePal;
var
  S: TDosStream;
  Sign: Longint;
  Cmd : Word;
  FileName: String;
begin
  if CFG^.Palette = '' then
     FileName := AtHome('default.pal')
  else
     FileName := AtHome(CFG^.Palette);

  FileName := '*.pal';
  if not ExecFileOpenDlg(LoadString(_SSavePalCaption), AtHome('*.pal'), FileName ) then
    Exit;

  if FileExists( FileName ) and
     (MessageBox( Format(LoadString(_SConfirmOverwrite), [FileName]), nil, mfWarning + mfYesNoCancel) <> cmYes) then
     Exit;

  S.Init( FileName, stCreate );

  if S.Status <> stOk then
  begin
    S.Done;
    ShowError( Format(LoadString(_SCantCreateFile), [FileName]) );
    Exit;
  end;

  Sign := PalSign;

  S.Write( Sign, 4 );
  S.Write( Application^.GetPalette^[1], Length(Application^.GetPalette^) );

  S.Done;

  if not JustSameText(CFG^.Palette, FileName) then
  begin
    CFG^.Palette  := FileName;
    CFG^.Modified := True;
  end;

end; { SavePal }

end.

