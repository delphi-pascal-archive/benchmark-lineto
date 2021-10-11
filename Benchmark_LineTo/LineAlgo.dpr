program LineAlgo;

uses
  Forms,
  uMain in 'uMain.pas' {Form1},
  uBmpLine in 'uBmpLine.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.
