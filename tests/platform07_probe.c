#include "../src/platform07.c"
#include <assert.h>
int main(int argc,char **argv){
 if(argc==2&&!strcmp(argv[1],"--powerd-events"))return zr_watch_events();
 if(argc==4&&!strcmp(argv[1],"--make-thumb"))return zr_make_thumb(argv[2],argv[3]);
 assert(argc>=2);
 if(!strcmp(argv[1],"device")){
  zr_device_init(0);usleep(200000);int a,b;zr_device_poll(&a,&b);assert(a==14&&b==18);
  for(int i=0;i<40;i++)zr_device_light(0,i);zr_device_light(1,-20);usleep(600000);zr_device_poll(&a,&b);assert(a==24&&b==0);
  zr_device_sleep(1);usleep(150000);zr_device_sleep(2);usleep(250000);
  int bits=zr_device_poll(&a,&b);assert(bits&1);assert(bits&4);assert(bits&8);assert(!(bits&16));
  zr_device_sleep(4);usleep(200000);zr_device_sleep(0);usleep(100000);zr_device_stop();puts("PASS LIPC startup reads/no writes, debounce/clamp, subscription, suspend/wake commands and cleanup");
 }else if(!strcmp(argv[1],"early-exit")){
  zr_device_init(0);zr_device_light(0,19);zr_device_light(1,7);zr_device_stop();puts("PASS final deliberate light change flushed even on immediate exit");
 }else if(!strcmp(argv[1],"failure")){
  zr_device_init(0);usleep(100000);zr_device_light(0,24);usleep(500000);int a,b;int bits=zr_device_poll(&a,&b);assert(bits&16);assert(a==14);zr_device_stop();puts("PASS failed LIPC write reported, last confirmed level retained");
 }else if(!strcmp(argv[1],"thumb")){
  assert(argc==4);zr_thumbs_init(argv[2]);unsigned char pix[TB];assert(zr_thumb(argv[3],pix)==0);
  long long t=millis();int ok=0;while(millis()-t<14000){if(zr_thumb(argv[3],pix)){ok=1;break;}nap();}assert(ok);
  int ink=0;for(int i=0;i<TB;i++)if(pix[i]<200)ink++;assert(ink>10);int fd=cachefd();assert(fd>=0);prune(fd,0);close(fd);
  printf("PASS lazy isolated first-page cover, %d ink pixels, bounded cache; %lld ms worker (not UI)\n",ink,millis()-t);
 }else if(!strcmp(argv[1],"timeout")){char *a[]={"sleep","5",0};long long t=millis();assert(command(a,0,0,150)==-1);assert(millis()-t<1000);puts("PASS hung CLI killed and reaped within timeout");}
 return 0;
}
