{******************************************************************************}
{                                                                              }
{                                PromiseResult                                 }
{                                                                              }
{             Copyright(c) 2025 Stefan van As <svanas@runbox.com>              }
{          Github Repository <https://github.com/svanas/PromiseResult>         }
{                                                                              }
{                        Distributed under GNU GPL v3.0                        }
{                                                                              }
{******************************************************************************}

unit PromiseResult;

interface

uses
  // Delphi
  System.SysUtils,
  // pas2js
  JS;

type
  TPromiseError = class
  strict protected
    FMessage: string;
  public
    constructor Create(const msg: string); overload;
    constructor Create(const msg: string; const args: array of const); overload;
    function Message: string; virtual;
  end;

  TPromiseResult<T> = class
  strict private
    type
      TSelf = TPromiseResult<T>;
    var
      FValue: T;
      FError: TPromiseError;
  public
    constructor Ok(const value: T);
    constructor Err(const error: TPromiseError);
    destructor Destroy; override;

    function IsResolved: Boolean;
    function IsRejected: Boolean;

    function ifResolved(const proc: TProc<T>): TSelf;
    function ifRejected(const proc: TProc<TPromiseError>): TSelf;
    procedure &else(const proc: TProc<T>); overload;
    procedure &else(const proc: TProc<TPromiseError>); overload;

    property Value: T read FValue;
    property Error: TPromiseError read FError;
  end;

  TPromise<T> = class
  public
    class function Execute(const F: TFunc<TJSPromise>): TJSPromise; static;
  end;

implementation

resourcestring
  RS_UNKNOWN_ERROR = 'an unknown error occurred';

{------------------------------- TPromiseError --------------------------------}

constructor TPromiseError.Create(const msg: string);
begin
  FMessage := msg;
end;

constructor TPromiseError.Create(const msg: string; const args: array of const);
begin
  FMessage := Format(msg, args);
end;

function TPromiseError.Message: string;
begin
  Result := FMessage;
end;

{----------------------------- TPromiseResult<T> ------------------------------}

constructor TPromiseResult<T>.Ok(const value: T);
begin
  FValue := value;
  FError := nil;
end;

constructor TPromiseResult<T>.Err(const error: TPromiseError);
begin
  FValue := Default(T);
  if Assigned(error) then
    FError := error
  else
    FError := TPromiseError.Create(RS_UNKNOWN_ERROR);
end;

destructor TPromiseResult<T>.Destroy;
begin
  if Assigned(FError) then FError.Free;
  inherited Destroy;
end;

function TPromiseResult<T>.IsResolved: Boolean;
begin
  Result := not IsRejected;
end;

function TPromiseResult<T>.IsRejected: Boolean;
begin
  Result := Assigned(FError);
end;

function TPromiseResult<T>.ifResolved(const proc: TProc<T>): TSelf;
begin
  Result := Self;
  if Self.IsResolved then proc(Self.Value);
end;

function TPromiseResult<T>.ifRejected(const proc: TProc<TPromiseError>): TSelf;
begin
  Result := Self;
  if Self.IsRejected then proc(Self.Error);
end;

procedure TPromiseResult<T>.&else(const proc: TProc<T>);
begin
  if Self.IsResolved then proc(Self.Value);
end;

procedure TPromiseResult<T>.&else(const proc: TProc<TPromiseError>);
begin
  if Self.IsRejected then proc(Self.Error);
end;

{-------------------------------- TPromise<T> ---------------------------------}

class function TPromise<T>.Execute(const F: TFunc<TJSPromise>): TJSPromise;

  procedure executor(resolve, _: TJSPromiseResolver); async;
  begin
    try
      resolve(TPromiseResult<T>.Ok(await(T, F)));
    except
      on E: TPromiseError do
        resolve(TPromiseResult<T>.Err(E));
      on E: Exception do
        resolve(TPromiseResult<T>.Err(TPromiseError.Create(E.Message)));
      on E: TJSError do
        resolve(TPromiseResult<T>.Err(TPromiseError.Create(E.Message)));
      else
        resolve(TPromiseResult<T>.Err(TPromiseError.Create(RS_UNKNOWN_ERROR)));
    end;
  end;

begin
  Result := TJSPromise.New(@executor);
end;

end.
