{ NativeASM | Copyright (c) 2026 Selahattin Erkoc }
{ SPDX-License-Identifier: MIT }
program NativeAsmGuiDemo;

{$APPTYPE GUI}
{$R *.res}

uses
  System.SysUtils,
  Winapi.Windows,
  NativeAsm.Types,
  NativeAsm.Builder,
  NativeAsm.Extensions;

type
  TGuiApi = record
    GetModuleHandleW: Pointer;
    RegisterClassExW: Pointer;
    UnregisterClassW: Pointer;
    LoadCursorW: Pointer;
    CreateWindowExW: Pointer;
    ShowWindow: Pointer;
    UpdateWindow: Pointer;
    GetMessageW: Pointer;
    TranslateMessage: Pointer;
    DispatchMessageW: Pointer;
    DefWindowProcW: Pointer;
    MessageBoxW: Pointer;
    PostQuitMessage: Pointer;
  end;

const
  CWM_DESTROY = 2;
  CWM_COMMAND = 273;
  CButtonId = 1001;
  CCsRedraw = 3;
  CColorWindowBrush = 6;
  CIdcArrow = 32512;
  CCwUseDefault = -2147483647 - 1;
  CSwShow = 5;
  CMainStyle = $10CF0000;
  CChildStyle = $50000000;
  CButtonStyle = $50000001;
  CMbInfo = $40;
  CMbError = $10;
  CWcOffset = 96;
  CMsgOffset = 96;
  CHInstanceOffset = 176;
  CHWndOffset = 184;

var
  GClassName: UnicodeString;
  GWindowTitle: UnicodeString;
  GStaticClass: UnicodeString;
  GStaticText: UnicodeString;
  GButtonClass: UnicodeString;
  GButtonText: UnicodeString;
  GMessageTitle: UnicodeString;
  GMessageText: UnicodeString;
  GErrorRegister: UnicodeString;
  GErrorWindow: UnicodeString;
  GErrorButton: UnicodeString;
  GErrorLoop: UnicodeString;

function PtrValue(P: Pointer): Int64; inline;
begin
  Result := Int64(NativeUInt(P));
end;

function TextPtr(const S: UnicodeString): Int64; inline;
begin
  Result := Int64(NativeUInt(PWideChar(S)));
end;

function ResolveApi(Module: HMODULE; const Name: AnsiString): Pointer;
begin
  Result := GetProcAddress(Module, PAnsiChar(Name));
  if Result = nil then raise Exception.CreateFmt('API nicht gefunden: %s', [string(Name)]);
end;

procedure LoadApis(out Api: TGuiApi; out User32: HMODULE);
var
  Kernel32: HMODULE;
begin
  Kernel32 := GetModuleHandleW('kernel32.dll');
  if Kernel32 = 0 then raise Exception.Create('kernel32.dll nicht gefunden');
  User32 := LoadLibraryW('user32.dll');
  if User32 = 0 then raise Exception.Create('user32.dll konnte nicht geladen werden');
  Api.GetModuleHandleW := ResolveApi(Kernel32, 'GetModuleHandleW');
  Api.RegisterClassExW := ResolveApi(User32, 'RegisterClassExW');
  Api.UnregisterClassW := ResolveApi(User32, 'UnregisterClassW');
  Api.LoadCursorW := ResolveApi(User32, 'LoadCursorW');
  Api.CreateWindowExW := ResolveApi(User32, 'CreateWindowExW');
  Api.ShowWindow := ResolveApi(User32, 'ShowWindow');
  Api.UpdateWindow := ResolveApi(User32, 'UpdateWindow');
  Api.GetMessageW := ResolveApi(User32, 'GetMessageW');
  Api.TranslateMessage := ResolveApi(User32, 'TranslateMessage');
  Api.DispatchMessageW := ResolveApi(User32, 'DispatchMessageW');
  Api.DefWindowProcW := ResolveApi(User32, 'DefWindowProcW');
  Api.MessageBoxW := ResolveApi(User32, 'MessageBoxW');
  Api.PostQuitMessage := ResolveApi(User32, 'PostQuitMessage');
end;

function BuildWndProc(const Api: TGuiApi): TExecutableCode;
var
  B: TAsmBuilder;
begin
  B := TAsmBuilder.New;
  try
    B.Prolog(32)
     .Cmp(EDX, CWM_COMMAND)
     .J(cond_JE, 'command')
     .Cmp(EDX, CWM_DESTROY)
     .J(cond_JE, 'destroy')
     .J(cond_JMP, 'default')
     .Label_('command')
     .Mov(EAX, R8D)
     .And_(EAX, $FFFF)
     .Cmp(EAX, CButtonId)
     .J(cond_JNE, 'default')
     .Mov(RDX, TextPtr(GMessageText))
     .Mov(R8, TextPtr(GMessageTitle))
     .Mov(R9D, CMbInfo)
     .Call(Api.MessageBoxW)
     .Xor_(EAX, EAX)
     .J(cond_JMP, 'return')
     .Label_('destroy')
     .Xor_(ECX, ECX)
     .Call(Api.PostQuitMessage)
     .Xor_(EAX, EAX)
     .J(cond_JMP, 'return')
     .Label_('default')
     .Call(Api.DefWindowProcW)
     .Label_('return')
     .Epilog
     .Ret;
    Result := TExecutableCode.FromBuilder(B);
  finally
    B.Free;
  end;
