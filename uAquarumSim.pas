unit uAquarumSim;

interface

uses
  System.SysUtils,
  System.Types,
  System.UITypes,
  System.Classes,
  System.Math,
  System.Math.Vectors,
  System.Generics.Collections,
  System.Threading, // Required for TParallel
  FMX.Types,
  FMX.Graphics,
  FMX.Objects,
  FMX.Controls;

type
  { Record representing an individual fish agent }
  TFish = record
    Position: TPointF;           // Current position
    Velocity: TPointF;           // Velocity and direction vector
    Color: TAlphaColor;          // Body color
    Size: TSizeF;                // Fish dimensions
    PhaseOffset: Single;         // Animation offset for tail wagging
    Angle: Single;               // Rotation in degrees
    TargetOrbit: Single;         // Assigned specific orbit radius to prevent crowding
    PreferredDist: Single;       // Target orbit radius from the school's center
    Fish_Tag: Integer;
  end;

  { Simulation Engine }
  TAquariumEngine = class
  private
    FLockFlag: Boolean;          // Lock for initialization
    FBuffer: TBitmap;            // Bitmap buffer for rendering
    FWidth, FHeight: Single;

    FFishes: TArray<TFish>;      // Array of fish data
    FFishCount: Integer;
    FBaseBody: TPathData;        // Fixed body path
    FTailPath: TPathData;        // Variable tail path
    FTime: Single;               // Accumulated time for animation
    FMousePos: TPointF;          // Current mouse position
    FIsMouseDown: Boolean;       // Mouse click state

    FMaxSpeed: Single;           // Maximum movement speed
    FMinSpeed: Single;           // Minimum movement speed

    FKey: Integer;
    FAquaKey: Integer;
    FScaleSize: Single;
    FCurrentCenter: TPointF;     // Internally tracked center for smooth transitions
    procedure DrawFish(ACanvas: TCanvas; AFish: TFish);
    function GetFishCount: Integer;
    procedure UpdateFishBodyPath(const ATailWag: Single);
    procedure UpdateFishCount(const ACount: Integer; const AViewRect: TRectF);
    procedure SetFishCount(const Value: Integer);
    procedure UpdatePhysics(const AMousePressed: Boolean; const AMousePos: TPointF);
  private
    { Internal helper for squared distance calculation to fix the Undeclared Identifier error }
    function GetDistSq(const P1, P2: TPointF): Single; inline;
  public
    constructor Create(const ACount: Integer; const AViewRect: TRectF);
    destructor Destroy; override;

    procedure Resize(AWidth, AHeight: Single);
    procedure Run(MainCanvas: TCanvas; const CW, CH: Single; const Trails, AMousePressed1, AMousePressed2: Boolean; const AMousePos: TPointF);
    procedure SetMouseInfo(APos: TPointF; AIsDown: Boolean);

    property FishCount: Integer         read GetFishCount        write SetFishCount;
  end;

implementation

uses
  uCommons;

{ TVicsekEngine2 }

constructor TAquariumEngine.Create(const ACount: Integer; const AViewRect: TRectF);
begin
  inherited Create;
  FTime := 0;
  FKey  := 0;
  FMousePos := TPointF.Create(-1000, -1000);
  FIsMouseDown := False;
  FLockFlag := False;

  FWidth :=  Max(1, Round(AViewRect.Width));
  FHeight := Max(1, Round(AViewRect.Height));
  FBuffer := TBitmap.Create(Round(FWidth), Round(FHeight));

  // Initialize starting center at screen center
  FCurrentCenter := TPointF.Create(100,100);

  FFishCount := 0;
  { Adjusted weights for smoother movement }
  FMaxSpeed := 4.2;     // Reduced from 2.5 for calmer flow
  FMinSpeed := 1.0;

  { Define the static part of the fish body }
  FBaseBody := TPathData.Create;
  FTailPath := TPathData.Create;

  UpdateFishBodyPath(0);
  UpdateFishCount(ACount, AViewRect);
end;

destructor TAquariumEngine.Destroy;
begin
  FBaseBody.Free;
  FTailPath.Free;
  FBuffer.Free;
  inherited;
end;

function TAquariumEngine.GetFishCount: Integer;
begin
  Result := Length(FFishes);
end;

procedure TAquariumEngine.UpdateFishBodyPath(const ATailWag: Single);
begin
  with FBaseBody do
  begin
    Clear;
    MoveTo(TPointF.Create(6, 0));
    CurveTo(TPointF.Create(3, -5), TPointF.Create(-1, -5), TPointF.Create(-4, 0));
    CurveTo(TPointF.Create(-1, 5), TPointF.Create(3, 5),   TPointF.Create(6, 0));
    ClosePath;
  end;
