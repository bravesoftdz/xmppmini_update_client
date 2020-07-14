unit uThreadDownLoad;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,


  {$IFDEF FPC}
  fphttp, fphttpclient,
  {$ELSE}
  IdBaseComponent, IdComponent, IdTCPConnection, IdTCPClient,
  IdHTTP,
  {$ENDIF}


  Dialogs;

{$IFDEF FPC}
type
  TWorkMode = Integer;

{$ELSE}

{$ENDIF}

type
  TThreadDownLoad = class;
  TThreadDownLoadEvent2 = procedure(thread:TThreadDownLoad; tag:Integer; const out1:string; succeed:boolean);  //û�пؼ���

type
  TThreadDownLoad = class(TThread)
  private
    //���ص����ļ�λ��
    curPos:Integer;
    //ȫ���Ĵ�С
    totalSize:Integer;
    //��ǰ�ķ�Χ
    curRange1,curRange2:Integer;
    curSize:Integer;
    curFile:TFileStream;
    //���صĳ������
    netErrCount:Integer;



    function GetTotalSize(s: string): Integer;
    function GetTotalSize_Http:Boolean;
    procedure GetRange(s: string);
    procedure IdHTTP_OnWork(Sender: TObject; AWorkMode: TWorkMode;
      const AWorkCount: Integer);


    {$IFDEF FPC}
    function DownBlock_la: Boolean;
    {$ELSE}
    function DownBlock_d7: Boolean;
    {$ENDIF}
    function DownBlock: Boolean;

    procedure DoDownComplete;

  protected
    procedure Execute; override;
  public
    //����ʲô�ļ�
    fileName:string;
    //ÿ�����ض��
    blockSize:Integer;

    {$IFDEF FPC}
    http:TFPHTTPClient;
    {$ELSE}
    http:TIdHTTP;
    {$ENDIF}


    Response:string;
    httpFileName:string;

    //test
    AWorkCount:Integer;

    txtInfo:String;

    //DoDownComplete �е��ã��̰߳�ȫ
    OnDownComplete:TThreadDownLoadEvent2;

    tag:Integer; //Ŀǰ���� OnDownComplete
    localFileName:string; //2020 ���غ�ı��صص��ļ���


    //������������ʾ��Ϣ
    procedure ShowInfo;
    //������������ʾ��Ϣ
    procedure ShowInfo2;

    procedure _ShowInfo_String;
    procedure ShowInfo_String(Const _s:String);
    function GetLocalFileName:String;
  end;

var
  DebugHook:Integer = 0;

implementation

uses
  http_client,
  la_functions,
  uUpdateMain;

{ Important: Methods and properties of objects in visual components can only be
  used in a method called using Synchronize, for example,

      Synchronize(UpdateCaption);

  and UpdateCaption could look like,

    procedure TThreadDownLoad.UpdateCaption;
    begin
      Form1.Caption := 'Updated in a thread';
    end; }

{ TThreadDownLoad }


function TThreadDownLoad.GetLocalFileName:String;
var
  _localFileName:String;
  fn:String;
begin
  //2020 ����Ĭ���ļ������� http ��ַ�������
  //httpFileName := GHttpFileName;
  _localFileName := ExtractFileName(httpFileName);
  fn := ExtractFilePath(Application.ExeName) + 'update_down\' + _localFileName;
  ForceDirectories(ExtractFilePath(Application.ExeName) + 'update_down');

  _localFileName := fn; //��һ������·�������滹����

  Result := _localFileName;
end;

procedure TThreadDownLoad.Execute;
var
  fn:string;
