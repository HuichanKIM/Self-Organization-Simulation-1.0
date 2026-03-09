unit Unit_Main;

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
  FMX.Objects,
  FMX.StdCtrls,
  FMX.Layouts,
  FMX.ListBox,
  FMX.Controls.Presentation,
  FMX.Ani,
  System.UIConsts,
  System.Actions,
  FMX.ActnList,
  //
  uVicsekSim0,
  uBoidsSim0,
  uBoidsSim1,
  uBoidsSim2,
  uBoidsSim3,
  uFractalGenerator,
  uPhyllotaxisPlant,
  uAquarumSim;

type
  TModeSelection = (ms_None= -1, ms_Vicsek0 = 0, ms_Boidss0, ms_Boidss1, ms_Boidss2, ms_Boidss3, ms_Fractal, ms_Aquarium);

  TMainForm = class(TForm)
    Timer_Engine: TTimer;
    PaintBox_Sim: TPaintBox;
    Label_Particles1: TLabel;
    Label_Velocity: TLabel;
    Label_Radius: TLabel;
    Label_Noise: TLabel;
    Label_Particles2: TLabel;
    Label_MaxSpeed: TLabel;
    Label_MaxForce: TLabel;
    Label_Perception: TLabel;
    Label_Cohesion: TLabel;
    Label_Alignment: TLabel;
    Label_Separation: TLabel;
    Label_Tails: TLabel;
    TrackBar_Radius: TTrackBar;
    TrackBar_Velocity: TTrackBar;
    TrackBar_Noise: TTrackBar;
    TrackBar_Particles1: TTrackBar;
    TrackBar_Tails: TTrackBar;
    TrackBar_Cohesion: TTrackBar;
    TrackBar_Perception: TTrackBar;
    TrackBar_Alignment: TTrackBar;
    TrackBar_Separation: TTrackBar;
    TrackBar_Particles2: TTrackBar;
    TrackBar_MaxForce: TTrackBar;
    TrackBar_MaxSpeed: TTrackBar;
    CheckBox_VicsekTrails: TCheckBox;
    StyleBook1: TStyleBook;
    Layout_Params: TLayout;
    Label2: TLabel;
    Label3: TLabel;
    ComboBox_Model: TComboBox;
    ActionList1: TActionList;
    Action_Start: TAction;
    Action_Reset: TAction;
    Action_Snapshot: TAction;
    CornerButton_Start: TCornerButton;
    CornerButton_Reset: TCornerButton;
    Text_StepCount: TText;
    CheckBox_Dynamic: TCheckBox;
    Text_HelpHint: TText;
    Image_LogoButton: TImage;
    Image_Bulgasari: TImage;
    CheckBox_BoidsTrails: TCheckBox;
    Layout_Vicsek: TLayout;
    Layout_Boids: TLayout;
    Line_Params: TLine;
    Image_Template: TImage;
    Circle_Logo: TCircle;
    Label_Alarm: TLabel;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure Timer_EngineTimer(Sender: TObject);
    procedure PaintBox_SimPaint(Sender: TObject; Canvas: TCanvas);
    procedure ComboBox_ModelChange(Sender: TObject);
    procedure PaintBox_SimResize(Sender: TObject);
    procedure PaintBox_SimMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Single);
    procedure PaintBox_SimMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Single);
    procedure PaintBox_SimMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Single);
    procedure PaintBox_SimMouseWheel(Sender: TObject; Shift: TShiftState;  WheelDelta: Integer; var Handled: Boolean);
    procedure Action_StartExecute(Sender: TObject);
    procedure Action_ResetExecute(Sender: TObject);
    procedure ActionList1Update(Action: TBasicAction; var Handled: Boolean);
    procedure FormShow(Sender: TObject);
    procedure Image_LogoButtonClick(Sender: TObject);
    procedure CheckBox_DynamicChange(Sender: TObject);
    procedure TrackBar_NoiseTracking(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word; var KeyChar: WideChar; Shift: TShiftState);
    procedure Action_SnapshotExecute(Sender: TObject);
  private
    FModeSelection: TModeSelection;
    FVicsekEngine1: TVicsekEngine0;
    FBoidssEngine0: TBoidssEngine0;
    FBoidssEngine1: TBoidssEngine1;
    FBoidssEngine2: TBoidssEngine2;
    FBoidssEngine3: TBoidssEngine3;
    FFractalEngine: TFractalEngine;
    FAquariumEngine: TAquariumEngine;
    //
    FLockControlFlag: Boolean;
    FLockPaintingFlag: Boolean;
    FStepcounts: Integer;
    FFramePerSeconed: Integer;
    FIsMousePressed1: Boolean;
    FIsMousePressed2: Boolean;
    FMousePos: TPointF;
    FLogoFlag: Boolean;
    FStarfishFlag: Boolean;
    //
    FStartMousePos: TPointF;
    procedure DrawCustomLogo;
    procedure UpdateParametersAndLabels(const ALabelFlag: Boolean = True);
    procedure SetModeSelection(const Value: TModeSelection);
    procedure SetStartStopLabel(const AFlag: Boolean);
    procedure Set_StepCounts;
    procedure SetStepcounts(const Value: Integer);
    procedure InitModeSelection(const Value: TModeSelection);
    function GetParticleCounts(const AModel: TModeSelection): Integer;
    function LoadLogo(): Boolean ;
    procedure Logo_FadeOutAndShrink(AControl: TControl; const ARestoreFlag: Boolean);
    function LoadBulgasari(): Boolean ;
    // extra ...
    procedure AnimateVisibility(const AControl: TControl; const AMsg: string; const AShow: Boolean);
    procedure AnimationFinishedEvent(Sender: TObject);
    procedure SaveScreenshot(const ADialogFlag: Boolean = True);
  public
    property ModeSelection: TModeSelection  read FModeSelection  write SetModeSelection;
    property Stepcounts: Integer  read FStepcounts  write SetStepcounts;
  end;

