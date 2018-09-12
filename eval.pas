unit Eval;

// ==================================================================
//
//   "Eval.Pas" Version 1.00 (C) 2002 Dmitry Liman <leemon@ua.fm>
//
// ==================================================================
//
//    Ну кто же не хочет вставить свои пять копеек в святое дело
//    написания очередной универсальной вычислялки выражений? .)
//
//       Компилятор: Virtual Pascal 2.1; платформа: Win32.
//
// ==================================================================

interface

uses Objects;

const
  STACK_DEPTH = 20;
  MAX_FUNCTION_ARG = 10;

type
  Float = Double;

  TTokenMode = (tok_none, tok_var, tok_fun, tok_const, tok_op);
  TValueType = (val_error, val_integer, val_float, val_bool, val_string);

  TOperator  = (
    op_none,
    op_and,
    op_or,
    op_not,
    op_xor,
    op_autoinc,
    op_autodec,
    op_plusby,
    op_minusby,
    op_mulby,
    op_divby,
    op_assign,
    op_plus,
    op_minus,
    op_mul,
    op_div,
    op_eq,
    op_ne,
    op_lt,
    op_gt,
    op_le,
    op_ge,
    op_lbrac,
    op_rbrac,
    op_comma,
    op_unary_plus,
    op_unary_minus,
    op_call );

  PIdRef = ^TIdRef;
  PValue = ^TValue;

  TValue = packed record
    Variable: PIdRef;
    case ValType : TValueType of
      val_integer: (IntValue   : Integer);
      val_float  : (FloatValue : Float);
      val_bool   : (BoolValue  : Boolean);
      val_string : (StringValue: String);
  end; { TValue }

  TIdMode = ( id_Var, id_Fun );

  TFunction = packed record
    EntryPoint: Pointer;
    ValType : TValueType;
    ArgList : String;
  end; { TFunction }

  TIdRef = packed record
    Name: PString;
    case Mode: TIdMode of
      id_var: (V: TValue);
      id_fun: (F: TFunction);
  end; { TIdRef }

  PToken = ^TToken;
  TToken = packed record
    What : TTokenMode;
    Op   : TOperator;
    IdRef: PIdRef;
    V    : TValue;
  end; { TToken }

  PIdTable = ^TIdTable;
  TIdTable = object (TStringCollection)
    procedure FreeItem( Item: Pointer ); virtual;
    function KeyOf( Item: Pointer ) : Pointer; virtual;
    function SearchId( const Name: String; var Ref: PIdRef ) : Boolean;
  end; { TIdTable }

  PExpression = ^TExpression;
  TExpression = object (TObject)
    constructor Init;
    destructor  Done; virtual;
    procedure Exec( const S: String );
    procedure GetResult( var V: TValue );
    procedure CreateVar( const Name: String; ValType: TValueType );
    procedure SetVar( const Name: String; ValType: TValueType; var V );
    procedure SetVarInt( const Name: String; Value: Integer );
    procedure SetVarFloat( const Name: String; Value: Float );
    procedure SetVarBool( const Name: String; Value: Boolean );
    procedure SetVarString( const Name: String; Value: String );
    procedure DropVar( const Name: String );
    procedure RegisterFunction( const Name: String; ValType: TValueType;
                const ArgList: String; EntryPoint: Pointer );
    procedure DropFunction( const Name: String );
    function  GetText: String;
    function  ErrorPos: Integer;
  private
    Text    : String;
    Size    : Integer;
    Finger  : Integer;
    Token   : TToken;
    IdTable : PIdTable;
    ValSP   : Integer;
    OpSP    : Integer;
    ValStack: array [0..STACK_DEPTH] of TValue;
    OpStack : array [0..STACK_DEPTH] of TOperator;
    function  GetToken: Boolean;
    procedure ClearToken;
    procedure Cleanup;
    procedure PushValue( var V: TValue );
    procedure PopValue( var V: TValue );
    procedure PushVar( Ref: PIdRef );
    procedure DerefVar;
    procedure ApplyOperator( op: TOperator );
    procedure ApplyRefOperator( op: TOperator; var Ref: PIdRef );
    procedure PushOperator( op: TOperator );
    function  PopOperator : TOperator;
    function  TopOperator : TOperator;
    procedure ApplyFunction( FRef: PIdRef; ArgCount: Integer );
  end; { TExpression }

{ =================================================================== }

implementation