begin

  try
    //--------------------------------------------------
    //��ʼ��
    curPos := 0;

    {$IFDEF FPC}
    http := TFPHTTPClient.Create(nil);
    //http.OnDataReceived := ;   //2020 la ����ʲô�¼�?
    {$ELSE}
    http := TIdHTTP.Create(nil);
    http.OnWork := Self.IdHTTP_OnWork;
    {$ENDIF}


    //--------------------------------------------------

  //  http.Request.CustomHeaders.Values['Range'] := 'bytes=1024-2048';//��Ӧ�Ļ�Ӧ������ "Content-Range"
  //  //Response := http.Get('http://www.csdn.net');
  //  http.Get('http://127.0.0.1:8080/20130502.1.rar?a=1&b=2&c=123');

    //--------------------------------------------------
    //curFile := TFileStream.Create('c:\2.rar', fmCreate or fmShareDenyNone);
    ////fn := ExtractFilePath(Application.ExeName) + 'update.zip';

    //2020 ����Ĭ���ļ������� http ��ַ�������
    //httpFileName := GHttpFileName;
    fn := GetLocalFileName();

    localFileName := fn; //��һ������·�������滹����

    if FileExists(fn) then
    begin
      //�����ļ��ĴӶϵ��
      curFile := TFileStream.Create(fn, fmOpenWrite or fmShareDenyNone);
      curPos := curFile.Size;
      curFile.Seek(0, soEnd);
    end
    else
      curFile := TFileStream.Create(fn, fmCreate or fmShareDenyNone);

    //ѭ������,ֱ������,ÿ�� blockSize ��С
    netErrCount := 0;//���صĳ������
    while True do
    begin
      if DownBlock()= False then Break;
      if netErrCount>10 then Break;//���� 10 �ξ��˳���

      //Synchronize(ShowInfo);
      Synchronize(@ShowInfo); //la ��Ҫ�ӵ�ַ��
    end;
    curFile.Free;

  except
  end;

  Synchronize(@DoDownComplete);
  //ShowInfo;

end;

{$IFDEF FPC}

{$ELSE}
function TThreadDownLoad.DownBlock_d7:Boolean;
var
  mem:TMemoryStream;
  curLen:Integer;
begin
  Result := True;

  if GStop = True then
  begin
    Result := False;
    Exit;
  end;

  mem := TMemoryStream.Create;
  try//���,�ҵ� indy ���ڲ��׳��쳣��,������ try ��
    //--------------------------------------------------
    curLen := curPos + blockSize;//���¼��㵱ǰҪ���صĳ��ȸ���,����Ŀǰ�������Բ��Է��������ݴ�

    //http.Request.CustomHeaders.Values['Range'] := 'bytes=1024-2048';//��Ӧ�Ļ�Ӧ������ "Content-Range"
    http.Request.CustomHeaders.Values['Range'] := 'bytes='+ IntToStr(curPos) + '-' + IntToStr(curPos + blockSize);//��Ӧ�Ļ�Ӧ������ "Content-Range"

    //http.ConnectTimeout := 10000;
    //http.ReadTimeout := 10000;//����
    http.ReadTimeout := 30000;

    //Response := http.Get('http://www.csdn.net');
    //http.Get('http://127.0.0.1:8080/20130502.1.rar?a=1&b=2&c=123', mem);
    //http.Get('http://127.0.0.1:8080/20130514.zip?a=1&b=2&c=123', mem);
    //http.Get('http://192.168.1.183:8090/' + httpFileName + '?a=1&b=2&c=123', mem);
    //http.Get('http://fyguilin.fuyoo.net:8090/' + httpFileName + '?a=1&b=2&c=123', mem);
    if GHttpFileName = '' then
    http.Get('http://' + GIP + ':' + IntToStr(GPort) + '/' + httpFileName + '?a=1&b=2&c=123', mem)
    else
    http.Get(GHttpFileName, mem);




    //mem.SaveToFile('c:\1.rar');
    mem.Position := 0;

    curFile.CopyFrom(mem, mem.Size);

    GetTotalSize(http.Response.RawHeaders.Values['Content-Range']);

    //--------------------------------------------------
    //ѭ������,ֱ������,ÿ�� blockSize ��С

    //��Ӧ�����������// 2015/7/9 11:55:36//������һ���� 206
    if DebugHook<>0 then
    if http.ResponseCode>=400
    then MessageBox(0, PChar('Content-Range:' + http.Response.ResponseText), '�ļ����ش���', MB_OK or MB_ICONWARNING);

    //range ����ֵ������ĵ�ǰ���ش�С,���������,�� mem.Size �ǲ�ͬ��
    if DebugHook<>0 then
    if curSize=0
    then MessageBox(0, PChar('Content-Range:' + http.Response.ResponseText), '�ļ����ش���', MB_OK or MB_ICONWARNING);

    if mem.Size < 1
    then Result := False;

    //��ǰλ���Ѿ��ƶ��������˾ͽ�����,��Ϊ curPos �Ǵ�0��ʼ��,�����������ʱ�ͽ�����
    if curPos>=totalSize
    then Result := False;


    netErrCount := 0;//�������سɹ��Ļ����ô������
  except
    //MessageBox(0, '�������ʧ��.', '', MB_OK or MB_ICONWARNING);

    //win2003 ��ԭ�� iis ��һ�����ص� bug ������� rang ������Χʱ��ʼ�շ���һ���ֽ�,���ڶ�������ʱ������� 'bytes */5021483' �� range ͷ
    //��ʱ�Ļ�Ӧ��Ϊ 'HTTP/1.1 416 Requested Range Not Satisfiable'

    //��Ӧ�����������// 2015/7/9 11:55:36//������һ���� 206
    if http.ResponseCode>=400 then
    begin
      Result := False;
      mem.Free;
      Exit;
    end;

    if DebugHook<>0 then MessageBox(0, PChar('Content-Range:' + http.Response.RawHeaders.Values['Content-Range']), '�ļ����ش���', MB_OK or MB_ICONWARNING);
    //���صĳ������
    Inc(netErrCount);
  end;

  mem.Free;
