unit uBoidsSim0;

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
  end;

  { Simulation Engine }
  //TVicsekEngine2 = class
  TBoidssEngine0 = class
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

    FNeighborRadius: Single;     // Interaction radius
    FAlignmentWeight: Single;    // Weight for alignment behavior               // Boids element ?
    FCohesionWeight: Single;     // Weight for cohesion behavior                // Boids element ?
    FSeparationWeight: Single;   // Weight for separation behavior              // Boids element ?
    FMaxSpeed: Single;           // Maximum movement speed
    FMinSpeed: Single;           // Minimum movement speed
    procedure DrawFishAll(ACanvas: TCanvas);
    procedure SetNeighborRadius(const Value: Single);
    function GetFishCount: Integer;
    procedure UpdateFishBodyPath(const ATailWag: Single);
    procedure UpdateFishCount(const ACount: Integer; const AViewRect: TRectF);
    procedure UpdatePhysics(const ARect: TRectF; const ADeltaTime: Single);
    procedure SetFishCount(const Value: Integer);
    procedure UpdateBuffer(const AW, AH: Single; const AFlag: Boolean = False);
    procedure RenderToBuffer(const ACanvas: TCanvas; const AMousePressed: Boolean; const AMousePos: TPointF);
  public
    constructor Create(const ACount: Integer; const AViewRect: TRectF);
    destructor Destroy; override;

    procedure Resize(AWidth, AHeight: Single);
    procedure Run(MainCanvas: TCanvas; const CW, CH: Single; const Trails, AMousePressed: Boolean; const AMousePos: TPointF);
    procedure SetMouseInfo(APos: TPointF; AIsDown: Boolean);

    property FishCount: Integer         read GetFishCount        write SetFishCount;
    property NeighborRadius: Single     read FNeighborRadius     write SetNeighborRadius;
    property SeparationWeight: Single   read FSeparationWeight   write FSeparationWeight;
    property AlignmentWeight: Single    read FAlignmentWeight    write FAlignmentWeight;
    property CohesionWeight: Single     read FCohesionWeight     write FCohesionWeight;
    property MaxSpeed: Single           read FMaxSpeed           write FMaxSpeed;
  end;

implementation

uses
  uCommons;

{ TVicsekEngine2 }

constructor TBoidssEngine0.Create(const ACount: Integer; const AViewRect: TRectF);
begin
  inherited Create;
  FTime := 0;
  FMousePos := TPointF.Create(-1000, -1000);
  FIsMouseDown := False;
  FLockFlag := False;

  FWidth :=  Max(1, Round(AViewRect.Width));
  FHeight := Max(1, Round(AViewRect.Height));
  FBuffer := TBitmap.Create(Round(FWidth), Round(FHeight));

  { Adjusted weights for smoother movement }
  FNeighborRadius :=   60.0;
  FAlignmentWeight :=  0.08;    // Reduced from 1.0 to prevent instant snapping
  FCohesionWeight :=   0.02;    // Slightly reduced for less "clumping" jitter
  FSeparationWeight := 0.8;     // Reduced from 1.5 to soften repulsion
  FMaxSpeed :=         4.2;     // Reduced from 2.5 for calmer flow
  FMinSpeed :=         1.0;

  { Define the static part of the fish body }
  FBaseBody := TPathData.Create;
  FTailPath := TPathData.Create;

  UpdateFishBodyPath(0);
  UpdateFishCount(ACount, AViewRect);
end;

destructor TBoidssEngine0.Destroy;
begin
  FBaseBody.Free;
  FTailPath.Free;
  FBuffer.Free;
  inherited;
end;

function TBoidssEngine0.GetFishCount: Integer;
begin
  Result := Length(FFishes);
end;

procedure TBoidssEngine0.UpdateFishBodyPath(const ATailWag: Single);
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

procedure TBoidssEngine0.UpdateFishCount(const ACount: Integer; const AViewRect: TRectF);
begin
  var _OldCount := Length(FFishes);
  if _OldCount = ACount then Exit;

  FLockFlag := True;
  SetLength(FFishes, ACount);
  Randomize;

  if ACount > _OldCount then
  begin
    var _Angle: Single := 0;
    for var _i := _OldCount to ACount - 1 do
    with FFishes[_i] do
    begin
      _Angle := Random * 2 * Pi;
      Position :=    PointF(Random * AViewRect.Width, Random * AViewRect.Height);
      Velocity :=    PointF(Cos(_Angle), Sin(_Angle)) * (FMinSpeed + Random * 2);
      Color :=       TAlphaColorRec.Alpha or TAlphaColor(Random($FFFFFF));
      Size :=        TSizeF.Create(22 + Random(30), 12 + Random(15)); // cx -15   cy - 8
      PhaseOffset := Random * 2 * Pi;
    end;
  end;

  FLockFlag := False;