var
  MainForm: TMainForm;

implementation

uses
  uCommons,
  System.Threading,
  System.Math,
  System.IOUtils,
  System.Math.Vectors;

{$R *.fmx}

const
  C_CaptionPrefix = 'Self-Organization Simulation 2026';
  C_TmInterval: array [ TModeSelection ] of Cardinal = (33, 33, 20, 16, 33, 16, 33, 16);
  C_StepOf_FPS: array [ TModeSelection ] of Cardinal = (30, 30, 50, 60, 30, 60, 30, 60);
  C_Selections: array [ TModeSelection ] of string = ('',
                                                      'Vicsek Model Simulation',
                                                      'Boids Model-0 Simulation',
                                                      'Boids Model-1 Simulation',
                                                      'Boids Model-2 Simulation',
                                                      'Boids Model-3',
                                                      'FractalEngine',
                                                      'AQuarium');
  C_ModelHelps: array [ TModeSelection ] of string = ('',
                                                      'Mouse Move - Avoidance  Left MouseButton Down - Attraction',
                                                      'Mouse Move - Avoidance  Left MouseButton Down - Attraction',
                                                      'Left MouseButton Down, Move : Attraction,  Right MouseButton Down - Diffusion',
                                                      'Mouse Move : Vector Reffernce / Attraction,  Left MouseButton Down - Avoidance',
                                                      'Left MouseButton Down: Attraction,  Right MouseButton Down - Diffusion',
                                                      'Mouse Wheel: Zoom  LeftMButton Down/Drag: Move  RightMButton: Toggle(Fractal, Julia)',
                                                      'Left MouseButton Down: Avoidance');

const
  C_Aquarium_FIshs = 150;  // Fix ...

{ TMainForm ------------------------------------------------------------------ }

procedure TMainForm.FormCreate(Sender: TObject);
begin
  Randomize;
  Self.Caption := C_CaptionPrefix;

  FLockControlFlag :=           True;
  FLockPaintingFlag :=          True;

  Label_Alarm.Visible :=        False;
  TrackBar_Particles1.Value :=  500;
  TrackBar_Noise.Value :=       Round(0.1 * 100);
  TrackBar_Radius.Value :=      Round(30.0);
  TrackBar_Velocity.Value :=    Round(4.2 * 10);
  TrackBar_Tails.Value :=       Round(0.15 * 100);

  TrackBar_MaxSpeed.Value :=    42.0;
  TrackBar_Particles2.Value :=  500;
  TrackBar_Separation.Value :=  15;
  TrackBar_Alignment.Value :=   10;
  TrackBar_Cohesion.Value :=    10;
  TrackBar_Perception.Value :=  50;

  FIsMousePressed1 :=           False;
  FIsMousePressed2 :=           False;
  FMousePos :=                  PointF(-1000, -1000);

  ComboBox_Model.CanFocus :=    False;
  Image_Bulgasari.Visible :=    False;

  Timer_Engine.Interval :=      33;
  Timer_Engine.Enabled :=       False;
  PaintBox_Sim.OnPaint :=       nil;

  ComboBox_Model.ItemIndex :=   -1;
  FModeSelection :=             ms_None;
  UpdateParametersAndLabels;
  Layout_Vicsek.Visible :=      False;
  Layout_Boids.Visible :=       False;
  Layout_Params.Height :=       1;

  FStepcounts :=                0;
  FFramePerSeconed :=           30;
  Set_Stepcounts;

  FLogoFlag := LoadLogo();
  FStarfishFlag := LoadBulgasari();
end;

function TMainForm.LoadLogo(): Boolean ;
begin
  Result := False;
  Image_Template.Visible := False;
  var _logofile := ExtractFilePath(ParamStr(0));
  _logofile := TPath.Combine(IncludeTrailingPathDelimiter(_logofile), 'logo.png');

  if FileExists(_logofile) then
  begin
    Image_LogoButton.Bitmap.LoadFromFile(_logofile);
    Result := not (Image_LogoButton.Bitmap.IsEmpty);
  end;
  DrawCustomLogo;
end;

function TMainForm.LoadBulgasari(): Boolean ;
begin
  Result := False;
  var _bugasarifile := ExtractFilePath(ParamStr(0));
  _bugasarifile := TPath.Combine(IncludeTrailingPathDelimiter(_bugasarifile), 'bugasari.png');
  if FileExists(_bugasarifile) then
  begin
    Image_Bulgasari.Bitmap.LoadFromFile(_bugasarifile);
    Result := not (Image_Bulgasari.Bitmap.IsEmpty);
  end;
end;

procedure TMainForm.FormDestroy(Sender: TObject);
begin
  if Assigned(FVicsekEngine1) then FreeAndNil(FVicsekEngine1);
  if Assigned(FBoidssEngine0) then FreeAndNil(FBoidssEngine0);
  if Assigned(FBoidssEngine1) then FreeAndNil(FBoidssEngine1);
  if Assigned(FBoidssEngine2) then FreeAndNil(FBoidssEngine2);
  if Assigned(FBoidssEngine3) then FreeAndNil(FBoidssEngine3);
  if Assigned(FFractalEngine) then FreeAndNil(FFractalEngine);
  if Assigned(FAquariumEngine) then FreeAndNil(FAquariumEngine);
end;

