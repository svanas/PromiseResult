# PromiseResult

`TPromiseResult<T>` is a new type for web applications made with [Delphi](https://www.embarcadero.com/products/delphi) and [TMS Web Core](https://www.tmssoftware.com/site/tmswebcore.asp).

## The problem

You can call `await()` on any function that returns a [TJSPromise](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Promise) and basically turn an asynchronous function call into a blocking function call.

When the promise gets resolved, `await()` will return the expected type and life is good. But when a promise gets rejected, [pas2js](https://wiki.freepascal.org/pas2js) will translate this into an exception.

There is nothing wrong with exceptions, but you do need to catch them in a `try..except` block or your web application will panic.

The bigger issue is that with web applications, everything is a `JSValue` and this includes exception objects. Your exception object could be derived from [Exception](https://docwiki.embarcadero.com/Libraries/Athens/en/System.SysUtils.Exception) or from [TJSError](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Error) or anything else. We don't know. This makes error handling prone to... errors.

## The solution

When you await for [TPromise&lt;T>.Execute()](https://github.com/svanas/PromiseResult/blob/main/PromiseResult.pas#L140) then this function will ALWAYS return a `TPromiseResult<T>`

You don't need a `try..except` block and neither do you need a lot of boiler code to get the error message, potentially not getting the error message at all.

If the promise got resolved, [TPromiseResult&lt;T>.IsResolved](https://github.com/svanas/PromiseResult/blob/main/PromiseResult.pas#L44) is True and you can get the return value via [TPromiseResult&lt;T>.Value](https://github.com/svanas/PromiseResult/blob/main/PromiseResult.pas#L52). But if the promise got rejected, [TPromiseResult&lt;T>.IsRejected](https://github.com/svanas/PromiseResult/blob/main/PromiseResult.pas#L45) is True and you can get the error message via [TPromiseResult&lt;T>.Error](https://github.com/svanas/PromiseResult/blob/main/PromiseResult.pas#L53):

```delphi
procedure TForm1.WebButton1Click(Sender: TObject);
var
  PR: TPromiseResult<string>;
begin
  PR := await(TPromiseResult<string>, TPromise<string>.Execute(@MyAsyncFunc));
  if PR.IsResolved then
    console.log('resolved: ' + PR.Value)
  else
    console.error('rejected: ' + PR.Error.Message);
end;
```

Then there are other methods such as [TPromiseResult&lt;T>.ifResolved](https://github.com/svanas/PromiseResult/blob/main/PromiseResult.pas#L47) and [TPromiseResult&lt;T>.ifRejected](https://github.com/svanas/PromiseResult/blob/main/PromiseResult.pas#L48) that allow for a functional programming style if you want. Here is an example:

```delphi
procedure TForm1.WebButton1Click(Sender: TObject);
begin
  await(TPromiseResult<string>, TPromise<string>.Execute(@MyAsyncFunc))
    .ifResolved(procedure(value: string)
    begin
      console.log('resolved: ' + value)
    end)
    .&else(procedure(error: TPromiseError)
    begin
       console.error('rejected: ' + error.Message);
    end);
end;
```

## Implementing a promise

If you ever find yourself in a promise executor and you need to reject the promise, you can create an Exception but if you are using PromiseResult in your project, it is recommended to do this:

```delphi
function MyAsyncFunc: TJSPromise;
begin
  Result := TJSPromise.New(
    procedure(resolve, reject: TJSPromiseResolver)
    begin
      reject(TPromiseError.Create('my error message'));
    end
  );
end;
```

## Custom errors

Creating a class that derives from `TPromiseError` allows for you to introduce your own custom errors. Here is an example:

```delphi
type
  TMyCustomError = class(TPromiseError)
  strict private
    FStatusCode: Integer;
  public
    constructor Create(const aMsg: string; const aStatusCode: Integer);
    function Message: string; override;
  end;

constructor TMyCustomError.Create(const aMsg: string; const aStatusCode: Integer);
begin
  inherited Create(aMsg);
  FStatusCode := aStatusCode;
end;

function TMyCustomError.Message: string;
begin
  Result := Format('%d: %s', [FStatusCode, FMessage]);
end;
```

Now that you have defined your own custom error, here is how to reject a promise:

```delphi
function MyAsyncFunc: TJSPromise;
begin
  Result := TJSPromise.New(
    procedure(_, reject: TJSPromiseResolver)
    begin
      reject(TMyCustomError.Create('my custom error message', 404));
    end
  );
end;
```
