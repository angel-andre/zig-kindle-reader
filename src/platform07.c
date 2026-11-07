/* Bounded asynchronous device commands and isolated low-priority cover worker.
 * No shell interpolation, network, sysfs writes, or framebuffer mode changes. */
#define _GNU_SOURCE
#include "render.h"
#include <pthread.h>
#include <spawn.h>
#include <sys/wait.h>
#include <sys/resource.h>
#include <sys/prctl.h>
#include <sys/stat.h>
#include <sys/statvfs.h>
#include <fcntl.h>
#include <unistd.h>
#include <signal.h>
#include <dirent.h>
#include <time.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <errno.h>
#include <math.h>
extern char **environ;
static long long millis(void){struct timespec t;clock_gettime(CLOCK_MONOTONIC,&t);return (long long)t.tv_sec*1000+t.tv_nsec/1000000;}
static void nap(void){struct timespec t={0,20000000};nanosleep(&t,0);}
/* Spawn+bounded reap, even when a firmware CLI hangs. Safe from worker threads. */
static int command(char *const argv[],char *out,size_t cap,int timeout){
 int pp[2];if(pipe2(pp,O_CLOEXEC|O_NONBLOCK))return -1;
 posix_spawn_file_actions_t a;posix_spawn_file_actions_init(&a);
 posix_spawn_file_actions_adddup2(&a,pp[1],1);
 posix_spawn_file_actions_addopen(&a,2,"/dev/null",O_WRONLY,0);
 pid_t pid;int e=posix_spawnp(&pid,argv[0],&a,0,argv,environ);
 posix_spawn_file_actions_destroy(&a);close(pp[1]);if(e){close(pp[0]);return -1;}
 long long end=millis()+timeout;size_t n=0;int st=0,rc=-1;
 for(;;){char b[256];ssize_t r=read(pp[0],b,sizeof b);if(r>0&&out&&cap>n+1){size_t k=(size_t)r;if(k>cap-n-1)k=cap-n-1;memcpy(out+n,b,k);n+=k;}
  if(waitpid(pid,&st,WNOHANG)==pid){rc=WIFEXITED(st)&&WEXITSTATUS(st)==0?0:-1;break;}
  if(millis()>end){kill(pid,SIGKILL);waitpid(pid,&st,0);break;}nap();
 }
 /* Read final pipe data after a short command exits. */
 if(out&&cap){ssize_t r=read(pp[0],out+n,cap-n-1);if(r>0)n+=r;out[n]=0;}close(pp[0]);return rc;
}
static int prop(const char *name,int value){char v[16];snprintf(v,sizeof v,"%d",value);char *a[]={"lipc-set-prop","-i","com.lab126.powerd",(char*)name,v,0};return command(a,0,0,2000);}
static int getprop(const char *name,int integer,char *b,size_t n){char *a[]={"lipc-get-prop",integer?"-i":"-s","com.lab126.powerd",(char*)name,0};return command(a,b,n,2000);}
static pthread_mutex_t dm=PTHREAD_MUTEX_INITIALIZER;
static int dv[2]={-1,-1},want[2]={-1,-1},dirtylight[2],error_count,event_bits,enable_req=-1,enabled,sleep_req,stop_dev,started_dev;
static long long due[2];
static int battery=-1;
int zr_battery(void){pthread_mutex_lock(&dm);int v=battery;pthread_mutex_unlock(&dm);return v;}
/* bits: going=1,out=2,ready=4,wakeup=8,CLI failure=16,subscription lost=32 */
static pid_t event_pid;static int event_fd=-1;static pthread_t dev_thread;
static void endevents(void){if(event_pid>0){kill(event_pid,SIGKILL);waitpid(event_pid,0,0);}event_pid=0;if(event_fd>=0)close(event_fd);event_fd=-1;}
int zr_watch_events(void){prctl(PR_SET_PDEATHSIG,SIGKILL);if(getppid()==1)return 1;execlp("lipc-wait-event","lipc-wait-event","-m","-s","0","com.lab126.powerd","*",(char*)0);return 1;}
static int startevents(void){int p[2];if(pipe2(p,O_CLOEXEC|O_NONBLOCK))return -1;
 posix_spawn_file_actions_t a;posix_spawn_file_actions_init(&a);posix_spawn_file_actions_adddup2(&a,p[1],1);posix_spawn_file_actions_addopen(&a,2,"/dev/null",O_WRONLY,0);
 char *v[]={"/proc/self/exe","--powerd-events",0};int e=posix_spawnp(&event_pid,v[0],&a,0,v,environ);posix_spawn_file_actions_destroy(&a);close(p[1]);if(e){close(p[0]);event_pid=0;return -1;}event_fd=p[0];return 0;}
