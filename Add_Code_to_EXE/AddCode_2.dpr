{ ������ ���������� ���� (������� Beep) � exe �����,
  ��� ���������� �� �������.
  �������� �����:
   1. ������� ������ � �����.
   2. �������� (�������� � ����� ������ 86 ����).
   3. ���� �������� ���������� ���.
   4. ������ ����� ����� �� ��� ���.
  ����� �����: ������� ������
               peexe@Mail.ru
 }
Program AddCode;
uses
  Windows;
Const
OpenFileName = 'C:\Test.exe'; // ���� � ��� � ���� ���������.
// ����� ������� ����� ��������� � ���.
ProgBeep: Array [0..81] of Byte = (
//�������� �������.     ����������� �������.
 $58,                        // pop eax  ��������� �� ����� ����� ������ Kernel.
 $66,$31,$C0,                // xor ax,ax ������� ������� ������� ������ � eax.
                     // Metka_1: ���� ��������� ����� Kernel � ������.
 $8B,$10,                    // mov edx,[eax] �������� �������� �� ����� ������ � edx.
 $66,$81,$FA,$4D,$5A,        // cmp dx,5A4Dh. ���� (dx = 'MZ') ��
 $74,$07,                    // jz Metka_2    ������� �� ����� 2
 $2D,$00,$00,$01,$00,        // sub eax,10000h. ����� ��������� ����� � eax �� 1 �������� ������ (65536 ����.)
 $EB,$F0,                    // jmp Metka_1   � ������� �� ����� 1.
                     // Metka_2: �� ����� ���� ����� ����� Kernel � ������. (� eax = ����� Kernel).
 $8B,$50,$3C,                // mov edx,[eax+$3C] �������� � edx �������� �� ��������� Kernel.
 $01,$C2,                    // add edx,eax  ��������� � �������� ����� Kernel -> � edx ����� �� ��������� Kernel.
 $87,$C2,                    // xchg eax,edx ������ ������� eax = ����� ��; edx = ����� Kernel.
 $8B,$40,$78,                // mov eax,[eax+$78] �������� � eax �������� ����. �������� �������.
 $01,$D0,                    // add eax,edx  ��������� � �������� ����. ����� Kernel. (� eax = ����� ����.��������).
 $8B,$70,$1C,                // mov esi,[eax+$1C] �������� � esi �������� ����. ������� �������.
 $01,$D6,                    // add esi,edx  ��������� � �������� ����. ������� ����� Kernel.(� esi = ����� ����. ������� �������).
 $8B,$78,$20,                // mov edi,[eax+$20] �������� � edi �������� ����. ��� �������.
 $01,$D7,                    // add edi,edx ��������� � �������� ����. ��� ����� Kernel.(� edi = ����� ����. ��� �������).
 $B9,$04,$00,$00,$00,        // mov ecx,04h. �������� � ecx 4 (������ 1 �������� ����. ��� � ������� �������).
                     // Metka_3: ���� ����� ������� Beep � ����. �������� Kernel.
 $8B,$07,                    // mov eax,[edi] �������� � eax �������� ����� �-�� �������.
 $01,$D0,                    // add eax,edx  ��������� � eax ����� Kernel.
 $81,$38,$42,$65,$65,$70,    // cmp dword[eax],$42656570h. ���� ������� ����� �� ������ eax = 'Beep' ��
 $74,$06,                    // jz Metka_4  ������� �� ����� 4 �����
 $01,$CF,                    // add edi,ecx ����������� ����� ����. ��� ������� (��������� � ���������� �����)
 $01,$CE,                    // add esi,ecx ����������� ����� ����. ������� ������� (��������� � ���������� ������)
 $EB,$EE,                    // jmp Metka_3 � ��������� �� ����� 3.
                     // Metka_4: �� ����� ���� ����� (esi = �������� ������ Beep � ���� ��������).
 $8B,$36,                    // mov esi,[esi] �������� � esi,�������� ������ Beep � Kernel.
 $01,$D6,                    // add esi,edx ��������� � �������� ������ Beep ����� Kernel.(� esi ����� ������� Beep).
 $6A,$7F,                    // push 7F �������� � ���� ��������� ������� (�����).
 $6A,$7F,                    // push 7F �������� � ���� ��������� ������� (�������).
 $FF,$D6,                    // call esi �������� ������� Beep.
 $B8,$00,$00,$00,$00,        // mov eax, OldEP + ImBase. �������� � eax "������" ����� ����� � ������.
 $FF,$E0);                   // jmp eax ������� �� ��.
