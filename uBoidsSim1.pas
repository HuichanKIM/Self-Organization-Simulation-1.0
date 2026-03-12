unit uBoidsSim1;

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
  { Individual Arrow Object }
  TBoid = class
  private
  public
    Position: TVector;
    Velocity: TVector;
    Acceleration: TVector;
    constructor Create(AWidth, AHeight: Single);
    procedure ApplyForce(Force: TVector);
    function Seek(Target: TVector; MaxSpeed, MaxForce: Single): TVector;        // Attraction
    function Flee(Target: TVector; MaxSpeed, MaxForce: Single): TVector;        // Diffusion
  end;

  { Simulation Engine }
  TBoidssEngine1 = class
  private
    FLockFlag: Boolean;
    FBoids: TObjectList<TBoid>;
    FWidth, FHeight: Single;
    FBuffer: TBitmap;
    FAlphaAmount: Single;
    //
    FMousePos: TPointF;
    FIsMouseDown: Boolean;
    procedure UpdateBuffer(const AW, AH: Single; const AFlag: Boolean = False);
    procedure SetParticleCount(const Value: Integer);
    procedure UpdatePhysics(const AMousePressed1, AMousePressed2: Boolean; const AMousePos: TPointF);
    procedure RenderToBuffer(const ACanvas: TCanvas; const AMousePressed: Boolean; const AMousePos: TPointF);
  public
    FParticleCount: Integer;
    FSeparationWeight: Single;
    FAlignmentWeight: Single;
    FCohesionWeight: Single;
    FMouseWeight: Single;
    FPerceptionRadius: Single;
    FMaxSpeed: Single;
    FMaxForce: Single;
    constructor Create(const AWidth, AHeight: Single; const ACount: Integer);
    destructor Destroy; override;
    { MousePressed: Left, MouseSecondaryPressed: Right }
    procedure Run(MainCanvas: TCanvas; const CW, CH: Single; const AMousePressed1, AMousePressed2: Boolean; const AMousePos: TPointF);
    procedure Resize(const AWidth, AHeight: Single);
    procedure SetMouseInfo(Pos: TPointF; IsDown: Boolean);
    property TrailingAmount: Single read FAlphaAmount write FAlphaAmount;
    //
    property ParticleCount: Integer    read FParticleCount     write SetParticleCount;
    property SeparationWeight: Single  read FSeparationWeight  write FSeparationWeight;
    property AlignmentWeight: Single   read FAlignmentWeight   write FAlignmentWeight;
    property CohesionWeight: Single    read FCohesionWeight    write FCohesionWeight;
    property MouseWeight: Single       read FMouseWeight       write FMouseWeight;
    property PerceptionRadius: Single  read FPerceptionRadius  write FPerceptionRadius;
    property MaxSpeed: Single          read FMaxSpeed          write FMaxSpeed;
    property MaxForce: Single          read FMaxForce          write FMaxForce;
  end;

implementation

uses
  uCommons;

{ TBoid }

constructor TBoid.Create(AWidth, AHeight: Single);
begin
  Position :=     Vector(Random * AWidth, Random * AHeight);
  Velocity :=     Vector(Random * 2 - 1, Random * 2 - 1);
  Velocity :=     Velocity.Normalize * (Random * 2 + 2);
  Acceleration := Vector(0, 0);
end;

procedure TBoid.ApplyForce(Force: TVector);
begin
  // Explicit management because W elements can change during TVector operation
  Acceleration.X := Acceleration.X + Force.X;
  Acceleration.Y := Acceleration.Y + Force.Y;
  Acceleration.W := 1.0;
end;

function TBoid.Seek(Target: TVector; MaxSpeed, MaxForce: Single): TVector;
begin
  var _Desired := Vector(Target.X - Position.X, Target.Y - Position.Y, 1.0);
  if _Desired.Length > 0 then
    begin
      _Desired := _Desired.Normalize * MaxSpeed;
      var _Steer := Vector(_Desired.X - Velocity.X, _Desired.Y - Velocity.Y, 1.0);

      Result := _Steer.Limit(MaxForce);
    end
  else
    Result := Vector(0, 0);
end;

function TBoid.Flee(Target: TVector; MaxSpeed, MaxForce: Single): TVector;
begin
  var _Desired: TVector := Vector(Position.X - Target.X, Position.Y - Target.Y, 1.0);
  var _Steer: TVector :=   Vector(0,0,0);
  if _Desired.Length > 0 then
    begin
      _Desired := _Desired.Normalize * MaxSpeed;
      _Steer.X := _Desired.X - Velocity.X;
      _Steer.Y := _Desired.Y - Velocity.Y;
      _Steer.W := 1.0;

      Result := _Steer.Limit(MaxForce);
    end
  else
    Result := Vector(0, 0);
end;

{ TBoidsEngine }

