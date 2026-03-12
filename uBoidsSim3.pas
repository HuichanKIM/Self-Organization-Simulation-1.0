unit uBoidsSim3;

interface

uses
  System.SysUtils,
  System.Types,
  System.UITypes,
  System.Classes,
  System.Variants,
  System.Math,
  System.Math.Vectors,
  System.Threading, // Required for TParallel
  FMX.Types,
  FMX.Controls,
  FMX.Forms,
  FMX.Graphics,
  FMX.Dialogs,
  System.Generics.Collections;

type
  { Individual Mouse Object }
  TBoidsMouse = class
  private
    FMax_Force: Single;
    FMax_Speed: Single;
  public
    Position: TVector;
    Velocity: TVector;
    Acceleration: TVector;
    Size: Single;
    AnimOffset: Single;
    constructor Create(const CanvasWidth, CanvasHeight: Single);
    procedure Update(const ASpeed: Single);
    procedure ApplyForce(const Force: TVector);
    function Get_Color: TAlphaColor;
    property Max_Force: Single read FMax_Force  write FMax_Force;
    property Max_Speed: Single read FMax_Speed  write FMax_Speed;
  end;

  { Simulation Engine }
  TBoidssEngine3 = class
  private
    FBuffer: TBitmap;
    FParticleCount: Integer;
    FWidth: Single;
    FHeight: Single;
    FBoids: TObjectList<TBoidsMouse>;
    FMousePos: TVector;
    FIsMouseDown1: Boolean;
    FIsMouseDown2: Boolean;
    FMaxForce: Single;
    FMaxSpeed: Single;
    FAlignWeight: Single;
    FCohesionWeight: Single;
    FSeparationWeight: Single;
    FTailMark: Single;
    FLockFlag: Boolean;
    procedure SetParticleCount(const Value: Integer);
    procedure InitBoids(const ACount: Integer);
    procedure UpdateBuffer(const AFlag: Boolean = False);
    function Align(ABoid: TBoidsMouse): TVector;
    function Cohesion(ABoid: TBoidsMouse): TVector;
    function Separation(ABoid: TBoidsMouse): TVector;
    procedure UpdatePhysics(const AMousePos: TVector; const AMousePressed1, AMousePressed2: Boolean);
    procedure UpdateBoids(const ACanvas: TCanvas);
  public
    constructor Create(AWidth, AHeight: Single; ACount: Integer);
    destructor Destroy; override;

    procedure SeTMouseInfo(Pos: TPointF; IsDown: Boolean);
    procedure Resize(AWidth, AHeight: Single);
    procedure Run(MainCanvas: TCanvas; const CW, CH: Single; const Trails: Boolean; const AMousePressed1, AMousePressed2: Boolean; const AMousePos: TPointF);

    property ParticleCount: Integer   read FParticleCount  write SetParticleCount;
    property MaxSpeed: Single         read FMaxSpeed       write FMaxSpeed;
    property MaxForce: Single         read FMaxForce       write FMaxForce;
    property AlignWeight: Single      read FAlignWeight    write FAlignWeight;
    property CohesionWeight: Single   read FCohesionWeight write FCohesionWeight;
    property SeparationWeight: Single read FSeparationWeight write FSeparationWeight;
  end;

implementation

uses
  uCommons;

{ TBoidsMouse }

constructor TBoidsMouse.Create(const CanvasWidth, CanvasHeight: Single);
begin
  Position := Vector(Random * CanvasWidth, Random * CanvasHeight, 0);
  Velocity := Vector(Random * 2 - 1, Random * 2 - 1, 0).Normalize * 2;
  Acceleration := Vector(0, 0, 0);
  FMax_Speed := 4;
  FMax_Force := 0.1;
  Size :=       4 + Random * 8;
  AnimOffset := Random * Pi * 2;
end;

procedure TBoidsMouse.ApplyForce(const Force: TVector);
begin
  Acceleration := Acceleration + Force;
end;

procedure TBoidsMouse.Update(const ASpeed: Single);
begin
  Velocity := Velocity + Acceleration;
  { Limit velocity by max speed }
  if Velocity.Length > ASpeed then
    Velocity := Velocity.Normalize * ASpeed;
  Position := Position + Velocity;
  Acceleration := Acceleration * 0;
end;