procedure TMainForm.FormKeyDown(Sender: TObject; var Key: Word; var KeyChar: WideChar; Shift: TShiftState);
const
  _MoveStep = 20.0; // Arrow key movement sensitivity (pixels)
begin
  if Assigned(FFractalEngine) then
  begin
    var _DeltaXY: TPointF := PointF(0, 0);

    if ssCtrl in Shift then
      case Key of
        vkUp:    begin FFractalEngine.ZoomAt(PaintBox_Sim.Width/2, PaintBox_Sim.Height/2, 1); end;
        vkDown:  begin FFractalEngine.ZoomAt(PaintBox_Sim.Width/2, PaintBox_Sim.Height/2, 0); end;
      end
    else
      case Key of
        vkLeft:  begin _DeltaXY := PointF(-_MoveStep, 0); FFractalEngine.MoveByOffset(_DeltaXY); end;
        vkUp:    begin _DeltaXY := PointF(0, -_MoveStep); FFractalEngine.MoveByOffset(_DeltaXY); end;
        vkRight: begin _DeltaXY := PointF(_MoveStep, 0);  FFractalEngine.MoveByOffset(_DeltaXY); end;
        vkDown:  begin _DeltaXY := PointF(0,  _MoveStep); FFractalEngine.MoveByOffset(_DeltaXY); end;
      end;
  end;

  if (UpperCase(KeyChar) = 'S') then
  begin
    SaveScreenshot(False);
    Key := 0;
  end;
end;

procedure TMainForm.SaveScreenshot(const ADialogFlag: Boolean = True);
begin
  var _Snapenflag: Boolean := False;
  var _SaveFile := '';
  if ADialogFlag then
    begin
      var _SaveDialog := TSaveDialog.Create(nil);
      try
        _SaveDialog.Filter := 'PNG Image|*.png';
        _SaveDialog.DefaultExt := 'png';
        _SaveDialog.FileName := Format('Snapshot_%s.png', [FormatDateTime('yyyyMMdd_hhmmss', Now)]);
        _Snapenflag := _SaveDialog.Execute;
        _SaveFile := _SaveDialog.FileName;
      finally
        _SaveDialog.Free;
      end;
    end
  else
    begin
      var _SaveParth := ExtractFilePath(ParamStr(0));
      _SaveFile := Format('Snapshot_%s.png', [FormatDateTime('yyyyMMdd_hhmmss', Now)]);
      _SaveFile := TPath.Combine(IncludeTrailingPathDelimiter(_SaveParth), _SaveFile);
      _Snapenflag := True;
    end;

  if _Snapenflag and (_SaveFile > ' ') then
    begin
      TTask.Run(
      procedure
      begin
        var _ScreenShot := PaintBox_Sim.MakeScreenshot;
        try
          _ScreenShot.SaveToFile(_SaveFile);
          if not FileExists(_SaveFile) then
            ShowMessage('Failed to save snapshot ')
          else
            AnimateVisibility(Label_Alarm, 'Saved a Snapshot', True);
        finally
          _ScreenShot.Free;
        end;
      end);
    end;
end;

procedure TMainForm.FormShow(Sender: TObject);
begin
  if Self.Tag = 0 then begin Self.Tag := 1; Global_TrimAppMemorySizeEx(0); end;   // Effect / USeful ?
  InitModeSelection(FModeSelection);
end;

procedure TMainForm.InitModeSelection(const Value: TModeSelection);
begin
  Self.Caption := C_CaptionPrefix + ' - '+ C_Selections[Value];;
  Text_HelpHint.Text :=  'Ref. : ' + C_ModelHelps[Value];
end;

procedure TMainForm.TrackBar_NoiseTracking(Sender: TObject);
begin
  if not FLockControlFlag then
    UpdateParametersAndLabels;
end;

