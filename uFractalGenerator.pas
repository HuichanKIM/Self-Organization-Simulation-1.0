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

type
  TAlphaColorArray = array [0..0] of TAlphaColor;
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
    procedure SetZoom(const Value: Double);
  public
    constructor Create(const AWidth, AHeight: Integer);
    destructor Destroy; override;
    procedure Render(ABitmap: TBitmap);
    procedure Move(const DX, DY: Double);
    procedure ZoomAt(const MouseX, MouseY, WheelDelta: Single; const ANeedUpdate: Boolean = True);
    procedure Resize(const AWidth, AHeight: Single);
    procedure SetMouseInfo(const APos: TPointF; const AIsDown1, AIsDown2: Boolean);
    procedure SetMouseWheelInfo(const APos: TPointF; const AWheelDelta: Integer);
    procedure MoveByOffset(const ANewPos: TPointF);
    procedure UpdateFractal();
    function GetModeStatus: string;
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
  uCommons;

{ TFractalEngine }

constructor TFractalEngine.Create(const AWidth, AHeight: Integer);
begin
  FWidth :=  AWidth;
  FHeight := AHeight;
  FMode :=    fm_Mandelbrot;
  FMaxIterations := 100;
  FZoom :=        1.0;
  FZoom_Rsv :=    1.0;
  FCenterX :=    -0.5;
  FCenterY :=     0;
  FCenterX_Rsv := FWidth / 2;
  FCenterY_Rsv := FHeight / 2;
  FJuliaCX :=    -0.7;
  FJuliaCY :=     0.27015;

  FBuffer := TBitmap.Create(Round(FWidth), Round(FHeight));
  FBuffer.Clear(TAlphaColorRec.Black);
  FNeedsUpdate := True;
end;

destructor TFractalEngine.Destroy;
begin
  FBuffer.Free;
  inherited;
end;

procedure TFractalEngine.SetMouseInfo(const APos: TPointF; const AIsDown1, AIsDown2: Boolean);
begin
  if AIsDown1 then
    Move(APos.X - FWidth / 2, APos.Y - FHeight / 2) else
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
      Mode := fm_Mandelbrot;
      Zoom := FZoom_Rsv;
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

procedure TFractalEngine.Move(const DX, DY: Double);
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

procedure TFractalEngine.Render(ABitmap: TBitmap);
begin
  var _BaseR: Byte := 22;
  var _BaseG: Byte := 37;
  var _BaseB: Byte := 61;
  var _InvZoom := 4.0 / (FHeight * FZoom);

  // Local copies for thread-safety in parallel loop
  var _LocalMode: TFractalMode := FMode;
  var _LocalJuliaCX := FJuliaCX;
  var _LocalJuliaCY := FJuliaCY;
  var _LocalMaxIter := FMaxIterations;
  var _LocalWidth :=   FWidth;
  var _LocalHeight :=  FHeight;
  var _LocalCenterX := FCenterX;
  var _LocalCenterY := FCenterY;

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
    begin
      _Scanline := PAlphaColorArray(_Data.GetScanline(_Y));

      for _X := 0 to _LocalWidth - 1 do
      begin
        if _LocalMode = fm_Mandelbrot then
          begin
            // Mandelbrot Set: Z_next = Z^2 + C where Z_0 = 0
            _CX := (_X - _LocalWidth / 2) * _InvZoom + _LocalCenterX;
            _CY := (_Y - _LocalHeight / 2) * _InvZoom + _LocalCenterY;
            _ZX := 0; _ZY := 0;
          end
        else
          begin
            // Julia Set: Z_next = Z^2 + C where C is constant
            _CX := _LocalJuliaCX;
            _CY := _LocalJuliaCY;
            _ZX := (_X - _LocalWidth / 2) * _InvZoom + _LocalCenterX;
            _ZY := (_Y - _LocalHeight / 2) * _InvZoom + _LocalCenterY;
          end;

        _Iter := 0;
        _ZX2 := _ZX * _ZX;
        _ZY2 := _ZY * _ZY;

        // Optimized inner escape loop
        while (_ZX2 + _ZY2 <= 4) and (_Iter < _LocalMaxIter) do
          begin
            _TempX := _ZX2 - _ZY2 + _CX;
            _ZY := 2 * _ZX * _ZY + _CY;
            _ZX := _TempX;
            _ZX2 := _ZX * _ZX;
            _ZY2 := _ZY * _ZY;
            Inc(_Iter);
          end;

        // Coloring based on iteration escape count
        if _Iter = _LocalMaxIter then
          _Color := MakeColor(_BaseR, _BaseG, _BaseB, 255)
        else
          begin
            _Color := MakeColor(
              Clamp(Round(_BaseR + 100 * Sin(_Iter * 0.3)),     0, 255),
              Clamp(Round(_BaseG + 100 * Sin(_Iter * 0.3 + 2)), 0, 255),
              Clamp(Round(_BaseB + 150 * Sin(_Iter * 0.3 + 4)), 0, 255),
              255
            );
          end;
        _Scanline[_X] := _Color;
      end;
    end);
  finally
    ABitmap.Unmap(_Data);
  end;
end;

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