end;

procedure TBoidssEngine0.SetNeighborRadius(const Value: Single);
begin
  FNeighborRadius := Value;
end;

procedure TBoidssEngine0.SetFishCount(const Value: Integer);
begin
  if FFishCount <> Value then
  begin
    FFishCount := Value;
    UpdateFishCount(Value, RectF(0,0,FWidth, FHeight));
  end;
end;

procedure TBoidssEngine0.SetMouseInfo(APos: TPointF; AIsDown: Boolean);
begin
  FMousePos := APos;
  FIsMouseDown := AIsDown;
end;

procedure TBoidssEngine0.Resize(AWidth, AHeight: Single);
begin
  FLockFlag := True;
  FWidth :=  Max(1, AWidth);
  FHeight := Max(1, AHeight);
  FBuffer.SetSize(Round(FWidth), Round(FHeight));
  FBuffer.Clear(TAlphaColorRec.Black);
  FLockFlag := False;
end;

procedure TBoidssEngine0.UpdatePhysics(const ARect: TRectF; const ADeltaTime: Single);
begin
  FTime := FTime + ADeltaTime;
  var _FCount := Length(FFishes);
  var _NewFishes: TArray<TFish>;
  SetLength(_NewFishes, _FCount);

  // Parallel processing of fish flocking logic
  TParallel.For(0, _FCount - 1,
  procedure(Index: Integer)
  var
    _AvgVel, _AvgPos, _Separation: TPointF;
    _NeighborCount: Integer;
    _Dist, _Speed: Single;
    _TargetVel: TPointF;
    _CurrentFish: TFish;
  begin
    _CurrentFish := FFishes[Index];
    _AvgVel := PointF(0, 0);
    _AvgPos := PointF(0, 0);
    _Separation := PointF(0, 0);
    _NeighborCount := 0;

    for var _j := 0 to _FCount - 1 do
    begin
      if Index = _j then Continue;

      var _Diff := FFishes[_j].Position - _CurrentFish.Position;
      if _Diff.X > ARect.Width / 2  then _Diff.X := _Diff.X - ARect.Width;      // Toroidal distance correction
      if _Diff.X < -ARect.Width / 2 then _Diff.X := _Diff.X + ARect.Width;
      if _Diff.Y > ARect.Height / 2  then _Diff.Y := _Diff.Y - ARect.Height;
      if _Diff.Y < -ARect.Height / 2 then _Diff.Y := _Diff.Y + ARect.Height;

      _Dist := _Diff.Length;
      if (_Dist > 0) and (_Dist < FNeighborRadius) then
      begin
        _AvgVel := _AvgVel + FFishes[_j].Velocity;
        _AvgPos := _AvgPos + FFishes[_j].Position;
        _Separation := _Separation + (_Diff.Normalize * -1.0 / _Dist);          // Separatin: steering away from neighbors
        Inc(_NeighborCount);
      end;
    end;

    _TargetVel := _CurrentFish.Velocity;

    if _NeighborCount > 0 then
    begin
      _AvgVel := _AvgVel / _NeighborCount;
      _AvgPos := (_AvgPos / _NeighborCount) - _CurrentFish.Position;

      // Apply flocking rules weights
      _TargetVel := _TargetVel + (_AvgVel * FAlignmentWeight);
      _TargetVel := _TargetVel + (_AvgPos * FCohesionWeight);
      _TargetVel := _TargetVel + (_Separation * FSeparationWeight * 20.0);
    end;

    var _MouseDiff := FMousePos - _CurrentFish.Position;                        // Mouse interaction logic
    var _MouseDist := _MouseDiff.Length;
    if _MouseDist < 100 then
    begin
      if FIsMouseDown then
        _TargetVel := _TargetVel + (_MouseDiff.Normalize * 2.0) // Attract
      else
        _TargetVel := _TargetVel - (_MouseDiff.Normalize * 1.5); // Repel
    end;

    _Speed := _TargetVel.Length;                                                // Limit _Speed and update position
    if _Speed > FMaxSpeed then
      _TargetVel := _TargetVel.Normalize * FMaxSpeed;
    if _Speed < 0.5 then
      _TargetVel := _TargetVel.Normalize * 0.5;

    _CurrentFish.Velocity := _TargetVel;
    _CurrentFish.Position := _CurrentFish.Position + _CurrentFish.Velocity;
    _CurrentFish.Color := GetDirectionColor(ArcTan2(_CurrentFish.Velocity.Y, _CurrentFish.Velocity.X));

    // Screen wrapping
    if _CurrentFish.Position.X < ARect.Left then _CurrentFish.Position.X := ARect.Right;
    if _CurrentFish.Position.X > ARect.Right then _CurrentFish.Position.X := ARect.Left;
    if _CurrentFish.Position.Y < ARect.Top then _CurrentFish.Position.Y := ARect.Bottom;
    if _CurrentFish.Position.Y > ARect.Bottom then _CurrentFish.Position.Y := ARect.Top;

    _NewFishes[Index] := _CurrentFish;
  end);

  FFishes := _NewFishes;
