unit uVicsekSim0;

interface

uses
  System.SysUtils,
  System.Types,
  System.UITypes,
  System.Classes,
  System.Variants,
  System.Math,
  System.Math.Vectors,
  System.Threading,    // Added for TParallel
  FMX.Types,
  FMX.Controls,
  FMX.Forms,
  FMX.Graphics,
  FMX.Dialogs,
  System.Generics.Collections;

type
  { Record representing an individual particle }
  TParticle = record
    X, Y: Double;      // Position
    Theta: Double;     // Movement Angle (Vector)
  end;

  { Simulation Engine }
  TVicsekEngine0 = class
  private
    FLockFlag: Boolean;
    FParticles: array of TParticle;
    FBuffer: TBitmap;
    FWidth, FHeight: Single;
    //
    FParticleCount: Integer;
    FRadius: Double;
    FVelocity: Double;
    FNoise: Double;
    FTailOp: Single;
    //
    FMousePos: TPointF;
    FIsMouseDown: Boolean;
    const MOUSE_INFLUENCE_RADIUS = 100.0;
    procedure SetParticleCount(const Value: Integer);
    procedure InitParticles(const PatCount: Integer);
  public
    constructor Create(AWidth, AHeight: Single; ACount: Integer);
    destructor Destroy; override;
    //
    procedure UpdateBuffer(const AFlag: Boolean = False);
    procedure Resize(AWidth, AHeight: Single);
    procedure UpdatePhysics(const AMousePressed: Boolean; const AMousePos: TPointF);
    procedure Run(MainCanvas: TCanvas; const CW, CH: Single; const Trails: Boolean; const AMousePressed: Boolean; const AMousePos: TPointF);
    procedure SetMouseInfo(APos: TPointF; AIsDown: Boolean);
    //
    property ParticleCount: Integer read FParticleCount  write SetParticleCount;
    property Radius: Double    read FRadius     write FRadius;
    property Velocity: Double  read FVelocity   write FVelocity;
    property Noise: Double     read FNoise      write FNoise;
    property TailOp: Single    read FTailOp     write FTailOp;
  end;

implementation

uses
  uCommons;

{ TVicsekEngine1 }

constructor TVicsekEngine0.Create(AWidth, AHeight: Single; ACount: Integer);
begin
  inherited Create;
  FParticleCount := ACount;
  FNoise :=         0.1;
  FRadius :=        30.0;
  FVelocity :=      4.2;
  FTailOp :=        0.15;
  FLockFlag :=      False;

  FIsMouseDown := False;
  FMousePos := PointF(-1000, -1000);

  FWidth :=  Max(1, AWidth);
  FHeight := Max(1, AHeight);
  FBuffer := TBitmap.Create(Round(FWidth), Round(FHeight));
  FBuffer.Clear(TAlphaColorRec.Black);

  InitParticles(ACount);
end;

destructor TVicsekEngine0.Destroy;
begin
  FBuffer.Free;
  inherited;
end;

procedure TVicsekEngine0.InitParticles(const PatCount: Integer);
begin
  FLockFlag := True;
  FParticleCount := PatCount;
  SetLength(FParticles, FParticleCount);
  Randomize;
  for var _i := 0 to FParticleCount - 1 do
  begin
    FParticles[_i].X := Random * FWidth;
    FParticles[_i].Y := Random * FHeight;
    FParticles[_i].Theta := Random * 2 * Pi;
  end;
  FLockFlag := False;
end;

procedure TVicsekEngine0.Resize(AWidth, AHeight: Single);
begin
  FWidth :=  Max(1, AWidth);
  FHeight := Max(1, AHeight);
  FBuffer.SetSize(Round(FWidth), Round(FHeight));
  FBuffer.Clear(TAlphaColorRec.Black);
end;

procedure TVicsekEngine0.SetMouseInfo(APos: TPointF; AIsDown: Boolean);
begin
  FMousePos := APos;
  FIsMouseDown := AIsDown;
end;

procedure TVicsekEngine0.SetParticleCount(const Value: Integer);
begin
  if FParticleCount <> Value then
  begin
    FParticleCount := Value;
    InitParticles(Value);
  end;