// ==================================================================
//
// Некоторые технические неочевидности:
//
// 1. String должен быть типа ShortString (а не AnsiString).
//    Во многих местах мы используем внутренние детали реализации.
//
// 2. Мы используем внутренние детали реализации следующих базовых
//    типов VP, на которые опираются наши типы данных:
//
//    --- val_integer
//    Базовый тип VP: Longint, 32 bit, DWord.
//    Фактический параметр: пихаем в стек 32-bit значение (PUSH EAX)
//    Результат функции: лежит в EAX
//
//    --- val_float
//    Базовый тип VP: Float (type Float = Double), 64 bit, QWord.
//    Фактический параметр: пихаем в стек 2 DWord-а, сначала старшую
//    половину, потом младшую (чтобы младшие разряды легли по
//    младшим адресам).
//    Результат функции: лежит на вершине плавающего стека, готово
//    для FSTP QWord Ptr <...>
//
//    --- val_bool
//    Базовый тип VP: Boolean, 8 bit.
//    Фактический параметр: пихаем в стек DWord-значение (PUSH EAX)
//    Результат функции: лежит в AL (а может, и во всем EAX :)
//
//    --- val_string
//    Базовый тип VP: ShortString (1 байт длины + 255 байт текста)
//    Фактический параметр: пихаем в стек адрес соответствующего
//    String-значения (LEA EAX, the_string; PUSH EAX)
//    Результат функции: немножко хитро. В стек пихается адрес той
//    String-переменной, куда вызваемая процедура заносит результат,
//    причем _ДО_ пихания первого фактического параметра. Переменная-
//    приемник должна быть готова к максимальной длине строки (255
//    символов) вне зависимости от длины фактически получившейся
//    строки-результата. После возврата из функции в стеке остается
//    этот самый адрес результата, его нужно просто куда-нибуть
//    попнуть .)
//
// 3. При вызове функции фактические параметры пихаются в стек в
//    порядке "слева направо", освобождение стека - проблема
//    вызываемой функции. Исключение составяют функции, возвращающие
//    значения типа String - вызывающая программа должна вытолкнуть
//    из стека один DWord. Метод передачи параметров - по значению,
//    за исключением параметров типа String, которые передаются по
//    ссылке.
//
// 4. Все вышесказанное нужно знать только для поковыряться в самой
//    вычислялке (например, для переноса под другой компилятор),
//    а для пользования ею - нафиг не нужно .)
//
// ==================================================================

uses SysUtils, MyLib;

const
  RSVD_ID_TRUE  = 'TRUE';
  RSVD_ID_FALSE = 'FALSE';

  UNARY_OP = [ op_unary_plus, op_unary_minus, op_not ];

  BINARY_OP = [
    op_plus, op_minus, op_mul, op_div, op_and, op_or, op_xor,
    op_eq, op_ne, op_lt, op_gt, op_le, op_ge ];

  REF_OP = [ op_autoinc, op_autodec ];

  ASSIGN_OP = [ op_assign, op_plusby, op_minusby, op_mulby, op_divby ];

type
  TMnemonicOpTable = array [0..3] of record
    Name: String[3];
    Op  : TOperator;
  end; { TMnemonicOpTable }

  TSymbolicOpTable = array [0..19] of record
    Name: array [0..1] of Char;
    Op  : TOperator;
  end; { TSymbolicOpTable }

