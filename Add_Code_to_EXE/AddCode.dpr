{
 К теме о прoтекторах на Delphi.
 Пример добавления кода (функции Beep) в exe файлы.
  Действия проги:
   1. Проверка, можно добавить секцию или нет.
   2. Если можно, то добавляем (с учетом Extra Data в конце файла) для инсталляшек.
   3. Переносим в свою секцию таблицу импорта.
   4. Добавляем в нее функцию Beep.
   5. Записываем пару строчек кода.
  Недоработки:
   1. Портит упакованные проги (90%).  
  Автор проги: Боровик Андрей
               peexe@Mail.ru
}

program DOP;
Uses
 Windows;
Const
 FileName = 'c:\tmp\test.exe';     //Путь и имя проги к которой добавляем.
 RAZMER = $400;                    //Размер добавляемой секции (1Кб).
Type
 TSect = packed record
   Name: Array [0..7] of Char;     //Имя секции.
   S_VSiz: DWORD;                  //Виртуальный размер.
   S_RVA: DWORD;                   //Виртувльное смещение.
   S_FSiz: DWORD;                  //Размер в файле.
   S_FOfs: DWORD;                  //Смещение в файле.
   S_Res: Array [0..11] of Byte;   //Не используем.
   S_Flag: DWORD;                  //Флаг секции.
 end;
 TStrTI = packed record
   ImpLookUp: DWORD;               //Указатель на таблицу указателей.
   DateStamp: DWORD;               //Время добавления.
   Chain: DWORD;                   //Не используем = FFFFFFFFh.
   NameDll: DWORD;                 //RVA указатель на имя файла DLL.
   AddrTabl: DWORD;                //Указатель на вторую таблицу указателей (IAT).
 end;
Var
 F: THandle;               //Хендл файла.
 Sect, NewSect: TSect;     //Структуры секций.
 StrTI: Array of TStrTI;   //Структурa строк табл. импорта.
 DStrTI: TStrTI;           //Структура добавляемой строки в табл.импорта.
 AdrPE, EP, ImBase, S_Align, F_Align, ImSize, RVA_TI, br: DWORD; //Нужные параметры заголовка.
 minS_FOfs: DWORD;           //Мин. смещение секции в файле (для проверки).
 maxS_RVA, maxS_VSiz: DWORD; //Параметры секции с макс. виртуал. смещ.
 TIS_RVA, TIS_FOfs: DWORD;   //Пароаметры секции с табл. импорта.
 NewS_RVA, NewS_FOfs: DWORD; //Пароаметры добавляемой секции.
 RVA_FUN, RVA_Dll, RVA_IAT: DWORD;  //Виртуальный адрес функции, модуля и таблицы IAT.
 CloseIAT: DWORD = $00000000; //Для закрытия IAT.
 Zero: Byte = $00; //Данные пустой секции (0).
 N_Sect: WORD;     //К-во секций.
 FS: DWORD;        //Размер файла.
 i, k : Integer;   //Счётчик секций и строк т.и.
 Kernel: Array [0..12] of Byte = ($4B,$65,$72,$6E,$65,$6C,$33,$32,$2E,$64,$6C,$6C,$00);  //Kernel32.dll#
 BEEP: Array [0..6] of Byte = ($00,$00,$42,$65,$65,$70,$00); //##Beep# (ф-нц пикалка находиться в кернеле).
 OfSet_TI: DWORD;  //Смещение табл. импорта в файле.
 Atr: DWORD = $E0000020; //Атрибут: cекция является кодовой, имеет разрешения на исполнение, чтение и запись.
 //Опкоды берём в любом дизасме.
 PushOpCod: Byte = $68;              //Опкод машинной команды Push #;
 CallOpCod: WORD = $15FF;            //Опкод машинной команды Call DwordPtr [#];
 Mov_EAX_OpCod: Byte = $B8;          //Опкод машинной команды Mov EAX, #;
 Jmp_EAX_OpCod: WORD = $E0FF;        //Опкод машинной команды Jmp EAX;
 Frec: DWORD = $00000200;            //Частота звука = 512 Гц.
 Time: DWORD = $000003E8;            //Длительность звучания = 1000 мc.
