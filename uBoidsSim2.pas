unit uBoidsSim2;

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
  { Individual Fly Object }
  TBoid_fly = class
  private
    FMax_Force: Single;
    FMax_Speed: Single;
    FWing_Tag: Integer;
    FSize: TSizeF;
  public
    Position: TPointF;
    Velocity: TPointF;
    Acceleration: TPointF;
    constructor Create(const PosX, PosY: Single);
    destructor Destroy; override;
    procedure ApplyForce(Force: TPointF);
    procedure Update;
    procedure Borders(const AWidth, AHeight: Single);

    property Size: TSizeF       read FSize       write FSize;
    property Max_Force: Single  read FMax_Force  write FMax_Force;
    property Max_Speed: Single  read FMax_Speed  write FMax_Speed;
    property Wing_Tag: Integer  read FWing_Tag   write FWing_Tag;
  end;

  { Simulation Engine }
  TBoidssEngine2 = class
  private
    FBuffer: TBitmap;
    FParticleCount: Integer;
    FBoids: TObjectList<TBoid_fly>;
    FWing_Data: TPathData;   { Reserved ... }
    FWidth: Single;
    FHeight: Single;

    FSeparationWeight: Single;
    FAlignmentWeight: Single;
    FCohesionWeight: Single;
    FMouseWeight: Single;
    FPerceptionRadius: Single;
    //
    FMousePos: TPointF;
    FIsMouseDown: Boolean;
    FMaxForce: Single;
    FMaxSpeed: Single;
    FLockFlag: Boolean;
    function Align(ABoid: TBoid_fly): TPointF;
    function Cohesion(ABoid: TBoid_fly): TPointF;
    function Separation(ABoid: TBoid_fly): TPointF;
    function Interact(Boid: TBoid_fly): TPointF;
    //
    procedure SetParticleCount(const Value: Integer);
    procedure UpdateBuffer(const AFlag: Boolean = False);
    procedure RenderToBuffer(const ACanvas: TCanvas; const AMousePressed: Boolean; const AMousePos: TPointF);
    procedure SynchronizeBuffer(const AW, AH: SIngle);
  public
    constructor Create(const ACount: Integer; const AWidth, AHeight: Single);
    destructor Destroy; override;
    procedure UpdatePhysics;
    procedure Run(MainCanvas: TCanvas; const CW, CH: SIngle; const Trails: Boolean; const AMousePressed: Boolean; const AMousePos: TPointF);
    procedure Resize(AWidth, AHeight: Single);
    procedure SetMouseInfo(Pos: TPointF; IsDown: Boolean);
    //
    property SeparationWeight: Single       read FSeparationWeight  write FSeparationWeight;
    property AlignmentWeight: Single        read FAlignmentWeight   write FAlignmentWeight;
    property CohesionWeight: Single         read FCohesionWeight    write FCohesionWeight;
    property MouseWeight: Single            read FMouseWeight       write FMouseWeight;
    property PerceptionRadius: Single       read FPerceptionRadius  write FPerceptionRadius;
    property ParticleCount: Integer         read FParticleCount     write SetParticleCount;
    property MaxForce: Single               read FMaxForce          write FMaxForce;
    property MaxSpeed: Single               read FMaxSpeed          write FMaxSpeed;
  end;

implementation

uses
  uCommons;

const               // 0 Up , 1 Down
  CWing_Data: array [0..1] of string = ('M 0,2 C -2,-2 -2,-8 0,-10 C 2,-8 2,-2 0,2 M -2,-6 L -12,-10 L -8,-2 Z M 2,-6 L 12,-10 L 8,-2 Z M 0,-10 L 0,-12',
                                        'M 0,2 C -2,-2 -2,-8 0,-10 C 2,-8 2,-2 0,2 M -2,-6 L -10,2 L -4,4 Z M 2,-6 L 10,2 L 4,4 Z M 0,-10 L 0,-12');

{ TBoid ---------------------------------------------------------------------- }

