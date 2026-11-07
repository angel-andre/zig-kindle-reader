/* v0.9.9: count device-worker wakeups while idle (host build, no LIPC). */
#ifndef SRC
#define SRC "../src/platform07.c"
#endif
#include SRC
#include <dirent.h>
static long sw(void){long t=0;DIR*d=opendir("/proc/self/task");struct dirent*e;while((e=readdir(d))){if(e->d_name[0]=='.')continue;char p[96],l[128];snprintf(p,sizeof p,"/proc/self/task/%s/status",e->d_name);FILE*f=fopen(p,"r");if(!f)continue;while(fgets(l,sizeof l,f)){long v;if(sscanf(l,"voluntary_ctxt_switches: %ld",&v)==1)t+=v;if(sscanf(l,"nonvoluntary_ctxt_switches: %ld",&v)==1)t+=v;}fclose(f);}closedir(d);return t;}
int main(void){zr_device_init(0);sleep(3);long a=sw();sleep(10);long b=sw();
 zr_device_light(0,10);usleep(400000);int x,y;zr_device_poll(&x,&y);zr_device_stop();
 printf("{\"device_worker_wakeups_per_s\": %.1f}\n",(b-a)/10.0);return 0;}