end;

procedure EmitError(B: TAsmBuilder; const Api: TGuiApi; const LabelName: string; const ErrorText: UnicodeString; Code: Integer);
begin
  B.Label_(LabelName)
   .Xor_(ECX, ECX)
   .Mov(RDX, TextPtr(ErrorText))
   .Mov(R8, TextPtr(GMessageTitle))
   .Mov(R9D, CMbError)
   .Call(Api.MessageBoxW)
   .Mov(EAX, Code)
   .J(cond_JMP, 'exit');
end;

function BuildGuiMain(const Api: TGuiApi; WndProc: Pointer): TExecutableCode;
var
  B: TAsmBuilder;
  I: Integer;
begin
  B := TAsmBuilder.New;
  try
    B.Prolog(192)
     .Xor_(ECX, ECX)
     .Call(Api.GetModuleHandleW)
     .Mov(QWordPtr(ridRSP, CHInstanceOffset), RAX)
     .Xor_(EAX, EAX);
    for I := 0 to 9 do B.Mov(QWordPtr(ridRSP, CWcOffset + I * 8), RAX);
    B.Mov(EAX, 80)
     .Mov(DWordPtr(ridRSP, CWcOffset), EAX)
     .Mov(EAX, CCsRedraw)
     .Mov(DWordPtr(ridRSP, CWcOffset + 4), EAX)
     .Mov(RAX, PtrValue(WndProc))
     .Mov(QWordPtr(ridRSP, CWcOffset + 8), RAX)
     .Mov(RAX, QWordPtr(ridRSP, CHInstanceOffset))
     .Mov(QWordPtr(ridRSP, CWcOffset + 24), RAX)
     .Xor_(ECX, ECX)
     .Mov(EDX, CIdcArrow)
     .Call(Api.LoadCursorW)
     .Mov(QWordPtr(ridRSP, CWcOffset + 40), RAX)
     .Mov(RAX, CColorWindowBrush)
     .Mov(QWordPtr(ridRSP, CWcOffset + 48), RAX)
     .Mov(RAX, TextPtr(GClassName))
     .Mov(QWordPtr(ridRSP, CWcOffset + 64), RAX)
     .Lea(RCX, TMemory.Create(ridRSP, CWcOffset))
     .Call(Api.RegisterClassExW)
     .Test(EAX, EAX)
     .J(cond_JE, 'error_register')
     .Mov(RAX, CCwUseDefault)
     .Mov(QWordPtr(ridRSP, 32), RAX)
     .Mov(QWordPtr(ridRSP, 40), RAX)
     .Mov(EAX, 720)
     .Mov(QWordPtr(ridRSP, 48), RAX)
     .Mov(EAX, 420)
     .Mov(QWordPtr(ridRSP, 56), RAX)
     .Xor_(EAX, EAX)
     .Mov(QWordPtr(ridRSP, 64), RAX)
     .Mov(QWordPtr(ridRSP, 72), RAX)
     .Mov(RAX, QWordPtr(ridRSP, CHInstanceOffset))
     .Mov(QWordPtr(ridRSP, 80), RAX)
     .Xor_(EAX, EAX)
     .Mov(QWordPtr(ridRSP, 88), RAX)
     .Xor_(ECX, ECX)
     .Mov(RDX, TextPtr(GClassName))
     .Mov(R8, TextPtr(GWindowTitle))
     .Mov(R9D, CMainStyle)
     .Call(Api.CreateWindowExW)
     .Test(RAX, RAX)
     .J(cond_JE, 'error_window')
     .Mov(QWordPtr(ridRSP, CHWndOffset), RAX)
     .Mov(EAX, 130)
     .Mov(QWordPtr(ridRSP, 32), RAX)
     .Mov(EAX, 92)
     .Mov(QWordPtr(ridRSP, 40), RAX)
     .Mov(EAX, 460)
     .Mov(QWordPtr(ridRSP, 48), RAX)
     .Mov(EAX, 32)
     .Mov(QWordPtr(ridRSP, 56), RAX)
     .Mov(RAX, QWordPtr(ridRSP, CHWndOffset))
     .Mov(QWordPtr(ridRSP, 64), RAX)
     .Xor_(EAX, EAX)
     .Mov(QWordPtr(ridRSP, 72), RAX)
     .Mov(RAX, QWordPtr(ridRSP, CHInstanceOffset))
     .Mov(QWordPtr(ridRSP, 80), RAX)
     .Xor_(EAX, EAX)
     .Mov(QWordPtr(ridRSP, 88), RAX)
     .Xor_(ECX, ECX)
     .Mov(RDX, TextPtr(GStaticClass))
     .Mov(R8, TextPtr(GStaticText))
     .Mov(R9D, CChildStyle)
     .Call(Api.CreateWindowExW)
     .Mov(EAX, 270)
     .Mov(QWordPtr(ridRSP, 32), RAX)
     .Mov(EAX, 180)
     .Mov(QWordPtr(ridRSP, 40), RAX)
     .Mov(QWordPtr(ridRSP, 48), RAX)
     .Mov(EAX, 52)
     .Mov(QWordPtr(ridRSP, 56), RAX)
     .Mov(RAX, QWordPtr(ridRSP, CHWndOffset))
     .Mov(QWordPtr(ridRSP, 64), RAX)
     .Mov(EAX, CButtonId)
     .Mov(QWordPtr(ridRSP, 72), RAX)
     .Mov(RAX, QWordPtr(ridRSP, CHInstanceOffset))
     .Mov(QWordPtr(ridRSP, 80), RAX)
     .Xor_(EAX, EAX)
     .Mov(QWordPtr(ridRSP, 88), RAX)
     .Xor_(ECX, ECX)
     .Mov(RDX, TextPtr(GButtonClass))
     .Mov(R8, TextPtr(GButtonText))
     .Mov(R9D, CButtonStyle)
     .Call(Api.CreateWindowExW)
     .Test(RAX, RAX)
     .J(cond_JE, 'error_button')
     .Mov(RCX, QWordPtr(ridRSP, CHWndOffset))
     .Mov(EDX, CSwShow)
     .Call(Api.ShowWindow)
     .Mov(RCX, QWordPtr(ridRSP, CHWndOffset))
     .Call(Api.UpdateWindow)
     .Label_('message_loop')
     .Lea(RCX, TMemory.Create(ridRSP, CMsgOffset))
     .Xor_(EDX, EDX)
     .Xor_(R8D, R8D)
     .Xor_(R9D, R9D)
     .Call(Api.GetMessageW)
     .Cmp(EAX, 0)
     .J(cond_JL, 'error_loop')
     .J(cond_JE, 'done')
     .Lea(RCX, TMemory.Create(ridRSP, CMsgOffset))
     .Call(Api.TranslateMessage)
     .Lea(RCX, TMemory.Create(ridRSP, CMsgOffset))
     .Call(Api.DispatchMessageW)
     .J(cond_JMP, 'message_loop')
     .Label_('done')
     .Mov(RAX, QWordPtr(ridRSP, CMsgOffset + 16))
     .Mov(QWordPtr(ridRSP, CHWndOffset), RAX)
     .Mov(RCX, TextPtr(GClassName))
     .Mov(RDX, QWordPtr(ridRSP, CHInstanceOffset))
     .Call(Api.UnregisterClassW)
     .Mov(RAX, QWordPtr(ridRSP, CHWndOffset))
     .J(cond_JMP, 'exit');
    EmitError(B, Api, 'error_register', GErrorRegister, 1);
    EmitError(B, Api, 'error_window', GErrorWindow, 2);
    EmitError(B, Api, 'error_button', GErrorButton, 3);
    EmitError(B, Api, 'error_loop', GErrorLoop, 4);
    B.Label_('exit').Epilog.Ret;
    Result := TExecutableCode.FromBuilder(B);
  finally
    B.Free;
  end;