procedure TMainForm.UpdateParametersAndLabels(const ALabelFlag: Boolean = True);
begin
  FLockControlFlag := True;

  if ALabelFlag then
  begin
    // ms_Vicsek = FVicsekEngine1, FBoidssEngine0
    Label_Particles1.Text :=    Format('Particles %d',  [Round(TrackBar_Particles1.Value)]);
    Label_Noise.Text :=         Format('Noise %.2f',    [TrackBar_Noise.Value / 100.0]);
    Label_Radius.Text :=        Format('Radius %.0f',   [TrackBar_Radius.Value]);
    Label_Velocity.Text :=      Format('Velocity %.1f', [TrackBar_Velocity.Value / 10.0]);
    Label_Tails.Text :=         Format('Tails %.2f',    [TrackBar_Tails.Value / 100]);
    // ms_Boids1 = FBoidssEngine1
    Label_Particles2.Text :=    Format('Particles %d',  [Round(TrackBar_Particles2.Value)]);
    Label_Separation.Text :=    Format('Sep %.1f',      [TrackBar_Separation.Value / 10]);
    Label_Alignment.Text :=     Format('Align %.1f',    [TrackBar_Alignment.Value / 10]);
    Label_Cohesion.Text :=      Format('Coh %.1f',      [TrackBar_Cohesion.Value / 10]);
    Label_Perception.Text :=    Format('Prcpt %d',      [Round(TrackBar_Perception.Value)]);
    // ms_Boids2 = FBoidssEngine2
    Label_MaxSpeed.Text :=      Format('Speed %.1f',    [TrackBar_MaxSpeed.Value / 10]);
    Label_MaxForce.Text :=      Format('Force %.1f',    [TrackBar_MaxForce.Value / 100]);
  end;

  case FModeSelection of
    ms_Vicsek0:
        if Assigned(FVicsekEngine1) then
          with FVicsekEngine1 do
            begin
              Noise :=            TrackBar_Noise.Value / 100.0;
              Radius :=           TrackBar_Radius.Value;
              Velocity :=         TrackBar_Velocity.Value / 10.0;
              TailOp :=           TrackBar_Tails.Value / 100;

              ParticleCount :=    Round(TrackBar_Particles1.Value);
            end;
    ms_Boidss0:
        if Assigned(FBoidssEngine0) then
          with FBoidssEngine0 do
            begin
              SeparationWeight := TrackBar_Separation.Value / 10;
              AlignmentWeight :=  TrackBar_Alignment.Value / 100;
              CohesionWeight :=   TrackBar_Cohesion.Value / 100;
              NeighborRadius :=   Max(30, TrackBar_Radius.Value);
              MaxSpeed :=         TrackBar_MaxSpeed.Value / 10;

              FishCount :=        Round(TrackBar_Particles1.Value);
            end;
    ms_Boidss1:
        if Assigned(FBoidssEngine1) then
          with FBoidssEngine1 do
            begin
              SeparationWeight := TrackBar_Separation.Value / 10;
              AlignmentWeight :=  TrackBar_Alignment.Value / 10;
              CohesionWeight :=   TrackBar_Cohesion.Value / 10;
              PerceptionRadius := TrackBar_Perception.Value;

              ParticleCount :=    Round(TrackBar_Particles2.Value);
            end;
    ms_Boidss2:
        if Assigned(FBoidssEngine2) then
          with FBoidssEngine2 do
            begin
              SeparationWeight := TrackBar_Separation.Value / 10;
              AlignmentWeight :=  TrackBar_Alignment.Value / 10;
              CohesionWeight :=   TrackBar_Cohesion.Value / 10;
              PerceptionRadius := TrackBar_Perception.Value;
              MaxSpeed :=         TrackBar_MaxSpeed.Value / 10;
              MaxForce :=         TrackBar_MaxForce.Value / 100;

              ParticleCount :=    Round(TrackBar_Particles2.Value);
            end;
    ms_Boidss3:
        if Assigned(FBoidssEngine3) then
          with FBoidssEngine3 do
            begin
              SeparationWeight := TrackBar_Separation.Value / 10;
              AlignWeight :=      TrackBar_Alignment.Value / 10;
              CohesionWeight :=   TrackBar_Cohesion.Value / 10;
              MaxSpeed :=         TrackBar_MaxSpeed.Value / 10;
              MaxForce :=         TrackBar_MaxForce.Value / 100;

              ParticleCount :=    Round(TrackBar_Particles2.Value);
            end;
     ms_Fractal:
            begin
              //
            end;
     ms_Aquarium:
            begin
              //
            end;
  end;
  FLockControlFlag := False;
end;

procedure TMainForm.PaintBox_SimMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Single);
begin
  FMousePos := PointF(X, Y);
  Image_Bulgasari.Visible := False;
  FIsMousePressed1 := Button = TMouseButton.mbLeft;
  FIsMousePressed2 := Button = TMouseButton.mbRight;
  if CheckBox_Dynamic.IsChecked then
  begin
    if FIsMousePressed1 then
      begin
        FStartMousePos := PointF(X, Y);
        if Assigned(FVicsekEngine1) then FVicsekEngine1.SetMouseInfo(FMousePos, True) else
        if Assigned(FBoidssEngine0) then FBoidssEngine0.SetMouseInfo(FMousePos, True) else
        if Assigned(FBoidssEngine1) then FBoidssEngine1.SetMouseInfo(FMousePos, True) else
        if Assigned(FBoidssEngine2) then FBoidssEngine2.SetMouseInfo(FMousePos, True) else
        if Assigned(FBoidssEngine3) then FBoidssEngine3.SetMouseInfo(FMousePos, True) else
        if Assigned(FAquariumEngine) then FAquariumEngine.SetMouseInfo(FMousePos, True);
      end else
    if FIsMousePressed2 then
      if Assigned(FFractalEngine) then FFractalEngine.SetMouseInfo(FMousePos, FIsMousePressed1, FIsMousePressed2);
  end;
end;

procedure TMainForm.PaintBox_SimMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Single);
begin
  if FIsMousePressed1 then
    begin
      FMousePos := PointF(X, Y);
      PaintBox_Sim.SetDragCursor(True, FModeSelection = ms_Fractal);
    end;

  if CheckBox_Dynamic.IsChecked then
  begin
    if Assigned(FVicsekEngine1) then FVicsekEngine1.SetMouseInfo(PointF(X, Y), FIsMousePressed1) else
    if Assigned(FBoidssEngine0) then
      begin
        FBoidssEngine0.SetMouseInfo(PointF(X, Y), FIsMousePressed1);
        if FIsMousePressed1 or FIsMousePressed2 then
          Image_Bulgasari.Visible := False
        else
          if FStarfishFlag then
            begin
              Image_Bulgasari.Visible := (FModeSelection = ms_Boidss0) and (Timer_Engine.Enabled) and (CheckBox_Dynamic.IsChecked);
              if Image_Bulgasari.Visible then
              begin
                var _AbsolutePoint: TPointF := Paintbox_Sim.LocalToAbsolute(PointF(X-25, Y-25));
                Image_Bulgasari.Position.X := _AbsolutePoint.X;
                Image_Bulgasari.Position.Y := _AbsolutePoint.Y;
              end;
            end;
      end else
    if Assigned(FBoidssEngine1) then FBoidssEngine1.SetMouseInfo(PointF(X, Y), FIsMousePressed1) else
    if Assigned(FBoidssEngine2) then FBoidssEngine2.SetMouseInfo(PointF(X, Y), FIsMousePressed1) else
    if Assigned(FBoidssEngine3) then FBoidssEngine3.SetMouseInfo(PointF(X, Y), FIsMousePressed1) else
    if Assigned(FAquariumEngine) then FAquariumEngine.SetMouseInfo(PointF(X, Y), FIsMousePressed1);
  end;