static void *device_worker(void *unused){(void)unused;char b[512];
 for(int i=0;i<2;i++){int v=-1;if(!getprop(i?"currentAmberLevel":"flIntensity",1,b,sizeof b)){char *e;long q=strtol(b,&e,10);if(e!=b&&q>=0&&q<=24)v=q;}pthread_mutex_lock(&dm);dv[i]=v;pthread_mutex_unlock(&dm);}
 long long lastbattery=-180000, laststate=0;char line[1024];size_t used=0;
 for(;;){int er,sr,values[2]={-1,-1},quit;pthread_mutex_lock(&dm);quit=stop_dev;er=enable_req;enable_req=-1;sr=sleep_req;sleep_req=0;
 for(int i=0;i<2;i++)if(dirtylight[i]&&(quit||millis()>=due[i])){values[i]=want[i];dirtylight[i]=0;}
 pthread_mutex_unlock(&dm);
 int failed=0;if(er>=0){enabled=er;if(enabled){endevents();if(startevents())failed=1;}else{endevents();if(prop("preventScreenSaver",1))failed=1;}}
 for(int i=0;i<2;i++)if(values[i]>=0){int rc=prop(i?"currentAmberLevel":"flIntensity",values[i]);pthread_mutex_lock(&dm);if(rc){error_count++;event_bits|=16;}else dv[i]=values[i];pthread_mutex_unlock(&dm);}
 if(quit)break;
 if(millis()-lastbattery>=180000){lastbattery=millis();int v=-1;
 if(!getprop("battLevel",1,b,sizeof b)){char *end;long n=strtol(b,&end,10);if(end!=b&&n>=0&&n<=100)v=n;}
 pthread_mutex_lock(&dm);battery=v;pthread_mutex_unlock(&dm);}

 if(sr==1&&enabled){if(prop("preventScreenSaver",0)||prop("powerButton",1))failed=1;}
 if(sr==3){if(!getprop("state",0,b,sizeof b)&&strstr(b,"active")){pthread_mutex_lock(&dm);event_bits|=2;pthread_mutex_unlock(&dm);}else if(prop("powerButton",1))failed=1;}
 if(sr==2){if(prop("preventScreenSaver",1))failed=1;}
 if(enabled&&event_fd>=0){char in[512];ssize_t n=read(event_fd,in,sizeof in);if(n==0){endevents();failed=1;pthread_mutex_lock(&dm);event_bits|=32;pthread_mutex_unlock(&dm);}
  for(ssize_t i=0;i<n;i++){if(in[i]=='\n'){line[used]=0;int bit=strstr(line,"goingToScreenSaver")?1:strstr(line,"outOfScreenSaver")?2:strstr(line,"readyToSuspend")?4:strstr(line,"wakeupFromSuspend")?8:0;pthread_mutex_lock(&dm);event_bits|=bit;pthread_mutex_unlock(&dm);used=0;}else if(used<sizeof line-1)line[used++]=in[i];else used=0;}}
 /* State polling is only a recovery fallback during a requested sleep. WakeupFromSuspend
  * alone is not a user wake: powerd may wake for housekeeping and return to suspend. */
 if(enabled&&millis()-laststate>2000){laststate=millis();if(!getprop("state",0,b,sizeof b)){int bit=strstr(b,"active")?64:strstr(b,"screenSaver")||strstr(b,"suspended")?128:0;pthread_mutex_lock(&dm);event_bits|=bit;pthread_mutex_unlock(&dm);}}
 if(failed){pthread_mutex_lock(&dm);error_count++;event_bits|=16;pthread_mutex_unlock(&dm);}nap();
 }endevents();if(enabled)prop("preventScreenSaver",1);return 0;}
