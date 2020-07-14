unit uUpdateMain;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, ComCtrls, StdCtrls,
  //VCLZip, VCLUnZip, uFormVSkin,

  {$IFDEF FPC}

  {$ELSE}
  XMLIntf,
  XMLDoc,
  IdBaseComponent, IdComponent,
  IdTCPConnection, IdTCPClient, IdHTTP,
  {$ENDIF}

  ExtCtrls;

type
  //TfrmUpdateMain = class(TFormVSkin)
  TfrmUpdateMain = class(TForm)
    btnUpdate1:TPanel;
    btnUpdate2:TPanel;
    ImagePanel1:TPanel;
    OpenDialog1:TOpenDialog;
    txtInfo:TLabel;
    pnlCaptionRight:TPanel;
    pnlClient:TPanel;
    ProgressBar_DownLoad: TProgressBar;
    btnDownLoad: TPanel;
    Panel1: TPanel;
    btnUpdate: TPanel;
    Image1: TPanel;
    Image2: TPanel;
    procedure btnDownLoadClick(Sender: TObject);
    procedure btnUpdate1Click(Sender:TObject);
    procedure btnUpdate2Click(Sender:TObject);
    procedure btnUpdateClick(Sender: TObject);

    procedure FormCreate(Sender: TObject);
    procedure btnStopClick(Sender: TObject);
  private

    procedure LoadConfig;
    { Private declarations }
  public
    { Public declarations }
    slLatest:TStringList;
    latestFileName:string;
    httpFileName:string;
  end;

//ͳһ�������ѯ�ʶԻ���//ע:�������߳���ʹ��,���Ҫ���߳��л��ǵ�ʹ��ԭʼ�� MessagBox
function MessageBox_New(hWnd: HWND; sText, sCaption: string): Boolean;


var
  frmUpdateMain: TfrmUpdateMain;
  GStop:Boolean = False;

  GMainExe:string = '';//������
  Glatest:string = ''; //Ҫ�� http ���ص���Ϣ
  //GHttpFileName:string = ''; //Ҫ�� http ���ص���Ϣ
  _GHttpFileName:string = '';

  // 2013-10-29 9:06:11 ������,ʹ�õ�ǰ���еľ�Ĭ���ط�ʽ,���̵�Ҳ��������
  GAutoDownFile:Boolean = False;//True;
  GForceUpdate:Boolean = False;//�Ƿ�ǿ�Ƹ���


  //--------------------------------------------------
  //���ش��ݵĹ�˾��
  GCompanyName : string = 'xm';

implementation

uses
  uThreadDownLoad, md5,
  //zipper, //lazarus �Դ�
  //sggzip,
  la_zip,
  LConvEncoding,
  LazUTF8,
  la_functions,
  md5_check,
  http_client;
  //uKillAppExe;

{$R *.dfm}

//ͳһ�������ѯ�ʶԻ���//ע:�������߳���ʹ��,���Ҫ���߳��л��ǵ�ʹ��ԭʼ�� MessagBox
function MessageBox_New(hWnd: HWND; sText, sCaption: string): Boolean;
var
  r:Integer;
begin
  r := MessageBox(hWnd, PAnsiChar(sText),  PAnsiChar(sCaption), MB_YESNO );

  if r = IDYES then Result := True
  else Result := False;
end;  


