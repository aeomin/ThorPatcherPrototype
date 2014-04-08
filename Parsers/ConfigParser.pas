unit ConfigParser;
//Thise unit is use to parse main index file
//main index file directs patcher to do something (usually is main.txt)
interface

uses
	Classes;
type
	TConfig = class
		private

		public
			//On/Off Switch
			//Allow/Deny
			Policy:Boolean;
			//Script Engine (not using yet)
			ASE:Boolean;

			//Message to show when policy is deny(false)
			PolicyMSG:String;
			//Core Version, it has nothing to do version of patcher
			Version:Integer;
			//CRC Checksum of client (not patcher), using Int
			ClientSum:String;
			//now is patcher
			PatcherSum:String;
			//URL of client and patcher (for update or so)
			ClientURL,PatcherURL:String;
			//Patchlist file
			PatchList:String;
			//Option bitmask
			OpBit:Integer;
			procedure LoadIndex(const Data:TMemoryStream);
			constructor Create;
	end;
implementation
uses sysutils, Global;
procedure TConfig.LoadIndex(const Data:TMemoryStream);
var
	Buffer : PChar;
	ConfStr : String;
	RawEntry : TStringList;
	Idx,Position : Integer;
	Name, Value : String;
begin
	GetMem(Buffer, Data.Size);
	Data.Read(Buffer^, Data.Size);
	ConfStr := Copy(Buffer, 0, Data.Size);
	FreeMem(Buffer);
	RawEntry := TStringList.Create;
        //use 0x0A in case =p
	Split(#10, ConfStr, RawEntry);
	for Idx := RawEntry.Count -1 downto 0 do
	begin
		if Trim(RawEntry[idx]) = '' then Continue;
		Position := Pos(':', RawEntry[idx]);
		//A very nice soft handling problem(s)
		if Position = 0 then
			Continue;
		Name := Trim(LowerCase(Copy(RawEntry[idx], 1, Position - 1)));
		Value := Trim(Copy(RawEntry[idx], Position + 1, StrLen(PChar(RawEntry[idx])) - Position));
		if Name = 'policy' then
			Config.Policy := CToggle(Value, False)
		else if Name = 'policy_msg' then
			Config.PolicyMSG := Value
		else if Name = 'ase' then
			Config.ASE := CToggle(Value, False)
		else if Name = 'version' then
			Config.Version := StrToIntDef(Value, 1)
		else if Name = 'clientsum' then
			Config.ClientSum := Value
		else if Name = 'patchersum' then
			Config.PatcherSum := Value
		else if (Name = 'clienturl') and (Value <> 'nil') then
			Config.ClientURL := Value
		else if (Name = 'patcherurl') and (Value <> 'nil') then
			Config.PatcherURL := Value
		else if (Name = 'patchlist') and (Value <> 'nil') then
			Config.PatchList := Value
		else if Name = 'opbit' then
			Config.OpBit := StrToIntDef(Value, 0)
	end;
	RawEntry.Clear;
	RawEntry.Free;
end;

constructor TConfig.Create;
begin
	Policy := False;
	ASE := False;
	PolicyMSG := 'Service Unavailable...';
	Version := 1;
	ClientSum := '';
	PatcherSum := '';
	ClientURL := '';
	PatcherURL := '';
	PatchList := '';
	OpBit := 0;
end;

end.