end;


{$ENDIF}

function TThreadDownLoad.DownBlock:Boolean;
begin
  {$IFDEF FPC}
  Result := DownBlock_la();
  {$ELSE}
  Result := DownBlock_d7();
  {$ENDIF}
end;

//----
//�����Ƶ� oss ��һ�� bug , ������� ['Range'] �����ļ���Сʱ�����᷵�������ļ��� ���Ҳ��ٺ��� ['Range'] ��Ӧ����������ʱ��Ϊ������Ҳû�� ['Range']
//����Ȼ�ܿ��£�����Ǽ��� G ���ǻ����ˣ�����Ӧ����һ�����̣���ȡ 0-1 ���ֽڣ��ȵõ� totalSize �ٽ��к���Ĳ���
//����Ҫ��һ��������ȡ totalSize resourcestring ����
//ֻȡһ�ξ�����
//�� DownBlock_la Ҳ��ֻ࣬��ֻȡһ���ֽڣ�����ȡ�ص����ݲ�����ļ���
function TThreadDownLoad.GetTotalSize_Http:Boolean;
var
  mem:TMemoryStream;
  _downSize:Integer;

  //������Ϊ�����ȫ�ֱ���ͬ��
  _curPos:Integer;

begin

  Result := True;

  if GStop = True then
  begin
    Result := False;
    Exit;
  end;

  mem := TMemoryStream.Create;
  try//���,�ҵ� indy ���ڲ��׳��쳣��,������ try ��
    //--------------------------------------------------

    //http.Request.CustomHeaders.Values['Range'] := 'bytes=1024-2048';//��Ӧ�Ļ�Ӧ������ "Content-Range"
    //http.Request.CustomHeaders.Values['Range'] := 'bytes='+ IntToStr(curPos) + '-' + IntToStr(curPos + blockSize);//��Ӧ�Ļ�Ӧ������ "Content-Range"
    //http.RequestHeaders.Values['Range'] := 'bytes='+ IntToStr(curPos) + '-' + IntToStr(curPos + blockSize);//��Ӧ�Ļ�Ӧ������ "Content-Range"
    //���ԣ������ 0-1 ����ôȡ�õ��������ֽڵ����ݣ�����Ӧ��ȡ 0-0 ����������յ㷶ΧҲ��һ����
    http.RequestHeaders.Values['Range'] := 'bytes='+ IntToStr(0) + '-' + IntToStr(0);//��Ӧ�Ļ�Ӧ������ "Content-Range" //ֻȡһ���ֽ�


    //http.ConnectTimeout := 10000;
    //http.ReadTimeout := 10000;//����
//    http.ReadTimeout := 30000;
    http.IOTimeout := 30000;  //2020 ��֪����λ�Ƿ�Ҳ�Ǻ���

    //la �ķ���ֵֻ�� 200 �����룬����Ҫ�Զ���һ��
    HttpGet(http, Self.httpFileName, mem);

    //----
    //�����Ƶ� oss ��һ�� bug , ������� ['Range'] �����ļ���Сʱ�����᷵�������ļ��� ���Ҳ��ٺ��� ['Range'] ��Ӧ����������ʱ��Ϊ������Ҳû�� ['Range']
    //����Ȼ�ܿ��£�����Ǽ��� G ���ǻ����ˣ�����Ӧ����һ�����̣���ȡ 0-1 ���ֽڣ��ȵõ� totalSize �ٽ��к���Ĳ���

    _downSize := mem.Size;
    ShowInfo_String('��ǰȡ�����ݳ���Ϊ��'+ IntToStr(_downSize) + ' ' + IntToStr(_downSize div 1024) + 'K ' + IntToStr(_downSize div (1024*1024)) + 'm');

    //---------------------------------------------------
    //mem.SaveToFile('c:\1.rar');
    ////mem.SaveToFile('d:\2.rar');
    mem.Position := 0;

    //���У�Ҫ���ж��Ƿ��� 'Content-Range'
    ////curFile.CopyFrom(mem, mem.Size);  //���������ݼ��뵽�ļ���

    //----------------------------------------------------

    _curPos := curPos; //curPos �ᱻ�޸ģ������ȱ���һ��ԭ����ֵ

    //GetTotalSize(http.Response.RawHeaders.Values['Content-Range']);
    //ShowMessage(http.ResponseHeaders.Text); //2020 ע�⣬la ͨ�� ResponseHeaders.Values ȡ��ʶʱǰ����һ���ո�
    GetTotalSize(http.ResponseHeaders.Values['Content-Range']);  //2020 ע�⣬la ͨ�� ResponseHeaders.Values ȡ��ʶʱǰ����һ���ո�

    curPos := _curPos;  //һ��Ҫ�ָ�ԭֵ
    //--------------------------------------------------
    //ѭ������,ֱ������,ÿ�� blockSize ��С

    //��Ӧ�����������// 2015/7/9 11:55:36//������һ���� 206
    if DebugHook<>0 then
    //if http.ResponseCode>=400
    //then MessageBox(0, PChar('Content-Range:' + http.Response.ResponseText), '�ļ����ش���', MB_OK or MB_ICONWARNING);
    if http.ResponseStatusCode>=400
    then MessageBox(0, PChar('Content-Range:' + http.ResponseStatusText), '�ļ����ش���', MB_OK or MB_ICONWARNING);

    //range ����ֵ������ĵ�ǰ���ش�С,���������,�� mem.Size �ǲ�ͬ��
    if DebugHook<>0 then
    if curSize=0
    then MessageBox(0, PChar('Content-Range:' + http.ResponseStatusText), '�ļ����ش���', MB_OK or MB_ICONWARNING);

    if mem.Size < 1
    then Result := False;

    //��ǰλ���Ѿ��ƶ��������˾ͽ�����,��Ϊ curPos �Ǵ�0��ʼ��,�����������ʱ�ͽ�����
    if curPos>=totalSize
    then Result := False;


    netErrCount := 0;//�������سɹ��Ļ����ô������
  except
    //MessageBox(0, '�������ʧ��.', '', MB_OK or MB_ICONWARNING);

    //win2003 ��ԭ�� iis ��һ�����ص� bug ������� rang ������Χʱ��ʼ�շ���һ���ֽ�,���ڶ�������ʱ������� 'bytes */5021483' �� range ͷ
    //��ʱ�Ļ�Ӧ��Ϊ 'HTTP/1.1 416 Requested Range Not Satisfiable'

    //��Ӧ�����������// 2015/7/9 11:55:36//������һ���� 206
    if http.ResponseStatusCode>=400 then
    begin
      Result := False;
      mem.Free;
      Exit;
    end;

    if DebugHook<>0 then MessageBox(0, PChar('Content-Range:' + http.ResponseHeaders.Values['Content-Range']), '�ļ����ش���', MB_OK or MB_ICONWARNING);
    //���صĳ������
    Inc(netErrCount);
  end;

  mem.Free;

end;


//���� false ʱ����ļ����������ع��̽���
function TThreadDownLoad.DownBlock_la:Boolean;
var
  mem:TMemoryStream;
  curLen:Integer;
  _downSize:Integer;
  _endPos:Integer; //2020 ��Ҫ��ȷ�ļ�������λ��
