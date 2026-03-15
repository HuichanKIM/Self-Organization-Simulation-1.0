unit uResources;

interface

uses
  System.SysUtils,
  System.Types,
  System.UITypes,
  System.Classes,
  System.Variants,
  FMX.Types,
  FMX.Controls,
  FMX.Forms,
  FMX.Graphics,
  FMX.Dialogs,
  FMX.Objects, FMX.Controls.Presentation, FMX.StdCtrls;

type
  TForm_Resources = class(TForm)
    Image_StreedLamp: TImage;
    Path1: TPath;
    Image_InnerLamp: TImage;
    Image_seoul: TImage;
    Image_WindowFrame: TImage;
    Image_AniNormal: TImage;
    Image_AniSurprise: TImage;
    Image_AniFront: TImage;
    Label1: TLabel;
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  Form_Resources: TForm_Resources;

implementation

{$R *.fmx}

end.
