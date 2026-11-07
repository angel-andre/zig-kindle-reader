#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <sys/ioctl.h>
#include <sys/time.h>
#include <linux/input.h>
#include <linux/fb.h>
#include <time.h>
#include <sys/stat.h>
static int in,fb; static struct fb_var_screeninfo v; static struct fb_fix_screeninfo f; static unsigned char *m; static int xmax,ymax;
static double now(){struct timespec t;clock_gettime(CLOCK_MONOTONIC,&t);return t.tv_sec+t.tv_nsec/1e9;}
static uint64_t hash(){uint64_t h=1469598103934665603ULL;for(int y=120;y<(int)v.yres-160;y+=4)for(int x=60;x<(int)v.xres-60;x+=4){h^=m[y*f.line_length+x];h*=1099511628211ULL;}return h;}
static void ev(int t,int c,int val){struct {int32_t sec,usec;uint16_t type,code;int32_t value;} e={0}; struct timeval tv;gettimeofday(&tv,0);e.sec=tv.tv_sec;e.usec=tv.tv_usec;e.type=t;e.code=c;e.value=val;if(write(in,&e,sizeof e)!=sizeof e){perror("input");exit(2);}}
static void tap(){static int seq=0; int d=(seq++%2)?-3:3;int x=xmax*85/100+d,y=ymax*50/100+d;ev(EV_ABS,ABS_MT_SLOT,0);ev(EV_ABS,ABS_MT_TRACKING_ID,42+seq);ev(EV_ABS,ABS_MT_POSITION_X,x);ev(EV_ABS,ABS_MT_POSITION_Y,y);ev(EV_ABS,ABS_MT_PRESSURE,50);ev(EV_KEY,BTN_TOUCH,1);ev(EV_SYN,SYN_REPORT,0);usleep(30000);ev(EV_ABS,ABS_MT_TRACKING_ID,-1);ev(EV_ABS,ABS_MT_PRESSURE,0);ev(EV_KEY,BTN_TOUCH,0);ev(EV_SYN,SYN_REPORT,0);}
int main(int ac,char**av){fb=open("/dev/fb0",O_RDONLY);in=open("/dev/input/event1",O_RDWR);if(fb<0||in<0)return 2;ioctl(fb,FBIOGET_VSCREENINFO,&v);ioctl(fb,FBIOGET_FSCREENINFO,&f);m=mmap(0,f.smem_len,PROT_READ,MAP_SHARED,fb,0);struct input_absinfo a;ioctl(in,EVIOCGABS(ABS_MT_POSITION_X),&a);xmax=a.maximum;ioctl(in,EVIOCGABS(ABS_MT_POSITION_Y),&a);ymax=a.maximum;if(ac==1){printf("screen=%ux%u stride=%u bpp=%u touch_max=%d,%d\n",v.xres,v.yres,f.line_length,v.bits_per_pixel,xmax,ymax);for(int c=0;c<64;c++)if(ioctl(in,EVIOCGABS(c),&a)==0)printf("abs=%d min=%d max=%d\n",c,a.minimum,a.maximum);return 0;}
if(!strcmp(av[1],"shot")){printf("P5\n%u %u\n255\n",v.xres,v.yres);for(int y=0;y<v.yres;y++)fwrite(m+y*f.line_length,1,v.xres,stdout);return 0;}
if(!strcmp(av[1],"launch")){struct stat st; long off=0;if(!stat(av[3],&st))off=st.st_size;uint64_t old=hash();double t=now(),last=t,first=-1,mark=-1;pid_t p=fork();if(p==0){setsid();execl("/bin/sh","sh","-c",av[2],(char*)0);_exit(127);}char buf[32768];while(now()-t<60){uint64_t h=hash();double tt=now();if(h!=old){if(first<0)first=tt;last=tt;old=h;}if(mark<0){FILE *fp=fopen(av[3],"r");if(fp){fseek(fp,off,SEEK_SET);size_t n=fread(buf,1,sizeof(buf)-1,fp);buf[n]=0;fclose(fp);if(strstr(buf,av[4]))mark=tt;}}if(!strcmp(av[4],"-") && mark<0)mark=t; if(mark>=0 && tt-t>3 && tt-last>.7 && tt-mark>.7)break;usleep(5000);}printf("first_change_ms,last_change_ms,ready_log_ms,marker_found\n%.6f,%.6f,%.6f,%d\n",first<0?-1:(first-t)*1000,(last-t)*1000,mark<0?-1:(mark-t)*1000,mark>=0);return 0;}
if(!strcmp(av[1],"turns")){int n=atoi(av[2]);printf("sample,first_change_ms,stable_ms,changed\n");for(int i=0;i<n;i++){uint64_t h=hash(),old=h;double t=now(),first=-1,last=t;tap();while(now()-t<8){uint64_t q=hash();double tt=now();if(q!=old){if(first<0)first=tt;last=tt;old=q;}if(first>=0 && tt-last>.3)break;usleep(2000);}double end=now();printf("%d,%.6f,%.6f,%d\n",i+1,first<0?-1:(first-t)*1000,(last-t)*1000,first>=0);fflush(stdout);double remain=1.5-(end-t);if(remain>0)usleep(remain*1e6);}return 0;}
if(!strcmp(av[1],"rapid")){uint64_t old=hash();double t=now(),last=t;int changes=0;for(int i=0;i<10;i++){tap();usleep(120000);uint64_t h=hash();if(h!=old){old=h;last=now();changes++;}}while(now()-t<15){uint64_t h=hash();if(h!=old){old=h;last=now();changes++;}if(now()-last>3)break;usleep(2000);}printf("taps,last_observed_change_ms,observed_changes\n10,%.6f,%d\n",(last-t)*1000,changes);return 0;}return 1;}
