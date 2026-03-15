unit uRainDropEngine;

interface

uses
  System.SysUtils,
  System.Types,
  System.UITypes,
  System.Classes,
  System.Math,
  System.Generics.Collections,
  System.Generics.Defaults,
  System.Threading,
  FMX.Graphics,
  FMX.Objects,
  FMX.Effects,
  Winapi.Windows; { Winapi.Windows for Beep function }

type
  { Particle structure for a single raindrop }
  TRainDrop = record
    X, Y: Single;         { Current Position }
    TargetY: Single;      { Perspective hit ground Y-coordinate }
    Speed: Single;        { Falling speed based on depth }
    Length: Single;       { Visual length of the drop }
    Depth: Single;        { 0.1 (Far) to 1.0 (Near) }
    IsSplashing: Boolean; { State: falling or hitting ground }
    SplashRadius: Single; { Current ripple size }

    { Thread-Safety flags for parallel processing }
    JustHit: Boolean;     { Flag to trigger splash sound/event on Main Thread }
    NeedsReset: Boolean;  { Flag to reset drop safely on Main Thread (avoids Random() race condition) }

    procedure ResetPosition(CanvasWidth, CanvasHeight: Single);
    procedure Initialize(CanvasWidth, CanvasHeight, HorizonY, ADepth: Single);
  end;

  { TLightningSegment: A single segment of a lightning bolt }
  TLightningSegment = record
    P1, P2: TPointF;
    Thickness: Single;
    Alpha: Single;
  end;

  { Core Simulation Engine }
  TRainDropEngine = class
  private
    FLockFlag: Boolean;                                 // Lock for initialization
    FDrops: TArray<TRainDrop>;
    FDropCount: Integer;
    FWidth, FHeight: Single;
    FHorizonY: Single;
    { ... }
    FBuffer: FMX.Graphics.TBitmap;
    FMousePos: TPointF;                                 // Current mouse position
    FIsMouseDown: Boolean;                              // Mouse click state
    FMaskWindowFlag: Boolean;
    { Lightning effect state }
    FLightningAlpha: Single; { 0.0 to 255.0 }
    FLightningSegments: TList<TLightningSegment>;       // Actual shapes of the lightning
    FThunderFlag: Boolean;
    FChangeCatDogFlag: Integer;
    FLampPos: TPointF;
    //
    FTime: Single;
    procedure SetDropCount(const Value: Integer);
    procedure UpdateBuffer(const CW, CH: Single);
    { Triggers a lightning flash }
    procedure CreateSubdivisions(const AP1, AP2: TPointF; const ADisplacement: Single; Const AMinDist: Single; const ACurrentThickness: Single);
    procedure GenerateLichtenbergBolt(StartPos, EndPos: TPointF);
    procedure TriggerLightning(const AMouseXPos: TPointF);
    { Plays a procedural thunder sound using system beep }
    procedure PlayThunderSound;
    procedure UpdateFrameWFrame(const ADrawFlag: Boolean; AMainanvas: TCanvas);
  public
    constructor Create(AWidth, AHeight: Single; ADropCount: Integer = 300);
    destructor Destroy; override;
    procedure UpdatePhysics(const DeltaTime: Single);
    procedure RenderToBuffer(const ACanvas: TCanvas; const AOpacity: Single = 1.0);
    procedure Resize(const AWidth, AHeight: Single);
    procedure Run(MainCanvas: TCanvas; const CW, CH: Single; const Trails, AMousePressed: Boolean; const AMousePos: TPointF);
    procedure SetMouseInfo(const APos: TPointF; const AIsDown1, AIsDown2: Boolean);

    property DropCount: Integer           read FDropCount       write SetDropCount;
    property MaskWindowFlag: Boolean      read FMaskWindowFlag  write FMaskWindowFlag;
  end;

implementation

uses
  Winapi.MMSystem,
  uCommons,
  uResources;

const
  C_ThunderSoundALias = 'thunder';
  C_ThunderSoundFile  = 'thunder.mp3';

{ TRainDrop Implementation }