end;

procedure TMainForm.PaintBox_SimMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Single);
begin
  FIsMousePressed1 := False;
  FIsMousePressed2 := False;
  PaintBox_Sim.SetDragCursor(False);
  if CheckBox_Dynamic.IsChecked then
  begin
    if Assigned(FVicsekEngine1) then FVicsekEngine1.SetMouseInfo(PointF(X, Y), False) else
    if Assigned(FBoidssEngine0) then FBoidssEngine0.SetMouseInfo(PointF(X, Y), False) else
    if Assigned(FBoidssEngine1) then FBoidssEngine1.SetMouseInfo(PointF(X, Y), False) else
    if Assigned(FBoidssEngine2) then FBoidssEngine2.SetMouseInfo(PointF(X, Y), False) else
    if Assigned(FBoidssEngine3) then FBoidssEngine3.SetMouseInfo(PointF(X, Y), False) else
    if (Button = TMouseButton.mbLeft) and Assigned(FFractalEngine) then
      begin
        var _DeltaXY: TPointF := PointF(X - FStartMousePos.X, Y - FStartMousePos.Y);
        FFractalEngine.MoveByOffset(_DeltaXY);
      end;
  end;
end;

procedure TMainForm.PaintBox_SimMouseWheel(Sender: TObject; Shift: TShiftState; WheelDelta: Integer; var Handled: Boolean);
begin
  if CheckBox_Dynamic.IsChecked and Assigned(FFractalEngine)  then
    begin
      var _LocalMousePos := PaintBox_Sim.AbsoluteToLocal(ScreenToClient(Screen.MousePos));
      FFractalEngine.SetMouseWheelInfo(_LocalMousePos, WheelDelta);
    end;
  Handled := True;
end;

procedure TMainForm.PaintBox_SimPaint(Sender: TObject; Canvas: TCanvas);
begin
  if FLockPaintingFlag then Exit;
  var _IsMousePressed1 :=  CheckBox_Dynamic.IsChecked and FIsMousePressed1;
  var _IsMousePressed2 :=  CheckBox_Dynamic.IsChecked and FIsMousePressed2;

  if Assigned(FVicsekEngine1) then
    begin
      FVicsekEngine1.Run(Canvas, PaintBox_Sim.Width, PaintBox_Sim.Height, CheckBox_VicsekTrails.IsChecked, _IsMousePressed1, FMousePos);
    end else
  if Assigned(FBoidssEngine0) then
    begin
      FBoidssEngine0.Run(Canvas, PaintBox_Sim.Width, PaintBox_Sim.Height, CheckBox_VicsekTrails.IsChecked, _IsMousePressed1, FMousePos);
    end else
  if Assigned(FBoidssEngine1) then
    begin
      { Run simulation and pass mouse state to the engine }
      FBoidssEngine1.Run(Canvas, _IsMousePressed1, _IsMousePressed2, FMousePos);

      { Draw visual feedback for mouse attraction }
      if _IsMousePressed1 then
      if Canvas.BeginScene() then
        try
          Canvas.Stroke.Color := TAlphaColorRec.White;
          Canvas.Stroke.Dash := TStrokeDash.Dot;
          Canvas.Stroke.Thickness := 3;
          Canvas.DrawEllipse(RectF(FMousePos.X - 30, FMousePos.Y - 30, FMousePos.X + 30, FMousePos.Y + 30), 0.8);
        finally
          Canvas.EndScene;
        end;
    end else
  if Assigned(FBoidssEngine2) then
    begin
      FBoidssEngine2.Run(Canvas, PaintBox_Sim.Width, PaintBox_Sim.Height, CheckBox_BoidsTrails.IsChecked, _IsMousePressed1, FMousePos);
    end else
  if Assigned(FBoidssEngine3) then
    begin
      FBoidssEngine3.Run(Canvas, PaintBox_Sim.Width, PaintBox_Sim.Height, CheckBox_BoidsTrails.IsChecked, _IsMousePressed1, _IsMousePressed2, FMousePos);
    end else
  if Assigned(FFractalEngine) then
    begin
      FFractalEngine.Run(Canvas, PaintBox_Sim.Width, PaintBox_Sim.Height, CheckBox_BoidsTrails.IsChecked, _IsMousePressed1, FMousePos);
    end else
  if Assigned(FAquariumEngine) then
    begin
      FAquariumEngine.Run(Canvas, PaintBox_Sim.Width, PaintBox_Sim.Height, CheckBox_BoidsTrails.IsChecked, _IsMousePressed1, _IsMousePressed2, FMousePos);
    end
  else
    Exit;

  Inc(FStepcounts);
end;

procedure TMainForm.PaintBox_SimResize(Sender: TObject);
begin
  if Assigned(FVicsekEngine1) then FVicsekEngine1.Resize(PaintBox_Sim.Width, PaintBox_Sim.Height) else
  if Assigned(FBoidssEngine0) then FBoidssEngine0.Resize(PaintBox_Sim.Width, PaintBox_Sim.Height) else
  if Assigned(FBoidssEngine1) then FBoidssEngine1.Resize(PaintBox_Sim.Width, PaintBox_Sim.Height) else
  if Assigned(FBoidssEngine2) then FBoidssEngine2.Resize(PaintBox_Sim.Width, PaintBox_Sim.Height) else
  if Assigned(FBoidssEngine3) then FBoidssEngine3.Resize(PaintBox_Sim.Width, PaintBox_Sim.Height) else
  if Assigned(FFractalEngine) then FFractalEngine.Resize(PaintBox_Sim.Width, PaintBox_Sim.Height) else
  if Assigned(FAquariumEngine) then FAquariumEngine.Resize(PaintBox_Sim.Width, PaintBox_Sim.Height);
