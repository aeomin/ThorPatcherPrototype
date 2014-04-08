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
	Windows,
	SysUtils,
	Classes,
	Math,
	GRFTypes,
	ZlibEx,
	HashList;
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
		FileData       : TFileStream;
		fTableLoaded    : Boolean;
		fModified       : Boolean;
		CompressedTableSize : Integer;
		RealTableSize       : Integer;
		fRealTotalSize : Int64;     //The actual data size, used to calculate fragment waste
		function LockedFile(FileName: string): Boolean;
		function NameHash(Name : String):Cardinal;
		function GetFragmentRatio:Byte;
		procedure CreateGRF(const Filename:String);
	public
//		Files           : TGrfFiles;
		Files           : THashClass;
		AllowCrypt      : Boolean;
		TableOffset     : Cardinal;
		RealTableOffset : Cardinal;
		Seeds           : Integer;
		FileCount       : Integer;
		Version         : Integer;

		property Modified   : Boolean read fModified;
		property FragmentRatio : Byte read GetFragmentRatio;
		property TableLoaded : Boolean read fTableLoaded;
		function LoadGrf(Filename:String):Byte;
		function LoadTable:Byte;
		function SaveTable:Byte;
		procedure ReloadTable;
//		function IndexOfFile(Name: String;IgnoreDelete:Boolean=False):Integer;
		function AddData(const Name: String; Data:TStream):Byte; overload;
		function AddDataC(const Name: String; Data:TStream):Byte; overload;
		function AddData(const Name, Location:String):Byte; overload;
		function Rename(const OldName, NewName:String):Byte; overload;
		function Delete(Leaf : PLeaf):Byte; overload;
		function ExtractToStream(Leaf : PLeaf;var Data:TMemoryStream):Byte; overload;
		function ExtractToStream(Name:String;var Data:TMemoryStream):Byte; overload;
		function ExtractToChar(Leaf : PLeaf;var Output:PChar):Byte; overload;
		function ExtractToChar(Name:String;var Output:PChar):Byte; overload;
		function ExtractToFile(Leaf : PLeaf; const Location: String):Byte; overload;
		function ExtractToFile(const Name, Location: String):Byte; overload;
		constructor Create;
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
		if Buffer[0] = #1 then  //Allow encryption
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
	fTableLoaded := False;
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
        TableOffset := 0;
	FileData.Write(GRF_ZERO, 4);      //Table offset... Zero first =p
	FileData.Write(GRF_ZERO, 4);      //Seeds
	FileData.Write(GRF_SEVEN, 4);       //7 for file count
	FileData.Write(GRF_VER, 4);      //GRF ver

	Temp  := TMemoryStream.Create;
	Table := TMemoryStream.Create;
	ZCompressStream(Temp, Table, zcMax);
	Temp.Free;
	Table.Position := 0;

	GetMem(Buffer, Table.Size);
	Table.Read(Buffer^, Table.Size);
	RealTableOffset := FileData.Position;
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
	Leaf  : PLeaf;
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
//	SetLength(Files, FileCount);  //How many files?
	Files.Clear;
	OffSet := 0;
	//Current position of TableData is 0
	for Idx := 0 to FileCount - 1 do
	begin
		TableData.Position := Offset;
		//PERFECT..since stream will stop at 0x00 so no worry..
		GetMem(Buffer, 255);
		TableData.Read(Buffer^, 255);
		Inc(Offset, StrLen(Buffer) +1 ); //Add string length to offset, +1 for zero terminate
		Leaf := Files.Add(Buffer);
		//More INFORMATIONS!!
		Leaf.Name := Buffer;
		Leaf.Hash := NameHash(ExtractFileName(Buffer));
		FreeMem(Buffer);
		TableData.Position := Offset; //UPDATE
		TableData.Read(Leaf.Compressed_Len, 4);
		TableData.Read(Leaf.Compressed_Len_Aligned, 4);
		TableData.Read(Leaf.RealLen, 4);
		TableData.Read(Leaf.Flags, 1);   //Flags is only one byte
		TableData.Read(Leaf.Pos, 4);
		Inc(Leaf.Pos, GRF_HEADER_FULL_LEN);  //Need add GRF_HEADER_FULL_LEN
		Inc(Offset, 17);    //0x11
		Leaf.Deleted := False;
	end;
	fTableLoaded := True;
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
	Idx, Tmp : Cardinal;
	Buffer : PChar;
	Recur  : PRecur;
	Leaf   : PLeaf;