constructor TBoidssEngine1.Create(const AWidth, AHeight: Single; const ACount: Integer);
begin
  FBoids := TObjectList<TBoid>.Create(True);
  FWidth :=  Max(1, AWidth);
  FHeight := Max(1, AHeight);
  FAlphaAmount := 0.2;

  FLockFlag := False;

  FBuffer := TBitmap.Create(Round(FWidth), Round(FHeight));
  FBuffer.Clear(TAlphaColorRec.Black);

  FParticleCount :=    ACount;
  FSeparationWeight := 1.8;
  FAlignmentWeight :=  1.0;
  FCohesionWeight :=   1.0;
  FPerceptionRadius := 60.0;
  FMouseWeight :=      3.0;
  FMaxSpeed :=         5.0;
  FMaxForce :=         0.2;

  FIsMouseDown := False;
  FMousePos := PointF(-1000, -1000);                                            // Initial mouse position (off-screen)

  for var _i := 1 to ACount do
    FBoids.Add(TBoid.Create(FWidth, FHeight));     // FWidth, FHeight - Position
end;

destructor TBoidssEngine1.Destroy;
begin
  FBuffer.Free;
  FBoids.Free;
  inherited;
end;

procedure TBoidssEngine1.Resize(const AWidth, AHeight: Single);
begin
  FLockFlag := True;
  FWidth :=  Max(1, AWidth);
  FHeight := Max(1, AHeight);
  FBuffer.SetSize(Round(FWidth), Round(FHeight));
  FBuffer.Clear(TAlphaColorRec.Black);
  FLockFlag := False;
end;

procedure TBoidssEngine1.SetMouseInfo(Pos: TPointF; IsDown: Boolean);
begin
  FMousePos := Pos;
  FIsMouseDown := IsDown;
end;

procedure TBoidssEngine1.SetParticleCount(const Value: Integer);
begin
  if FParticleCount <> Value then
  begin
    FParticleCount := Value;

    FLockFlag := True;
    FBoids.Clear;
    for var _I := 1 to FParticleCount do
      FBoids.Add(TBoid.Create(FWidth, FHeight));
    FLockFlag := False;
  end;
end;

procedure TBoidssEngine1.UpdatePhysics(const AMousePressed1, AMousePressed2: Boolean; const AMousePos: TPointF);
begin
  var _Target := Vector(AMousePos.X, AMousePos.Y);
  // 1. Parallel Processing ------------------------------------------------- //
  TParallel.For(0, FParticleCount - 1,
    procedure(Index: Integer)
    begin
      var _Align: TVector := Vector(0, 0);
      var _Coh: TVector := Vector(0, 0);
      var _Sep: TVector := Vector(0, 0);
      var _MouseForce: TVector := Vector(0, 0);
      var _Total: Integer := 0;
      var _Dist: Single := 0;

      var _CurrentBoid := FBoids[Index];

      for var _Other: TBoid in FBoids do
        begin
          _Dist := Sqrt(Sqr(_CurrentBoid.Position.X - _Other.Position.X) + Sqr(_CurrentBoid.Position.Y - _Other.Position.Y));
          if (_Other <> _CurrentBoid) and (_Dist < FPerceptionRadius) then
            begin
              _Align.X := _Align.X + _Other.Velocity.X;
              _Align.Y := _Align.Y + _Other.Velocity.Y;

              _Coh.X := _Coh.X + _Other.Position.X;
              _Coh.Y := _Coh.Y + _Other.Position.Y;

              if _Dist > 0 then
                begin
                  _Sep.X := _Sep.X + (_CurrentBoid.Position.X - _Other.Position.X) / (_Dist * _Dist);
                  _Sep.Y := _Sep.Y + (_CurrentBoid.Position.Y - _Other.Position.Y) / (_Dist * _Dist);
                end;
              Inc(_Total);
            end;
        end;

      if _Total > 0 then
        begin
          _Align.X := _Align.X / _Total;
          _Align.Y := _Align.Y / _Total;
          _Align := _Align.Normalize * MaxSpeed;
          _Align.X := _Align.X - _CurrentBoid.Velocity.X;
          _Align.Y := _Align.Y - _CurrentBoid.Velocity.Y;
          _Align := _Align.Limit(FMaxForce);

          _Coh.X := (_Coh.X / _Total) - _CurrentBoid.Position.X;
          _Coh.Y := (_Coh.Y / _Total) - _CurrentBoid.Position.Y;
          _Coh := _Coh.Normalize * FMaxSpeed;
          _Coh.X := _Coh.X - _CurrentBoid.Velocity.X;
          _Coh.Y := _Coh.Y - _CurrentBoid.Velocity.Y;
          _Coh := _Coh.Limit(FMaxForce);

          _Sep.X := _Sep.X / _Total;
          _Sep.Y := _Sep.Y / _Total;
          _Sep := _Sep.Normalize * FMaxSpeed;
          _Sep.X := _Sep.X - _CurrentBoid.Velocity.X;
          _Sep.Y := _Sep.Y - _CurrentBoid.Velocity.Y;
          _Sep := _Sep.Limit(FMaxForce);

          _CurrentBoid.ApplyForce(_Align * FAlignmentWeight);
          _CurrentBoid.ApplyForce(_Coh *   FCohesionWeight);
          _CurrentBoid.ApplyForce(_Sep *   FSeparationWeight);
        end;

      // Mouse Interaction: Seek or Flee
      var _MouseDist := Sqrt(Sqr(_CurrentBoid.Position.X - _Target.X) + Sqr(_CurrentBoid.Position.Y - _Target.Y));
      if AMousePressed1 then
        begin
          _MouseForce := _CurrentBoid.Seek(_Target, FMaxSpeed, FMaxForce * 1.5);
          _CurrentBoid.ApplyForce(_MouseForce * FMouseWeight);
        end
      else if AMousePressed2 then
        begin
          if _MouseDist < 200 then
            begin
              _MouseForce := _CurrentBoid.Flee(_Target, FMaxSpeed * 1.2, FMaxForce * 2.0);
              _CurrentBoid.ApplyForce(_MouseForce * FMouseWeight * 2);
            end;
        end;

      // Update Velosity, Position
      _CurrentBoid.Velocity.X := _CurrentBoid.Velocity.X + _CurrentBoid.Acceleration.X;
      _CurrentBoid.Velocity.Y := _CurrentBoid.Velocity.Y + _CurrentBoid.Acceleration.Y;
      _CurrentBoid.Velocity := _CurrentBoid.Velocity.Limit(FMaxSpeed);

      _CurrentBoid.Position.X := _CurrentBoid.Position.X + _CurrentBoid.Velocity.X;
      _CurrentBoid.Position.Y := _CurrentBoid.Position.Y + _CurrentBoid.Velocity.Y;

      // Update Edges
      if _CurrentBoid.Position.X > FWidth then _CurrentBoid.Position.X := 0;
      if _CurrentBoid.Position.X < 0 then _CurrentBoid.Position.X := FWidth;
      if _CurrentBoid.Position.Y > FHeight then _CurrentBoid.Position.Y := 0;
      if _CurrentBoid.Position.Y < 0 then _CurrentBoid.Position.Y := FHeight;
      _CurrentBoid.Acceleration := Vector(0, 0);
    end);