begin
  Result := True;

  if GStop = True then
  begin
    Result := False;
    Exit;
  end;

  //--------------------------------------------------------
  //Ϊ���Ⱒ���ƶԴ��� Range ͷ�᷵��ȫ�����ݵ����⣬������ȡһ���ļ���������С
  if totalSize = 0 then
  begin
    GetTotalSize_Http();
    ShowInfo_String('�ļ���СΪ��' + IntToStr(totalSize));
  end;

  if curPos >= totalSize then //�����ǰλ�ô���ȫ�����ߵ��ڣ�����Ϊ���������
  begin
    ShowInfo_String('��������ȫ�����ݡ�');
    Result := False;
    Exit;
  end;
  //--------------------------------------------------------

  mem := TMemoryStream.Create;
  try//���,�ҵ� indy ���ڲ��׳��쳣��,������ try ��
    //--------------------------------------------------
    curLen := curPos + blockSize;//���¼��㵱ǰҪ���صĳ��ȸ���,����Ŀǰ�������Բ��Է��������ݴ�
    _endPos := curPos + blockSize;
    //2020 ����λ�ò����� totalSize ���� totalSize-1 ����ֻȡһ���ֽڵĻ� range ���� 0-0 ������ 0-1
    //if _endPos > totalSize then _endPos := totalSize; //2020 һ��Ҫ��ȷ���㣬�������������ķ��������ܻ���Ϊ�Ǵ���� range ͷ�����������ļ���
    if _endPos > (totalSize-1) then _endPos := totalSize - 1; //2020 һ��Ҫ��ȷ���㣬�������������ķ��������ܻ���Ϊ�Ǵ���� range ͷ�����������ļ���

    //http.Request.CustomHeaders.Values['Range'] := 'bytes=1024-2048';//��Ӧ�Ļ�Ӧ������ "Content-Range"
    //http.Request.CustomHeaders.Values['Range'] := 'bytes='+ IntToStr(curPos) + '-' + IntToStr(curPos + blockSize);//��Ӧ�Ļ�Ӧ������ "Content-Range"
    //http.RequestHeaders.Values['Range'] := 'bytes='+ IntToStr(curPos) + '-' + IntToStr(curPos + blockSize);//��Ӧ�Ļ�Ӧ������ "Content-Range"
    http.RequestHeaders.Values['Range'] := 'bytes='+ IntToStr(curPos) + '-' + IntToStr(_endPos);//��Ӧ�Ļ�Ӧ������ "Content-Range"

    ShowInfo_String('��ǰ����λ�ã�' + IntToStr(curPos) + ' ' + IntToStr(curPos div 1024) + 'K ' + IntToStr(curPos div (1024*1024)) + 'm');

    //http.ConnectTimeout := 10000;
    //http.ReadTimeout := 10000;//����
//    http.ReadTimeout := 30000;
    http.IOTimeout := 30000;  //2020 ��֪����λ�Ƿ�Ҳ�Ǻ���

    //Response := http.Get('http://www.csdn.net');
    //http.Get('http://127.0.0.1:8080/20130502.1.rar?a=1&b=2&c=123', mem);
    //http.Get('http://127.0.0.1:8080/20130514.zip?a=1&b=2&c=123', mem);
    //http.Get('http://192.168.1.183:8090/' + httpFileName + '?a=1&b=2&c=123', mem);

    //la �ķ���ֵֻ�� 200 �����룬����Ҫ�Զ���һ��
    HttpGet(http, Self.httpFileName, mem);

    //----
    //�����Ƶ� oss ��һ�� bug , ������� ['Range'] �����ļ���Сʱ�����᷵�������ļ��� ���Ҳ��ٺ��� ['Range'] ��Ӧ����������ʱ��Ϊ������Ҳû�� ['Range']
    //����Ȼ�ܿ��£�����Ǽ��� G ���ǻ����ˣ�����Ӧ����һ�����̣���ȡ 0-1 ���ֽڣ��ȵõ� totalSize �ٽ��к���Ĳ���

    _downSize := mem.Size;
    ShowInfo_String('��ǰȡ�����ݳ���Ϊ��'+ IntToStr(_downSize) + ' ' + IntToStr(_downSize div 1024) + 'K ' + IntToStr(_downSize div (1024*1024)) + 'm');

    //---------------------------------------------------
    //mem.SaveToFile('c:\1.rar');
    ////mem.SaveToFile('d:\1.rar');
    mem.Position := 0;

    //���У�Ҫ���ж��Ƿ��� 'Content-Range'
    curFile.CopyFrom(mem, mem.Size);  //���������ݼ��뵽�ļ���

    //----------------------------------------------------

