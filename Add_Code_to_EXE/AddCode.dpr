{
 � ���� � ��o�������� �� Delphi.
 ������ ���������� ���� (������� Beep) � exe �����.
  �������� �����:
   1. ��������, ����� �������� ������ ��� ���.
   2. ���� �����, �� ��������� (� ������ Extra Data � ����� �����) ��� �����������.
   3. ��������� � ���� ������ ������� �������.
   4. ��������� � ��� ������� Beep.
   5. ���������� ���� ������� ����.
  �����������:
   1. ������ ����������� ����� (90%).  
  ����� �����: ������� ������
               peexe@Mail.ru
}

program DOP;
Uses
 Windows;
Const
 FileName = 'c:\tmp\test.exe';     //���� � ��� ����� � ������� ���������.
 RAZMER = $400;                    //������ ����������� ������ (1��).
Type
 TSect = packed record
   Name: Array [0..7] of Char;     //��� ������.
   S_VSiz: DWORD;                  //����������� ������.
   S_RVA: DWORD;                   //����������� ��������.
   S_FSiz: DWORD;                  //������ � �����.
   S_FOfs: DWORD;                  //�������� � �����.
   S_Res: Array [0..11] of Byte;   //�� ����������.
   S_Flag: DWORD;                  //���� ������.
 end;
 TStrTI = packed record
   ImpLookUp: DWORD;               //��������� �� ������� ����������.
   DateStamp: DWORD;               //����� ����������.
   Chain: DWORD;                   //�� ���������� = FFFFFFFFh.
   NameDll: DWORD;                 //RVA ��������� �� ��� ����� DLL.
   AddrTabl: DWORD;                //��������� �� ������ ������� ���������� (IAT).
 end;
Var
 F: THandle;               //����� �����.
 Sect, NewSect: TSect;     //��������� ������.
 StrTI: Array of TStrTI;   //��������a ����� ����. �������.
 DStrTI: TStrTI;           //��������� ����������� ������ � ����.�������.
 AdrPE, EP, ImBase, S_Align, F_Align, ImSize, RVA_TI, br: DWORD; //������ ��������� ���������.
 minS_FOfs: DWORD;           //���. �������� ������ � ����� (��� ��������).
 maxS_RVA, maxS_VSiz: DWORD; //��������� ������ � ����. �������. ����.
 TIS_RVA, TIS_FOfs: DWORD;   //���������� ������ � ����. �������.
 NewS_RVA, NewS_FOfs: DWORD; //���������� ����������� ������.
 RVA_FUN, RVA_Dll, RVA_IAT: DWORD;  //����������� ����� �������, ������ � ������� IAT.
 CloseIAT: DWORD = $00000000; //��� �������� IAT.
 Zero: Byte = $00; //������ ������ ������ (0).
 N_Sect: WORD;     //�-�� ������.
 FS: DWORD;        //������ �����.
 i, k : Integer;   //������� ������ � ����� �.�.
 Kernel: Array [0..12] of Byte = ($4B,$65,$72,$6E,$65,$6C,$33,$32,$2E,$64,$6C,$6C,$00);  //Kernel32.dll#
 BEEP: Array [0..6] of Byte = ($00,$00,$42,$65,$65,$70,$00); //##Beep# (�-�� ������� ���������� � �������).
 OfSet_TI: DWORD;  //�������� ����. ������� � �����.
 Atr: DWORD = $E0000020; //�������: c����� �������� �������, ����� ���������� �� ����������, ������ � ������.
 //������ ���� � ����� �������.
 PushOpCod: Byte = $68;              //����� �������� ������� Push #;
 CallOpCod: WORD = $15FF;            //����� �������� ������� Call DwordPtr [#];
 Mov_EAX_OpCod: Byte = $B8;          //����� �������� ������� Mov EAX, #;
 Jmp_EAX_OpCod: WORD = $E0FF;        //����� �������� ������� Jmp EAX;
 Frec: DWORD = $00000200;            //������� ����� = 512 ��.
 Time: DWORD = $000003E8;            //������������ �������� = 1000 �c.
Begin
 AdrPE:= 0; maxS_VSiz:= 0; TIS_RVA:= 0; TIS_FOfs:= 0;   //������������� ����������.
 F:= CreateFile(FileName, GENERIC_READ or GENERIC_WRITE,
                FILE_SHARE_READ or FILE_SHARE_WRITE, nil,
                OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL,0);
 if F = INVALID_HANDLE_VALUE Then Exit; //��� ������ �����.
 SetFilePointer(F, $3C, nil, FILE_BEGIN); //������ ��������� �� ����� �������� �� ���������.
 ReadFile(F, AdrPE, 4, br, nil);    //����� �������� ��.
 SetFilePointer(F, AdrPE + $06, nil, FILE_BEGIN);
 ReadFile(F, N_Sect, 2, br, nil);   //�-�� ������.
 SetFilePointer(F, AdrPE + $28, nil, FILE_BEGIN);
 ReadFile(F, EP, 4, br, nil);       //����� �����.
 SetFilePointer(F, AdrPE + $34, nil, FILE_BEGIN);
 ReadFile(F, ImBase, 4, br, nil);   //������� ����� ��������.
 SetFilePointer(F, AdrPE + $38, nil, FILE_BEGIN);
 ReadFile(F, S_Align, 4, br, nil);  //������������ ������ � ������.
 ReadFile(F, F_Align, 4, br, nil);  //������������ ������ �� �����.
 SetFilePointer(F, AdrPE + $80, nil, FILE_BEGIN);
 ReadFile(F, RVA_TI, 4, br, nil);   //RVA ������� �������.
 SetFilePointer(F, AdrPE + $F8, nil, FILE_BEGIN);
 minS_FOfs:= $FFFFFFFF;           //��������� �������� ������.
 maxS_RVA:=  $00000000;
