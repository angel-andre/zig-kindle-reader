/* v0.10.1: run Contents detection on one book and print the result file. */
#include "render.h"
#include <stdio.h>
#include <unistd.h>
#include <stdlib.h>
int main(int argc,char**argv){if(argc<3)return 2;
 if(zr_contents_start(argv[1],argv[2],argc>3?argv[3][0]-48:0,1272*72.f/300,1696*72.f/300,9,18,1.4f))return 1;
 int d,t,f,ms,s;while((s=zr_contents_poll(&d,&t,&f,&ms))==1)usleep(20000);
 printf("state\t%d\tpages\t%d\tfound\t%d\tms\t%d\n",s,t,f,ms);return s==2?0:1;}