end;

procedure TAquariumEngine.UpdateFishCount(const ACount: Integer; const AViewRect: TRectF);
begin
  FLockFlag := True;

  FFishCount := ACount;
  Randomize;
  SetLength(FFishes, ACount);

  var _Angle: Single := 0;
  for var _i := 0 to ACount - 1 do
  begin
    with FFishes[_i] do
    begin
      _Angle :=      Random * 2 * Pi;
      Position :=    FCurrentCenter + PointF(Random * AViewRect.Width, Random * AViewRect.Height);
      Velocity :=    PointF(Cos(_Angle), Sin(_Angle)) * (FMinSpeed + Random * 2);
      Color :=       TAlphaColorRec.Alpha or TAlphaColor(Random($FFFFFF));
      Size :=        TSizeF.Create(30 + Random(40), 15 + Random(20));
      PhaseOffset := Random * 2 * Pi;
      // Distinct orbit layers to prevent overcrowding (220px ~ 420px)
      PreferredDist := 240.0 + (_i mod 5) * 50.0;
      //
      Fish_Tag :=    Random(10) mod 2;
    end;
  end;

  FLockFlag := False;
end;

procedure TAquariumEngine.SetFishCount(const Value: Integer);
begin
  if FFishCount <> Value then
  begin
    FFishCount := Value;
    UpdateFishCount(Value, RectF(0,0,FWidth, FHeight));
  end;
end;

procedure TAquariumEngine.SetMouseInfo(APos: TPointF; AIsDown: Boolean);
begin
  FMousePos := APos;
  FIsMouseDown := AIsDown;
end;

procedure TAquariumEngine.Resize(AWidth, AHeight: Single);
begin
  FLockFlag := True;
  FWidth :=  Max(1, AWidth);
  FHeight := Max(1, AHeight);
  FBuffer.SetSize(Round(FWidth), Round(FHeight));
  FBuffer.Clear(TAlphaColorRec.Black);
  FLockFlag := False;
end;

function TAquariumEngine.GetDistSq(const P1, P2: TPointF): Single;
begin
  // Direct calculation to avoid 'LengthSquared' identification issues
  Result := Sqr(P1.X - P2.X) + Sqr(P1.Y - P2.Y);
end;

var
  VVortexStrength: Single = 0.15; // Rotational force for spiraling

  { * Ref
    SPIRAL LOGIC:
    The center itself moves in a circle that shrinks over time.
    Radius decreases using an exponential decay or oscillating function. }

procedure TAquariumEngine.UpdatePhysics(const AMousePressed: Boolean; const AMousePos: TPointF);
const
  _DeltaTime            = 0.033;        // Time
  _MinRadius            = 1.0;          // Center exclusion zone
  _TargetRadius         = 250.0;        // Ideal orbiting radius
  _SeparationDist       = 120.0;        // Increased distance to prevent overlapping (Personal space)
  _SeparationForce      = 0.65;         // Stronger repulsion to avoid stacking
  _ReflectionElasticity = 0.7;          //

                                        // Smoothing and Spiral constants
  _LerpFactor           = 0.04;         // Slightly slower for more grace
  _MaxSpiralRadius      = 300.0;        // Maximum distance from center during spiral
  _SpiralSpeed          = 0.5;          // Angular speed of the center movement
  _SpiralDecay          = 0.05;         // How fast the spiral converges to center