void zr_device_init(int simulation){if(simulation)return;if(!pthread_create(&dev_thread,0,device_worker,0)){started_dev=1;}}
void zr_device_light(int which,int v){if(which<0||which>1)return;if(v<0)v=0;if(v>24)v=24;pthread_mutex_lock(&dm);want[which]=v;dirtylight[which]=1;due[which]=millis()+250;pthread_mutex_unlock(&dm);}
int zr_device_poll(int *light,int *warm){pthread_mutex_lock(&dm);*light=dv[0];*warm=dv[1];int bits=event_bits;event_bits=0;pthread_mutex_unlock(&dm);return bits;}
void zr_device_sleep(int action){pthread_mutex_lock(&dm);if(action==0||action==1)enable_req=action;else sleep_req=action==2?1:action==4?3:2;pthread_mutex_unlock(&dm);}
void zr_device_stop(void){if(!started_dev)return;/* bounded CLI waits; joins only during final exit, never in the input loop */pthread_mutex_lock(&dm);stop_dev=1;pthread_mutex_unlock(&dm);pthread_join(dev_thread,0);started_dev=0;}

#define TW 96
#define TH 128
#define TB (TW*TH)
#define TN 32
#define CACHE_CAP (10*1024*1024)
struct thumb{char path[1100];uint64_t key,age;int status;unsigned char pix[TB];};
static struct thumb ts[TN];static pthread_mutex_t tm=PTHREAD_MUTEX_INITIALIZER;static pthread_cond_t tc=PTHREAD_COND_INITIALIZER;static uint64_t tick;static unsigned revision;static char cachedir[1200];static int thumb_started;
static uint64_t hashbytes(uint64_t h,const void *v,size_t n){const unsigned char *s=v;while(n--)h=(h^*s++)*1099511628211ULL;return h;}
static int cachefd(void){return open(cachedir,O_RDONLY|O_DIRECTORY|O_NOFOLLOW|O_CLOEXEC);}
/* Prune only our own regular *.zrt files, never book files or links. Worker only. */
static void prune(int fd,size_t reserve){
 for(;;){DIR *d=fdopendir(dup(fd));if(!d)return;rewinddir(d);size_t total=0;time_t oldest=0;char victim[64]="";struct dirent *e;
 while((e=readdir(d))){size_t l=strlen(e->d_name);struct stat st;if(l!=20||strcmp(e->d_name+16,".zrt")||fstatat(fd,e->d_name,&st,AT_SYMLINK_NOFOLLOW)||!S_ISREG(st.st_mode))continue;total+=st.st_size;if(!*victim||st.st_mtime<oldest){oldest=st.st_mtime;snprintf(victim,sizeof victim,"%s",e->d_name);}}
 closedir(d);if(total+reserve<=CACHE_CAP||!*victim)break;if(unlinkat(fd,victim,0))break;
 }}
