unit uVicsekSim_Base;

interface

uses
  System.SysUtils,
  System.Types,
  System.UITypes,
  System.Classes,
  System.Variants,
  System.Math,
  System.Math.Vectors,
  FMX.Types,
  FMX.Controls,
  FMX.Forms,
  FMX.Graphics,
  FMX.Dialogs,
  System.Generics.Collections;

type
  TVicsek = class
  private
  public
    Position: TPointF;
    Velocity: TPointF;
    Color: TAlphaColor;
    Size: TSizeF;
    constructor Create(const CanvasWidth, CanvasHeight: Single);
  end;

  TVicsekEngine = class
  private
    FVicsek: TObjectList<TVicsek>;
    FWidth, FHeight: Single;
    FBuffer: TBitmap;
    FParticleCount: Integer;

    FRadius: Double;
    FVelocity: Double;
    FNoise: Double;
    procedure SetParticleCount(const Value: Integer);
  public
    constructor Create(const AWidth, AHeight: Single; const ACount: Integer);
    destructor Destroy; override;

    procedure Run(MainCanvas: TCanvas; const CW, CH: SIngle; const Trails: Boolean; const AMousePressed1, AMousePressed2: Boolean; const AMousePos: TPointF);

    property ParticleCount: Integer read FParticleCount  write SetParticleCount;
    property Radius: Double    read FRadius     write FRadius;
    property Velocity: Double  read FVelocity   write FVelocity;
    property Noise: Double     read FNoise      write FNoise;
  end;

implementation

uses
  uCommons;

{ TVicsek }

constructor TVicsek.Create(const CanvasWidth, CanvasHeight: Single);
begin
  inherited Create;
end;

{ TVicsekEngine }

constructor TVicsekEngine.Create(const AWidth, AHeight: Single; const ACount: Integer);
begin
  inherited Create;
  FWidth := AWidth;
  FHeight := AHeight;
  FParticleCount := ACount;
end;

destructor TVicsekEngine.Destroy;
begin
  FVicsek.Free;
  if Assigned(FBuffer) then FBuffer.Free;
  inherited;
end;

procedure TVicsekEngine.Run(MainCanvas: TCanvas; const CW, CH: SIngle; const Trails, AMousePressed1, AMousePressed2: Boolean; const AMousePos: TPointF);
begin
  //
end;

procedure TVicsekEngine.SetParticleCount(const Value: Integer);
begin
  FParticleCount := Value;
end;


end.