//    GetTotalSize(http.Response.RawHeaders.Values['Content-Range']);
    //ShowMessage(http.ResponseHeaders.Text); //2020 ע�⣬la ͨ�� ResponseHeaders.Values ȡ��ʶʱǰ����һ���ո�
    GetTotalSize(http.ResponseHeaders.Values['Content-Range']);  //2020 ע�⣬la ͨ�� ResponseHeaders.Values ȡ��ʶʱǰ����һ���ո�

    //--------------------------------------------------
    //ѭ������,ֱ������,ÿ�� blockSize ��С

    //��Ӧ�����������// 2015/7/9 11:55:36//������һ���� 206
    if DebugHook<>0 then
    //if http.ResponseCode>=400
    //then MessageBox(0, PChar('Content-Range:' + http.Response.ResponseText), '�ļ����ش���', MB_OK or MB_ICONWARNING);
    if http.ResponseStatusCode>=400
    then MessageBox(0, PChar('Content-Range:' + http.ResponseStatusText), '�ļ����ش���', MB_OK or MB_ICONWARNING);

    //range ����ֵ������ĵ�ǰ���ش�С,���������,�� mem.Size �ǲ�ͬ��
    if DebugHook<>0 then
    if curSize=0
    then MessageBox(0, PChar('Content-Range:' + http.ResponseStatusText), '�ļ����ش���', MB_OK or MB_ICONWARNING);

    if mem.Size < 1
    then Result := False;

    //��ǰλ���Ѿ��ƶ��������˾ͽ�����,��Ϊ curPos �Ǵ�0��ʼ��,�����������ʱ�ͽ�����
    if curPos>=totalSize
    then Result := False;


    netErrCount := 0;//�������سɹ��Ļ����ô������
  except
    //MessageBox(0, '�������ʧ��.', '', MB_OK or MB_ICONWARNING);

    //win2003 ��ԭ�� iis ��һ�����ص� bug ������� rang ������Χʱ��ʼ�շ���һ���ֽ�,���ڶ�������ʱ������� 'bytes */5021483' �� range ͷ
    //��ʱ�Ļ�Ӧ��Ϊ 'HTTP/1.1 416 Requested Range Not Satisfiable'

    //��Ӧ�����������// 2015/7/9 11:55:36//������һ���� 206
    if http.ResponseStatusCode>=400 then
    begin
      Result := False;
      mem.Free;
      Exit;
    end;

    if DebugHook<>0 then MessageBox(0, PChar('Content-Range:' + http.ResponseHeaders.Values['Content-Range']), '�ļ����ش���', MB_OK or MB_ICONWARNING);
    //���صĳ������
    Inc(netErrCount);
  end;

  mem.Free;
end;


//���뵱ǰ�����ط�Χ
procedure TThreadDownLoad.GetRange(s:string);
var
  i:Integer;
  bf:Boolean;//�ҵ���ʼ�ַ���
  s1:string;
  s2:string;
begin

  bf := False;
  s1 := '';
  s2 := '';

  for i := 1 to Length(s) do
  begin
    if bf = False then
    begin
      //�õ���ǰ�ķ�Χ
      if s[i]='-' then
      begin
        bf := True;
        Continue;
      end;

      s1 := s1 + s[i];
    end
    else
    begin
      s2 := s2 + s[i];

    end;
  end;

  curRange1 := StrToIntDef(s1, -1);//0);
  curRange2 := StrToIntDef(s2, -1);//0);// 2015/7/9 14:14:50 ����, http ����Э���� 0 ���������,������߶��� 0 ��ʾ�����ص� 1 ���ֽ�!���Գ�ʼӦ��Ϊ -1


  //if (curRange2>curRange1)and(curRange1>=0) then
  if (curRange2>=curRange1)and(curRange1>=0) then //�����ǿ�����ȵ�// 2015/7/9 15:15:06
  begin
    //curPos := curRange2; //����λ����ȵĻ���ʾȡ��ǰλ�õ�1���ֽ�,�������������Ҫ�� 1 ��
    curPos := curRange2 + 1;
    //curSize := curRange2 - curRange1;
    curSize := curRange2 - curRange1 + 1; //����λ����ȵĻ���ʾȡ��ǰλ�õ�1���ֽ�,�������������Ҫ�� 1 ��
  end;  

end;

//������ܴ�С����
function TThreadDownLoad.GetTotalSize(s:string):Integer;
var
  i:Integer;
  bf:Boolean;//�ҵ���ʼ�ַ���
  bt:Boolean;//�ҵ��ܴ�С�ַ���
  st:string;
  range:string;
