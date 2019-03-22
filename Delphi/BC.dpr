program BC;

uses
  Forms,
  BCommander in 'BCommander.pas' {Form1};

{$R *.RES}

begin
  Application.Initialize;
  Application.Title := 'Boris';
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.
