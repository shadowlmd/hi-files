unit MyViews;

/////////////////////////////////////////////////////////////////////
//
// Hi-Files Version 2
// Copyright (c) 1997-2004 Dmitry Liman [2:461/79]
//
// http://hi-files.narod.ru
//
/////////////////////////////////////////////////////////////////////

interface

uses
  Objects, Views, Dialogs, Drivers;

type
  LBFlag  = (lb_multisel, lb_reorder, lb_speedsearch);
  LBMode = set of LBFlag;

type
  PMyListBox = ^TMyListBox;
  TMyListBox = object (TListBox)
    Reordered: Boolean;
    Mode     : LBMode;

    constructor Init( var R: TRect; ANumCols: Integer; ScrollBar: PScrollBar );
    procedure SetMode( AMode: LBMode );
    function  GetSearchStr( Item: Integer ) : String; virtual;
    procedure HandleEvent( var Event: TEvent ); virtual;
    procedure Draw; virtual;
    procedure FocusItem( Item: Integer ); virtual;
    procedure SelectItem( Item: Integer ); virtual;
    procedure TagItem( Item: Integer; Tag: Boolean ); virtual;
    function  ItemTagged( Item: Integer ) : Boolean; virtual;
    function  GetTagCount: Integer;
    function  SelectedItem: Pointer;
    procedure DragItemUp; virtual;
    procedure DragItemDn; virtual;
    function  DataSize: Integer; virtual;
    procedure GetData( var Data ); virtual;
    procedure SetData( var Data ); virtual;
  private
    SearchPos: Integer;
    Focusing : Boolean;
  end; { TMyListBox }

  PStrListEditor = ^TStrListEditor;
  TStrListEditor = object (TDialog)
    InputLine: PInputLine;
    ListBox  : PMyListBox;
    procedure SetupDialog( const Caption: String; List: PCollection );
    procedure HandleEvent( var Event: TEvent ); virtual;
  end; { TStrListEditor }

  PInfoPane = ^TInfoPane;
  TInfoPane = object (TParamText)
    function GetPalette: PPalette; virtual;
  end; { TInfoPane }

type
  ShortStr = String[20];
  LongStr  = String[128];

const
  cmDragItemUp = 100;
  cmDragItemDn = 101;
  cmTagAll     = 102;
  cmUntagAll   = 103;
  cmInsItem    = 104;
  cmDelItem    = 105;
  cmChgItem    = 106;
  cmAppItem    = 107;
  cmFocusMoved = 110;
  cmFocusLeave = 111;

  cmEnter   = 270;
  cmOptions = 271;
  cmImport  = 272;


{ =================================================================== }

implementation

uses
  SysUtils, MyLib, _Res;

{ --------------------------------------------------------- }
{ TMyListBox                                                }
{ --------------------------------------------------------- }

{ Init ---------------------------------------------------- }

constructor TMyListBox.Init( var R: TRect; ANumCols: Integer; ScrollBar: PScrollBar );
begin
  inherited Init(R, ANumCols, ScrollBar);
  SetMode([lb_speedsearch]);
end; { Init }

{ SetMode ------------------------------------------------- }

procedure TMyListBox.SetMode( AMode: LBMode );
begin
  Mode := AMode;
  if lb_speedsearch in Mode then
  begin
    ShowCursor;
    SetCursor(1, 0);
  end
  else
    HideCursor;
end; { SetMode }

{ GetSearchStr -------------------------------------------- }

function TMyListBox.GetSearchStr( Item: Integer ) : String;
begin
  Result := GetText( Item, Size.X );
end; { GetSearchStr }

{ HandleEvent --------------------------------------------- }

procedure TMyListBox.HandleEvent( var Event: TEvent );
var
  j: Integer;
  SearchStr: String;
  OldFocus : Integer;

procedure EventCommand( Command: Word );
begin
  Event.What := evCommand;
  Event.Command := Command;
end; { EventCommand }

function FirstMatch( var Index: Integer ) : Boolean;
var
  j: Integer;
  S: String;
begin
  for j := 0 to List^.Count - 1 do
  begin
    S := Copy( GetSearchStr( j ), 1, SearchPos );
    if JustSameText( S, SearchStr ) then
    begin
      Index := j;
      Result := True;
      Exit;
    end;
  end;
  Result := False;
end; { FirstMatch }

procedure TagAll( Tag: Boolean );
var
  j: Integer;
begin
  if lb_multisel in Mode then
  begin
    for j := 0 to Pred(Range) do
      TagItem( j, Tag );
    DrawView;
  end;
end; { TagAll }