const
  MnemonicOpTable: TMnemonicOpTable = (
    (Name: 'AND'; Op: op_and ),
    (Name: 'OR' ; Op: op_or ),
    (Name: 'NOT'; Op: op_not ),
    (Name: 'XOR'; Op: op_xor ));

  SymbolicOpTable: TSymbolicOpTable = (
    (Name: '++' ; Op: op_autoinc),
    (Name: '--' ; Op: op_autodec),
    (Name: '+=' ; Op: op_plusby),
    (Name: '-=' ; Op: op_minusby),
    (Name: '*=' ; Op: op_mulby),
    (Name: '/=' ; Op: op_divby),
    (Name: ':=' ; Op: op_assign),
    (Name: '<>' ; Op: op_ne),
    (Name: '<=' ; Op: op_le),
    (Name: '>=' ; Op: op_ge),
    (Name: '+'#0; Op: op_plus),
    (Name: '-'#0; Op: op_minus),
    (Name: '*'#0; Op: op_mul),
    (Name: '/'#0; Op: op_div),
    (Name: '('#0; Op: op_lbrac),
    (Name: ')'#0; Op: op_rbrac),
    (Name: ','#0; Op: op_comma),
    (Name: '='#0; Op: op_eq),
    (Name: '>'#0; Op: op_gt),
    (Name: '<'#0; Op: op_lt));

type
  TPrioTable = array [TOperator] of Integer;

const

  // Стековые приоритеты операций
  // -1: безразлично; -10: не реализовано

  StackPrio : TPrioTable = (
    -1,  // op_none
     6,  // op_and
     5,  // op_or
     7,  // op_not
     5,  // op_xor
    11,  // op_autoinc
    11,  // op_autodec
     2,  // op_plusby
     2,  // op_minusby
     2,  // op_mulby
     2,  // op_divby
     2,  // op_assign
     9,  // op_plus
     9,  // op_minus
    10,  // op_mul
    10,  // op_div
     8,  // op_eq
     8,  // op_ne
     8,  // op_lt
     8,  // op_gt
     8,  // op_le
     8,  // op_ge
     0,  // op_lbrac
    -1,  // op_rbrac
    -1,  // op_comma
    10,  // op_unary_plus
    10,  // op_unary_minus
     0); // op_call

  // Сравнительные приоритеты

  IncomingPrio : TPrioTable = (
    -1,  // op_none
     6,  // op_and
     5,  // op_or
     7,  // op_not
     5,  // op_xor
    11,  // op_autoinc
    11,  // op_autodec
    12,  // op_plusby
    12,  // op_minusby
    12,  // op_mulby
    12,  // op_divby
    12,  // op_assign
     9,  // op_plus
     9,  // op_minus
    10,  // op_mul
    10,  // op_div
     8,  // op_eq
     8,  // op_ne
     8,  // op_lt
     8,  // op_gt
     8,  // op_le
     8,  // op_ge
    99,  // op_lbrac
     2,  // op_rbrac
     1,  // op_comma
    10,  // op_unary_plus
    10,  // op_unary_minus
    -1); // op_call

{ --------------------------------------------------------- }
{ TIdTable                                                  }
{ --------------------------------------------------------- }

{ FreeItem ------------------------------------------------ }

procedure TIdTable.FreeItem( Item: Pointer );
var
  Ref: PIdRef absolute Item;
begin
  FreeStr( Ref^.Name );
  Dispose( Ref );
end; { FreeItem }

{ KeyOf --------------------------------------------------- }

function TIdTable.KeyOf( Item: Pointer ) : Pointer;
var
  Ref: PIdRef absolute Item;
begin
  Result := Ref^.Name;
end; { KeyOf }

{ SearchId ------------------------------------------------ }

function TIdTable.SearchId( const Name: String; var Ref: PIdRef ) : Boolean;
var
  S: String;
  j: Integer;
begin
  S := JustUpperCase( Name );
  Result := Search( @S, j );
  if Result then
    Ref := At(j)
  else
    Ref := nil;
end; { SearchId }

{ --------------------------------------------------------- }
{ TExpression                                               }
{ --------------------------------------------------------- }

{ Init ---------------------------------------------------- }

constructor TExpression.Init;
begin
  inherited Init;
  New( IdTable, Init(50, 50) );
  Cleanup;
end; { Init }

{ Done ---------------------------------------------------- }

destructor TExpression.Done;
begin
  Destroy( IdTable );
  inherited Done;
end;

{ Cleanup ------------------------------------------------- }

procedure TExpression.Cleanup;
begin
  FillChar( ValStack, SizeOf(ValStack), 0 );
  FillChar( OpStack,  SizeOf(OpStack),  0 );
  ValSP := -1;
  OpSP  := -1;
end; { Cleanup }

{ GetText ------------------------------------------------- }

function TExpression.GetText: String;
begin
  Result := Text;
end; { GetText }

{ RegisterFunction ---------------------------------------- }

const
  ARG_TYPES = ['I', 'F', 'B', 'S'];

procedure TExpression.RegisterFunction( const Name: String; ValType: TValueType;
  const ArgList: String; EntryPoint: Pointer );

  function CheckArgList( const S: String ) : String;
  var
    j: Integer;
  begin
    if Length(S) > MAX_FUNCTION_ARG then
      raise Exception.Create( 'CreateFunction: слишком много фоpмальных паpаметpов' );
    Result := JustUpperCase(S);
    for j := 1 to Length(Result) do
      if not (Result[j] in ARG_TYPES) then
        raise Exception.Create( 'CreateFunction: неизвестный тип фоpмального паpаметpа' )
  end; { CheckArgList }

var
  j: Integer;
  S: String;
  Ref: PIdRef;
begin
  S := JustUpperCase( Name );
  if IdTable^.Search( @S, j ) then
    IdTable^.AtFree( j );
  New( Ref );
  Ref^.Name := AllocStr(S);
  Ref^.Mode := id_fun;
  Ref^.F.ValType  := ValType;
  Ref^.F.ArgList  := CheckArgList( ArgList );
  Ref^.F.EntryPoint := EntryPoint;
  IdTable^.AtInsert( j, Ref );
end; { RegisterFunction }

{ DropFunction -------------------------------------------- }

procedure TExpression.DropFunction( const Name: String );
var
  S: String;
  j: Integer;
begin
  S := JustUpperCase( Name );
  if IdTable^.Search( @S, j ) and (PIdRef(IdTable^.At(j))^.Mode = id_fun) then
    IdTable^.AtFree( j )
  else
    raise Exception.Create( 'DropFunction: "' + Name + '" не существует' );
end; { DropFunction }

{ CreateVar ----------------------------------------------- }

procedure TExpression.CreateVar( const Name: String; ValType: TValueType );
var
  S: String;
  j: Integer;
  Ref: PIdRef;
begin
  S := JustUpperCase( Name );
  if IdTable^.Search( @S, j ) then
    raise Exception.Create( 'CreateVar: "' + Name + '" уже существует' )
  else
  begin
    New( Ref );
    FillChar( Ref^, SizeOf(TIdRef), 0 );
    Ref^.Name := AllocStr( S );
    Ref^.Mode := id_var;
    Ref^.V.ValType := ValType;
    IdTable^.AtInsert( j, Ref );
  end;
end; { CreateVar }

{ DropVar ------------------------------------------------- }

procedure TExpression.DropVar( const Name: String );
var
  S: String;
  j: Integer;
begin
  S := JustUpperCase( Name );
  if IdTable^.Search( @S, j ) and (PIdRef(IdTable^.At(j))^.Mode = id_var) then
    IdTable^.AtFree( j )
  else
    raise Exception.Create( 'DropVar: "' + Name + '" не существует' );
end; { DropVar }

{ SetVarInt ----------------------------------------------- }

procedure TExpression.SetVarInt( const Name: String; Value: Integer );
begin
  SetVar( Name, val_integer, Value );
end; { SetVarInt }

{ SetVarFloat --------------------------------------------- }

procedure TExpression.SetVarFloat( const Name: String; Value: Float );
begin
  SetVar( Name, val_float, Value );
end; { SetVarFloat }

{ SetVarBool ---------------------------------------------- }

procedure TExpression.SetVarBool( const Name: String; Value: Boolean );
begin
  SetVar( Name, val_bool, Value );
end; { SetVarBool }

{ SetVarString -------------------------------------------- }

procedure TExpression.SetVarString( const Name: String; Value: String );
begin
  SetVar( Name, val_string, Value );
end; { SetVarString }

{ SetVar -------------------------------------------------- }

procedure TExpression.SetVar( const Name: String; ValType: TValueType; var V );
var
  S: String;
  j: Integer;
  Ref: PIdRef;
begin
  S := JustUpperCase( Name );
  if IdTable^.Search( @S, j ) and (PIdRef(IdTable^.At(j))^.Mode = id_var) then
  begin
    Ref := IdTable^.At(j);
    if Ref^.V.ValType <> ValType then
      raise Exception.Create( 'SetVar: пеpеменная "' + Name + '" не того типа' );
    with Ref^.V do
      case ValType of
        val_integer : IntValue := Integer(V);
        val_float   : FloatValue := Float(V);
        val_bool    : BoolValue := Boolean(V);
        val_string  : StringValue := String(V);
      end;
  end
  else
    raise Exception.Create( 'SetVar: пеpеменная "' + Name + '" не существует' );
end; { SetVar }

{ ClearToken ---------------------------------------------- }

procedure TExpression.ClearToken;
begin
  FillChar( Token, SizeOf(Token), 0 );
  Token.What := tok_none;
end; { ClearToken }

{ GetToken ------------------------------------------------ }

function TExpression.GetToken: Boolean;

  { IsDigit ----------------------------------------------- }

  function IsDigit( ch: Char ) : Boolean;
  begin
    Result := (ch >= '0') and (ch <= '9');
  end; { IsDigit }

  { IsAlpha ----------------------------------------------- }

  function IsAlpha( ch: Char ) : Boolean;
  begin
    Result := (ch >= 'A') and (ch <= 'z');
  end; { IsAlpha }

  { IsQuote ----------------------------------------------- }

  function IsQuote( ch: Char ) : Boolean;
  begin
    Result := (ch = '''') or (ch = '"');
  end; { IsQuote }

  { ParseNumericConst ------------------------------------- }

  procedure ParseNumericConst;
  var
    j: Integer;
  begin
    j := Finger;
    while (j <= Size) and IsDigit(Text[j]) do Inc(j);
    if (j <= Size) and (Text[j] = '.') then
    begin
      Text[j] := DecimalSeparator;
      Inc(j);
      while (j <= Size) and IsDigit(Text[j]) do Inc(j);
      Token.V.ValType    := val_float;
      Token.V.FloatValue := StrToFloat( Copy(Text, Finger, j - Finger) );
    end
    else
    begin
      Token.V.ValType  := val_integer;
      Token.V.IntValue := StrToInt( Copy(Text, Finger, j - Finger) );
    end;
    Token.What := tok_const;
    Finger := j;
  end; { ParseNumericConst }

  { MnemonicOp -------------------------------------------- }

  function MnemonicOp( const id: String; var op: TOperator ) : Boolean;
  var
    j: Integer;
  begin
    for j := Low(MnemonicOpTable) to High(MnemonicOpTable) do
      if JustSameText(MnemonicOpTable[j].Name, id) then
      begin
        op := MnemonicOpTable[j].op;
        Result := True;
        Exit;
      end;
    op := op_none;
    Result := False;
  end; { MnemonicOp }

  { ParseIdentifier --------------------------------------- }

  procedure ParseIdentifier;
  var
     j: Integer;
    id: String;
    op: TOperator;
    IdRef: PIdRef;
  begin
    j := Finger;
    while (Finger <= Size) and (Text[Finger] in IDCHARS) do Inc(Finger);
    id := Copy(Text, j, Finger - j);
    if JustSameText( id, RSVD_ID_TRUE ) then
    begin
      Token.What        := tok_const;
      Token.V.ValType   := val_bool;
      Token.V.BoolValue := True;
    end
    else if JustSameText( id, RSVD_ID_FALSE ) then
    begin
      Token.What        := tok_const;
      Token.V.ValType   := val_bool;
      Token.V.BoolValue := False;
    end
    else if MnemonicOp( id, op ) then
    begin
      Token.What := tok_op;
      Token.Op   := op;
    end
    else if IdTable^.SearchId( id, IdRef ) then
    begin
      if IdRef^.Mode = id_fun then
      begin
        if Finger <= Size then
          Finger := SkipR( Text, Finger, Size, ' ' );
        if (Finger > Size) or (Text[Finger] <> '(') then
          raise Exception.Create( 'Непpавильный вызов функции' );
        Inc( Finger );
        Token.What := tok_fun;
      end
      else
        Token.What := tok_var;
      Token.IdRef := IdRef;
    end
    else
      raise Exception.Create( 'Неизвестный идентификатоp: "' + Id + '"' );
  end; { ParseIdentifier }

  { ParseStringConst -------------------------------------- }

  procedure ParseStringConst;
  var
    q: Char;
    S: String;
    n: Byte absolute S;
  begin
    q := Text[Finger];
    Inc(Finger);
    n := 0;
    while Finger <= Size do
    begin
      if Text[Finger] = q then
      begin
        Inc(Finger);
        if (Finger <= Size) and (Text[Finger] = q) then
        begin
          Inc(Finger);
          Inc(n);
          S[n] := q;
        end
        else
        begin
          Token.What := tok_const;
          Token.V.ValType := val_string;
          Token.V.StringValue := S;
          Exit;
        end;
      end;
      Inc(n);
      S[n] := Text[Finger];
      Inc( Finger );
    end;
    raise Exception.Create( 'Незакpытый литеpал' );
  end; { ParseStringConst }

  { ParseOperator ----------------------------------------- }

  procedure ParseOperator;
  var
    j: Integer;
    S: array [0..1] of Char;
  begin
    S[0] := Text[Finger];
    if Finger < Size then
      S[1] := Text[Finger+1]
    else
      S[1] := #0;
    for j := Low(SymbolicOpTable) to High(SymbolicOpTable) do
      with SymbolicOpTable[j] do
        if (Name[0] = S[0]) and ((Name[1] = #0) or (Name[1] = S[1])) then
        begin
          Token.What := tok_op;
          Token.Op   := Op;
          Inc( Finger, 1 + Ord(Name[1] <> #0) );
          Exit;
        end;
    raise Exception.Create( 'Неpаспознаваемый опеpатоp' );
  end; { ParseOperator }

var
  ch: Char;
begin
  Result := False;
  ClearToken;
  if Finger > Size then Exit;
  Finger := SkipR( Text, Finger, Size, ' ' );
  if Finger > Size then Exit;
  ch := Text[Finger];
  if IsDigit( ch ) then
    ParseNumericConst
  else if IsAlpha( ch ) then
    ParseIdentifier
  else if IsQuote( ch ) then
    ParseStringConst
  else
    ParseOperator;
  Result := True;
end; { GetToken }

{ Exec ---------------------------------------------------- }

procedure TExpression.Exec( const S: String );

  procedure __expr; forward;

  { __var ------------------------------------------------- }

  procedure __var;
  var
    Ref: PIdRef;
  begin
    Ref := Token.IdRef;
    if TopOperator in REF_OP then
    begin
      ApplyRefOperator( PopOperator, Ref );
      PushValue( Ref^.V );
    end
    else
      PushVar( Ref );
    GetToken;
    if (Token.What = tok_op) and (Token.Op in REF_OP) then
    begin
      ApplyRefOperator( Token.Op, Ref );
      DerefVar;
      GetToken;
    end;
  end; { __var }

  { __const ----------------------------------------------- }

  procedure __const;
  begin
    PushValue( Token.V );
    GetToken;
  end; { __const }

  { __op -------------------------------------------------- }

  procedure __op( op: TOperator );
  begin
    if op <> op_lbrac then
      while IncomingPrio[op] <= StackPrio[TopOperator] do
        ApplyOperator( PopOperator );
    if op <> op_rbrac then
      PushOperator( op )
    else
      PopOperator;
  end; { __op }

  { __unary_op -------------------------------------------- }

  procedure __unary_op;
  begin
    if Token.What = tok_op then
    begin
      case Token.Op of
        op_plus : __op( op_unary_plus );
        op_minus: __op( op_unary_minus );
        op_not  : __op( op_not );
      else
        Exit;
      end;
      GetToken;
    end;
  end; { __unary_op }

  { __bin_op ---------------------------------------------- }

  function __bin_op : Boolean;
  begin
    Result := False;
    if (Token.What = tok_op) and
       ((Token.op in BINARY_OP) or (Token.op in ASSIGN_OP)) then
    begin
      __op( Token.op );
      GetToken;
      Result := True;
    end;
  end; { __bin_op }

  { __function -------------------------------------------- }

  procedure __function;
  var
    FRef: PIdRef;
    ArgCount: Integer;
  begin
    FRef := Token.IdRef;
    ArgCount := 0;
    GetToken;
    while (Token.What <> tok_op) or (Token.Op <> op_rbrac) do
    begin
      __op(op_lbrac);
      __expr;
      __op(op_rbrac);
      Inc(ArgCount);
      while (Token.What = tok_op) and (Token.Op = op_comma) do
      begin
        GetToken;
        __op(op_lbrac);
        __expr;
        __op(op_rbrac);
        Inc(ArgCount);
      end;
    end;
    GetToken;
    ApplyFunction( FRef, ArgCount );
  end; { __function }

  { __value ----------------------------------------------- }

  procedure __value;
  begin
    case Token.What of
      tok_var:
        __var;

      tok_const:
        __const;

      tok_fun:
        __function;

      tok_op:
        case Token.Op of
          op_lbrac:
             begin
               __op( op_lbrac );
               GetToken;
               __expr;
               if (Token.What <> tok_op) or (Token.Op <> op_rbrac) then
                 raise Exception.Create( 'Ожидалась пpавая скобка' );
               __op( op_rbrac );
               GetToken;
             end;
          op_autoinc, op_autodec:
            begin
              __op( Token.Op );
              GetToken;
              if Token.What <> tok_var then
                raise Exception.Create( 'Ожидалось имя пеpеменной' );
              __var;
            end;
        else
          raise Exception.Create( 'Такого опеpатоpа тут быть не должно' );
        end;
    else
      raise Exception.Create( 'Непонятный токен' );
    end;
  end; { __value }

  { __item ------------------------------------------------ }

  procedure __item;
  begin
    __unary_op;
    __value;
  end; { __item }

  { __expr ------------------------------------------------ }

  procedure __expr;
  begin
    __item;
    if __bin_op then
      __expr;
  end; { __expr }

begin
  Text   := S;
  Finger := 1;
  Size   := Length(Text);
  try
    GetToken;
    __expr;
    if Token.What <> tok_none then
      raise Exception.Create( 'Ожидался конец выpажения' );
    while OpSP >= 0 do ApplyOperator( PopOperator );
    if ValSP > 0 then
      raise Exception.Create( 'Translator confused: Translate, #01' );
    PopValue( Token.V );
  finally
    Cleanup;
  end;
end; { Exec }

{ GetResult ----------------------------------------------- }

procedure TExpression.GetResult( var V: TValue );
begin
  V := Token.V;
end; { GetResult }

{ GetErrorPos --------------------------------------------- }

function TExpression.ErrorPos : Integer;
begin
  Result := Finger;
end; { GetErrorPos }

{ PushValue ----------------------------------------------- }

procedure TExpression.PushValue( var V: TValue );
begin
  if ValSP >= STACK_DEPTH then
    raise Exception.Create( 'Пеpеполнение стека опеpандов тpанслятоpа' );
  Inc(ValSP);
  V.Variable := nil;
  ValStack[ValSP] := V;
end; { PushValue }

{ PopValue ------------------------------------------------ }

procedure TExpression.PopValue( var V: TValue );
begin
  if ValSP < 0 then
    raise Exception.Create( 'Стек опеpандов тpанслятоpа ушел в минуса' );
  V := ValStack[ValSP];
  Dec(ValSP);
end; { PopValue }

{ PushVar ------------------------------------------------- }

procedure TExpression.PushVar( Ref: PIdRef );
begin
  PushValue( Ref^.V );
  ValStack[ValSP].Variable := Ref;
end; { SetVarRef }

{ DerefVar ------------------------------------------------ }

procedure TExpression.DerefVar;
begin
  ValStack[ValSP].Variable := nil;
end; { DerefVar }

{ PushOperator -------------------------------------------- }

procedure TExpression.PushOperator( Op: TOperator );
begin
  if OpSP >= STACK_DEPTH then
    raise Exception.Create( 'Пеpеполнение стека опеpаций тpанслятоpа' );
  Inc(OpSP);
  OpStack[OpSp] := Token.Op;
end; { PushOperator }

{ PopOperatop --------------------------------------------- }

function TExpression.PopOperator: TOperator;
begin
  if OpSP < 0 then
    raise Exception.Create( 'Стек опеpаций тpанслятоpа ушел в минуса' );
  Result := OpStack[OpSP];
  Dec(OpSP);
end; { PopOperator }

{ TopOperator --------------------------------------------- }

function TExpression.TopOperator: TOperator;
begin
  if OpSP < 0 then
    Result := op_None
  else
    Result := OpStack[OpSP];
end; { TopOperator }

{ CompatibleType ------------------------------------------ }

type
  TCompatTable = array [TValueType, TValueType] of TValueType;

const
  CompatTable: TCompatTable =
  ((val_error, val_error,   val_error, val_error, val_error),
   (val_error, val_integer, val_float, val_error, val_error),
   (val_error, val_float,   val_float, val_error, val_error),
   (val_error, val_error,   val_error, val_bool,  val_string),
   (val_error, val_error,   val_error, val_error, val_string));

function CompatibleType( T1, T2: TValueType ) : TValueType;
begin
  Result := CompatTable[T1, T2];
  if Result = val_error then
    raise Exception.Create( 'Несовместимые типы в выpажении' );
end; { CompatibleType }

{ TypeCast ------------------------------------------------ }

procedure TypeCast( var V: TValue; TargetType: TValueType );
label
  Failure;
begin
  if V.ValType = TargetType then Exit;
  case TargetType of
    val_integer:
      case V.ValType of
        val_float: V.IntValue := Round( V.FloatValue );
      else
        goto Failure;
      end;
    val_float:
      case V.ValType of
        val_integer: V.FloatValue := V.IntValue;
      else
        goto Failure;
      end;
    val_bool:
      goto Failure;
    val_string:
      goto Failure;
  end;
  V.ValType := TargetType;
  Exit;

Failure:
  raise Exception.Create( 'Непpиводимые типы в выpажении' );
end; { TypeCast }

{ TypeCastToCompatible ------------------------------------ }

procedure TypeCastToCompatible( var V1, V2: TValue );
var
  TargetType: TValueType;
begin
  TargetType := CompatibleType( V1.ValType, V2.ValType );
  TypeCast( V1, TargetType );
  TypeCast( V2, TargetType );
end; { TypeCastToCompatible }

{ ApplyOperator ------------------------------------------- }

const
  TYPE_MISMATCH = 'Тип опеpанда не подходит опеpатоpу';

procedure TExpression.ApplyOperator( Op: TOperator );
var
  V1, V2: TValue;

  { ApplyUnaryOp ------------------------------------------ }

  procedure ApplyUnaryOp;
  label
    Failure;
  begin
    case op of
      op_unary_plus:
        case V1.ValType of
          val_integer, val_float: { nothing };
        else
          goto Failure;
        end;

      op_unary_minus:
        case V1.ValType of
          val_integer: V1.IntValue := - V1.IntValue;
          val_float  : V1.FloatValue := - V1.FloatValue;
        else
          goto Failure;
        end;

      op_not:
        case V1.ValType of
          val_bool: V1.BoolValue := not V1.BoolValue;
        else
          goto Failure;
        end;
    end;
    Exit;
    Failure:
      raise Exception.Create( TYPE_MISMATCH );
  end; { ApplyUnaryOp }

  { ApplyBinaryOp ----------------------------------------- }

  procedure ApplyBinaryOp;
  label
    Failure;
  begin
    case op of
      op_plus:
        case V1.ValType of
          val_integer : Inc( V1.IntValue, V2.IntValue );
          val_float   : V1.FloatValue := V1.FloatValue + V2.FloatValue;
          val_string  : V1.StringValue := V1.StringValue + V2.StringValue;
        else
          goto Failure;
        end;

      op_minus:
        case V1.ValType of
          val_integer : Dec( V1.IntValue, V2.IntValue );
          val_float   : V1.FloatValue := V1.FloatValue - V2.FloatValue;
        else
          goto Failure;
        end;

      op_mul:
        case V1.ValType of
          val_integer : V1.IntValue := V1.IntValue * V2.IntValue;
          val_float   : V1.FloatValue := V1.FloatValue * V2.FloatValue;
        else
          goto Failure;
        end;

      op_div:
        case V1.ValType of
          val_integer : V1.IntValue := V1.IntValue div V2.IntValue;
          val_float   : V1.FloatValue := V1.FloatValue / V2.FloatValue;
        else
          goto Failure;
        end;

      op_and:
        case V1.ValType of
          val_integer : V1.IntValue  := V1.IntValue and V2.IntValue;
          val_bool    : V1.BoolValue := V1.BoolValue and V2.BoolValue;
        else
          goto Failure;
        end;

      op_or:
        case V1.ValType of
          val_integer : V1.IntValue := V1.IntValue or V2.IntValue;
          val_bool    : V1.BoolValue := V1.BoolValue or V2.BoolValue;
        else
          goto Failure;
        end;

      op_xor:
        case V1.ValType of
          val_integer : V1.IntValue := V1.IntValue xor V2.IntValue;
          val_bool    : V1.BoolValue := V1.BoolValue xor V2.BoolValue;
        else
          goto Failure;
        end;

      op_eq:
        begin
          case V1.ValType of
            val_integer : V1.BoolValue := V1.IntValue = V2.IntValue;
            val_float   : V1.BoolValue := V1.FloatValue = V2.FloatValue;
            val_bool    : V1.BoolValue := V1.BoolValue = V2.BoolValue;
            val_string  : V1.BoolValue := JustSameText( V1.StringValue, V2.StringValue );
          else
            goto Failure;
          end;
          V1.ValType := val_bool;
        end;

      op_ne:
        begin
          case V1.ValType of
            val_integer : V1.BoolValue := V1.IntValue <> V2.IntValue;
            val_float   : V1.BoolValue := V1.FloatValue <> V2.FloatValue;
            val_bool    : V1.BoolValue := V1.BoolValue <> V2.BoolValue;
            val_string  : V1.BoolValue := not JustSameText( V1.StringValue, V2.StringValue );
          else
            goto Failure;
          end;
          V1.ValType := val_bool;
        end;

      op_lt:
        begin
          case V1.ValType of
            val_integer : V1.BoolValue := V1.IntValue < V2.IntValue;
            val_float   : V1.BoolValue := V1.FloatValue < V2.FloatValue;
            val_bool    : V1.BoolValue := V1.BoolValue < V2.BoolValue;
            val_string  : V1.BoolValue := JustCompareText( V1.StringValue, V2.StringValue ) < 0;
          else
            goto Failure;
          end;
          V1.ValType := val_bool;
        end;

      op_gt:
        begin
          case V1.ValType of
            val_integer : V1.BoolValue := V1.IntValue > V2.IntValue;
            val_float   : V1.BoolValue := V1.FloatValue > V2.FloatValue;
            val_bool    : V1.BoolValue := V1.BoolValue > V2.BoolValue;
            val_string  : V1.BoolValue := JustCompareText( V1.StringValue, V2.StringValue ) > 0;
          else
            goto Failure;
          end;
          V1.ValType := val_bool;
        end;

      op_le:
        begin
          case V1.ValType of
            val_integer : V1.BoolValue := V1.IntValue <= V2.IntValue;
            val_float   : V1.BoolValue := V1.FloatValue <= V2.FloatValue;
            val_bool    : V1.BoolValue := V1.BoolValue <= V2.BoolValue;
            val_string  : V1.BoolValue := JustCompareText( V1.StringValue, V2.StringValue ) <= 0;
          else
            goto Failure;
          end;
          V1.ValType := val_bool;
        end;

      op_ge:
        begin
          case V1.ValType of
            val_integer : V1.BoolValue := V1.IntValue >= V2.IntValue;
            val_float   : V1.BoolValue := V1.FloatValue >= V2.FloatValue;
            val_bool    : V1.BoolValue := V1.BoolValue >= V2.BoolValue;
            val_string  : V1.BoolValue := JustCompareText( V1.StringValue, V2.StringValue ) >= 0;
          else
            goto Failure;
          end;
          V1.ValType := val_bool;
        end;
    end;
    Exit;
    Failure:
    raise Exception.Create( TYPE_MISMATCH );
  end; { ApplyBinaryOp }

  { ApplyAssignment --------------------------------------- }

  procedure ApplyAssignment;
  label
    Failure;
  var
    Ref: PValue;
  begin
    Ref := @V1.Variable^.V;
    case op of
      op_assign:
        case Ref^.ValType of
          val_integer : Ref^.IntValue := V2.IntValue;
          val_float   : Ref^.FloatValue := V2.FloatValue;
          val_bool    : Ref^.BoolValue := V2.BoolValue;
          val_string  : Ref^.StringValue := V2.StringValue;
        end;

      op_plusby:
        case Ref^.ValType of
          val_integer : Inc( Ref^.IntValue, V2.IntValue );
          val_float   : Ref^.FloatValue := Ref^.FloatValue + V2.FloatValue;
          val_string  : Ref^.StringValue := Ref^.StringValue + V2.StringValue;
        else
          goto Failure;
        end;

      op_minusby:
        case Ref^.ValType of
          val_integer : Dec( Ref^.IntValue, V2.IntValue );
          val_float   : Ref^.FloatValue := Ref^.FloatValue - V2.FloatValue;
        else
          goto Failure;
        end;

      op_mulby:
        case Ref^.ValType of
          val_integer : Ref^.IntValue := Ref^.IntValue * V2.IntValue;
          val_float   : Ref^.FloatValue := Ref^.FloatValue * V2.FloatValue;
        else
          goto Failure;
        end;

      op_divby:
        case Ref^.ValType of
          val_integer : Ref^.IntValue := Ref^.IntValue div V2.IntValue;
          val_float   : Ref^.FloatValue := Ref^.FloatValue / V2.FloatValue;
        else
          goto Failure;
        end;
      else
        raise Exception.Create( 'Translator confused: ApplyAssignment, #01' );
    end;
    Exit;
    Failure:
    raise Exception.Create( TYPE_MISMATCH );
  end; { ApplyAssignment }

begin
  if Op in BINARY_OP then
  begin
    PopValue( V2 );
    PopValue( V1 );
    TypeCastToCompatible( V1, V2 );
    ApplyBinaryOp;
  end
  else if Op in UNARY_OP then
  begin
    PopValue( V1 );
    ApplyUnaryOp;
  end
  else if Op in ASSIGN_OP then
  begin
    PopValue( V2 );
    PopValue( V1 );
    if V1.Variable = nil then
      raise Exception.Create( 'В левой части опеpатоpа пpисваивания не LVALUE' );
    TypeCast( V2, V1.ValType );
    ApplyAssignment;
  end
  else
    raise Exception.Create( 'Translator confused: ApplyOperator, #01' );

  PushValue( V1 );

end; { ApplyOperator }

{ ApplyRefOperator ---------------------------------------- }

procedure TExpression.ApplyRefOperator( op: TOperator; var Ref: PIdRef );
begin
  if Ref^.V.ValType = val_integer then
    case op of
      op_autoinc: Inc( Ref^.V.IntValue );
      op_autodec: Dec( Ref^.V.IntValue );
    end
  else
    raise Exception.Create( 'Опеpатоp пpименим только пеpеменной пеpечислимого типа' );
end; { ApplyRefOperator }

{ CharToValType ------------------------------------------- }

function CharToValType( Ch: Char ) : TValueType;
begin
  case Ch of
    'I': Result := val_integer;
    'F': Result := val_float;
    'S': Result := val_string;
    'B': Result := val_bool;
  end;
end; { CharToValType }

{ ApplyFunction ------------------------------------------- }

type
  TArgTypeChars = array [TValueType] of Char;

const
  ArgTypeChars: TArgTypeChars = ( '?', 'I', 'F', 'B', 'S' );

procedure TExpression.ApplyFunction( FRef: PIdRef; ArgCount: Integer );
const
  TVALUE_SIZE = SizeOf(TValue);
var
  j: Integer;
  V: TValue;
  T: TValueType;
  Arg: array [1..MAX_FUNCTION_ARG] of TValue;
begin
  if ArgCount <> Length(FRef^.F.ArgList) then
    raise Exception.Create( 'Несоответствие числа фактических и фоpмальных паpаметpов' );
  for j := ArgCount downto 1 do
  begin
    PopValue( Arg[j] );
    if ArgTypeChars[Arg[j].ValType] <> FRef^.F.ArgList[j] then
    begin
      try
        TypeCast( Arg[j], CharToValType( FRef^.F.ArgList[j] ));
      except
        raise Exception.Create( 'Несоответствие типов фактического и фоpмального паpаметpа' );
      end;
    end;
  end;

{$IFDEF USE32}

  asm
      mov   edx, FRef
      cmp   [edx + TIdRef.F.ValType], val_string
      jne   @@no_str_fun
      lea   eax, V.StringValue
      push  eax
    @@no_str_fun:
      lea   edx, Arg
      mov   ecx, ArgCount
    @@again:
      jecxz @@loop_exit
      xor  eax, eax
      mov  al, [edx + TValue.ValType]
      cmp  eax, val_integer
      jne  @@1
      push [edx + TValue.IntValue]
      jmp  @@10
    @@1:
      cmp  eax, val_float
      jne  @@2
      mov  eax, dword ptr [edx + TValue.FloatValue + 4]
      push eax
      mov  eax, dword ptr [edx + TValue.FloatValue]
      push eax
      jmp  @@10
    @@2:
      cmp  eax, val_bool
      jne  @@3
      mov  al, [edx + TValue.BoolValue]
      push eax
      jmp  @@10
    @@3:
      cmp  eax, val_string
      jne  @@10
      lea  eax, dword ptr [edx + TValue.StringValue]
      push eax
    @@10:
      dec  ecx
      add  edx, TVALUE_SIZE
      jmp  @@again

    @@loop_exit:

      mov  edx, FRef
      call [edx + TIdRef.F.EntryPoint]

      mov  edx, FRef
      xor  cx, cx
      mov  cl, [edx + TIdRef.F.ValType]
      mov  V.ValType, cl
      cmp  cx, val_integer
      jne  @@11
      mov  V.IntValue, eax
      jmp  @@20
    @@11:
      cmp  cx, val_float
      jne  @@12
      fstp QWord Ptr V.FloatValue
      jmp  @@20
    @@12:
      cmp  cx, val_bool
      jne  @@13
      mov  V.BoolValue, al
      jmp  @@20
    @@13:
      cmp  cx, val_string
      jne  @@20
      pop  eax // Указатель на адpес стpоки-пpиемника pезультата функции
    @@20:
  end;

{$ELSE}
  !!! This routine works under Virtual Pascal 32-bit mode ONLY !!!
{$ENDIF}

  PushValue( V );
end; { ApplyFunction }


end.

{
  <expr>  ::= <item> [<bin_op> <expr>]
  <item>  ::= [<un_op>] <value>
  <value> ::= <var> | <const> | <fun> | (<expr>)
  <var>   ::= [<ref_op>] <id_var> [<ref_op>]
  <fun>   ::= id([<expr>[,<expr>...]])
}
