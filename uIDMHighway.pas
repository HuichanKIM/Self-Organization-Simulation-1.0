unit uIDMHighway;

interface

uses
  System.SysUtils,
  System.Types,
  System.UITypes,
  System.Classes,
  System.Variants,
  System.Math,
  System.Generics.Collections,
  FMX.Types,
  FMX.Controls,
  FMX.Forms,
  FMX.Graphics,
  FMX.Dialogs,
  FMX.StdCtrls,
  FMX.Objects,
  FMX.Layouts,
  FMX.Edit,
  FMX.Controls.Presentation;

type
  TVehicleType = (Sedan, SUV, Truck, Sport);

  TVehicleProfile = record
    Length: Single;
    Height: Single;
    BodyColor: TAlphaColor;
    RoofColor: TAlphaColor;
  end;

  TRealisticCar = class
  public
    ID: Integer;
    X: Single;           // 도로 상의 위치 (m)
    Lane: Integer;       // 차선 (0-7)
    V: Single;           // 속도 (m/s)
    Direction: Integer;  // 1 (우측), -1 (좌측)
    Acc: Single;         // 가속도
    TypeKey: TVehicleType;
    BrakeLights: Boolean;
    CurrentS: Single;    // 앞차와의 거리
    RequiredS: Single;   // 필요 안전 거리

    constructor Create(AID: Integer; AX: Single; ALane: Integer; AV: Single; AType: TVehicleType; ADir: Integer);
    procedure Draw(ACanvas: TCanvas; const ARoadRect: TRectF; APixelsPerMeter: Single; ARoadLen: Single);
  end;

  TIDMEngine = class
  private
    FCars: TObjectList<TRealisticCar>;
    FParticleCount: Integer;
    FBuffer: TBitmap;
    FCurrentV0: Single;
    FCurrentV_Limit: Single;
    FCurrentT0: Single;
    FCurrentS0: Single;
    FRoadLength0: Single;
    FWidth, FHeight: Single;
    //
    FLockFlag: Boolean;
    FMousePos: TPointF;
    FIsMouseDown: Boolean;
    procedure SetParticleCount(const Value: Integer);
    procedure UpdateBuffer(const AFlag: Boolean = False);
    procedure Render_Cars(AWidth, AHeight, ARoadLength: Single);
    procedure Render_Road(AWidth, AHeight: Single);
  public
    constructor Create(const AWidth, AHeight: Single; const ACount: Integer);
    destructor Destroy; override;

    procedure InitSimulation(ANumCars: Integer; ARoadLength: Single);
    procedure Step(ADT: Single; ARoadLength: Single);

    procedure SetMouseInfo(APos: TPointF; AIsDown: Boolean);
    procedure Run(MainCanvas: TCanvas; const CW, CH: SIngle; const Trails: Boolean; const AMousePressed: Boolean; const AMousePos: TPointF);
    procedure Resize(AWidth, AHeight: Single);

    property ParticleCount: Integer read FParticleCount  write SetParticleCount;
    property Buffer: TBitmap read FBuffer;
    property CurrentV0: Single       read FCurrentV0       write FCurrentV0;
    property CurrentV_Limit: Single  read FCurrentV_Limit  write FCurrentV_Limit;
    property CurrentT: Single        read FCurrentT0       write FCurrentT0;
    property CurrentS0: Single       read FCurrentS0       write FCurrentS0;
    property RoadLength0: Single     read  FRoadLength0    write  FRoadLength0;
  end;

implementation

const
  LANE_WIDTH = 45.0;
  MEDIAN_WIDTH = 40.0;
  ACC_MAX = 2.2;
  DECEL_COMFORT = 4.5;

