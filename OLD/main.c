#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <unistd.h>


int main()
{
    char * Buff = malloc(1024*2);
    char * STDOUT = malloc(1024*2);

#ifdef _WIN32
    char Interprete[] = "powershell";
#else
    char Interprete[] = "pwsh";
#endif

    char Comando[] =" ./VisorDeProcesos.ps1";
    
    memcpy(Buff,Interprete,sizeof(Interprete));
    strcat(Buff,Comando);

    int tmp = system(Buff);

    return EXIT_SUCCESS;
}