Begin
 AdrPE:= 0; maxS_VSiz:= 0; TIS_RVA:= 0; TIS_FOfs:= 0;   //Инициализация переменных.
 F:= CreateFile(FileName, GENERIC_READ or GENERIC_WRITE,
                FILE_SHARE_READ or FILE_SHARE_WRITE, nil,
                OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL,0);
 if F = INVALID_HANDLE_VALUE Then Exit; //При ошибке выход.
 SetFilePointer(F, $3C, nil, FILE_BEGIN); //Ставим указатель на адрес смещения РЕ заголовка.
 ReadFile(F, AdrPE, 4, br, nil);    //Узнаём смещение РЕ.
 SetFilePointer(F, AdrPE + $06, nil, FILE_BEGIN);
 ReadFile(F, N_Sect, 2, br, nil);   //К-во секций.
 SetFilePointer(F, AdrPE + $28, nil, FILE_BEGIN);
 ReadFile(F, EP, 4, br, nil);       //Точка входа.
 SetFilePointer(F, AdrPE + $34, nil, FILE_BEGIN);
 ReadFile(F, ImBase, 4, br, nil);   //Базовый адрес загрузки.
 SetFilePointer(F, AdrPE + $38, nil, FILE_BEGIN);
 ReadFile(F, S_Align, 4, br, nil);  //Выравнивание секций в памяти.
 ReadFile(F, F_Align, 4, br, nil);  //Выравнивание секций на диске.
 SetFilePointer(F, AdrPE + $80, nil, FILE_BEGIN);
 ReadFile(F, RVA_TI, 4, br, nil);   //RVA таблицы импорта.
 SetFilePointer(F, AdrPE + $F8, nil, FILE_BEGIN);
 minS_FOfs:= $FFFFFFFF;           //Начальные значения поиска.
 maxS_RVA:=  $00000000;
For i:= 1 To N_Sect Do
 begin      //Читаем секции по очереди.
  ReadFile(F, Sect, SizeOf(Sect), br, nil);
            //Находим секцию с мин. смещением в файле.
  if (Sect.S_FOfs > 0) and (Sect.S_FOfs <= minS_FOfs) Then
   minS_FOfs:= Sect.S_FOfs; //Сохраняем мин. смещение (нужно для проверки добав. секции).
  if (Sect.S_RVA > 0) and (Sect.S_RVA >= maxS_RVA) Then
   begin    //Находим секцию с макс виртуальным смещением.
   maxS_RVA:= Sect.S_RVA;   //Сохраняем её параметры
   maxS_VSiz:= Sect.S_VSiz; //(нужны для добавления новой секции).
   end;     //Находим секцию в которой расположена табл. импорта.
  if (Sect.S_RVA <= RVA_TI) and (RVA_TI <= (Sect.S_RVA + Sect.S_VSiz)) Then
   begin
   TIS_RVA:= Sect.S_RVA;    //Сохраняем её параметры
   TIS_FOfs:= Sect.S_FOfs;  //(нужны для копирования табл. импорта).
   end;
 end;                   //Проверяем: можно добавить секцию или нет.