{ TVehicle Profiles Helper }
function GetProfile(AType: TVehicleType): TVehicleProfile;
begin
  case AType of
    Sedan: begin Result.Length := 5.2;  Result.Height := 18; Result.BodyColor := $FFF8FAFC; Result.RoofColor := $FFCBD5E1; end;
    SUV:   begin Result.Length := 6.8;  Result.Height := 22; Result.BodyColor := $FF475569; Result.RoofColor := $FF1E293B; end;
    Truck: begin Result.Length := 15.0; Result.Height := 24; Result.BodyColor := $FFCBD5E1; Result.RoofColor := $FF94A3B8; end;
    Sport: begin Result.Length := 5.0;  Result.Height := 17; Result.BodyColor := $FFE11D48; Result.RoofColor := $FF9F1239; end;
  end;
end;

{ TRealisticCar }

constructor TRealisticCar.Create(AID: Integer; AX: Single; ALane: Integer; AV: Single; AType: TVehicleType; ADir: Integer);
begin
  ID :=        AID;
  X :=         AX;
  Lane :=      ALane;
  V :=         AV;
  TypeKey :=   AType;
  Direction := ADir;
end;

procedure TRealisticCar.Draw(ACanvas: TCanvas; const ARoadRect: TRectF; APixelsPerMeter: Single; ARoadLen: Single);
begin
  var _Profile: TVehicleProfile := GetProfile(TypeKey);
  var _Center: Single := ARoadRect.Top + (ARoadRect.Height / 2);

  // 좌표 계산
  var _Draw_X: Single := (X / ARoadLen) * ARoadRect.Width;
  var _Draw_Y: Single := 0;
  if Lane < 4 then
    _Draw_Y := _Center - (MEDIAN_WIDTH / 2) - (3 - Lane) * LANE_WIDTH - (LANE_WIDTH / 2)
  else
    _Draw_Y := _Center + (MEDIAN_WIDTH / 2) + (Lane - 4) * LANE_WIDTH + (LANE_WIDTH / 2);

  var _Draw_W: Single := _Profile.Length * APixelsPerMeter;
  var _CarRect: TRectF := TRectF.Create(_Draw_X - _Draw_W/2, _Draw_Y - _Profile.Height/2, _Draw_X + _Draw_W/2, _Draw_Y + _Profile.Height/2);

  // 차체 그림자
  ACanvas.Fill.Color := $66000000;
  ACanvas.FillRect(TRectF.Create(_CarRect.Left+2, _CarRect.Top+2, _CarRect.Right+2, _CarRect.Bottom+2), 3, 3, AllCorners, 1.0);

  // 차체 그리기 (위험 시 빨간색)
  ACanvas.Fill.Color := _Profile.BodyColor;
  if CurrentS < RequiredS then ACanvas.Fill.Color := $FFEF4444;
  ACanvas.FillRect(_CarRect, 3, 3, AllCorners, 1.0);

  // 지붕/창문 디테일
  var _RoofRect: TRectF := _CarRect;
  _RoofRect.Inflate(-_Draw_W * 0.25, -_Profile.Height * 0.15);
  ACanvas.Fill.Color := _Profile.RoofColor;
  ACanvas.FillRect(_RoofRect, 2, 2, AllCorners, 1.0);

  // 헤드라이트 (진행 방향에 따라)
  ACanvas.Fill.Color := $FFFFFFCC;
  if Direction = 1 then
    ACanvas.FillRect(TRectF.Create(_CarRect.Right - 3, _CarRect.Top + 2, _CarRect.Right, _CarRect.Top + 6), 0, 0, [], 1.0)
  else
    ACanvas.FillRect(TRectF.Create(_CarRect.Left, _CarRect.Top + 2, _CarRect.Left + 3, _CarRect.Top + 6), 0, 0, [], 1.0);

  // 브레이크등
  if BrakeLights then
  begin
    ACanvas.Fill.Color := $FFFF0000;
    if Direction = 1 then
      ACanvas.FillRect(TRectF.Create(_CarRect.Left - 1, _CarRect.Top + 2, _CarRect.Left + 2, _CarRect.Bottom - 2), 0, 0, [], 1.0)
    else
      ACanvas.FillRect(TRectF.Create(_CarRect.Right - 2, _CarRect.Top + 2, _CarRect.Right + 1, _CarRect.Bottom - 2), 0, 0, [], 1.0);
  end;
