unit uCommons;

interface

uses
  System.SysUtils,
  System.Types,
  System.UITypes,
  System.Classes,
  System.Variants,
  System.Math,
  System.Math.Vectors,
  Winapi.Windows,
  Winapi.Messages,
  FMX.Types,
  FMX.Graphics,
  FMX.Controls,
  FMX.Forms;

const
  C_BackgroundColor = TAlphaColor($16253d);  // R,G,B = 22,37,61

type
  TVectorHelper = record helper for TVector
    function Length: Single;
    function Normalize: TVector;
    function Limit(AMax: Single): TVector;
  end;

  { MousePosChecker }

  TFormHelper = class helper for TCommonCustomForm
  public
    function IsMouseInside(): Boolean;
  end;

  TControlHelper = class helper for TControl
  public
    function IsMouseInside(): Boolean;
    procedure SetDragCursor(const AIsDragging: Boolean; const ATag: Boolean = True);
  end;

type
  IIF = class
    class function CastBool<T>(AExpression: Boolean; const ATrue, AFalse: T): T; static;
  end;

procedure Global_TrimAppMemorySizeEx(const AStrategy: Integer);
function Clamp(const Value, Min, Max: Integer): Integer;
function ClampD(const Value, Min, Max: Single): Single;
function OneDiv(aPoint: TPointF): TPointF;
function LerpAngle(Current, Target, Amount: Double): Double; inline;
function IsVectorEmpty(const V: TVector): Boolean; inline;
function Limit_Point(V: TPointF; Max: Single): TPointF;
function Set_Mag(V: TPointF; Mag: Single): TPointF;
function GetColorFromHSL(AHH, ASS, ALL: Single): TAlphaColor;
function GetDirectionColor(Theta: Double): TAlphaColor;
function CaptureComponent(const AControl: TControl; const ASavefile: string): Boolean;

function  ReadAllText_Unicode(const AFilePath: string=''): string;
function  WriteAllText_Unicode(const AFilePath, AContents: string): Boolean;

implementation

uses
  SYstem.UIConsts;

{ Global_TrimAppMemorySizeEx }

procedure Global_TrimAppMemorySizeEx(const AStrategy: Integer);
begin
  if AStrategy = 0 then
  begin
    var _MainHandle: THandle := Winapi.Windows.OpenProcess(PROCESS_ALL_ACCESS, False, Winapi.Windows.GetCurrentProcessID);
    if _MainHandle > 0 then
    try
      Winapi.Windows.SetProcessWorkingSetSize(_MainHandle, High(SIZE_T), High(SIZE_T));   // Win64
    finally
      Winapi.Windows.CloseHandle(_MainHandle);
    end;
  end;
  Application.ProcessMessages;
end;

{ MousePosChecker }

function TFormHelper.IsMouseInside(): Boolean;
begin
  // 1. Get the current mouse position relative to the screen.
  var _MousePos: TPointF := Screen.MousePos;
  // 2. Convert the screen coordinates to local coordinates relative to the current form.
  var _RelativePos: TPointF := Self.ScreenToClient(_MousePos);
  // 3. Check if the converted coordinates are within the form's client area (0, 0, Width, Height).
  // TRectF.Contains returns True if the point is within the rectangle.
  Result := TRectF.Create(0, 0, Self.ClientWidth, Self.ClientHeight).Contains(_RelativePos);
end;

{ TControlHelper }

function TControlHelper.IsMouseInside(): Boolean;
begin
  var _MousePos: TPointF := Screen.MousePos;
  var _LocalPos: TPointF := Self.ScreenToLocal(_MousePos);
  Result := TRectF.Create(0, 0, Self.Width, Self.Height).Contains(_LocalPos);
end;

procedure TControlHelper.SetDragCursor(const AIsDragging: Boolean; const ATag: Boolean);
begin
  var _dragcursor: TCursor := IIF.CastBool<TCursor>(ATag, crDrag, crHandPoint);
  Self.Cursor := IIF.CastBool<TCursor>(AIsDragging, _dragcursor, crDefault);
end;

{ TVectorHelper }