function Zip(ZipMode,PackSize:Integer;ZipFile,UnzipDir:String):Boolean; //ѹ�����ѹ���ļ�
//var
//  ziper:TVCLZip;
begin
  {
  //�����÷���Zip(ѹ��ģʽ��ѹ������С��ѹ���ļ�����ѹĿ¼)
  //ZipModeΪ0��ѹ����Ϊ1����ѹ����PackSizeΪ0�򲻷ְ�������Ϊ�ְ��Ĵ�С
  try
    if copy(UnzipDir, length(UnzipDir), 1) = '\' then
    UnzipDir := copy(UnzipDir, 1, length(UnzipDir) - 1); //ȥ��Ŀ¼��ġ�\��
    
    ziper:=TVCLZip.Create(application);//����zipper
    ziper.DoAll:=true;//�Ӵ����ý��Էְ��ļ���ѹ����Ч
    ziper.OverwriteMode:=Always;//���Ǹ���ģʽ

    if PackSize<>0 then begin//���Ϊ0��ѹ����һ���ļ�������ѹ�ɶ��ļ�
      ziper.MultiZipInfo.MultiMode:=mmBlocks;//���÷ְ�ģʽ
      ziper.MultiZipInfo.SaveZipInfoOnFirstDisk:=True;//�����Ϣ�����ڵ�һ�ļ���
      ziper.MultiZipInfo.FirstBlockSize:=PackSize;//�ְ����ļ���С
      ziper.MultiZipInfo.BlockSize:=PackSize;//�����ְ��ļ���С
    end;

    ziper.FilesList.Clear;
    ziper.ZipName := ZipFile; //��ȡѹ���ļ���
    
    if ZipMode=0 then begin //ѹ���ļ�����
      ziper.FilesList.Add(UnzipDir+'\*.*');//��ӽ�ѹ���ļ��б�
      Application.ProcessMessages;//��ӦWINDOWS�¼�
      ziper.Zip;//ѹ��
    end else begin
      ziper.DestDir:= UnzipDir;//��ѹ����Ŀ��Ŀ¼
      ziper.RecreateDirs := True;//Ҫ����������ڽ�ѹʱ��Ŀ¼
      ziper.UnZip; //��ѹ��
    end;

    ziper.Free; //�ͷ�ѹ��������Դ
    Result:=True; //ִ�гɹ�
  except
    Result:=False;//ִ��ʧ��
  end;
  }
end;

procedure TfrmUpdateMain.btnDownLoadClick(Sender: TObject);
var
  thread:TThreadDownLoad;
begin
  GStop := False;
  btnDownLoad.Enabled := False;

  //----
  GetHttpFileInfo_index := 0; //��ǰ�ļ���Ϣ�ǵڼ����ļ��ģ��� 0 ��ʼ
  GetHttpFile_index := 0; //��ǰ���صĵڼ����ļ����� 0 ��ʼ

  //----
  //ȡ��һ���ļ�
  GetHttpFileName_List;

  exit;
  //----

  //ÿ���� 40 K
  thread := TThreadDownLoad.Create(True);
  thread.blockSize := 40 * 1024;
  thread.httpFileName := Self.httpFileName;


  thread.Resume;

  
end;


procedure TfrmUpdateMain.btnUpdateClick(Sender: TObject);
var
  h:THandle;
  md5:string;
  fn:string;
begin

  if nil = GHttpFileName_List then
  begin
    ShowMessage(AnsiToUtf8_delphi7('���������ļ���'));
    Exit;
  end;
  MakeLocalFileMd5_All();
  //CopyFileAll();

  Exit;//2020
  //--------------------------------------------------
  //��ɱ������
  //KillAppExe(GMainExe); //2020 la ����Щ windows api �����ò���
  Sleep(3000);


  //--------------------------------------------------

  //ֻ��������һ��ʵ��
  h := CreateMutex(nil, false, 'MarketV3');
  if (GetLastError() = ERROR_ALREADY_EXISTS) then
  begin
    //CloseHandle(hMutex);
    MessageBox(Application.Handle, '�������������У����˳����ٽ��и��£�', '��ʾ', MB_OK or MB_ICONWARNING);
    //oldWindow := FindWindow('TfrmLogin', nil);

    //���,���ڵ������Ҳ��Ҫ�ͷŵ�,������ظ�������
    ReleaseMutex(h);
    CloseHandle(h);

    Self.Show;//��Ĭ����ʱ������δ���Ǵ򿪵�,����Ҫ��ʾһ��

    Exit;
  end;

  ReleaseMutex(h);
  CloseHandle(h);

  btnDownLoad.Enabled := False;
  btnUpdate.Enabled := False;

  //--------------------------------------------------
  //Zip(1, 0, 'c:\1.zip', 'c:\2');
  fn := ExtractFilePath(Application.ExeName) + 'update.zip';
  md5 := MD5DigestToString(MD5File(fn));

  if md5<>slLatest.Values['MD5'] then
  begin
    ShowMessage('�ļ���,����������.');
    DeleteFile(fn);
    btnDownLoad.Enabled := True;
    Exit;
  end;  

  Zip(1, 0, fn, ExtractFileDir(Application.ExeName));
  ShowMessage('�������.');
  slLatest.SaveToFile(latestFileName);
  //ɾ���ļ�
  CopyFile(PChar(ExtractFilePath(Application.ExeName) + 'update.zip'), PChar(ExtractFilePath(Application.ExeName) + 'update.old.zip'), False);
  DeleteFile(ExtractFilePath(Application.ExeName) + 'update.zip');

  //����������
  WinExec(PChar(ExtractFilePath(Application.ExeName) + GMainExe), SW_SHOWNORMAL);

  ExitProcess(0);

