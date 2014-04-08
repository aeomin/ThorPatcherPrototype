unit Main;

interface

uses 
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, RzPrgres, jpeg, ExtCtrls, OleCtrls, SHDocVw, MSHTML, ShellApi, StdCtrls,
  List32, Global, aebutton,
  Fetcher,
  CallBackes,
  ConfigParser, PngImageList;
const 
  TH_MESSAGE = WM_USER + 1;
type
  TMainFrm = class(TForm)
    BG: TImage;
    Nav: TWebBrowser;
    ProgressBar: TRzProgressBar;
    CancelBTN: TAEButton;
    StartBTN: TAEButton;
    ExitBTN: TAEButton;
    Status: TLabel;
    PngCollection: TPngImageCollection;
    procedure StartBTNClick(Sender: TObject);
    procedure CancelBTNClick(Sender: TObject);
    procedure BGMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure BGMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure NavNavigateError(ASender: TObject; const pDisp: IDispatch;
      var URL, Frame, StatusCode: OleVariant; var Cancel: WordBool);
    procedure FormShow(Sender: TObject);
    procedure NavNavigateComplete2(ASender: TObject; const pDisp: IDispatch;
      var URL: OleVariant);
    procedure NavDownloadComplete(Sender: TObject);
    procedure FormCreate(Sender: TObject);
  private
    procedure HandleMessage(var Message:TMessage); message TH_MESSAGE;
  public
    { Public declarations }
  end;

var
  MainFrm: TMainFrm;
  CriticalSection : TRTLCriticalSection;
  dx, dy: integer;
  ds : boolean = false;
implementation

uses
	CRC32,
	PListParser,
	ace_lib,
	Grf_Lib,fusion;
{$R *.dfm}
//------------------------------------------------------------------------------
procedure WB_SetBorderStyle(Sender: TObject; BorderStyle: string);
var
  Document: IHTMLDocument2;
  Element: IHTMLElement;
begin
  Document := TWebBrowser(Sender).Document as IHTMLDocument2;
  if Assigned(Document) then
  begin
    Element := Document.Body;
    if Element <> nil then
    begin
      Element.Style.BorderStyle := BorderStyle;
    end;
  end;
end;
//------------------------------------------------------------------------------

//------------------------------------------------------------------------------
procedure TMainFrm.FormCreate(Sender: TObject);
var
	i : Integer;
begin
//	SetWindowLong(application.handle, gwl_exstyle, ws_ex_toolwindow);
	Nav.Hide;   //Hide web broswer first, so we don't a white box
	if (ParamStr(1) = '@idunno') and (ParamStr(2) <> '') then
	begin
		//I dont want to see you..
		SetWindowLong(application.handle, gwl_exstyle, ws_ex_toolwindow);
		Sleep(200);
		for i:=1 to 10 do
		if CopyFile(PChar(ParamStr(0)), PChar(ExtractFilePath(ParamStr(0)) + ParamStr(2)), False) then
			break;
		ShellExecute(Handle, 'open', PChar(ExtractFilePath(ParamStr(0)) + ParamStr(2)), '@ucu', nil, SW_SHOWNORMAL);
		ds := True;
		Application.Terminate;
	end else
	begin
		if (ParamStr(1) = '@ucu') then begin
			Sleep(200);
			DeleteFile(ExtractFilePath(ParamStr(0)) + 'tmp.exe');
		end;
		Config := TConfig.Create;
		ThreadList := TIntList32.Create;
		PatchList := TPListParser.Create;
		Ace := TAce.Create;
		Grf := TGrf.Create;
		Nav.Navigate(BASEURL + 'Notice.html');
	end;
end;
//------------------------------------------------------------------------------

//------------------------------------------------------------------------------
procedure TMainFrm.NavDownloadComplete(Sender: TObject);
begin
//	Nav.Show;  //Load complete? then show it!
end;

//------------------------------------------------------------------------------
procedure TMainFrm.NavNavigateComplete2(ASender: TObject;
  const pDisp: IDispatch; var URL: OleVariant);
begin
	Nav.Show;  //Load complete? then show it!
	WB_SetBorderStyle(Nav, 'none');
end;

procedure TMainFrm.FormShow(Sender: TObject);
begin
	if ds then Exit;
	case Ace.LoadACE(AceFile) of  //XD
		//only success!
		ACE_SUCCESS:
		begin    
			AppFull := ParamStr(0);
			AppPath := ExtractFilePath(ParamStr(0)); //i want keep at this spot XD
			AppName := ExtractFilename(ParamStr(0));
			MakeTable;
			CurrentID := Ace.PatchVersion;
			TFetcher.Create('main.txt', PMain, DownloadComplete);
		end;
		ACE_FILELOCKED: MainSwitch(SError, AceFile + ' is locked.');
		ACE_INVALID: MainSwitch(SError, AceFile + ' is an invalid ACE file.');
		ACE_UNIMPLEMENT_VERSION: MainSwitch(SError, 'Verion of ' + AceFile + ' is not supported');
	end;

end;

procedure TMainFrm.NavNavigateError(ASender: TObject; const pDisp: IDispatch;
  var URL, Frame, StatusCode: OleVariant; var Cancel: WordBool);
begin
	Nav.Hide;    //Error? HIDE!!
end;

procedure TMainFrm.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
//var
//	Idx : Integer;
//	Thread : TThread;
begin
	if not LockedDown then
	begin
		if assigned(Grf) then
			Grf.Free;
		if assigned(Ace) then
			Ace.Free;
	end else
		CanClose := False;
//	EnterCriticalSection(CriticalSection);
//	for Idx := ThreadList.Count - 1 downto 0 do
//	begin
//		Thread := ThreadList.Objects[Idx] as TThread;
//		Thread.Free;
//	end;
//	LeaveCriticalSection(CriticalSection);
//	ThreadList.Free;
end;

procedure TMainFrm.BGMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
	dx := X;
	dy := y;
end;

procedure TMainFrm.BGMouseMove(Sender: TObject; Shift: TShiftState; X,
  Y: Integer);
begin
	if Shift = [ssleft] then begin
		Left := Left + (X - dx);
		Top := Top + (Y - dy);
	end;
end;

procedure TMainFrm.CancelBTNClick(Sender: TObject);
begin
	Close(); //just do it!
end;
procedure TMainFrm.HandleMessage(var Message:TMessage);
begin
	Close;
end;
procedure TMainFrm.StartBTNClick(Sender: TObject);
begin
	if CanStart then
	begin
		ShellExecute(Handle, 'open', PChar(AppPath + ClientFile), nil, PChar(AppPath), SW_SHOWNORMAL);
		Close;
	end;
end;

end.