procedure TRainDrop.ResetPosition(CanvasWidth, CanvasHeight: Single);
begin
  X := Random * CanvasWidth;
  { Always spawn above the visible top edge }
  Y := -100 - (Random * CanvasHeight);
  IsSplashing := False;
  SplashRadius := 0;
  JustHit := False;
  NeedsReset := False;
end;

procedure TRainDrop.Initialize(CanvasWidth, CanvasHeight, HorizonY, ADepth: Single);
begin
  Depth := ADepth;
  { Use Power of 2 (Sqr) for non-linear perspective distribution }
  { Non-linear target Y distribution for better depth feeling }
  TargetY := HorizonY + (Power(Depth, 1.5) * (CanvasHeight - HorizonY));

  { Scale properties based on distance (Depth) }
  Speed := (15 + Random * 25) * Depth;
  { Near drops are significantly longer }
  Length := (10 + Random * 15) * Power(Depth, 1.2);

  ResetPosition(CanvasWidth, CanvasHeight);
  { Initially scatter vertically so the screen is immediately filled }
  Y := TargetY - (Random * CanvasHeight * 1.5);
end;

{ TRainDropEngine Implementation }

constructor TRainDropEngine.Create(AWidth, AHeight: Single; ADropCount: Integer);
begin
  inherited Create;
  FLockFlag :=       False;
  FMaskWindowFlag := False;
  FThunderFlag :=    False;
  FWidth :=          AWidth;
  FHeight :=         AHeight;

  FTime := 0;

  FChangeCatDogFlag := 0;
  { Define Horizon Line at 55% of the screen height }
  FHorizonY := FHeight * 0.55;   { Ground level }
  FLightningAlpha := 0;
  FLightningSegments := TList<TLightningSegment>.Create;

  { Initialize Bitmap Buffer }
  FBuffer := FMX.Graphics.TBitmap.Create;
  FBuffer.SetSize(Ceil(AWidth), Ceil(AHeight));

  SetDropCount(ADropCount);
end;

destructor TRainDropEngine.Destroy;
begin
  mciSendString('close '+C_ThunderSoundALias, nil, 0, 0);
  FBuffer.Free;
  FLightningSegments.Free;
  inherited;
end;