//(мин.смещ.секции-(смещ.РЕ+Размер_РЕ+(К-во_секций*Размер_одной_секции)))>=размер_добав.секции.
if (minS_FOfs - (AdrPE + $F8 + (N_Sect * $28))) >= $28 Then
 begin                  //если да то новая секция влезет в табл. секций, если нет - выход.
  FS:= GetFileSize(F, nil); //Узнаём размер файла.
  //Выравневаем новую секцию в памяти по значеию S_Align.
  if ((maxS_RVA + maxS_VSiz) mod S_Align) = 0 Then NewS_RVA:= maxS_RVA + maxS_VSiz
  Else NewS_RVA:= (((maxS_RVA + maxS_VSiz) div S_Align) + 1) * S_Align;
  //Выравневаем новую секцию в файле по значеию F_Align.
  if (FS mod F_Align) = 0 Then NewS_FOfs:= FS
  Else NewS_FOfs:= ((FS div F_Align) + 1) * F_Align;
  //Добавляем секцию.
  NewSect.Name[0]:= '.';
  NewSect.Name[1]:= 'N';
  NewSect.Name[2]:= 'e';
  NewSect.Name[3]:= 'w';      //Имя секции (произвольное).
  NewSect.Name[4]:= 'S';
  NewSect.Name[5]:= 'e';
  NewSect.Name[6]:= 'c';
  NewSect.Name[7]:= 't';
  NewSect.S_RVA:= NewS_RVA;   //Начало новой секции в памяти.
  NewSect.S_VSiz:= RAZMER;    //Размер новой секции в памяти.
  NewSect.S_FOfs:= NewS_FOfs; //Смещение новой секции в файле.
  NewSect.S_FSiz:= RAZMER;    //Размер новой секции в файле.
  NewSect.S_Flag:= Atr;       //Атрибут секции.
  //Запишим нашу созданную секцию в табл. секций в файле.
             //Смещение_РЕ + Его_размер + (к-во_секций * размер_одной).
  SetFilePointer(F, (AdrPE + $F8 + (N_Sect * $28)), nil, FILE_BEGIN);
  WriteFile(F, NewSect, SizeOf(NewSect), br, nil); //Записали.
  //Заполним нашу секцию в файле нулями.
  //Ставим указатель на предпоследний байт в файле и пишем 0.
  //До указателя всё автоматически заполняеться нулями.
  SetFilePointer(F, (NewS_FOfs + RAZMER)-1, nil, FILE_BEGIN);
  WriteFile(F, Zero, 1, br, nil);
  //Корректируем к-во секций в заголовке.
  SetFilePointer(F, AdrPE + $06, nil, FILE_BEGIN);
  N_Sect:= N_Sect + 1;        //К-во секций + ещё одна.
  WriteFile(F, N_Sect, 2, br, nil);
  //Корректируем размер загружаемого образа в заголовке.
  SetFilePointer(F, AdrPE + $50, nil, FILE_BEGIN);
  ImSize:= NewS_RVA + RAZMER;   //Общий объём виртуальной памяти.
  WriteFile(F, ImSize, 4, br, nil);
  //Далее записываем мини программу в нашу секцию.
  //Добавляем в начало нашей секции имя модуля (dll), имя функции, таблицу IAT, переносим в неё
  //(табл. импорта + наша ф-нц), код вызова функции и код передачи управл. проге к которой дописались.
  SetFilePointer(F, NewS_FOfs, nil, FILE_BEGIN);//Указатель на нашу секцию.
  WriteFile(F, Kernel, 13, br, nil); //Записали имя модуля (dll) с которой импортируем ф-нц.
  RVA_Dll:= NewS_RVA;                //Запомним RVA нашего модуля = RVA секции.
  WriteFile(F, BEEP, 7, br, nil);    //Записали имя функции.
  RVA_FUN:= NewS_RVA + 13;           //Запомним RVA функции.
  WriteFile(F, RVA_FUN, 4, br, nil); //Записали в IAT RVA функции.
  WriteFile(F, CloseIAT, 4, br, nil);//Закрыли IAT 0000 0000.
  RVA_IAT:= NewS_RVA + 13 + 7;       //Запомним RVA IAT.
  //Создаём добавочную строку табл. импорта. (заполняем структуру).
  DStrTI.ImpLookUp:= RVA_IAT;       //RVA таблицы указателей 1.
  DStrTI.DateStamp:= $FFFFFFFF;     //Макс. время создания.
  DStrTI.Chain:= $FFFFFFFF;         //Просто ФФФФФФФФ.
  DStrTI.NameDll:= RVA_Dll;         //RVA строки с именем файла DLL.
  DStrTI.AddrTabl:= RVA_IAT;        //RVA таблицы указателей 2.
  WriteFile(F, DStrTI, SizeOf(DStrTI), br, nil); //Записали добавочную строку т.и.
  //Далее копируем в свою секцию табл. импорта.
  OfSet_TI:= RVA_TI - TIS_RVA + TIS_FOfs;     //Смещение т.и в файле.
  SetFilePointer(F, OfSet_TI, nil, FILE_BEGIN); //Указатель на т.и. в файле.
  k:= -1;
  Repeat //Считуем т.и построчно пока не нарвёмся на строку с нулями (конец т.и).
  begin
  Inc(k);//Счётчик строк в т.и.
  SetLength(StrTI, k + 1);  //Установка размера масива строк т.и.
  ReadFile(F, StrTI[k], SizeOf(StrTI[k]), br, nil);   //Считуем строку в масив.
  end;
  Until (StrTI[k].NameDll = 0) and (StrTI[k].AddrTabl = 0); //Проверка на строки с нулями.
            //Смещение_секции + размер_Kernel + размер_BEEP + размер_IAT + размер_нашей_строки_в_т.и.
  SetFilePointer(F, NewS_FOfs + 13 + 7 + 8 + 20, nil, FILE_BEGIN);
  For i:= 0 To k - 1 Do WriteFile(F, StrTI[i], SizeOf(StrTI[i]), br, nil); //Комируем т.и.
  RVA_TI:= NewS_RVA + 13 + 7 + 8; //Виртуальное_смещение_секции + размер_Kernel + размер_BEEP + размер_IAT.
  //Корректируем смещение т.и. в заголовке.
  SetFilePointer(F, AdrPE + $80, nil, FILE_BEGIN);
  WriteFile(F, RVA_TI, 4, br, nil);
  RVA_IAT:= RVA_IAT + ImBase; //Узнаём виртуальный адрес IAT при загрузке в память.
  EP:= EP + ImBase;           //Узнаём адрес точкивхода при загрузке в память.
  //Записуем код после т.и.
