program SelfOrganization;

uses
  FastMM4,
  System.StartUpCopy,
  System.SysUtils,
  WinApi.Windows,
  FMX.Forms,
  FMX.Types,
  uCommons in 'uCommons.pas',
  uVicsekSim0 in 'uVicsekSim0.pas',
  uBoidsSim0 in 'uBoidsSim0.pas',
  uBoidsSim1 in 'uBoidsSim1.pas',
  uBoidsSim2 in 'uBoidsSim2.pas',
  uBoidsSim3 in 'uBoidsSim3.pas',
  uVicsekSim_Base in 'uVicsekSim_Base.pas',
  uBoidsSim_Base in 'uBoidsSim_Base.pas',
  uFractalGenerator in 'uFractalGenerator.pas',
  uPhyllotaxisPlant in 'uPhyllotaxisPlant.pas',
  uAquarumSim in 'uAquarumSim.pas',
  uRainDropEngine in 'uRainDropEngine.pas',
  uCyclicPalette in 'uCyclicPalette.pas',
  Unit_Main in 'Unit_Main.pas' {MainForm},
  uResources in 'uResources.pas' {Form_Resources};

{$R *.res}

{ Reference for $SETPEFLAGS IMAGE_FILE_LARGE_ADDRESS_AWARE ...
... Increasing the Memory Address Space
... Go Up to Managing Memory Index
... This section describes how to extend the address space of the Memory Manager beyond 2 GB, on Win32.
... Note: The default size of the user mode address space for a Win32 application is 2GB,
... but this can optionally be increased to 3GB on 32-bit Windows and 4GB on 64-bit Windows.
... The address space is always somewhat fragmented, so it is unlikely that a GetMem request
... for a single contiguous block much larger than 1GB will succeed - even with a 4GB address space.
}

{$SETPEFLAGS IMAGE_FILE_LARGE_ADDRESS_AWARE}    //  Good effects ...
{.$DEFINE USE_GPUACCELERATION }                 //  for GPU-accelerated drawing implementation
                                                //  Deprecated : cause Drawing FillPath on canvas is very slow than FillPolygon ...
const
  _AppTitle: string   = 'Self Organization SImulation 2026';
  _AppWarning: string = 'Self Organization SImulation 2026 is already running...';

var
  _mxHandle: THandle = 0;
  _RunTime: Boolean;

begin
  _RunTime := Application.MainForm = nil;
  if _RunTime then
    begin
      _mxHandle := CreateMutex(nil, False, PChar(_AppTitle));
      if GetLastError = ERROR_ALREADY_EXISTS then
      begin
        MessageBox(0, PChar(_AppWarning), PChar(_AppTitle), MB_OK or MB_ICONINFORMATION);
        Halt(0);
      end;
    end
  else
    begin
      MessageBox(0, PChar(_AppWarning), PChar(_AppTitle), MB_OK or MB_ICONINFORMATION);
      Halt(0);
    end;

  if _mxHandle <> 0 then
  try
    {$IFDEF USE_GPUACCELERATION}
    FMX.Types.GlobalUseGPUCanvas := True;
    {$ENDIF}

    Application.Initialize;
    Application.CreateForm(TMainForm, MainForm);
  Application.CreateForm(TForm_Resources, Form_Resources);
  Application.Run;
  finally
    CloseHandle(_mxHandle);
  end;
end.