For i:= 1 To N_Sect Do
 begin      //������ ������ �� �������.
  ReadFile(F, Sect, SizeOf(Sect), br, nil);
            //������� ������ � ���. ��������� � �����.
  if (Sect.S_FOfs > 0) and (Sect.S_FOfs <= minS_FOfs) Then
   minS_FOfs:= Sect.S_FOfs; //��������� ���. �������� (����� ��� �������� �����. ������).
  if (Sect.S_RVA > 0) and (Sect.S_RVA >= maxS_RVA) Then
   begin    //������� ������ � ���� ����������� ���������.
   maxS_RVA:= Sect.S_RVA;   //��������� � ���������
   maxS_VSiz:= Sect.S_VSiz; //(����� ��� ���������� ����� ������).
   end;     //������� ������ � ������� ����������� ����. �������.
  if (Sect.S_RVA <= RVA_TI) and (RVA_TI <= (Sect.S_RVA + Sect.S_VSiz)) Then
   begin
   TIS_RVA:= Sect.S_RVA;    //��������� � ���������
   TIS_FOfs:= Sect.S_FOfs;  //(����� ��� ����������� ����. �������).
   end;
 end;                   //���������: ����� �������� ������ ��� ���.
//(���.����.������-(����.��+������_��+(�-��_������*������_�����_������)))>=������_�����.������.
if (minS_FOfs - (AdrPE + $F8 + (N_Sect * $28))) >= $28 Then
 begin                  //���� �� �� ����� ������ ������ � ����. ������, ���� ��� - �����.
  FS:= GetFileSize(F, nil); //����� ������ �����.
  //����������� ����� ������ � ������ �� ������� S_Align.
  if ((maxS_RVA + maxS_VSiz) mod S_Align) = 0 Then NewS_RVA:= maxS_RVA + maxS_VSiz
  Else NewS_RVA:= (((maxS_RVA + maxS_VSiz) div S_Align) + 1) * S_Align;
  //����������� ����� ������ � ����� �� ������� F_Align.
  if (FS mod F_Align) = 0 Then NewS_FOfs:= FS
  Else NewS_FOfs:= ((FS div F_Align) + 1) * F_Align;
  //��������� ������.
  NewSect.Name[0]:= '.';
  NewSect.Name[1]:= 'N';
  NewSect.Name[2]:= 'e';
  NewSect.Name[3]:= 'w';      //��� ������ (������������).
  NewSect.Name[4]:= 'S';
  NewSect.Name[5]:= 'e';
  NewSect.Name[6]:= 'c';
  NewSect.Name[7]:= 't';
  NewSect.S_RVA:= NewS_RVA;   //������ ����� ������ � ������.
  NewSect.S_VSiz:= RAZMER;    //������ ����� ������ � ������.
  NewSect.S_FOfs:= NewS_FOfs; //�������� ����� ������ � �����.
  NewSect.S_FSiz:= RAZMER;    //������ ����� ������ � �����.
  NewSect.S_Flag:= Atr;       //������� ������.
  //������� ���� ��������� ������ � ����. ������ � �����.
             //��������_�� + ���_������ + (�-��_������ * ������_�����).
  SetFilePointer(F, (AdrPE + $F8 + (N_Sect * $28)), nil, FILE_BEGIN);
  WriteFile(F, NewSect, SizeOf(NewSect), br, nil); //��������.
  //�������� ���� ������ � ����� ������.
  //������ ��������� �� ������������� ���� � ����� � ����� 0.
  //�� ��������� �� ������������� ������������ ������.
  SetFilePointer(F, (NewS_FOfs + RAZMER)-1, nil, FILE_BEGIN);
  WriteFile(F, Zero, 1, br, nil);
  //������������ �-�� ������ � ���������.
  SetFilePointer(F, AdrPE + $06, nil, FILE_BEGIN);
  N_Sect:= N_Sect + 1;        //�-�� ������ + ��� ����.
  WriteFile(F, N_Sect, 2, br, nil);
  //������������ ������ ������������ ������ � ���������.
  SetFilePointer(F, AdrPE + $50, nil, FILE_BEGIN);
  ImSize:= NewS_RVA + RAZMER;   //����� ����� ����������� ������.
  WriteFile(F, ImSize, 4, br, nil);
  //����� ���������� ���� ��������� � ���� ������.
  //��������� � ������ ����� ������ ��� ������ (dll), ��� �������, ������� IAT, ��������� � ��
  //(����. ������� + ���� �-��), ��� ������ ������� � ��� �������� ������. ����� � ������� ����������.
  SetFilePointer(F, NewS_FOfs, nil, FILE_BEGIN);//��������� �� ���� ������.
  WriteFile(F, Kernel, 13, br, nil); //�������� ��� ������ (dll) � ������� ����������� �-��.
  RVA_Dll:= NewS_RVA;                //�������� RVA ������ ������ = RVA ������.
  WriteFile(F, BEEP, 7, br, nil);    //�������� ��� �������.
  RVA_FUN:= NewS_RVA + 13;           //�������� RVA �������.
  WriteFile(F, RVA_FUN, 4, br, nil); //�������� � IAT RVA �������.
  WriteFile(F, CloseIAT, 4, br, nil);//������� IAT 0000 0000.
  RVA_IAT:= NewS_RVA + 13 + 7;       //�������� RVA IAT.
  //������ ���������� ������ ����. �������. (��������� ���������).
  DStrTI.ImpLookUp:= RVA_IAT;       //RVA ������� ���������� 1.
  DStrTI.DateStamp:= $FFFFFFFF;     //����. ����� ��������.
  DStrTI.Chain:= $FFFFFFFF;         //������ ��������.
  DStrTI.NameDll:= RVA_Dll;         //RVA ������ � ������ ����� DLL.
  DStrTI.AddrTabl:= RVA_IAT;        //RVA ������� ���������� 2.
  WriteFile(F, DStrTI, SizeOf(DStrTI), br, nil); //�������� ���������� ������ �.�.
  //����� �������� � ���� ������ ����. �������.
  OfSet_TI:= RVA_TI - TIS_RVA + TIS_FOfs;     //�������� �.� � �����.
  SetFilePointer(F, OfSet_TI, nil, FILE_BEGIN); //��������� �� �.�. � �����.
  k:= -1;
  Repeat //������� �.� ��������� ���� �� ������� �� ������ � ������ (����� �.�).
  begin
  Inc(k);//������� ����� � �.�.
  SetLength(StrTI, k + 1);  //��������� ������� ������ ����� �.�.
  ReadFile(F, StrTI[k], SizeOf(StrTI[k]), br, nil);   //������� ������ � �����.
  end;
  Until (StrTI[k].NameDll = 0) and (StrTI[k].AddrTabl = 0); //�������� �� ������ � ������.
            //��������_������ + ������_Kernel + ������_BEEP + ������_IAT + ������_�����_������_�_�.�.
  SetFilePointer(F, NewS_FOfs + 13 + 7 + 8 + 20, nil, FILE_BEGIN);
  For i:= 0 To k - 1 Do WriteFile(F, StrTI[i], SizeOf(StrTI[i]), br, nil); //�������� �.�.
  RVA_TI:= NewS_RVA + 13 + 7 + 8; //�����������_��������_������ + ������_Kernel + ������_BEEP + ������_IAT.
  //������������ �������� �.�. � ���������.
  SetFilePointer(F, AdrPE + $80, nil, FILE_BEGIN);
  WriteFile(F, RVA_TI, 4, br, nil);
  RVA_IAT:= RVA_IAT + ImBase; //����� ����������� ����� IAT ��� �������� � ������.
  EP:= EP + ImBase;           //����� ����� ���������� ��� �������� � ������.
  //�������� ��� ����� �.�.
