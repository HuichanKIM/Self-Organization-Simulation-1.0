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
  System.UIConsts;

type
  TAlphaColorArray = array[0..0] of TAlphaColor;
  PAlphaColorArray = ^TAlphaColorArray;

  TFractalMode = (fmMandelbrot, fmJulia);

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
    //
    FJuliaCX, FJuliaCY: Double;
    //
    FNeedsUpdate: Boolean;
    procedure SetZoom(const Value: Double);
  public
    constructor Create(const AWidth, AHeight: Integer);
    destructor Destroy; override;
    procedure Render(ABitmap: TBitmap);
    procedure Move(const DX, DY: Double);
    procedure ZoomAt(const MouseX, MouseY, WheelDelta: Single; const ANeedUpdate: Boolean = True);
    //
    procedure Resize(const AWidth, AHeight: Single);
    procedure SetMouseInfo(const APos: TPointF; const AIsDown1, AIsDown2: Boolean);
    procedure SetMouseWheelInfo(const APos: TPointF; const AWheelDelta: Integer);
    procedure MoveByOffset(const ANewPos: TPointF);
    procedure UpdateFractal();
    function GetModeStatus: string;
    procedure Run(MainCanvas: TCanvas; const CW, CH: SIngle; const Trails: Boolean; const AMousePressed: Boolean; const AMousePos: TPointF);
    //
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

function Clamp(const Value, Min, Max: Integer): Integer;
begin
  if Value < Min then Result := Min else
  if Value > Max then Result := Max
  else
    Result := Value;
end;

{ TFractalEngine }

constructor TFractalEngine.Create(const AWidth, AHeight: Integer);
begin
  FWidth :=  AWidth;
  FHeight := AHeight;

  FMode :=    fmMandelbrot;
  FMaxIterations := 100;
  FZoom :=        1.0;
  FZoom_Rsv :=    1.0;
  FCenterX :=    -0.5;
  FCenterY :=     0;
  FCenterX_Rsv := FWidth / 2;;
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
    begin
      Move(APos.X - FWidth / 2, APos.Y - FHeight / 2);
    end else
  if AIsDown2 then
    begin
      if FMode = fmMandelbrot then
      begin
        FCenterX_Rsv := FCenterX;
        FCenterY_Rsv := FCenterY;
        FZoom_Rsv :=    Zoom;
        JuliaCX := (APos.X - FWidth / 2) *  (4.0 / (FWidth * Zoom)) +  CenterX;
        JuliaCY := (APos.Y - FHeight / 2) * (4.0 / (FHeight * Zoom)) + CenterY;
        Mode :=    fmJulia;
        Zoom :=    1.0;                                                       // Zoom reset when moving to Julia
        CenterX := 0;
        CenterY := 0;
      end
      else
      begin
        Mode := fmMandelbrot;
        Zoom := FZoom_Rsv;
        FCenterX := FCenterX_Rsv;
        FCenterY := FCenterY_Rsv;
      end;
    end
  else
    Exit;

  FNeedsUpdate := True;
end;

procedure TFractalEngine.SetMouseWheelInfo(const APos: TPointF; const AWheelDelta: Integer);
begin
  ZoomAt(APos.X, APos.Y, AWheelDelta);
  //FNeedsUpdate := True;
end;

procedure TFractalEngine.SetZoom(const Value: Double);
begin
  FZoom := Max(1E-14, Value);
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
  // Determining the position by Height
  var _OldMouseC_X := (MouseX - FWidth / 2) *  (4.0 / (FHeight * FZoom)) + FCenterX;
  var _OldMouseC_Y := (MouseY - FHeight / 2) * (4.0 / (FHeight * FZoom)) + FCenterY;

  var _ZoomFactor := 1.2;
  if WheelDelta > 0 then
    FZoom := FZoom * _ZoomFactor
  else
    FZoom := FZoom / _ZoomFactor;

  FMaxIterations := Clamp(Round(100 + Log10(FZoom + 1) * 25), 80, 300);
  FCenterX := _OldMouseC_X - (MouseX - FWidth / 2) *  (4.0 / (FHeight * FZoom)); // recalc the center with Height only
  FCenterY := _OldMouseC_Y - (MouseY - FHeight / 2) * (4.0 / (FHeight * FZoom));

  FNeedsUpdate := ANeedUpdate;