int zr_make_thumb(const char *path,const char *dest){
 prctl(PR_SET_PDEATHSIG,SIGKILL);if(getppid()==1)return 1;
 struct rlimit lim={256UL<<20,256UL<<20};setrlimit(RLIMIT_AS,&lim);nice(15);
 zr_doc *z=zr_open_cover(path);if(!z)return 1;float r[4];unsigned char pix[TB];int ok=0;
 if(zr_page_bounds(z,0,r)==0&&isfinite(r[2])&&isfinite(r[3])&&r[2]>r[0]&&r[3]>r[1]){float s=fminf(TW/(r[2]-r[0]),TH/(r[3]-r[1]));float m[6]={s,0,0,s,(TW-(r[2]-r[0])*s)/2-r[0]*s,(TH-(r[3]-r[1])*s)/2-r[1]*s};memset(pix,255,sizeof pix);ok=zr_render(z,0,m,pix,TW,TH,TW,0)==0;}
 zr_close(z);if(!ok)return 1;int fd=open(dest,O_WRONLY|O_CREAT|O_EXCL|O_NOFOLLOW|O_CLOEXEC,0600);if(fd<0)return 1;ssize_t n=write(fd,pix,sizeof pix);close(fd);return n==sizeof pix?0:1;
}
static int thumb_read(int fd,uint64_t key,const char *path,unsigned char *pix,char *name){
 struct stat st;if(stat(path,&st)||!S_ISREG(st.st_mode))return -1;
 /* Stable fixed-width identity on ARM and host; versioned raster format. */
 int64_t identity[]={st.st_size,st.st_mtim.tv_sec,st.st_mtim.tv_nsec,8};
 uint64_t disk=hashbytes(key,identity,sizeof identity);snprintf(name,64,"%016llx.zrt",(unsigned long long)disk);
 int f=openat(fd,name,O_RDONLY|O_NOFOLLOW|O_CLOEXEC),ok=0;if(f>=0){struct stat cs;if(!fstat(f,&cs)&&S_ISREG(cs.st_mode)&&cs.st_size==TB&&read(f,pix,TB)==TB)ok=1;close(f);}return ok;
}
static void *thumb_disk_worker(void *unused){(void)unused;int fd=cachefd();
 for(;;){pthread_mutex_lock(&tm);int k=-1;uint64_t oldest=UINT64_MAX;for(int i=0;i<TN;i++)if(ts[i].status==1&&ts[i].age<oldest){k=i;oldest=ts[i].age;}
 if(k<0){pthread_cond_wait(&tc,&tm);pthread_mutex_unlock(&tm);continue;}ts[k].status=6;char path[1100];strcpy(path,ts[k].path);uint64_t key=ts[k].key;pthread_mutex_unlock(&tm);
 unsigned char pix[TB];char name[64];int ok=thumb_read(fd,key,path,pix,name);
 pthread_mutex_lock(&tm);if(ts[k].key==key){if(ok==1){memcpy(ts[k].pix,pix,TB);ts[k].status=3;revision++;}else ts[k].status=ok<0?4:5;}pthread_cond_broadcast(&tc);pthread_mutex_unlock(&tm);
 }return 0;}
static void *thumb_worker(void *arg){(void)arg;nice(10);int fd=cachefd();if(fd>=0)prune(fd,0);
 for(;;){pthread_mutex_lock(&tm);int k=-1;uint64_t oldest=UINT64_MAX;for(int i=0;i<TN;i++)if(ts[i].status==5&&ts[i].age<oldest){k=i;oldest=ts[i].age;}
 if(k<0){pthread_cond_wait(&tc,&tm);pthread_mutex_unlock(&tm);continue;}ts[k].status=2;char path[1100];strcpy(path,ts[k].path);uint64_t key=ts[k].key;pthread_mutex_unlock(&tm);
 unsigned char pix[TB];char name[64],tmp[1280];int ok=thumb_read(fd,key,path,pix,name)==1;
 if(!ok&&fd>=0){snprintf(tmp,sizeof tmp,"%s/.thumb-%ld.tmp",cachedir,(long)getpid());unlink(tmp);char *a[]={"/proc/self/exe","--make-thumb",path,tmp,0};if(!command(a,0,0,12000)){int f=open(tmp,O_RDONLY|O_NOFOLLOW|O_CLOEXEC);if(f>=0){if(read(f,pix,TB)==TB)ok=1;close(f);}if(ok){prune(fd,TB);renameat(AT_FDCWD,tmp,fd,name);}}unlink(tmp);}
 pthread_mutex_lock(&tm);if(ts[k].key==key){if(ok)memcpy(ts[k].pix,pix,TB);ts[k].status=ok?3:4;revision++;}pthread_mutex_unlock(&tm);
 }return 0;
}
void zr_thumbs_init(const char *data){snprintf(cachedir,sizeof cachedir,"%s/thumbs",data);mkdir(cachedir,0700);int fd=cachefd();if(fd<0)return;close(fd);pthread_t t;pthread_attr_t a;pthread_attr_init(&a);pthread_attr_setstacksize(&a,512*1024);if(!pthread_create(&t,&a,thumb_worker,0)){pthread_detach(t);if(!pthread_create(&t,&a,thumb_disk_worker,0)){pthread_detach(t);thumb_started=1;}}pthread_attr_destroy(&a);}
/* Cancel stale queued misses on page change; a single active child stays bounded. */
/* v0.8.1: ready RAM covers stay ready across page changes. Demoting them to a
 * disk re-read made every cached cover arrive late and trigger its own redraw. */
