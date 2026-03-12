unit uPhyllotaxisPlant;

interface

uses
  System.SysUtils,
  System.Types,
  System.UITypes,
  System.Classes,
  System.Math,
  System.Math.Vectors,
  System.Threading, // Required for TParallel
  FMX.Types,
  FMX.Controls,
  FMX.Forms,
  FMX.Graphics,
  FMX.Objects,
  System.UIConsts;

type
  { Data structure for each leaf in the phyllotaxis pattern }
  TLeafData = record
    Position: TPointF;
    Angle: Single;
    Scale: Single;
    Color: TAlphaColor;
  end;

  { Plant simulation engine using Phyllotaxis algorithm }
  TPlantEngine = class
  private
    FLeafCount: Integer;
    FGoldenAngle: Single;
    FSpacing: Single;
    FLeaves: array of TLeafData;
    FLogoText: string;
    function InterpolateAlphaColor(const AStartColor, AEndColor: TAlphaColor; const AT: Single): TAlphaColor;
    procedure Generate(const AViewRect: TRectF; const ACenter: TPointF);
    procedure DrawSignature(ACanvas: TCanvas; const ASceneRect: TRectF);
  public
    constructor Create;
    procedure Render(ACanvas: TCanvas; ASceneRect: TRectF);
    property LeafCount: Integer read FLeafCount write FLeafCount;
    property LogoText: string   read FLogoText  write FLogoText;
  end;

implementation

uses
  uCommons;

{ TPlantEngine }

constructor TPlantEngine.Create;
begin
  inherited Create;
  FLeafCount := 120; // Default number of leaves
  FGoldenAngle := 137.5; // Phyllotaxis golden angle
  FSpacing := 6.5; // Spacing between leaves
  FLogoText := 'Delphi Phyllotaxis';
end;

function TPlantEngine.InterpolateAlphaColor(const AStartColor, AEndColor: TAlphaColor; const AT: Single): TAlphaColor;
begin
  // Precision color interpolation using TAlphaColorRec (Delphi 12 feature)
  var _S := TAlphaColorRec(AStartColor);
  var _E := TAlphaColorRec(AEndColor);
  var _R: TAlphaColorRec;
  _R.A := Round(_S.A + (_E.A - _S.A) * AT);
  _R.R := Round(_S.R + (_E.R - _S.R) * AT);
  _R.G := Round(_S.G + (_E.G - _S.G) * AT);
  _R.B := Round(_S.B + (_E.B - _S.B) * AT);
  Result := TAlphaColor(_R);
end;

procedure TPlantEngine.Generate(const AViewRect: TRectF; const ACenter: TPointF);
begin
  if Length(FLeaves) <> FLeafCount then
    SetLength(FLeaves, FLeafCount);

  { Parallel generation of leaf positions and attributes }
  TParallel.For(0, FLeafCount - 1, procedure(Index: Integer)
  var
    _Angle, _Radius: Single;
    _Norm: Single;
  begin
    { Phyllotaxis algorithm: calculate polar coordinates }
    _Angle := Index * DegToRad(FGoldenAngle);
    _Radius := FSpacing * Sqrt(Index + 1);

    { Convert to Cartesian coordinates }
    FLeaves[Index].Position := PointF(
      ACenter.X + Cos(_Angle) * _Radius,
      ACenter.Y + Sin(_Angle) * _Radius
    );

    { Visual attributes }
    FLeaves[Index].Angle := RadToDeg(_Angle) + 90; // Rotate leaf to face outward
    FLeaves[Index].Scale := 0.2 + (Sqrt(Index) / Sqrt(FLeafCount)) * 1.2; // Size increases toward the outer edge

    { Color interpolation: Center (Light Green) to Outer (Darker Teal) }
    _Norm := Index / FLeafCount;
    FLeaves[Index].Color := InterpolateAlphaColor($FFD4E157, $FF00796B, _Norm);
  end);
end;

procedure TPlantEngine.DrawSignature(ACanvas: TCanvas; const ASceneRect: TRectF);
begin
{
  ACanvas.Fill.Color := $AFFFFFFF;
  ACanvas.Font.Size := 14;
  ACanvas.FillText(RectF(ASceneRect.Left + 20, ASceneRect.Bottom - 40, ASceneRect.Right, ASceneRect.Bottom),
    FLogoText, False, 1.0, [], TTextAlign.Leading);
}
  with ACanvas do
  begin
    Font.Size := 14;
    Font.Family := 'Segoe UI';
    Font.Style := [TFontStyle.fsBold];
    Fill.Color := claBlack;
    var _shadowrect := ASceneRect;
    _shadowrect.Offset(100,60);
    FillText(_shadowrect, FLogoText, False, 0.8, [], TTextAlign.Leading, TTextAlign.Leading);
  end;
end;

procedure TPlantEngine.Render(ACanvas: TCanvas; ASceneRect: TRectF);
begin
  { Update data before rendering }
  Generate(ASceneRect, ASceneRect.CenterPoint);

  var _Path := TPathData.Create;
  try
    { Define leaf shape using Bezier curves (succulent style) }
    with _Path do
    begin
      MoveTo(PointF(0, 0));
      CurveTo(PointF(-14, -12), PointF(-16, -38), PointF(0, -60));
      CurveTo(PointF(16, -38), PointF(14, -12), PointF(0, 0));
      ClosePath;
    end;

    var _OriginalMatrix := ACanvas.Matrix;

    { Render from outer to inner to simulate depth layering }
    for var _i := FLeafCount - 1 downto 0 do
    begin
      { Calculate transformation matrix for the current leaf }
      var _Matrix := TMatrix.Identity;
      _Matrix:= TMatrix.CreateScaling(FLeaves[_i].Scale, FLeaves[_i].Scale) *
                TMatrix.CreateRotation(DegToRad(FLeaves[_i].Angle)) *
                TMatrix.CreateTranslation(FLeaves[_i].Position.X, FLeaves[_i].Position.Y);

      with ACanvas do
      begin
        SetMatrix(_Matrix * _OriginalMatrix);
        { Apply leaf fill color }
        Fill.Kind := TBrushKind.Solid;
        Fill.Color := FLeaves[_i].Color;
        { Apply subtle leaf stroke }
        Stroke.Kind := TBrushKind.Solid;
        Stroke.Color := $30000000;
        Stroke.Thickness := 0.5;
        { Draw the path }
        FillPath(_Path, 1.0);
        DrawPath(_Path, 1.0);
      end;
    end;

    { Restore original matrix to draw UI/Signature }
    ACanvas.SetMatrix(_OriginalMatrix);
    DrawSignature(ACanvas, ASceneRect);
  finally
    _Path.Free;
  end;
end;

end.