end;

procedure TBoidssEngine0.DrawFishAll(ACanvas: TCanvas);
begin
  for var _i := 0 to Length(FFishes) - 1 do
    begin
      var _State: TCanvasSaveState := ACanvas.SaveState;
      var _Fish := FFishes[_i];
      try
        var _Angle: Single := ArcTan2(_Fish.Velocity.Y, _Fish.Velocity.X);
        var _Matrix := TMatrix.Identity;
        _Matrix := TMatrix.CreateScaling(_Fish.Size.Width / 13, _Fish.Size.Height / 10) *
                   TMatrix.CreateRotation(_Angle) *
                   TMatrix.CreateTranslation(_Fish.Position.X, _Fish.Position.Y);

        with ACanvas do
          begin
            SetMatrix(_Matrix);
            Fill.Color := _Fish.Color;
            Fill.Kind := TBrushKind.Solid;
            FillPath(FBaseBody, 0.85);
          end;

        { Update tail animation path }
        var _TailWag: Single := Sin((FTime + _Fish.PhaseOffset) * 15) * 3.5;
        with FTailPath do
          begin
            Clear;
            MoveTo(TPointF.Create(-4, 0));
            LineTo(TPointF.Create(-8, -3.5 + _TailWag));
            LineTo(TPointF.Create(-8, 3.5 +  _TailWag));
            ClosePath;
          end;

        ACanvas.FillPath(FTailPath, 0.85);

        with ACanvas do
          begin
            Stroke.Color := TAlphaColorRec.Black;
            Stroke.Thickness := 0.6;
            DrawPath(FBaseBody, 0.4);
            DrawPath(FTailPath, 0.4);

            Fill.Color := TAlphaColorRec.White; { Draw eyes }
            FillEllipse(TRectF.Create(3.2, -2.2, 5.0, -0.4), 1.0);
          end;
      finally
        ACanvas.RestoreState(_State);
      end;
    end;
end;

procedure TBoidssEngine0.RenderToBuffer(const ACanvas: TCanvas; const AMousePressed: Boolean; const AMousePos: TPointF);
begin
  if ACanvas.BeginScene then
  try
    DrawFishAll(ACanvas);//
  finally
    ACanvas.EndScene;
  end;

  // 4. Show interaction range if mouse is pressed -------------------------- //
  if AMousePressed then
  with ACanvas do
  if BeginScene then
  try
    Stroke.Color := TAlphaColorRec.White;
    Stroke.Kind := TBrushKind.Solid;
    Stroke.Thickness := 1;
    Stroke.Dash := TStrokeDash.Dot;
    DrawEllipse(RectF(AMousePos.X - FNeighborRadius, AMousePos.Y - FNeighborRadius,
                      AMousePos.X + FNeighborRadius, AMousePos.Y + FNeighborRadius), 0.8);
  finally
    EndScene;
  end;
end;

procedure TBoidssEngine0.UpdateBuffer(const AW, AH: Single; const AFlag: Boolean = False);
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
          FillRect(RectF(0, 0, FWidth, FHeight), 0, 0, [], 0.2);
        end
      else
        Clear(TAlphaColorRec.Black);
    finally
      EndScene;
    end;
end;

procedure TBoidssEngine0.Run(MainCanvas: TCanvas; const CW, CH: Single; const Trails, AMousePressed: Boolean; const AMousePos: TPointF);
begin
  if FLockFlag then Exit;

  // 1. Update physics and flocking data ------------------------------------ //
  UpdatePhysics(RectF(0, 0, CW, CH), 0.02);
  // 2. Sync buffer size ---------------------------------------------------- //
  UpdateBuffer(CW, CH);
  // 3. Rendering on buffer canvas (Sequential) ----------------------------- //
  RenderToBuffer(FBuffer.Canvas, AMousePressed, AMousePos);
  // 4. Draw final buffer to main canvas ------------------------------------ //
  MainCanvas.DrawBitmap(FBuffer, RectF(0, 0, FBuffer.Width, FBuffer.Height), RectF(0, 0, FWidth, FHeight), 1.0);
end;

end.
