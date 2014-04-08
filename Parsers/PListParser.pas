unit PListParser;
interface
uses SysUtils, Classes, List32;
type
	TPListParser = class
	private
		PListI : TIntList32;  //Stores Ids
		PListS : TStringList; //Stores Filename
		function GetNextID:Integer;
	public
		procedure Load(const Data:TMemoryStream);
		procedure GetNext;
	end;
implementation
uses Main, Global, Fetcher, CallBackes, grf_Lib, GRFTypes;
procedure TPListParser.Load(const Data:TMemoryStream);
var
	Buffer : PChar;
	ConfStr : String;
	RawEntry : TStringList;
	Idx,Position : Integer;
	Name, Value : String;
        Id : Integer;
begin
	if not assigned(PListI) then
		PListI := TIntList32.Create
	else
		PListI.Clear;
	if not assigned(PListS) then
		PListS := TStringList.Create
	else
		PListS.Clear;

	GetMem(Buffer, Data.Size);
	Data.Read(Buffer^, Data.Size);
	ConfStr := Copy(Buffer, 0, Data.Size);
	FreeMem(Buffer);
	Split(#10, ConfStr, RawEntry);
	for Idx := 0 to RawEntry.Count -1 do
	begin
		Position := Pos(' ', RawEntry[Idx]);
		if Position > 0 then
		begin
			if Trim(RawEntry[idx]) = '' then Continue;
			Name := Trim(Copy(RawEntry[idx], 1, Position - 1));
			Value := Trim(Copy(RawEntry[idx], Position + 1, StrLen(PChar(RawEntry[idx])) - Position));
			if not IsInt(Name) then Continue;
			Id := StrToInt(Name);
			PListI.Add(Id);
			PListS.Add(Value);
		end;
	end;
	RawEntry.Free;
end;

function TPListParser.GetNextID:Integer;
var
  Idx: integer;
begin
	Result := PListI.IndexOf(CurrentId + 1); //Try next id
	if Result = -1 then  //Ops
	begin
		for Idx := 0 to PListI.Count - 1 do
		begin
			if PListI[Idx] > CurrentId then   //then try best to fetch any higher number
			begin
				Result := Idx;
				Break;
			end;
		end;
	end;
end;

procedure TPListParser.GetNext;
var
	Id : Integer;
begin
	if (not assigned(PListI)) or (not assigned(PListS)) then
		Exit;
	if PListI.Count = 0 then    //No patch AT ALL? then your job is done..
		MainSwitch(SSuccess)
	else begin
		Id := GetNextID;
		if Id = -1 then  //Since we can't get any new patch..
		begin
			if assigned(Grf) then
			begin
				Grf.SaveTable;
				Ace.PatchVersion := CurrentID;
			end;
			MainSwitch(SSuccess);
		end else
		begin  //new patch
			if not LoadedGrf then
			begin
				if Assigned(Grf) then
					Grf.Free;
				Grf := TGrf.Create;
				case Grf.LoadGrf(GrfFile) of
					GRF_SUCCESS:
					begin   //Start to load table!
						case Grf.LoadTable of
							GRF_SUCCESS:
							begin
								LoadedGrf := True; //Finally...
								//Now lets get file...
								Status('Getting file ' + PListS[Id] +'.');
								TFetcher.Create(PListS[Id], PFile, DownloadComplete, Id);
								MainFrm.CancelBTN.Enabled := True;
								LockedDown := False;
							end;
							GRF_STAKEOVERFLOW: MainSwitch(SError, GrfFile + ' Stack Overflow.');
							GRF_STAKERANGEOUT: MainSwitch(SError, GrfFile + ' Stack Out of Range.');
						end;
					end; //end  GRF_SUCCESS
					GRF_FILELOCKED: MainSwitch(SError, GrfFile + ' is locked.');
					GRF_INVALID: MainSwitch(SError, GrfFile + ' is an invalid GRF file.');
					GRF_UNKNOWN_CRYPT: MainSwitch(SError, GrfFile + ' has an unknown encryption.');
					GRF_UNIMPLEMENT_VERSION: MainSwitch(SError, GrfFile + ' has an unsupported version.');
				end; //end case
			end else  //end If
			begin
				//OMG..duplicated CODE!!!!
				Status('Getting file ' + PListS[Id] +'.');
				TFetcher.Create(PListS[Id], PFile, DownloadComplete, Id);
			end;
		end; //end else
	end;
end;
end.