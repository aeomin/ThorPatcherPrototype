unit grf_lib;
{
	`.
       `. ..                                     `.
      `.  `..      `..       `..   `... `.. `..    `.. `..
     `..   `..   `.   `..  `..  `.. `..  `.  `..`.. `..  `..
    `...... `.. `..... `..`..    `..`..  `.  `..`.. `..  `..
   `..       `..`.         `..  `.. `..  `.  `..`.. `..  `..
  `..         `.. `....      `..   `...  `.  `..`..`...  `..
			GRF CORE
		Orignal code from GrfTool
	   Rewrite in Delphi/Pascal by Aeomin

NOTE:
Hash apparent not used... er..
}
interface
uses
	Windows,dialogs,SysUtils,
	Classes,
	GRFTypes,
	ZlibEx;
const
	GRF_Header = 'Master of Magic';
	GRF_Header_Len = Length(GRF_Header);

	//Uhm..should it change to dynamic generated?
	Crypt_WaterMark : packed array[0..14] of Byte = ($00, $01, $02, $03, $04, $05, $06, $07, $08,
							$09, $0A, $0B, $0C, $0D, $0E );
	Crypt_WaterMark_Len = Length(Crypt_WaterMark);
	GRF_Header_Mid_Len = GRF_Header_Len + Crypt_WaterMark_Len;
	GRF_Header_Full_Len = GRF_Header_Len + $1F;
type
TGrfFile = packed record
	Compressed_Len_Aligned: Cardinal;
	Compressed_Len: Cardinal;
	RealLen: Cardinal;
	Pos: Cardinal;

	Flags: Byte;

	Hash: Cardinal;
	Name: String;

	Deleted : Boolean; //Soft deletion
end;
PGrfFile = ^TGrfFile;
TGrfFiles = array of TGrfFile;
//------------------------------------------------------------------------------
TGrf = class
	private
		FileData : TFileStream;
		TableLoaded : Boolean;
		Modified   : Boolean;
		function LockedFile(FileName: string): Boolean;
		function NameHash(Name : String):Cardinal;
		procedure CreateGRF(const Filename:String);
	public
		Files: TGrfFiles;
		AllowCrypt: Boolean;
		TableOffset : Integer;
		RealTableOffset : Integer;
		Seeds	: Integer;
		FileCount  : Integer;
		Version : Integer;

		CompressedTableSize : Integer;
		RealTableSize : Integer;
		function LoadGrf(Filename:String):Byte;
		function LoadTable:Byte;
		function SaveTable:Byte;
		procedure ReloadTable;
		function IndexOfFile(Name: String):Integer;
		function AddData(const Name: String; Data:TStream):Byte; overload;
		function AddData(const Name, Location:String):Byte; overload;
		function Rename(const OldName, NewName:String):Byte; overload;
		function Delete(const Idx:Integer):Byte; overload;
		function ExtractToStream(Idx:Integer;var Data:TMemoryStream):Byte; overload;
		function ExtractToStream(Name:String;var Data:TMemoryStream):Byte; overload;
		function ExtractToChar(Idx:Integer;var Output:PChar):Byte; overload;
		function ExtractToChar(Name:String;var Output:PChar):Byte; overload;
		function ExtractToFile(const Idx: Integer; const Location: String):Byte; overload;
		function ExtractToFile(const Name, Location: String):Byte; overload;
		destructor Destroy();override;
end;
implementation
uses
	Global, Main; //Use to control progressbar
var
	GRF_ZERO :Integer= 0;
	GRF_ONE :Integer= 1;
	GRF_Seven : Integer = 7;
	GRF_VER : Integer=$200;
//Never used...
//------------------------------------------------------------------------------
//function LittleEndian(N:LongInt) : LongInt;
//var
//B0, B1, B2, B3 : Byte;
//begin
//	B0 := (N AND $000000FF) SHR 0;
//	B1 := (N AND $0000FF00) SHR 8;
//	B2 := (N AND $00FF0000) SHR 16;
//	B3 := (N AND $FF000000) SHR 24;
//	Result := (B0 SHL 24) OR (B1 SHL 16) OR (B2 SHL 8) OR (B3 SHL 0);
//end;
//------------------------------------------------------------------------------

//STATUS: COMPLETE, IMPROVEMENT NEEDED!
//------------------------------------------------------------------------------
function TGrf.LoadGrf(Filename:String) : Byte;
var
	Buffer : PChar;
//	IntBuffer : Integer;
	Idx	: Integer;
begin
	Result := GRF_SUCCESS;
	if Assigned(FileData) then FileData.Free;
	if not FileExists(Filename) then
		CreateGrf(Filename);
	if LockedFile(Filename) then
	begin
		Result := GRF_FILELOCKED;
		Exit;
	end;
	FileData := TFileStream.Create(Filename, fmOpenReadWrite or fmShareDenyWrite);
	FileData.Seek(0, soFromBeginning);
	GetMem(Buffer, GRF_Header_Len);
	//Read header
	FileData.Read(Buffer^, GRF_Header_Len);
	//Wrong Header!!!
	if Copy(Buffer, 0, GRF_Header_Len) <> GRF_Header then
	begin
		Result := GRF_INVALID;
		Exit;
	end;
	FreeMem(Buffer);
	//One byte at a time...
	GetMem(Buffer, 1);
//	Filedata.Seek(1, soFromCurrent);
	FileData.ReadBuffer(Buffer[0], 1); //We only need first byte..
	if Buffer[0] = #0 then
	begin
		FileData.ReadBuffer(Buffer[0], 1); //Second byte, either 1 or 0 else fail
		if Buffer[0] = #1 then  //Encryption allow
		begin
			{* 00 01 02 03 04 05 06 07 08 09 0A 0B 0C 0D 0E *}
			for Idx := 2 to Crypt_WaterMark_Len - 1 do
			begin
				FileData.ReadBuffer(Buffer[0], 1);
				if Buffer[0] <> Char(Crypt_WaterMark[Idx]) then
				begin
					Result := GRF_UNKNOWN_CRYPT;
					Exit;
				end;
				AllowCrypt := True;
			end;
		end else if Buffer[0] = #0 then //Encryption disallow
		begin
			{* 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 *}
			for Idx := 2 to Crypt_WaterMark_Len - 1 do
			begin
				FileData.ReadBuffer(Buffer[0], 1);
				if Buffer[0] <> #0 then
				begin
					Result := GRF_UNKNOWN_CRYPT;
					Exit;
				end;
				AllowCrypt := False;
			end;
		end else
		begin  //Failed..
			Result := GRF_UNKNOWN_CRYPT;
			Exit;
		end;
	end else
	begin
		Result := GRF_UNKNOWN_CRYPT;
		Exit;
	end;
	FreeMem(Buffer); //Freedom..(even only one byte)
	//So...the file is pretty much valid..or maybe..lets check and get some informations...
	//The pointer is currently at GRF_HEADER_MID_LEN
	FileData.ReadBuffer(TableOffset, 4);
	RealTableOffset := TableOffset+GRF_HEADER_FULL_LEN;
	FileData.ReadBuffer(Seeds, 4);
	FileData.ReadBuffer(FileCount, 4);
	FileCount := FileCount - Seeds - 7;
        FileData.ReadBuffer(Version, 4);
	if Version <> $200 then  //0x200 ONLY!!
	begin
		Result := GRF_UNIMPLEMENT_VERSION;
		Exit;
	end;
	TableLoaded := False;
end;
//------------------------------------------------------------------------------


procedure TGrf.CreateGRF(const Filename:String);
var
	Temp, Table : TMemoryStream;
	Buffer : PChar;
	TmpOffset : Int64;
	idx,Size : Integer;
begin
	FileData := TFileStream.Create(Filename, fmCreate);
	FileData.Seek(0, soFromBeginning);
	FileData.Write(GRF_Header, GRF_Header_Len);
	for idx := 0 to 14 do             //Crypt LOL..
		FileData.Write(GRF_ZERO, 1);     
	FileData.Write(GRF_ZERO, 4);      //Table offset... Zero first =p
	FileData.Write(GRF_ZERO, 4);      //Seeds
	FileData.Write(GRF_SEVEN, 4);       //7 for file count
	FileData.Write(GRF_VER, 4);      //GRF ver
	Temp := TMemoryStream.Create;
	Table := TMemoryStream.Create;
	ZCompressStream(Temp, Table, zcMax);
	Temp.Free;
	Table.Position := 0;
	GetMem(Buffer, Table.Size);
	Table.Read(Buffer^, Table.Size);
	TmpOffset := FileData.Position - GRF_HEADER_FULL_LEN;
	Size := Table.Size;
	FileData.Write(Size, 4);
	FileData.Write(GRF_ZERO, 4);
	FileData.Write(Buffer^, Table.Size);
	FreeMem(Buffer);
	FileData.Position := GRF_Header_Len; //go back to table offset
	FileData.Write(TmpOffset, 4);
	Table.Free;
	FileData.Free;
end;


//STATUS : WORKING BUT...uhm..i dunno...
//WARNING : THIS IS ONLY FOR 0x200 GRF!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
//------------------------------------------------------------------------------
function TGrf.LoadTable:Byte;
var
	TempData : TMemoryStream;
	TableData : TMemoryStream;
	Buffer:Pchar;
	Idx : Integer;
	OffSet : Integer;
begin
	Result := GRF_SUCCESS;
	//Go to table offset.
	FileData.Position := RealTableOffset;
//	if assigned(TableData) then TableData.Free;
	TempData := TMemoryStream.Create;
	TableData := TMemoryStream.Create;
	FileData.ReadBuffer(CompressedTableSize, 4);
	FileData.ReadBuffer(RealTableSize, 4);
	if CompressedTableSize > FileData.Size - FileData.Position then
	begin
		Result := GRF_STAKEOVERFLOW;
		Exit;
	end;
	TempData.CopyFrom(FileData, CompressedTableSize); //Just copy there
	TempData.Position:=0;  //We need back to start
	ZDecompressStream(TempData, TableData); //Decompress using ZLib
	TempData.Clear;
	TempData.Free; //Bye..
	TableData.Position := 0; //Back to start.
	if TableData.Size <> RealTableSize then
	begin
		Result := GRF_STAKERANGEOUT;
		Exit;
	end;
	SetLength(Files, FileCount);  //How many files?
	OffSet := 0;
	//Current position of TableData is 0
	for Idx := 0 to FileCount - 1 do
	begin
		TableData.Position := Offset;
		//PERFECT..since stream will stop at 0x00 so no worry..
		GetMem(Buffer, 255);
		TableData.Read(Buffer^, 255);
		Inc(Offset, StrLen(Buffer) +1 ); //Add string length to offset, +1 for zero terminate
		//More INFORMATIONS!!
		Files[Idx].Name := Buffer;
		Files[Idx].Hash := NameHash(ExtractFileName(Buffer));
		FreeMem(Buffer);
		TableData.Position := Offset; //UPDATE
		TableData.Read(Files[Idx].Compressed_Len, 4);
		TableData.Read(Files[Idx].Compressed_Len_Aligned, 4);
		TableData.Read(Files[Idx].RealLen, 4);
		TableData.Read(Files[Idx].Flags, 1);   //Flags is only one byte
		TableData.Read(Files[Idx].Pos, 4);
		Inc(Files[Idx].Pos, GRF_HEADER_FULL_LEN);  //Need add GRF_HEADER_FULL_LEN
		Inc(Offset, 17);    //0x11
		Files[Idx].Deleted := False;
	end;
	TableLoaded := True;
	TableData.Clear;
	TableData.Free;
end;
//------------------------------------------------------------------------------


//------------------------------------------------------------------------------
//	Purpose:
//		Regenerate Index Table
//	Any changes require to run this function, or else GRF will be occrupt.
//
//------------------------------------------------------------------------------
function TGrf.SaveTable:Byte;
var
	TableData, TempData : TMemoryStream;
	Idx, Tmp : Integer;
	Buffer : PChar;
begin
	if not Modified then
	begin
		Result := GRF_NOTMODIFIED;
		Exit;
	end;
	Status('Repacking resource files...');
	LockedDown := True;
	MainFrm.CancelBTN.Enabled := False;
	MainFrm.ProgressBar.TotalParts := FileCount;
	Result := GRF_SUCCESS;
	TableData := TMemoryStream.Create;
	TempData  := TMemoryStream.Create;
	TableData.Position := 0;    //Reset Offset to 0
	//Generate Table
	for Idx := 0 to FileCount - 1 do
	begin
		if Files[Idx].Deleted then Continue; //Soft Deletion
		GetMem(Buffer, StrLen(PChar(Files[Idx].Name)));
		Buffer := PChar(Files[Idx].Name + #0);
		TableData.Write(Buffer^, StrLen(Buffer) + 1);
//		FreeMem(Buffer);
		TableData.Write(Files[Idx].Compressed_Len, 4);
		TableData.Write(Files[Idx].Compressed_Len_Aligned, 4);
		TableData.Write(Files[Idx].RealLen, 4);
		TableData.Write(Files[Idx].Flags, 1);   //Flags is only one byte
		Dec(Files[Idx].Pos, GRF_HEADER_FULL_LEN); //Subtract
		TableData.Write(Files[Idx].Pos, 4);
		MainFrm.ProgressBar.PartsComplete := MainFrm.ProgressBar.PartsComplete + 1;
	end;
	FileData.Position := GRF_HEADER_MID_LEN;
	FileData.Write(TableOffset, 4);    //Renew offsets
	Tmp := 0;                              //DAMN IT
	FileData.Write(Tmp, 4);                  //Seeds..still not sure
	Tmp := FileCount + 7;
	FileData.Write(Tmp, 4);      //Filecount

	FileData.Position := RealTableOffset;
	TableData.Position :=0;
	TempData.Position := 0;
	ZcompressStream(TableData, TempData, zcDefault);
	TableData.Position :=0;
	TempData.Position := 0;
	GetMem(Buffer, TempData.Size);
	TempData.Read(Buffer^, TempData.Size);
	Tmp := TempData.Size;   //Bad way..but the damn thing require variable..
	FileData.Write(Tmp, 4);
	Tmp := TableData.Size;
	FileData.Write(Tmp, 4);
	FileData.Write(Buffer^, TempData.Size);
	FileData.Size := RealTableOffset + TempData.Size + 8;  //add 8 for those 2 integers
	FreeMem(Buffer);
	TableData.Free;
	FileData.Position := 0;
	Modified := False; //Unlock
end;
//------------------------------------------------------------------------------


//------------------------------------------------------------------------------
//	Purpose:
//		A wraper to save and load it again (LOL)
//
//------------------------------------------------------------------------------
procedure TGrf.ReloadTable;
begin
	if SaveTable = GRF_SUCCESS then
	Loadtable;
end;
//------------------------------------------------------------------------------


//------------------------------------------------------------------------------
//	Purpose:
//		Check if file is locked up on local harddrive
//		(ex. Opened with other program)
//
//------------------------------------------------------------------------------
function TGrf.LockedFile(FileName: string): Boolean;
var
	AFile: THandle;
	SecAtrrs: TSecurityAttributes;
begin
	FillChar(SecAtrrs, SizeOf(SecAtrrs), #0);
	SecAtrrs.nLength := SizeOf(SecAtrrs);
	SecAtrrs.lpSecurityDescriptor := nil;
	SecAtrrs.bInheritHandle := True;
	AFile := CreateFile(PChar(FileName), GENERIC_READ or GENERIC_WRITE,
	FILE_SHARE_Read, @SecAtrrs, OPEN_EXISTING,
	FILE_ATTRIBUTE_Normal, 0);
	if AFile = INVALID_HANDLE_VALUE then
	begin
		Result := True;
	end else
	begin
		Result := False;
	end;
	CloseHandle(AFile);
end;
//------------------------------------------------------------------------------


//------------------------------------------------------------------------------
//			CONVERTED FROM LIBGRF
//	Purpose:
//		Make a hash of filename, used for search.
//------------------------------------------------------------------------------
function TGrf.NameHash(Name : String):Cardinal;
var
	Len : Integer;
	Idx : Integer;
begin
	Len := StrLen(PChar(Name));
	Result := $1505;
	for Idx := 1 to Len do
	begin
		Result := Result * $21 + Ord(Name[Idx]);
	end;
end;
//------------------------------------------------------------------------------


//------------------------------------------------------------------------------
//	Purpose:
//		Get index of an file
//
//------------------------------------------------------------------------------
function TGrf.IndexOfFile(Name: String):Integer;
var
	Idx : Integer;
	Hash : Cardinal;
begin
	Result := -1;
	Hash := NameHash(ExtractFileName(Name));
	for Idx := Length(Files) - 1 downto 0 do
	begin
		if (Files[Idx].Hash = Hash)and(Files[Idx].Name = Name) then
		begin
			if not Files[Idx].Deleted then
			Result := Idx;
			Break;
		end;
	end;
end;
//------------------------------------------------------------------------------


//------------------------------------------------------------------------------
//	Purpose:
//		Add data to GRF, GRF is locked up after using this function.
//	Use SaveTable to flush up and unlock.
//
//------------------------------------------------------------------------------
function TGrf.AddData(const Name: String; Data:TStream):Byte;
var
	Idx : Integer;
	TempData : TMemoryStream;
	Buffer : PChar;
	OldSize : Integer;
begin
	Idx := IndexOfFile(Name);
	TempData := TMemoryStream.Create;
	Data.Position := 0;
	ZcompressStream(Data, TempData, zcDefault);
	Data.Position := 0;
	TempData.Position := 0;

	//if not found.. add new!
	if (Idx = -1) or (Files[Idx].Compressed_Len_Aligned < TempData.Size) then
	begin
		if (Idx = -1) then
		begin
			//A new file, a new entry
			Idx := FileCount; //Since idx is 0 based, kekeke ^.^
			Inc(FileCount);
			SetLength(Files, FileCount);
			Files[Idx].Name := Name;
			Files[Idx].Hash := NameHash(ExtractFileName(Name));
		end;
		//Replace the table XD  (its called recycle)
		FileData.Position := RealTableOffset;
		Files[Idx].Pos := RealTableOffset;  //YEP..RECYCLE..
	end else
	begin
		FileData.Position := Files[Idx].Pos;

		//Compare new compressed size with old one.
		//and update offset of table
		//if is equal of smaller than old one, just leave as old one, but leaves junks though
//		if (Files[Idx].Compressed_Len < TempData.Size) then
//		begin
//			RealTableOffset := RealTableOffset + (TempData.Size + (8 - (TempData.Size mod 8)) - Files[Idx].Compressed_Len_Aligned);
//		end;
	end;
	OldSize := Files[Idx].Compressed_Len_Aligned;
	Files[Idx].Compressed_Len := TempData.Size;
	Files[Idx].Compressed_Len_Aligned := Files[Idx].Compressed_Len;
	Inc(Files[Idx].Compressed_Len_Aligned, 8 - (Files[Idx].Compressed_Len_Aligned mod 8));
	Files[Idx].RealLen := Data.Size;
	Files[Idx].Flags := GRFFILE_FLAG_FILE; //UHM...
        Files[Idx].Deleted := False; //Even is soft delete, but not anymore!

	//Fill extra 0s
	GetMem(Buffer, Files[Idx].Compressed_Len_Aligned);
	FillChar(Buffer[Files[Idx].Compressed_Len], Files[Idx].Compressed_Len_Aligned - Files[Idx].Compressed_Len, 0);
	TempData.Read(Buffer^, Files[Idx].Compressed_Len);
	FileData.Write(Buffer^, Files[Idx].Compressed_Len_Aligned);
	//well...
	if (OldSize < TempData.Size) then
	begin
		RealTableOffset := FileData.Position; //Update offset of table
		TableOffset := RealTableOffset - GRF_HEADER_FULL_LEN;
	end;
	Data.Free;
	TempData.Free;
	FreeMem(Buffer);
	Modified := True; //Set to true to lock whole thing up.
end;
//------------------------------------------------------------------------------


//------------------------------------------------------------------------------
//	Purpose:
//		Wraper for previous AddData
//		This is use to load file instead stream
//
//------------------------------------------------------------------------------
function TGrf.AddData(const Name, Location:String):Byte;
var
	Data : TFileStream;
begin
	if not FileExists(Location) then
	begin
		Result := GRF_FILENOTFOUND;
		Exit;
	end;

	Data := TFileStream.Create(Location, fmShareExclusive);
	Result := AddData(Name, Data);
end;
//------------------------------------------------------------------------------


//------------------------------------------------------------------------------
//	Purpose:
//		A very simple function to replace a filename
//		GRF is locked up after using this function
//		Require SaveTable to Unlock
//
//------------------------------------------------------------------------------
function TGrf.Rename(const OldName, NewName:String):Byte;
var
	Idx : Integer;
begin
	Idx := IndexOfFile(OldName);
	if (Idx = -1) or (Files[Idx].Deleted) then
	begin
		Result := GRF_FILENOTFOUND;
	end else
	begin
		Files[Idx].Name := NewName;
		Modified := True;        //Locked up
	end;
end;
//------------------------------------------------------------------------------


//------------------------------------------------------------------------------
//	Purpose:
//		Soft delete by mark as Deleted
//	(Since we can't delete an item in array unless doing the minding loop)
//
//------------------------------------------------------------------------------
function TGrf.Delete(const Idx:Integer):Byte;
begin
	if (Idx > FileCount -1) or (idx < 0) then
	begin
		Result := GRF_STAKERANGEOUT;
	end else
	begin
		Files[Idx].Deleted := True;
		Modified := True;
	end;
end;
//------------------------------------------------------------------------------


//------------------------------------------------------------------------------
function TGrf.ExtractToStream(Idx:Integer;var Data:TMemoryStream):Byte;
var
	TempData : TMemoryStream;
begin
	if Modified then
	begin
		Result := GRF_FILECHANGED;
		Exit;
	end;
	if (Idx > FileCount -1) or (idx < 0) then
	begin
		Result := GRF_STAKERANGEOUT;
		Exit; //CANT FIND...it
	end;
	if not Boolean(Files[Idx].Flags and GRFFILE_FLAG_FILE)then Exit; //NO FOLDER ALLOWED..
	Result := GRF_SUCCESS;
	TempData := TMemoryStream.Create;
	FileData.Position := Files[Idx].Pos;
	TempData.CopyFrom(FileData, Files[Idx].Compressed_Len);
	TempData.Position:=0;
	ZDecompressStream(TempData, Data);
	Data.Position := 0;
	TempData.Clear;
	TempData.Free;
end;
//------------------------------------------------------------------------------


//------------------------------------------------------------------------------
function TGrf.ExtractToStream(Name:String;var Data:TMemoryStream):Byte;
var
	TempData : TMemoryStream;
	Idx: Integer;
begin
	if Modified then
	begin
		Result := GRF_FILECHANGED;
		Exit;
	end else
	begin
		Idx := IndexOfFile(Name);
		if Idx = -1 then
		begin
			Result := GRF_FILENOTFOUND;
		end else
		begin
			Result := ExtractToStream(Idx, Data);
		end;
	end;
end;
//------------------------------------------------------------------------------


//------------------------------------------------------------------------------
//	Purpose:
//		Extract file using index
//
//------------------------------------------------------------------------------
function TGrf.ExtractToChar(Idx:Integer;var Output:PChar):Byte;
var
	Data : TMemoryStream;
	Buffer:Pchar;
begin
	if Modified then
	begin
		Result := GRF_FILECHANGED;
		Exit;
	end;
	if (Idx > FileCount -1) or (idx < 0) then
	begin
		Result := GRF_STAKERANGEOUT;
		Exit; //CANT FIND...it
	end;
	if not Boolean(Files[Idx].Flags and GRFFILE_FLAG_FILE)then Exit; //uhm..folder?
	Result := GRF_SUCCESS;
        Data := TMemoryStream.Create;
	if (ExtractToStream(Idx, Data) <> GRF_SUCCESS) then
	begin
		Result := GRF_EXTRACTFAIL;
	end else
	begin
		GetMem(Output, Files[Idx].RealLen);
		Data.Read(Output^, Files[Idx].RealLen);
		Data.Free;
	end;
end;
//------------------------------------------------------------------------------


//------------------------------------------------------------------------------
//	Purpose:
//		And using filename
//
//------------------------------------------------------------------------------
function TGrf.ExtractToChar(Name:String;var Output:PChar):Byte;
var
	TempData, Data : TMemoryStream;
	Buffer:Pchar;
	Idx: Integer;
begin
	if Modified then
	begin
		Result := GRF_FILECHANGED;
		Exit;
	end;
	Idx := IndexOfFile(Name);
	if Idx = -1 then
	begin
		Result := GRF_FILENOTFOUND;
		Exit; //CANT FIND...it
	end;
	if not Boolean(Files[Idx].Flags and GRFFILE_FLAG_FILE)then Exit; //NO FOLDER ALLOWED..
	Result := ExtractToChar(Idx, Output);
end;
//------------------------------------------------------------------------------

//------------------------------------------------------------------------------
//	Purpose:
//		Extract data to file
//	Directory will be strip away leaves only filename and store at Location
//
//------------------------------------------------------------------------------
function TGrf.ExtractToFile(const Idx: Integer;const Location: String):Byte;
var
	TempData : TMemoryStream;
	Data : TFileStream;
begin
	if Modified then
	begin
		Result := GRF_FILECHANGED;
		Exit;
	end;
	if (Idx > FileCount -1) or (idx < 0) then
	begin
		Result := GRF_STAKERANGEOUT;
		Exit;
	end;
	if not Boolean(Files[Idx].Flags and GRFFILE_FLAG_FILE) then Exit; //NO FOLDER ALLOWED..
	Result := GRF_SUCCESS;
	TempData := TMemoryStream.Create;
	Data := TFileStream.Create(ExtractFilePath(Location) + ExtractFileName(Files[Idx].Name), fmCreate);
	FileData.Position := Files[Idx].Pos;
	TempData.CopyFrom(FileData, Files[Idx].Compressed_Len);
	TempData.Position:=0;
	ZDecompressStream(TempData, Data);
	Data.Position := 0;
	TempData.Clear;
	TempData.Free;
	Data.Free;
end;
//------------------------------------------------------------------------------


//------------------------------------------------------------------------------
//STATUS: not even started yet
function TGrf.ExtractToFile(const Name, Location: String):Byte;
var
	Idx : Integer;
begin
	if Modified then
	begin
		Result := GRF_FILECHANGED;
		Exit;
	end;
	Idx := IndexOfFile(Name);
	if Idx = -1 then
	begin
		Result := GRF_FILENOTFOUND;
	end else
	begin
		Result := ExtractToFile(Idx, Location);
	end;
end;
//------------------------------------------------------------------------------


//------------------------------------------------------------------------------
destructor TGrf.Destroy;
begin
	if assigned(FileData) then
	begin
		FileData.Free;
	end;
	SetLength(Files, 0);
	inherited;
end;
//------------------------------------------------------------------------------
end.