begin
  Result := 0;

  s := Trim(s); //la �õ���ǰ����һ���ո�����Ҫ��ȥ��//2020 ע�⣬la ͨ�� ResponseHeaders.Values ȡ��ʶʱǰ����һ���ո�

  bf := False;
  bt := False;
  st := '';
  range := '';

  for i := 1 to Length(s) do
  begin
    if bf = False then
    begin
      //bf := True;
      //�õ���ǰ�ķ�Χ
      if s[i]=' ' then
      begin
        bf := True;
        Continue;
      end;
    end
    else
    begin
      if (bt = False)and(s[i]<>'/') then range := range + s[i];

    end;

    if bt = False then
    begin
      //�õ���ǰ�ķ�Χ
      if s[i]='/' then
      begin
        bt := True;
        Continue;
      end;
    end
    else
    begin
      st := st + s[i];

    end;

  end;

  GetRange(range);
  totalSize := StrToIntDef(st, 0);
  Result := StrToIntDef(st, 0);

end;

procedure TThreadDownLoad.ShowInfo;
begin
//  ShowMessage(Response);
//  //ShowMessage(http.Response.ResponseText);
//  ShowMessage(http.Response.RawHeaders.Text);//��չ��ͷ��Ϣ����������õ�
//  ShowMessage(http.Response.RawHeaders.Values['Content-Range']);
//
//  ShowMessage(IntToStr(GetTotalSize(http.Response.RawHeaders.Values['Content-Range'])));

  if totalSize > 0 then
  begin
    frmUpdateMain.ProgressBar_DownLoad.Position := Trunc(curPos * 100 / totalSize);
    frmUpdateMain.Image2.Width := Trunc(frmUpdateMain.Image1.Width * (curPos / totalSize));
  end;
  
end;

//���������
procedure TThreadDownLoad.DoDownComplete;
var
  succeed:Boolean;
begin
  //ShowMessage(Response);
  ////ShowMessage(http.Response.ResponseText);
  //ShowMessage(http.Response.RawHeaders.Text);//��չ��ͷ��Ϣ����������õ�
  //ShowMessage(http.Response.RawHeaders.Values['Content-Range']);

  //ShowMessage(IntToStr(GetTotalSize(http.Response.RawHeaders.Values['Content-Range'])));

  if nil<>OnDownComplete then
  begin
    succeed := True;;
    OnDownComplete(self, Self.tag, Self.httpFileName, succeed);
  end;

  if netErrCount>10 then
  begin
    ShowMessage('�����쳣,������ʱ��������.');
    ////Application.Terminate;
    Exit;
  end;

  if totalSize > 0 then
  frmUpdateMain.ProgressBar_DownLoad.Position := Trunc(curPos * 100 / totalSize);

  //frmUpdateMain.Image2.Width := frmUpdateMain.Image1.Width * Trunc(curPos / totalSize);

  //if curPos = totalSize then
  if curPos >= totalSize then//��Ϊ�п���������һ������,�����п��ܴ���
  begin
    {
    frmUpdateMain.btnUpdate.Enabled := True;
    
    //ShowMessage('�������,�����г������,��ȷ��ԭ�����Ѿ��˳�.');
    if GForceUpdate = True then//ǿ�Ƹ��µ�ʱ�򶼲�����
    begin
      ShowMessage('�������,�����г������,��ȷ��ԭ�����Ѿ��˳�.');
    end
    else  
    if MessageBox_New(Application.Handle, '�Ѿ�Ϊ��׼���ó�������°汾,�Ƿ����ڽ��и���?', '��ʾ') <> True then
    begin
      ////Application.Terminate;
      Exit;
    end;

    //������ɺ��Զ����и���
    frmUpdateMain.btnUpdateClick(frmUpdateMain.btnUpdate);
    }
  end;

end;

procedure TThreadDownLoad.IdHTTP_OnWork(Sender: TObject; AWorkMode: TWorkMode;
  const AWorkCount: Integer);
begin
  //
//  curPos := AWorkCount;
//
//  Synchronize(ShowInfo);

  Self.AWorkCount := AWorkCount;
  Synchronize(@ShowInfo2);

end;

procedure TThreadDownLoad.ShowInfo2;
begin
  //frmUpdateMain.Caption := IntToStr(AWorkCount);
  
end;

procedure TThreadDownLoad._ShowInfo_String;
begin
  frmUpdateMain.txtInfo.Caption := Self.txtInfo;

end;


procedure TThreadDownLoad.ShowInfo_String(Const _s:String);
var
  s:String;
begin

  s := AnsiToUtf8_delphi7(_s);

  Self.txtInfo := s;

  Synchronize(@_ShowInfo_String);

end;

end.
