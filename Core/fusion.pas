unit fusion;
interface
uses
	SysUtils,
	Classes,
	Global,
	Ass_Lib,
	Grf_Lib;

	function AssFusion(Filename:String):Boolean;
implementation
uses
	Main;
function AssFusion(Filename:String):Boolean;
var
	Ass : TAss;
	Idx : Integer;
	Data : TMemoryStream;
	DataName : String;
begin
	Result := False;
	Ass := TAss.Create;
		//well..load it DUH..
		case Ass.LoadAss(FileName) of
			ASS_SUCCESS:
			begin   //YES..LOADED!!!
				Ass.CounterReset; //OK, back to begining!
				//since count is count, and it does not have index..so..
				//Idx just used to loop, nothing more!
				LockedDown := True;
				MainFrm.CancelBTN.Enabled := False;
				MainFrm.ProgressBar.TotalParts := Ass.FileCount;
				Status('Saving Resource...');
				for Idx := 1 to Ass.FileCount do
				begin
					Data := TMemoryStream.Create;
					Ass.ExtractData(DataName, Data);
					if Ass.DataType = ASST_GRF then
					begin
						Grf.AddData(DataName, Data);
					end else
					begin   //what else? GRF or FILE..
						CreateDir(AppPath + ExtractFilePath(DataName));
						Data.SaveToFile(AppPath + DataName);
						Data.Free; //Free UP!
					end;
					MainFrm.ProgressBar.PartsComplete := MainFrm.ProgressBar.PartsComplete + 1;
				end;
				Result := True;
				LockedDown := False;
				MainFrm.CancelBTN.Enabled := True;
			end;
			ASS_FILELOCKED:MainSwitch(SError, FileName + ' is locked.');
			ASS_INVALID:MainSwitch(SError, FileName + ' is an invalid ASS file.');
			ASS_INVALIDTYPE:MainSwitch(SError, FileName + ' has an invalid data type.');
		end;
	Ass.Free;
	DeleteFile(FileName);
end;

end.