begin
	if not fModified then
	begin
		Result := GRF_NOTMODIFIED;
		Exit;
	end;
	Status('Repacking resource files...');
	LockedDown := True;
	MainFrm.CancelBTN.Enabled := False;
	MainFrm.ProgressBar.TotalParts := FileCount;
	MainFrm.ProgressBar.PartsComplete := 0;
	Result := GRF_SUCCESS;
	TableData := TMemoryStream.Create;
	TempData  := TMemoryStream.Create;
	TableData.Position := 0;    //Reset Offset to 0
	New(Recur);
	Files.RecurReady(Recur);
	//Generate Table
	for Idx := 0 to FileCount - 1 do
	begin
		Leaf := Files.RecurNext(Recur);
		if (Leaf = nil) or Leaf.Deleted then
		begin
			MainFrm.ProgressBar.PartsComplete := MainFrm.ProgressBar.PartsComplete + 1;
			Continue; //Soft Deletion
		end;
//		GetMem(Buffer, StrLen(PChar(Files[Idx].Name)));
		Buffer := PChar(Leaf.Name + #0);
		TableData.Write(Buffer^, StrLen(Buffer) + 1);
//		FreeMem(Buffer);
		TableData.Write(Leaf.Compressed_Len, 4);
		TableData.Write(Leaf.Compressed_Len_Aligned, 4);
		TableData.Write(Leaf.RealLen, 4);
		TableData.Write(Leaf.Flags, 1);   //Flags is only one byte
		Dec(Leaf.Pos, GRF_HEADER_FULL_LEN); //Subtract
		TableData.Write(Leaf.Pos, 4);
		Inc(Leaf.Pos, GRF_HEADER_FULL_LEN); // Put it back
		MainFrm.ProgressBar.PartsComplete := MainFrm.ProgressBar.PartsComplete + 1;
	end;
	Dispose(Recur);
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
	CompressedTableSize := TempData.Size;
	FileData.Write(CompressedTableSize, 4);
	RealTableSize := TableData.Size;
	FileData.Write(RealTableSize, 4);
	FileData.Write(Buffer^, TempData.Size);
	FileData.Size := RealTableOffset + TempData.Size + 8;  //add 8 for those 2 integers
	FreeMem(Buffer);

	TableData.Clear;
	TableData.Free;

	TempData.Clear;
	TempData.Free;
	FileData.Position := 0;
	fModified := False; //Unlock
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
//	Calculate fragment ratio in percentage.
//------------------------------------------------------------------------------
function TGrf.GetFragmentRatio:Byte;
var
	Index  : Cardinal;
	Size   : Int64;
	Recur  : PRecur;
	Leaf   : PLeaf;
begin
	Result := 0;
	// First get size of header and table
	// 8 for 2 int used to store size of table
	fRealTotalSize := GRF_Header_Full_Len + CompressedTableSize + 8;
	New(Recur);
	Files.RecurReady(Recur);
	for Index := FileCount - 1 downto 0 do
	begin
		Leaf := Files.RecurNext(Recur);
		if (Leaf = nil) or Leaf.Deleted then
			Continue;
		Inc(fRealTotalSize, Leaf.Compressed_Len_Aligned);
	end;
	Dispose(Recur);
	Size := FileData.Size;
	if Size > fRealTotalSize then
	begin
		Result := 100-Trunc(fRealTotalSize/Size*100);
	end;
end;{GetFragmentRatio}
//------------------------------------------------------------------------------


//------------------------------------------------------------------------------
//	Purpose:
//		Get index of an file
//           WANTED : HASH TABLE
//------------------------------------------------------------------------------
//function TGrf.IndexOfFile(Name: String;IgnoreDelete:Boolean=False):Integer;
//var
//	Idx : Integer;
//	Hash : Cardinal;
//begin
//	Result := -1;
//	Hash := NameHash(ExtractFileName(Name));
//	for Idx := Length(Files) - 1 downto 0 do
//	begin
//		if (Files[Idx].Hash = Hash)and(Files[Idx].Name = Name) then
//		begin
//			if (not Files[Idx].Deleted) or (IgnoreDelete) then
//			Result := Idx;
//			Break;
//		end;
//	end;
//end;
//------------------------------------------------------------------------------


//------------------------------------------------------------------------------
//	Purpose:
//		Add data to GRF, GRF is locked up after using this function.
//	Use SaveTable to flush up and unlock.
//
//------------------------------------------------------------------------------
function TGrf.AddData(const Name: String; Data:TStream):Byte;
var
	TempData : TMemoryStream;
	Buffer : PChar;
	OldSize : Integer;
	Leaf   : PLeaf;
begin
	Result := GRF_SUCCESS;
	Leaf := Files.GetObject(Name);
	TempData := TMemoryStream.Create;
	Data.Position := 0;
	ZcompressStream(Data, TempData, zcDefault);
	Data.Position := 0;
	TempData.Position := 0;

	//if not found.. add new!
	if (Leaf = nil) or (Leaf.Compressed_Len_Aligned < TempData.Size) then
	begin
		if (Leaf = nil) then
		begin
			//A new file, a new entry
//			Idx := FileCount; //Since idx is 0 based, kekeke ^.^
			Inc(FileCount);
//			SetLength(Files, FileCount);
			Leaf := Files.Add(Name);
			Leaf.Compressed_Len := 0;
			Leaf.Compressed_Len_Aligned := 0;
			Leaf.RealLen := 0;
			Leaf.Flags := 0;
//			Files[Idx].Name := Name;
//			Leaf.Hash := NameHash(ExtractFileName(Name));
		end;
		//Replace the table XD  (its called recycle)
		FileData.Position := RealTableOffset;
		Leaf.Pos := RealTableOffset;  //YEP..RECYCLE..
	end else
	begin
		FileData.Position := Leaf.Pos;

		//Compare new compressed size with old one.
		//and update offset of table
		//if is equal of smaller than old one, just leave as old one, but leaves junks though
//		if (Files[Idx].Compressed_Len < TempData.Size) then
//		begin
//			RealTableOffset := RealTableOffset + (TempData.Size + (8 - (TempData.Size mod 8)) - Files[Idx].Compressed_Len_Aligned);
//		end;
	end;
	OldSize := Leaf.Compressed_Len_Aligned;
	Leaf.Compressed_Len := TempData.Size;
	Leaf.Compressed_Len_Aligned := Leaf.Compressed_Len;
	Inc(Leaf.Compressed_Len_Aligned, 8 - (Leaf.Compressed_Len_Aligned mod 8));
	Leaf.RealLen := Data.Size;
	Leaf.Flags := GRFFILE_FLAG_FILE; //UHM...
	Leaf.Deleted := False; //Even is deleted, but not anymore!

	//Fill extra 0s
	GetMem(Buffer, Leaf.Compressed_Len_Aligned);
	FillChar(Buffer[Leaf.Compressed_Len], Leaf.Compressed_Len_Aligned - Leaf.Compressed_Len, 0);
	TempData.Read(Buffer^, Leaf.Compressed_Len);
	FileData.Write(Buffer^, Leaf.Compressed_Len_Aligned);
	//well...
	if (OldSize < TempData.Size) then
	begin
		RealTableOffset := FileData.Position; //Update offset of table
		TableOffset := RealTableOffset - GRF_HEADER_FULL_LEN;
	end;
//	Data.Free;
	TempData.Free;
	FreeMem(Buffer);
	fModified := True; //Set to true to lock whole thing up.
end;
//------------------------------------------------------------------------------


//------------------------------------------------------------------------------
// Same as above except data does not compress (ideal for patcher)
//------------------------------------------------------------------------------
function TGrf.AddDataC(const Name: String; Data:TStream):Byte;
var

	Buffer : PChar;
	OldSize : Integer;
	Leaf   : PLeaf;
begin
	Result := GRF_SUCCESS;
	Leaf := Files.GetObject(Name);
	Data.Position := 0;

	//if not found.. add new!
	if (Leaf = nil) or (Leaf.Compressed_Len_Aligned < Data.Size) then
	begin
		if (Leaf = nil) then
		begin
			//A new file, a new entry
//			Idx := FileCount; //Since idx is 0 based, kekeke ^.^
			Inc(FileCount);
//			SetLength(Files, FileCount);
			Leaf := Files.Add(Name);
			Leaf.Compressed_Len := 0;
			Leaf.Compressed_Len_Aligned := 0;
			Leaf.RealLen := 0;
			Leaf.Flags := 0;
//			Files[Idx].Name := Name;
//			Leaf.Hash := NameHash(ExtractFileName(Name));
		end;
		//Replace the table XD  (its called recycle)
		FileData.Position := RealTableOffset;
		Leaf.Pos := RealTableOffset;  //YEP..RECYCLE..
	end else
	begin
		FileData.Position := Leaf.Pos;

		//Compare new compressed size with old one.
		//and update offset of table
		//if is equal of smaller than old one, just leave as old one, but leaves junks though
//		if (Files[Idx].Compressed_Len < TempData.Size) then
//		begin
//			RealTableOffset := RealTableOffset + (TempData.Size + (8 - (TempData.Size mod 8)) - Files[Idx].Compressed_Len_Aligned);
//		end;
	end;
	OldSize := Leaf.Compressed_Len_Aligned;
	Leaf.Compressed_Len := Data.Size;
	Leaf.Compressed_Len_Aligned := Leaf.Compressed_Len;
	Inc(Leaf.Compressed_Len_Aligned, 8 - (Leaf.Compressed_Len_Aligned mod 8));
	Leaf.RealLen := Data.Size;
	Leaf.Flags := GRFFILE_FLAG_FILE; //UHM...
	Leaf.Deleted := False; //Even is deleted, but not anymore!

	//Fill extra 0s
	GetMem(Buffer, Leaf.Compressed_Len_Aligned);
	FillChar(Buffer[Leaf.Compressed_Len], Leaf.Compressed_Len_Aligned - Leaf.Compressed_Len, 0);
	Data.Read(Buffer^, Leaf.Compressed_Len);
	FileData.Write(Buffer^, Leaf.Compressed_Len_Aligned);
	//well...
	if (OldSize < Data.Size) then
	begin
		RealTableOffset := FileData.Position; //Update offset of table
		TableOffset := RealTableOffset - GRF_HEADER_FULL_LEN;
	end;
//	Data.Free;
	FreeMem(Buffer);
	fModified := True; //Set to true to lock whole thing up.
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
	Data.Free;
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
//	Idx : Integer;
	Leaf : PLeaf;
begin
	Result := GRF_SUCCESS;
//	Idx := IndexOfFile(OldName);
	Leaf := Files.GetObject(OldName);
	if (Leaf = nil) or (Leaf.Deleted) then
	begin
		Result := GRF_FILENOTFOUND;
	end else
	begin
		Leaf.Name := NewName;
		fModified := True;        //Locked up
	end;
end;
//------------------------------------------------------------------------------


//------------------------------------------------------------------------------
//	Purpose:
//		Soft delete by mark as Deleted
//	(Since we can't delete an item in array unless doing the minding loop)
//
//------------------------------------------------------------------------------
function TGrf.Delete(Leaf : PLeaf):Byte;
begin
	Result := GRF_SUCCESS;
	if (Leaf = nil) then
	begin
		Result := GRF_STAKERANGEOUT;
	end else
	begin
		Leaf.Deleted := True;
		fModified := True;
	end;
end;
//------------------------------------------------------------------------------


//------------------------------------------------------------------------------
function TGrf.ExtractToStream(Leaf : PLeaf;var Data:TMemoryStream):Byte;
var
	TempData : TMemoryStream;
//	Leaf : PLeaf;
begin
	Result := GRF_SUCCESS;
	if fModified then
	begin
		Result := GRF_FILECHANGED;
		Exit;
	end;
//	Leaf := Files.RecurNext(Recur);
	if Leaf = nil then
	begin
		Result := GRF_STAKERANGEOUT;
		Exit; //CANT FIND...it
	end;
	if not Boolean(Leaf.Flags and GRFFILE_FLAG_FILE) then
	begin
		Result := GRF_FAILED;
		Exit; //NO FOLDER ALLOWED..
	end;
	TempData := TMemoryStream.Create;
	FileData.Position := Leaf.Pos;
	TempData.CopyFrom(FileData, Leaf.Compressed_Len);

	TempData.Position := 0;
	Data.Position := 0;
	ZDecompressStream(TempData, Data);
	Data.Position := 0;
	TempData.Clear;
	TempData.Free;
end;
//------------------------------------------------------------------------------


//------------------------------------------------------------------------------
function TGrf.ExtractToStream(Name:String;var Data:TMemoryStream):Byte;
var
	Leaf : PLeaf;
begin
	if fModified then
	begin
		Result := GRF_FILECHANGED;
		Exit;
	end else
	begin
		Leaf := Files.GetObject(Name);
		if Leaf = nil then
		begin
			Result := GRF_FILENOTFOUND;
		end else
		begin
			Result := ExtractToStream(Leaf, Data);
		end;
	end;
end;
//------------------------------------------------------------------------------


//------------------------------------------------------------------------------
//	Purpose:
//		Extract file using index
//
//------------------------------------------------------------------------------
function TGrf.ExtractToChar(Leaf : PLeaf;var Output:PChar):Byte;
var
	Data : TMemoryStream;
begin
	Result := GRF_SUCCESS;
	if fModified then
	begin
		Result := GRF_FILECHANGED;
		Exit;
	end;
	if (Leaf = nil) then
	begin
		Result := GRF_STAKERANGEOUT;
		Exit; //CANT FIND...it
	end;
	if not Boolean(Leaf.Flags and GRFFILE_FLAG_FILE)then
		Exit; //uhm..folder?
	Data := TMemoryStream.Create;
	if (ExtractToStream(Leaf, Data) <> GRF_SUCCESS) then
	begin
		Result := GRF_EXTRACTFAIL;
	end else
	begin
		GetMem(Output, Leaf.RealLen);
		Data.Read(Output^, Leaf.RealLen);
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
	Leaf  : PLeaf;
begin
	Result := GRF_SUCCESS;
	if fModified then
	begin
		Result := GRF_FILECHANGED;
		Exit;
	end;
	Leaf := Files.GetObject(Name);
	if Leaf = nil then
	begin
		Result := GRF_FILENOTFOUND;
		Exit; //CANT FIND...it
	end;
	if Boolean(Leaf.Flags and GRFFILE_FLAG_FILE)then
	begin//NO FOLDER ALLOWED..
		Result := ExtractToChar(Leaf, Output);
	end else
	begin
		Result := GRF_FAILED;
	end;
end;
//------------------------------------------------------------------------------

//------------------------------------------------------------------------------
//	Purpose:
//		Extract data to file
//	Directory will be strip away leaves only filename and store at Location
//
//------------------------------------------------------------------------------
function TGrf.ExtractToFile(Leaf : PLeaf;const Location: String):Byte;
var
	TempData : TMemoryStream;
	Data : TFileStream;
begin
	Result := GRF_SUCCESS;
	if fModified then
	begin
		Result := GRF_FILECHANGED;
		Exit;
	end;
	if Leaf = nil then
	begin
		Result := GRF_STAKERANGEOUT;
		Exit;
	end;
	if Boolean(Leaf.Flags and GRFFILE_FLAG_FILE) then
	begin  //NO FOLDER ALLOWED..
		TempData := TMemoryStream.Create;
		Data := TFileStream.Create(ExtractFilePath(Location) + ExtractFileName(Leaf.Name), fmCreate);
		FileData.Position := Leaf.Pos;
		TempData.CopyFrom(FileData, Leaf.Compressed_Len);
		TempData.Position:=0;
		ZDecompressStream(TempData, Data);
		Data.Position := 0;
		TempData.Clear;
		TempData.Free;
		Data.Free;
	end else
	begin
		Result := GRF_FAILED;
	end;
end;
//------------------------------------------------------------------------------


//------------------------------------------------------------------------------
//STATUS: not even started yet
function TGrf.ExtractToFile(const Name, Location: String):Byte;
var
	Leaf : PLeaf;
begin
	if fModified then
	begin
		Result := GRF_FILECHANGED;
		Exit;
	end;
	Leaf := Files.GetObject(Name);
	if Leaf = nil then
	begin
		Result := GRF_FILENOTFOUND;
	end else
	begin
		Result := ExtractToFile(Leaf, Location);
	end;
end;
//------------------------------------------------------------------------------


constructor TGrf.Create;
begin
	Files := THashClass.Create(1024);
end;

//------------------------------------------------------------------------------
destructor TGrf.Destroy;
//var
//	Index : Cardinal;
begin
	if assigned(FileData) then
	begin
		FileData.Free;
	end;
//	for Index := FileCount -1 downto 0 do
//	begin
//		Files[Index];
//	end;
	Files.Free;
	inherited;
end;
//------------------------------------------------------------------------------
end.
