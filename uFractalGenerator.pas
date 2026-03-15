unit uFractalGenerator;

interface

uses
  System.SysUtils,
  System.Types,
  System.UITypes,
  System.Classes,
  System.Math,
  FMX.Types,
  FMX.Controls,
  FMX.Forms,
  FMX.Graphics,
  FMX.Objects,
  System.UIConsts,
  System.Threading; // Added for TParallel support

const
  PALETTE_SIZE = 4096; // Extended palette size for ultra-smooth color transitions

type
  TAlphaColorArray = array [0..65535] of TAlphaColor;
  PAlphaColorArray = ^TAlphaColorArray;

  TFractalMode = (fm_Mandelbrot, fm_Julia);

  TFractalEngine = class
  private
    FBuffer: TBitmap;
    FWidth, FHeight: Integer;
    FMaxIterations: Integer;
    FZoom: Double;
    FZoom_Rsv: Double;
    FCenterX, FCenterY: Double;
    FCenterX_Rsv, FCenterY_Rsv: Double;
    FMode: TFractalMode;
    FJuliaCX, FJuliaCY: Double;
    FNeedsUpdate: Boolean;
    // Palette LUT (Look-Up Table)
    FPaletteBitmap: TBitmap;
    FPalette: array[0..PALETTE_SIZE - 1] of TAlphaColor;
    FSetColor: TAlphaColor;
    procedure LoadPaletteFromBitmap();
    procedure Render(ABitmap: TBitmap);
    procedure MoveByPos(const DX, DY: Double);
    procedure UpdateFractal();
    procedure SetZoom(const Value: Double);
    function LinearInterpolateColor(const StartColor, EndColor: TAlphaColor; const t: Double): TAlphaColor;
    procedure BuildMultiSpectrumPalette;
  public
    constructor Create(const AWidth, AHeight: Integer);
    destructor Destroy; override;

    function GetModeStatus: string;
    procedure ZoomAt(const MouseX, MouseY, WheelDelta: Single; const ANeedUpdate: Boolean = True);
    procedure Resize(const AWidth, AHeight: Single);
    procedure MoveByOffset(const ANewPos: TPointF);
    procedure SetMouseInfo(const APos: TPointF; const AIsDown1, AIsDown2: Boolean);
    procedure SetMouseWheelInfo(const APos: TPointF; const AWheelDelta: Integer);

    procedure Run(MainCanvas: TCanvas; const CW, CH: Single; const Trails, AMousePressed: Boolean; const AMousePos: TPointF);

    property NeedsUpdate: Boolean    read FNeedsUpdate    write FNeedsUpdate;
    property Zoom: Double            read FZoom           write SetZoom;
    property MaxIterations: Integer  read FMaxIterations  write FMaxIterations;
    property CenterX: Double         read FCenterX        write FCenterX;
    property CenterY: Double         read FCenterY        write FCenterY;
    property Mode: TFractalMode      read FMode           write FMode;
    property JuliaCX: Double         read FJuliaCX        write FJuliaCX;
    property JuliaCY: Double         read FJuliaCY        write FJuliaCY;
  end;

implementation

uses
  uCommons,
  uCyclicPalette,
  FMX.Utils;

{ TFractalEngine }

constructor TFractalEngine.Create(const AWidth, AHeight: Integer);
begin
  FWidth :=       AWidth;
  FHeight :=      AHeight;
  FMode :=        fm_Mandelbrot;

  FZoom :=        1.0;
  FZoom_Rsv :=    1.0;
  FCenterX :=    -0.5;
  FCenterY :=     0;
  FCenterX_Rsv := FWidth / 2;
  FCenterY_Rsv := FHeight / 2;
  FJuliaCX :=    -0.7;
  FJuliaCY :=     0.27015;
  FMaxIterations := 512;

  FSetColor := $FF16253D;    // Requested internal color
  LoadPaletteFromBitmap();

  FBuffer := FMX.Graphics.TBitmap.Create(Round(FWidth), Round(FHeight));
  FBuffer.Clear(TAlphaColorRec.Black);
  FNeedsUpdate := True;
end;