end;

{ TIDMEngine }

constructor TIDMEngine.Create(const AWidth, AHeight: Single; const ACount: Integer);
begin
  FWidth :=  Max(1, AWidth);
  FHeight := Max(1, AHeight);

  FCars := TObjectList<TRealisticCar>.Create(True);
  FBuffer := TBitmap.Create(Round(FWidth), Round(FHeight));
  FBuffer.Clear(TAlphaColorRec.Black);

  FLockFlag := False;
  FParticleCount := 0;
  FRoadLength0 := 1400.0; //////////////////////////////////////////////////////
  FCurrentV_Limit := 110;
  FCurrentV0 := 110 / 3.6;
  FCurrentT0 := 1.8;
  FCurrentS0 := 5.0;

  SetParticleCount(FParticleCount);
end;

destructor TIDMEngine.Destroy;
begin
  FCars.Free;
  FBuffer.Free;
  inherited;
end;

procedure TIDMEngine.InitSimulation(ANumCars: Integer; ARoadLength: Single);
begin
  FLockFlag := True;
  FCars.Clear;
  var _Lane: Integer := 0;
  var _XPos: Single := 0;
  var _CarType: TVehicleType;
  for var _i := 0 to ANumCars - 1 do
  begin
    //_Lane := Random(8);
    //_XPos := Random * ARoadLength;
    //_CarType := TVehicleType(Random(4));
    //FCars.Add(TRealisticCar.Create(_i, _XPos, _Lane, FCurrentV0 * (0.4 + Random * 0.4), _CarType, IfThen(_Lane < 4, 1, -1)));
  //end;

  //Cars.Clear;
  //for i := 0 to NumCars - 1 do
  //begin
    _Lane := Random(8);
    _XPos := (_i / ANumCars) * ARoadLength + (Random * 20); // Distributed start
    _CarType := TVehicleType(Random(4));
    FCars.Add(TRealisticCar.Create(_i, _XPos, _Lane, FCurrentV0 * 0.8, _CarType, IfThen(_Lane < 4, 1, -1)));
  end;
  FLockFlag := False;
end;

procedure TIDMEngine.SetParticleCount(const Value: Integer);
begin
  if FParticleCount <> Value then
  begin
    FParticleCount := Value;
    InitSimulation(FParticleCount, FRoadLength0);
  end;
end;

procedure TIDMEngine.SetMouseInfo(APos: TPointF; AIsDown: Boolean);
begin
  FMousePos := APos;
  FIsMouseDown := AIsDown;
end;

procedure TIDMEngine.Resize(AWidth, AHeight: Single);
begin
  FWidth :=  Max(1, AWidth);
  FHeight := Max(1, AHeight);
  FBuffer.SetSize(Round(FWidth), Round(FHeight));
  FBuffer.Clear(TAlphaColorRec.Black);
