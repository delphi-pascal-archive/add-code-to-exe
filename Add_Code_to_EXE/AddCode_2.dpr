{ Пример добавления кода (функции Beep) в exe файлы,
  без увеличения их размера.
  Действия проги:
   1. Находим секцию с кодом.
   2. Проверка (свободно в конце секции 86 байт).
   3. Если свободно дописываем код.
   4. Меняем точку входа на наш код.
  Автор проги: Боровик Андрей
               peexe@Mail.ru
 }
Program AddCode;
uses
  Windows;
Const
OpenFileName = 'C:\Test.exe'; // Путь и имя к чему добавляем.
// Прога которую будем добавлять к ехе.
ProgBeep: Array [0..81] of Byte = (
//Машинная команда.     Асемблерная команда.
 $58,                        // pop eax  Извлекаем из стека адрес внутри Kernel.
 $66,$31,$C0,                // xor ax,ax Очищаем младшие разряды адреса в eax.
                     // Metka_1: Ищем начальный адрес Kernel в памяти.
 $8B,$10,                    // mov edx,[eax] Помещаем значение из этого адреса в edx.
 $66,$81,$FA,$4D,$5A,        // cmp dx,5A4Dh. Если (dx = 'MZ') то
 $74,$07,                    // jz Metka_2    прыгаем на метку 2
 $2D,$00,$00,$01,$00,        // sub eax,10000h. иначе уменьшаем адрес в eax на 1 страницу памяти (65536 байт.)
 $EB,$F0,                    // jmp Metka_1   и прыгаем на метку 1.
                     // Metka_2: Мы здесь если нашли адрес Kernel в памяти. (в eax = адрес Kernel).
 $8B,$50,$3C,                // mov edx,[eax+$3C] Помещаем в edx смещение РЕ заголовка Kernel.
 $01,$C2,                    // add edx,eax  Добавляем к смещению адрес Kernel -> в edx адрес РЕ заголовка Kernel.
 $87,$C2,                    // xchg eax,edx Меняем местами eax = адрес РЕ; edx = адрес Kernel.
 $8B,$40,$78,                // mov eax,[eax+$78] Помещаем в eax смещение табл. експорта функций.
 $01,$D0,                    // add eax,edx  Добавляем к смещению табл. адрес Kernel. (в eax = адрес табл.експорта).
 $8B,$70,$1C,                // mov esi,[eax+$1C] Помещаем в esi смещение табл. адресов функций.
 $01,$D6,                    // add esi,edx  Добавляем к смещению табл. адресов адрес Kernel.(в esi = адрес табл. адресов функций).
 $8B,$78,$20,                // mov edi,[eax+$20] Помещаем в edi смещение табл. имён функций.
 $01,$D7,                    // add edi,edx Добавляем к смещению табл. имён адрес Kernel.(в edi = адрес табл. имён функций).
 $B9,$04,$00,$00,$00,        // mov ecx,04h. Помещаем в ecx 4 (размер 1 елемента табл. имён и адресов функций).
                     // Metka_3: Ищем адрес функции Beep в табл. експорта Kernel.
 $8B,$07,                    // mov eax,[edi] Помещаем в eax смещение имени і-ой функции.
 $01,$D0,                    // add eax,edx  Добавляем к eax адрес Kernel.
 $81,$38,$42,$65,$65,$70,    // cmp dword[eax],$42656570h. Если двойное слово по адресу eax = 'Beep' то
 $74,$06,                    // jz Metka_4  прыгаем на метку 4 иначе
 $01,$CF,                    // add edi,ecx увеличиваем адрес табл. имён функций (переходим к следующему имени)
 $01,$CE,                    // add esi,ecx увеличиваем адрес табл. адресов функций (переходим к следующему адресу)
 $EB,$EE,                    // jmp Metka_3 и переходим на метку 3.
                     // Metka_4: Мы здесь если нашли (esi = смещение адреса Beep в табл експорта).
 $8B,$36,                    // mov esi,[esi] Помещаем в esi,смещение адреса Beep в Kernel.
 $01,$D6,                    // add esi,edx Добавляем к смещению адреса Beep адрес Kernel.(в esi адрес функции Beep).
 $6A,$7F,                    // push 7F Помещаем в стек параметры функции (время).
 $6A,$7F,                    // push 7F Помещаем в стек параметры функции (частота).
 $FF,$D6,                    // call esi Вызываем функцию Beep.
 $B8,$00,$00,$00,$00,        // mov eax, OldEP + ImBase. Помещаем в eax "старую" точку входа в памяти.
 $FF,$E0);                   // jmp eax Прыгаем на неё.