end;

procedure TFractalEngine.Render(ABitmap: TBitmap);
begin
  var _BaseR: Byte := 22;
  var _BaseG: Byte := 37;
  var _BaseB: Byte := 61;
  var _Data: TBitmapData;
  var _ZX, _ZY, _CX, _CY, _TempX, _ZX2, _ZY2: Double;

  if ABitmap.Map(TMapAccess.Write, _Data) then
  try
    var _InvZoom := 4.0 / (FHeight * FZoom);                                     // Determining the scale by Height (square format core)
    var _Iter: Integer := 0;
    var _Scanline: PAlphaColorArray := nil;
    var _Color: TAlphaColor := TAlphaColorRec.White;
    for var _Y := 0 to FHeight - 1 do
    begin
      _Scanline := PAlphaColorArray(_Data.GetScanline(_Y));

      for var _X := 0 to FWidth - 1 do
      begin
        if FMode = fmMandelbrot then
        begin
          // Mandelbrot: Z0 = 0, C = pixel coord
          _CX := (_X - FWidth / 2) * _InvZoom + FCenterX;
          _CY := (_Y - FHeight / 2) * _InvZoom + FCenterY;
          _ZX := 0; _ZY := 0;
        end
        else
        begin
          // Julia: Z0 = pixel coord, C = constant
          _CX := FJuliaCX;
          _CY := FJuliaCY;
          _ZX := (_X - FWidth / 2) * _InvZoom + FCenterX;
          _ZY := (_Y - FHeight / 2) * _InvZoom + FCenterY;
        end;

        _Iter := 0;
        _ZX2 := _ZX * _ZX;
        _ZY2 := _ZY * _ZY;

        while (_ZX2 + _ZY2 <= 4) and (_Iter < FMaxIterations) do
        begin
          _TempX := _ZX2 - _ZY2 + _CX;
          _ZY := 2 * _ZX * _ZY + _CY;
          _ZX := _TempX;
          _ZX2 := _ZX * _ZX;
          _ZY2 := _ZY * _ZY;
          Inc(_Iter);
        end;

        if _Iter = FMaxIterations then
          _Color := MakeColor(_BaseR, _BaseG, _BaseB, 255)
        else
          begin
            _Color := MakeColor(
              Clamp(Round(_BaseR + 100 * Sin(_Iter * 0.3)), 0, 255),
              Clamp(Round(_BaseG + 100 * Sin(_Iter * 0.3 + 2)), 0, 255),
              Clamp(Round(_BaseB + 150 * Sin(_Iter * 0.3 + 4)), 0, 255),
              255
            );
          end;
        _Scanline[_X] := _Color;
      end;
    end;
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
  if Mode = fmMandelbrot then
    Result := 'Mode: Mandelbrot (Right-Click point to see Julia)'
  else
    Result := Format('Mode: Julia (C = %.4f + %.4fi, Right-Click to return)', [FJuliaCX, FJuliaCY]);
end;

procedure TFractalEngine.UpdateFractal();
begin
  if FBuffer.Canvas.BeginScene then
  try
    Render(FBuffer);
  finally
    FBuffer.Canvas.EndScene;
  end;
end;

procedure TFractalEngine.Run(MainCanvas: TCanvas; const CW, CH: SIngle; const Trails, AMousePressed: Boolean; const AMousePos: TPointF);
begin
  if (FBuffer.Width <> Round(CW)) or (FBuffer.Height <> Round(CH)) then
   begin
     Resize(CW, CH);
     Exit;
   end;

   if FNeedsUpdate then
     try
       // ------------------------------------------------------------------- //
       UpdateFractal();
       // ------------------------------------------------------------------- //
       MainCanvas.DrawBitmap(FBuffer, TRectF.Create(0, 0, FBuffer.Width, FBuffer.Height), TRectF.Create(0, 0, CW, CH), 1.0);
     finally
       FNeedsUpdate := False;
     end
   else
     MainCanvas.DrawBitmap(FBuffer, TRectF.Create(0, 0, FBuffer.Width, FBuffer.Height), TRectF.Create(0, 0, CW, CH), 1.0);
end;

end.