end;

procedure TBoidssEngine1.RenderToBuffer(const ACanvas: TCanvas; const AMousePressed: Boolean; const AMousePos: TPointF);
begin
  if ACanvas.BeginScene then
  try
    ACanvas.Clear(TAlphaColorRec.Black);
    for var _Boid in FBoids do
      begin
        var _Angle: Single := ArcTan2(_Boid.Velocity.Y, _Boid.Velocity.X);
        var _State: TCanvasSaveState := ACanvas.SaveState;
        try
          ACanvas.SetMatrix(ACanvas.Matrix * TMatrix.CreateRotation(_Angle) * TMatrix.CreateTranslation(_Boid.Position.X, _Boid.Position.Y));
          ACanvas.Fill.Color := GetDirectionColor(_Angle);
          ACanvas.Fill.Kind := TBrushKind.Solid;

          ACanvas.FillPolygon([PointF(8, 0), PointF(-6, 4), PointF(-3, 0), PointF(-6, -4)], 1.0);
        finally
          ACanvas.RestoreState(_State);
         end;
      end;
  finally
    ACanvas.EndScene;
  end;
end;

procedure TBoidssEngine1.UpdateBuffer(const AW, AH: Single; const AFlag: Boolean = False);
begin
  if (FBuffer.Width <> Round(AW)) or (FBuffer.Height <> Round(AH)) then
  begin
    FWidth :=  AW;
    FHeight := AH;
    FBuffer.SetSize(Round(AW), Round(AH));
  end;

  with FBuffer.Canvas do
  if BeginScene then
    try
      if AFlag then
        begin
          Fill.Color := TAlphaColorRec.Black;
          Fill.Kind := TBrushKind.Solid;
          FillRect(RectF(0, 0, FWidth, FHeight), 0, 0, [], FAlphaAmount);
        end
      else
        Clear(TAlphaColorRec.Black);
    finally
      EndScene;
    end;
end;

procedure TBoidssEngine1.Run(MainCanvas: TCanvas; const CW, CH: Single; const AMousePressed1, AMousePressed2: Boolean; const AMousePos: TPointF);
begin
  if FLockFlag then Exit;

  // 1. Parallel update of Boids logic  ------------------------------------- //
  UpdatePhysics(AMousePressed1, AMousePressed2, AMousePos);
  // 2. Update Buffer Canvas ------------------------------------------------ //
  UpdateBuffer(CW, CH, True);
  // 3. Rendering on buffer canvas (Sequential) ----------------------------- //
  RenderToBuffer(FBuffer.Canvas, AMousePressed1, AMousePos);
  // 4. Output buffer to main canvas  --------------------------------------- //
  MainCanvas.DrawBitmap(FBuffer, RectF(0, 0, FWidth, FHeight), RectF(0, 0, FWidth, FHeight), 1.0);
end;

end.