end;

procedure TMainForm.CheckBox_DynamicChange(Sender: TObject);
begin
  Image_Bulgasari.Visible := FStarfishFlag and (FModeSelection = ms_Boidss0) and (Timer_Engine.Enabled) and (CheckBox_Dynamic.IsChecked);
end;

procedure TMainForm.ComboBox_ModelChange(Sender: TObject);
begin
  if ComboBox_Model.ItemIndex >= 0 then
  begin
    ModeSelection := TModeSelection(ComboBox_Model.ItemIndex);
    if PaintBox_Sim.CanFocus then
      PaintBox_Sim.SetFocus;
  end;
end;

procedure TMainForm.SetModeSelection(const Value: TModeSelection);
begin
  FModeSelection := Value;

  FLockPaintingFlag := True;
  Timer_Engine.Enabled := False;

  if Assigned(FVicsekEngine1)  then FreeAndNil(FVicsekEngine1);
  if Assigned(FBoidssEngine0)  then FreeAndNil(FBoidssEngine0);
  if Assigned(FBoidssEngine1)  then FreeAndNil(FBoidssEngine1);
  if Assigned(FBoidssEngine2)  then FreeAndNil(FBoidssEngine2);
  if Assigned(FBoidssEngine3)  then FreeAndNil(FBoidssEngine3);
  if Assigned(FFractalEngine)  then FreeAndNil(FFractalEngine);
  if Assigned(FAquariumEngine) then FreeAndNil(FAquariumEngine);

  { Reset Params COntrol ... }
  Layout_Vicsek.Visible :=           (Value = ms_Vicsek0);
  Layout_Boids.Visible :=            (Value = ms_Boidss0) or (Value = ms_Boidss1) or (Value = ms_Boidss2) or (Value = ms_Boidss3);
  Layout_Params.Height :=            IfThen((Value = ms_Fractal) or (Value = ms_Aquarium), 1,  41);

  TrackBar_Noise.Enabled :=          (Value = ms_Vicsek0);
  TrackBar_Velocity.Enabled :=       (Value = ms_Vicsek0);
  CheckBox_VicsekTrails.Enabled :=   (Value = ms_Vicsek0);
  TrackBar_Tails.Enabled :=          (Value = ms_Vicsek0);

  TrackBar_Separation.Enabled :=     (Value = ms_Boidss0) or (Value = ms_Boidss1) or (Value = ms_Boidss2) or (Value = ms_Boidss3);
  TrackBar_Alignment.Enabled :=      (Value = ms_Boidss0) or (Value = ms_Boidss1) or (Value = ms_Boidss2) or (Value = ms_Boidss3);
  TrackBar_Cohesion.Enabled :=       (Value = ms_Boidss0) or (Value = ms_Boidss1) or (Value = ms_Boidss2) or (Value = ms_Boidss3);
  TrackBar_Perception.Enabled :=     (Value = ms_Boidss1) or (Value = ms_Boidss2) or (Value = ms_Boidss3);
  TrackBar_MaxForce.Enabled :=       (Value = ms_Boidss0) or (Value = ms_Boidss2) or (Value = ms_Boidss3);
  TrackBar_MaxSpeed.Enabled :=       (Value = ms_Boidss0) or (Value = ms_Boidss2) or (Value = ms_Boidss3);
  CheckBox_BoidsTrails.Enabled :=    (Value = ms_Boidss3);

  TrackBar_Particles1.OnTracking := nil;
  TrackBar_Particles1.OnTracking := nil;

  { Init Simulation Engine ... }
  FFramePerSeconed := 30;
  FIsMousePressed1 := False;
  FIsMousePressed2 := False;

  Timer_Engine.Interval := C_TmInterval[Value];
  FFramePerSeconed :=      C_StepOf_FPS[Value];
  Stepcounts := 0;

  var _RestoreParticles: Integer := 500;
  case Value of
    ms_Vicsek0:
      begin
        _RestoreParticles := Round(TrackBar_Particles1.Value);
        FVicsekEngine1 := TVicsekEngine0.Create(PaintBox_Sim.Width, PaintBox_Sim.Height, _RestoreParticles);
      end;
    ms_Boidss0:
      begin
        _RestoreParticles := Round(TrackBar_Particles1.Value);
        FBoidssEngine0 := TBoidssEngine0.Create(_RestoreParticles, PaintBox_Sim.LocalRect);
      end;
    ms_Boidss1:
      begin
        _RestoreParticles := Round(TrackBar_Particles2.Value);
        FBoidssEngine1 := TBoidssEngine1.Create(PaintBox_Sim.Width, PaintBox_Sim.Height, _RestoreParticles);
        FBoidssEngine1.TrailingAmount := 0.2;
      end;
    ms_Boidss2:
      begin
        _RestoreParticles := Round(TrackBar_Particles2.Value);
        FBoidssEngine2 := TBoidssEngine2.Create(_RestoreParticles, PaintBox_Sim.Width, PaintBox_Sim.Height);
      end;
    ms_Boidss3:
      begin
        _RestoreParticles := Round(TrackBar_Particles2.Value);
        FBoidssEngine3 := TBoidssEngine3.Create(PaintBox_Sim.Width, PaintBox_Sim.Height, _RestoreParticles);
      end;
    ms_Fractal:
      begin
        FFractalEngine := TFractalEngine.Create(Round(PaintBox_Sim.Width), Round(PaintBox_Sim.Height));
      end;
    ms_Aquarium:
      begin
        FAquariumEngine := TAquariumEngine.Create(C_Aquarium_FIshs, PaintBox_Sim.LocalRect);   //
      end;
  end;

  UpdateParametersAndLabels(False);
  Image_Bulgasari.Visible := FStarfishFlag and (FModeSelection = ms_Boidss0) and (Timer_Engine.Enabled) and (CheckBox_Dynamic.IsChecked);

  TrackBar_Particles1.OnTracking := TrackBar_NoiseTracking;  // rename ...
  TrackBar_Particles2.OnTracking := TrackBar_NoiseTracking;

  SetStartStopLabel(Timer_Engine.Enabled);
  InitModeSelection(Value);

  if ComboBox_Model.ItemIndex >= 0 then
    Action_Start.Execute;