begin
  FTime := FTime + _DeltaTime;

  // 1. Calculate Target Center with Spiral Convergence ----------------------
  var _TargetGoal: TPointF;
  var _GlobalVelocity := TPointF.Zero;

  var ScreenCenter := TPointF.Create(FWidth / 2, FHeight / 2);                  { * Ref. }
  // Calculate shrinking radius based on time (cycles every ~20-30 seconds)
  var _CurrentRadius := _MaxSpiralRadius * (0.3 + 0.7 * Abs(Cos(FTime * _SpiralDecay)));
  // Spiral position calculation
  var _Angle := FTime * _SpiralSpeed;
  _TargetGoal.X := ScreenCenter.X + Cos(_Angle) * _CurrentRadius;
  _TargetGoal.Y := ScreenCenter.Y + Sin(_Angle) * _CurrentRadius;

  // Smoothly interpolate current simulation center towards the goal
  FCurrentCenter.X := FCurrentCenter.X + (_TargetGoal.X - FCurrentCenter.X) * _LerpFactor;
  FCurrentCenter.Y := FCurrentCenter.Y + (_TargetGoal.Y - FCurrentCenter.Y) * _LerpFactor;

  // Calculate average velocity for global alignment sync
  for var i := 0 to FFishCount - 1 do
    _GlobalVelocity := _GlobalVelocity + FFishes[i].Velocity;
  _GlobalVelocity := _GlobalVelocity / FFishCount;

  VVortexStrength := Min(0.15, VVortexStrength + 0.001);

  // Time-based convergence (spiral effect settles over 10 seconds)
  var _ConvergenceAlpha := Min(1.0, FTime / 10.0);
  var _CurrentCenteringForce := 0.07 * _ConvergenceAlpha;

  // Parallel --------------------------------------------------------------- //
  TParallel.For(0, FFishCount - 1, procedure(Index: Integer)
  begin
    var _Fish := FFishes[Index];
    var _Steering := TPointF.Zero;

    // 1. Centering & Vortex Logic with Exclusion Zone
    var _Diff := FCurrentCenter - _Fish.Position;//_Center - _Fish.Position;
    var _Dist := _Diff.Length;

    if _Dist > 1.0 then
    begin
      var _NormalizedDiff := _Diff / _Dist;

      // Prevent entering the 200px _Center zone
      if _Dist < _MinRadius then
      begin
        var _PushForce := (_MinRadius - _Dist) * 0.8;
        _Steering := _Steering - _NormalizedDiff * _PushForce;
      end
      else
      begin
        // Maintain orbit around _TargetRadius
        var _PullFactor := Abs(_Dist - _TargetRadius) * 0.06;
        _Steering := _Steering + _NormalizedDiff * (_CurrentCenteringForce * _PullFactor);
      end;

      // Circular motion force
      var _Swirl := TPointF.Create(-_NormalizedDiff.Y, _NormalizedDiff.X);
      _Steering := _Steering + _Swirl * VVortexStrength;
    end;

    // 2. ENHANCED ANTI-OVERLAP (Separation)
    // Stronger logic to ensure _Fish maintain unique positions
    for var _j := 0 to FFishCount - 1 do
    begin
      if Index = _j then Continue;

      var _DistSq := GetDistSq(_Fish.Position, FFishes[_j].Position);
      // If two _Fish are too close (within _SeparationDist)
      if (_DistSq < Sqr(_SeparationDist)) and (_DistSq > 0.1) then
      begin
        var _DistVec := _Fish.Position - FFishes[_j].Position;
        var _D := Sqrt(_DistSq);
        // Exponential-like push-back force to prevent overlapping
        //var _Ratio := 1.0 - (_D / _SeparationDist);
        //var _ForceMagnitude := Sqr(_Ratio) * _SeparationForce;
        var _ForceMagnitude := (1.0 - (_D / _SeparationDist)) * _SeparationForce;
        _Steering := _Steering + (_DistVec / _D) * _ForceMagnitude;
      end;
    end;

    _Steering := _Steering + (_GlobalVelocity - _Fish.Velocity) * 0.4;
    // 3. Mouse Interaction (Repel)
    if AMousePressed then
    begin
      var _MDiff := _Fish.Position - AMousePos;
      var _MDistSq := GetDistSq(_Fish.Position, AMousePos);
      if (_MDistSq < Sqr(300)) and (_MDistSq > 0.1) then  // 260 ...
      begin
        var _MD := Sqrt(_MDistSq);
        _Steering := _Steering + (_MDiff / _MD) * 8.0 * (1.0 - _MD / 260);
      end;
      VVortexStrength := 0;
    end;

    // 4. Final Velocity Calculation
    _Fish.Velocity := _Fish.Velocity + _Steering;

    // Clamp _ to prevent erratic jittering
    var _Speed := _Fish.Velocity.Length;
    if _Speed > 8.0 then _Fish.Velocity := _Fish.Velocity.Normalize * 8.0;
    if _Speed < 2.0 then _Fish.Velocity := _Fish.Velocity.Normalize * 2.0;

    // Update position
    _Fish.Position := _Fish.Position + _Fish.Velocity;

    // 5. Hard Boundary Reflection (Physics Wall)
    var _Margin := 25.0;
    if _Fish.Position.X < _Margin then
    begin
      _Fish.Position.X := _Margin;
      if _Fish.Velocity.X < 0 then _Fish.Velocity.X := -_Fish.Velocity.X * _ReflectionElasticity;
    end
    else if _Fish.Position.X > FWidth - _Margin then
    begin
      _Fish.Position.X := FWidth - _Margin;
      if _Fish.Velocity.X > 0 then _Fish.Velocity.X := -_Fish.Velocity.X * _ReflectionElasticity;
    end;

    if _Fish.Position.Y < _Margin then
    begin
      _Fish.Position.Y := _Margin;
      if _Fish.Velocity.Y < 0 then _Fish.Velocity.Y := -_Fish.Velocity.Y * _ReflectionElasticity;
    end
    else if _Fish.Position.Y > FHeight - _Margin then
    begin
      _Fish.Position.Y := FHeight - _Margin;
      if _Fish.Velocity.Y > 0 then _Fish.Velocity.Y := -_Fish.Velocity.Y * _ReflectionElasticity;
    end;

    // Heading angle for drawing
    _Fish.Angle := RadToDeg(ArcTan2(_Fish.Velocity.Y, _Fish.Velocity.X));

    FFishes[Index] := _Fish;
  end);