//Смещение_секции + размер_Kernel + размер_BEEP + размер_IAT + размер_нашей_строки_в_т.и. + ((к-во_строк_т.и + одна_с_нулями) * размер строки).
  SetFilePointer(F, NewS_FOfs + 13 + 7 + 8 + 20 + ((k+1) * 20), nil, FILE_BEGIN);
  //Опкоды машинных команд и операнды.
  WriteFile(F, PushOpCod, 1, br, nil); WriteFile(F, Time, 4, br, nil);    //Push Time;            //Помещаем в стек Time.
  WriteFile(F, PushOpCod, 1, br, nil); WriteFile(F, Frec, 4, br, nil);    //Push Frec;            //Помещаем в стек Frec.
  WriteFile(F, CallOpCod, 2, br, nil); WriteFile(F, RVA_IAT, 4, br, nil); //Call Dword Ptr [IAT]; //Вызываем ф-нц Beep.
  WriteFile(F, Mov_EAX_OpCod, 1, br, nil); WriteFile(F, EP, 4, br, nil);  //Mov EAX, EP;          //Помещаем в регистр EAX старую точку входа.
  WriteFile(F, Jmp_EAX_OpCod, 2, br, nil);                                //Jmp EAX;              //Прыгаем на неё.
  //Меняем точку входа на наш код.
  EP:= NewS_RVA + 13 + 7 + 8 + 20 + ((k+1) * 20);
  //Корректируем точку входа в заголовке.
  SetFilePointer(F, AdrPE + $28, nil, FILE_BEGIN);
  WriteFile(F, EP, 4, br, nil);
 end;
 CloseHandle(F);   //Закрыли файл.
End.