destructor TFractalEngine.Destroy;
begin
  FBuffer.Free;
  if Assigned(FPaletteBitmap) then FPaletteBitmap.Free;
  inherited;
end;

{ Build Fractal Palette ------------------------------------------------------ }

procedure TFractalEngine.LoadPaletteFromBitmap();
begin
  FPaletteBitmap := TCyclicGradientEngine.GenerateAndBitmap(400, 110, 5);
  if not Assigned(FPaletteBitmap) or (FPaletteBitmap.Width = 0) then
    begin
      BuildMultiSpectrumPalette;
      Exit;
    end;

  var _Data: TBitmapData;
  var _SampleX: Integer := 0;
  if FPaletteBitmap.Map(TMapAccess.Read, _Data) then
  try
    for var _i := 0 to PALETTE_SIZE - 1 do
    try
      // Map palette index to bitmap width (linear sampling)
      _SampleX := Round((_i / (PALETTE_SIZE - 1)) * (FPaletteBitmap.Width - 1));  // Keep Magin ...
      FPalette[_i] := _Data.GetPixel(_SampleX, _i mod 100);                       // FPaletteBitmap.Height / 2
    except
    end;
    FNeedsUpdate := True;
  finally
    FPaletteBitmap.Unmap(_Data);
  end;
end;

function TFractalEngine.LinearInterpolateColor(const StartColor, EndColor: TAlphaColor; const t: Double): TAlphaColor;
begin
  var _S := TAlphaColorRec(StartColor);
  var _E := TAlphaColorRec(EndColor);
  var _R := Clamp(Round(_S.R + (_E.R - _S.R) * t), 0, 255);
  var _G := Clamp(Round(_S.G + (_E.G - _S.G) * t), 0, 255);
  var _B := Clamp(Round(_S.B + (_E.B - _S.B) * t), 0, 255);

  Result := MakeColor(_R, _G, _B, 255);
end;

procedure TFractalEngine.BuildMultiSpectrumPalette;
var
  _Colors: array[0..5] of TAlphaColor;
begin
  // Defining a more diverse and vibrant 6-point color spectrum
  _Colors[0] := $FF00071A; // Near Black Blue
  _Colors[1] := $FF004E92; // Royal Blue
  _Colors[2] := $FFFFFFFF; // Pure White (High contrast highlight)
  _Colors[3] := $FFFFD700; // Golden Yellow
  _Colors[4] := $FFFF4500; // Orange Red
  _Colors[5] := $FF4B0082; // Indigo Purple

  var _t: Double := 0;
  for var _i := 0 to PALETTE_SIZE - 1 do  // Scale to 5 segments
  begin
    _t := (_i / (PALETTE_SIZE - 1)) * 5;
    if _t < 1 then FPalette[_i] := LinearInterpolateColor(_Colors[0], _Colors[1], _t) else
    if _t < 2 then FPalette[_i] := LinearInterpolateColor(_Colors[1], _Colors[2], _t - 1) else
    if _t < 3 then FPalette[_i] := LinearInterpolateColor(_Colors[2], _Colors[3], _t - 2) else
    if _t < 4 then FPalette[_i] := LinearInterpolateColor(_Colors[3], _Colors[4], _t - 3)
              else FPalette[_i] := LinearInterpolateColor(_Colors[4], _Colors[5], _t - 4);
  end;
end;

{ ... }

procedure TFractalEngine.Resize(const AWidth, AHeight: Single);
begin
  FWidth :=  Max(1, Round(AWidth));
  FHeight := Max(1, Round(AHeight));
  FBuffer.SetSize(Round(FWidth), Round(FHeight));
  FBuffer.Clear(TAlphaColorRec.Black);
  FNeedsUpdate := True;
end;

function TFractalEngine.GetModeStatus(): string;
begin
  Result := IIF.CastBool<string>(Mode = fm_Mandelbrot,
                                 Format('Mode: Mandelbrot Zoom %.2f', [Zoom]), // (Right-Click point to see Julia)',
                                 Format('Mode: Julia (C = %.4f + %.4fi)', [FJuliaCX, FJuliaCY]) );