function TBoidsMouse.Get_Color: TAlphaColor;
begin
  Result := GetDirectionColor(ArcTan2(Velocity.Y, Velocity.X));
end;

{ TBoidssEngine3 }

constructor TBoidssEngine3.Create(AWidth, AHeight: Single; ACount: Integer);
begin
  inherited Create;
  FBoids :=  TObjectList<TBoidsMouse>.Create(True);
  FWidth :=  Max(1, AWidth);
  FHeight := Max(1, AHeight);
  FBuffer := TBitmap.Create(Round(FWidth), Round(FHeight));
  FBuffer.Clear(TAlphaColorRec.Black);

  FParticleCount := ACount;
  FMaxForce :=          0.2;
  FMaxSpeed :=          4.0;
  FAlignWeight :=       1.0;
  FCohesionWeight :=    1.0;
  FSeparationWeight :=  1.5;
  FTailMark :=          0.2;

  InitBoids(ACount);
end;

destructor TBoidssEngine3.Destroy;
begin
  FBuffer.Free;
  FBoids.Free;
  inherited;
end;

procedure TBoidssEngine3.InitBoids(const ACount: Integer);
begin
  FLockFlag := True;
  FBoids.Clear;
  Randomize;
  for var i := 0 to ACount - 1 do
    FBoids.Add(TBoidsMouse.Create(FWidth, FHeight));
  FLockFlag := False;
end;

procedure TBoidssEngine3.Resize(AWidth, AHeight: Single);
begin
  FWidth := Max(1, AWidth);
  FHeight := Max(1, AHeight);
  FBuffer.SetSize(Round(FWidth), Round(FHeight));
  FBuffer.Clear(TAlphaColorRec.Black);
end;

procedure TBoidssEngine3.SetParticleCount(const Value: Integer);
begin
  if FParticleCount <> Value then
  begin
    FParticleCount := Value;
    InitBoids(Value);
  end;
end;

function TBoidssEngine3.Align(ABoid: TBoidsMouse): TVector;
var
  _Sum: TVector;
  _Count: Integer;
  _NeighborDist: Single;
begin
  _Sum := Vector(0, 0, 0);
  _Count := 0;
  _NeighborDist := 50.0;

  for var _Other in FBoids do
  begin
    var D := (ABoid.Position - _Other.Position).Length;
    if (D > 0) and (D < _NeighborDist) then
    begin
      _Sum := _Sum + _Other.Velocity;
      Inc(_Count);
    end;
  end;

  if _Count > 0 then
  begin
    _Sum := (_Sum / _Count).Normalize * FMaxSpeed;
    Result := (_Sum - ABoid.Velocity);
    if Result.Length > FMaxForce then
      Result := Result.Normalize * FMaxForce;
  end
  else
    Result := Vector(0, 0, 0);
end;

function TBoidssEngine3.Cohesion(ABoid: TBoidsMouse): TVector;
var
  _Sum: TVector;
  _Count: Integer;
  _NeighborDist: Single;
begin
  _Sum := Vector(0, 0, 0);
  _Count := 0;
  _NeighborDist := 50.0;

  for var _Other in FBoids do
  begin
    var D := (ABoid.Position - _Other.Position).Length;
    if (D > 0) and (D < _NeighborDist) then
    begin
      _Sum := _Sum + _Other.Position;
      Inc(_Count);
    end;
  end;

  if _Count > 0 then
  begin
    _Sum := _Sum / _Count;
    var Desired := (_Sum - ABoid.Position).Normalize * FMaxSpeed;
    Result := (Desired - ABoid.Velocity);
    if Result.Length > FMaxForce then
      Result := Result.Normalize * FMaxForce;
  end
  else
    Result := Vector(0, 0, 0);
end;

function TBoidssEngine3.Separation(ABoid: TBoidsMouse): TVector;
var
  _Steer: TVector;
  _Count: Integer;
  _DesiredSeparation: Single;
begin
  _Steer := Vector(0, 0, 0);
  _Count := 0;
  _DesiredSeparation := 25.0;

  for var _Other in FBoids do
  begin
    var _D := (ABoid.Position - _Other.Position).Length;
    if (_D > 0) and (_D < _DesiredSeparation) then
    begin
      var Diff := (ABoid.Position - _Other.Position).Normalize / _D;
      _Steer := _Steer + Diff;
      Inc(_Count);
    end;
  end;

  if _Count > 0 then
    _Steer := _Steer / _Count;

  if _Steer.Length > 0 then
  begin
    _Steer := _Steer.Normalize * FMaxSpeed;
    _Steer := _Steer - ABoid.Velocity;
    if _Steer.Length > FMaxForce then
      _Steer := _Steer.Normalize * FMaxForce;
  end;
  Result := _Steer;