end;

procedure TAquariumEngine.DrawFish(ACanvas: TCanvas; AFish: TFish);
begin
  if Length(FFishes) <= 0 then Exit;
  // Save current transformation state
  var _State: TCanvasSaveState := ACanvas.SaveState;
  try
    var _Matrix := TMatrix.Identity;
    _Matrix := TMatrix.CreateScaling(AFish.Size.Width / 13, AFish.Size.Height / 10) *
               TMatrix.CreateRotation(DegToRad(AFish.Angle)) *
               TMatrix.CreateTranslation(AFish.Position.X, AFish.Position.Y);

    ACanvas.SetMatrix(_Matrix); // * ACanvas.Matrix);                               { for GPU-accelerated ? }
    { Update tail animation path }
    var _TailWag: Single := Sin((FTime + AFish.PhaseOffset) * 15) * 3.5;
    with FTailPath do
    begin
      Clear;
      MoveTo(TPointF.Create(-4, 0));
      LineTo(TPointF.Create(-8, -3.5 + _TailWag));
      LineTo(TPointF.Create(-8, 3.5  + _TailWag));
      ClosePath;
    end;

    if AFish.Fish_Tag = 0 then
      with ACanvas do
      begin
        Stroke.Color := AFish.Color;
        DrawPath(FBaseBody, 0.85);
        DrawPath(FTailPath, 0.85);
      end
    else
      with ACanvas do
      begin
        Fill.Color := AFish.Color;
        Fill.Kind :=  TBrushKind.Solid;
        FillPath(FBaseBody, 0.85);
        FillPath(FTailPath, 0.85);
      end;

    with ACanvas do
    begin
      Stroke.Color := TAlphaColorRec.Black;
      Stroke.Thickness := 0.6;
      DrawPath(FBaseBody, 0.4);
      DrawPath(FTailPath, 0.4);

      Fill.Color := TAlphaColorRec.White;                                       { Draw eyes }
      FillEllipse(TRectF.Create(3.2, -2.2, 5.0, -0.4), 1.0);
    end;
  finally
    // Restore transformation state to avoid affecting subsequent draws
    ACanvas.RestoreState(_State);
  end;
end;

procedure TAquariumEngine.Run(MainCanvas: TCanvas; const CW, CH: Single; const Trails, AMousePressed1, AMousePressed2: Boolean; const AMousePos: TPointF);
begin
  if FLockFlag then Exit;

  // 1. Sync buffer size ---------------------------------------------------- //
  if (FBuffer.Width <> Round(CW)) or (FBuffer.Height <> Round(CH)) then
  begin
    FWidth := CW;
    FHeight := CH;
    FBuffer.SetSize(Round(CW), Round(CH));
  end;
  // 2. Update physics and flocking data ------------------------------------ //
  UpdatePhysics(AMousePressed1, AMousePos);
  // 3. Draw all fish ------------------------------------------------------- //
  if (Length(FFishes) > 0) and FBuffer.Canvas.BeginScene then
  begin
    try
      FBuffer.Canvas.Clear(TAlphaColorRec.Black);
      for var _i := 0 to Length(FFishes)- 1 do
        DrawFish(FBuffer.Canvas, FFishes[_i]);
    finally
      FBuffer.Canvas.EndScene;
    end;
  end;
  // 4. Draw final buffer to main canvas ------------------------------------ //
  MainCanvas.DrawBitmap(FBuffer, RectF(0, 0, FBuffer.Width, FBuffer.Height), RectF(0, 0, FWidth, FHeight), 1.0);
  // 5. Show interaction range if mouse is pressed -------------------------- //
  if AMousePressed1 then
  if MainCanvas.BeginScene then
  with MainCanvas do
  try
    Stroke.Color := TAlphaColorRec.White;
    Stroke.Kind := TBrushKind.Solid;
    Stroke.Thickness := 1;
    Stroke.Dash := TStrokeDash.Dot;
    DrawEllipse(RectF(AMousePos.X - 30, AMousePos.Y - 30,
                      AMousePos.X + 30, AMousePos.Y + 30), 0.8);
  finally
    EndScene;
  end;
end;

end.