constructor TBoid_fly.Create(const PosX,PosY: Single);
begin
  Position := TPointF.Create(PosX, PosY);
  // Initialize with random velocity
  Velocity :=     TPointF.Create(RandomRange(-200, 200) / 100, RandomRange(-200, 200) / 100);
  Acceleration := TPointF.Create(0, 0);
  FMax_Force :=   0.5;
  FMax_Speed :=   5.0;
  FWing_Tag :=    Random(100) mod 2;
  //
  FSize := TSizeF.Create(24 + Random(30), 12 + Random(15));
end;

destructor TBoid_fly.Destroy;
begin
  inherited;
end;

procedure TBoid_fly.ApplyForce(Force: TPointF);
begin
  Acceleration := Acceleration + Force;
end;

procedure TBoid_fly.Update;
begin
  Velocity := Velocity + Acceleration;
  Velocity := Limit_Point(Velocity, FMax_Speed);
  Position := Position + Velocity;

  // Reset acceleration after each update
  Acceleration := TPointF.Create(0, 0);
end;

procedure TBoid_fly.Borders(const AWidth, AHeight: Single);
begin
  // Screen wrapping logic
  if Position.X < 0       then Position.X := AWidth;
  if Position.Y < 0       then Position.Y := AHeight;
  if Position.X > AWidth  then Position.X := 0;
  if Position.Y > AHeight then Position.Y := 0;
end;

{ TBoidsEngine --------------------------------------------------------------- }

constructor TBoidssEngine2.Create(const ACount: Integer; const AWidth, AHeight: Single);
begin
  inherited Create;
  FLockFlag := False;

  FBoids := TObjectList<TBoid_fly>.Create(True);
  FWidth :=  AWidth;
  FHeight := AHeight;

  FIsMouseDown := False;
  FMousePos := TPointF.Create(-1000, -1000);

  FSeparationWeight := 1.8;
  FAlignmentWeight :=  1.0;
  FCohesionWeight :=   1.0;
  FPerceptionRadius := 60.0;

  FMaxForce := 0.5;
  FMaxSpeed := 5.0;

  FWing_Data := TPathData.Create;
  FBuffer :=    TBitmap.Create(Round(FWidth), Round(FHeight));
  FBuffer.Clear(TAlphaColorRec.Black);

  FParticleCount := 0;
  SetParticleCount(ACount);
end;

destructor TBoidssEngine2.Destroy;
begin
  FWing_Data.Free;
  FBoids.Free;
  FBuffer.Free;
  inherited;
end;

procedure TBoidssEngine2.Resize(AWidth, AHeight: Single);
begin
  FWidth :=  AWidth;
  FHeight := AHeight;
  FBuffer.SetSize(Round(FWidth), Round(FHeight));
  FBuffer.Clear(TAlphaColorRec.Black);
end;

procedure TBoidssEngine2.SetMouseInfo(Pos: TPointF; IsDown: Boolean);
begin
  FMousePos := Pos;
  FIsMouseDown := IsDown;
end;

function TBoidssEngine2.Interact(Boid: TBoid_fly): TPointF;
begin
  var _Steer := TPointF.Create(0, 0);
  var _Diff :=  TPointF.Create(0, 0);
  var _Dist :=  Boid.Position.Distance(FMousePos);

  if _Dist < 200 then // Radius
    begin
      if FIsMouseDown then
        begin                                                                   // Panic
          _Diff :=  Boid.Position - FMousePos;
          _Diff :=  _Diff.Normalize * Boid.Max_Speed * 2;
          _Steer := _Diff - Boid.Velocity;
          _Steer := Limit_Point(_Steer, Boid.Max_Force * 2);
        end
      else
        begin                                                                   // Attract
          _Diff :=  FMousePos - Boid.Position;
          _Diff :=  Set_Mag(_Diff, Boid.Max_Speed);
          _Steer := _Diff - Boid.Velocity;
          _Steer := Limit_Point(_Steer, Boid.Max_Force * 0.5);
        end;
    end;
  Result := _Steer;
end;