Type
 TSect = packed record       // Структура секции.
   Name: Array [0..7] of Char;  // имя.
   VSiz: DWORD;                 // виртуальній размер.
   VOfs: DWORD;                 // виртуальное смещение.
   FSiz: DWORD;                 // физический размер.
   FOfs: DWORD;                 // физическое смащение.
   Res: Array [0..11] of Byte;
   Flag: DWORD;                 // флаг.
 end;
Var
 H: THandle;                    // идентификатор.
 Sect: TSect;                   // Структура секции.
 PE,EP,Imb,VAS,FAS,br: DWORD;   // нада.
 Chek: Array [0..85] of Byte;   // для проверки.
 N: WORD;                       // к-во секций.
 i: Integer;                    // счётчик.
Begin
 H:= CreateFile(OpenFileName,$C0000000,3,nil,3,$00000080,0); //Откр. файл Чт/Зп.
 if H = $FFFFFFFF Then
 begin
 MessageBox(0,'Ошибка открытия: '+OpenFileName,'MESG',MB_OK);
 Exit; // Ошибка выходим.
 end;
 SetFilePointer(H,$3C,nil,0);
 ReadFile(H,PE,4,br,nil);    // Cмещение РЕ.
 SetFilePointer(H,PE+$06,nil,0);
 ReadFile(H,N,2,br,nil);     // К-во секций.
 SetFilePointer(H,PE+$28,nil,0);
 ReadFile(H,EP,4,br,nil);    // RVA точки входа.
 SetFilePointer(H,PE+$34,nil,0);
 ReadFile(H,Imb,4,br,nil);   // База загрузки.
 SetFilePointer(H,PE+$F8,nil,0);
 FAS:=0; VAS:=0;
 For i:= 0 To N - 1 Do
 begin
  ReadFile(H,Sect,$28,br,nil); // Читаем секции по очереди.
  if (Sect.VOfs <= EP)and(EP < (Sect.VOfs + Sect.VSiz)) Then
  begin
  VAS:= Sect.VOfs + Sect.FSiz - 86;  //виртуальный адрес нашего кода.
  FAS:= Sect.FOfs + Sect.FSiz - 86;  //физический адрес нашего кода.
  end;
 end;
 SetFilePointer(H,FAS,nil,0);
 ReadFile(H,Chek,86,br,nil);         //читаем 86 байт по физическому адресу нашего кода.
 For i:= 0 To 85 Do if Chek[i] <> $00 Then
 begin
  MessageBox(0,'Нехватает места в конце кодовой секции.','MESG',MB_OK);
  CloseHandle(H);
  Exit;  // Ошибка выходим.
 end;
 SetFilePointer(H,FAS+4,nil,0);    // +4 для запаса чтоб код проги не повредить.
 WriteFile(H,ProgBeep,82,br,nil);  // записуем нашу прогу.
 SetFilePointer(H,FAS+4+82-6,nil,0); //уст. на OldEP.
 EP:= EP + Imb;                    // узнаём ЕР в памяти.
 WriteFile(H,EP,4,br,nil);         // записуем ЕР в памяти.
 SetFilePointer(H,PE+$28,nil,0);
 VAS:= VAS + 4;                    // меняем точку входа на наш код.
 WriteFile(H,VAS,4,br,nil);
 CloseHandle(H);                   // закрываемся.
 MessageBox(0,'Команды удачно добавлены в конец кодовой секции.','MESG',MB_OK);
end.