procedure TRainDropEngine.SetDropCount(const Value: Integer);
begin
  FLockFlag := True;
  FDropCount := Value;
  SetLength(FDrops, FDropCount);

  { Assign random depths and initialize }
  for var i := 0 to High(FDrops) do
    FDrops[i].Initialize(FWidth, FHeight, FHorizonY, 0.1 + (Random * 0.9));

  { Sort array by Depth (Painter's algorithm)
    This ensures drops further away (lower depth) are drawn FIRST,
    preventing far ripples from drawing on top of near ripples. }
  TArray.Sort<TRainDrop>(FDrops, TComparer<TRainDrop>.Construct(
    function(const L, R: TRainDrop): Integer
    begin
      if L.Depth < R.Depth then Result := -1  else
      if L.Depth > R.Depth then Result := 1
      else
        Result := 0;
    end
  ));

  FLockFlag := False;
end;

procedure TRainDropEngine.SetMouseInfo(const APos: TPointF; const AIsDown1, AIsDown2: Boolean);
begin
  FMousePos := APos;
  FIsMouseDown := AIsDown1;
  { Trigger lightning effect on mouse down }
  if AIsDown1 then TriggerLightning(APos);
  if AIsDown2 then
    MaskWindowFlag := not FMaskWindowFlag;
end;

procedure TRainDropEngine.Resize(const AWidth, AHeight: Single);
begin
  FLockFlag := True;

  FWidth :=    AWidth;
  FHeight :=   AHeight;
  FHorizonY := AHeight * 0.55;

  { Re-calculate the TargetY for all drops based on new dimensions }
  for var _i := 0 to High(FDrops) do
    FDrops[_i].TargetY := FHorizonY + (Power(FDrops[_i].Depth, 1.5) * (FHeight - FHorizonY));

  FLockFlag := False;
end;

procedure TRainDropEngine.PlayThunderSound;
begin
  if FThunderFlag then Exit;

  { Run sound in a separate thread to prevent freezing the UI during Beep sequence }
  TThread.CreateAnonymousThread(
    procedure
    begin
      FThunderFlag := True;
      Sleep(100); { thunder delay }
      mciSendString(PChar('close ' + C_ThunderSoundALias), nil, 0, 0);
      if mciSendString(PChar('open "' + string(C_ThunderSoundFile) + '" type mpegvideo alias ' + C_ThunderSoundALias), nil, 0, 0) = 0 then
        mciSendString(PChar('play ' + C_ThunderSoundALias), nil, 0, 0);
      FThunderFlag := False;
    end).Start;
end;

procedure TRainDropEngine.UpdatePhysics(const DeltaTime: Single);
begin
  if Length(FDrops) = 0 then Exit;

  FTime := FTime + DeltaTime;

  // Handle Lightning Fade-out
  if FLightningAlpha > 0 then
  begin
    FLightningAlpha := FLightningAlpha - (500.0 * DeltaTime);
    if FLightningAlpha < 0 then
    begin
      FLightningAlpha := 0;
      FLightningSegments.Clear;
    end;
  end;

  // Parallel update for performance
  TParallel.For(0, High(FDrops), procedure(Index: Integer)
  var
    _Drop: TRainDrop;
  begin
    _Drop := FDrops[Index];
    _Drop.JustHit := False;
    if not _Drop.IsSplashing then
    begin
      _Drop.Y := _Drop.Y + (_Drop.Speed * DeltaTime * 60);
      if _Drop.Y >= _Drop.TargetY then
      begin
        _Drop.Y := _Drop.TargetY;
        _Drop.IsSplashing := True;
        _Drop.JustHit := True;
      end;
    end
    else
    begin
      _Drop.SplashRadius := _Drop.SplashRadius + (3.5 * _Drop.Depth);
      if _Drop.SplashRadius > (50.0 * Power(_Drop.Depth, 1.3)) then
        _Drop.NeedsReset := True;
    end;
    FDrops[Index] := _Drop;
  end);

  // Process state changes on main thread
  for var _i := 0 to High(FDrops) do
  begin
    if FDrops[_i].NeedsReset then
      FDrops[_i].ResetPosition(FWidth, FHeight);
  end;
end;

procedure TRainDropEngine.GenerateLichtenbergBolt(StartPos, EndPos: TPointF);
begin
  FLightningSegments.Clear;
  { Displacement: controls jaggedness, MinDist: controls detail level }
  CreateSubdivisions(StartPos, EndPos, StartPos.Distance(EndPos) * 0.6, 5.0, 3.0);
end;

procedure TRainDropEngine.TriggerLightning(const AMouseXPos: TPointF);
begin
  FLightningAlpha := 255.0;

  { Start from top (randomly slightly offset from click X) }
  var _StartPoint := PointF(AMouseXPos.X + (Random * 300 - 150), 0);//PointF(AMouseXPos.X + (Random * 200 - 100), 0);
  { End exactly at Mouse Click position }
  var _EndPoint := PointF(AMouseXPos.X, AMouseXPos.Y);
  FLampPos := PointF(150, 100);

  //  Lichtenberg Algorithms ------------------------------------------------ //
  GenerateLichtenbergBolt(_StartPoint, _EndPoint);
  //  LichtenbergBolt ------------------------------------------------------- //
  { Play the system beep thunder effect }
  PlayThunderSound;
end;

{ Recursive Subdivision }
procedure TRainDropEngine.CreateSubdivisions(const AP1, AP2: TPointF; const ADisplacement: Single; Const AMinDist: Single; const ACurrentThickness: Single);
begin
  var _Dist := AP1.Distance(AP2);
  var _Seg: TLightningSegment;
  { Base Case: If the segment is small enough, add it to the list }
  if _Dist < AMinDist then
  begin
    _Seg.P1 := AP1;
    _Seg.P2 := AP2;
    _Seg.Thickness := ACurrentThickness;
    _Seg.Alpha := 1.0;

    FLightningSegments.Add(_Seg);

    Exit;
  end;

  { Calculate midpoint and apply perpendicular ADisplacement for jagged look }
  var _Mid :=    PointF((AP1.X + AP2.X) / 2, (AP1.Y + AP2.Y) / 2);
  var _Normal := PointF(-(AP2.Y - AP1.Y), AP2.X - AP1.X); { Perpendicular vector }
  if _Normal.Length > 0 then _Normal := _Normal * (1.0 / _Normal.Length);

  _Mid.X := _Mid.X + _Normal.X * (Random - 0.5) * ADisplacement;
  _Mid.Y := _Mid.Y + _Normal.Y * (Random - 0.5) * ADisplacement;

  { Branching Logic: Create secondary branches with a specific probability }
  if (ACurrentThickness > 1.0) and (Random < 0.2) then
  begin
    var _BranchEnd: TPointF;
    { Branch extends outward based on parent direction }
    _BranchEnd.X := _Mid.X + (_Mid.X - AP1.X) * 0.7 + (Random - 0.5) * ADisplacement;
    _BranchEnd.Y := _Mid.Y + (_Mid.Y - AP1.Y) * 0.7 + (Random - 0.5) * ADisplacement;
    CreateSubdivisions(_Mid, _BranchEnd, ADisplacement * 0.5, AMinDist, ACurrentThickness * 0.5);
  end;

  { Recursive Subdivision }
  CreateSubdivisions(AP1, _Mid, ADisplacement * 0.5, AMinDist, ACurrentThickness);
  CreateSubdivisions(_Mid, AP2, ADisplacement * 0.5, AMinDist, ACurrentThickness);
end;

procedure TRainDropEngine.RenderToBuffer(const ACanvas: TCanvas; const AOpacity: Single);
begin
  if ACanvas.BeginScene then
  try
    { a NightView of Seoul, Korea }
    if FMaskWindowFlag then
    with Form_Resources.Image_seoul do
      begin
        var _scale := Bitmap.Height / Bitmap.Width;
        ACanvas.DrawBitmap(Bitmap, RectF(0, 0, Bitmap.Width, Bitmap.Height), RectF(0, 0, FWidth, FHeight * _scale), 1.0);
      end;

    ACanvas.Stroke.Kind := TBrushKind.Solid;
    var _ColorRec: TAlphaColorRec := TAlphaColorRec.Create(TAlphaColorRec.White);

    { 1. Ground Gradient Background (Atmospheric Depth) }
    { Draws a darkening gradient from horizon to bottom }
    for var _i := 0 to 20 do
    begin
      var _SegDepth := _i / 20.0;
      var _SegY1 := FHorizonY + (_SegDepth * (FHeight - FHorizonY));
      var _SegY2 := FHorizonY + ((_i + 1) / 20.0 * (FHeight - FHorizonY));

      _ColorRec := TAlphaColorRec.Create(TAlphaColorRec.Black);
      { Gradient: 0 (at horizon) to 80 (at bottom) alpha of a dark blueish slate }
      _ColorRec.B := 40;
      _ColorRec.A := Round(80 * _SegDepth * AOpacity);

      ACanvas.Fill.Color := TAlphaColor(_ColorRec);
      ACanvas.FillRect(TRectF.Create(0, _SegY1, FWidth, _SegY2), 0, 0, [], 1.0);
    end;

    { 2. Ground Perspective Lines: Enhances the flat plane feeling of the floor }
    ACanvas.Stroke.Kind := TBrushKind.Solid;
    for var _i := 1 to 6 do
    begin
      var _lineDepth := _i / 6.0;
      var _lineY := FHorizonY + (Power(_lineDepth, 1.5) * (FHeight - FHorizonY));

      _ColorRec := TAlphaColorRec.Create(TAlphaColorRec.Slategray);
      _ColorRec.A := Round(50 * AOpacity * _lineDepth);
      ACanvas.Stroke.Color := TAlphaColor(_ColorRec);
      ACanvas.Stroke.Thickness := 0.2 + (_lineDepth * 2.5); { Thicker lines for near ground }
      ACanvas.DrawLine(PointF(0, _lineY), PointF(FWidth, _lineY), 1.0);
    end;

    { 3. Draw all drops }
    for var _i := 0 to High(FDrops) do
    begin
      var _Drop := FDrops[_i];
      if not _Drop.IsSplashing then
        begin
          { Falling Drop Visualization }
          _ColorRec := TAlphaColorRec.Create(TAlphaColorRec.White);
          _ColorRec.A := Round(200 * _Drop.Depth * AOpacity);
          ACanvas.Stroke.Color := TAlphaColor(_ColorRec);

          { Perspective thickness: Squared depth for extra emphasis on near drops }
          ACanvas.Stroke.Thickness := Max(0.4, 4.5 * Sqr(_Drop.Depth));

          ACanvas.DrawLine(PointF(_Drop.X, _Drop.Y),
                           PointF(_Drop.X, _Drop.Y + _Drop.Length), 1.0);
        end
      else
        begin
         { Draw ground ripple (ellipse) and splash sparks }
          var _MaxRadius := 80.0 * Power(_Drop.Depth, 1.3);                     { control factor }
          var _Progress := _Drop.SplashRadius / _MaxRadius;
          var _SplashAlpha := 1.0 - _Progress;

          { Ripple (Flattened Ellipse) }
          _ColorRec := TAlphaColorRec.Create(TAlphaColorRec.Lightskyblue);
          _ColorRec.A := Round(230 * _SplashAlpha * AOpacity);
          ACanvas.Stroke.Color := TAlphaColor(_ColorRec);

          { Near ripples are much thicker }
          ACanvas.Stroke.Thickness := Max(0.2, 7.0 * Sqr(_Drop.Depth));         { control factor }

          var _Rect: TRectF;
          _Rect.Left :=    _Drop.X - _Drop.SplashRadius;
          _Rect.Top :=     _Drop.Y - (_Drop.SplashRadius * 0.20);               { Flatter perspective }
          _Rect.Right :=   _Drop.X + _Drop.SplashRadius;
          _Rect.Bottom :=  _Drop.Y + (_Drop.SplashRadius * 0.20);

          ACanvas.DrawEllipse(_Rect, 1.0);

          { Enhanced Spark Effect }
          if _Progress < 0.35 then
            begin
              var _SparkAlpha := (0.35 - _Progress) / 0.35;
              _ColorRec := TAlphaColorRec.Create(TAlphaColorRec.White);
              _ColorRec.A := Round(255 * _SparkAlpha * AOpacity);
              ACanvas.Stroke.Color := TAlphaColor(_ColorRec);
              ACanvas.Stroke.Thickness := ACanvas.Stroke.Thickness * 0.2;       { Flatter perspective }

              var _SparkHeight := 13.0 * _Drop.Depth * _SparkAlpha;  // 15.0 * _Drop[_i].Depth * _SparkAlpha;
              ACanvas.DrawLine(PointF(_Drop.X - 2, _Drop.Y), PointF(_Drop.X - 5, _Drop.Y - _SparkHeight),   1.0);
              ACanvas.DrawLine(PointF(_Drop.X, _Drop.Y),     PointF(_Drop.X, _Drop.Y - _SparkHeight * 1.3), 1.0);
              ACanvas.DrawLine(PointF(_Drop.X + 2, _Drop.Y), PointF(_Drop.X + 5, _Drop.Y - _SparkHeight),   1.0);
            end;
        end;
    end;

    { 4. Render Lightning Bolt terminating at Target }
    if (FLightningAlpha > 0) and (FLightningSegments.Count > 0) then
    begin
      { Background Flash }
      _ColorRec := TAlphaColorRec.Create(TAlphaColorRec.White);
      _ColorRec.A := Round(FLightningAlpha * 0.2);
      ACanvas.Fill.Color := TAlphaColor(_ColorRec);
      ACanvas.FillRect(TRectF.Create(0, 0, FWidth, FHeight), 0, 0, [], 1.0);

      { Outer Glow Path }
      ACanvas.Stroke.Kind := TBrushKind.Solid;
      for var _Seg in FLightningSegments do
      begin
        _ColorRec := TAlphaColorRec.Create(TAlphaColorRec.Lightskyblue);
        _ColorRec.A := Round(FLightningAlpha * 0.4);
        ACanvas.Stroke.Color := TAlphaColor(_ColorRec);
        ACanvas.Stroke.Thickness := _Seg.Thickness * 3.5;
        ACanvas.DrawLine(_Seg.P1, _Seg.P2, 0.5);
      end;

      { Core Bright Path }
      for var _Seg in FLightningSegments do
      begin
        _ColorRec := TAlphaColorRec.Create(TAlphaColorRec.Yellow);
        _ColorRec.A := Round(FLightningAlpha);
        ACanvas.Stroke.Color := TAlphaColor(_ColorRec);
        ACanvas.Stroke.Thickness := _Seg.Thickness;
        ACanvas.DrawLine(_Seg.P1, _Seg.P2, 1.0);
      end;
    end;
  finally
    ACanvas.EndScene;
  end;
end;

procedure TRainDropEngine.UpdateBuffer(const CW, CH: Single);
begin
  { Ensure buffer size matches PaintBox }
  if (FBuffer.Width <> Ceil(CW)) or (FBuffer.Height <> Ceil(CH)) then
    begin
      FWidth :=  CW;
      FHeight := CH;
      FBuffer.SetSize(Ceil(FWidth), Ceil(FHeight));
    end;

  { Start drawing on the Bitmap's Canvas }
  if FBuffer.Canvas.BeginScene then
  try
    { Clear the background }
    FBuffer.Canvas.Clear(TAlphaColorRec.Black);
  finally
    FBuffer.Canvas.EndScene;
  end;
end;

procedure TRainDropEngine.UpdateFrameWFrame(const ADrawFlag: Boolean; AMainanvas: TCanvas);
begin
  if ADrawFlag then
  with Form_Resources do
  begin
    with Image_WindowFrame do
      AMainanvas.DrawBitmap(Bitmap, RectF(0, 0, Bitmap.Width, Bitmap.Height), RectF(0, 0, FWidth, FHeight), 1.0);

    if FLightningAlpha > 0 then
      begin
         with Image_AniSurprise do
         AMainanvas.DrawBitmap(Bitmap, RectF(0, 0, Bitmap.Width, Bitmap.Height),
                                       RectF(FWidth -  Bitmap.Width - 50,
                                             FHeight - Bitmap.Height - 80,
                                             FWidth -  50,
                                             FHeight - 30),
                                1.0);
         FChangeCatDogFlag := 0;
      end
    else
      begin
        Inc(FChangeCatDogFlag);
        { 30 fps x 30 sec = 900 }
        var _timeflag :=  FChangeCatDogFlag mod 900;
        var _Image := IIF.CastBool<TImage>((_timeflag  > 0 ) and (_timeflag < 600 ), Image_AniNormal, Image_AniFront);
        with _Image do
        AMainanvas.DrawBitmap(Bitmap, RectF(0, 0, Bitmap.Width, Bitmap.Height),
                                      RectF(FWidth -  Bitmap.Width - 50,
                                            FHeight - Bitmap.Height - 80,
                                            FWidth - 50,
                                            FHeight - 30),
                               1.0);
      end;
  end;
end;

procedure TRainDropEngine.Run(MainCanvas: TCanvas; const CW, CH: Single; const Trails, AMousePressed: Boolean; const AMousePos: TPointF);
begin
  if FLockFlag then Exit;

  // 1. Update physics and flocking data ------------------------------------ //
  UpdatePhysics(33 / 1000);   // TimerUpdate.Interval / 1000
  // 2. Sync buffer size ---------------------------------------------------- //
  UpdateBuffer(CW, CH);
  // 3. Rendering on buffer canvas (Sequential) ----------------------------- //
  RenderToBuffer(FBuffer.Canvas, 1.0); // Opacity ...
  // 4. Draw final buffer to main canvas ------------------------------------ //
  var _maskoffset: Integer := IIF.CastBool<Integer>(FMaskWindowFlag, 30, 0);
  MainCanvas.DrawBitmap(FBuffer, RectF(0, 0, FBuffer.Width, FBuffer.Height), RectF(0, 0, FWidth, FHeight-_maskoffset), 1.0);
  // 5. Show Windows Frame -------------------------------------------------- //
  UpdateFrameWFrame(FMaskWindowFlag, MainCanvas);
end;

end.