begin
  case Event.What of
    evKeyDown:
      begin
        if (GetShiftState and (kbLeftShift or kbRightShift)) <> 0 then
        begin
          case Event.KeyCode of
            kbUp  : EventCommand( cmDragItemUp );
            kbDown: EventCommand( cmDragItemDn );
          end;
        end
        else
          case Event.KeyCode of
            kbGrayMinus: EventCommand( cmUntagAll );
            kbGrayPlus : EventCommand( cmTagAll   );
            kbIns      : EventCommand( cmInsItem );
            kbDel      : EventCommand( cmDelItem );
          end;
      end;
  end;

  OldFocus := Focused;
  inherited HandleEvent( Event );
  if OldFocus <> Focused then
    SearchPos := 0;
  if Focused >= Range then Exit;

  case Event.What of
    evCommand:
      begin
        case Event.Command of
          cmDragItemUp: DragItemUp;
          cmDragItemDn: DragItemDn;
          cmTagAll    : TagAll( True );
          cmUntagAll  : TagAll( False );
        else
          Exit;
        end;
        ClearEvent( Event );
      end;

    evKeyDown:
      begin
        if (lb_speedsearch in Mode)      and
           (Event.KeyCode <> kbEnter )   and
           (Event.KeyCode <> kbEsc)      and
           (Event.KeyCode <> kbTab)      and
           (Event.KeyCode <> kbShiftTab) and
           (Event.CharCode <> #0)
        then
        begin
          SearchStr := Copy( GetSearchStr(Focused), 1, SearchPos );
          if (Event.KeyCode = kbBack) and (SearchPos > 0) then
          begin
            Dec( SearchPos );
            Dec( SearchStr[0] );
            FirstMatch( j );
            FocusItem( j );
          end
          else
          begin
            Inc( SearchPos );
            SearchStr[ SearchPos ] := Event.CharCode;
            SearchStr[0] := Chr( SearchPos );
            if FirstMatch( j ) then
              FocusItem( j )
            else
              Dec( SearchPos );
          end;
          SetCursor( SearchPos+1, Cursor.Y );
          ClearEvent( Event );
        end;
      end;
  end;
end; { HandleEvent }

{ Draw ---------------------------------------------------- }

procedure TMyListBox.Draw;
const
  TAG_CHAR = ' '; // Disabled tag char
var
  I, J, Item: Integer;
  NormalColor, SelectedColor, FocusedColor, Color: Word;
  ColWidth, CurCol, Indent: Integer;
  B: TDrawBuffer;
  Text: String;
begin
  if State and (sfSelected + sfActive) = (sfSelected + sfActive) then
  begin
    NormalColor := GetColor(1);
    FocusedColor := GetColor(3);
  end
  else
    NormalColor := GetColor(2);

  SelectedColor := GetColor(4);

  if HScrollBar <> nil then
    Indent := HScrollBar^.Value
  else
    Indent := 0;
  ColWidth := Size.X div NumCols + 1;
  for I := 0 to Size.Y - 1 do
  begin
    for J := 0 to NumCols-1 do
    begin
      Item := J*Size.Y + I + TopItem;
      CurCol := J*ColWidth;

      if (State and (sfSelected + sfActive) = (sfSelected + sfActive)) and
        (Focused = Item) and (Range > 0) then
      begin
        Color := FocusedColor;
        SetCursor(CurCol+1,I);
      end
      else if Item < Range then
      begin
        if (lb_multisel in Mode) and ItemTagged(Item) or
           not (lb_multisel in Mode) and IsSelected(Item)
        then
          Color := SelectedColor
        else
          Color := NormalColor
      end
      else
        Color := NormalColor;

      MoveChar(B[CurCol], ' ', Color, ColWidth);
      if Item < Range then
      begin
        Text := GetText(Item, ColWidth + Indent);
        Text := Copy(Text,Indent,ColWidth);
        MoveStr(B[CurCol+1], Text, Color);
        if ItemTagged( Item ) then
        begin
          WordRec(B[CurCol]).Lo := Byte( TAG_CHAR );
          WordRec(B[CurCol+ColWidth-2]).Lo := Byte( TAG_CHAR );
        end;
      end;
      MoveChar(B[CurCol+ColWidth-1], #179, GetColor(5), 1);
    end;
    WriteLine(0, I, Size.X, 1, B);
  end;
end; { Draw }

{ FocusItem ----------------------------------------------- }

procedure TMyListBox.FocusItem( Item: Integer );
begin
  if not Focusing then
  begin
    Focusing := True;
    Message( Owner, evBroadcast, cmFocusLeave, Pointer(Focused) );
    inherited FocusItem( Item );
    Message( Owner, evBroadcast, cmFocusMoved, Pointer(Item) );
    Focusing := False;
    DrawView;
  end;
end; { FocusItem }

{ SelectItem ---------------------------------------------- }

procedure TMyListBox.SelectItem( Item: Integer );
begin
  if lb_multisel in Mode then
  begin
    TagItem( Item, not ItemTagged(Item) );
    if Item < Pred(Range) then
      FocusItem( Succ(Item) )
    else
      DrawView;
  end
  else
    inherited SelectItem(Item);
end; { SelectItem }

{ TagItem ------------------------------------------------- }

procedure TMyListBox.TagItem( Item: Integer; Tag: Boolean );
begin
end; { TagItem }

{ ItemTagged ---------------------------------------------- }

function TMyListBox.ItemTagged( Item: Integer ) : Boolean;
begin
  Result := False;
end; { ItemTagged }

{ GetTagCount --------------------------------------------- }

function TMyListBox.GetTagCount: Integer;
var
  j: Integer;
begin
  Result := 0;
  for j := Pred(List^.Count) downto 0 do
    if ItemTagged(j) then
      Inc(Result);
end; { GetTagCount }

{ SelectedItem -------------------------------------------- }

function TMyListBox.SelectedItem: Pointer;
begin
  if Range = 0 then
    Result := nil
  else
    Result := List^.At(Focused);
end; { SelectedItem }

{ DragItemUp ---------------------------------------------- }

procedure TMyListBox.DragItemUp;
var
  p: Pointer;
begin
  if lb_reorder in Mode then
  begin
    p := SelectedItem;
    if (p = nil) or (Focused = 0) then Exit;
    List^.AtDelete( Focused );
    List^.AtInsert( Pred(Focused), p );
    FocusItem( Pred(Focused) );
    Reordered := True;
  end;
end; { DragItemUp }

{ DragItemDn ---------------------------------------------- }

procedure TMyListBox.DragItemDn;
var
  p: Pointer;
begin
  if lb_reorder in Mode then
  begin
    p := SelectedItem;
    if (p = nil) or (Focused = Pred(Range)) then Exit;
    List^.AtDelete( Focused );
    List^.AtInsert( Succ(Focused), p );
    FocusItem( Succ(Focused) );
    Reordered := True;
  end;
end; { DragItemDn }

{ DataSize ------------------------------------------------ }

function TMyListBox.DataSize: Integer;
begin
  Result := 0;
end; { DataSize }

{ GetData ------------------------------------------------- }

procedure TMyListBox.SetData( var Data );
begin
end; { SetData }

{ GetData ------------------------------------------------- }

procedure TMyListBox.GetData( var Data );
begin
end; { GetData }

{ --------------------------------------------------------- }
{ TStrListEditor                                            }
{ --------------------------------------------------------- }

{ SetupDialog --------------------------------------------- }

procedure TStrListEditor.SetupDialog( const Caption: String; List: PCollection );
var
  R: TRect;
begin
  R.Assign( 0, 0, 0, 0 );
  ListBox   := PMyListBox( ShoeHorn( @Self, New( PMyListBox, Init(R, 1, nil) )));
  ListBox^.SetMode([lb_speedsearch, lb_reorder]);
  InputLine := PInputLine( ShoeHorn( @Self, New( PInputLine, Init(R, Pred(SizeOf(LongStr))))));
  ListBox^.NewList( List );
  ReplaceStr( Title, Caption );
end; { SetupDialog }

{ HandleEvent --------------------------------------------- }

procedure TStrListEditor.HandleEvent( var Event: TEvent );
var
  S: LongStr;

procedure AppendItem;
begin
  with ListBox^, List^ do
  begin
    AtInsert( Range, AllocStr(S) );
    SetRange( Succ(Range) );
    FocusItem( Pred(Range) );
  end;
end; { AppendItem }

procedure ChangeItem;
begin
  with ListBox^, List^ do
  begin
    if Range > 0 then
    begin
      AtFree( Focused );
      AtInsert( Focused, AllocStr(S) );
      FocusItem( Focused );
    end
    else
      AppendItem;
  end;
end; { ChangeItem }

procedure InsertItem;
begin
  with ListBox^, List^ do
  begin
    AtInsert( Focused, AllocStr('') );
    SetRange( Succ(Range) );
    FocusItem( Focused );
  end;
end; { InsertItem }

procedure DeleteItem;
begin
  with ListBox^, List^ do
  begin
    if Range = 0 then Exit;
    AtFree(Focused);
    SetRange(Pred(Range));
    FocusItem(Focused);
  end;
end; { DeleteItem }

procedure FocusMoved;
var
  p: PString;
begin
  p := ListBox^.SelectedItem;
  if p <> nil then
    S := p^
  else
    S := '';
  InputLine^.SetData( S );
end; { FocusMoved }

begin
  inherited HandleEvent( Event );
  case Event.What of
    evCommand:
      begin
        InputLine^.GetData( S );
        case Event.Command of
          cmChgItem: ChangeItem;
          cmInsItem: InsertItem;
          cmDelItem: DeleteItem;
          cmAppItem: AppendItem;
        else
          Exit;
        end;
        ClearEvent( Event );
      end;
    evBroadcast:
      case Event.Command of
        cmFocusMoved: FocusMoved;
      end;
  end;
end; { HandleEvent }

{ --------------------------------------------------------- }
{ TInfoPane                                                 }
{ --------------------------------------------------------- }

{ GetPalette ---------------------------------------------- }

function TInfoPane.GetPalette: PPalette;
const
  CInfoPane = #30;
  P: String[Length(CInfoPane)] = CInfoPane;
begin
  Result := @P;
end; { GetPalette }


end.