{ Helper function to create TVector with X, Y, W (Delphi 12 Athens standard) }
function Vec(const X, Y: Single; const W: Single = 0): TVector; inline;
begin
  { Based on the user's definition: TVector = (X, Y, W) }
  Result := TVector.Create(X, Y, W);
end;

{ IIF.Cast ... }

class function IIF.CastBool<T>(AExpression: Boolean; const ATrue, AFalse: T): T;
begin
  if AExpression
    then Result := ATrue
    else Result := AFalse;
end;

function Clamp(const Value, Min, Max: Integer): Integer;
begin
  if Value < Min then Result := Min else
  if Value > Max then Result := Max
  else Result := Value;
end;

function ClampD(const Value, Min, Max: Single): Single;
begin
  if Value < Min then Result := Min else
  if Value > Max then Result := Max
  else Result := Value;
end;

function OneDiv(aPoint: TPointF): TPointF;
begin
  var _Q := aPoint;
  if _Q.X = 0.0 then _Q.X := 1E-5;
  if _Q.Y = 0.0 then _Q.Y := 1E-5;
  Result := PointF(1 / Abs(_Q.X), 1 / Abs(_Q.Y));
end;

function LerpAngle(Current, Target, Amount: Double): Double;
begin
  var _Diff: Double := Target - Current;
  // Normalize the angle difference to the range -Pi to Pi
  while _Diff < -Pi do _Diff := _Diff + 2 * Pi;
  while _Diff > Pi do _Diff := _Diff - 2 * Pi;

  Result := Current + _Diff * Amount;
end;

{ Safe check if a vector is near zero length }
function IsVectorEmpty(const V: TVector): Boolean; inline;
begin
  Result := (Abs(V.X) < 1E-6) and (Abs(V.Y) < 1E-6);
end;

function TVectorHelper.Length: Single;
begin
  Result := Sqrt(Sqr(Self.X) + Sqr(Self.Y));
end;

function TVectorHelper.Normalize: TVector;
begin
  var _L: Single := Self.Length;
  if _L > 0 then
  begin
    Result.X := Self.X / _L;
    Result.Y := Self.Y / _L;
    Result.W := 1.0;
  end
  else
    Result := Self;
end;

function TVectorHelper.Limit(AMax: Single): TVector;
begin
  var _L: Single := Self.Length;
  if _L > AMax then
  begin
    Result := Self.Normalize * AMax;
    Result.W := 1.0;
  end
  else
    Result := Self;
end;

{ Functions ... }

function Limit_Point(V: TPointF; Max: Single): TPointF;
begin
  var MagSq: Single := V.X * V.X + V.Y * V.Y;
  if MagSq > Max * Max then
    Result := V.Normalize * Max
  else
    Result := V;
end;

function Set_Mag(V: TPointF; Mag: Single): TPointF;
begin
  Result := V.Normalize * Mag;
end;

function GetColorFromHSL(AHH, ASS, ALL: Single): TAlphaColor;
begin
  Result := HSLtoRGB(AHH, ASS, ALL);
end;

function GetDirectionColor(Theta: Double): TAlphaColor;
var
  _R, _G, _B: Byte;
begin
  var _Hue: Double := (Theta + Pi) / (2 * Pi);
  if _Hue < 0.33 then
    begin
      _R := 255;
      _G := Clamp(Round(_Hue*765), 0, 255);
      _B := 0;
    end else
  if _Hue < 0.66 then
    begin
      _R := 0;
      _G := 255;
      _B := Clamp(Round((_Hue - 0.33) * 765), 0, 255);
    end
  else
    begin
      _R := Clamp(Round((1 - _Hue) * 765), 0, 255);
      _G := 0;
      _B := 255;
    end;

  Result := TAlphaColorRec.Alpha or (_R shl 16) or (_G shl 8) or _B;
end;

function CaptureComponent(const AControl: TControl; const ASavefile: string): Boolean;
begin
  Result := False;
  var LScreenshot: TBitmap := AControl.MakeScreenshot;
  try
    // reserved ... Image1.Bitmap.Assign(LScreenshot);
    LScreenshot.SaveToFile(ASavefile);
    Result := FileExists(ASavefile);
  finally
    LScreenshot.Free;
  end;
end;

function ReadAllText_Unicode(const AFilePath: string=''): string;
begin
  Result := '';
  if FileExists(AFilePath) then
  begin
    var _strings: TStrings := TStringList.Create;
    try
      _strings.LoadFromFile(AFilePath);
      Result := _strings.Text;
    finally
      _strings.Free;
    end;
  end;
end;

function WriteAllText_Unicode(const AFilePath, AContents: string): Boolean;
begin
  Result := False;
  var _strings: TStrings := TStringList.Create;
  try
    _strings.Text := AContents;
    _strings.SaveToFile(AFilePath);
  finally
    _strings.Free;
  end;
  Result := FileExists(AFilePath);
end;

// Reserved ...
function CaptureForm(const AForm: TForm; const ASavefile: string): Boolean;
begin
  Result := False;
  var LScreenshot: TBitmap := TControl(AForm).MakeScreenshot;
  try
    LScreenshot.SaveToFile(ASavefile);
    Result := FileExists(ASavefile);
  finally
    LScreenshot.Free;
  end;
end;

end.