end;
{
procedure TIDMEngine.Step(ADT: Single; ARoadLength: Single);
begin
  var _sdiff: Single := 0;
  var _dv: Single := 0;
  var _minS: Single := 0;

  for var _Car: TRealisticCar in FCars do
  begin
    _minS := 1000.0;
    _dv := 0;

    // 같은 차선의 앞차 탐색
    for var Other: TRealisticCar in FCars do
    begin
      if (_Car = Other) or (_Car.Lane <> Other.Lane) then Continue;

      // 상대 거리 계산 (Cyclic Boundary)
      _sdiff := IfThen(_Car.Direction = 1, Other.X - _Car.X, _Car.X - Other.X);
      if _sdiff < 0 then _sdiff := _sdiff + ARoadLength;

      if _sdiff < _minS then
      begin
        _minS := _sdiff;
        _dv := _Car.V - Other.V;
      end;
    end;

    _Car.CurrentS := Max(0.1, _minS - GetProfile(_Car.TypeKey).Length);

    // IDM (Intelligent Driver Model) 핵심 로직
    _Car.RequiredS := FCurrentS0 + Max(0, (_Car.V * FCurrentT0) + (_Car.V * _dv) / (2 * Sqrt(ACC_MAX * DECEL_COMFORT)));

    var FreeRoadTerm: Single := Power(_Car.V / FCurrentV0, 4);
    var InteractionTerm: Single := Power(_Car.RequiredS / _Car.CurrentS, 2);

    _Car.Acc := ACC_MAX * (1 - FreeRoadTerm - InteractionTerm);

    // 비정상적인 접근 시 감속 가중치
    if _Car.CurrentS < FCurrentS0 then
      _Car.Acc := _Car.Acc - Power(FCurrentS0 / _Car.CurrentS, 3) * 2;
  end;

  // 위치 및 속도 업데이트
  for var _Car: TRealisticCar in FCars do
  begin
    _Car.V := Max(0, _Car.V + _Car.Acc * ADT);
    _Car.X := _Car.X + (_Car.V * _Car.Direction) * ADT;

    if _Car.X > ARoadLength then _Car.X := _Car.X - ARoadLength;
    if _Car.X < 0 then _Car.X := _Car.X + ARoadLength;
    _Car.BrakeLights := _Car.Acc < -0.6;
  end;
end;
}
procedure TIDMEngine.Step(ADT: Single; ARoadLength: Single);
var
  _Car, _Other: TRealisticCar;
  _s, _dv, _minS: Single;
  _InteractionTerm, _FreeRoadTerm: Single;
begin
  for _Car in FCars do
  begin
    _minS := 1000.0;
    _dv := 0;

    for _Other in FCars do
    begin
      if (_Car = _Other) or (_Car.Lane <> _Other.Lane) then Continue;

      _s := IfThen(_Car.Direction = 1, _Other.X - _Car.X, _Car.X - _Other.X);
      if _s < 0 then _s := _s + ARoadLength;

      if _s < _minS then
      begin
        _minS := _s;
        _dv := _Car.V - _Other.V;
      end;
    end;

    _Car.CurrentS := Max(0.1, _minS - GetProfile(_Car.TypeKey).Length);
    _Car.RequiredS := FCurrentS0 + Max(0, (_Car.V * FCurrentT0) + (_Car.V * _dv) / (2 * Sqrt(ACC_MAX * DECEL_COMFORT)));

    _FreeRoadTerm := Power(_Car.V / Max(0.1, FCurrentV0), 4);
    _InteractionTerm := Power(_Car.RequiredS / _Car.CurrentS, 2);

    _Car.Acc := ACC_MAX * (1 - _FreeRoadTerm - _InteractionTerm);

    if _Car.CurrentS < FCurrentS0 then
      _Car.Acc := _Car.Acc - Power(FCurrentS0 / _Car.CurrentS, 2);
  end;

  for _Car in FCars do
  begin
    _Car.V := Max(0, _Car.V + _Car.Acc * ADT);
    _Car.X := _Car.X + (_Car.V * _Car.Direction) * ADT;

    if _Car.X > ARoadLength then _Car.X := _Car.X - ARoadLength;
    if _Car.X < 0 then _Car.X := _Car.X + ARoadLength;
    _Car.BrakeLights := _Car.Acc < -0.5;
  end;
end;