end;

procedure TBoidssEngine3.SeTMouseInfo(Pos: TPointF; IsDown: Boolean);
begin
  FMousePos := Pos;
  FIsMouseDown1 := IsDown;
end;

procedure TBoidssEngine3.UpdatePhysics(const AMousePos: TVector; const AMousePressed1, AMousePressed2: Boolean);
begin
  { Parallelize the heavy calculation part }
  TParallel.For(0, FBoids.Count - 1,
  procedure(Index: Integer)
  var
    _Ali, _Coh, _Sep, _MouseForce: TVector;
    _CurrentBoid: TBoidsMouse;
    _Dist: Single;
  begin
    _CurrentBoid := FBoids[Index];

    { 1. Calculate flocking behaviors }
    _Ali := Align(_CurrentBoid);
    _Coh := Cohesion(_CurrentBoid);
    _Sep := Separation(_CurrentBoid);

    { 2. Apply weights }
    _CurrentBoid.ApplyForce(_Ali * FAlignWeight);
    _CurrentBoid.ApplyForce(_Coh * FCohesionWeight);
    _CurrentBoid.ApplyForce(_Sep * FSeparationWeight);

    { 3. Handle Mouse Interaction }
    //_Dist := _CurrentBoid.Position.Distance(_CurrentBoid.Position, AMousePos);
    _Dist := (_CurrentBoid.Position - AMousePos).Length;

    if AMousePressed1 then { Attraction }
    begin
      _MouseForce := (AMousePos - _CurrentBoid.Position).Normalize * FMaxSpeed;
      _MouseForce := _MouseForce - _CurrentBoid.Velocity;
      if _MouseForce.Length > FMaxForce * 2 then _MouseForce := _MouseForce.Normalize * FMaxForce * 2;
      _CurrentBoid.ApplyForce(_MouseForce);
    end else
    if AMousePressed2 then { Repulsion }
    begin
      if _Dist < 200 then
      begin
        _MouseForce := (_CurrentBoid.Position - AMousePos).Normalize * FMaxSpeed * 1.5;
        _MouseForce := _MouseForce - _CurrentBoid.Velocity;
        if _MouseForce.Length > FMaxForce * 3 then _MouseForce := _MouseForce.Normalize * FMaxForce * 3;
        _CurrentBoid.ApplyForce(_MouseForce);
      end;
    end;

    { 4. Update Physics }
    _CurrentBoid.Update(FMaxSpeed);

    { 5. Screen Borders Logic (Toroidal world) }
    if _CurrentBoid.Position.X < 0 then _CurrentBoid.Position.X := FWidth;
    if _CurrentBoid.Position.Y < 0 then _CurrentBoid.Position.Y := FHeight;
    if _CurrentBoid.Position.X > FWidth then _CurrentBoid.Position.X := 0;
    if _CurrentBoid.Position.Y > FHeight then _CurrentBoid.Position.Y := 0;
  end);
end;

procedure TBoidssEngine3.UpdateBoids(const ACanvas: TCanvas);
var
  _State: TCanvasSaveState;
  _Angle: Single;
  _BodyRect, _HeadRect: TRectF;
  _BoidColor: TAlphaColor;
