unit uCyclicPalette;

interface

uses
  System.SysUtils,
  System.Types,
  System.UITypes,
  System.Classes,
  FMX.Graphics,
  System.UIConsts,
  System.Math;

type
  { Engine class responsible for generating cyclic gradients. }
  TCyclicGradientEngine = class
  private
    { Class function to linearly interpolate between two TAlphaColor values.
      Factor is a value from 0.0 to 1.0 representing the interpolation point. }
    class function InterpolateColor(AColor1, AColor2: TAlphaColor; AFactor: Single): TAlphaColor;
  public
    { Class procedure to generate a cyclic gradient bitmap based on specified parameters }
    class function GenerateAndBitmap(const AWidth, AHeight, ARepeats: Integer; const ASaveFlag: Boolean = False): TBitmap; static;
  end;

implementation

{ TCyclicGradientEngine }

// Calculate interpolated color between Color1 and Color2
class function TCyclicGradientEngine.InterpolateColor(AColor1, AColor2: TAlphaColor; AFactor: Single): TAlphaColor;
var
  _ColorRec: TAlphaColorRec; // Declaring a TAlphaColorRec variable explicitly
begin
  // Extract individual color channels (Alpha, Red, Green, Blue) from TAlphaColor
  var _A1: Byte := TAlphaColorRec(AColor1).A;
  var _R1: Byte := TAlphaColorRec(AColor1).R;
  var _G1: Byte := TAlphaColorRec(AColor1).G;
  var _B1: Byte := TAlphaColorRec(AColor1).B;

  var _A2: Byte := TAlphaColorRec(AColor2).A;
  var _R2: Byte := TAlphaColorRec(AColor2).R;
  var _G2: Byte := TAlphaColorRec(AColor2).G;
  var _B2: Byte := TAlphaColorRec(AColor2).B;

  // Calculate linear interpolation for each channel
  var _A: Byte := Round(_A1 + AFactor * (_A2 - _A1));
  var _R: Byte := Round(_R1 + AFactor * (_R2 - _R1));
  var _G: Byte := Round(_G1 + AFactor * (_G2 - _G1));
  var _B: Byte := Round(_B1 + AFactor * (_B2 - _B1));

  // Instead of using TAlphaColorRec.Create(R, G, B, A),
  // assign values directly to the fields of a TAlphaColorRec variable.

  _ColorRec.A := _A;
  _ColorRec.R := _R;
  _ColorRec.G := _G;
  _ColorRec.B := _B;

  // Typecast the populated TAlphaColorRec back to TAlphaColor for the result.
  Result := TAlphaColor(_ColorRec);
end;

// Main engine function to create the gradient and save it to file
class function TCyclicGradientEngine.GenerateAndBitmap(const AWidth, AHeight, ARepeats: Integer; const ASaveFlag: Boolean = False): TBitmap;
const
  // Define the sequence of colors for the gradient palette using TAlphaColor constants.
  //Palette: array [0 .. 6] of TAlphaColor = (claBlack, claWhite, claYellow, claGray, claGreen, claOrange, claBlue);
  Palette: array [0 .. 8] of TAlphaColor = (claBlack, claWhite, claYellow, claGray, claLime, claCyan, claGreen, claOrange, claBlue);
begin
  if (AWidth <= 0) or (AHeight <= 0) or (ARepeats <= 0) then
    raise Exception.Create('Invalid parameters for gradient generation.');

  var _BitmapData: TBitmapData;
  var _X := 0;
  var _Y := 0;
  var _Position: Single := 0;
  var _ColorIndex := 0;
  var _Factor: Single := 0;
  var _CurrentColor: TAlphaColor := claBlack;

  // Create a new TBitmap with specified dimensions
  var _Bitmap := TBitmap.Create(AWidth, AHeight);
  try
    var _PaletteCount := Length(Palette);

    // Attempt to map the _Bitmap's memory for direct pixel access with Write permission.
    // This provides significantly faster pixel manipulation than using Canvas.DrawPixel.
    if _Bitmap.Map(TMapAccess.Write, _BitmapData) then
      begin
        try
          // Loop horizontally across the entire width of the _Bitmap
          for _X := 0 to AWidth - 1 do
            begin
              // Calculate the gradient progression based on current _X _Position,
              // scaled to range from 0.0 to ARepeats.
              _Position := (_X / AWidth) * ARepeats;

              // Determine the starting color index within the palette array and the interpolation _Factor.
              // Trunc(_Position) gives the integer part (current cycle/color step),
              // mod (_PaletteCount - 1) ensures the index wraps correctly around the palette array.
              // Frac(_Position) extracts the fractional part, representing the interpolation ratio between two colors.
              _ColorIndex := Trunc(_Position) mod (_PaletteCount - 1);
              _Factor := Frac(_Position);

              // Calculate the final color for the current column by interpolating between the two palette colors.
              _CurrentColor := InterpolateColor(Palette[_ColorIndex], Palette[_ColorIndex + 1], _Factor);

              // Loop vertically across the height of the _Bitmap at the current _X column.
              // This creates vertical stripes of uniform color based on the horizontal gradient calculation.
              for _Y := 0 to AHeight - 1 do
                begin
                  // Directly set the pixel value at (_X, _Y) within the mapped _BitmapData.
                  _BitmapData.SetPixel(_X, _Y, _CurrentColor);
                end;
            end;
        finally
          // Unmap the _Bitmap data to commit changes and release memory access.
          _Bitmap.Unmap(_BitmapData);
        end;
      end;

    // Save the completed _Bitmap to the specified file name.
    // The format (PNG, JPEG, etc.) is automatically determined by the file extension.
    if ASaveFlag then
    _Bitmap.SaveToFile('cyclicpalette.png');

    Result := _Bitmap;
  finally
  end;
end;

end.