end;

procedure TFractalEngine.SetMouseInfo(const APos: TPointF; const AIsDown1, AIsDown2: Boolean);
begin
  if AIsDown1 then
    MoveByPos(APos.X - FWidth / 2, APos.Y - FHeight / 2) else
  if AIsDown2 then
  begin
    if FMode = fm_Mandelbrot then
    begin
      // Save Mandelbrot state and switch to Julia mode
      FCenterX_Rsv := FCenterX;
      FCenterY_Rsv := FCenterY;
      FZoom_Rsv :=    Zoom;
      JuliaCX := (APos.X - FWidth / 2) *  (4.0 / (FHeight * Zoom)) + CenterX;
      JuliaCY := (APos.Y - FHeight / 2) * (4.0 / (FHeight * Zoom)) + CenterY;
      Mode :=    fm_Julia;
      Zoom :=    1.0;
      CenterX := 0;
      CenterY := 0;
    end
    else
    begin
      // Return to Mandelbrot mode
      Mode :=     fm_Mandelbrot;
      Zoom :=     FZoom_Rsv;
      FCenterX := FCenterX_Rsv;
      FCenterY := FCenterY_Rsv;
    end;
  end
  else Exit;

  FNeedsUpdate := True;
end;

procedure TFractalEngine.SetMouseWheelInfo(const APos: TPointF; const AWheelDelta: Integer);
begin
  ZoomAt(APos.X, APos.Y, AWheelDelta);
end;

procedure TFractalEngine.SetZoom(const Value: Double);
begin
  FZoom := Max(0.1, Value); //  Max(1E-14, Value);
end;

procedure TFractalEngine.MoveByOffset(const ANewPos: TPointF);
begin
  var _ViewScale: Double := 4.0 / (FHeight * FZoom);
  FCenterX := FCenterX - (ANewPos.X * _ViewScale);
  FCenterY := FCenterY - (ANewPos.Y * _ViewScale);
  FNeedsUpdate := True;
end;

procedure TFractalEngine.MoveByPos(const DX, DY: Double);
begin
  FCenterX := FCenterX + (DX * (4.0 / (FHeight * FZoom)));
  FCenterY := FCenterY + (DY * (4.0 / (FHeight * FZoom)));
end;

procedure TFractalEngine.ZoomAt(const MouseX, MouseY, WheelDelta: Single; const ANeedUpdate: Boolean = True);
begin
  // Calculate relative complex coordinates before zooming
  var _OldMouseC_X := (MouseX - FWidth / 2) *  (4.0 / (FHeight * FZoom)) + FCenterX;
  var _OldMouseC_Y := (MouseY - FHeight / 2) * (4.0 / (FHeight * FZoom)) + FCenterY;

  var _ZoomFactor := 1.2;
  if WheelDelta > 0 then
    Zoom := FZoom * _ZoomFactor
  else
    Zoom := FZoom / _ZoomFactor;

  // Increase iterations for deep zoom to maintain detail
  FMaxIterations := Clamp(Round(100 + Log10(FZoom + 1) * 25), 80, 500);

  // Recalculate center to keep the mouse point fixed during zoom
  FCenterX := _OldMouseC_X - (MouseX - FWidth / 2) *  (4.0 / (FHeight * FZoom));
  FCenterY := _OldMouseC_Y - (MouseY - FHeight / 2) * (4.0 / (FHeight * FZoom));

  FNeedsUpdate := ANeedUpdate;
end;

{ Render Fractal --------------------------------------------------------------}