end;


procedure TfrmUpdateMain.LoadConfig;
var
  i : Integer;
  sl:TStringList;

begin
  sl := TStringList.Create;
  sl.LoadFromFile(ExtractFilePath(Application.ExeName) + 'config_updateclient.txt');

  //ShowMessage(response);

  try

    //--------------------------------------------------
    //������������ַ

    GCompanyName := sl.Values['CompanyName'];

    GMainExe := sl.Values['MainExe'];

    // 2015/7/9 10:41:04 Ҫ���ص��ļ�����Ϣ
		//latest="http://127.0.0.1/latest.txt"
		//HttpFileName="http://127.0.0.1/update.zip"
    Glatest := sl.Values['latest'];
    _GHttpFileName := sl.Values['HttpFileName'];
    GHttpFileName_List_Fn := sl.Values['HttpFileName'];

    

    //--------------------------------------------------

  //finally
  except
    //GLoadConfigError := True;
    ShowMessage(sl.Text);//���� xml ��ʽ

  end;
//  XML.Free;

  sl.Free;


end;


procedure TfrmUpdateMain.FormCreate(Sender: TObject);
begin
  //Application.Title := '���³���';

  slLatest := TStringList.Create;
  latestFileName := ExtractFilePath(Application.ExeName) + 'latest.txt';

  LoadConfig();

  Image2.Width := 0;

  //--------------
  //2020
  if GAutoDownFile then btnDownLoadClick(btnDownLoad);

end;

procedure TfrmUpdateMain.btnStopClick(Sender: TObject);
begin
  GStop := True;
  Sleep(1000);
  btnDownLoad.Enabled := True;

  GetHttpFileInfo_index := 0; //��ǰ�ļ���Ϣ�ǵڼ����ļ��ģ��� 0 ��ʼ
  GetHttpFile_index := 0; //��ǰ���صĵڼ����ļ����� 0 ��ʼ
end;

procedure TfrmUpdateMain.btnUpdate1Click(Sender:TObject);
var
  fn,path:String;
  r:Boolean;
begin
  path := ExtractFilePath(Application.ExeName) + 'update';

  fn := ExtractFilePath(Application.ExeName) + 'update.zip';

  ForceDirectories(path);

  //la �Ľ�ѹģ�鲻�ܽ�ѹ����ԭ�ļ���С���ļ������Լ�����û winrar �á��������Ը���ԭ���ļ���������ȷ��ѹ��Ŀ¼
  r := UnZip(fn, path);

  //if False = r Then ShowMessage(AnsiToUtf8('zip �ļ���'));
  //if False = r Then ShowMessage(CP936ToUTF8('zip �ļ���')); //LConvEncoding , lazarus �� AnsiToUtf8 �ǲ���ת�� gbk ��Դ���
  //(CP936ToUTF8

  //LazUTF8.UTF8ToWinCP(s);
  //if False = r Then ShowMessage(LazUTF8.WinCPToUTF8('zip �ļ���')); //���Ҳ����

  if False = r Then ShowMessage(AnsiToUtf8_delphi7('zip �ļ���')) //���Ҳ����
  else ShowMessage(AnsiToUtf8_delphi7('��ѹ��ϡ�'));

end;

procedure TfrmUpdateMain.btnUpdate2Click(Sender:TObject);
var
  s:String;
begin

  if OpenDialog1.Execute = False Then Exit;

  MakeLocalFileMd5(OpenDialog1.FileName);
  //GetFileMd5(OpenDialog1.FileName);

  ShowMessage('ok');

  Exit;
  //----
  s := GetFileMd5(ExtractFilePath(Application.ExeName) + 'update.zip');

  s := ExtractFileName('http://softhub.newbt.net/174/174--1.html');
  ShowMessage(s);

  GetHttpFileName_List();

end;


end.
