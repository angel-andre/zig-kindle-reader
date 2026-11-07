#include "../src/platform07.c"
#include <assert.h>
int main(int argc,char **argv){
 if(argc==4&&!strcmp(argv[1],"--make-thumb")){
  if(getenv("ZR08_FORBID_RENDER"))return 77;
  if(strstr(argv[2],"slow")){struct timespec t={2,0};nanosleep(&t,0);}
  return zr_make_thumb(argv[2],argv[3]);
 }
 if(argc==2&&!strcmp(argv[1],"battery")){zr_device_init(0);long long end=millis()+2000;while(zr_battery()<0&&millis()<end)nap();assert(zr_battery()==76);zr_device_stop();puts("PASS read-only cached battLevel 76%");return 0;}
 if(argc<4)return 2;
 zr_thumbs_init(argv[2]);unsigned char p[TB];long long start=millis();
 if(!strcmp(argv[1],"page")){assert(argc==10);int ready=0;while(millis()-start<1000){ready=0;for(int i=3;i<10;i++)ready+=zr_thumb(argv[i],p);if(ready==7)break;nap();}assert(ready==7);printf("PASS cached page: 7 covers ready in %lld ms, no renders\n",millis()-start);return 0;}

 if(!strcmp(argv[1],"blocked")){assert(argc==5);zr_thumb(argv[4],p);while(millis()-start<200)nap();start=millis();}
 zr_thumb(argv[3],p);int ok=0;while(millis()-start<5000){if(zr_thumb(argv[3],p)){ok=1;break;}nap();}
 long long elapsed=millis()-start;
 if(!strcmp(argv[1],"invalid")){assert(!ok);puts("PASS changed file invalidates disk thumbnail identity");return 0;}
 assert(ok);if(!strcmp(argv[1],"hit")||!strcmp(argv[1],"blocked"))assert(elapsed<250);
 printf("PASS %s cover readiness %lld ms\n",argv[1],elapsed);return 0;
}