void zr_thumbs_focus(void){pthread_mutex_lock(&tm);for(int i=0;i<TN;i++)if(ts[i].status==1||ts[i].status==5)ts[i].status=0;pthread_mutex_unlock(&tm);}
/* Library rescan only: re-check identity (size/mtime) of RAM covers off the UI thread. */
void zr_thumbs_revalidate(void){pthread_mutex_lock(&tm);for(int i=0;i<TN;i++)if(ts[i].status==3)ts[i].status=1;pthread_cond_broadcast(&tc);pthread_mutex_unlock(&tm);}
/* 3 ready, 1 disk read pending, 2 generation pending, 4 failed, 0 unknown. Never queues. */
int zr_thumb_peek(const char *path){if(!thumb_started||strlen(path)>=1100)return 4;uint64_t h=hashbytes(14695981039346656037ULL,path,strlen(path));int r=0;pthread_mutex_lock(&tm);
 for(int i=0;i<TN;i++)if(ts[i].status&&ts[i].key==h&&!strcmp(ts[i].path,path)){int st=ts[i].status;r=st==3?3:st==4?4:(st==1||st==6)?1:2;break;}pthread_mutex_unlock(&tm);return r;}
/* UI never reads disk, renders, waits for a mutex or a child. Bounded 32-entry RAM LRU. */
/* Workers hold tm only for short memcpy/bookkeeping, never during I/O; a blocking
 * lock avoids a spurious placeholder (and a later extra update) for a cached cover. */
int zr_thumb(const char *path,unsigned char *pixels){if(!thumb_started||strlen(path)>=1100)return 0;pthread_mutex_lock(&tm);uint64_t h=hashbytes(14695981039346656037ULL,path,strlen(path));int k=-1,empty=-1;uint64_t age=UINT64_MAX;
 for(int i=0;i<TN;i++){if(ts[i].status&&ts[i].key==h&&!strcmp(ts[i].path,path)){k=i;break;}if(ts[i].status!=1&&ts[i].status!=2&&ts[i].status!=5&&ts[i].status!=6&&ts[i].age<age){empty=i;age=ts[i].age;}}
 int ready=0;if(k>=0){ts[k].age=++tick;if(ts[k].status==3){memcpy(pixels,ts[k].pix,TB);ready=1;}}
 else if(empty>=0){k=empty;strcpy(ts[k].path,path);ts[k].key=h;ts[k].age=++tick;ts[k].status=1;pthread_cond_broadcast(&tc);}pthread_mutex_unlock(&tm);return ready;}
unsigned zr_thumb_revision(void){unsigned r=0;if(!pthread_mutex_trylock(&tm)){r=revision;pthread_mutex_unlock(&tm);}return r;}

/* C wrappers honor musl time64 symbol redirection on 32-bit ARM. Zig's direct
 * extern time() resolved the legacy time32 ABI and read a bogus high word. */
int64_t zr_now_seconds(void){return (int64_t)time(NULL);}
struct tm *zr_localtime64(const int64_t *v,struct tm *out){time_t t=(time_t)*v;return localtime_r(&t,out);}
uint64_t zr_file_size(const char *path){struct stat st;return !stat(path,&st)&&S_ISREG(st.st_mode)?(uint64_t)st.st_size:0;}
int zr_storage(const char *path,uint64_t *free_bytes,uint64_t *total){struct statvfs st;if(statvfs(path,&st))return -1;*free_bytes=(uint64_t)st.f_bavail*st.f_frsize;*total=(uint64_t)st.f_blocks*st.f_frsize;return 0;}

void zr_no_core(void){struct rlimit r={0,0};setrlimit(RLIMIT_CORE,&r);}