end;

procedure TVicsekEngine0.UpdatePhysics(const AMousePressed: Boolean; const AMousePos: TPointF);
begin
  var _PW: Double := FWidth;
  var _PH: Double := FHeight;
  if (_PW <= 0) or (_PH <= 0) then Exit;

  var _NextThetas: array of Double;
  SetLength(_NextThetas, FParticleCount);

  // 1. Parallel Processing of Particle Interactions ------------------------ //
  TParallel.For(0, FParticleCount - 1,
  procedure(Index: Integer)
  var
    _sinSum, _cosSum: Double;
    _dx, _dy, _distSq: Double;
    _mDx, _mDy, _mDistSq: Double;
    _angleToMouse: Double;
    _count: Integer;
    _j: Integer;
  begin
    _sinSum := 0;
    _cosSum := 0;
    _count := 0;

    // 1.1. Calculate average direction of neighbors within Radius ---------- //
    for _j := 0 to FParticleCount - 1 do
    begin
      _dx := FParticles[_j].X - FParticles[Index].X;
      _dy := FParticles[_j].Y - FParticles[Index].Y;

      // Handle Periodic Boundary Conditions (Toroidal space)
      if _dx > _PW / 2  then _dx := _dx - _PW;
      if _dx < -_PW / 2 then _dx := _dx + _PW;
      if _dy > _PH / 2  then _dy := _dy - _PH;
      if _dy < -_PH / 2 then _dy := _dy + _PH;

      _distSq := _dx * _dx + _dy * _dy;

      if _distSq < (FRadius * FRadius) then
      begin
        _sinSum := _sinSum + Sin(FParticles[_j].Theta);
        _cosSum := _cosSum + Cos(FParticles[_j].Theta);
        Inc(_count);
      end;
    end;

    // 1.2 Calculate mean direction  ---------------------------------------- //
    if _count > 0 then
      _NextThetas[Index] := ArcTan2(_sinSum / _count, _cosSum / _count)
    else
      _NextThetas[Index] := FParticles[Index].Theta;

    // 1.3. Mouse Interaction (Dynamic Effects) ----------------------------- //
    _mDx := AMousePos.X - FParticles[Index].X;
    _mDy := AMousePos.Y - FParticles[Index].Y;
    _mDistSq := _mDx * _mDx + _mDy * _mDy;

    if _mDistSq < Sqr(MOUSE_INFLUENCE_RADIUS) then
    begin
      _angleToMouse := ArcTan2(_mDy, _mDx);
      if AMousePressed then
        // On Click: Strong attraction towards mouse
        _NextThetas[Index] := LerpAngle(_NextThetas[Index], _angleToMouse, 0.5)
      else
        // On Hover: Avoidance behavior from mouse
        _NextThetas[Index] := LerpAngle(_NextThetas[Index], _angleToMouse + Pi, 0.2);
    end;

    // 1.4. Add Angular Noise ----------------------------------------------- //
    // Note: Random is not thread-safe. In high-performance scenarios,
    // consider a thread-local random generator.
    _NextThetas[Index] := _NextThetas[Index] + (Random - 0.5) * FNoise * 2 * Pi;
  end);

  // 2. Update Positions based on new angles -------------------------------- //
  //    sequential update to avoid race conditions on FParticles
  for var _i := 0 to FParticleCount - 1 do
  begin
    FParticles[_i].Theta := _NextThetas[_i];
    FParticles[_i].X := FParticles[_i].X + Cos(FParticles[_i].Theta) * FVelocity;
    FParticles[_i].Y := FParticles[_i].Y + Sin(FParticles[_i].Theta) * FVelocity;

    // Wrap around boundaries
    if FParticles[_i].X < 0   then FParticles[_i].X := FParticles[_i].X + _PW;
    if FParticles[_i].X > _PW then FParticles[_i].X := FParticles[_i].X - _PW;
    if FParticles[_i].Y < 0   then FParticles[_i].Y := FParticles[_i].Y + _PH;
    if FParticles[_i].Y > _PH then FParticles[_i].Y := FParticles[_i].Y - _PH;
  end;

  SetLength(_NextThetas, 0);
end;