end;

var
  Api: TGuiApi;
  User32: HMODULE;
  WndCode: TExecutableCode;
  GuiCode: TExecutableCode;
begin
  User32 := 0;
  WndCode := nil;
  GuiCode := nil;
  GClassName := 'NativeAsm.Generated.Gui';
  GWindowTitle := 'NativeAsm - GUI aus generiertem x64-Code';
  GStaticClass := 'STATIC';
  GStaticText := 'Fenster, Controls, Message-Loop und WndProc laufen im NativeAsm-JIT-Code.';
  GButtonClass := 'BUTTON';
  GButtonText := 'OK - NativeAsm';
  GMessageTitle := 'NativeAsm';
  GMessageText := 'Der Button-Handler und dieser WinAPI-Aufruf kommen aus NativeAsm-generiertem x64-Code.';
  GErrorRegister := 'RegisterClassExW ist im generierten Code fehlgeschlagen.';
  GErrorWindow := 'CreateWindowExW fuer das Hauptfenster ist im generierten Code fehlgeschlagen.';
  GErrorButton := 'CreateWindowExW fuer den Button ist im generierten Code fehlgeschlagen.';
  GErrorLoop := 'GetMessageW hat im generierten Code einen Fehler geliefert.';
  try
    LoadApis(Api, User32);
    WndCode := BuildWndProc(Api);
    GuiCode := BuildGuiMain(Api, WndCode.EntryPoint);
    GuiCode.Run;
  except
    on E: Exception do Winapi.Windows.MessageBoxW(0, PWideChar(E.Message), 'NativeAsm Bootstrap', CMbError);
  end;
  GuiCode.Free;
  WndCode.Free;
  if User32 <> 0 then FreeLibrary(User32);
end.
