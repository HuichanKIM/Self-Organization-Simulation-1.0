unit uBoidsSim_Base;

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
  TBoids = class
  private
    FMax_Force: Single;
    FMax_Speed: Single;
  public
    Position: TVector;
    Velocity: TVector;
    Acceleration: TVector;
    Size: Single;
    AnimOffset: Single;
    constructor Create(const CanvasWidth, CanvasHeight: Single);
    property Max_Force: Single read FMax_Force  write FMax_Force;
    property Max_Speed: Single read FMax_Speed  write FMax_Speed;
  end;

  TBoidsEngine = class
  private
    FBoids: TObjectList<TBoids>;
    FWidth, FHeight: Single;
    FBuffer: TBitmap;
    procedure SetParticleCount(const Value: Integer);
  public
    FParticleCount: Integer;
    FSeparationWeight: Single;
    FAlignmentWeight: Single;
    FCohesionWeight: Single;
    FMouseWeight: Single;
    FPerceptionRadius: Single;
    FMaxSpeed: Single;
    FMaxForce: Single;
    //
    FLockFlag: Boolean;
    FMousePos: TPointF;
    FIsMouseDown: Boolean;
    constructor Create(const AWidth, AHeight: Single; const ACount: Integer);
    destructor Destroy; override;
    //
    procedure Run(MainCanvas: TCanvas; const CW, CH: SIngle; const Trails: Boolean; const AMousePressed1, AMousePressed2: Boolean; const AMousePos: TPointF);
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

{ TMouse }

constructor TBoids.Create(const CanvasWidth, CanvasHeight: Single);
begin
  inherited Create;
end;

{ TBoidssEngine }

constructor TBoidsEngine.Create(const AWidth, AHeight: Single; const ACount: Integer);
begin
  inherited Create;
end;

destructor TBoidsEngine.Destroy;
begin
  FBoids.Free;
  inherited;
end;

procedure TBoidsEngine.Run(MainCanvas: TCanvas; const CW, CH: SIngle; const Trails, AMousePressed1, AMousePressed2: Boolean; const AMousePos: TPointF);
begin
  //
end;

procedure TBoidsEngine.SetParticleCount(const Value: Integer);
begin
  FParticleCount := Value;
end;

end.