end;

var
  V_LockDrawFlag: Boolean = False;

function TMainForm.GetParticleCounts(const AModel: TModeSelection): Integer;
begin
  Result := 0;
  case AModel of
    ms_Vicsek0: if Assigned(FVicsekEngine1) then Result := FVicsekEngine1.ParticleCount;
    ms_Boidss0: if Assigned(FBoidssEngine0) then Result := FBoidssEngine0.FishCount;
    ms_Boidss1: if Assigned(FBoidssEngine1) then Result := FBoidssEngine1.ParticleCount;
    ms_Boidss2: if Assigned(FBoidssEngine2) then Result := FBoidssEngine2.ParticleCount;
    ms_Boidss3: if Assigned(FBoidssEngine3) then Result := FBoidssEngine3.ParticleCount;
    ms_Fractal: Result := 0;
    ms_Aquarium: if Assigned(FAquariumEngine) then Result := FAquariumEngine.FishCount;
  end;
end;

procedure TMainForm.Set_StepCounts();
begin
  if Assigned(FFractalEngine) then Text_StepCount.Text := FFractalEngine.GetModeStatus else
  Text_StepCount.Text := Format('Particles: %d  FPS: %d  Steps: %d', [GetParticleCounts(FModeSelection), FFramePerSeconed, Stepcounts])
end;

procedure TMainForm.SetStepcounts(const Value: Integer);
begin
  FStepcounts := Value;
  if Assigned(FFractalEngine) then Text_StepCount.Text := FFractalEngine.GetModeStatus else
  Text_StepCount.Text := Format('Particles: %d  FPS: %d  Steps: %d', [GetParticleCounts(FModeSelection), FFramePerSeconed, FStepcounts])
end;

procedure TMainForm.Timer_EngineTimer(Sender: TObject);
begin
  if FLockControlFlag then Exit;
  if V_LockDrawFlag then Exit;

  V_LockDrawFlag := True;
  // ------------------------------------------------------------------------ //
  PaintBox_Sim.Repaint;
  Set_StepCounts();
  // ------------------------------------------------------------------------ //
  V_LockDrawFlag := False;
end;

procedure TMainForm.ActionList1Update(Action: TBasicAction; var Handled: Boolean);
begin
  Action_Reset.Enabled :=  Timer_Engine.Enabled;
  FLockPaintingFlag := not Timer_Engine.Enabled;
  if FModeSelection = ms_Boidss0 then
  begin
    Image_Bulgasari.Visible := PaintBox_Sim.IsMouseInside() and FStarfishFlag and (FModeSelection = ms_Boidss0) and
                              (Timer_Engine.Enabled) and (CheckBox_Dynamic.IsChecked);
  end;
end;

procedure TMainForm.SetStartStopLabel(const AFlag: Boolean);
begin
  if Timer_Engine.Enabled
    then Action_Start.Text := 'STP'
    else Action_Start.Text := 'RUN';

  FLockPaintingFlag :=  not Timer_Engine.Enabled;
  PaintBox_Sim.OnPaint  :=   PaintBox_SimPaint;
  Action_Reset.Enabled  :=   Timer_Engine.Enabled;
  Image_Bulgasari.Visible := PaintBox_Sim.IsMouseInside() and FStarfishFlag and (FModeSelection = ms_Boidss0) and
                             (Timer_Engine.Enabled) and (CheckBox_Dynamic.IsChecked);
end;

procedure TMainForm.AnimateVisibility(const AControl: TControl; const AMsg: string; const AShow: Boolean);
begin
  TLabel(AControl).Text := AMsg;
  var _Anim := TFloatAnimation.Create(AControl);
  with _Anim do
  begin
    Parent := AControl;
    PropertyName := 'Opacity';
    Duration := 2.0;
    AnimationType := TAnimationType.Out;
    Interpolation := TInterpolationType.Linear;
  end;

  if AShow then
    begin
      AControl.Opacity := 0;
      AControl.Visible := True;
      _Anim.StartValue := 0.5;
      _Anim.StopValue :=  1;
      _Anim.OnFinish :=   AnimationFinishedEvent;
    end
  else
    begin
      _Anim.StartValue := AControl.Opacity;
      _Anim.StopValue :=  0;
      _Anim.OnFinish :=   AnimationFinishedEvent;
    end;

  _Anim.Start;
end;

procedure TMainForm.AnimationFinishedEvent(Sender: TObject);
begin
  Label_Alarm.Visible := False;
end;

procedure TMainForm.Logo_FadeOutAndShrink(AControl: TControl; const ARestoreFlag: Boolean);
begin
  if not FLogoFlag then Exit;

  if ARestoreFlag then
    begin
      AControl.Opacity := 0;
      AControl.Visible := True;
      AControl.BringToFront;
      TAnimator.AnimateFloatWait(AControl, 'Opacity', 0.8, 0.5, TAnimationType.Out);
    end
  else
    begin
      AControl.Opacity := 0.8;
      TAnimator.AnimateFloatWait(AControl, 'Opacity', 0,   0.5, TAnimationType.IN);
      AControl.Visible := False;
    end;