begin
  for var _Boid: TBoidsMouse in FBoids do
  with ACanvas do
    begin
      _BoidColor := _Boid.Get_Color;
      _Angle := ArcTan2(_Boid.Velocity.Y, _Boid.Velocity.X);
      _State := SaveState;
      try
        //  Create Matrix that rotates first, then moves to _Boid's position.
        //  Combining with the current canvas matrix to ensure it stays within the buffer coordinates.
        var _Matrix := TMatrix.Identity;
        _Matrix := TMatrix.CreateRotation(_Angle) * TMatrix.CreateTranslation(_Boid.Position.X, _Boid.Position.Y);
        SetMatrix(_Matrix * ACanvas.Matrix);

        //  Using local coordinates relative to (0,0).
        //  The center of the _Boid is (0,0).

        // 1. Tail (Draw from center to back)
        Stroke.Color := _BoidColor;
        Stroke.Thickness := _Boid.Size * 0.3;
        Stroke.Cap := TStrokeCap.Round;
        DrawLine(PointF(-_Boid.Size * 1.0, 0), PointF(-_Boid.Size * 2.2, 0), 0.7);

        // 2. Body Components
        Fill.Color := _BoidColor;
        Fill.Kind := TBrushKind.Solid;

        /// Main Body: Centered at (0,0)
        _BodyRect := RectF(-_Boid.Size * 1.2, -_Boid.Size * 0.6, _Boid.Size * 1.2, _Boid.Size * 0.6);
        FillEllipse(_BodyRect, 1.0);

        /// Head: Positioned in front (+X)
        _HeadRect := RectF(_Boid.Size * 0.5, -_Boid.Size * 0.5, _Boid.Size * 1.8, _Boid.Size * 0.5);
        FillEllipse(_HeadRect, 1.0);

        // 3. Ears/Horns: Anchored to the head
        Stroke.Color := TAlphaColorRec.White;
        Stroke.Thickness := 1.2;
        DrawLine(PointF(_Boid.Size * 1.0, -0.2 * _Boid.Size), PointF(_Boid.Size * 1.6, -0.6 * _Boid.Size), 0.8);
        DrawLine(PointF(_Boid.Size * 1.0, 0.2 * _Boid.Size),  PointF(_Boid.Size * 1.6, 0.6 * _Boid.Size), 0.8);

      finally
        RestoreState(_State);
      end;
    end;
end;

procedure TBoidssEngine3.UpdateBuffer(const AFlag: Boolean);
begin
  if FBuffer.Canvas.BeginScene then
  try
    if AFlag then
    with FBuffer.Canvas do
      begin                                                                     { Apply trail effect using semi-transparent overlay }
        Fill.Color := TAlphaColorRec.Black;
        Fill.Kind := TBrushKind.Solid;
        FillRect(RectF(0, 0, FWidth, FHeight), 0, 0, [], 0.4 - FTailMark);      // Shaodw Length ...
      end
    else
      FBuffer.Canvas.Clear(TAlphaColorRec.Black);
  finally
    FBuffer.Canvas.EndScene;
  end;
end;

procedure TBoidssEngine3.Run(MainCanvas: TCanvas; const CW, CH: Single; const Trails: Boolean; const AMousePressed1, AMousePressed2: Boolean; const AMousePos: TPointF);
begin
  if FLockFlag then Exit;

  FMousePos := Vector(AMousePos.X, AMousePos.Y, 0);
  // ------------------------------------------------------------------------ //
  UpdatePhysics(FMousePos, AMousePressed1, AMousePressed2);                              { 1. Update Physics and Flocking in Parallel }
  // ------------------------------------------------------------------------ //
  if (FBuffer.Width <> Round(CW)) or (FBuffer.Height <> Round(CH)) then         { 2. Sync Buffer Size }
  begin
    FWidth := CW;
    FHeight := CH;
    FBuffer.SetSize(Round(CW), Round(CH));
    UpdateBuffer(False);
  end;
  // ------------------------------------------------------------------------ //
  UpdateBuffer(Trails);                                                         { 3. Handle Trails }
  // ------------------------------------------------------------------------ //
  if FBuffer.Canvas.BeginScene then                                             { 4. Render Boids to Buffer }
  with FBuffer do
  try
    { Visualize mouse interaction center }
    if AMousePressed1 or AMousePressed2 then
    begin
      Canvas.Stroke.Thickness := 1;
      Canvas.Stroke.Color := TAlphaColorRec.Silver;
      Canvas.DrawEllipse(RectF(AMousePos.X - 20, AMousePos.Y - 20, AMousePos.X + 20, AMousePos.Y + 20), 0.5);
    end;
  // ------------------------------------------------------------------------ //
    UpdateBoids(Canvas);
  // ------------------------------------------------------------------------ //
  finally
    Canvas.EndScene;
  end;

  MainCanvas.DrawBitmap(FBuffer, RectF(0, 0, FBuffer.Width, FBuffer.Height), RectF(0, 0, CW, CH), 1.0);
end;

end.