function TBoidssEngine2.Align(ABoid: TBoid_fly): TPointF;
begin
  var _Steering: TPointF := TPointF.Create(0, 0);
  var _Total: Integer := 0;
  var _Dist: Single := 0;
  // Calculate average velocity of neighbors
  for var _Other: TBoid_fly in FBoids do
  begin
    _Dist := ABoid.Position.Distance(_Other.Position);
    if (_Other <> ABoid) and (_Dist < FPerceptionRadius) then
    begin
      _Steering := _Steering + _Other.Velocity;
      Inc(_Total);
    end;
  end;
  if _Total > 0 then
  begin
    _Steering := _Steering / _Total;
    _Steering := Set_Mag(_Steering, ABoid.Max_Speed);
    _Steering := _Steering - ABoid.Velocity;
    _Steering := Limit_Point(_Steering, ABoid.Max_Force);
  end;
  Result := _Steering;
end;

function TBoidssEngine2.Cohesion(ABoid: TBoid_fly): TPointF;
begin
  var _Steering: TPointF := TPointF.Create(0, 0);
  var _Total: Integer := 0;
  var _Dist: Single := 0;
  // Calculate average position of neighbors
  for var _Other: TBoid_fly in FBoids do
  begin
    _Dist := ABoid.Position.Distance(_Other.Position);
    if (_Other <> ABoid) and (_Dist < FPerceptionRadius) then
    begin
      _Steering := _Steering + _Other.Position;
      Inc(_Total);
    end;
  end;
  if _Total > 0 then
  begin
    _Steering := _Steering / _Total;
    _Steering := _Steering - ABoid.Position;
    _Steering := Set_Mag(_Steering, ABoid.Max_Speed);
    _Steering := _Steering - ABoid.Velocity;
    _Steering := Limit_Point(_Steering, ABoid.Max_Force);
  end;
  Result := _Steering;
end;

function TBoidssEngine2.Separation(ABoid: TBoid_fly): TPointF;
begin
  var _Steering: TPointF := TPointF.Create(0, 0);
  var _Total: Integer := 0;
  var _Dist: Single := 0;
  var _Diff: TPointF := PointF(0,0);
  // Steer to avoid crowding neighbors
  for var _Other: TBoid_fly in FBoids do
    begin
      _Dist := ABoid.Position.Distance(_Other.Position);
      if (_Other <> ABoid) and (_Dist < FPerceptionRadius) then
        begin
          _Diff := ABoid.Position - _Other.Position;
          if _Dist > 0 then
            _Diff := _Diff / (_Dist * _Dist);
          _Steering := _Steering + _Diff;
          Inc(_Total);
        end;
    end;
  if _Total > 0 then
    begin
      _Steering := _Steering / _Total;
      _Steering := Set_Mag(_Steering, ABoid.Max_Speed);
      _Steering := _Steering - ABoid.Velocity;
      _Steering := Limit_Point(_Steering, ABoid.Max_Force);
    end;
  Result := _Steering;
end;

procedure TBoidssEngine2.SetParticleCount(const Value: Integer);
begin
  if FParticleCount <> Value then
  begin
    FParticleCount := Value;

    FLockFlag := True;
    FBoids.Clear;
    for var _I := 1 to FParticleCount do
      FBoids.Add(TBoid_fly.Create(Random(Round(FWidth)), Random(Round(FHeight))));
    FLockFlag := False;
  end;
end;

procedure TBoidssEngine2.UpdatePhysics;
begin
  // Parallel processing of Boid physics calculations
  // This significantly improves performance when ParticleCount is high
  TParallel.For(0, FBoids.Count - 1,
  procedure(Index: Integer)
    var
      _Boid: TBoid_fly;
    begin
      _Boid := FBoids[Index];
      _Boid.Max_Force := MaxForce;
      _Boid.Max_Speed := MaxSpeed;

      // Applying Flocking Rules
      _Boid.ApplyForce(Align(_Boid) *      FAlignmentWeight);
      _Boid.ApplyForce(Cohesion(_Boid) *   FCohesionWeight);
      _Boid.ApplyForce(Separation(_Boid) * FSeparationWeight);

      // Mouse interaction
      _Boid.ApplyForce(Interact(_Boid));

      // Update physics state
      _Boid.Update;
      _Boid.Borders(FWidth, FHeight);
    end);