Type
 TSect = packed record       // ��������� ������.
   Name: Array [0..7] of Char;  // ���.
   VSiz: DWORD;                 // ���������� ������.
   VOfs: DWORD;                 // ����������� ��������.
   FSiz: DWORD;                 // ���������� ������.
   FOfs: DWORD;                 // ���������� ��������.
   Res: Array [0..11] of Byte;
   Flag: DWORD;                 // ����.
 end;
Var
 H: THandle;                    // �������������.
 Sect: TSect;                   // ��������� ������.
 PE,EP,Imb,VAS,FAS,br: DWORD;   // ����.
 Chek: Array [0..85] of Byte;   // ��� ��������.
 N: WORD;                       // �-�� ������.
 i: Integer;                    // �������.
Begin
 H:= CreateFile(OpenFileName,$C0000000,3,nil,3,$00000080,0); //����. ���� ��/��.
 if H = $FFFFFFFF Then
 begin
 MessageBox(0,'������ ��������: '+OpenFileName,'MESG',MB_OK);
 Exit; // ������ �������.
 end;
 SetFilePointer(H,$3C,nil,0);
 ReadFile(H,PE,4,br,nil);    // C������� ��.
 SetFilePointer(H,PE+$06,nil,0);
 ReadFile(H,N,2,br,nil);     // �-�� ������.
 SetFilePointer(H,PE+$28,nil,0);
 ReadFile(H,EP,4,br,nil);    // RVA ����� �����.
 SetFilePointer(H,PE+$34,nil,0);
 ReadFile(H,Imb,4,br,nil);   // ���� ��������.
 SetFilePointer(H,PE+$F8,nil,0);
 FAS:=0; VAS:=0;
 For i:= 0 To N - 1 Do
 begin
  ReadFile(H,Sect,$28,br,nil); // ������ ������ �� �������.
  if (Sect.VOfs <= EP)and(EP < (Sect.VOfs + Sect.VSiz)) Then
  begin
  VAS:= Sect.VOfs + Sect.FSiz - 86;  //����������� ����� ������ ����.
  FAS:= Sect.FOfs + Sect.FSiz - 86;  //���������� ����� ������ ����.
  end;
 end;
 SetFilePointer(H,FAS,nil,0);
 ReadFile(H,Chek,86,br,nil);         //������ 86 ���� �� ����������� ������ ������ ����.
 For i:= 0 To 85 Do if Chek[i] <> $00 Then
 begin
  MessageBox(0,'��������� ����� � ����� ������� ������.','MESG',MB_OK);
  CloseHandle(H);
  Exit;  // ������ �������.
 end;
 SetFilePointer(H,FAS+4,nil,0);    // +4 ��� ������ ���� ��� ����� �� ���������.
 WriteFile(H,ProgBeep,82,br,nil);  // �������� ���� �����.
 SetFilePointer(H,FAS+4+82-6,nil,0); //���. �� OldEP.
 EP:= EP + Imb;                    // ����� �� � ������.
 WriteFile(H,EP,4,br,nil);         // �������� �� � ������.
 SetFilePointer(H,PE+$28,nil,0);
 VAS:= VAS + 4;                    // ������ ����� ����� �� ��� ���.
 WriteFile(H,VAS,4,br,nil);
 CloseHandle(H);                   // �����������.
 MessageBox(0,'������� ������ ��������� � ����� ������� ������.','MESG',MB_OK);
end.