//��������_������ + ������_Kernel + ������_BEEP + ������_IAT + ������_�����_������_�_�.�. + ((�-��_�����_�.� + ����_�_������) * ������ ������).
  SetFilePointer(F, NewS_FOfs + 13 + 7 + 8 + 20 + ((k+1) * 20), nil, FILE_BEGIN);
  //������ �������� ������ � ��������.
  WriteFile(F, PushOpCod, 1, br, nil); WriteFile(F, Time, 4, br, nil);    //Push Time;            //�������� � ���� Time.
  WriteFile(F, PushOpCod, 1, br, nil); WriteFile(F, Frec, 4, br, nil);    //Push Frec;            //�������� � ���� Frec.
  WriteFile(F, CallOpCod, 2, br, nil); WriteFile(F, RVA_IAT, 4, br, nil); //Call Dword Ptr [IAT]; //�������� �-�� Beep.
  WriteFile(F, Mov_EAX_OpCod, 1, br, nil); WriteFile(F, EP, 4, br, nil);  //Mov EAX, EP;          //�������� � ������� EAX ������ ����� �����.
  WriteFile(F, Jmp_EAX_OpCod, 2, br, nil);                                //Jmp EAX;              //������� �� ��.
  //������ ����� ����� �� ��� ���.
  EP:= NewS_RVA + 13 + 7 + 8 + 20 + ((k+1) * 20);
  //������������ ����� ����� � ���������.
  SetFilePointer(F, AdrPE + $28, nil, FILE_BEGIN);
  WriteFile(F, EP, 4, br, nil);
 end;
 CloseHandle(F);   //������� ����.
End.
