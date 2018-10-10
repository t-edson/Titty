# Titty
Ejemplo de Emulador de terminal en Linux, con Free Pascal

Este código es el que se presenta en el artículo: http://blog.pucp.edu.pe/blog/tito/2016/12/04/el-inicio-de-un-terminal-con-linux-y-free-pascal/

El trabajo de este programa está en crear un proceso con el programa que se pasa como parámetro, y luego enchufarlo a un PTY, para poder interactuar con él, mediante el lado Master.

Las tareas de crear un proceso y lanzarlo recae en el código del proceso hijo. Aquí se hace uso de rutinas muy bajas, del sistema operativo, para crear el proceso requerido.

Con este programa podemos ahora controlar procesos rebeldes, que no quieren trabajar con stdin y stdout, sino que piden un terminal para operar. 

Este código es una aplicación de consola, para Linux. No funcionará en Windows. Además, como es una aplicación de consola, debe primero compilarse y usarse desde la línea de comando.

Una vez compilado, se puede llamar desde línea de comandos, pasando el comando a ejecutar como parámetro. Por ejemplo si se desea ejecutar el comando "ls -l":

$ ./titty ls -l