procedure TIDMEngine.Render_Road(AWidth, AHeight: Single);
begin
  if (AWidth <= 0) or (AHeight <= 0) then Exit;

  if FBuffer.Canvas.BeginScene then
  with FBuffer.Canvas do
  try
    //FBuffer.Canvas.Clear($FF0F172A); // 배경 (Dark Slate)

    var _RoadRect: TRectF := TRectF.Create(0, AHeight/2 - 200, AWidth, AHeight/2 + 200);

    // 도로 바닥
    Fill.Color := $FF1E293B;
    FillRect(_RoadRect, 0, 0, [], 1.0);

    // 중앙 분리대 영역
    Fill.Color := $FF334155;
    FillRect(TRectF.Create(0, AHeight/2 - (MEDIAN_WIDTH/2), AWidth, AHeight/2 + (MEDIAN_WIDTH/2)), 0, 0, [], 1.0);

    // 차선 (점선)
    Stroke.Color := $33FFFFFF;
    Stroke.Dash := TStrokeDash.Dash;
    Stroke.Thickness := 2;

    var _Y: Single := 0;
    for var _i := 1 to 3 do
    begin
      _Y := AHeight/2 - (MEDIAN_WIDTH/2) - (_i * LANE_WIDTH);
      DrawLine(PointF(0, _Y), PointF(AWidth, _Y), 1.0);
      _Y := AHeight/2 + (MEDIAN_WIDTH/2) + (_i * LANE_WIDTH);
      DrawLine(PointF(0, _Y), PointF(AWidth, _Y), 1.0);
    end;

    // 중앙 노란선
    Stroke.Color := $FFB1A21E;
    Stroke.Dash := TStrokeDash.Solid;
    DrawLine(PointF(0, AHeight/2 - (MEDIAN_WIDTH/2)+2), PointF(AWidth, AHeight/2 - (MEDIAN_WIDTH/2)+2), 1.0);
    DrawLine(PointF(0, AHeight/2 + (MEDIAN_WIDTH/2)-2), PointF(AWidth, AHeight/2 + (MEDIAN_WIDTH/2)-2), 1.0);

  finally
    FBuffer.Canvas.EndScene;
  end;
end;

procedure TIDMEngine.Render_Cars(AWidth, AHeight: Single; ARoadLength: Single);
begin
  var _PixelsPerMeter := AWidth / 250; // Dynamic scale for 250m visible window or adjust as needed
  if _PixelsPerMeter < 4 then _PixelsPerMeter := 4; // Min scale

  if FBuffer.Canvas.BeginScene then
  try
    var _RoadRect: TRectF := TRectF.Create(0, AHeight/2 - 200, AWidth, AHeight/2 + 200);
    for var _Car: TRealisticCar in FCars do
      _Car.Draw(FBuffer.Canvas, _RoadRect, _PixelsPerMeter, ARoadLength);
  finally
    FBuffer.Canvas.EndScene;
  end;
end;

procedure TIDMEngine.UpdateBuffer(const AFlag: Boolean = False);
begin
  if FBuffer.Canvas.BeginScene then
  begin
    try
      FBuffer.Canvas.Clear(TAlphaColorRec.Black);
    finally
      FBuffer.Canvas.EndScene;
    end;
  end;
end;

procedure TIDMEngine.Run(MainCanvas: TCanvas; const CW, CH: SIngle; const Trails, AMousePressed: Boolean; const AMousePos: TPointF);
begin
  if FLockFlag then Exit;

  // 버퍼 크기 동기화
  if (FBuffer.Width <> Round(CW)) or (FBuffer.Height <> Round(CH)) then
   begin
     FWidth := CW;
     FHeight := CH;
     FBuffer.SetSize(Round(CW), Round(CH));
   end;

  // ------------------------------------------------------------------------ //
  // 엔진 파라미터 업데이트 및 물리 계산
  FCurrentV0 := FCurrentV_Limit / 3.6;
  Step(0.016, FRoadLength0);
  // ------------------------------------------------------------------------ //

  UpdateBuffer(False);
  Render_Road(CW, CH);
  Render_Cars(CW, CH,  FRoadLength0);

  MainCanvas.DrawBitmap(FBuffer, RectF(0, 0, FWidth, FHeight), RectF(0, 0, FWidth, FHeight), 1.0);
end;

end.