end;

procedure TMainForm.Action_SnapshotExecute(Sender: TObject);
begin
  SaveScreenshot;
end;

procedure TMainForm.Action_StartExecute(Sender: TObject);
begin
  if FLogoFlag and Circle_Logo.Visible then
    Logo_FadeOutAndShrink(Circle_Logo, False);

  if ComboBox_Model.ItemIndex < 0 then
  begin
    ComboBox_Model.ItemIndex := 0;
    SetModeSelection(ms_Vicsek0);
    Exit;
  end;

  Timer_Engine.Enabled := not Timer_Engine.Enabled;
  SetStartStopLabel(Timer_Engine.Enabled);
end;

procedure TMainForm.Action_ResetExecute(Sender: TObject);
begin
  var _Timerflag := Timer_Engine.Enabled;
  Timer_Engine.Enabled := False;
  FLockPaintingFlag :=    True;
  FIsMousePressed1 :=     False;
  FIsMousePressed2 :=     False;

  var _Particles: Integer := 500;
  case FModeSelection of
    ms_Vicsek0:
        if Assigned(FVicsekEngine1) then
          begin
            FreeAndNil(FVicsekEngine1);
            _Particles := Round(TrackBar_Particles1.Value);
            FVicsekEngine1 := TVicsekEngine0.Create(PaintBox_Sim.Width, PaintBox_Sim.Height, _Particles);
          end;
    ms_Boidss0:
        if Assigned(FBoidssEngine0) then
          begin
            FreeAndNil(FBoidssEngine0);
            _Particles := Round(TrackBar_Particles1.Value);
            FBoidssEngine0 := TBoidssEngine0.Create(_Particles, PaintBox_Sim.LocalRect);
          end;
    ms_Boidss1:
        if Assigned(FBoidssEngine1) then
          begin
            FreeAndNil(FBoidssEngine1);
            _Particles := Round(TrackBar_Particles2.Value);
            FBoidssEngine1 := TBoidssEngine1.Create(PaintBox_Sim.Width, PaintBox_Sim.Height, _Particles);
            FBoidssEngine1.TrailingAmount := 0.2;
          end;
    ms_Boidss2:
        if Assigned(FBoidssEngine2) then
          begin
            FreeAndNil(FBoidssEngine2);
            _Particles := Round(TrackBar_Particles2.Value);
            FBoidssEngine2 := TBoidssEngine2.Create(_Particles, PaintBox_Sim.Width, PaintBox_Sim.Height);
          end;
    ms_Boidss3:
        if Assigned(FBoidssEngine3) then
          begin
            FreeAndNil(FBoidssEngine3);
            _Particles := Round(TrackBar_Particles2.Value);
            FBoidssEngine3 := TBoidssEngine3.Create(PaintBox_Sim.Width, PaintBox_Sim.Height, _Particles);
          end;
    ms_Fractal:
        if Assigned(FFractalEngine) then
          begin
            FreeAndNil(FFractalEngine);
            _Particles := Round(TrackBar_Particles2.Value);
            FFractalEngine := TFractalEngine.Create(Round(PaintBox_Sim.Width), Round(PaintBox_Sim.Height));
          end;
    ms_Aquarium:
        if Assigned(FAquariumEngine) then
          begin
            FreeAndNil(FAquariumEngine);
            FAquariumEngine := TAquariumEngine.Create(C_Aquarium_FIshs, PaintBox_Sim.LocalRect);
          end;
  end;

  Timer_Engine.Interval := C_TmInterval[FModeSelection];
  FFramePerSeconed :=      C_StepOf_FPS[FModeSelection];

  Stepcounts := 0;
  UpdateParametersAndLabels(False);
  Timer_Engine.Enabled := _Timerflag;
  SetStartStopLabel(Timer_Engine.Enabled);
end;

// Extra -------------------------------------------------------------------- //

procedure MakeImageCircular(const ASource: TBitmap; const ATargetCircle: TCircle);
begin
  ATargetCircle.Fill.Kind := TBrushKind.Bitmap;
  ATargetCircle.Fill.Bitmap.Bitmap.Assign(ASource);
  ATargetCircle.Fill.Bitmap.WrapMode := TWrapMode.TileStretch;

  ATargetCircle.Stroke.Color := C_BackgroundColor;//TAlphaColors.White;
  ATargetCircle.Stroke.Thickness := 1;
  ATargetCircle.Stroke.Kind := TBrushKind.Solid;
end;

procedure TMainForm.Image_LogoButtonClick(Sender: TObject);
begin
  Logo_FadeOutAndShrink(Circle_Logo, not Circle_Logo.Visible);
end;

procedure TMainForm.DrawCustomLogo();
begin
  var _PlantEngine := TPlantEngine.Create;
  try
    with Image_Template.Bitmap do
    try
      SetSize(300, 300);
      Canvas.BeginScene;
      Canvas.Clear(TAlphaColor($16253d));
      _PlantEngine.LogoText := 'Phyllotaxis';
      _PlantEngine.Render(Canvas, Image_Template.LocalRect);
    finally
      Canvas.EndScene;
    end;
    Image_Template.Visible := False;
    Circle_Logo.Visible := True;
    Circle_Logo.BringToFront;
  finally
    FreeAndNil(_PlantEngine);
  end;

  MakeImageCircular(Image_Template.Bitmap, Circle_Logo);
end;

end.
