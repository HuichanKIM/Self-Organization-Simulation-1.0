unit PhyllotaxisPlant;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Math,
  System.Math.Vectors, FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics,
  FMX.Objects, FMX.Effects, FMX.Filter.Effects;

type
  { --- Phyllotaxis Engine --- }
  TLeafData = record
    Position: TPointF;
    Angle: Single;
    Scale: Single;
    Color: TAlphaColor;
  end;

  TPlantEngine = class
  private
    FLeafCount: Integer;
    FGoldenAngle: Single;
    FSpacing: Single;
    FLeaves: array of TLeafData;
    procedure Generate(Center: TPointF);
  public
    constructor Create;
    procedure Render(Canvas: TCanvas; SceneRect: TRectF);
    property LeafCount: Integer read FLeafCount write FLeafCount;
  end;

  { --- Main Form --- }
  TFormPlant = class(TForm)
    PaintBoxMain: TPaintBox;
    TimerAnim: TTimer;
    procedure FormCreate(Sender: TObject);
    procedure PaintBoxMainPaint(Sender: TObject; Canvas: TCanvas);
    procedure TimerAnimTimer(Sender: TObject);
  private
    FEngine: TPlantEngine;
    FOffset: Single;
  public
  end;

var
  FormPlant: TFormPlant;

implementation

{ TPlantEngine }

constructor TPlantEngine.Create;
begin
  FLeafCount := 180;
  FGoldenAngle := 137.5 * (PI / 180);
  FSpacing := 8.0;
end;

procedure TPlantEngine.Generate(Center: TPointF);
var
  I: Integer;
  R, Theta: Single;
begin
  SetLength(FLeaves, FLeafCount);
  for I := 0 to FLeafCount - 1 do
  begin
    // 피보나치 나선 공식
    Theta := I * FGoldenAngle;
    R := FSpacing * Sqrt(I + 1) * 2.5;

    FLeaves[I].Position := PointF(Center.X + Cos(Theta) * R, Center.Y + Sin(Theta) * R);
    FLeaves[I].Angle := RadToDeg(Theta) + 90;
    FLeaves[I].Scale := 0.5 + (I / FLeafCount) * 2.5;
    
    // 색상 보간 (중심은 진한 녹색, 외곽은 밝은 연두색)
    FLeaves[I].Color := InterpolateColor($FF104020, $FF90FF60, I / FLeafCount);
  end;
end;

procedure TPlantEngine.Render(Canvas: TCanvas; SceneRect: TRectF);
var
  I: Integer;
  Path: TPathData;
  State: TCanvasSaveState;
  Center: TPointF;
  LeafRect: TRectF;
begin
  Center := SceneRect.CenterPoint;
  Generate(Center);

  Path := TPathData.Create;
  try
    // 유기적인 잎 모양 정의 (Bezier 곡선)
    Path.MoveTo(PointF(0, 0));
    Path.CurveTo(PointF(-10, -15), PointF(-5, -30), PointF(0, -40));
    Path.CurveTo(PointF(5, -30), PointF(10, -15), PointF(0, 0));
    Path.ClosePath;

    // 뒤쪽 잎부터 그리기 위해 역순 렌더링
    for I := FLeafCount - 1 downto 0 do
    begin
      State := Canvas.SaveState;
      try
        Canvas.Translate(FLeaves[I].Position.X, FLeaves[I].Position.Y);
        Canvas.Rotate(FLeaves[I].Angle);
        Canvas.Scale(FLeaves[I].Scale, FLeaves[I].Scale);

        // 잎 채우기 (그라데이션)
        Canvas.Fill.Kind := TBrushKind.Gradient;
        Canvas.Fill.Gradient.Color := FLeaves[I].Color;
        Canvas.Fill.Gradient.Color1 := TAlphaColorRec.White; // 하이라이트 효과
        
        // 외곽선 (이미지의 하얀 테두리 효과)
        Canvas.Stroke.Color := $CCFFFFFF;
        Canvas.Stroke.Thickness := 0.5 / FLeaves[I].Scale;
        Canvas.Stroke.Kind := TBrushKind.Solid;

        Canvas.FillPath(Path, 0.8);
        Canvas.DrawPath(Path, 1.0);
      finally
        Canvas.RestoreState(State);
      end;
    end;
  finally
    Path.Free;
  end;
end;

{ TFormPlant }

procedure TFormPlant.FormCreate(Sender: TObject);
begin
  FEngine := TPlantEngine.Create;
  FOffset := 0;
  // 배경색을 이미지와 유사한 어두운 청록색 계열로 설정
  Self.Fill.Color := $FF051510;
  Self.Fill.Kind := TBrushKind.Solid;
end;

procedure TFormPlant.PaintBoxMainPaint(Sender: TObject; Canvas: TCanvas);
var
  Rect: TRectF;
begin
  Rect := TRectF.Create(0, 0, PaintBoxMain.Width, PaintBoxMain.Height);
  
  // 배경에 부드러운 빛망울 효과 (단순 원형으로 구현)
  Canvas.Fill.Color := $2200FF88;
  Canvas.FillEllipse(TRectF.Create(Rect.Width*0.6, Rect.Height*0.2, Rect.Width*0.9, Rect.Height*0.5), 0.3);
  
  FEngine.Render(Canvas, Rect);
end;

procedure TFormPlant.TimerAnimTimer(Sender: TObject);
begin
  // 미세한 움직임을 위해 다시 그리기
  PaintBoxMain.Repaint;
end;

end.