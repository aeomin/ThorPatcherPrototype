unit Fetcher;

interface
uses SysUtils, Classes, IdHTTP, IdHTTPHeaderInfo, IdBaseComponent, IdFTPCommon, IdComponent, IdTCPConnection, IdTCPClient, Global, CallBackes;

type
	TFetcher = class(TThread)
		HTTP: TIdHTTP;
	private
		fUrl,fFilename: string;
		fType : Byte;
		fCallBack:TCallBack;
		//Use to store current file id
		fId:Integer;
		procedure HTTPWork(Sender: TObject; AWorkMode: TWorkMode; AWorkCount: Integer);
		procedure HTTPWorkBegin(Sender: TObject; AWorkMode: TWorkMode; AWorkCountMax: Integer);
	protected
		procedure Execute; override;
	public
		constructor Create(const aFilename: string;aType:Byte;const aCallBack:TCallBack;const aId:Integer=0); overload;
	end;
implementation
uses
	Main;

constructor TFetcher.Create(const aFilename: string;aType:Byte;const aCallBack:TCallBack;const aId:Integer=0);
begin
	fFilename := aFilename;
	fType := aType;
	fCallBack := aCallBack;
	fId := aId;
//	FreeOnTerminate := true;
	inherited Create(false);
end;

procedure TFetcher.HTTPWork(Sender: TObject; AWorkMode: TWorkMode; AWorkCount: Integer);
begin
	MainFrm.ProgressBar.PartsComplete := AWorkCount;
end;

procedure TFetcher.HTTPWorkBegin(Sender: TObject; AWorkMode: TWorkMode; AWorkCountMax: Integer);
begin
	if AWorkCountMax > 0 then
	begin
		MainFrm.ProgressBar.PartsComplete := 0;
		MainFrm.ProgressBar.TotalParts := AWorkCountMax;
	end;
end;

procedure TFetcher.Execute;
var
	Trails: integer;
	Data : TMemoryStream;
	Parameter : TParameter;
begin
	HTTP := TIdHTTP.Create(nil);
	HTTP.AllowCookies := false;
	HTTP.HandleRedirects := true;
	HTTP.ProtocolVersion := pv1_1;
	HTTP.OnWork := HTTPWork;
	HTTP.OnWorkBegin := HTTPWorkBegin;
	HTTP.Request.UserAgent := 'Game Updater';
	Data := TMemoryStream.Create;
	Parameter := TParameter.Create;
	Parameter.ID := fId;
	Parameter.aType:=fType;
	if (fType = PFile) or (fType = PCFile) then
		fUrl := FILEURL + fFileName
	else
		fUrl := BASEURL + fFileName;
	for Trails := 0 to 10 do begin
		try
			Data.Clear;

			HTTP.Get(fUrl, Data);
			HTTP.Disconnect;
			HTTP.Free;
			Data.Position := 0;
			Parameter.aData := Data;
			fCallBack(Parameter);
			Data.Free;
			Parameter.Free;
			//I don't think should reset to zero in this time...
//			MainFrm.ProgressBar.PartsComplete := 0;
			break;
		except
		end;
	end;
//	Code below runs when all trails didnt work out -.- (yes..11 LOL)
	if Trails = 11 then
	begin
		if fType = PFile then
		begin
			//Even failed we still have to save it..
			Grf.SaveTable;
			Ace.PatchVersion := CurrentID;
			MainSwitch(SError, 'Failed to get ' + fFilename + ', Repacking...');
		end else
		begin
			MainSwitch(SError, 'Failed to communicate with server');
		end;
	end;
end;
end.

