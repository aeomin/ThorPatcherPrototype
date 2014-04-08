unit Global;
interface

uses
	Windows, Classes, List32,
	ConfigParser,
	PListParser,
	ace_lib,
	ass_lib,
	Grf_Lib,
	CommClient;
const
	//Base URL for main script
	BASEURL = 'http://oceanro.com/patcher/';
	//All other files should be in here (included patch files)
	FILEURL = 'http://oceanro.com/pdata/';

	AceFile = 'OceanRo.ace';   //main ace file
	GrfFile = 'oro.dat';       //main patch file
	ClientFile = 'oro.exe';

	//Start/finished download (Unused Default)
	PS = 0;
	//main
	PMain = 1;
	//Core files (patcher,client)
	PCFILE = 2;
	//Patch List
	PList = 3;
	//File
	PFile = 4;

	CPatcher = 0;
	CClient = 1;

	SError = 0;
	SSuccess = 1;

	procedure Status(Msg:String='');
	procedure MainSwitch(Id:Byte;Msg:String='');
	procedure Split(const Splitter,Src:String;var Dsc:TStringList;const Append:Boolean=false);
	function Q_PosStr(const FindString, SourceString: string; StartPos: Integer): Integer;
	function CToggle(const Str:String;Default:Boolean):Boolean;
	function IsInt(AStr: string): Boolean;
	function LockedFile(FileName: string): Boolean;
type

	TParameter = class
		ID : Integer;
                aType:Byte;
		aString : string;
		aInt : Integer;
		aData : TMemoryStream;
	end;

	TCallBack = procedure(
		const
			aParameter : TParameter
		);


var
	ThreadList : TIntList32;
	PatchList : TPListParser;
	Config : TConfig;
	CurrentID : Integer = 0; //Current id of patch
	Ace : TAce;
	Grf : TGrf;
	LoadedGrf : Boolean = False;
	LockedDown : Boolean = True; //program cannot close when set to true
	CanStart : Boolean = False;
	AppPath : String;
	AppFull : String;    //full address...
	AppName : String = 'OceanRo.exe';
	CriticalSection: TRTLCriticalSection;
	HashClient : TInterClient;
implementation

uses
	SysUtils,
	Main;
procedure Status(Msg:String='');
begin
	MainFrm.Status.Caption := Msg;
end;

procedure MainSwitch(Id:Byte;Msg:String='');
begin
	case Id of
		// Fatal Error, patcher have to stop immediately
		SError: begin
			MainFrm.ProgressBar.Visible := False;
			MainFrm.CancelBTN.Visible := False;
			//Set to visible, visible didn't mean you can click
			MainFrm.StartBTN.Visible := True;
			MainFrm.ExitBTN.Visible := True;
			MainFrm.StartBTN.Enabled := False;
			MainFrm.ExitBTN.Enabled := True;
			MainFrm.Status.Caption := Msg;
			LockedDown := False;
			CanStart := False;
		end;
		SSuccess: begin
			MainFrm.ProgressBar.Visible := False;
			MainFrm.CancelBTN.Visible := False;
			MainFrm.StartBTN.Visible := True;
			MainFrm.ExitBTN.Visible := True;
			MainFrm.StartBTN.Enabled := True;
			MainFrm.ExitBTN.Enabled := True;
			MainFrm.Status.Caption := Msg;
			LockedDown := False;
			CanStart := True;
		end;
	end;
end;

//Split data into TStringList
procedure Split(const Splitter,Src:String;var Dsc:TStringList;const Append:Boolean=false);
var
	Idx, OldIdx : Integer;
begin
	//Clean/create whatever needed to done
	if not assigned(Dsc) then
		Dsc := TStringList.Create
	else if not Append then Dsc.Clear;
	if (Splitter = '') or (Src = '') then
		Exit;
	Idx := 1;
	while True do
	begin
		OldIdx := Idx;
		Idx := Q_PosStr(Splitter, Src, Idx);
		if Idx = 0 then
			Break;
		Dsc.Add(Copy(Src, OldIdx, Idx - OldIdx + 1));
		Inc(Idx);
	end;
end;

// return 0 if not found, fist index was 1
function Q_PosStr(const FindString, SourceString: string; StartPos: Integer): Integer;
asm
       PUSH    ESI
       PUSH    EDI
       PUSH    EBX
       PUSH    EDX
       TEST    EAX,EAX
       JE      @@qt
       TEST    EDX,EDX
       JE      @@qt0
       MOV     ESI,EAX
       MOV     EDI,EDX
       MOV     EAX,[EAX-4]
       MOV     EDX,[EDX-4]
       DEC     EAX
       SUB     EDX,EAX
       DEC     ECX
       SUB     EDX,ECX
       JNG     @@qt0
       XCHG    EAX,EDX
       ADD     EDI,ECX
       MOV     ECX,EAX
       JMP     @@nx
@@fr:   INC     EDI
       DEC     ECX
       JE      @@qt0
@@nx:   MOV     EBX,EDX
       MOV     AL,BYTE PTR [ESI]
@@lp1:  CMP     AL,BYTE PTR [EDI]
       JE      @@uu
       INC     EDI
       DEC     ECX
       JE      @@qt0
       CMP     AL,BYTE PTR [EDI]
       JE      @@uu
       INC     EDI
       DEC     ECX
       JE      @@qt0
       CMP     AL,BYTE PTR [EDI]
       JE      @@uu
       INC     EDI
       DEC     ECX
       JE      @@qt0
       CMP     AL,BYTE PTR [EDI]
       JE      @@uu
       INC     EDI
       DEC     ECX
       JNE     @@lp1
@@qt0:  XOR     EAX,EAX
@@qt:   POP     ECX
       POP     EBX
       POP     EDI
       POP     ESI
       RET
@@uu:   TEST    EDX,EDX
       JE      @@fd
@@lp2:  MOV     AL,BYTE PTR [ESI+EBX]
       CMP     AL,BYTE PTR [EDI+EBX]
       JNE     @@fr
       DEC     EBX
       JE      @@fd
       MOV     AL,BYTE PTR [ESI+EBX]
       CMP     AL,BYTE PTR [EDI+EBX]
       JNE     @@fr
       DEC     EBX
       JE      @@fd
       MOV     AL,BYTE PTR [ESI+EBX]
       CMP     AL,BYTE PTR [EDI+EBX]
       JNE     @@fr
       DEC     EBX
       JE      @@fd
       MOV     AL,BYTE PTR [ESI+EBX]
       CMP     AL,BYTE PTR [EDI+EBX]
       JNE     @@fr
       DEC     EBX
       JNE     @@lp2
@@fd:   LEA     EAX,[EDI+1]
       SUB     EAX,[ESP]
       POP     ECX
       POP     EBX
       POP     EDI
       POP     ESI
end;

//Customized String to boolean
function CToggle(const Str:String;Default:Boolean):Boolean;
begin
	if LowerCase(Str)= 'allow' then
		Result := True
	else
		Result := False
end;

function IsInt(AStr: string): Boolean;
var
	Value, E: Integer;
begin
	Val(AStr, Value, E);
	Result := (E = 0);
end;

function LockedFile(FileName: string): Boolean;
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
end.