program OceanRO;

uses
  FastMM4 in 'FastMM4.pas',
{$define FullDebugMode}
{$define LogMemoryLeakDetailToFile}
  Forms,
  Global in 'Global.pas',
  CallBackes in 'CallBackes.pas',
  Fetcher in 'Threads/Fetcher.pas',
  ConfigParser in 'Parsers/ConfigParser.pas',
  PListParser in 'Parsers/PListParser.pas',
  ZLibEx in 'zlib/ZLibEx.pas',
  ace_lib in 'Core/ace_lib.pas',
  ass_lib in 'Core/ass_lib.pas',
  grf_lib in 'Core/grf_lib.pas',
  fusion in 'Core/fusion.pas',
  GRFTypes in 'Core/GRFTypes.pas',
  CRC32 in 'Core/CRC32.pas',
  CommClient in 'Classes/CommClient.pas',
  Main in 'Main.pas' {MainFrm};

{$R *.res}

begin
  Application.Initialize;
  Application.Title := 'Patcher';
  Application.CreateForm(TMainFrm, MainFrm);
  Application.Run;
end.
