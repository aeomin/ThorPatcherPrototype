Unit ass_lib;
{
	`.
       `. ..                                     `.
      `.  `..      `..       `..   `... `.. `..    `.. `..
     `..   `..   `.   `..  `..  `.. `..  `.  `..`.. `..  `..
    `...... `.. `..... `..`..    `..`..  `.  `..`.. `..  `..
   `..       `..`.         `..  `.. `..  `.  `..`.. `..  `..
  `..         `.. `....      `..   `...  `.  `..`..`...  `..
			  ASS CORE
	      AEOMIN SIMPLE STRUCTURED FORMATE
		 COPYRIGHT 2007 AEOMIN DEV
About this Structure:
Sealed after make file.
After seal, the file is no longer able to modify
(Unless hex/Destroy code)
There's no index table.
USE ONLY FOR WRITE/LOOPING READ.
}
interface

uses
	Windows,dialogs, SysUtils, Classes, ZlibEx;

const
	ASS_Header = 'ASSF (C) 2007 Aeomin DEV';
	ASS_Header_Len = Length(ASS_Header);
	ASS_FOOTER = 'SEALED!';
	ASS_FOOTER_Len = Length(ASS_FOOTER);

	ASS_SUCCESS = 0;
	ASS_FILELOCKED = 1;
	ASS_INVALID = 2;
	ASS_INVALIDTYPE = 3;
	ASS_ALREADYSEALED = 4;
	ASS_FILENOTFOUND = 5;

	ASST_GRF = 1;
	ASST_FILE = 2;

type
TAss = class
	private
		fSealed : Boolean;
		fVersion : Word;
		FileData : TFileStream;
		function LockedFile(FileName: string): Boolean;
	public
		DataType : Byte;
		FileCount : Integer;
		function LoadAss(Filename:String):Byte;
		function CreateAss(Filename:String;aDataType:Byte):Byte;
		procedure CounterReset;
		function AddData(Name:PChar;InStream: TStream):Byte; overload;
		function AddData(Name:PChar;Location:String):Byte; overload;
		function ExtractData(var Filename:String;var OutStream: TMemoryStream):Byte;
		function ExtractDataC(var Filename:String;var OutStream: TMemoryStream):Byte;
		function Seal:Byte;
		destructor Destroy();override;
end;

implementation

var
	ZERO : Byte = 0;   //Thats the best i can do..
	Ver  : Word = $10;
function TAss.LockedFile(FileName: string): Boolean;
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
//
//
//------------------------------------------------------------------------------
function TAss.LoadAss(Filename:String):Byte;
var
	Buffer : PChar;
begin
	Result := ASS_SUCCESS;
	if LockedFile(Filename) then
	begin
		Result := ASS_FILELOCKED;
		Exit;
	end;
	FileData := TFileStream.Create(Filename, fmOpenReadWrite or fmShareDenyWrite);
	FileData.Seek(0, soFromBeginning);
	
	GetMem(Buffer, ASS_Header_Len);
	FileData.Read(Buffer^, ASS_Header_Len);
	if Copy(Buffer, 0, ASS_Header_Len) <> ASS_Header then
	begin
		Result := ASS_INVALID;
		FreeMem(Buffer);   //Free up anyways
		Exit;
	end;
	FreeMem(Buffer);
	FileData.Read(DataType, 1);
	if (DataType < ASST_GRF) and (DataType > ASST_FILE)then
	begin
		Result := ASS_INVALIDTYPE;
		Exit;
	end;
	FileData.Read(FileCount, 4);
	FileData.Read(fVersion,  2);
	FileData.Seek(-ASS_FOOTER_Len, soFromEnd);
	GetMem(Buffer, ASS_FOOTER_Len);
	FileData.Read(Buffer^, ASS_FOOTER_Len);
	if Copy(Buffer, 0, ASS_FOOTER_Len) = ASS_FOOTER then
		fSealed := True;
	FreeMem(Buffer);
end;
//------------------------------------------------------------------------------


//------------------------------------------------------------------------------
function TAss.CreateAss(Filename:String;aDataType:Byte):Byte;
begin
	Result := ASS_SUCCESS;
	FileData := TFileStream.Create(Filename, fmCreate);
	FileData.Seek(0, soFromBeginning);
	FileData.Write(ASS_HEADER, ASS_HEADER_Len);    //Add Header
	FileData.Write(aDataType, 1);
	FileData.Write(ZERO, 4);                       //FileCount
	FileData.Write(Ver, 2);
end;
//------------------------------------------------------------------------------


//------------------------------------------------------------------------------
procedure TAss.CounterReset;
begin
	FileData.Seek(ASS_HEADER_Len + 5, soFromBeginning);
end;
//------------------------------------------------------------------------------


//------------------------------------------------------------------------------
function TAss.AddData(Name:PChar;InStream: TStream):Byte;
var
	Data     : TMemoryStream;
	Size     : Cardinal;
	RealSize : Cardinal;
	NameSize : byte;
begin
	if fSealed then
		Result := ASS_ALREADYSEALED
	else begin
		Data := TMemoryStream.Create;
		InStream.Position := 0;
		ZCompressStream(InStream, Data, zcMax);  //MAX!!!
		InStream.Position := 0;
		Data.Position := 0;
		FileData.Seek(ASS_HEADER_Len + 1, soFromBeginning);  //Change filecount
		Inc(FileCount);
		FileData.Write(FileCount, 4);
		FileData.Seek(0, soFromEnd);   //Append
		Size := Data.Size;
		FileData.Write(Size, 4);
		RealSize := InStream.Size;
		FileData.Write(RealSize, 4);
		NameSize := StrLen(Name);
		FileData.Write(NameSize, 1);
		FileData.Write(Name^, NameSize);
		FileData.CopyFrom(Data, Size);
		Data.Clear;
		Data.Free;
		Result := ASS_SUCCESS;
	end;
end;
//------------------------------------------------------------------------------


function TAss.AddData(Name:PChar;Location:String):Byte;
var
	Data : TFileStream;
begin
	if not FileExists(Location) then
	begin
		Result := ASS_FILENOTFOUND;
		Exit;
	end;

	Data := TFileStream.Create(Location, fmShareExclusive);
	Result := AddData(Name, Data);
	Data.Free;
end;


//------------------------------------------------------------------------------
function TAss.ExtractData(var Filename:String;var OutStream: TMemoryStream):Byte;
var
	Size : Cardinal;
	RealSize : Cardinal;
	NameSize : Byte;
	Data : TMemoryStream;
	Buffer : pChar;
begin
//	if not fSealed then
	Result := ASS_SUCCESS;
	FileData.Read(Size, 4);   //Get size..
	FileData.Read(RealSize, 4);
	FileData.Read(NameSize, 1);
	GetMem(Buffer, NameSize);
	FileData.Read(Buffer^, NameSize);
	FileName := Copy(Buffer, 0, NameSize);
	FreeMem(Buffer);
	Data := TMemoryStream.Create;

	GetMem(Buffer, Size);
	FileData.Read(Buffer^, Size);
	Data.Write(Buffer^, Size);
	FreeMem(Buffer);

	Data.Position := 0;
	OutStream.Position := 0;
	ZDecompressStream(Data, OutStream);
	OutStream.Position := 0;
	Data.Clear;
	Data.Free;
end;
//------------------------------------------------------------------------------


//------------------------------------------------------------------------------
// Same as above except not decompress..
//------------------------------------------------------------------------------
function TAss.ExtractDataC(var Filename:String;var OutStream: TMemoryStream):Byte;
var
	Size : Cardinal;
	RealSize : Cardinal;
	NameSize : Byte;
	Buffer : pChar;
begin
//	if not fSealed then
	Result := ASS_SUCCESS;
	FileData.Read(Size, 4);   //Get size..
	FileData.Read(RealSize, 4);
	FileData.Read(NameSize, 1);
	GetMem(Buffer, NameSize);
	FileData.Read(Buffer^, NameSize);
	FileName := Copy(Buffer, 0, NameSize);
	FreeMem(Buffer);

	GetMem(Buffer, Size);
	FileData.Read(Buffer^, Size);
	OutStream.Position := 0;
	OutStream.Write(Buffer^, Size);
	FreeMem(Buffer);

	OutStream.Position := 0;
end;
//------------------------------------------------------------------------------


//------------------------------------------------------------------------------
function TAss.Seal:Byte;
begin
	Result := ASS_SUCCESS;
	if fSealed then
		Result := ASS_ALREADYSEALED
	else begin
		FileData.Seek(0, soFromEnd);
		FileData.Write(ASS_FOOTER, ASS_FOOTER_Len);
		fSealed := True;
	end;
end;
//------------------------------------------------------------------------------


//------------------------------------------------------------------------------
destructor TAss.Destroy();
begin
	if assigned(FileData) then
	begin
		FileData.Free;
	end;
	inherited;
end;
//------------------------------------------------------------------------------
end.
