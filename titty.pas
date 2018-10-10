{Titty
 Programa para Linux, que crea un terminal para controlar a un proceso, de modo
 que el proceso se comportará tal cual, como si se ejecutara en un terminal real.
 Este programa se comunica mediante los flujos comunes: stdin y stdout.
                                                Por Tito Hinostroza - Lima 2016.}
program titty;
uses termio, BaseUnix, strings, linux;
const
  clib = 'c';

  function grantpt(__fd:cint):cint;cdecl;external clib name 'grantpt';
  function unlockpt(__fd:cint):cint;cdecl;external clib name 'unlockpt';
  function posix_openpt(__oflag:longint):longint;cdecl;external clib name 'posix_openpt';
  function ptsname(__fd:longint):Pchar;cdecl;external clib name 'ptsname';
  function execvp(__file:Pchar; __argv:PPchar):longint;cdecl;external clib name 'execvp';

var
 fdm, fds: integer;
 rc , i: integer;
 input: array [0..149] of char;
 fd_in: TFDSet;
 slave_orig_term_settings: termios; // Saved terminal settings
 new_term_settings: termios; // Current terminal settings

 child_av: PPchar;  //necesario para execvp()
 nbytes: TsSize;

begin
  if argc <= 1 then begin
    writeln(stderr, 'Error de sintaxis.');
    writeln(stderr, '  Usar: ', argv[0], ' <programa_a_ejecutar>');
    exit;
  end;
  //Abre un pseudo terminal y devuelve un descriptor de archivo
  fdm := posix_openpt(O_RDWR);
  if fdm < 0 then begin
    writeln(stderr, 'Error ', errno, ' en posix_openpt()');
    ExitCode:=1;
    exit;
  end;
  //Obtiene privilegios sobre el esclavo de "fdm"
  rc := grantpt(fdm);
  if rc <> 0 then begin
    writeln(stderr, 'Error ', errno, ' en grantpt()');
    ExitCode:=1;
    exit;
  end;
  //Desbloquea el esclavo de "fdm"
  rc := unlockpt(fdm);
  if rc <> 0 then begin
    writeln(stderr, 'Error ', errno, ' en unlockpt()');
    ExitCode:=1;
    exit;
  end;
  // Abre el lado esclavo del PTY
  fds := fpopen(ptsname(fdm), O_RDWR);

  //Crea el proceso hijo
  if fpfork<>0 then begin   //hace la magia del "fork"
    //////////// Códido del proceso PADRE ///////////////
    {Este es el proceso con el que vamos a interactuar directamente}
    fpclose(fds);  //cierra el lado esclavo del PTY
    while true do begin   //lazo infinito
      // Espera datos por el master del PTY
      fpFD_ZERO(fd_in);
      fpFD_SET(0, fd_in);
      fpFD_SET(fdm, fd_in);
      //"fpselect" se detiene a esperar. Si no se desea esperar, se puede usar
      //fpselect(fdm + 1, @fd_in, nil, nil, 1), que da un desborde de 1 mseg.
      rc := fpselect(fdm + 1, @fd_in, nil, nil, nil);
      if rc = -1 then begin
        writeln(stderr, 'Error ', errno, ' en select()');
        ExitCode:=1;
        exit;
      end else begin
          // Verifica si hay algo en stdin de este programa
          if fpFD_ISSET(0, fd_in)<>0 then begin
            nbytes := fpread(0, input, sizeof(input));
            if (nbytes > 0) then begin
              //Lo envía al master del PTY, para que le llegue al proceso
              fpwrite(fdm, input, nbytes);
            end else begin
              if (nbytes < 0) then begin
                writeln(stderr, 'Error ', errno, ' en standard input');
                ExitCode:=1;
                exit;
              end;
            end;
          end;
          //Verifica si hay algo en el master del PTY
          if fpFD_ISSET(fdm, fd_in)<>0 then begin
            nbytes := fpread(fdm, input, sizeof(input));
            if (nbytes > 0) then begin
              //Lo envía al stdout, o dicho de otra forma, lo escribe en pantalla
              fpwrite(1, input, nbytes);  //podría ser un simple: writeln(input);
            end else begin
              if (nbytes < 0) then begin
                writeln(stderr, 'Error ', errno, ' en read master PTY');
                ExitCode:=1;
                exit;
              end;
            end;
          end;
      end;
    end;
  end else begin
    //////////// Código del proceso HIJO ///////////////
    {Este es el proceso interactuará con el lado esclavo del PTY}
    fpclose(fdm);   //cierra el lado master del PTY

    //Guarda los parámetros del lado esclavo del PTY
    rc := tcgetattr(fds, slave_orig_term_settings);
    //Pone en modo "raw" en el lado esclavo del PTY
    new_term_settings := slave_orig_term_settings;
    cfmakeraw(new_term_settings);
    tcsetattr(fds, TCSANOW, new_term_settings);  //aplica cambios, ahora mismo

    //Desconecta los flujos del proceso hijo
    fpclose(0); // Cierra su stdin (current terminal)
    fpclose(1); // Cierra su stdout (current terminal)
    fpclose(2); // Cierra su stderr (current terminal)
    //Reconecta los flujos del proceso hijo
    fpdup(fds); // conecta al PTY: standard input (0)
    fpdup(fds); // conecta al PTY: standard output (1)
    fpdup(fds); // conecta al PTY: standard error (2)

    fpclose(fds);   //ya no es útil este descriptor

    // Crea nueva sesión, y hace al proceso hijo, lider de la sesión.
    fpsetsid;

    // Fija el controlador del terminal al lado slave del PTY
    fpioctl(0, TIOCSCTTY, Pointer(1) );

    //Ejecuta el programa pasado como parámetro

    //Crea el arreglo de parámetros, para pasar a execvp()
    GetMem(child_av, argc*SizeOf(Pchar));
    for i := 1 to argc-1 do begin
      child_av[i - 1] := strnew(argv[i]);
    end;
    child_av[argc-1] := nil;   //marca de fin
    rc := execvp(child_av[0], child_av);

    // Si no hay error con el proceso, execvp(), nunca termina
    ExitCode := 1;
    exit;
  end;
  ExitCode := 0;
end.