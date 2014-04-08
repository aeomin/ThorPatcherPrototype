unit Unit1;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, ComCtrls, StdCtrls, FileCtrl, ass_lib;

type
  TForm1 = class(TForm)
    InputDir: TEdit;
    Button1: TButton;
    Label1: TLabel;
    opFile: TRadioButton;
    RadioButton1: TRadioButton;
    OutFile: TEdit;
    Label2: TLabel;
    Button2: TButton;
    SaveDialog: TSaveDialog;
    Button3: TButton;
    Progress: TProgressBar;
    Button4: TButton;
    procedure Button4Click(Sender: TObject);
    procedure Button3Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure SerchFile(Dir:String);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  Form1: TForm1;
  FileList : TStringList;
implementation

{$R *.dfm}

procedure TForm1.Button1Click(Sender: TObject);
var
	ReadDir : String;
begin
	if (SelectDirectory('Select the folder to pack', '', ReadDir)) then
	begin
		InputDir.Text := ReadDir;
		if Length(ReadDir) > 3 then
			InputDir.Text := InputDir.Text + '\';
	end;
end;

procedure TForm1.Button2Click(Sender: TObject);
begin
	if SaveDialog.Execute then
	begin
		OutFile.Text := SaveDialog.FileName;
	end;
end;

procedure TForm1.SerchFile(Dir:String);
var
	SearchResult : TSearchRec;
begin
		SetCurrentDir(InputDir.Text + Dir);
		if FindFirst('*', faDirectory or faAnyFile, SearchResult) = 0 then
		begin
			Repeat
				if (SearchResult.Name <> '.') and (SearchResult.Name <> '..') then
					if ((SearchResult.Attr and faDirectory) <> 0) then
					begin
							SerchFile(Dir + SearchResult.Name + '\');
					end else
					begin
						if SearchResult.Name <> 'thumbs.db' then
							FileList.Add(Dir + SearchResult.Name);
					end;
			until FindNext(SearchResult) <> 0;
		end;
		FindClose(searchResult);
end;

procedure TForm1.Button3Click(Sender: TObject);
var
	i : integer;
	ass : TAss;
	tmp : byte;
begin
	if (InputDir.Text <> '') and (OutFile.Text <>'' ) then
	begin
		FileList := TStringList.Create;
		FileList.Clear;
		Button1.Enabled := False;
		Button2.Enabled := False;
		Button3.Enabled := False;
		ass := TAss.Create;
		if opFile.Checked then
			tmp := ASST_File
		else
			tmp := ASST_GRF;
		if ass.CreateAss(OutFile.Text, tmp) <> ASS_SUCCESS then
		begin
			showmessage('fail to create');
		end;
		SerchFile('');

		if  Filelist.Count >0 then
		begin
			Progress.Max := FileList.Count;
			for  i := 0 to Filelist.Count -1 do
			begin
				Application.ProcessMessages;
				Ass.AddData(PChar(Filelist[i]), InputDir.Text + Filelist[i]);
				Progress.Position := Progress.Position + 1;
			end;
		end;
		ass.Seal;
		ass.Free;
		FileList.Free;
		Button1.Enabled := True;
		Button2.Enabled := True;
		Button3.Enabled := True;
	end;
end;

procedure TForm1.Button4Click(Sender: TObject);
//var
//	i : integer;
//	ass : TGRF;
begin
//	if (InputDir.Text <> '') and (OutFile.Text <>'' ) then
//	begin
//		FileList := TStringList.Create;
//		FileList.Clear;
//		Button1.Enabled := False;
//		Button2.Enabled := False;
//		Button3.Enabled := False;
//		ass := TGRF.Create;
//		if ass.LoadGrf(OutFile.Text) <> GRF_SUCCESS then
//		begin
//			showmessage('fail to create');
//		end;
//		SerchFile('');
//
//		if  Filelist.Count >0 then
//		begin
//			Progress.Max := FileList.Count;
//			for  i := 0 to Filelist.Count -1 do
//			begin
//				Application.ProcessMessages;
//				Ass.AddData(PChar(Filelist[i]), InputDir.Text + Filelist[i]);
//				Progress.Position := Progress.Position + 1;
//			end;
//		end;
//		Ass.SaveTable;
//		ass.Free;
//		FileList.Free;
//		Button1.Enabled := True;
//		Button2.Enabled := True;
//		Button3.Enabled := True;
//	end;
end;

end.
