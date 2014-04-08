unit CallBackes;

interface

uses
	Windows, ShellAPI, SysUtils, Global;

	procedure DownloadComplete(
		const
			aParameter : TParameter
		);
implementation

uses Main, Crc32, Fetcher, PListParser, ConfigParser, Ass_Lib, fusion;
//Active when file is downloaded
procedure DownloadComplete(
		const
			aParameter : TParameter
		);
var
	FileName:String;
begin
	case aParameter.aType of
		//If just main file..
		PMain: begin
			//Load Config from stream, LoadIndex should able to handle
			//all errors
			Config.LoadIndex(aParameter.aData);
			//Force playable?
			if (Config.OpBit and 1)>0 then
			begin
				MainSwitch(SSuccess);
			end else
			if not Config.Policy then
			begin
				//Denied
				MainSwitch(SError, Config.PolicyMSG);
			end else
			begin
				//Begin to fetch filelist
				TFetcher.Create(Config.PatchList, PList, DownloadComplete);
			end;
		end;
		//Finish downloading patch list?
		PList: begin
			PatchList.Load(aParameter.aData);
			//this shouldn't happen! uhm..runing using wine in LINUX?
			if not FileExists(AppFull) then
			begin
				MainSwitch(SError, 'Unexpected Fatal error. 0x000001');
			end else
//			check patcher's checksum first!!!
//			if (Config.PatcherSum <> '') and (IntToHex(GetFileCrc32(AppFull), 8) <> Config.PatcherSum) then
//			begin
//				Status('Updating Patcher');
//				MainFrm.CancelBTN.Enabled := True;
//				LockedDown := False;
//				TFetcher.Create(Config.PatcherURL, PCFILE, DownloadComplete, CPatcher);
//			end else
//			if client not exists then just redownload!
//			if (Config.ClientSum <> '') and not FileExists(ClientFile) then
//			begin
//				Status('Updating Client');
//				MainFrm.CancelBTN.Enabled := True;
//				LockedDown := False;
//				TFetcher.Create(Config.ClientURL, PCFILE, DownloadComplete, CClient);
//			end else
//			if (Config.ClientSum <> '') and (IntToHex(GetFileCrc32(AppPath + ClientFile), 8)<>Config.ClientSum) then
//			begin
//				Status('Updating Client');
//				MainFrm.CancelBTN.Enabled := True;
//				LockedDown := False;
//				TFetcher.Create(Config.ClientURL, PCFILE, DownloadComplete, CClient);
//			end else
				PatchList.GetNext;
		end;
		PCFILE: begin
			case aParameter.ID of
				CPatcher: begin
					if FileExists(ExtractFilePath(AppFull) + 'tmp.exe') and LockedFile(ExtractFilePath(AppFull) + 'tmp.exe')then
						MainSwitch(SError, 'Unexpected Fatal error. 0x000002')
					else begin
						aParameter.aData.SaveToFile(ExtractFilePath(AppFull) + 'tmp.exe');
						ShellExecute(0, 'open', PChar(ExtractFilePath(AppFull) + 'tmp.exe'), Pchar('@idunno "' + AppName +'"'), nil, SW_SHOWNORMAL);
						PostMessage(MainFrm.Handle,TH_MESSAGE, 0 ,0);
					end;
				end;
				CClient : begin
					if FileExists(AppPath + ClientFile) and LockedFile(AppPath + ClientFile)then
						MainSwitch(SError, 'Client Application is locked')
					else begin
						aParameter.aData.SaveToFile(AppPath + ClientFile);
						PatchList.GetNext;
					end;
				end;
			end;
		end;
		//and patch file
		PFile: begin
			FileName := 'tmp'+IntToStr(aParameter.ID)+'.ass';
			aParameter.aData.SaveToFile(FileName); //save to temp file
			if AssFusion(FileName) then   //Oh..okay...fusioned!!! next~
			begin
				Inc(CurrentID);
				PatchList.GetNext;
			end;
		end;
	end;
end;

end.