end;

procedure TBoidssEngine2.UpdateBuffer(const AFlag: Boolean = False);
begin
  if FBuffer.Canvas.BeginScene then
  begin
    try
      if AFlag then
        begin
          // Trails effect (partial clear)
          FBuffer.Canvas.Fill.Color := TAlphaColorRec.Black;
          FBuffer.Canvas.Fill.Kind := TBrushKind.Solid;
          FBuffer.Canvas.FillRect(RectF(0, 0, FWidth, FHeight), 0, 0, [], 0.2);
        end
      else
        FBuffer.Canvas.Clear(TAlphaColorRec.Black);
    finally
      FBuffer.Canvas.EndScene;
    end;
  end;
end;

procedure TBoidssEngine2.RenderToBuffer(const ACanvas: TCanvas; const AMousePressed: Boolean; const AMousePos: TPointF);
begin
  // Rendering must be done on the main thread for FMX Canvas safety
  if ACanvas.BeginScene then
  try
    if AMousePressed then
    with ACanvas do
    begin
      Stroke.Color := TAlphaColorRec.White;
      Stroke.Kind := TBrushKind.Solid;
      Stroke.Thickness := 3;
      Stroke.Dash := TStrokeDash.Dot;
      DrawEllipse(RectF(AMousePos.X - 30, AMousePos.Y - 30, AMousePos.X + 30, AMousePos.Y + 30), 0.8);
    end;

    var _Angle: Single := 0;
    var _Tag: Integer := 0;
    for var _Boid: TBoid_fly in FBoids do
      with ACanvas do
      begin
        var _State: TCanvasSaveState := ACanvas.SaveState;
        _Angle := ArcTan2(_Boid.Velocity.Y, _Boid.Velocity.X);
        var _Matrix := TMatrix.Identity;
        _Matrix := TMatrix.CreateScaling(_Boid.Size.Width / 13, _Boid.Size.Height / 10) *
                   TMatrix.CreateRotation(_Angle + DegToRad(90)) *
                   TMatrix.CreateTranslation(_Boid.Position.X, _Boid.Position.Y);

        SetMatrix(_Matrix);

        FWing_Data.Data := CWing_Data[_Boid.Wing_Tag];
        if _Boid.Wing_Tag > 0 then
          begin
            Stroke.Color := GetDirectionColor(_Angle);
            DrawPath(FWing_Data, 0.85);
          end
        else
          begin
            Fill.Color := GetDirectionColor(_Angle);
            Fill.Kind := TBrushKind.Solid;
            FillPath(FWing_Data, 0.85);
          end;

        ACanvas.RestoreState(_State);
        Inc(_Tag);
      end;
  finally
    ACanvas.EndScene;
  end;
end;

procedure TBoidssEngine2.SynchronizeBuffer(const AW, AH: SIngle);
begin
  if (FBuffer.Width <> Round(AW)) or (FBuffer.Height <> Round(AH)) then
  begin
    FWidth :=  AW;
    FHeight := AH;
    FBuffer.SetSize(Round(AW), Round(AH));
  end;
end;

procedure TBoidssEngine2.Run(MainCanvas: TCanvas; const CW, CH: SIngle; const Trails: Boolean; const AMousePressed: Boolean; const AMousePos: TPointF);
begin
  if FLockFlag then Exit;

  // 1. Synchronize buffer sizes with the host canvas ----------------------- //
  SynchronizeBuffer(CW, CH);
  // 2. Physics calculation (Parallel) -------------------------------------- //
  UpdatePhysics;
  // 3. Clear or fade the back buffer --------------------------------------- //
  UpdateBuffer;
  // 4. Render boids to the back buffer ------------------------------------- //
  RenderToBuffer(FBuffer.Canvas, AMousePressed, AMousePos);
  // 5. Transfer buffer to the screen  -------------------------------------- //
  MainCanvas.DrawBitmap(FBuffer, RectF(0, 0, FBuffer.Width, FBuffer.Height), RectF(0, 0, FWidth, FHeight), 1.0);
end;

end.