procedure TFractalEngine.Render(ABitmap: TBitmap);
begin
  var _InvZoom := 4.0 / (FHeight * FZoom);
  // Local copies for thread-safety in parallel loop
  var _LocalMode: TFractalMode := FMode;
  var _LocalJuliaCX :=  FJuliaCX;
  var _LocalJuliaCY :=  FJuliaCY;
  var _LocalMaxIter :=  FMaxIterations;
  var _LocalWidth :=    FWidth;
  var _LocalHeight :=   FHeight;
  var _LocalCenterX :=  FCenterX;
  var _LocalCenterY :=  FCenterY;
  var _InnerSetColor := FSetColor;

  var _Data: TBitmapData;
  if ABitmap.Map(TMapAccess.Write, _Data) then
  try
    // Use TParallel.For for multi-core rendering by Y-axis (scanlines)
    TParallel.For(0, _LocalHeight - 1, procedure(_Y: Integer)
    var
      _X: Integer;
      _ZX, _ZY, _CX, _CY, _TempX, _ZX2, _ZY2: Double;
      _Iter: Integer;
      _Scanline: PAlphaColorArray;
      _Color: TAlphaColor;
      _PalIdx: Integer;
      _LogZ, _MValue, _SmoothIter: Double;
    begin
      _Scanline := PAlphaColorArray(_Data.GetScanline(_Y));

      for _X := 0 to _LocalWidth - 1 do
      begin
        if _LocalMode = fm_Mandelbrot then
          begin
            // Mandelbrot Set: Z_next = Z^2 + C where Z_0 = 0
            _CX := (_X - _LocalWidth / 2) *  _InvZoom + _LocalCenterX;
            _CY := (_Y - _LocalHeight / 2) * _InvZoom + _LocalCenterY;
            _ZX := 0; _ZY := 0;
          end
        else
          begin
            // Julia Set: Z_next = Z^2 + C where C is constant
            _CX := _LocalJuliaCX;
            _CY := _LocalJuliaCY;
            _ZX := (_X - _LocalWidth / 2) *  _InvZoom + _LocalCenterX;
            _ZY := (_Y - _LocalHeight / 2) * _InvZoom + _LocalCenterY;
          end;

        _Iter := 0;
        _ZX2 := _ZX * _ZX;
        _ZY2 := _ZY * _ZY;

        // Optimized inner fractal loop                                         // Escape radius 16.0 (R=4) for better smoothing consistency
        while (_ZX2 + _ZY2 <= 16.0) and (_Iter < _LocalMaxIter) do              // Escape radius 4 (squared = 16) for better smoothing
        begin
          _TempX := _ZX2 - _ZY2 + _CX;
          _ZY := 2.0 * _ZX * _ZY + _CY;
          _ZX := _TempX;
          _ZX2 := _ZX * _ZX;
          _ZY2 := _ZY * _ZY;
          Inc(_Iter);
        end;

        // Coloring based on iteration escape count
        if _Iter >= _LocalMaxIter then
          _Scanline[_X] := _InnerSetColor
        else
          begin
            // Smooth Coloring Algorithm
            _LogZ := System.Math.Log10(_ZX2 + _ZY2) / 2.0;
            _MValue := System.Math.Log10(_LogZ / System.Math.Log10(2.0)) / System.Math.Log10(2.0);
            _SmoothIter := _Iter + 1 - _MValue;

            // Map to Palette with controlled cycle speed
            _PalIdx := Round(_SmoothIter * 20.0) mod PALETTE_SIZE; { 2048 - 12.0, 4096 - 20.0 }
            if _PalIdx < 0 then _PalIdx := 0;

            _Scanline[_X] := FPalette[_PalIdx];
          end;
      end;
    end);
  finally
    ABitmap.Unmap(_Data);
  end;
end;

procedure TFractalEngine.UpdateFractal();
begin
  Render(FBuffer);
end;

procedure TFractalEngine.Run(MainCanvas: TCanvas; const CW, CH: Single; const Trails, AMousePressed: Boolean; const AMousePos: TPointF);
begin
  // Check for resolution changes
  if (FBuffer.Width <> Round(CW)) or (FBuffer.Height <> Round(CH)) then
  begin
    Resize(CW, CH);
    Exit;
  end;

  // 1. Trigger re-render only when parameters change ----------------------- //
  if FNeedsUpdate then
  begin
    UpdateFractal();
    FNeedsUpdate := False;
  end;
  // 2. Draw the processed fractal buffer to the main canvas ---------------- //
  MainCanvas.DrawBitmap(FBuffer, TRectF.Create(0, 0, FBuffer.Width, FBuffer.Height), TRectF.Create(0, 0, CW, CH), 1.0);
end;

end.