procedure TVicsekEngine0.UpdateBuffer(const AFlag: Boolean = False);
begin
  if FBuffer.Canvas.BeginScene then
  begin
    try
      if AFlag then
      begin
        // Apply trailing effect by drawing a semi-transparent rectangle  --- //
        FBuffer.Canvas.Fill.Color := TAlphaColorRec.Black;
        FBuffer.Canvas.Fill.Kind := TBrushKind.Solid;
        FBuffer.Canvas.FillRect(RectF(0, 0, FWidth, FHeight), 0, 0, [], 0.3 - FTailOp);
      end
      else
        FBuffer.Canvas.Clear(TAlphaColorRec.Black);
    finally
      FBuffer.Canvas.EndScene;
    end;
  end;
end;

procedure TVicsekEngine0.Run(MainCanvas: TCanvas; const CW, CH: Single; const Trails: Boolean; const AMousePressed: Boolean; const AMousePos: TPointF);
begin
  if FLockFlag then Exit;

  // 1. Perform physics calculations  --------------------------------------- //
  UpdatePhysics(FIsMouseDown, FMousePos);
  // 2. Synchronize buffer size with canvas --------------------------------- //
  if (FBuffer.Width <> Round(CW)) or (FBuffer.Height <> Round(CH)) then
  begin
    FWidth := CW;
    FHeight := CH;
    FBuffer.SetSize(Round(CW), Round(CH));
  end;

  // 3. Clear or fade buffer  ----------------------------------------------- //
  UpdateBuffer(Trails);
  // 4. Render particles ---------------------------------------------------- //
  if FBuffer.Canvas.BeginScene then
  try
    // Optional: Visualize mouse influence radius
    if AMousePressed then
    with FBuffer.Canvas do
    begin
      Stroke.Color := TAlphaColorRec.White;
      Stroke.Kind := TBrushKind.Solid;
      Stroke.Thickness := 1;
      Stroke.Dash := TStrokeDash.Dot;
      DrawEllipse(RectF(AMousePos.X - FRadius, AMousePos.Y - FRadius, AMousePos.X + FRadius, AMousePos.Y + FRadius), 0.8);
    end;

    var _Size: Double := 7.0;
    var _Points: TPolygon := [];
    SetLength(_Points, 4);

    for var _i := 0 to FParticleCount - 1 do
    with FBuffer.Canvas do
    begin
      // Highlight specific indices
      if (_i = 0) then
        begin
          Fill.Color := TAlphaColors.White;
          _Size := 14.0;
        end else
      if (_i = FParticleCount - 1) then
        begin
          Fill.Color := TAlphaColors.Yellow;
          _Size := 14.0;
        end
      else
        begin
          Fill.Color := GetDirectionColor(FParticles[_i].Theta);
          _Size := 7.0;
        end;

      Stroke.Kind := TBrushKind.None;

      // Create arrow shape for the particle
      _Points[0] := PointF(FParticles[_i].X + Cos(FParticles[_i].Theta) * _Size,              FParticles[_i].Y + Sin(FParticles[_i].Theta) * _Size);
      _Points[1] := PointF(FParticles[_i].X + Cos(FParticles[_i].Theta + 2.6) * _Size,        FParticles[_i].Y + Sin(FParticles[_i].Theta + 2.6) * _Size);
      _Points[2] := PointF(FParticles[_i].X + Cos(FParticles[_i].Theta + Pi) * (_Size * 0.4), FParticles[_i].Y + Sin(FParticles[_i].Theta + Pi) * (_Size * 0.4));
      _Points[3] := PointF(FParticles[_i].X + Cos(FParticles[_i].Theta - 2.6) * _Size,        FParticles[_i].Y + Sin(FParticles[_i].Theta - 2.6) * _Size);

      FillPolygon(_Points, 1.0);
    end;

  finally
    FBuffer.Canvas.EndScene;
  end;

  // 5. Output buffer to main canvas  --------------------------------------- //
  MainCanvas.DrawBitmap(FBuffer, RectF(0, 0, FBuffer.Width, FBuffer.Height),  RectF(0, 0, FWidth, FHeight), 1.0);
end;

end.
